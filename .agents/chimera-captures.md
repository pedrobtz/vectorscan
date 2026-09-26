# Capture groups via Chimera — plan

Status: planned (2026-09-26). Tracks the roadmap item "Capture groups via
Chimera" (Stage 2b in `roadmap.md`).

## Goal

Turn text into columns with one regex, at Vectorscan speed on the lines that
do not match:

```r
fmt <- "^(?<timestamp>\\S+ \\S+) \\[(?<level>\\w+)\\]\\s+(?<location>[^ :]+):(?<line>\\d+) - (?<text>.*)$"
log <- hs_capture(fmt, readLines("app.log"),
                  proto = data.frame(timestamp = character(), level = character(),
                                     location = character(), line = integer(),
                                     text = character()))
```

`log` is a data frame with one row per line and one column per capture group:
what `utils::strcapture()` returns, without running a PCRE match on every
line.

Vectorscan alone cannot do this: its engine reports where a pattern matched,
never where a group did. Chimera, shipped in the Vectorscan tree, can. It
compiles each pattern twice: as a Hyperscan prefilter, which rejects most
non-matching input in one pass, and as a PCRE pattern, run only on the
candidates to confirm the match and fill in the groups.

## Decisions

- **Chimera, as upstream ships it, on PCRE 8.45 now.** PCRE1 has been
  end-of-life since June 2021 and distributions are dropping it (Debian 13,
  openSUSE Tumbleweed, Fedora rawhide, NixOS), so it is bundled, never taken
  from the system. python-hyperscan made the same choice: it has had Chimera
  on PCRE 8.45 since v0.3.0 (2022).
