{ pkgs, pname, ... }:
pkgs.writeShellScriptBin pname ''
  echo "Widget!"
''
