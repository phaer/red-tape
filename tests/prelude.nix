# Test prelude — shared setup for all test files
let
  sources = import ../npins;
  adiosAll = import sources.adios;
  adios = adiosAll.adios;

  redTape = import ../. {};
  inherit (redTape) _internal;

  realPkgs = import sources.nixpkgs { system = "x86_64-linux"; };

  mockPkgs = {
    system = "x86_64-linux";
    lib = realPkgs.lib;
    mkShell = args: { type = "devshell"; } // args;
    hello = { type = "derivation"; name = "hello"; meta = {}; };
    writeShellScriptBin = name: text: {
      type = "derivation"; inherit name; meta = {};
    };
    runCommand = name: env: cmd: {
      type = "derivation"; inherit name; meta = {};
    };
    nodejs = { type = "derivation"; name = "nodejs"; meta = {}; };
    nixfmt-tree = { type = "derivation"; name = "nixfmt-tree"; meta = {}; };
  };

  sys = "x86_64-linux";
  fixtures = ../tests/fixtures;
in
{
  inherit adios redTape realPkgs mockPkgs sys fixtures _internal;
  types = adios.types;
}
