# Integration tests — full tree evaluation with mock pkgs
let
  prelude = import ./prelude.nix;
  inherit (prelude) adios mockPkgs sys fixtures _internal;
  inherit (_internal) discover filterPlatforms;
  mods = _internal.modules;

  mkModules = discovered:
    { nixpkgs = mods.modNixpkgs; formatter = mods.modFormatter; }
    // (if discovered.packages  != {} then { packages  = mods.modPackages; }  else {})
    // (if discovered.devshells != {} then { devshells = mods.modDevshells; } else {})
    // (if discovered.checks    != {} then { checks    = mods.modChecks; }    else {})
    // (if discovered.overlays  != {} then { overlays  = mods.modOverlays; }  else {});

  mkOptions = discovered:
    { "/nixpkgs"   = { system = sys; pkgs = mockPkgs; };
      "/formatter" = { formatterPath = discovered.formatter; };
    }
    // (if discovered.packages  != {} then { "/packages"  = { discovered = discovered.packages; }; }  else {})
    // (if discovered.devshells != {} then { "/devshells" = { discovered = discovered.devshells; }; } else {})
    // (if discovered.checks    != {} then { "/checks"    = { discovered = discovered.checks; }; }    else {})
    // (if discovered.overlays  != {} then { "/overlays"  = { discovered = discovered.overlays; }; }  else {});

  evalFixture = src:
    let
      discovered = discover src;
      modules = mkModules discovered;
      loaded = adios { name = "test"; inherit modules; };
      evaled = loaded { options = mkOptions discovered; };
      ms = evaled.modules;

      pkgResult = if ms ? packages  then ms.packages {}  else { filteredPackages = {}; };
      devResult = if ms ? devshells then ms.devshells {}  else { devShells = {}; };
      fmtResult = ms.formatter {};
      chkResult = if ms ? checks    then ms.checks {}     else { checks = {}; };
      ovlResult = if ms ? overlays  then ms.overlays {}   else { overlays = {}; };
    in
    {
      packages = pkgResult.filteredPackages;
      devShells = devResult.devShells;
      formatter = fmtResult.formatter;
      checks = chkResult.checks;
      overlays = ovlResult.overlays;
      moduleNames = builtins.sort builtins.lessThan (builtins.attrNames modules);
    };

in
{
  testSimplePackageNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (evalFixture (fixtures + "/simple")).packages);
    expected = [ "goodbye" "hello" ];
  };

  testPackageType = {
    expr = (evalFixture (fixtures + "/simple")).packages.hello.type;
    expected = "derivation";
  };

  testDevshellNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (evalFixture (fixtures + "/simple")).devShells);
    expected = [ "backend" "default" ];
  };

  testSimpleFormatter = {
    expr = (evalFixture (fixtures + "/simple")).formatter != null;
    expected = true;
  };

  testFormatterFallback = {
    expr = (evalFixture (fixtures + "/minimal")).formatter.name;
    expected = "nixfmt-tree";
  };

  testCheckNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (evalFixture (fixtures + "/simple")).checks);
    expected = [ "mycheck" ];
  };

  # Conditional modules: minimal fixture has only nixpkgs + formatter
  testMinimalModules = {
    expr = (evalFixture (fixtures + "/minimal")).moduleNames;
    expected = [ "formatter" "nixpkgs" "packages" ];
  };

  # Simple fixture has packages, devshells, checks, overlays
  testSimpleModules = {
    expr = (evalFixture (fixtures + "/simple")).moduleNames;
    expected = [ "checks" "devshells" "formatter" "nixpkgs" "overlays" "packages" ];
  };

  # Empty fixture has only nixpkgs + formatter
  testEmptyModules = {
    expr = (evalFixture (fixtures + "/empty")).moduleNames;
    expected = [ "formatter" "nixpkgs" ];
  };

  # Overlay names from simple fixture
  testSimpleOverlayNames = {
    expr = builtins.attrNames (evalFixture (fixtures + "/simple")).overlays;
    expected = [ "my-overlay" ];
  };

  # Overlay is a function (final: prev: { ... })
  testOverlayIsFunction = {
    expr = builtins.isFunction (evalFixture (fixtures + "/simple")).overlays.my-overlay;
    expected = true;
  };

  # No overlays in minimal
  testMinimalNoOverlays = {
    expr = (evalFixture (fixtures + "/minimal")).overlays;
    expected = {};
  };

  # Memoization: override /nixpkgs for second system
  testMemoization = {
    expr =
      let
        src = fixtures + "/simple";
        discovered = discover src;
        modules = mkModules discovered;
        loaded = adios { name = "test"; inherit modules; };
        evaled = loaded { options = mkOptions discovered; };
        result1 = evaled.modules.packages {};

        mockPkgs2 = mockPkgs // { system = "aarch64-linux"; };
        evaled2 = evaled.override {
          options = mkOptions discovered // {
            "/nixpkgs" = { system = "aarch64-linux"; pkgs = mockPkgs2; };
          };
        };
        result2 = evaled2.modules.packages {};
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
