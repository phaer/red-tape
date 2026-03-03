let
  prelude = import ./prelude.nix;
  inherit (prelude) discover fixtures;
in
{
  testPrefixDiscovery = {
    expr = builtins.sort builtins.lessThan (
      builtins.attrNames (discover.discoverAll (fixtures + "/prefixed/nix")).packages
    );
    expected = [
      "default"
      "widget"
    ];
  };
  testNoPrefixMissesPackages = {
    expr = (discover.discoverAll (fixtures + "/prefixed")).packages;
    expected = { };
  };
}
