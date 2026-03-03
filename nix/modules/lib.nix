# red-tape/lib — Import and expose the project's lib/default.nix
#
# Inputs: ../scan
# Options: self, inputs
# Result: { lib = <attrset>; }
{
  name = "lib";
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
      inherit (builtins) isFunction removeAttrs;
      found = results.scan;
      self = options.self;
      allInputs = (removeAttrs options.inputs [ "self" ])
        // (if self != null then { inherit self; } else {});
      raw =
        if found.lib == null then {}
        else
          let m = import found.lib;
          in if isFunction m then m { flake = self; inputs = allInputs; } else m;
    in
    if raw != {} then { lib = raw; }
    else {};
}
