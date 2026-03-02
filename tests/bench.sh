#!/usr/bin/env bash
# Benchmark red-tape vs blueprint evaluation using nix-eval-jobs.
#
# Uses nix-eval-jobs (single worker, force-recurse) to force evaluation
# of all derivations — the same workload as CI. Measures wall time, CPU,
# and peak RSS.
#
# Runs each output category in two modes:
#   1-sys:  .#<attr>.x86_64-linux
#   4-sys:  .#<attr>  (all 4 architectures)
#
# Usage:
#   ./tests/bench.sh              # default: 5 iterations
#   ./tests/bench.sh -n 10        # 10 iterations
#   ./tests/bench.sh -v           # verbose: print per-iteration stats
set -euo pipefail

cd "$(dirname "$0")/.."

# ── Defaults ──────────────────────────────────────────────────────────
ITERATIONS=5
VERBOSE=0
SYSTEM="x86_64-linux"
ATTRS=("checks" "packages" "devShells")

while getopts "n:v" opt; do
  case "$opt" in
    n) ITERATIONS="$OPTARG" ;;
    v) VERBOSE=1 ;;
    *) echo "Usage: $0 [-n iterations] [-v]" >&2; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

bold=$(tput bold 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
dim=$(tput setaf 8 2>/dev/null || true)

gnu_time=/run/current-system/sw/bin/time
if [[ ! -x "$gnu_time" ]]; then
  gnu_time=$(which time 2>/dev/null || echo "time")
fi

fmt_ms() { awk "BEGIN { printf \"%.1f\", $1 * 1000 }"; }
fmt_mb() { awk "BEGIN { printf \"%.1f\", $1 / 1024 }"; }

# run_eval <flake_ref> <time_file>
# Returns wall-clock seconds to stdout.
run_eval() {
  local flake_ref="$1" time_file="$2"
  local start end

  start=$( date +%s%N )
  "$gnu_time" -v \
    nix-eval-jobs --flake "$flake_ref" \
      --workers 1 --force-recurse \
      >/dev/null 2>"$time_file"
  end=$( date +%s%N )

  awk "BEGIN { printf \"%.6f\", ($end - $start) / 1000000000 }"
}

parse_field() {
  grep "$2" "$1" | awk '{print $NF}'
}

# bench_one <label> <name> <attr> <scope> <flake_ref>
bench_one() {
  local label="$1" name="$2" attr="$3" scope="$4" flake_ref="$5"

  local wall_sum=0 user_sum=0 rss_max=0

  for i in $(seq 1 "$ITERATIONS"); do
    local timef="$tmpdir/${label}_${i}.time"
    local wall user_time rss

    wall=$( run_eval "$flake_ref" "$timef" )
    user_time=$( parse_field "$timef" "User time" )
    rss=$( parse_field "$timef" "Maximum resident" )

    wall_sum=$( awk "BEGIN { print $wall_sum + $wall }" )
    user_sum=$( awk "BEGIN { print $user_sum + $user_time }" )
    rss_max=$( awk "BEGIN { print ($rss > $rss_max) ? $rss : $rss_max }" )

    if [[ "$VERBOSE" -eq 1 ]]; then
      printf "  ${dim}#%d  wall=%sms  user=%ss  rss=%sMB${reset}\n" \
        "$i" \
        "$(fmt_ms "$wall")" \
        "$user_time" \
        "$(fmt_mb "$rss")"
    fi
  done

  local avg_wall avg_user
  avg_wall=$( awk "BEGIN { print $wall_sum / $ITERATIONS }" )
  avg_user=$( awk "BEGIN { print $user_sum / $ITERATIONS }" )

  printf "%-12s  %-12s  %-6s  %10s  %10s  %10s\n" \
    "$attr" "$name" "$scope" \
    "$(fmt_ms "$avg_wall")" \
    "$(fmt_ms "$avg_user")" \
    "$(fmt_mb "$rss_max")"
}

# ── Fixture paths ─────────────────────────────────────────────────────
RED_TAPE="./tests/bench-red-tape"
BLUEPRINT="./tests/bench-blueprint"

# Warm up
echo "${dim}Warming up (fetching inputs if needed)…${reset}"
nix-eval-jobs --flake "$RED_TAPE#checks.${SYSTEM}" --workers 1 --force-recurse \
  >/dev/null 2>&1 || true
nix-eval-jobs --flake "$BLUEPRINT#checks.${SYSTEM}" --workers 1 --force-recurse \
  >/dev/null 2>&1 || true
echo ""

# ── Header ────────────────────────────────────────────────────────────
echo "${bold}nix-eval-jobs benchmark (${ITERATIONS} iterations, 1 worker)${reset}"
echo ""
printf "%s%-12s  %-12s  %-6s  %10s  %10s  %10s%s\n" \
  "$bold" "attribute" "framework" "scope" \
  "wall(ms)" "user(ms)" "peak(MB)" "$reset"
printf '%.0s─' {1..68}; echo ""

# ── Run ───────────────────────────────────────────────────────────────
for attr in "${ATTRS[@]}"; do
  for entry in "red-tape:$RED_TAPE" "blueprint:$BLUEPRINT"; do
    name="${entry%%:*}"
    dir="${entry#*:}"

    # Single system
    bench_one "${name}_${attr}_1sys" "$name" "$attr" "1-sys" "$dir#${attr}.${SYSTEM}"

    # All 4 systems
    bench_one "${name}_${attr}_4sys" "$name" "$attr" "4-sys" "$dir#${attr}"
  done
  echo ""
done

# ── Legend ─────────────────────────────────────────────────────────────
echo "${bold}Legend${reset}"
echo "  scope     — 1-sys: .#attr.$SYSTEM (single architecture)"
echo "              4-sys: .#attr (all 4: x86_64/aarch64 × linux/darwin)"
echo "  wall(ms)  — wall-clock time (mean of $ITERATIONS iterations)"
echo "  user(ms)  — user CPU time (mean of $ITERATIONS iterations)"
echo "  peak(MB)  — peak RSS across all iterations"
echo ""
echo "Uses nix-eval-jobs --workers 1 --force-recurse."
