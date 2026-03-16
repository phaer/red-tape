# red-tape/templates — Discover template directories
let
  inherit (builtins)
    attrNames
    filter
    listToAttrs
    map
    mapAttrs
    pathExists
    readDir
    ;
in
{
  name = "templates";
  inputs = {
    scan = {
      path = "../scan";
    };
  };
  impl =
    { results, ... }:
    let
      src = results.scan.resolvedSrc;
      p = src + "/templates";
      found =
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
      templates = mapAttrs (
        name: e:
        let
          f = e.path + "/flake.nix";
        in
        {
          inherit (e) path;
          description = if pathExists f then (import f).description or name else name;
        }
      ) found;
    in
    if found != { } then { inherit templates; } else { };
}
