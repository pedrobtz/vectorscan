# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## What this is

`vectorscan` is an R package providing bindings to
[Vectorscan](https://github.com/VectorCamp/vectorscan) (the portable
fork of Intel Hyperscan) for high-performance multi-pattern regex
matching. The Vectorscan C/C++ source is **vendored** under
`src/vendor/vectorscan` (v5.4.13) and compiled into a private static
`libhs` during package install; the runtime machine needs no system
Vectorscan.

Never edit files under `src/vendor/vectorscan` by hand:
`tools/vendor/verify` (run by the `vendor` workflow) fails on any change
that did not come from `tools/vendor/fetch`. To change the vendored
code, add or edit a patch in `tools/patches/vectorscan/`, list it in
`tools/vendor/manifest.tsv` and `inst/COPYRIGHTS`, and re-run
`tools/vendor/fetch` (needs network and Ragel). See
`src/vendor/README.md`.

## Common commands

``` sh
air format .                                # format R code (this repo uses air, not styler)
Rscript -e "devtools::document()"           # regenerate man/ and NAMESPACE from roxygen
Rscript -e "devtools::load_all()"           # load for interactive dev
Rscript -e "devtools::test()"               # run all tests
Rscript -e "testthat::test_file('tests/testthat/test-database.R')"  # single test file
Rscript -e "devtools::check()"              # full R CMD check
Rscript -e "pkgdown::check_pkgdown()"       # validate _pkgdown.yml reference index
```

Building requires `cmake` (install-time only). Boost headers come from
the `BH` package (`LinkingTo`); Ragel is optional because the generated
parser sources are vendored as
`src/vendor/vectorscan/src/parser/*.rl.cpp`.

## Build configuration

The `configure` (Unix) / `configure.win` (Windows) scripts decide how to
link `libhs` and write `src/Makevars`. `src/Makevars` is **generated** —
do not hand- edit it; edit the configure scripts instead. `cleanup`
removes the generated `Makevars` and build outputs.

Relevant environment variables (see README “Build Configuration”): -
`VECTORSCAN_USE_SYSTEM=true` — link an installed `libhs` instead of
building the vendored source (faster dev iteration). -
`VECTORSCAN_INCLUDE_DIR` / `VECTORSCAN_LIB_DIR` — point at a custom
install. - `VECTORSCAN_BOOST_ROOT` — Boost headers location. -
`VECTORSCAN_ALLOW_STUBS=true` — build no-op stubs when native Vectorscan
is unavailable; **wrapper development only**, scans will not work.

## Architecture

Two layers, bridged by `.Call`:

**R layer (`R/`)** — user-facing API and all input validation. Native
code assumes inputs are already validated, so keep checks in R. -
`database.R` —
[`hs_database()`](https://pedrobtz.github.io/vectorscan/reference/hs_database.md)
creates an environment-based handle (`ptr`, `scratch`, `mode`,
`pattern_ids`, `pattern_flags`) with S3 class `hs_database`;
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
fills in the compiled pointers via `.Call`. - `scan.R` / `stream.R` —
[`hs_scan()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan.md),
[`hs_scan_vector()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan_vector.md),
and the stream lifecycle. All scan entry points share the same dual
return contract: a match **data frame** when `callback = NULL`, or the
callback invocation **count** (invisibly) when a callback is supplied.
Return `TRUE` from a callback to terminate scanning early. - `ext.R` —
[`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
extended-parameter objects; `normalize_ext_list()` recycles them to
one-per-expression for
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md). -
`serialize.R`, `constants.R` (`HS_*` flags/modes), `errors.R`
(`stop_vectorscan()` typed conditions), `utils.R` (validation helpers,
[`hs_available()`](https://pedrobtz.github.io/vectorscan/reference/hs_available.md)).

**Native layer (`src/`)** — thin C wrapper over Vectorscan. -
`vectorscan.c` is compiled twice-over via the `HAVE_HS` macro: with it
defined, real bindings; without it, every entry point is a stub that
errors (`#ifndef HAVE_HS` block at the top). `configure` sets
`-DHAVE_HS`. - `hs_database_t`, `hs_scratch_t`, and `hs_stream_t` are
held as R external pointers with registered C finalizers — do not free
them manually from R. - `init.c` registers the `.Call` entry points (all
prefixed `vctrsn_`); it must stay in sync with the `.Call(vctrsn_...)`
names used in R. - `link.cpp` exists only to force the C++ linker
(Vectorscan needs libstdc++).

### Two cross-layer invariants worth knowing

1.  **`HS_FLAG_SOM_LEFTMOST` and match `from`.** Vectorscan only reports
    a real start-of-match offset when a pattern was compiled with
    `HS_FLAG_SOM_LEFTMOST`. `normalize_match_from()` in `scan.R` uses
    the stored `pattern_ids` / `pattern_flags` to set `from = NA` for
    any match whose pattern lacked that flag. This is why the database
    handle caches the per-pattern flags.

2.  **Flag/mode constants are mirrored.** The `HS_*` integer values in
    `constants.R` must match Vectorscan’s `hs.h`. When updating the
    vendored source or adding a flag, change both sides.

## Testing notes

- testthat edition 3 (`Config/testthat/edition: 3`); snapshot tests live
  in `tests/testthat/_snaps/`.
- Tests and examples gate real scanning on
  [`hs_available()`](https://pedrobtz.github.io/vectorscan/reference/hs_available.md),
  so they pass even in a stub build. When adding tests that exercise
  native scanning, guard them the same way (or
  `skip_if_not(hs_available())`).

## Conventions

- roxygen2 with markdown (`Roxygen: list(markdown = TRUE)`); edit
  roxygen comments in `R/`, never `man/*.Rd` or `NAMESPACE` directly —
  run `devtools::document()`.
- User-facing errors go through `stop_vectorscan()` with a specific
  condition `class` (e.g. `vectorscan_error_mode`), not bare
  [`stop()`](https://rdrr.io/r/base/stop.html).
