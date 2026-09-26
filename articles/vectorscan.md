# Getting started with vectorscan

`vectorscan` wraps
[Vectorscan](https://github.com/VectorCamp/vectorscan) (the portable
fork of Intel Hyperscan) so you can match many regular expressions
against text at high speed from R.

This vignette walks through the typical workflow:

1.  Build a database of patterns.
2.  Compile it.
3.  Scan some data.

``` r

library(vectorscan)
```

## A first match

A database holds one or more compiled patterns. Patterns are given as a
character vector, with optional ids and per-pattern flags.

``` r

db <- hs_database(mode = HS_MODE_BLOCK)
hs_compile(db, expressions = "foo")
db
#> <hs_database: compiled, block mode>
```

[`hs_scan()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan.md)
returns a data frame with one row per match event.

``` r

hs_scan(db, "look for foo in here")
#>   id from to flags
#> 1  0   NA 12     0
```

The `from` column is `NA` unless the pattern was compiled with
`HS_FLAG_SOM_LEFTMOST` (start-of-match). Vectorscan only tracks match
end-offsets by default; opting in to start-of-match has a small cost.

## Multiple patterns with ids and flags

Each pattern can carry its own integer id (so you can tell matches
apart) and its own flags. Flags can be combined with
[`bitwOr()`](https://rdrr.io/r/base/bitwise.html) or `|`.

``` r

db <- hs_database()
hs_compile(
  db,
  expressions = c("foo", "^foobar$", "BAR"),
  ids = c(10L, 20L, 30L),
  flags = c(
    HS_FLAG_NONE,
    HS_FLAG_NONE,
    HS_FLAG_CASELESS | HS_FLAG_SOM_LEFTMOST
  )
)

hs_scan(db, "foobar")
#>   id from to flags
#> 1 10   NA  3     0
#> 2 30   NA  6     0
#> 3 20   NA  6     0
```

Pattern `30` was compiled with `HS_FLAG_SOM_LEFTMOST`, so its `from`
offset is populated; the others report `NA`.

## Handling matches with a callback

For low-allocation processing, pass a callback. It is invoked once per
match with `(id, from, to, flags, context)`. Return `TRUE` to stop
scanning early.

``` r

db <- hs_database()
hs_compile(db, c("foo", "bar"))

hs_scan(
  db,
  "foo and bar and foo again",
  callback = function(id, from, to, flags, context) {
    context$hits <- context$hits + 1L
    cat(sprintf("match id=%d at offset %d\n", id, to))
    FALSE
  },
  context = new.env()
)
#> match id=0 at offset 3
#> match id=1 at offset 11
#> match id=0 at offset 19
```

## Vectored and streaming modes

Vectored mode treats a list of buffers as one logical input.

``` r

db <- hs_database(HS_MODE_VECTORED)
hs_compile(db, "foobar")
hs_scan_vector(db, c("foo", "bar"))
#>   id from to flags
#> 1  0   NA  6     0
```

Streaming mode keeps scan state across arbitrarily many chunks, which is
useful when input arrives over time or is too large to hold in memory.

``` r

db <- hs_database(HS_MODE_STREAM)
hs_compile(db, "foo.*bar")

stream <- hs_stream_open(db)
hs_stream_scan(stream, "foo")
#> [1] id    from  to    flags
#> <0 rows> (or 0-length row.names)
hs_stream_scan(stream, " and then bar")
#>   id from to flags
#> 1  0   NA 16     0
hs_stream_close(stream)
#> [1] id    from  to    flags
#> <0 rows> (or 0-length row.names)
```

Always close a stream when done; the close step also reports any pending
matches.

## Saving a compiled database

Compiling can be expensive. Serialize once and reload later:

``` r

db <- hs_database()
hs_compile(db, "foo")

path <- tempfile(fileext = ".hsdb")
hs_save(db, path)

restored <- hs_load(path)
hs_scan(restored, "foo")
#>   id from to flags
#> 1  0    0  3     0
```

## A real-world example: scanning text for secrets and PII

This is where Vectorscan earns its keep. A typical secret-scanner,
log-rule engine, or SIEM workload looks like:

- **Many** patterns (tens, hundreds, thousands).
- One large body of text (a log file, a git diff, a network payload).
- You want **all** matches with type labels, ideally in one pass.

Base R would compile each regex separately and walk the text once per
pattern: O(N_patterns × len(text)). Vectorscan compiles all patterns
into a single automaton and walks the text **once**.

### Set up a catalogue of patterns

We tag each pattern with a stable integer `id` and a human-readable
`label`, then compile them as a batch. `HS_FLAG_SOM_LEFTMOST` is added
to every pattern so we can recover the start offset and extract the
matched substring.

``` r

patterns <- data.frame(
  id = 1:7,
  label = c(
    "email", "ipv4", "credit_card", "aws_access_key",
    "github_pat", "jwt", "us_phone"
  ),
  regex = c(
    "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
    "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
    "\\b(?:[0-9]{4}[ -]?){3}[0-9]{4}\\b",
    "\\b(?:AKIA|ASIA)[0-9A-Z]{16}\\b",
    "ghp_[0-9A-Za-z]{36}",
    "eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+",
    "\\b[0-9]{3}[-.][0-9]{3}[-.][0-9]{4}\\b"
  ),
  base_flags = c(
    HS_FLAG_CASELESS, HS_FLAG_NONE, HS_FLAG_NONE, HS_FLAG_NONE,
    HS_FLAG_NONE, HS_FLAG_NONE, HS_FLAG_NONE
  ),
  stringsAsFactors = FALSE
)

db <- hs_database()
hs_compile(
  db,
  expressions = patterns$regex,
  ids = patterns$id,
  flags = bitwOr(patterns$base_flags, HS_FLAG_SOM_LEFTMOST)
)

hs_database_size(db)
#> [1] 27968
```

### Scan a payload

``` r

text <- paste(
  "User signed up: alice@Example.COM from 192.168.1.42.",
  "Stripe webhook: card 4242 4242 4242 4242 charged.",
  "Leaked creds: AKIAIOSFODNN7EXAMPLE and",
  "  ghp_1234567890abcdefghijklmnopqrstuvwxyz.",
  "Support call: 415-555-0199.",
  "JWT: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.dozjgNryP4J3jVmNHl0w5N",
  sep = "\n"
)

hits <- hs_scan(db, text)
head(hits)
#>   id from  to flags
#> 1  1   16  32     0
#> 2  1   16  33     0
#> 3  2   39  51     0
#> 4  3   74  93     0
#> 5  4  117 137     0
#> 6  5  144 184     0
```

### Turn match events into a useful result

Vectorscan reports a match event at every position where a pattern
*ends*, so a pattern with repetition (like the email’s `{2,}` TLD
quantifier) can produce multiple events at the same start offset, one
per accepted end. Most applications want the **longest** match per
`(id, start)` pair. A two-line post-process gives that, plus the
extracted substring and the human label:

``` r

hits <- hits[order(hits$id, hits$from, -hits$to), ]
hits <- hits[!duplicated(hits[, c("id", "from")]), ]

hits$label <- patterns$label[match(hits$id, patterns$id)]
hits$matched <- substring(text, hits$from + 1L, hits$to)

hits[, c("label", "from", "to", "matched")]
#>             label from  to
#> 2           email   16  33
#> 3            ipv4   39  51
#> 4     credit_card   74  93
#> 5  aws_access_key  117 137
#> 6      github_pat  144 184
#> 29            jwt  219 278
#> 7        us_phone  200 212
#>                                                        matched
#> 2                                            alice@Example.COM
#> 3                                                 192.168.1.42
#> 4                                          4242 4242 4242 4242
#> 5                                         AKIAIOSFODNN7EXAMPLE
#> 6                     ghp_1234567890abcdefghijklmnopqrstuvwxyz
#> 29 eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.dozjgNryP4J3jVmNHl0w5N
#> 7                                                 415-555-0199
```

Offsets are 0-based and `[from, to)` is half-open, which is why we use
`from + 1L` when indexing into the R string.

### Why this scales

To see why this matters for real workloads, scale the payload up and
compare against running each pattern separately with base R.

``` r

big_text <- paste(rep(text, 2000), collapse = "\n")
nchar(big_text)
#> [1] 557999

# Vectorscan: one pass, all patterns at once.
vs_time <- system.time({
  vs_hits <- hs_scan(db, big_text)
})

# Base R: one pass per pattern.
base_time <- system.time({
  base_hits <- lapply(patterns$regex, function(re) {
    regmatches(big_text, gregexpr(re, big_text, perl = TRUE))[[1]]
  })
})

vs_time["elapsed"]
#> elapsed 
#>   0.006
base_time["elapsed"]
#> elapsed 
#>   0.021
```

The gap widens as you add more patterns. With a hundred rules (realistic
for a log-rule engine) the base-R approach pays the linear factor in
pattern count, while Vectorscan stays close to flat: its automaton
already encodes all of them.

### Notes on pattern syntax

Vectorscan accepts a PCRE-like syntax with a few important restrictions:

- **No backreferences** (e.g. `\1`).
- **No general lookaround** (lookahead/lookbehind not supported in the
  default mode; `HS_FLAG_PREFILTER` exists for limited cases).
- Capture groups are allowed but **not returned** — only the overall
  match offsets are reported.
- A pattern can match at multiple end positions, as shown above — plan
  for it in post-processing.

If a regex is rejected at compile time,
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
raises an informative R condition with the offending expression index.

## Next steps

- See
  [`?hs_compile`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
  for the full list of flags.
- See
  [`?hs_ext`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
  for extended parameters such as `min_length` and `edit_distance` for
  approximate matching.
- See `vectorscan-constants` for `HS_FLAG_*` and `HS_MODE_*` values.
