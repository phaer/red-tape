# red-tape/scan — Pure filesystem discovery module
#
# Options:
#   src    — Source path to scan (typically `self`)
#   prefix — Optional subdirectory prefix
#
# Result: the full discovery attrset from discover.discoverAll
{ discover }:

let
  inherit (builtins) isPath;
in
{
  name = "scan";
  options = {
    src = {
      type = {
        name = "path-like";
        verify = v:
          if isPath v || (builtins.isAttrs v && v ? outPath) || builtins.isString v
          then null
          else "expected a path, string, or attrset with outPath";
      };
    };
    prefix = {
      type = {
        name = "nullable-string";
        verify = v:
          if v == null || builtins.isString v || isPath v
          then null
          else "expected null, a string, or a path";
      };
      default = null;
    };
  };
  impl = { options, ... }:
    let
      src = options.src;
      prefix = options.prefix;
      resolvedSrc =
        if prefix != null then
          (if isPath prefix then prefix else src + "/${prefix}")
        else src;
    in
    discover.discoverAll resolvedSrc;
}
