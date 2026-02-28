# Integration tests — full tree evaluation with mock pkgs
let
  prelude = import ./prelude.nix;
  inherit (prelude) adios mockPkgs sys fixtures;

  discover = import ../modules/discover.nix;
  filterPlatforms = import ../lib/filter-platforms.nix;

  callMod = path: import path adios;

  # Build modules conditionally, same as mk-red-tape.nix
  mkModules = discovered:
    { nixpkgs   = callMod ../modules/nixpkgs.nix;
      formatter = callMod ../modules/formatter.nix;
    }
    // (if discovered.packages != {} then { packages  = callMod ../modules/packages.nix; } else {})
    // (if discovered.devshells != {} then { devshells = callMod ../modules/devshells.nix; } else {})
    // (if discovered.checks != {} then { checks = callMod ../modules/checks.nix; } else {});

  mkOptions = discovered:
    { "/nixpkgs" = { system = sys; pkgs = mockPkgs; };
      "/formatter" = { formatterPath = discovered.formatter; };
    }
    // (if discovered.packages != {} then { "/packages" = { discovered = discovered.packages; }; } else {})
    // (if discovered.devshells != {} then { "/devshells" = { discovered = discovered.devshells; }; } else {})
    // (if discovered.checks != {} then { "/checks" = { discovered = discovered.checks; }; } else {});

  evalFixture = src:
    let
      discovered = discover src;
      modules = mkModules discovered;
      loaded = adios { name = "test"; inherit modules; };
      evaled = loaded.eval { options = mkOptions discovered; };
      mods = evaled.root.modules;

      pkgResult = if mods ? packages  then mods.packages {}  else { filteredPackages = {}; };
      devResult = if mods ? devshells then mods.devshells {}  else { devShells = {}; };
      fmtResult = mods.formatter {};
      chkResult = if mods ? checks    then mods.checks {}    else { checks = {}; };
    in
    {
      packages = pkgResult.filteredPackages;
      devShells = devResult.devShells;
      formatter = fmtResult.formatter;
      checks = chkResult.checks;
      # Expose which modules are in the tree
      moduleNames = builtins.sort builtins.lessThan (builtins.attrNames modules);
    };

in
{
  testSimplePackageNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (evalFixture (fixtures + "/simple")).packages);
    expected = [ "goodbye" "hello" ];
  };

  testSimpleDevshellNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (evalFixture (fixtures + "/simple")).devShells);
    expected = [ "backend" "default" ];
  };

  testSimpleUserChecks = {
    expr = builtins.attrNames (evalFixture (fixtures + "/simple")).checks;
    expected = [ "mycheck" ];
  };

  testSimpleFormatter = {
    expr = (evalFixture (fixtures + "/simple")).formatter != null;
    expected = true;
  };

  testMinimalPackage = {
    expr = builtins.attrNames (evalFixture (fixtures + "/minimal")).packages;
    expected = [ "default" ];
  };

  # Empty fixture: only nixpkgs + formatter modules in tree
  testEmptyOutputs = {
    expr =
      let result = evalFixture (fixtures + "/empty");
      in {
        packages = result.packages;
        devShells = result.devShells;
        checks = result.checks;
      };
    expected = {
      packages = {};
      devShells = {};
      checks = {};
    };
  };

  testEmptyModulesMinimal = {
    expr = (evalFixture (fixtures + "/empty")).moduleNames;
    expected = [ "formatter" "nixpkgs" ];
  };

  # Simple fixture has all modules
  testSimpleModulesPresent = {
    expr = (evalFixture (fixtures + "/simple")).moduleNames;
    expected = [ "checks" "devshells" "formatter" "nixpkgs" "packages" ];
  };

  # Minimal fixture only has packages + formatter
  testMinimalModulesPresent = {
    expr = (evalFixture (fixtures + "/minimal")).moduleNames;
    expected = [ "formatter" "nixpkgs" "packages" ];
  };

  # Memoization: override /nixpkgs for second system
  testMemoization = {
    expr =
      let
        src = fixtures + "/simple";
        discovered = discover src;
        modules = mkModules discovered;
        loaded = adios { name = "test"; inherit modules; };
        evaled = loaded.eval { options = mkOptions discovered; };
        result1 = evaled.root.modules.packages {};

        mockPkgs2 = mockPkgs // { system = "aarch64-linux"; };
        evaled2 = evaled.override {
          options = mkOptions discovered // {
            "/nixpkgs" = { system = "aarch64-linux"; pkgs = mockPkgs2; };
          };
        };
        result2 = evaled2.root.modules.packages {};
      in
      {
        sys1 = builtins.sort builtins.lessThan (builtins.attrNames result1.filteredPackages);
        sys2 = builtins.sort builtins.lessThan (builtins.attrNames result2.filteredPackages);
      };
    expected = {
      sys1 = [ "goodbye" "hello" ];
      sys2 = [ "goodbye" "hello" ];
    };
  };
}
