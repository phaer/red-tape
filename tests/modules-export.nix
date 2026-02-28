# Tests for module export via adios module
let
  prelude = import ./prelude.nix;
  inherit (prelude) adios _internal fixtures;
  inherit (_internal) discover;

  evalModulesExport = discoveredModules:
    let
      loaded = adios {
        name = "modexp-test";
        modules.modules-export = _internal.modules.modModulesExport;
      };
      evaled = loaded {
        options."/modules-export" = {
          discovered = discoveredModules;
          flakeInputs = {};
          self = null;
        };
      };
    in
    evaled.modules.modules-export {};

  full = evalModulesExport (discover (fixtures + "/full")).modules;
  empty = evalModulesExport (discover (fixtures + "/empty")).modules;
in
{
  testOutputKeys = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames full);
    expected = [ "darwinModules" "homeModules" "nixosModules" ];
  };

  testNixosModuleNames = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames full.nixosModules);
    expected = [ "injected" "server" ];
  };

  testHomeModuleNames = {
    expr = builtins.attrNames full.homeModules;
    expected = [ "shared" ];
  };

  testDarwinModuleNames = {
    expr = builtins.attrNames full.darwinModules;
    expected = [ "defaults" ];
  };

  testPlainModuleIsPath = {
    expr = builtins.isPath full.nixosModules.server;
    expected = true;
  };

  testInjectedModuleIsFunction = {
    expr = builtins.isFunction full.nixosModules.injected;
    expected = true;
  };

  testEmptyModules = {
    expr = empty;
    expected = {};
  };
}
