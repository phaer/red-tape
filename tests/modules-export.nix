# Tests for module export
let
  buildModules = import ../lib/build-modules.nix {
    flakeInputs = {};
    self = null;
  };
  discover = import ../modules/discover.nix;
  fixtures = ../tests/fixtures;

  full = buildModules (discover (fixtures + "/full")).modules;
  empty = buildModules (discover (fixtures + "/empty")).modules;
in
{
  # modules.<type>.<name> structure
  testModuleTypes = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames full.modules);
    expected = [ "darwin" "home" "nixos" ];
  };

  testNixosModuleNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames full.modules.nixos);
    expected = [ "injected" "server" ];
  };

  testHomeModuleNames = {
    expr = builtins.attrNames full.modules.home;
    expected = [ "shared" ];
  };

  testDarwinModuleNames = {
    expr = builtins.attrNames full.modules.darwin;
    expected = [ "defaults" ];
  };

  # Well-known aliases
  testNixosModulesAlias = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames full.nixosModules);
    expected = [ "injected" "server" ];
  };

  testDarwinModulesAlias = {
    expr = builtins.attrNames full.darwinModules;
    expected = [ "defaults" ];
  };

  testHomeModulesAlias = {
    expr = builtins.attrNames full.homeModules;
    expected = [ "shared" ];
  };

  # Plain modules (no publisher args) are re-exported as paths
  testPlainModuleIsPath = {
    expr = builtins.isPath full.modules.nixos.server;
    expected = true;
  };

  # Publisher-args modules are called and return a function (the inner module)
  testInjectedModuleIsFunction = {
    expr = builtins.isFunction full.modules.nixos.injected;
    expected = true;
  };

  # Empty project
  testEmptyModules = {
    expr = empty.modules;
    expected = {};
  };
}
