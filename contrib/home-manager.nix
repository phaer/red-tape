# contrib/home-manager.nix — home-manager host + module support
# https://github.com/nix-community/home-manager
{
  name = "home-manager";
  impl =
    { ... }:
    {
      scanHostTypes = [
        {
          type = "home-manager";
          file = "home-configuration.nix";
        }
      ];
      hostTypes.home-manager = {
        outputKey = "homeConfigurations";
        build =
          {
            name,
            info,
            specialArgs,
            inputs,
          }:
          let
            hm = inputs.home-manager or (throw "red-tape: home-manager contrib needs inputs.home-manager");
          in
          hm.lib.homeManagerConfiguration {
            modules = [ info.configPath ];
            extraSpecialArgs = specialArgs // {
              hostName = name;
            };
          };
      };
      moduleTypes = {
        home = "homeModules";
      };
    };
}
