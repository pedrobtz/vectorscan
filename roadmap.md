# vectorscan — Roadmap

A staged plan to take `vectorscan` from a working prototype to a
relevant, maintained package in the R ecosystem.

## Where the package stands today

**Strengths**

- Complete low-level binding of the core Hyperscan API: block / vectored
  / streaming scans, callbacks with early termination, extended
  parameters, serialization, database metadata.
- Self-contained build: vendored Vectorscan 5.4.13 (~8.1 MB, 682 files)
  compiled to a private static `libhs` at install time, with system-lib
  and stub fallbacks for development.
- Good engineering hygiene for its age: typed error conditions, external
  pointers with C finalizers, roxygen docs, pkgdown config, two
  vignettes — including an honest benchmark vignette that shows where
  Vectorscan does *not* win.

**Gaps**

- The API is C-shaped, not R-shaped.
  [`hs_scan()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan.md)
  takes *one* string and returns byte offsets. The dominant R idiom —
  “match patterns against a character vector, give me back which
  elements matched what text” — is not expressible without a manual loop
  in R.
- No matched-text extraction; users get offsets and must slice bytes
  themselves (and offsets are byte offsets, undocumented for UTF-8).
- Thin test suite (~130 lines) with no coverage of serialization
  round-trips, stream edge cases, UTF-8, large inputs, error paths in
  native code, or callback misbehavior (errors thrown inside callbacks).
- CI (since 2026-09-26) checks the bundled build on Linux, macOS and
  Windows, in CRAN-like containers, and under ASan, UBSan, valgrind,
  LTO, gctorture and rchk. The system-library and stub build modes are
  not exercised yet.
- Not on CRAN. Ragel and Boost are no longer build requirements and the
  source tarball is 1.25 MB; build time is the main remaining risk (see
  Stage 4).

**Positioning: why this package deserves to exist**

R’s regex options — TRE/PCRE (base), ICU (`stringi`/`stringr`), RE2
(`re2`), Oniguruma (`ore`) — all match *one pattern per pass*.
`AhoCorasickTrie` does multi-pattern matching but literals only. Nothing
in the ecosystem compiles thousands of regexes into a single automaton
and walks the input once.

That is Vectorscan’s structural advantage, and it maps to concrete R
user pain:

- **Security / log analytics**: secret & PII scanning, IOC matching,
  SIEM rule sets over log corpora (the benchmark vignette already leans
  this way).
- **Data cleaning at scale**: “flag every row matching any of these
  5,000 patterns” — today an O(patterns × rows)
  [`grepl()`](https://rdrr.io/r/base/grep.html) loop.
- **Bioinformatics / text mining**: motif and dictionary scanning over
  large sequences and corpora, streaming over files too big for memory.

The strategy in one sentence: **keep the faithful low-level `hs_*`
layer, and win adoption with a vectorized, stringr-flavored high-level
layer on top of it** — then make the package installable everywhere
(CRAN) and prove the performance story with reproducible benchmarks.

------------------------------------------------------------------------

## Stage 1 — Foundation: hygiene, CI, and test depth

*Goal: a repo a stranger can trust and contribute to. Everything later
builds on this.*

Fix package identity: real maintainer in `DESCRIPTION`, correct
`URL`/`BugReports` (repo is `pedrobtz/vectorscan`), align `_pkgdown.yml`
URL.

Add `.gitignore` / clean tree: remove committed `src/*.o`,
`src/vectorscan.so`, `src/vendor/vectorscan-install/`,
`vignettes/*.html`; verify `.Rbuildignore` covers dev-only files
(`roadmap.md`, `CLAUDE.md`, `_pkgdown.yml`, `.github/`).

GitHub Actions CI matrix: - \[x\] `R CMD check` on Linux / macOS /
Windows with the **bundled** build, via pedrobtz/r-actions (only cmake
is needed now), plus the clang23, ubuntu-clang and ubuntu-gcc16
containers. - \[ \] One Linux job with `VECTORSCAN_USE_SYSTEM=true`. -
\[ \] One job with `VECTORSCAN_ALLOW_STUBS=true` to keep the stub path
compiling and the
[`hs_available()`](https://pedrobtz.github.io/vectorscan/reference/hs_available.md)
gating honest. - \[ \] Cache the compiled `libhs` between runs (the
bundled build is the slow step).

Memory-safety CI (`native-checks.yaml`: ASan containers running
`tools/sanitizer-exercise.R`, UBSan, valgrind, LTO, gctorture, rchk).
Its first run found a use-after-free in the compile error path and a
read past the end of the input in Vectorscan itself (patch 0005, \#4).
Original item: ASAN/UBSAN job (rocker `r-devel-san` or rhub2 actions),
valgrind spot-checks. External-pointer packages live and die by this.

Test-suite expansion (target: every exported function, every typed error
class). Done 2026-09-26: 49 tests, 187 expectations across
serialization, streams, callbacks, inputs and validation. It found that
deserialization lost the mode and the SOM flags (fixed). Callback errors
are caught with `R_tryEval()` and re-raised after the scan, so no
longjmp crosses Vectorscan; the ASan job exercises that path. -
serialization: round-trip equivalence,
[`hs_save()`](https://pedrobtz.github.io/vectorscan/reference/hs_save.md)/[`hs_load()`](https://pedrobtz.github.io/vectorscan/reference/hs_load.md),
corrupt-bytes error path, cross-mode deserialization. - streams: matches
spanning chunk boundaries, matches reported at
[`hs_stream_close()`](https://pedrobtz.github.io/vectorscan/reference/hs_stream_close.md),
scanning a closed stream, stream outliving its database (GC/finalizer
ordering). - callbacks: R error thrown inside a callback mid-scan
(longjmp through the C frame — verify no leak/corruption; if unsafe, fix
in Stage 2 with `R_UnwindProtect`). - inputs: empty strings, embedded
NULs via raw vectors, non-ASCII UTF-8, very large inputs, all
[`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
parameters actually affecting matches. - validation: one test per
`stop_vectorscan()` class.

Coverage reporting (`covr` via pedrobtz/r-actions, badge committed to
`.github/badges/coverage.svg`; no codecov).

`README` badges (R-CMD-check, native-checks, coverage; add r-universe
once live).

*Exit criteria: green matrix CI, clean sanitizer run, coverage
meaningfully tracked, no placeholder metadata.*

## Stage 2 — The R-native API: make it feel like R

*Goal: an R user who knows `stringr` is productive in five minutes. This
stage is the adoption driver — prioritize it over everything except
safety.*

**Vectorized scanning (the centerpiece)**

`hs_match(db, x)` — scan a character vector, return a tidy data frame:
`input` (element index), `id`/`pattern`, `from`, `to`, `match`
(extracted text). Implemented in C: loop over elements reusing one
scratch, no per-element R overhead.

`hs_detect(db, x)` — [`grepl()`](https://rdrr.io/r/base/grep.html) at
scale: logical vector (“any pattern hit?”) plus a variant returning
per-pattern results (element × pattern logical matrix or list-column).

`hs_count(db, x)` — match counts per element (respecting
`HS_FLAG_SINGLEMATCH` semantics where set).

`hs_extract(db, x)` — matched substrings; auto-enable
`HS_FLAG_SOM_LEFTMOST` when needed (with a documented opt-out, since SOM
costs compile-time/state).

**Ergonomics**

Named patterns: accept a named character vector or a data frame of rules
(`pattern`, `id`, `flags`, ext columns) in
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md);
carry names through to match output. This is how real rule sets (secret
scanners, IOC feeds) arrive.

One-call convenience:
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
on a bare character vector without pre-creating a database
([`hs_database()`](https://pedrobtz.github.io/vectorscan/reference/hs_database.md)
becomes optional plumbing).

Literal API: bind `hs_compile_lit_multi()` for massive literal
dictionaries (no regex escaping footguns, faster compiles).

Encoding correctness: document byte vs character offsets; provide
character-offset conversion for UTF-8 inputs (or return both).

Callback safety: wrap callback invocation with `R_UnwindProtect` so an
error inside an R callback cannot leak scratch/stream state.

Flag ergonomics: accept flag names as strings
(`flags = c("caseless", "som_leftmost")`) alongside integer constants.

Richer `print.hs_database`: pattern count, mode, database size.

**Deliverable docs**

Rewrite the “Getting started” vignette around the vectorized verbs;
relegate the low-level `hs_*` C-shaped API to a “low-level interface”
section/vignette.

*Exit criteria: a user can replace `grepl(paste(pats, collapse="|"), x)`
with two lines of vectorscan and get pattern-level attribution, matched
text, and a 10–100× speedup on large pattern sets.*

## Stage 3 — Performance, parallelism, and scale

*Goal: own the “fast” claim with receipts, and handle data that doesn’t
fit in memory.*

Scratch management for parallelism: expose `hs_scratch_clone()`
semantics so databases can be shared across threads/processes; document
(and test) the one-scratch-per-thread rule.

Parallel vectorized scan: optional OpenMP (or thread pool) over elements
in `hs_match()`/`hs_detect()` — Vectorscan scans are callback-driven C,
so true parallelism is feasible when no R callback is involved.

File/connection streaming helpers: `hs_scan_file(db, path, chunk_size)`
built on the streaming API — scan multi-GB logs without loading them;
line-number attribution for matches.

Database caching: pattern-set hashing +
[`hs_serialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_serialize.md)
to skip recompilation of large rule sets across sessions (compiles of
10k+ patterns are expensive).

Benchmark vignette v2: add `stringi` and `re2` (not just base R),
scaling curves (patterns × corpus size), compile-time vs scan-time
breakdown, memory footprint; publish results on the pkgdown site.

Micro-optimizations informed by profiling: match-buffer growth policy,
avoiding [`enc2utf8()`](https://rdrr.io/r/base/Encoding.html) copies for
already-UTF-8 vectors, ALTREP-aware string access.

*Exit criteria: published, reproducible benchmarks showing the crossover
points vs base R / stringi / re2; multi-GB file scanning works in
bounded memory.*

## Stage 4 — Distribution: CRAN and beyond

*Goal: `install.packages("vectorscan")` works everywhere R runs. This is
the hardest stage; start de-risking it early.*

Known blockers and their mitigations:

**Ragel**: not present on CRAN build machines. Pre-generate the ragel
outputs (`.rl` → `.cpp`) and vendor the generated sources, dropping
ragel from `SystemRequirements` entirely.

**Boost headers**: avoid requiring a system Boost. Options, in order of
preference: (a) point the CMake build at the `BH` package’s headers via
`LinkingTo: BH` + `BOOST_ROOT`; (b) vendor the small subset of Boost
headers Vectorscan actually uses.

**Tarball size**: 1.25 MB compressed (773 files) with Vectorscan 5.4.13,
measured 2026-09-26 – well under the ceiling, no pruning needed.
Original item: measure the compressed source tarball; prune the vendored
tree further (per-arch SIMD sources for platforms CRAN doesn’t ship,
cmake scaffolding). CRAN’s informal ceiling is ~5 MB — request an
exception with justification if pruning can’t get there.

**Build time**: CRAN checks time out; tune the bundled build (single
target, `-j2`, `FAT_RUNTIME=OFF` with baseline SIMD) and measure on the
slowest platform. Measured in CI on 2026-09-26: a single install with
the x86-64 fat runtime at `-j2` takes about 5 min; a full R CMD check
(two builds, `-j4`) 8 min on macOS, 11-17 min on Linux and 20 min on
Windows. Windows and Intel macOS already build without the fat runtime.

**Architecture coverage**: verify builds on CRAN’s actual fleet — x86-64
Linux/Windows (ucrt), macOS x86-64 + arm64 (NEON path). CI covers x86-64
Linux and Windows and arm64 macOS; Intel macOS is not exercised. Also
and decide behavior on unsupported arches (fail at install vs stub build
— CRAN will not accept a package whose examples/tests all skip, so
unsupported-arch policy must be explicit).

**Interim channel**: publish on r-universe now
(`pedrobtz.r-universe.dev`) for binary installs and continuous checks
before CRAN is feasible.

CRAN submission checklist: `cran-comments.md`, win-builder + mac-builder
runs, rhub2 sweep, `Additional_repositories`/`SystemRequirements`
accuracy, reverse-dependency-free first release.

Vendored-source upgrade policy: `tools/vendor/` (manifest pinned by
commit and sha256, keep list, patches in `tools/patches/`, `verify`),
the `vendor` guard and the `vendor-upstream` release watcher; updated to
5.4.13. Original item: Define the vendored-source upgrade policy: script
the sync from upstream (`tools/update-vendor.sh`), record the upstream
commit, track Vectorscan releases (5.4.x → current) and CVEs.

*Exit criteria: on CRAN (or documented, dated plan for the remaining
blockers), with r-universe binaries available meanwhile.*

## Stage 5 — Ecosystem integration and community

*Goal: be the obvious answer when someone asks “how do I match 10,000
patterns fast in R?”*

Use-case vignettes / pkgdown articles, each targeting a searchable
problem: - “Scanning logs for secrets and PII” (expand the benchmark
vignette’s rule set into a worked example). - “Matching IOC /
threat-intel feeds against network logs.” - “Dictionary and motif
scanning for text mining / bioinformatics.”

Interop sugar: examples (not hard dependencies) for `data.table`,
`dplyr`/`tidyr` list-column workflows, and `arrow`/duckdb pipelines
feeding `hs_scan_file()`.

Evaluate a **Chimera** add-on (Hyperscan’s PCRE hybrid, currently
excluded from the vendored tree): would bring capture groups and full
PCRE semantics — decide based on user demand, as it roughly doubles
build complexity.

Community scaffolding: `CONTRIBUTING.md`, issue templates, `NEWS.md`
discipline per release, lifecycle badges.

Announce: r-universe listing, R Weekly submission, a blog post built
around the benchmark story, rOpenSci soft-review consideration.

Track adoption: CRAN downloads, GitHub issues by theme — feed back into
roadmap re-prioritization.

*Exit criteria: organic issues/questions arriving from real users; the
package appears in search results for its target problems.*

------------------------------------------------------------------------

## Sequencing and priorities

    Stage 1 (foundation)  ──►  Stage 2 (R-native API)  ──►  Stage 3 (performance)
            │                                                      │
            └────────────►  Stage 4 (CRAN de-risking: start early, land late)
                                                                   │
                                                    Stage 5 (ecosystem) ◄┘

- Stages 1 → 2 are strictly ordered: don’t build the high-level API on
  an untested native layer.
- Stage 4’s de-risking spikes (ragel pre-generation, BH headers, tarball
  size measurement) should start during Stage 2 — if CRAN turns out to
  be impossible in the current shape, that changes vendoring decisions
  early.
- The single highest-leverage item in the whole plan is **`hs_match()` /
  `hs_detect()` over character vectors** (Stage 2). Without it the
  package is a niche C binding; with it, it answers a question thousands
  of R users actually have.

## Risks

| Risk | Impact | Mitigation |
|----|----|----|
| CRAN rejects the vendored build (size/time/toolchain) | No mainstream distribution | Stage 4 spikes early; r-universe as interim channel |
| Callback longjmp corrupts native state | Crashes, memory bugs | Stage 1 tests + Stage 2 `R_UnwindProtect` |
| Upstream Vectorscan divergence / CVEs | Stale, vulnerable vendored code | Scripted vendor sync + release tracking (Stage 4) |
| SIMD portability (new arches, old x86) | Install failures | Explicit arch policy + CI matrix (Stages 1, 4) |
| Single-maintainer bus factor | Stalled project | Community scaffolding (Stage 5), rOpenSci review |
