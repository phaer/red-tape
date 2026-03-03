# red-tape — Convention-based Nix project builder on adios-flake
{ adios-flake }:
let
  adiosFlakeLib = adios-flake.lib or adios-flake;
  defaultModules = import ../modules;
  mkFlake =
    {
      inputs,
      self ? null,
      src,
      prefix ? null,
      systems ? [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ],
      modules ? [ ],
      perSystem ? null,
      config ? { },
      flake ? { },
    }:
    adiosFlakeLib.mkFlake {
      inherit
        inputs
        self
        systems
        perSystem
        flake
        ;
      modules = [ defaultModules.default ] ++ modules;
      config = {
        "red-tape/scan" = {
          inherit src self;
          inputs = inputs;
        }
        // (if prefix != null then { inherit prefix; } else { });
      }
      // config;
    };
in
{
  inherit mkFlake;
  modules = defaultModules;
}
