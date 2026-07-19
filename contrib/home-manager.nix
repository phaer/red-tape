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
            system,
            pkgsFor,
          }:
          let
            hm = inputs.home-manager or (throw "red-tape: home-manager contrib needs inputs.home-manager");
            # home-manager can't infer the platform like nixosSystem; pass concrete pkgs.
            systemFile = info.hostPath + "/system.nix";
            hostSystem = if builtins.pathExists systemFile then import systemFile else system;
          in
          hm.lib.homeManagerConfiguration {
            pkgs = pkgsFor hostSystem;
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
