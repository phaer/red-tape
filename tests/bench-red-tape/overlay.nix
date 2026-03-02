{ ... }:
final: prev: {
  bench-tool = final.writeShellScriptBin "bench-tool" "echo bench";
}
