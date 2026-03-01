{ pkgs, ... }:
pkgs.mkShell {
  packages = [ pkgs.hello ];
  shellHook = "echo 'red-tape consumer devshell'";
}
