# Tests for template export
let
  prelude = import ./prelude.nix;
  inherit (prelude) _internal fixtures;
  inherit (_internal) discover buildTemplates;
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
