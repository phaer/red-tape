# Performance benchmark

Equivalent projects for comparing red-tape vs blueprint evaluation time.

## Structure

Both projects have 6 packages, 5 devshells, 5 checks, evaluated across
4 systems (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin).

## Running

```console
# From this directory:
nix eval .#checks --apply builtins.attrNames --json --no-eval-cache
time nix eval .#checks --apply builtins.attrNames --json --no-eval-cache

# Compare with blueprint:
cd ../bench-blueprint
time nix eval .#checks --apply builtins.attrNames --json --no-eval-cache
```

## Results

At this scale both take ~265ms — dominated by Nix startup and nixpkgs loading.
Project evaluation itself is negligible.

The adios memoization benefit (evaluate once, override `/nixpkgs` per
system) shows up in larger projects where per-system module evaluation
is expensive. At ~10 packages/devshells the overhead is below measurement
noise.
