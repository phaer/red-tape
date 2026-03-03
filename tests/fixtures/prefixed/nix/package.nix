{ pkgs, pname, ... }:
pkgs.writeShellScriptBin pname ''
  echo "Default!"
''
