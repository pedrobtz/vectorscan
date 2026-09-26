# Package index

## Matching character vectors

- [`hs_detect()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  [`hs_count()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  [`hs_match()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  [`hs_extract()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
  : Vectorized matching over a character vector

## Capture groups

- [`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
  [`hs_capture_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
  : Capture groups into a data frame

## Database lifecycle

- [`hs_database()`](https://pedrobtz.github.io/vectorscan/reference/hs_database.md)
  : Create a Vectorscan database handle
- [`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
  : Compile expressions into a database
- [`hs_info()`](https://pedrobtz.github.io/vectorscan/reference/hs_info.md)
  : Get database information
- [`hs_database_size()`](https://pedrobtz.github.io/vectorscan/reference/hs_database_size.md)
  : Get database size

## Scanning

- [`hs_scan()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan.md)
  : Scan one block of data
- [`hs_scan_vector()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan_vector.md)
  : Scan vectored data

## Streaming

- [`hs_stream_open()`](https://pedrobtz.github.io/vectorscan/reference/hs_stream_open.md)
  : Open a stream
- [`hs_stream_scan()`](https://pedrobtz.github.io/vectorscan/reference/hs_stream_scan.md)
  : Scan a stream chunk
- [`hs_stream_close()`](https://pedrobtz.github.io/vectorscan/reference/hs_stream_close.md)
  : Close a stream
- [`hs_stream_size()`](https://pedrobtz.github.io/vectorscan/reference/hs_stream_size.md)
  : Size of a stream's state

## Serialization

- [`hs_serialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_serialize.md)
  : Serialize a database
- [`hs_deserialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_deserialize.md)
  : Deserialize a database
- [`hs_save()`](https://pedrobtz.github.io/vectorscan/reference/hs_save.md)
  : Save a serialized database
- [`hs_load()`](https://pedrobtz.github.io/vectorscan/reference/hs_load.md)
  : Load a serialized database

## Helpers

- [`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
  : Create extended expression parameters
- [`hs_flags()`](https://pedrobtz.github.io/vectorscan/reference/hs_flags.md)
  : Flags from letters or names
- [`hs_read_patterns()`](https://pedrobtz.github.io/vectorscan/reference/hs_read_patterns.md)
  : Read a Hyperscan pattern file
- [`hs_available()`](https://pedrobtz.github.io/vectorscan/reference/hs_available.md)
  [`hs_version()`](https://pedrobtz.github.io/vectorscan/reference/hs_available.md)
  : Is Vectorscan or Hyperscan available?
- [`HS_FLAG_NONE`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_CASELESS`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_DOTALL`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_MULTILINE`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_SINGLEMATCH`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_ALLOWEMPTY`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_UTF8`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_UCP`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_PREFILTER`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_SOM_LEFTMOST`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_COMBINATION`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_FLAG_QUIET`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_MODE_BLOCK`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_MODE_STREAM`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_MODE_VECTORED`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_MODE_SOM_HORIZON_LARGE`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_MODE_SOM_HORIZON_MEDIUM`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  [`HS_MODE_SOM_HORIZON_SMALL`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
  : Vectorscan and Hyperscan constants
- [`vectorscan-errors`](https://pedrobtz.github.io/vectorscan/reference/vectorscan-errors.md)
  : Errors raised by vectorscan
