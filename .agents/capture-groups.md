# Capture groups — plan

Status: M0 done, backend decided (2026-09-26). Tracks roadmap Stage 2b.

## Goal

Turn text into columns with one regex, at least 10× faster than base R:

```r
fmt <- "^(?<timestamp>\\S+ \\S+) \\[(?<level>\\w+)\\] (?<location>[^ :]+):(?<line>\\d+) - (?<text>.*)$"
log <- hs_capture(fmt, readLines("app.log"),
                  proto = data.frame(timestamp = character(), level = character(),
                                     location = character(), line = integer(),
                                     text = character()))
```

`log` is a data frame with one row per line and one column per capture
group, as `utils::strcapture()` returns.

## M0 — benchmark gate (done)

A synthetic log of 1,000,000 lines (72 MB) in the format above, with either
every line matching or 1% matching. macOS arm64, R 4.6.1; the times cover
matching plus reading every group's offsets.

| 1M lines | all lines match | 1% match |
|---|---|---|
| `utils::strcapture(perl = TRUE)` | 12.5 s | 5.7 s |
| `regexec(perl = TRUE)` alone | 6.3 s | 0.73 s |
| `grepl(perl = TRUE)` (match only, no groups) | 0.23 s | 0.10 s |
| C loop + PCRE2 10.48 with JIT | **0.13 s** | 0.07 s |
| C loop + Chimera (Hyperscan prefilter + PCRE 8.45) | 0.99 s | **0.06 s** |

What that shows:

- Base R's time goes into building R objects, not into matching. `regexec()`
  allocates a vector per element, and `regmatches()`, the data-frame
  assembly and type conversion add the rest. PCRE2 itself matches the million
  lines in 0.23 s.
- A C loop that matches and writes the columns directly is 10-100× faster
  than `strcapture()`, whichever engine does the matching.
- Where every line matches, the main case, PCRE2 with JIT is 7.5× faster
  than Chimera. Chimera runs its Hyperscan pass and then PCRE1, whose JIT
  code is lost when Chimera copies the bytecode into its database.
- Chimera wins only when few lines match, and only slightly.

**Decision: `hs_capture()` runs on PCRE2 directly.** No Chimera, no
end-of-life PCRE1. For rule sets and low-match inputs, Vectorscan becomes our
own prefilter in front of PCRE2 (M4): Chimera's idea, on a maintained engine,
under our control. Chimera stays shelved unless upstream's PCRE2-based 5.5
changes the numbers above.

The benchmark scripts are in `tools/bench-capture/`. M3 turns them into a
benchmark vignette section.

## Decisions

- **PCRE2, preferably the one R itself uses.**
  - Windows: Rtools ships a static `libpcre2-8` and its headers (R for
    Windows is built with it); link `-lpcre2-8` with `PCRE2_STATIC`.
  - Linux and macOS: `pkg-config libpcre2-8` or `pcre2-config`. On Linux
    this is the same shared library R loads.
  - Fallback: vendored PCRE2 10.48, the library subset with its JIT (about
    0.57 MB compressed), compiled by R's make from an explicit object list;
    no CMake.
- **The vendored fallback hides its symbols.** On Linux, R has already loaded
  the system `libpcre2-8.so`. A second, statically linked PCRE2 in our `.so`
  with the same exported names could have its calls resolved to R's copy, a
  different version with different internals, which can crash. So the
  vendored copy is compiled with hidden visibility (`-fvisibility=hidden`,
  `PCRE2_EXP_DECL` / `PCRE2_EXP_DEFN` overridden). macOS's two-level
  namespace and Windows DLLs do not have this problem, but the same build is
  used everywhere.
- **JIT when available, interpreter otherwise.** `pcre2_jit_compile()`
  failing (a PCRE2 built without JIT, or JIT memory refused) falls back to the
  interpreter silently; only speed changes. `hs_capture_info()` (or
  `extSoftVersion()`-style output) reports which one is in use.
- **Semantics are PCRE2's.** Base R's `regexec(perl = TRUE)` is PCRE2 too, so
  results can be tested for exact equality against it.
- **Nothing downloaded at install.** The vendored fallback follows the
  existing `tools/vendor/` layout (a second source in the manifest, keep list,
  sha256, `verify`).

## Architecture

```
R:        hs_capture()                    hs_detect() / hs_match() (existing)
            |                                  |
C glue:   vctrsn_pcre2_compile              vctrsn_hs_scan_many (existing)
          vctrsn_pcre2_capture_many  <----  optional prefilter (M4)
            |
PCRE2:    system libpcre2-8 (Rtools / pkg-config) or vendored 10.48 (hidden)
```

`vctrsn_pcre2_capture_many()` follows `vctrsn_hs_scan_many()`:

- one `pcre2_match_data` per call;
- output columns allocated up front and filled in place, so there are no
  per-match R objects;
- `NA_STRING` for elements that do not match and for unset groups;
- interrupts checked through `R_ToplevelExec()` every 1,024 elements.

