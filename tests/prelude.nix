# Test prelude — shared setup for all test files
#
# Provides adios, the red-tape library, and a mock nixpkgs.
let
  sources = import ../npins;
  adiosAll = import sources.adios;
  adios = adiosAll.adios;

  redTape = import ../lib/mk-red-tape.nix { inherit adios; };

  # For unit tests that don't need real packages, we use a mock pkgs.
  # For integration tests that build derivations, use real nixpkgs.
  realPkgs = import sources.nixpkgs { system = "x86_64-linux"; };

  # Minimal mock pkgs for pure tests (no derivation building)
  mockPkgs = {
    system = "x86_64-linux";
    lib = realPkgs.lib;
    # Enough to satisfy callPackage patterns
    mkShell = args: { type = "devshell"; } // args;
    hello = { type = "derivation"; name = "hello"; meta = {}; };
    writeShellScriptBin = name: text: {
      type = "derivation";
      inherit name;
      meta = {};
    };
    runCommand = name: env: cmd: {
      type = "derivation";
      inherit name;
      meta = {};
    };
    nodejs = { type = "derivation"; name = "nodejs"; meta = {}; };
    nixfmt-tree = { type = "derivation"; name = "nixfmt-tree"; meta = {}; };
  };

  sys = "x86_64-linux";

  fixtures = ../tests/fixtures;
in
{
  inherit adios redTape realPkgs mockPkgs sys fixtures;
  types = adios.types;
}
