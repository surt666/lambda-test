#!/usr/bin/env bash
# Scaffold a Clojure app with deps-new, clj-kondo, reitit + malli and optional AWS Lambda/SAM setup.
set -euo pipefail

DEPS_NEW='{:deps {io.github.seancorfield/deps-new {:git/tag "v0.16.0" :git/sha "bac3a23"}}}'

usage() {
  cat <<USAGE
Usage: $(basename "$0") <org/name> [options]

Options:
  --dir <path>   Target directory (default: ./<name>)
  --no-reitit    Don't add reitit
  --no-malli     Don't add malli
  -h, --help     Show this help
USAGE
}

name=""
dir=""
reitit=true
malli=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --no-reitit) reitit=false; shift ;;
    --no-malli) malli=false; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) [[ -z "$name" ]] || { echo "Unexpected argument: $1" >&2; exit 1; }
       name="$1"; shift ;;
  esac
done

[[ "$name" == */* ]] || { echo "Project name must be <org>/<name>, e.g. surt666/my-app" >&2; usage >&2; exit 1; }

org="${name%%/*}"
project="${name#*/}"
dir="$(realpath -m "${dir:-$project}")"
[[ ! -e "$dir" ]] || { echo "Target already exists: $dir" >&2; exit 1; }

command -v clj-kondo >/dev/null || { echo "clj-kondo not found on PATH" >&2; exit 1; }

echo "Creating $name in $dir..."
# Run outside any project so a local deps.edn can't interfere.
(cd "$(mktemp -d)" && clojure -Sdeps "$DEPS_NEW" -X org.corfield.new/app \
  :name "$name" :target-dir "\"$dir\"")

cd "$dir"

deps=()
if $reitit; then deps+=("metosin/reitit-ring 0.11.0"); fi
if $malli; then deps+=("metosin/malli 0.20.3"); fi
if $reitit && $malli; then deps+=("metosin/reitit-malli 0.11.0"); fi

add_deps() {
  [[ ${#deps[@]} -gt 0 ]] || return 0
  echo "Adding dependencies..."
  local extra="" lib ver
  for d in "${deps[@]}"; do
    read -r lib ver <<<"$d"
    extra+="\\n        $lib {:mvn/version \"$ver\"}"
  done
  # deps-new writes the :deps map on one line; append ours before its closing brace.
  sed -i "s|^ :deps {\(.*\)}\$| :deps {\1$extra}|" deps.edn
  for d in "${deps[@]}"; do
    grep -q "${d%% *} " deps.edn || { echo "Failed to add ${d%% *} to deps.edn" >&2; exit 1; }
  done
}

add_clj_kondo() {
  echo "Setting up clj-kondo..."
  mkdir -p .clj-kondo
  cat > .clj-kondo/config.edn <<'KONDO'
{:linters {:shadowed-var {:level :warning}}}
KONDO
  # Import lint configs that libraries ship (e.g. malli, reitit).
  clj-kondo --lint "$(clojure -Spath -A:test)" --dependencies --copy-configs --skip-lint
}

add_deps
add_clj_kondo

echo "Done: $dir"
