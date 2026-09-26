# Vendored Vectorscan

This directory contains the Vectorscan 5.4.13 source tree from:

<https://github.com/VectorCamp/vectorscan/tree/vectorscan/5.4.13>

Vectorscan is licensed under the BSD 3-Clause license. See
`vectorscan/LICENSE` and `vectorscan/COPYING` for the upstream license text,
and `inst/COPYRIGHTS` for everything bundled.

The tree is not edited by hand. `tools/vendor/fetch` rebuilds it from the
release archive pinned in `tools/vendor/manifest.tsv`:

1. keeps the files listed in `tools/vendor/keep/vectorscan.txt` (upstream
   unit tests, command-line tools, examples, benchmarks, documentation and
   Chimera sources are left out);
2. applies the patches in `tools/patches/vectorscan/`, each of which
   explains itself in its header;
3. generates `src/parser/Parser.rl.cpp` and `src/parser/control_verbs.rl.cpp`
   with Ragel, so installing the package does not need Ragel;
4. records `tools/vendor/checksums.sha256`.

`tools/vendor/verify` checks the tree against all of that offline, and the
`vendor` CI workflow runs it. To update Vectorscan, change the manifest row,
re-check that each patch still applies, run `tools/vendor/fetch`, and review
the diff.

The package `configure` script builds this source tree into a local static
`libhs` and links the R extension against it. Set `VECTORSCAN_USE_SYSTEM=true`
to use an externally installed compatible `libhs` during development.
