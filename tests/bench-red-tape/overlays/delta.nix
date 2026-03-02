{ ... }:
final: prev: {
  bench-delta = final.writeShellScriptBin "bench-delta" "echo delta";
}
