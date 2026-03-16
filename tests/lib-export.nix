# Tests for lib export
let
  prelude = import ./prelude.nix;
  inherit (prelude) fixtures;
  inherit (builtins) pathExists;

  scanLib =
    src:
    let
      p = src + "/lib/default.nix";
    in
    if pathExists p then p else null;

  importLib =
    libPath: args:
    if libPath == null then
      { }
    else
      let
        mod = import libPath;
      in
      if builtins.isFunction mod then mod args else mod;
in
{
  testLibPresent = {
    expr = (scanLib (fixtures + "/full")) != null;
    expected = true;
  };

  testLibImport = {
    expr =
      let
        libPath = scanLib (fixtures + "/full");
        lib = importLib libPath {
          flake = null;
          inputs = { };
        };
      in
      lib.greet "world";
    expected = "Hello, world!";
  };

  testNoLib = {
    expr = scanLib (fixtures + "/empty");
    expected = null;
  };

  testPlainLib = {
    expr =
      let
        libPath = scanLib (fixtures + "/plain-lib");
        lib = importLib libPath { };
      in
      lib.add 1 2;
    expected = 3;
  };
}
