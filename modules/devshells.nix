# /devshells — Per-system devshell builder

let mkModule = import ../lib/mk-per-system-module.nix;
in mkModule {
  name = "devshells";
  postProcess = { built, ... }: { devShells = built; };
}
