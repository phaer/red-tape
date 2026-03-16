let
  prelude = import ./prelude.nix;
  inherit (prelude)
    discover
    helpers
    builders
    fixtures
    ;
  inherit (helpers) entryPath;
  inherit (builders) buildModules;
  inherit (discover) scanDir scanHosts coreHostTypes;
in
{
  testScanCustomHostType = {
    expr =
      let
        found = scanHosts (fixtures + "/custom-hosts/hosts") [
          {
            type = "nix-on-droid";
            file = "droid-configuration.nix";
          }
        ];
      in
      {
        names = builtins.attrNames found;
        type = found.myphone.type;
      };
    expected = {
      names = [ "myphone" ];
      type = "nix-on-droid";
    };
  };
  testCoreHostTypesIgnoreCustom = {
    expr = scanHosts (fixtures + "/custom-hosts/hosts") coreHostTypes;
    expected = { };
  };
  testScanHostsFirstMatchWins = {
    expr =
      let
        found = scanHosts (fixtures + "/full/hosts") [
          {
            type = "custom";
            file = "default.nix";
          }
          {
            type = "nixos";
            file = "configuration.nix";
          }
        ];
      in
      {
        customType = found.custom.type;
        myhostType = found.myhost.type;
      };
    expected = {
      customType = "custom";
      myhostType = "nixos";
    };
  };
  testScanModuleSubdirs = {
    expr =
      let
        modulesPath = fixtures + "/full/modules";
        entries = builtins.readDir modulesPath;
        types = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);
      in
      builtins.sort builtins.lessThan types;
    expected = [
      "darwin"
      "home"
      "nixos"
    ];
  };
  testUnknownModuleTypeSkipped = {
    expr =
      let
        result = buildModules {
          discovered = {
            flake = scanDir (fixtures + "/full/modules/nixos");
          };
        };
      in
      {
        hasAlias = result ? flakeModules;
        hasHierarchy = result ? modules;
        hierarchyKeys = builtins.attrNames result.modules;
      };
    expected = {
      hasAlias = false;
      hasHierarchy = true;
      hierarchyKeys = [ "flake" ];
    };
  };
  testExtraModuleTypes = {
    expr =
      let
        modulesPath = fixtures + "/custom-modules/modules";
        entries = builtins.readDir modulesPath;
        discovered = builtins.listToAttrs (
          builtins.map (n: {
            name = n;
            value = scanDir (modulesPath + "/${n}");
          }) (builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries))
        );
        result = buildModules {
          inherit discovered;
          extraModuleTypes = {
            flake = "flakeModules";
          };
        };
      in
      {
        keys = builtins.sort builtins.lessThan (builtins.attrNames result);
        modNames = builtins.attrNames (result.flakeModules or { });
      };
    expected = {
      keys = [
        "flakeModules"
        "modules"
      ];
      modNames = [ "mymod" ];
    };
  };
}
