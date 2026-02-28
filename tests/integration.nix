# Integration tests — full tree evaluation with mock pkgs
let
  prelude = import ./prelude.nix;
  inherit (prelude) adios mockPkgs sys fixtures;

  discover = import ../modules/discover.nix;
  filterPlatforms = import ../lib/filter-platforms.nix;

  callMod = path: import path adios;

  rootModules = {
    nixpkgs   = callMod ../modules/nixpkgs.nix;
    packages  = callMod ../modules/packages.nix;
    devshells = callMod ../modules/devshells.nix;
    formatter = callMod ../modules/formatter.nix;
    checks    = callMod ../modules/checks.nix;
  };

  # Evaluate the full tree for a fixture, call modules, return results
  evalFixture = src:
    let
      discovered = discover src;
      loaded = adios { name = "test"; modules = rootModules; };
      evaled = loaded.eval {
        options = {
          "/nixpkgs" = { system = sys; pkgs = mockPkgs; };
          "/packages" = { discovered = discovered.packages; };
          "/devshells" = { discovered = discovered.devshells; };
          "/formatter" = { formatterPath = discovered.formatter; };
          "/checks" = { discovered = discovered.checks; };
        };
      };
      mods = evaled.root.modules;
      pkgResult = mods.packages {};
      devResult = mods.devshells {};
      fmtResult = mods.formatter {};
      chkResult = mods.checks {};
    in
    {
      packages = pkgResult.filteredPackages;
      devShells = devResult.devShells;
      formatter = fmtResult.formatter;
      checks = chkResult.checks;
    };

in
{
  # Simple fixture produces expected package names
  testSimplePackageNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (evalFixture (fixtures + "/simple")).packages);
    expected = [ "goodbye" "hello" ];
  };

  # Simple fixture produces expected devshell names
  testSimpleDevshellNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (evalFixture (fixtures + "/simple")).devShells);
    expected = [ "backend" "default" ];
  };

  # User-defined checks are found
  testSimpleUserChecks = {
    expr = builtins.attrNames (evalFixture (fixtures + "/simple")).checks;
    expected = [ "mycheck" ];
  };

  # Formatter is present
  testSimpleFormatter = {
    expr = (evalFixture (fixtures + "/simple")).formatter != null;
    expected = true;
  };

  # Minimal fixture with just package.nix
  testMinimalPackage = {
    expr = builtins.attrNames (evalFixture (fixtures + "/minimal")).packages;
    expected = [ "default" ];
  };

  # Empty fixture produces empty outputs
  testEmpty = {
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

  # Memoization: override /nixpkgs for second system
  testMemoization = {
    expr =
      let
        src = fixtures + "/simple";
        discovered = discover src;
        loaded = adios { name = "test"; modules = rootModules; };
        evaled = loaded.eval {
          options = {
            "/nixpkgs" = { system = "x86_64-linux"; pkgs = mockPkgs; };
            "/packages" = { discovered = discovered.packages; };
            "/devshells" = { discovered = discovered.devshells; };
            "/formatter" = { formatterPath = discovered.formatter; };
            "/checks" = { discovered = discovered.checks; };
          };
        };

        result1 = evaled.root.modules.packages {};

        # Override for a different "system"
        mockPkgs2 = mockPkgs // { system = "aarch64-linux"; };
        evaled2 = evaled.override {
          options = {
            "/nixpkgs" = { system = "aarch64-linux"; pkgs = mockPkgs2; };
            "/packages" = { discovered = discovered.packages; };
            "/devshells" = { discovered = discovered.devshells; };
            "/formatter" = { formatterPath = discovered.formatter; };
            "/checks" = { discovered = discovered.checks; };
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
