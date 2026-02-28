# Tests for the discover function (modules/discover.nix)
let
  fixtures = ../tests/fixtures;
  discover = import ../modules/discover.nix;
in
{
  # Discovers packages from both .nix files and directories
  testDiscoverPackages = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/simple")).packages);
    expected = [ "goodbye" "hello" ];
  };

  # Discovers package.nix as "default"
  testDiscoverPackageNix = {
    expr = builtins.attrNames (discover (fixtures + "/minimal")).packages;
    expected = [ "default" ];
  };

  # Discovers devshells (named + default)
  testDiscoverDevshells = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (discover (fixtures + "/simple")).devshells);
    expected = [ "backend" "default" ];
  };

  # Discovers formatter
  testDiscoverFormatter = {
    expr = (discover (fixtures + "/simple")).formatter != null;
    expected = true;
  };

  # Discovers checks
  testDiscoverChecks = {
    expr = builtins.attrNames (discover (fixtures + "/simple")).checks;
    expected = [ "mycheck" ];
  };

  # Empty project has no discoveries
  testDiscoverEmpty = {
    expr =
      let result = discover (fixtures + "/empty");
      in {
        packages = result.packages;
        devshells = result.devshells;
        checks = result.checks;
        formatter = result.formatter;
      };
    expected = {
      packages = {};
      devshells = {};
      checks = {};
      formatter = null;
    };
  };

  # No formatter returns null
  testNoFormatter = {
    expr = (discover (fixtures + "/minimal")).formatter;
    expected = null;
  };
}