- **Move to PCRE2 later.** Upstream plans the PCRE2 migration for Vectorscan
  5.5 (VectorCamp/vectorscan#320, maintainer comment of 2026-05-31), with no
  date yet. We move when 5.5 ships; `vendor-upstream.yaml` opens an issue on
  the tag. Porting Chimera ourselves stays an option if 5.5 is far off (a few
  hundred lines across four files, see "PCRE2 migration" below).
- **PCRE sits behind our own C layer.** The R API and the C glue talk to a
  small capture backend (compile, scan with groups, free). Only that backend
  and the vendoring change when PCRE1 is replaced, and the tests below are the
  contract that has to hold across the switch.
- **Block mode only.** Chimera supports neither streaming nor vectored scans.
  That fits the use case: one element (log line, record) at a time.
- **Nothing downloaded at install.** PCRE is vendored like Vectorscan: pinned
  archive, sha256, keep list, patches, `tools/vendor/verify`.

## Architecture

```
R:        hs_capture()          hs_detect() / hs_match() / ...   (existing)
            |                        |
C glue:   vctrsn_ch_compile       vctrsn_hs_scan_many            (existing)
          vctrsn_ch_capture_many
            |
backend:  capture backend  -----> Chimera (ch_compile_ext_multi, ch_scan)
                                     |            |
                                 libhs (Vectorscan)  libpcre 8.45 -> later PCRE2
```

- A Chimera database is a separate object (`hs_capture_database`, or an
  `engine` field on `hs_database`; see open questions). It has no
  serialization: Chimera has no `ch_serialize_database()`, so `hs_serialize()`
  refuses it with a clear error.
- The per-element C loop follows `vctrsn_hs_scan_many()`: one scratch per
  call, `malloc()`ed buffers, no R allocation or longjmp inside the Chimera
  callbacks, interrupts checked through `R_ToplevelExec()`.

## Milestones

Each milestone is one PR, and each ends with the full CI profile green
(`full-ci` label): R CMD check on all platforms and containers, ASan, UBSan,
valgrind, LTO, gctorture, rchk, and the build-modes jobs.

### M0 — Build spike (started)

Prove Chimera and bundled PCRE build inside the vendored tree, before any
package code.

- Findings so far, from a local prototype (PCRE 8.45, Vectorscan 5.4.13 with
  our patches, CMake 4):
  - Vectorscan's `cmake/pcre.cmake` accepts `-DPCRE_SOURCE=<dir>`, and its
    PCRE >= 8.41 version check passes.
  - PCRE's `CMakeLists.txt` needs two changes for CMake 4:
    `CMAKE_MINIMUM_REQUIRED(VERSION 2.8.5)` must become 3.5, and
    `CMAKE_POLICY(SET CMP0026 OLD)` must go. The policy only matters for
    rebuilding the character tables and for the tests, both off.
  - PCRE's CMake reads its version from `configure.ac`, so that file has to
    be in the keep list.
- Still to do: build the `chimera` and `pcre` targets, and scan with
  `CH_MODE_GROUPS` from a small C program, under ASan.
- Exit: `libchimera.a` and `libpcre.a` build on macOS arm64, Linux x86-64
  (fat runtime) and Windows (Rtools, no fat runtime), and the C program
  returns correct groups.

### M1 — Vendoring

- `tools/vendor/manifest.tsv`: a second source, `pcre`, pinned to 8.45 by the
  SourceForge archive's sha256, BSD-3-Clause.
- `tools/vendor/keep/pcre.txt`: the ~36 files the library build needs (the 20
  `pcre_*.c` sources, the headers, `CMakeLists.txt`, `cmake/`, the `.in`
  templates, `configure.ac`, licence files). No tests, `pcregrep`, `pcrecpp`
  or JIT (`sljit/`).
- `tools/patches/pcre/0001-cmake-4.patch` for the two CMake lines above.
- Add upstream `chimera/` (15 files, 156 KB) to
  `tools/vendor/keep/vectorscan.txt`.
- `tools/vendor/fetch`: `.tar.bz2` archives and the SourceForge download URL.
- `inst/COPYRIGHTS`: the PCRE section. `Authors@R`: University of Cambridge
  and Philip Hazel as copyright holders of the bundled PCRE.
- Exit: `tools/vendor/verify` passes for both sources, and the vendor guard
  is green. Expected tarball growth: about 0.3 MB compressed (PCRE subset
  0.25 MB plus Chimera), from 1.25 MB.

### M2 — Build integration

- `configure` / `configure.win`: pass `PCRE_SOURCE` and the PCRE options
  (`PCRECPP`, `PCREGREP` and tests off; UTF-8 and Unicode properties on),
  build the `chimera` target next to `hs` and `hs_runtime`, and link
  `libchimera.a` and `libpcre.a`. PCRE's static library has no install rule,
  so it is copied from the build tree.
- The system-library mode (`VECTORSCAN_USE_SYSTEM`) keeps working without
  Chimera. A capability check (`hs_capture_available()`, or a field of
  `hs_available()`) tells the R layer whether captures exist.
- Measure the added build time; it should be small next to libhs (about 25
  more C files).
- Exit: the package builds and links everywhere, all existing tests pass, and
  the capability check is TRUE on the bundled build and FALSE on the system
  and stub builds.

### M3 — C bindings

- `vctrsn_ch_compile()`: `ch_compile_ext_multi()` with `CH_MODE_GROUPS`,
  ids, flags, and configurable `match_limit` / `match_limit_recursion`, with
  the database and scratch behind finalizers.
- `vctrsn_ch_capture_many()`: loop over a character vector, `ch_scan()` each
  element, and record per element the matching pattern id and each group's
  `(from, to)`, unset groups included. Keep the first match per element; for
  a line-parsing regex anchored with `^...$` there is only one.
- The Chimera error callback (`CH_ERROR_MATCHLIMIT`,
  `CH_ERROR_RECURSIONLIMIT`) is recorded per element, not raised, so one
  pathological line cannot abort a million-line scan.
- Validate the backend before the R API goes on top:
  - build upstream's `unit/chimera` suite (trimmed from the package tree) in
    scratch against our build;
  - add a differential test against base R's `regexec(perl = TRUE)` on random
    inputs and patterns: same match or no match, same group offsets.
- Exit: C-level results equal `regexec()` on the differential test, and ASan
  and valgrind are clean on the capture path (added to
  `tools/sanitizer-exercise.R`).

### M4 — R API

- `hs_capture(pattern, x, proto = NULL, flags = ..., match_limit = ...)`
  returns a data frame, one row per element of `x`:
  - Column names come from named groups `(?<name>...)` (parsed from the
    pattern), else from `proto`, else `V1`, `V2`, ...
  - Column types come from `proto`, converted as `utils::strcapture()`
    converts them, so its users can switch over.
  - Elements that do not match, or hit a limit, give an `NA` row. Unset
    optional groups give `NA`.
  - `NA` input gives an `NA` row.
- A compiled form for reuse, parallel to `hs_compile()` for the other verbs.
- Documentation: `?hs_capture`, a "Parsing logs" article (pkgdown), README
  section, NEWS.
- Exit: documented examples match `utils::strcapture()` output on the same
  input, and the tests cover names, `proto` types, unset groups, UTF-8,
  `NA`, limits and non-matching lines.

### M5 — Hardening and performance

- Security note in `?hs_capture` and `inst/COPYRIGHTS`: PCRE 8.45 is
  end-of-life, `match_limit` and `match_limit_recursion` bound the work per
  element, and the defaults are set for untrusted input.
- Benchmark vignette section: `hs_capture()` against `utils::strcapture()`
  (PCRE2), `stringr::str_match()` (ICU) and `re2`, on a real log where most
  lines match and on one where few do.
- Exit: published numbers, and a clean sanitizer and valgrind run on a
  million-line input.

### M6 — PCRE2 migration (later)

- Trigger: Vectorscan 5.5 ships with PCRE2 (the watcher issue), or 5.5 is
  still far off and we port Chimera ourselves.
- Upstream route: upgrade the vendored Vectorscan, drop the PCRE1 source,
  vendor PCRE2 (library subset about 0.35 MB compressed, 0.57 MB with JIT),
  or link Rtools / `pkg-config libpcre2-8` with the vendored copy as
  fallback.
- Own-port route (known scope from reading the 5.4.13 sources):
  - 56 PCRE references in `ch_compile.cpp`, `ch_runtime.c`,
    `ch_database.h` and `ch_scratch.c`.
  - The one design change: Chimera copies PCRE1 bytecode into its database
    block and runs `pcre_exec()` on the copy, which PCRE2 cannot do. Since
    Chimera has no serialization, the database can hold `pcre2_code`
    pointers freed with it.
  - Per-thread `pcre2_match_data` and a match context (limits) move into the
    scratch.
  - PCRE2 JIT would then actually be used; PCRE1's is lost when the bytecode
    is copied.
- Either way: the M3 differential tests and the M4 R tests must pass
  unchanged. PCRE2's syntax differs slightly from PCRE1, and upstream calls
  5.5 compatibility-breaking, so the changes go in NEWS.

## Open questions (decide before M3/M4)

1. **One pattern or many?** `hs_capture(pattern, x)` with a single format
   covers the log case. Rule sets with several formats (route each line to
   its format, then capture) could take a named vector of patterns and return
   a `pattern` column plus the union of their group columns, or a list of
   data frames. Proposal: single pattern in M4, multiple later.
2. **Database class.** A separate `hs_capture_database`, or an `engine` field
   on `hs_database`? The separate class avoids verbs that cannot work on it
   (streams, serialization). Proposal: separate class.
3. **First match or all matches?** `strcapture()` semantics (first match per
   element) by default. All matches as an option, later, if asked for.
4. **Defaults for `match_limit` / `match_limit_recursion`.** PCRE's own
   defaults (10,000,000) are large for untrusted input. Proposal: keep PCRE's
   defaults, document the arguments, and revisit after the M5 benchmarks.

## Risks

- **PCRE1 is end-of-life.** It gets no security fixes, and logs are
  untrusted input. Mitigations: the match limits, the sanitizer jobs, the
  PCRE2 move, and saying so in the docs. CRAN reviewers may ask; the answer
  is the plan above.
- **Build complexity.** A second vendored source with its own CMake build.
  Mitigated by the vendoring guard and by M0 proving the build on all
  platforms first.
- **Semantics drift.** Results should equal PCRE's, not Hyperscan's, and the
  M3 differential test against `regexec(perl = TRUE)` checks that. Base R's
  PCRE is PCRE2, so a tiny dialect difference could show up there; that is
  worth knowing before M6.
- **Upstream 5.5 timing.** If it is long delayed, we carry PCRE1 longer or
  port Chimera ourselves (M6).
