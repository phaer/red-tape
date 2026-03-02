{ ... }:
final: prev: {
  bench-epsilon = final.writeShellScriptBin "bench-epsilon" "echo epsilon";
}
