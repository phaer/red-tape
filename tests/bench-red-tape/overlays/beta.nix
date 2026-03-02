{ ... }:
final: prev: {
  bench-beta = final.writeShellScriptBin "bench-beta" "echo beta";
}
