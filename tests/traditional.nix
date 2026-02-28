# Tests for the traditional (non-flake) eval entry point
let
  prelude = import ./prelude.nix;
  inherit (prelude) redTape mockPkgs fixtures;

in
{
  # eval produces packages
  testEvalPackages = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (redTape.eval {
        pkgs = mockPkgs;
        src = fixtures + "/simple";
      }).packages);
    expected = [ "goodbye" "hello" ];
  };

  # eval produces devShells
  testEvalDevshells = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (redTape.eval {
        pkgs = mockPkgs;
        src = fixtures + "/simple";
      }).devShells);
    expected = [ "backend" "default" ];
  };

  # eval provides shell convenience alias
  testEvalShell = {
    expr = (redTape.eval {
      pkgs = mockPkgs;
      src = fixtures + "/simple";
    }).shell != null;
    expected = true;
  };

  # eval on empty fixture
  testEvalEmpty = {
    expr =
      let result = redTape.eval {
        pkgs = mockPkgs;
        src = fixtures + "/empty";
      };
      in {
        packages = result.packages;
        devShells = result.devShells;
      };
    expected = {
      packages = {};
      devShells = {};
    };
  };

  # eval on minimal fixture (package.nix only)
  testEvalMinimal = {
    expr = builtins.attrNames (redTape.eval {
      pkgs = mockPkgs;
      src = fixtures + "/minimal";
    }).packages;
    expected = [ "default" ];
  };
}
