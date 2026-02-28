# /hosts — System-agnostic host configuration builder
#
# No /nixpkgs dependency — each host determines its own system.
# Evaluated once by adios, memoized across system overrides.
#
# Dispatches by filename convention:
#   configuration.nix        → nixosConfigurations (via nixpkgs.lib.nixosSystem)
#   darwin-configuration.nix → darwinConfigurations (via nix-darwin.lib.darwinSystem)
#   default.nix              → escape hatch (returns { class, value })

{ types, ... }:
let
  inherit (builtins)
    addErrorContext
    attrNames
    filter
    listToAttrs
    mapAttrs
    ;

  classMap = {
    "nixos" = "nixosConfigurations";
    "nix-darwin" = "darwinConfigurations";
  };
in
{
  name = "hosts";

  # No inputs — system-independent

  options = {
    discovered = {
      type = types.attrs;
      default = {};
    };
    flakeInputs = {
      type = types.attrs;
      default = {};
    };
    self = {
      type = types.any;
      default = null;
    };
  };

  impl = { options, ... }:
    let
      flakeInputs = options.flakeInputs;
      self = options.self;
      allInputs = flakeInputs // (if self != null then { self = self; } else {});

      specialArgs = {
        flake = self;
        inputs = allInputs;
      };

      loadHost = hostName: hostInfo:
        addErrorContext "while building host '${hostName}' (${hostInfo.type})" (
          if hostInfo.type == "custom" then
            import hostInfo.configPath {
              inherit (specialArgs) flake inputs;
              inherit hostName;
            }
          else if hostInfo.type == "nixos" then {
            class = "nixos";
            value = flakeInputs.nixpkgs.lib.nixosSystem {
              modules = [ hostInfo.configPath ];
              specialArgs = specialArgs // { inherit hostName; };
            };
          }
          else if hostInfo.type == "darwin" then
            let
              nix-darwin = flakeInputs.nix-darwin
                or (throw "red-tape: host '${hostName}' uses darwin-configuration.nix but inputs.nix-darwin is missing");
            in {
              class = "nix-darwin";
              value = nix-darwin.lib.darwinSystem {
                modules = [ hostInfo.configPath ];
                specialArgs = specialArgs // { inherit hostName; };
              };
            }
          else
            throw "red-tape: unknown host config type '${hostInfo.type}' for '${hostName}'"
        );

      loaded = mapAttrs loadHost options.discovered;

      mkCategory = category:
        listToAttrs (filter (x: x != null)
          (map (name:
            let host = loaded.${name};
            in
            if (classMap.${host.class} or null) == category then
              { inherit name; value = host.value; }
            else
              null
          ) (attrNames loaded)));
    in
    {
      nixosConfigurations = mkCategory "nixosConfigurations";
      darwinConfigurations = mkCategory "darwinConfigurations";
    };
}
