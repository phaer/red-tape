# Tests for prefix support
let
  discover = import ../modules/discover.nix;
  fixtures = ../tests/fixtures;
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
    expr = (discover (fixtures + "/prefixed")).packages;
    expected = {};
  };
}
