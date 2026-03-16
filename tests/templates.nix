# Template tests
let
  prelude = import ./prelude.nix;
  inherit (prelude) fixtures;
  inherit (builtins)
    attrNames
    filter
    listToAttrs
    map
    mapAttrs
    pathExists
    readDir
    ;

  scanTemplates =
    src:
    let
      p = src + "/templates";
    in
    if !pathExists p then
      { }
    else
      let
        e = readDir p;
      in
      listToAttrs (
        map (n: {
          name = n;
          value = {
            path = p + "/${n}";
          };
        }) (filter (n: e.${n} == "directory") (attrNames e))
      );

  mkTemplates =
    src:
    mapAttrs (
      name: entry:
      let
        f = entry.path + "/flake.nix";
      in
      {
        inherit (entry) path;
        description = if pathExists f then (import f).description or name else name;
      }
    ) (scanTemplates src);
in
{
  testTemplateNames = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames (mkTemplates (fixtures + "/full")));
    expected = [
      "default"
      "minimal"
    ];
  };

  testTemplateDescription = {
    expr = (mkTemplates (fixtures + "/full")).default.description;
    expected = "A default template";
  };

  testEmptyTemplates = {
    expr = mkTemplates (fixtures + "/empty");
    expected = { };
  };
}
