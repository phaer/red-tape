let
  prelude = import ./prelude.nix;
  inherit (prelude) discover fixtures;
  inherit (discover) optional optionalDefault optionalSingle;

  scanPackages =
    src:
    optionalDefault (src + "/packages")
    // optional (src + "/packages")
    // optionalSingle (src + "/package.nix") "default";
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
