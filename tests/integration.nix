# Integration tests — builders with mock pkgs
let
  prelude = import ./prelude.nix;
  inherit (prelude) mockPkgs sys fixtures _internal;
  inherit (_internal) discover callFile buildAll filterPlatforms withPrefix;

  evalFixture = src:
    let
      found = discover.discoverAll src;
      scope = { pkgs = mockPkgs; system = sys; lib = mockPkgs.lib; };

      packages  = if found.packages  != null then filterPlatforms sys (buildAll scope found.packages)  else {};
      devShells = if found.devshells  != null then buildAll scope found.devshells  else {};
      checks    = if found.checks     != null then filterPlatforms sys (buildAll scope found.checks) else {};
      overlays  = if found.overlays   != null then buildAll { flake = null; inputs = {}; } found.overlays else {};
      formatter = if found.formatter  != null then callFile scope found.formatter {} else mockPkgs.nixfmt-tree;
    in
    { inherit packages devShells checks overlays formatter; };
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

  testSimpleOverlayNames = {
    expr = builtins.attrNames (evalFixture (fixtures + "/simple")).overlays;
    expected = [ "my-overlay" ];
  };

  testOverlayIsFunction = {
    expr = builtins.isFunction (evalFixture (fixtures + "/simple")).overlays.my-overlay;
    expected = true;
  };

  testMinimalNoOverlays = {
    expr = (evalFixture (fixtures + "/minimal")).overlays;
    expected = {};
  };
}
