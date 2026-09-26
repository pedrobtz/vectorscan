# Shared helpers for the vendoring scripts. Sourced, not executed.

# sha256 of a file, bare hex, on macOS and Linux alike.
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        echo "no sha256sum or shasum available" >&2
        exit 1
    fi
}

# Field $2 of the manifest row for source $1.
manifest_field() {
    awk -v want="$1" -v col="$2" '
        NR == 1 { for (i = 1; i <= NF; i++) if ($i == col) c = i; next }
        $1 == want { print $c; found = 1; exit }
        END { if (!found) exit 1 }
    ' FS='\t' "$MANIFEST"
}

# Every source in the manifest.
manifest_sources() {
    awk 'NR > 1 { print $1 }' FS='\t' "$MANIFEST"
}

# Every vendored file for source $1, sorted, repo-relative. Build outputs a
# local install can leave behind are not part of the tree.
vendored_files() {
    find "src/vendor/$1" -type f ! -name '*.o' ! -name '*.so' ! -name '*.dll' \
        ! -name '.DS_Store' | LC_ALL=C sort
}

# The keep list for source $1 as "dest:source" pairs, one word per file.
keep_list() {
    list="tools/vendor/keep/$1.txt"
    if [ ! -f "$list" ]; then
        echo "no keep list for source: $1 (expected $list)" >&2
        exit 1
    fi
    sed 's/#.*//' "$list" | awk 'NF == 2 { print $1 ":" $2 }'
}

# A comma-separated manifest field as one item per line; "-" is empty.
split_field() {
    [ "$1" = "-" ] && return 0
    printf '%s\n' "$1" | tr ',' '\n' | grep -v '^$' || true
}