## Milestones

One PR each; each ends with the full CI profile green (`full-ci` label).

### M1 — PCRE2 in the build

- `configure`: find PCRE2 (`pkg-config libpcre2-8`, then `pcre2-config`),
  else build the vendored copy.
- `configure.win`: Rtools' `-lpcre2-8` with `-DPCRE2_STATIC`, else the
  vendored copy.
- `tools/vendor`: `pcre2` as a second source, pinned to 10.48:
  - keep list: the library `src/pcre2_*.c` files, `deps/sljit`, and the
    generated-file inputs (`pcre2.h.generic`, `config.h.generic`,
    `pcre2_chartables.c.dist`);
  - patches, if any, and COPYRIGHTS / Authors@R entries.
- A `VECTORSCAN_PCRE2` environment variable (`system` or `vendored`) forces
  one route. `build-modes.yaml` gains a job that builds the vendored route
  where a system PCRE2 is also installed, which is exactly the
  symbol-collision setting.
- A trivial C entry point (PCRE2 version and whether JIT is on) is the smoke
  test.
- Exit: the package builds on every platform by both routes, the smoke test
  passes, and `nm` shows no exported `pcre2_*` symbols in the vendored build.

### M2 — C capture loop

- `vctrsn_pcre2_compile()`: `pcre2_compile()` (UTF on) plus
  `pcre2_jit_compile()`, behind a finalizer, with the capture count and the
  group names (`PCRE2_INFO_NAMETABLE`).
- `vctrsn_pcre2_capture_many()`: the loop described above.
- Differential test against `regexec(perl = TRUE)` on random patterns and
  inputs: the same elements match, with identical group offsets and text.
- Exit: the differential test passes, and ASan, UBSan and valgrind are clean
  (added to `tools/sanitizer-exercise.R`).

### M3 — R API and performance

- `hs_capture(pattern, x, proto = NULL)`:
  - Column names come from named groups, else from `proto`, else `V1`,
    `V2`, ...
  - Column types come from `proto`, as `utils::strcapture()` converts them.
  - A non-matching element, and `NA` input, gives an `NA` row.
- A compiled form for reuse, parallel to `hs_compile()`.
- Docs: `?hs_capture`, a "Parsing logs" article, README, NEWS.
- Benchmark section in the benchmarks vignette, using the M0 data.
- Exit: identical output to `strcapture()` on the tests, and at least 10×
  faster on the 1M-line benchmark, all lines matching.

### M4 — Vectorscan prefilter and rule sets

- `hs_capture(rules, x)` with several formats: Vectorscan's `hs_match()`
  routes each line to the formats it can match, and PCRE2 captures only
  there. The output is a `pattern` column plus the union of group columns.
- A prefilter for a single pattern when it pays off, for low-match inputs:
  the same Vectorscan-then-PCRE2 split Chimera makes.
- Exit: beats plain PCRE2 on the 1% benchmark and on a many-format rule set,
  and is no slower when all lines match.

### M5 — Hardening

- `match_limit` / `depth_limit` through a PCRE2 match context. A limit hit
  gives an `NA` row plus a warning, never an abort.
- Invalid UTF-8 input: validate once per element, and choose between an `NA`
  row with a warning and `PCRE2_MATCH_INVALID_UTF` (PCRE2 >= 10.34) to match
  around bad bytes.
- JIT unavailable and JIT stack exhaustion: interpreter fallback, tested.
- Exit: sanitizers and valgrind clean on 1M lines including pathological
  patterns and invalid UTF-8.

## Open questions

1. **Multiple patterns** land in M4. Is a union of columns plus a `pattern`
   column the right shape, or a list of data frames, one per format?
2. **Invalid UTF-8** (M5): an `NA` row with a warning, or match around it?
3. **Limits**: PCRE2's defaults (match limit 10,000,000; depth limit, which
   is a heap limit in PCRE2 10.30+) or tighter defaults for untrusted logs?

## Risks

- **Symbol collision with R's PCRE2** (vendored route on Linux): prevented by
  hidden visibility, and tested by the M1 build-modes job and `nm`.
- **System PCRE2 version spread** (roughly 10.34-10.48 across distributions):
  require a minimum, 10.34 for `PCRE2_MATCH_INVALID_UTF`, else fall back to
  the vendored copy.
- **JIT policy**: some hardened systems forbid executable memory, so JIT
  compilation fails. The interpreter fallback keeps results identical, only
  slower.

## Not chosen

- **Chimera** (Hyperscan prefilter + PCRE 8.45): 7.5× slower than PCRE2 with
  JIT when all lines match (M0), and it would bundle end-of-life PCRE1 plus
  its own patches (CMake 4, `-Werror`, an unqualified `std::move`).
  Reconsider if Vectorscan 5.5 moves Chimera to PCRE2 and M0's numbers change.
- **Calling R's own PCRE2 symbols directly** (on macOS they are inside
  `libR.dylib`): not part of R's API, and no headers ship with R.
