# Tests for lib export
let
  discover = import ../modules/discover.nix;
  fixtures = ../tests/fixtures;
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
}
