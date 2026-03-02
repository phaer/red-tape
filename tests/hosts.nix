# Tests for host building via adios module
let
  prelude = import ./prelude.nix;
  inherit (prelude) adios _internal fixtures;
  inherit (_internal) coreDescriptors;
  discover = src: _internal.discover src coreDescriptors;

  fullHosts = (discover (fixtures + "/full")).hosts;

  evalHosts = discoveredHosts:
    let
      loaded = adios {
        name = "hosts-test";
        modules.hosts = _internal.modules.modHosts;
      };
      evaled = loaded {
        options."/hosts" = {
          discovered = discoveredHosts;
          flakeInputs = {};
          self = null;
        };
      };
    in
    evaled.modules.hosts {};

  testResult = evalHosts {
    inherit (fullHosts) custom mymac;
  };
in
{
  testCustomHostLoaded = {
    expr = testResult.nixosConfigurations.custom._type;
    expected = "test-nixos-system";
  };

  testCustomHostName = {
    expr = testResult.nixosConfigurations.custom.hostName;
    expected = "custom";
  };

  testDarwinHostLoaded = {
    expr = testResult.darwinConfigurations.mymac._type;
    expected = "test-darwin-system";
  };

  testDarwinHostName = {
    expr = testResult.darwinConfigurations.mymac.hostName;
    expected = "mymac";
  };

  testDarwinNotInNixos = {
    expr = testResult.nixosConfigurations ? mymac;
    expected = false;
  };

  testNixosNotInDarwin = {
    expr = testResult.darwinConfigurations ? custom;
    expected = false;
  };

  testEmptyHosts = {
    expr = evalHosts {};
    expected = {
      nixosConfigurations = {};
      darwinConfigurations = {};
    };
  };

  testHostDiscoveryTypes = {
    expr =
      let hosts = (discover (fixtures + "/full")).hosts;
      in {
        myhost = hosts.myhost.type;
        mymac = hosts.mymac.type;
        custom = hosts.custom.type;
      };
    expected = {
      myhost = "nixos";
      mymac = "custom";
      custom = "custom";
    };
  };
}
