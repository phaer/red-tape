# Tests for prefix support
let
  prelude = import ./prelude.nix;
  inherit (prelude) _internal fixtures;
  inherit (_internal) coreDescriptors;
  discover = src: _internal.discover src coreDescriptors;
in
{
  # Discover sees packages when pointed at the prefix subdirectory
  testPrefixDiscovery = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/prefixed/nix")).packages);
    expected = [ "default" "widget" ];
  };

  # Discover at the wrong root sees nothing
  testNoPrefixMissesPackages = {
    expr = (discover (fixtures + "/prefixed")) ? packages;
    expected = false;
  };
}
