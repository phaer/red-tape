{ ... }:
final: prev: {
  bench-gamma = final.writeShellScriptBin "bench-gamma" "echo gamma";
}
