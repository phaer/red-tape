{ inputs, ... }:
{
  greet = name: "Hello, ${name}!";
  add = a: b: a + b;
  helpers = {
    mkName = prefix: suffix: "${prefix}-${suffix}";
    filterEmpty = builtins.filter (x: x != "");
    wrapList = x: [ x ];
  };
}
