# Integration tests — builders with mock pkgs
let
  prelude = import ./prelude.nix;
  inherit (prelude)
    mockPkgs
    sys
    fixtures
    discover
    helpers
    ;
  inherit (helpers)
    callFile
    buildAll
    filterPlatforms
    withPrefix
    ;

  sort = builtins.sort builtins.lessThan;
  names = builtins.attrNames;

  evalFixture =
    src:
    let
      found = discover.discoverAll src;
      scope = {
        pkgs = mockPkgs;
        system = sys;
        lib = mockPkgs.lib;
      };
      packages = filterPlatforms sys (buildAll scope found.packages);
      devShells = buildAll scope found.devshells;
      checks = filterPlatforms sys (buildAll scope found.checks);
      formatter =
        if found.formatter != null then callFile scope found.formatter { } else mockPkgs.nixfmt-tree;
    in
    {
      inherit
        packages
        devShells
        checks
        formatter
        ;
    };

  full = evalFixture (fixtures + "/full");
  minimal = evalFixture (fixtures + "/minimal");
in
{
  # --- Packages ---

  testFullPackageNames = {
    expr = sort (names full.packages);
    expected = [
      "goodbye"
      "hello"
    ];
  };

  testPackageType = {
    expr = full.packages.hello.type;
    expected = "derivation";
  };

  testMinimalPackage = {
    expr = names minimal.packages;
    expected = [ "default" ];
  };

  testPlatformFilterKeeps = {
    expr =
      let

        pkg = {
          type = "derivation";
          name = "kept";
          meta.platforms = [ "x86_64-linux" ];
        };
      in
      names (filterPlatforms sys { kept = pkg; });
    expected = [ "kept" ];
  };

  testPlatformFilterDrops = {
    expr =
      let
        pkg = {
          type = "derivation";
          name = "dropped";
          meta.platforms = [ "aarch64-darwin" ];
        };
      in
      names (filterPlatforms sys { dropped = pkg; });
    expected = [ ];
  };

  # --- DevShells ---

  testFullDevshellNames = {
    expr = sort (names full.devShells);
    expected = [
      "backend"
      "default"
    ];
  };

  testDevshellType = {
    expr = full.devShells.default.type;
    expected = "devshell";
  };

  # --- Formatter ---

  testFullFormatter = {
    expr = full.formatter != null;
    expected = true;
  };

  testFormatterFallback = {
    expr = minimal.formatter.name;
    expected = "nixfmt-tree";
  };

  # --- Checks ---

  testFullCheckNames = {
    expr = sort (names full.checks);
    expected = [ "mycheck" ];
  };

  # --- Auto-checks ---

  testAutoCheckPackagePrefix = {
    expr = sort (names (withPrefix "pkgs-" full.packages));
    expected = [
      "pkgs-goodbye"
      "pkgs-hello"
    ];
  };

  testAutoCheckDevshellPrefix = {
    expr = sort (names (withPrefix "devshell-" full.devShells));
    expected = [
      "devshell-backend"
      "devshell-default"
    ];
  };
}
