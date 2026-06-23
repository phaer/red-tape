# red-tape/project — Project-level flake context (src, self, inputs)
#
# Individual modules handle their own filesystem discovery.
# Result: { resolvedSrc, src, self, inputs, systems, defaultSystem, pkgsFor }
let
  inherit (builtins) head isPath removeAttrs;
in
{
  name = "project";
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
    systems = {
      type = {
        name = "list-of-string";
        verify =
          v:
          if builtins.isList v && builtins.all builtins.isString v then
            null
          else
            "expected a list of system strings";
      };
      default = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
  };
  impl =
    { options, ... }:
    let
      src = options.src;
      prefix = options.prefix;
      self = options.self;
      systems = options.systems;
      resolvedSrc =
        if prefix != null then (if isPath prefix then prefix else src + "/${prefix}") else src;
      inputs =
        (removeAttrs options.inputs [ "self" ]) // (if self != null then { inherit self; } else { });
      defaultSystem =
        if systems == [ ] then throw "red-tape: `systems` must not be empty" else head systems;
      pkgsFor = system: import inputs.nixpkgs { inherit system; };
    in
    {
      inherit
        resolvedSrc
        src
        self
        inputs
        systems
        defaultSystem
        pkgsFor
        ;
    };
}
