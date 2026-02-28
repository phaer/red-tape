# mk-red-tape.nix — Core entry point logic shared by flake and traditional modes
#
# Constructs the adios module tree, evaluates it for each system,
# and assembles the final output.
#
# Adios API:
#   loaded  = adios rootDef              → { eval, root }
#   evaled  = loaded.eval { options }    → { evalParams, override, root }
#   result  = evaled.root.modules.<name> {}  → impl return value
#   evaled2 = evaled.override { options }    → same shape as eval result
#
# Data flow:
#   Discovery runs as a plain function (not an adios module).
#   Discovered paths are passed as options to per-system modules.
#   The entry point calls each module through the tree and assembles results.

{ adios }:

let
  inherit (builtins)
    attrNames
    concatMap
    head
    tail
    listToAttrs
    map
    mapAttrs
    ;

  transpose = import ./transpose.nix;
  filterPlatforms = import ./filter-platforms.nix;
  discover = import ../modules/discover.nix;
  buildTemplates = import ./build-templates.nix;

  # Prefix all keys of an attrset
  withPrefix = prefix: attrs:
    listToAttrs (map (name: {
      name = "${prefix}${name}";
      value = attrs.${name};
    }) (attrNames attrs));

  # Build the adios module tree definition from our modules.
  mkRootDef = { extraModules ? {} }:
    let
      callMod = path: import path adios;
    in
    {
      name = "red-tape";
      modules = {
        nixpkgs   = callMod ../modules/nixpkgs.nix;
        packages  = callMod ../modules/packages.nix;
        devshells = callMod ../modules/devshells.nix;
        formatter = callMod ../modules/formatter.nix;
        checks    = callMod ../modules/checks.nix;
      } // extraModules;
    };

  # Build the perSystem attrset for a given system from flake inputs.
  mkPerSystem = flakeInputs: self: system:
    let
      base = mapAttrs (_name: input:
        if builtins.isAttrs input then
          (input.legacyPackages.${system} or {})
          // (input.packages.${system} or {})
        else
          input
      ) flakeInputs;
    in
    if self != null then
      base // {
        self = (self.legacyPackages.${system} or {}) // (self.packages.${system} or {});
      }
    else
      base;

  # Build the extra scope injected into callPackage for user files.
  mkExtraScope = { flakeInputs ? {}, self ? null, perSystem ? {} }:
    { inherit perSystem; }
    // (if self != null then { flake = self; } else {})
    // (if flakeInputs != {} || self != null then {
      inputs = flakeInputs // (if self != null then { self = self; } else {});
    } else {});

  # Collect results from an evaluated tree for one system.
  # Calls each module through the tree and assembles the output.
  collectResults = evaled: system: discovered:
    let
      mods = evaled.root.modules;

      # Call each module (passes {} = no extra options)
      pkgResult = mods.packages {};
      devResult = mods.devshells {};
      fmtResult = mods.formatter {};
      chkResult = mods.checks {};

      # Auto-checks: packages + passthru.tests + devshells
      packageChecks =
        withPrefix "pkgs-" pkgResult.filteredPackages
        // listToAttrs (concatMap (pname:
          let
            pkg = pkgResult.filteredPackages.${pname};
            tests = filterPlatforms system (pkg.passthru.tests or {});
          in
          map (tname: {
            name = "pkgs-${pname}-${tname}";
            value = tests.${tname};
          }) (attrNames tests)
        ) (attrNames pkgResult.filteredPackages));

      devshellChecks = withPrefix "devshell-" devResult.devShells;
    in
    {
      packages = pkgResult.filteredPackages;
      devShells = devResult.devShells;
      formatter = fmtResult.formatter;
      # User checks take precedence over auto-checks
      checks = packageChecks // devshellChecks // chkResult.checks;
    };

  # Main flake-mode entry point
  mkFlake =
    {
      # Flake inputs (must contain nixpkgs)
      inputs,
      # The flake self-reference (for fixpoint)
      self ? inputs.self or null,
      # Source root (resolved from prefix)
      src ? (if self != null then self else throw "red-tape: either `self` or `src` must be provided"),
      # Optional prefix within source
      prefix ? null,
      # Systems to build for
      systems ? [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ],
      # Nixpkgs configuration
      nixpkgs ? {},
      # Extra adios modules to include
      extraModules ? {},
      # Third-party module config (maps to adios tree options)
      config ? {},
    }:
    let
      flakeInputs = builtins.removeAttrs inputs [ "self" ];

      resolvedSrc =
        if prefix != null then
          if builtins.isPath prefix then prefix
          else if builtins.isString prefix then src + "/${prefix}"
          else throw "red-tape: prefix must be a string or path"
        else
          src;

      # Discover filesystem layout (pure, evaluated once)
      discovered = discover resolvedSrc;

      rootDef = mkRootDef { inherit extraModules; };

      nixpkgsFor = system:
        let
          cfg = nixpkgs.config or {};
          overlays = nixpkgs.overlays or [];
        in
        if cfg == {} && overlays == [] then
          inputs.nixpkgs.legacyPackages.${system}
        else
          import inputs.nixpkgs {
            inherit system;
            config = cfg;
            inherit overlays;
          };

      # Convert config parameter to adios option paths
      configOptions = listToAttrs (map (key: {
        name = "/${key}";
        value = config.${key};
      }) (attrNames config));

      mkOptions = system:
        let
          perSystem = mkPerSystem flakeInputs self system;
          extraScope = mkExtraScope { inherit flakeInputs self perSystem; };
        in
        {
          "/nixpkgs" = {
            inherit system;
            pkgs = nixpkgsFor system;
          };
          "/packages" = {
            discovered = discovered.packages;
            inherit extraScope;
          };
          "/devshells" = {
            discovered = discovered.devshells;
            inherit extraScope;
          };
          "/formatter" = {
            formatterPath = discovered.formatter;
            inherit extraScope;
          };
          "/checks" = {
            discovered = discovered.checks;
            inherit extraScope;
          };
        } // configOptions;

      # Load the tree once
      loaded = adios rootDef;

      # First system: full evaluation
      firstSystem = head systems;
      firstEvaled = loaded.eval { options = mkOptions firstSystem; };
      firstResult = collectResults firstEvaled firstSystem discovered;

      # Subsequent systems: override /nixpkgs + per-system options
      remainingSystems = tail systems;
      otherResults = listToAttrs (map (sys:
        let
          perSystem = mkPerSystem flakeInputs self sys;
          extraScope = mkExtraScope { inherit flakeInputs self perSystem; };
          overridden = firstEvaled.override {
            options = {
              "/nixpkgs" = {
                system = sys;
                pkgs = nixpkgsFor sys;
              };
              "/packages" = {
                discovered = discovered.packages;
                inherit extraScope;
              };
              "/devshells" = {
                discovered = discovered.devshells;
                inherit extraScope;
              };
              "/formatter" = {
                formatterPath = discovered.formatter;
                inherit extraScope;
              };
              "/checks" = {
                discovered = discovered.checks;
                inherit extraScope;
              };
            };
          };
        in
        { name = sys; value = collectResults overridden sys discovered; }
      ) remainingSystems);

      allPerSystem = { ${firstSystem} = firstResult; } // otherResults;

      # Transpose to flake output shape
      transposed = transpose allPerSystem;

      # System-agnostic outputs
      buildModules = import ./build-modules.nix { inherit flakeInputs self; };
      buildHosts = import ./build-hosts.nix { inherit flakeInputs self; };

      modulesOutput = buildModules discovered.modules;
      hostsOutput = buildHosts discovered.hosts;
      templatesOutput = buildTemplates discovered.templates;

      libOutput =
        if discovered.lib != null then
          import discovered.lib {
            flake = self;
            inputs = flakeInputs // (if self != null then { self = self; } else {});
          }
        else
          {};

      agnosticOutputs =
        hostsOutput
        // modulesOutput
        // (if templatesOutput != {} then { templates = templatesOutput; } else {})
        // (if libOutput != {} then { lib = libOutput; } else {});

    in
    transposed // agnosticOutputs;

  # Traditional (non-flake) entry point
  eval =
    {
      # Nixpkgs instance
      pkgs,
      # Source root
      src,
      # Extra adios modules
      extraModules ? {},
      # Third-party module config
      config ? {},
      # Extra scope for callPackage
      extraScope ? {},
    }:
    let
      system = pkgs.system or pkgs.stdenv.hostPlatform.system;

      discovered = discover src;

      rootDef = mkRootDef { inherit extraModules; };

      configOptions = listToAttrs (map (key: {
        name = "/${key}";
        value = config.${key};
      }) (attrNames config));

      loaded = adios rootDef;
      evaled = loaded.eval {
        options = {
          "/nixpkgs" = { inherit system pkgs; };
          "/packages" = {
            discovered = discovered.packages;
            inherit extraScope;
          };
          "/devshells" = {
            discovered = discovered.devshells;
            inherit extraScope;
          };
          "/formatter" = {
            formatterPath = discovered.formatter;
            inherit extraScope;
          };
          "/checks" = {
            discovered = discovered.checks;
            inherit extraScope;
          };
        } // configOptions;
      };

      result = collectResults evaled system discovered;

      templatesOutput = buildTemplates discovered.templates;

      libOutput =
        if discovered.lib != null then
          import discovered.lib {
            flake = null;
            inputs = {};
          }
        else
          {};
    in
    result // {
      # Convenience alias
      shell = result.devShells.default or null;
    }
    // (if templatesOutput != {} then { templates = templatesOutput; } else {})
    // (if libOutput != {} then { lib = libOutput; } else {});

in
{
  inherit mkFlake eval;
}
