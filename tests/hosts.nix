# Tests for host building
let
  discover = import ../modules/discover.nix;
  fixtures = ../tests/fixtures;

  # Test with custom escape hatch (doesn't require real nixpkgs.lib.nixosSystem)
  buildHosts = import ../lib/build-hosts.nix {
    flakeInputs = {};
    self = null;
  };

  # Only test the custom host — nixos/darwin need real nixpkgs
  customOnly = buildHosts {
    custom = (discover (fixtures + "/full")).hosts.custom;
  };
in
{
  testCustomHostLoaded = {
    expr = customOnly.nixosConfigurations.custom._type;
    expected = "test-nixos-system";
  };

  testCustomHostName = {
    expr = customOnly.nixosConfigurations.custom.hostName;
    expected = "custom";
  };

  testEmptyHosts = {
    expr = buildHosts {};
    expected = {
      nixosConfigurations = {};
      darwinConfigurations = {};
      systemConfigs = {};
    };
  };

  # Discovery correctly identifies host types
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
      mymac = "darwin";
      custom = "custom";
    };
  };
}
