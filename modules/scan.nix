# red-tape/scan — Shared flake context (src, self, inputs)
#
# Individual modules handle their own filesystem discovery.
# Result: { resolvedSrc, src, self, inputs }
let
  inherit (builtins) isPath removeAttrs;
in
{
  name = "scan";
  options = {
    src = {
      type = {
        name = "path-like";
        verify = v: if isPath v || builtins.isString v then null else "expected a path or string";
      };
    };
    prefix = {
      type = {
        name = "nullable-string";
        verify =
          v:
          if v == null || builtins.isString v || isPath v then null else "expected null, a string, or a path";
      };
      default = null;
    };
    self = {
      # Never inspected — avoids forcing the flake fixpoint to weak head normal form.
      type = {
        name = "any";
        verify = _: null;
      };
      default = null;
    };
    inputs = {
      type = {
        name = "attrs";
        verify = v: if builtins.isAttrs v then null else "expected attrset";
      };
      default = { };
    };
  };
  impl =
    { options, ... }:
    let
      src = options.src;
      prefix = options.prefix;
      self = options.self;
      resolvedSrc =
        if prefix != null then (if isPath prefix then prefix else src + "/${prefix}") else src;
      inputs =
        (removeAttrs options.inputs [ "self" ]) // (if self != null then { inherit self; } else { });
    in
    {
      inherit resolvedSrc src self inputs;
    };
}
