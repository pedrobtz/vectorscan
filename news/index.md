# Changelog

## vectorscan 0.0.0.9000

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
