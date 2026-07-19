# Tests for host building
let
  prelude = import ./prelude.nix;
  inherit (prelude)
    discover
    builders
    fixtures
    coreHostTypes
    ;
  inherit (discover) scanHosts;
  inherit (builders) buildHosts;

  fullHosts = scanHosts (fixtures + "/full/hosts") coreHostTypes;

  testResult = buildHosts {
    discovered = { inherit (fullHosts) custom; };
  };

  homeManager = (import ../contrib/home-manager.nix).impl { };
  homeHostTypes = coreHostTypes ++ homeManager.scanHostTypes;
  homeHosts = scanHosts (fixtures + "/home/hosts") homeHostTypes;

  homeResult = buildHosts {
    discovered = homeHosts;
    inputs = {
      home-manager = {
        lib.homeManagerConfiguration = args: args;
      };
    };
    extraHostTypes = homeManager.hostTypes;
    defaultSystem = "x86_64-linux";
  };
in
{
  testCustomHostLoaded = {
    expr = testResult.nixosConfigurations.custom.value._type;
    expected = "test-nixos-system";
  };

  testCustomHostName = {
    expr = testResult.nixosConfigurations.custom.value.hostName;
    expected = "custom";
  };

  testEmptyHosts = {
    expr =
      let
        result = buildHosts { discovered = { }; };
      in
      {
        hasAutoChecks = builtins.isFunction result.autoChecks;
        noOutputKeys = builtins.attrNames (builtins.removeAttrs result [ "autoChecks" ]);
      };
    expected = {
      hasAutoChecks = true;
      noOutputKeys = [ ];
    };
  };

  testHostDiscoveryTypes = {
    expr =
      let
        hosts = scanHosts (fixtures + "/full/hosts") coreHostTypes;
      in
      {
        myhost = hosts.myhost.type;
        custom = hosts.custom.type;
      };
    expected = {
      myhost = "nixos";
      custom = "custom";
    };
  };

  testHomeConfigurationGetsDefaultPkgs = {
    expr = homeResult.homeConfigurations.alice.pkgs.system;
    expected = "x86_64-linux";
  };

  testHomeConfigurationSystemOverride = {
    expr = homeResult.homeConfigurations.bob.pkgs.system;
    expected = "aarch64-darwin";
  };

  testHomeConfigurationOutputKey = {
    expr = builtins.attrNames homeResult.homeConfigurations;
    expected = [
      "alice"
      "bob"
    ];
  };
}
