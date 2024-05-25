#!/bin/bash -euo pipefail

sha="$(git log -n 1 '--pretty=format:%h')"
if [[ $(git status -s | wc -c) -ne 0 ]]; then 
  sha="${sha}.dirty"
fi

preprocess_dir=infoplist-preprocess
compiled_headers="$preprocess_dir/compiled.h"

cat "$preprocess_dir/fixed/"*.h > "$compiled_headers"

printf '#define FULL_BUILD_VERSION %s\n' "$(/bin/date -u '+%Y.%m%d.%H%M%S')" >> "$compiled_headers"
