# Tests for template export
let
  buildTemplates = import ../lib/build-templates.nix;
  discover = import ../modules/discover.nix;
  fixtures = ../tests/fixtures;
in
{
  testTemplateNames = {
    expr = builtins.sort builtins.lessThan
      (builtins.attrNames (buildTemplates (discover (fixtures + "/full")).templates));
    expected = [ "default" "minimal" ];
  };

  testTemplateDescription = {
    expr = (buildTemplates (discover (fixtures + "/full")).templates).default.description;
    expected = "A default template";
  };

  testEmptyTemplates = {
    expr = buildTemplates (discover (fixtures + "/empty")).templates;
    expected = {};
  };
}
