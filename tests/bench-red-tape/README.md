# Performance benchmark

Equivalent projects for comparing red-tape vs blueprint evaluation time.

## Structure

Both projects have 6 packages, 5 devshells, 5 checks, evaluated across
4 systems (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin).

## Running

```console
# From this directory or bench-blueprint/:
NIX_SHOW_STATS=1 nix eval .#packages --json --no-eval-cache 2>stats.json >/dev/null
cat stats.json | grep cpuTime
```

## Results

At this scale both take ~265ms wall time and ~700ms CPU — dominated by
Nix startup and nixpkgs loading. Project evaluation is below noise.

### What adios memoization actually does

Adios `override` memoizes `evalParams.results` — the intermediate option
resolution and dependency wiring. The final `module {}` call in
`tree.modules.<name> {}` re-runs each time it's forced, because that
wrapper is a lazy thunk, not a cached result.

```
# Even the same eval's module is called fresh each time:
e1.modules.pure {}   # runs impl
e1.modules.pure {}   # runs impl again
e2.modules.pure {}   # runs impl again (override)
```

The benefit is that option computation and input wiring (the adios
bookkeeping) is not repeated for modules whose inputs haven't changed.
For red-tape's modules, that bookkeeping is cheap.

### Practical conclusion

The memoization benefit is real but small for projects of typical size.
Blueprint uses `lib.genAttrs` which re-evaluates each system fully and
independently — same practical result because Nix's own lazy evaluation
already deduplicates the expensive parts (importing nixpkgs, evaluating
package files).

At the project scale where you'd actually feel a difference (hundreds of
packages, many systems), adios has an architectural advantage. But it's
not measurable with the current fixture size.
