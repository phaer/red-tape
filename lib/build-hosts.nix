# build-hosts.nix — Build host configurations from discovered hosts
#
# Returns: { nixosConfigurations, darwinConfigurations, systemConfigs }
# Each is { hostname = configValue; }
#
# Host configs receive { flake, inputs, hostName, perSystem } via specialArgs.
# This function is called by the entry point, not inside an adios module.

{ flakeInputs, self }:

let
  inherit (builtins)
    attrNames
    filter
    listToAttrs
    mapAttrs
    ;

  specialArgs = {
    inherit (flakeInputs) nixpkgs;
    flake = self;
    inputs = flakeInputs // (if self != null then { self = self; } else {});
  };

  loadHost = hostName: hostInfo:
    if hostInfo.type == "custom" then
      import hostInfo.path {
        inherit (specialArgs) flake inputs;
        inherit hostName;
      }
    else if hostInfo.type == "nixos" then {
      class = "nixos";
      value = flakeInputs.nixpkgs.lib.nixosSystem {
        modules = [ hostInfo.path ];
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
          modules = [ hostInfo.path ];
          specialArgs = specialArgs // { inherit hostName; };
        };
      }
    else if hostInfo.type == "system-manager" then
      let
        system-manager = flakeInputs.system-manager
          or (throw "red-tape: host '${hostName}' uses system-configuration.nix but inputs.system-manager is missing");
      in {
        class = "system-manager";
        value = system-manager.lib.makeSystemConfig {
          modules = [ hostInfo.path ];
          extraSpecialArgs = specialArgs // { inherit hostName; };
        };
      }
    else if hostInfo.type == "rpi" then
      let
        nixos-raspberrypi = flakeInputs.nixos-raspberrypi
          or (throw "red-tape: host '${hostName}' uses rpi-configuration.nix but inputs.nixos-raspberrypi is missing");
      in {
        class = "nixos";
        value = nixos-raspberrypi.lib.nixosSystem {
          modules = [ hostInfo.path ];
          specialArgs = specialArgs // { inherit hostName; };
        };
      }
    else if hostInfo.type == "home-only" then
      # No host configuration, only home-manager users (standalone)
      null
    else
      throw "red-tape: unknown host config type '${hostInfo.type}' for '${hostName}'";

  # Classify by output category
  classMap = {
    "nixos" = "nixosConfigurations";
    "nix-darwin" = "darwinConfigurations";
    "system-manager" = "systemConfigs";
  };

in
discoveredHosts:
let
  loaded = mapAttrs loadHost discoveredHosts;

  # Filter out nulls (home-only hosts)
  nonNull = listToAttrs (filter (x: x.value != null)
    (map (name: { inherit name; value = loaded.${name}; }) (attrNames loaded)));

  # Group by class
  mkCategory = category:
    listToAttrs (filter (x: x != null)
      (map (name:
        let host = nonNull.${name};
        in
        if (classMap.${host.class} or null) == category then
          { inherit name; value = host.value; }
        else
          null
      ) (attrNames nonNull)));
in
{
  nixosConfigurations = mkCategory "nixosConfigurations";
  darwinConfigurations = mkCategory "darwinConfigurations";
  systemConfigs = mkCategory "systemConfigs";
}
