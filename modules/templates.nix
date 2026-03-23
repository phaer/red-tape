# red-tape/templates — Discover template directories
let
  inherit (import ../lib/internal.nix) scanSubdirs;
  inherit (builtins) mapAttrs pathExists;
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
      found = scanSubdirs (src + "/templates") (path: {
        inherit path;
      });
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
