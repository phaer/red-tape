# red-tape/lib — Discover and expose the project's lib/default.nix
let
  inherit (builtins) isFunction pathExists;
in
{
  name = "lib";
  inputs = {
    scan = {
      path = "../scan";
    };
  };
  impl =
    { results, ... }:
    let
      src = results.scan.resolvedSrc;
      inherit (results.scan) self inputs;
      libPath =
        let
          p = src + "/lib/default.nix";
        in
        if pathExists p then p else null;
      raw =
        if libPath == null then
          { }
        else
          let
            m = import libPath;
          in
          if isFunction m then
            m {
              flake = self;
              inherit inputs;
            }
          else
            m;
    in
    if raw != { } then { lib = raw; } else { };
}
