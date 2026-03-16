let
  prelude = import ./prelude.nix;
  inherit (prelude) discover fixtures;
  inherit (discover) scanEntries;

  scanPackages = src: scanEntries { dir = src + "/packages"; single = src + "/package.nix"; };
in
{
  testPrefixDiscovery = {
    expr = builtins.sort builtins.lessThan (
      builtins.attrNames (scanPackages (fixtures + "/prefixed/nix"))
    );
    expected = [
      "default"
      "widget"
    ];
  };
  testNoPrefixMissesPackages = {
    expr = scanPackages (fixtures + "/prefixed");
    expected = { };
  };
}
