# red-tape/overlays — Discover and build overlay expressions
#
# Inputs: ../scan
# Options: self, inputs
# Result: { overlays = { name = overlay-fn; }; }
{ buildAll }:

{
  name = "overlays";
  inputs = {
    scan = { path = "../scan"; };
  };
  options = {
    self = {
      type = { name = "any"; verify = _: null; };
      default = null;
    };
    inputs = {
      type = { name = "attrs"; verify = v: if builtins.isAttrs v then null else "expected attrset"; };
      default = {};
    };
  };
  impl = { results, options, ... }:
    let
      inherit (builtins) removeAttrs;
      found = results.scan;
      self = options.self;
      allInputs = (removeAttrs options.inputs [ "self" ])
        // (if self != null then { inherit self; } else {});
      agnostic = { flake = self; inputs = allInputs; };
    in
    if found.overlays != {} then
      { overlays = buildAll agnostic found.overlays; }
    else
      {};
}
