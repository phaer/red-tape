# Consumer integration test

A minimal red-tape consumer flake. Run with:

```console
$ nix flake check
$ nix build        # builds packages.default
$ nix develop      # enters devShells.default
```

Expected outputs:
- `packages.x86_64-linux.default` — a hello script
- `devShells.x86_64-linux.default` — shell with pkgs.hello
- `formatter.x86_64-linux` — nixfmt-tree (fallback)
- `checks.x86_64-linux.pkgs-default` — auto-check from package
- `checks.x86_64-linux.devshell-default` — auto-check from devshell
