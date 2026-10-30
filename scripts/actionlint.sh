#!/usr/bin/env bash
# Runs a checksum-pinned actionlint over the repository's workflows.
set -euo pipefail

version=1.7.12
sha256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
archive="actionlint_${version}_linux_amd64.tar.gz"

root=$(git rev-parse --show-toplevel)
dir="${XDG_CACHE_HOME:-$HOME/.cache}/actionlint-$version"
bin="$dir/actionlint"

if [ ! -x "$bin" ]; then
  mkdir -p "$dir"
  curl -fsSL -o "$dir/$archive" "https://github.com/rhysd/actionlint/releases/download/v$version/$archive"
  echo "$sha256  $dir/$archive" | sha256sum -c -
  tar -xzf "$dir/$archive" -C "$dir" actionlint
  rm "$dir/$archive"
fi

cd "$root"
"$bin" "$@"
