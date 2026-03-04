# contrib/darwin.nix — nix-darwin host + module support
# https://github.com/LnL7/nix-darwin
{
  name = "darwin";
  impl =
    { ... }:
    {
      scanHostTypes = [
        {
          type = "darwin";
          file = "darwin-configuration.nix";
        }
      ];
      hostTypes.darwin = {
        outputKey = "darwinConfigurations";
        build =
          {
            name,
            info,
            specialArgs,
            inputs,
          }:
          let
            nd = inputs.nix-darwin or (throw "red-tape: darwin contrib needs inputs.nix-darwin");
          in
          nd.lib.darwinSystem {
            modules = [ info.configPath ];
            specialArgs = specialArgs // {
              hostName = name;
            };
          };
      };
      moduleTypes = {
        darwin = "darwinModules";
      };
    };
}
