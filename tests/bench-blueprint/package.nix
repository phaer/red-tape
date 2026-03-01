{ pkgs, pname, ... }:
pkgs.writeShellScriptBin pname ''
  echo "Hello from red-tape consumer test!"
''
