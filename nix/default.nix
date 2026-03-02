# red-tape — Convention-based Nix project builder on adios-flake
#
# Usage:  outputs = inputs: inputs.red-tape.lib { inherit inputs; };
{ adios-flake }:
let
  inherit (builtins)
    addErrorContext all attrNames concatMap elem filter
    foldl' functionArgs intersectAttrs isAttrs isFunction
    isPath isString listToAttrs map mapAttrs pathExists readDir;

  adiosFlakeLib = adios-flake.lib or adios-flake;
  discover = import ./discover.nix;

  # ── Primitives ─────────────────────────────────────────────────────
  #
  # Three small, orthogonal tools that the rest is built from:
  #
  #   callFile  — import a .nix file, auto-inject from scope
  #   entryPath — resolve a discovered entry to its .nix path
  #   buildAll  — callFile over every discovered entry

  callFile = scope: path: extra:
    addErrorContext "while evaluating '${toString path}'" (
      let fn = import path;
      in fn (intersectAttrs (functionArgs fn) (scope // extra))
    );

  entryPath = entry:
    if entry.type == "directory" then entry.path + "/default.nix" else entry.path;

  buildAll = scope: discovered:
    mapAttrs (pname: entry: callFile scope (entryPath entry) { inherit pname; }) discovered;

  withPrefix = prefix: attrs:
    listToAttrs (map (n: { name = "${prefix}${n}"; value = attrs.${n}; }) (attrNames attrs));

  filterPlatforms = system: attrs:
    listToAttrs (filter (x: x != null) (map (name:
      let p = attrs.${name}.meta.platforms or [];
      in if p == [] || elem system p
        then { inherit name; value = attrs.${name}; }
        else null
    ) (attrNames attrs)));

  # ── Module export ──────────────────────────────────────────────────

  defaultTypeAliases = { nixos = "nixosModules"; darwin = "darwinModules"; home = "homeModules"; };

  buildModules = { discovered, flakeInputs, self, extraTypeAliases ? {} }:
    let
      allInputs     = flakeInputs // (if self != null then { inherit self; } else {});
      publisherArgs = { flake = self; inputs = allInputs; };
      typeAliases   = defaultTypeAliases // extraTypeAliases;

      expectsPublisherArgs = fn:
        isFunction fn && (functionArgs fn) != {}
        && all (a: elem a (attrNames publisherArgs)) (attrNames (functionArgs fn));

      importModule = entry:
        let path = entryPath entry; mod = import path;
        in if expectsPublisherArgs mod
          then { _file = toString path; imports = [ (mod (intersectAttrs (functionArgs mod) publisherArgs)) ]; }
          else path;

      built = mapAttrs (_: entries: mapAttrs (_: importModule) entries) discovered;
    in
    foldl' (acc: t:
      let alias = typeAliases.${t} or null;
      in if alias != null && discovered ? ${t}
        then acc // { ${alias} = built.${t}; }
        else acc
    ) {} (attrNames discovered);

  # ── Host configurations ────────────────────────────────────────────

  buildHosts = { discovered, flakeInputs, self }:
    let
      allInputs   = flakeInputs // (if self != null then { inherit self; } else {});
      specialArgs = { flake = self; inputs = allInputs; };

      classMap = { nixos = "nixosConfigurations"; nix-darwin = "darwinConfigurations"; };

      loadHost = name: info:
        addErrorContext "while building host '${name}' (${info.type})" (
          if info.type == "custom" then
            import info.configPath { inherit (specialArgs) flake inputs; hostName = name; }
          else if info.type == "nixos" then {
            class = "nixos";
            value = flakeInputs.nixpkgs.lib.nixosSystem {
              modules = [ info.configPath ];
              specialArgs = specialArgs // { hostName = name; };
            };
          }
          else if info.type == "darwin" then
            let nd = flakeInputs.nix-darwin or (throw "red-tape: host '${name}' needs inputs.nix-darwin");
            in { class = "nix-darwin"; value = nd.lib.darwinSystem {
              modules = [ info.configPath ];
              specialArgs = specialArgs // { hostName = name; };
            }; }
          else throw "red-tape: unknown host type '${info.type}' for '${name}'"
        );

      loaded = mapAttrs loadHost discovered;

      byCategory = cat: listToAttrs (filter (x: x != null) (map (n:
        let h = loaded.${n};
        in if (classMap.${h.class} or null) == cat then { name = n; value = h.value; } else null
      ) (attrNames loaded)));

      result = { nixosConfigurations = byCategory "nixosConfigurations"; darwinConfigurations = byCategory "darwinConfigurations"; };

      autoChecks = system:
        let go = prefix: hosts: listToAttrs (filter (x: x != null) (map (n:
              let s = hosts.${n}.config.nixpkgs.hostPlatform.system or null;
              in if s == system then { name = "${prefix}-${n}"; value = hosts.${n}.config.system.build.toplevel; } else null
            ) (attrNames hosts)));
        in go "nixos" result.nixosConfigurations // go "darwin" result.darwinConfigurations;
    in
    result // { inherit autoChecks; };

  # ── mkFlake ────────────────────────────────────────────────────────

  mkFlake =
    { inputs
    , self ? inputs.self or null
    , src ? (if self != null then self else throw "red-tape: either self or src required")
    , prefix ? null
    , systems ? [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ]
    , nixpkgs ? {}
    , modules ? []
    , perSystem ? null
    , config ? {}
    , flake ? {}
    , moduleTypeAliases ? {}
    }:
    let
      flakeInputs = builtins.removeAttrs inputs [ "self" ];
      allInputs   = flakeInputs // (if self != null then { inherit self; } else {});

      resolvedSrc =
        if prefix != null then
          if isPath prefix then prefix
          else if isString prefix then src + "/${prefix}"
          else throw "red-tape: prefix must be a string or path"
        else src;

      found = discover.discoverAll resolvedSrc;

      # ── Scopes ──
      mkScope = pkgs: system: {
        inherit pkgs system;
        lib = pkgs.lib;
        flake = self;
        inputs = allInputs;
        perSystem = mapAttrs (_: input:
          if isAttrs input
          then (input.legacyPackages.${system} or {}) // (input.packages.${system} or {})
          else input
        ) allInputs;
      };

      agnosticScope = { flake = self; inputs = allInputs; };

      hasCustomNixpkgs = (nixpkgs.config or {}) != {} || (nixpkgs.overlays or []) != [];
      customNixpkgsFor = system: import inputs.nixpkgs {
        inherit system; config = nixpkgs.config or {}; overlays = nixpkgs.overlays or [];
      };

      # ── Per-system ──
      perSystemFromDiscovery = { pkgs, system, ... }:
        let
          p = if hasCustomNixpkgs then customNixpkgsFor system else pkgs;
          scope = mkScope p system;

          packages  = if found.packages  != null then filterPlatforms system (buildAll scope found.packages)  else {};
          devShells = if found.devshells  != null then buildAll scope found.devshells  else {};
          checks    = if found.checks     != null then filterPlatforms system (buildAll scope found.checks) else {};
          formatter = if found.formatter  != null then callFile scope found.formatter {} else p.nixfmt-tree or p.nixfmt
            or (throw "red-tape: no formatter.nix and nixfmt-tree unavailable");

          # Auto-checks: packages + passthru.tests + devshells
          pkgChecks = withPrefix "pkgs-" packages
            // listToAttrs (concatMap (pname:
              let tests = filterPlatforms system (packages.${pname}.passthru.tests or {});
              in map (t: { name = "pkgs-${pname}-${t}"; value = tests.${t}; }) (attrNames tests)
            ) (attrNames packages));
        in {
          inherit packages devShells formatter;
          checks = pkgChecks // withPrefix "devshell-" devShells // checks;
        };

      composedPerSystem =
        if perSystem != null then args:
          let d = perSystemFromDiscovery args; u = perSystem args;
          in d // u // {
            packages  = d.packages  // (u.packages or {});
            devShells = d.devShells // (u.devShells or {});
            checks    = d.checks    // (u.checks or {});
          }
        else perSystemFromDiscovery;

      # ── System-agnostic ──
      overlays  = if found.overlays != null then { overlays = buildAll agnosticScope found.overlays; } else {};
      hosts     = if found.hosts    != null then buildHosts { discovered = found.hosts; inherit flakeInputs self; } else {};
      modExport = if found.modules  != null then buildModules { discovered = found.modules; inherit flakeInputs self; extraTypeAliases = moduleTypeAliases; } else {};

      templates = let t = mapAttrs (name: entry:
          let f = entry.path + "/flake.nix";
          in { inherit (entry) path; description = if pathExists f then (import f).description or name else name; }
        ) found.templates;
        in if t != {} then { inherit templates; } else {};

      libExport = let l =
          if found.lib == null then {}
          else let mod = import found.lib;
          in if isFunction mod then mod { flake = self; inputs = allInputs; } else mod;
        in if l != {} then { lib = l; } else {};

      discoveredFlake =
        overlays // (builtins.removeAttrs hosts [ "autoChecks" ])
        // modExport // templates // libExport;

      composedFlake =
        if isFunction flake then { withSystem }:
          discoveredFlake // flake { inherit withSystem; }
        else discoveredFlake // flake;

      hostAutoChecks = if found.hosts != null then hosts.autoChecks else (_: {});

      finalPerSystem = args @ { pkgs, system, ... }:
        let base = composedPerSystem args;
        in base // { checks = hostAutoChecks system // base.checks; };

    in
    adiosFlakeLib.mkFlake {
      inherit inputs self systems config modules;
      perSystem = finalPerSystem;
      flake = composedFlake;
    };

in
{
  inherit mkFlake;
  _internal = {
    inherit discover callFile buildAll entryPath withPrefix filterPlatforms;
    builders = { inherit buildModules buildHosts; };
  };
}
