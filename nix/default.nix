# red-tape — Convention-based Nix project builder on adios-flake
#
# Primary API:
#   red-tape.lib.module { src = self; ... }       — adios-flake module (per-system + flake)
#
# Convenience:
#   red-tape.mkFlake { inherit inputs; }           — full flake via mkFlake wrapper
{ adios-flake }:
let
  inherit (builtins)
    addErrorContext all attrNames concatMap elem filter
    foldl' functionArgs intersectAttrs isAttrs isFunction
    isPath isString listToAttrs map mapAttrs pathExists;

  adiosFlakeLib = adios-flake.lib or adios-flake;
  discover = import ./discover.nix;

  # ── Primitives ─────────────────────────────────────────────────────

  callFile = scope: path: extra:
    addErrorContext "while evaluating '${toString path}'" (
      let fn = import path;
      in fn (intersectAttrs (functionArgs fn) (scope // extra))
    );

  entryPath = e: if e.type == "directory" then e.path + "/default.nix" else e.path;

  buildAll = scope: mapAttrs (pname: e: callFile scope (entryPath e) { inherit pname; });

  withPrefix = pre: a: listToAttrs (map (n: { name = "${pre}${n}"; value = a.${n}; }) (attrNames a));

  filterPlatforms = system: a:
    listToAttrs (filter (x: x != null) (map (n:
      let p = a.${n}.meta.platforms or [];
      in if p == [] || elem system p then { name = n; value = a.${n}; } else null
    ) (attrNames a)));

  # ── Module export ──────────────────────────────────────────────────

  defaultTypeAliases = { nixos = "nixosModules"; darwin = "darwinModules"; home = "homeModules"; };

  buildModules = { discovered, allInputs, self, extraTypeAliases ? {} }:
    let
      publisherArgs = { flake = self; inputs = allInputs; };
      typeAliases = defaultTypeAliases // extraTypeAliases;

      isPublisherFn = fn:
        isFunction fn && (functionArgs fn) != {}
        && all (a: elem a [ "flake" "inputs" ]) (attrNames (functionArgs fn));

      importModule = e:
        let path = entryPath e; mod = import path;
        in if isPublisherFn mod
          then { _file = toString path; imports = [ (mod (intersectAttrs (functionArgs mod) publisherArgs)) ]; }
          else path;

      built = mapAttrs (_: mapAttrs (_: importModule)) discovered;
    in
    foldl' (acc: t:
      let alias = typeAliases.${t} or null;
      in if alias != null then acc // { ${alias} = built.${t}; } else acc
    ) {} (attrNames discovered);

  # ── Host configurations ────────────────────────────────────────────

  buildHosts = { discovered, allInputs, self }:
    let
      specialArgs = { flake = self; inputs = allInputs; };
      outputKey = { nixos = "nixosConfigurations"; nix-darwin = "darwinConfigurations"; };

      loadHost = name: info:
        addErrorContext "while building host '${name}' (${info.type})" (
          if info.type == "custom" then
            import info.configPath { inherit (specialArgs) flake inputs; hostName = name; }
          else if info.type == "nixos" then {
            class = "nixos";
            value = allInputs.nixpkgs.lib.nixosSystem {
              modules = [ info.configPath ];
              specialArgs = specialArgs // { hostName = name; };
            };
          }
          else if info.type == "darwin" then
            let nd = allInputs.nix-darwin or (throw "red-tape: host '${name}' needs inputs.nix-darwin");
            in { class = "nix-darwin"; value = nd.lib.darwinSystem {
              modules = [ info.configPath ];
              specialArgs = specialArgs // { hostName = name; };
            }; }
          else throw "red-tape: unknown host type '${info.type}' for '${name}'"
        );

      loaded = mapAttrs loadHost discovered;

      byClass = cls: listToAttrs (filter (x: x != null) (map (n:
        let h = loaded.${n};
        in if (outputKey.${h.class} or null) == cls then { name = n; value = h.value; } else null
      ) (attrNames loaded)));

      nixos  = byClass "nixosConfigurations";
      darwin = byClass "darwinConfigurations";

      autoChecks = system:
        let check = pre: hosts: listToAttrs (filter (x: x != null) (map (n:
              let s = hosts.${n}.config.nixpkgs.hostPlatform.system or null;
              in if s == system then { name = "${pre}-${n}"; value = hosts.${n}.config.system.build.toplevel; } else null
            ) (attrNames hosts)));
        in check "nixos" nixos // check "darwin" darwin;
    in
    { nixosConfigurations = nixos; darwinConfigurations = darwin; inherit autoChecks; };

  # ── Public API: adios-flake module ─────────────────────────────────
  #
  # Returns a function suitable for use in adios-flake's `modules` list.
  # Discovers all convention-based outputs (packages/, devshells/, checks/,
  # hosts/, modules/, overlays/, templates/, lib/) and returns them as a
  # single attrset. adios-flake's /_collector and /_flake handle routing
  # per-system vs flake-scoped keys automatically.

  module = import ./module.nix {
    inherit discover callFile buildAll filterPlatforms withPrefix
            buildModules buildHosts;
  };

  # ── Convenience: mkFlake wrapper ───────────────────────────────────

  mkFlake =
    { inputs
    , self ? inputs.self or null
    , src ? self
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
      # red-tape's unified module: discovers everything, returns both
      # per-system keys and flake-scoped keys in one attrset
      redTapeModule = module {
        inherit src nixpkgs prefix inputs self;
        moduleTypeAliases = moduleTypeAliases;
      };

    in
    adiosFlakeLib.mkFlake {
      inherit inputs self systems config;
      modules = [ redTapeModule ] ++ modules;
      perSystem = perSystem;
      flake = flake;
    };

in {
  inherit mkFlake module;
  _internal = {
    inherit discover callFile buildAll entryPath withPrefix filterPlatforms;
    builders = { inherit buildModules buildHosts; };
  };
}
