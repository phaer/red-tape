# Tests for lib export
let
  prelude = import ./prelude.nix;
  inherit (prelude) _internal fixtures;
  inherit (_internal) discover;
in
{
  testLibPresent = {
    expr = (discover (fixtures + "/full")).lib != null;
    expected = true;
  };

  testLibImport = {
    expr =
      let
        libPath = (discover (fixtures + "/full")).lib;
        lib = import libPath { flake = null; inputs = {}; };
      in
      lib.greet "world";
    expected = "Hello, world!";
  };

  testNoLib = {
    expr = (discover (fixtures + "/empty")).lib;
    expected = null;
  };

  # Plain attrset lib (no { flake, inputs } wrapper)
  testPlainLib = {
    expr =
      let
        libPath = (discover (fixtures + "/plain-lib")).lib;
        lib = import libPath;
      in
      lib.add 1 2;
    expected = 3;
  };
}
