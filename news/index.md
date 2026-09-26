# Changelog

## vectorscan 0.0.0.9000

- An error raised inside a match callback now reaches the caller
  unchanged, with its own class and message; it used to become a generic
  “R callback failed” error.
- Errors from the Vectorscan library carry a class per error code
  (`vectorscan_error_db_mode`, `vectorscan_error_scratch_in_use`, …)
  under `vectorscan_error_native`, and compile errors are
  `vectorscan_error_compile` with the offending `expression` and the
  `reason`. See `?vectorscan-errors`.
- New `HS_MODE_SOM_HORIZON_LARGE`, `_MEDIUM` and `_SMALL`, needed for
  start offsets (`HS_FLAG_SOM_LEFTMOST`) in stream mode; a start beyond
  the horizon is `NA`.
- New
  [`hs_version()`](https://pedrobtz.github.io/vectorscan/reference/hs_available.md)
  and
  [`hs_stream_size()`](https://pedrobtz.github.io/vectorscan/reference/hs_stream_size.md).
- `hs_compile(literal = TRUE)` compiles plain strings instead of regular
  expressions (Vectorscan’s literal compiler): `"a.b"` matches only
  `"a.b"`.
- Flags can be written as letters or names: `flags = "i"`,
  `"caseless|dotall"`, also in a rules data frame’s `flags` column.
  [`hs_flags()`](https://pedrobtz.github.io/vectorscan/reference/hs_flags.md)
  does the conversion.
- New
  [`hs_read_patterns()`](https://pedrobtz.github.io/vectorscan/reference/hs_read_patterns.md)
  reads Hyperscan’s pattern files (`id:/regex/flags{ext}`, as used by
  `hsbench` and `hscollider`) into a rules data frame, with an `ext`
  list column for extended parameters. Rules data frames now take such
  an `ext` column.
- [`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
  keeps offsets beyond R’s integer range, up to 2^53, instead of turning
  them into `NA`.
- New
  [`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
  turns text into a data frame with one regular expression: one row per
  element, one column per capture group, named after named groups or
  typed by a `proto` as in
  [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html). It
  returns the same data frame as `strcapture(perl = TRUE)` about 20-27
  times faster on a million log lines, by matching with PCRE2 (with JIT)
  and filling the columns in C.
  [`hs_capture_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
  compiles a pattern once for reuse. See the “Parsing logs” article.
- [`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
  also takes several formats, for input that mixes them: each element is
  captured by the first format that matches, with a `pattern` column and
  the union of group columns by name. Vectorscan routes each element to
  the formats that can match it (prefilter mode), so PCRE2 runs only
  there: 2.7 times faster than trying 20 formats in order on a million
  lines.
- [`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
  gains `match_limit` and `depth_limit`, so a pathological line on
  untrusted input gives an `NA` row and a warning instead of a runaway
  match; warnings now name PCRE2’s error. An element that overflows the
  just-in-time compiler’s stack is retried in the interpreter, and
  `hs_capture_compile(jit = FALSE)` runs the interpreter throughout.
- PCRE2 is now part of the build, for the upcoming
  [`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md):
  a system PCRE2 (\>= 10.34) when available, else a bundled PCRE2 10.48
  compiled with its symbols hidden so it cannot clash with the PCRE2 R
  itself loads. `VECTORSCAN_PCRE2` selects the route.
- New vectorized verbs scan a whole character vector in one call:
  [`hs_detect()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  (like [`grepl()`](https://rdrr.io/r/base/grep.html) for many
  patterns),
  [`hs_count()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md),
  [`hs_match()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  (a data frame of every match with its pattern, offsets and text) and
  [`hs_extract()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md).
  They take a compiled block-mode database or the patterns themselves;
  given patterns,
  [`hs_match()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  and
  [`hs_extract()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  turn on start-of-match offsets automatically.
- [`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
  accepts named patterns and rules data frames (`pattern`, `id`,
  `flags`, `name`), and `hs_compile(patterns)` without a database
  returns a new block-mode database.
- Initial package implementation with native bindings for compiling
  databases, block scanning, vectored scanning, streaming, database
  metadata, and database serialization.
- The package now vendors the Vectorscan source and builds the native
  library from source by default during configuration.
- The bundled Vectorscan is updated to 5.4.13, which fixes a stack
  buffer overflow in `rvermicelliDoubleExecReal()`, an AVX-512 scanning
  bug, SVE accelerator bugs, an integer overflow, a wrong page-size
  assumption on Apple Silicon, and compiler errors with clang 21 and GCC
  15/16. Invalid character classes are now a compile error.
- Compile errors now report Vectorscan’s message correctly; it was read
  after being freed.
- [`hs_deserialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_deserialize.md)
  and
  [`hs_load()`](https://pedrobtz.github.io/vectorscan/reference/hs_load.md)
  now restore the database mode and the per-pattern flags, so a restored
  database reports matches exactly like the original (`from` stays `NA`
  for patterns compiled without `HS_FLAG_SOM_LEFTMOST`; it used to come
  back as `0`).
  [`hs_serialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_serialize.md)
  still returns plain Vectorscan bytes, with the pattern ids and flags
  attached as attributes.
  [`hs_save()`](https://pedrobtz.github.io/vectorscan/reference/hs_save.md)
  now writes a small tagged header (`VSCANRDB`) with that metadata
  before the bytes;
  [`hs_load()`](https://pedrobtz.github.io/vectorscan/reference/hs_load.md)
  reads both this format and plain Vectorscan files.
- `VECTORSCAN_USE_SYSTEM=true` without a system `libhs` now fails at
  configure, as the bundled build does, instead of silently building
  runtime stubs; set `VECTORSCAN_ALLOW_STUBS=true` to get the stubs.
- Fixed a read past the end of the input in the bundled Vectorscan
  (`vermicelliExec`), hit when a scan ends inside a run of a repeated
  character, for example `foo.*bar` over a chunk of `x`s in streaming
  mode. It could crash R if the input ended at a page boundary.
- On Windows and Intel macOS the bundled library is now built for
  x86-64-v2 (SSE4.2); x86-64 Linux keeps per-CPU dispatch. Linux
  distributions that install libraries to `lib64` (Fedora, RHEL,
  openSUSE) now build correctly.
