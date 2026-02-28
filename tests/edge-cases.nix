# Edge case tests
let
  scanDir = import ../lib/scan-dir.nix;
  filterPlatforms = import ../lib/filter-platforms.nix;
in
{
  # meta.platforms filtering removes packages for wrong system
  testPlatformFilter = {
    expr = filterPlatforms "x86_64-linux" {
      good = { meta.platforms = [ "x86_64-linux" "aarch64-linux" ]; };
      bad = { meta.platforms = [ "aarch64-darwin" ]; };
      noMeta = {};
    };
    expected = {
      good = { meta.platforms = [ "x86_64-linux" "aarch64-linux" ]; };
      noMeta = {};
    };
  };

  # scanDir ignores non-nix files
  testScanDirNixOnly = {
    expr =
      let
        # The simple fixture has hello.nix and goodbye/ — both should appear
        result = scanDir ../tests/fixtures/simple/packages;
      in
      builtins.sort builtins.lessThan (builtins.attrNames result);
    expected = [ "goodbye" "hello" ];
  };

  # Empty directory scan
  testScanDirEmpty = {
    expr = scanDir ../tests/fixtures/empty;
    expected = {};
  };

  # buildTemplates reads description from flake.nix
  testTemplateDescriptionFallback = {
    expr =
      let
        buildTemplates = import ../lib/build-templates.nix;
        # Template without a flake.nix description
        result = buildTemplates {
          nodesc = { path = ../tests/fixtures/empty; };
        };
      in
      result.nodesc.description;
    expected = "nodesc";
  };
}
