{ ... }:
final: prev: {
  bench-alpha = final.writeShellScriptBin "bench-alpha" "echo alpha";
}
