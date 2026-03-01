{
  description = "red-tape benchmark project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    red-tape.url = "path:../..";
    red-tape.inputs = {};
  };

  outputs = inputs: inputs.red-tape.lib {
    inherit inputs;
    src = ./.;
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
