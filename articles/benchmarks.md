# Benchmarking vectorscan against R's regex engines

This vignette compares `vectorscan` against R’s built-in regular
expression engines on workloads where multi-pattern matching matters.
The goal is to show **where Vectorscan wins, where it doesn’t, and why**
— not to oversell it.

R ships with two regex engines reachable from base R:

- **TRE**, the default (`grepl`, `gregexpr`, `regmatches`).
- **PCRE**, opted in with `perl = TRUE`.

Both walk the input text once per pattern. Vectorscan compiles all
patterns into one automaton and walks the text **once**, regardless of
pattern count. That is the structural difference these benchmarks
exercise.

``` r

library(vectorscan)
```

## A small benchmarking helper

We avoid taking a hard dependency on `bench` or `microbenchmark` and
instead measure with
[`system.time()`](https://rdrr.io/r/base/system.time.html) repeated a
few times. The median of `n` runs is reported in seconds.

``` r

time_it <- function(expr, n = 5L) {
  expr <- substitute(expr)
  env <- parent.frame()
  times <- replicate(n, system.time(eval(expr, env))[["elapsed"]])
  median(times)
}
```

## A realistic pattern catalogue

The same secret/PII-detection patterns from the introductory vignette.
We then pad the set with synthetic literal patterns so we can study how
each engine scales as the rule count grows. The filler patterns are
literals that do not occur in the corpus — i.e. the engines do real work
but report no matches, isolating the *cost of looking*.

``` r

real_patterns <- c(
  "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
  "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
  "\\b(?:[0-9]{4}[ -]?){3}[0-9]{4}\\b",
  "\\b(?:AKIA|ASIA)[0-9A-Z]{16}\\b",
  "ghp_[0-9A-Za-z]{36}",
  "eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+",
  "\\b[0-9]{3}[-.][0-9]{3}[-.][0-9]{4}\\b"
)

make_patterns <- function(n_extra) {
  filler <- sprintf("ZZZ_FILLER_%05d_NEEDLE", seq_len(n_extra))
  c(real_patterns, filler)
}
```

## A corpus

Roughly 200 KB of mixed text. Large enough that per-pass cost dominates
and small enough that the vignette builds quickly.

``` r

seed_text <- paste(
  "User signed up: alice@example.com from 192.168.1.42.",
  "Card on file: 4242 4242 4242 4242. Phone: 415-555-0199.",
  "Leaked key: AKIAIOSFODNN7EXAMPLE.",
  "Token: ghp_1234567890abcdefghijklmnopqrstuvwxyz.",
  "JWT: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.dozjgNryP4J3jVmNHl0w5N",
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
  "The quick brown fox jumps over the lazy dog.",
  sep = "\n"
)
corpus <- paste(rep(seed_text, 500), collapse = "\n\n")
nchar(corpus)
#> [1] 179998
```

## Benchmark 1 — scaling with the number of patterns

We grow the rule set from 7 to ~1000 and time the matching phase for
each engine. Vectorscan’s compile cost is measured separately below;
this benchmark times **scanning only**.

``` r

n_extra_grid <- c(0L, 25L, 100L, 500L)

scan_one_engine <- function(engine, patterns, text) {
  switch(engine,
    vectorscan = {
      db <- hs_database()
      hs_compile(db, expressions = patterns)
      time_it(hs_scan(db, text))
    },
    base_pcre = time_it(
      lapply(patterns, function(p) gregexpr(p, text, perl = TRUE))
    ),
    base_tre = time_it(
      lapply(patterns, function(p) gregexpr(p, text))
    )
  )
}

results <- do.call(rbind, lapply(n_extra_grid, function(n_extra) {
  patterns <- make_patterns(n_extra)
  data.frame(
    n_patterns = length(patterns),
    vectorscan = scan_one_engine("vectorscan", patterns, corpus),
    base_pcre  = scan_one_engine("base_pcre",  patterns, corpus),
    base_tre   = scan_one_engine("base_tre",   patterns, corpus)
  )
}))

results
#>   n_patterns vectorscan base_pcre base_tre
#> 1          7      0.002     0.010    0.023
#> 2         32      0.002     0.010    0.074
#> 3        107      0.002     0.011    0.226
#> 4        507      0.002     0.014    1.028
```

Compute throughput in MB/s so the columns are easy to read.

``` r

mb <- nchar(corpus) / 1024 / 1024
throughput <- data.frame(
  n_patterns = results$n_patterns,
  vectorscan_mb_s = round(mb / results$vectorscan, 1),
  base_pcre_mb_s  = round(mb / results$base_pcre,  1),
  base_tre_mb_s   = round(mb / results$base_tre,   1)
)
throughput
#>   n_patterns vectorscan_mb_s base_pcre_mb_s base_tre_mb_s
#> 1          7            85.8           17.2           7.5
#> 2         32            85.8           17.2           2.3
#> 3        107            85.8           15.6           0.8
#> 4        507            85.8           12.3           0.2
```

You should see Vectorscan stay roughly flat as rules grow, while the
base-R columns degrade roughly linearly with `n_patterns`. That is the
whole point of compiling N patterns into one automaton.

## Benchmark 2 — scaling with corpus size

Fix the rule set, grow the corpus. Both engines should scale linearly in
input size; the differentiator is the constant factor and the allocation
behaviour.

``` r

patterns <- make_patterns(50L)
sizes <- c(1L, 5L, 25L, 100L) # multiplier on seed_text repetitions

size_results <- do.call(rbind, lapply(sizes, function(mult) {
  text <- paste(rep(seed_text, 500L * mult), collapse = "\n")

  db <- hs_database()
  hs_compile(db, expressions = patterns)

  data.frame(
    corpus_kb = round(nchar(text) / 1024, 1),
    vectorscan_s = time_it(hs_scan(db, text), n = 3L),
    base_pcre_s  = time_it(
      lapply(patterns, function(p) gregexpr(p, text, perl = TRUE)),
      n = 3L
    )
  )
}))

size_results
#>   corpus_kb vectorscan_s base_pcre_s
#> 1     175.3        0.002       0.010
#> 2     876.5        0.009       0.050
#> 3    4382.3        0.053       0.247
#> 4   17529.3        0.203       0.977
```

## Benchmark 3 — compile cost is amortizable

Vectorscan’s compile step is non-trivial — it builds an NFA, optimizes,
and emits a JIT-friendly database. For interactive one-off queries that
cost can dominate. For any repeated workload it is a one-time fee, and
you can avoid even paying it once per process by serializing the
compiled database to disk.

``` r

patterns <- make_patterns(200L)

compile_time <- time_it({
  db <- hs_database()
  hs_compile(db, expressions = patterns)
}, n = 3L)

scan_time <- time_it(hs_scan(db, corpus), n = 5L)

path <- tempfile(fileext = ".hsdb")
hs_save(db, path)

load_time <- time_it(hs_load(path), n = 5L)

data.frame(
  step = c("compile", "save+load", "scan once"),
  seconds = round(c(compile_time, load_time, scan_time), 4)
)
#>        step seconds
#> 1   compile   0.028
#> 2 save+load   0.000
#> 3 scan once   0.002
```

In a real deployment you compile patterns once,
[`hs_save()`](https://pedrobtz.github.io/vectorscan/reference/hs_save.md)
the result, ship the file with your app, and
[`hs_load()`](https://pedrobtz.github.io/vectorscan/reference/hs_load.md)
it at startup. The per-scan number is the only one that runs in your hot
path.

## Benchmark 4 — callback vs. data frame collection

[`hs_scan()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan.md)
supports two output modes: collect every match into a data frame (the
default), or invoke an R callback per match. Intuitively the callback
sounds cheaper because it avoids building a data frame, but each
invocation crosses the C → R boundary and pays interpreter cost per
event. Let’s measure.

``` r

patterns <- make_patterns(50L)
db <- hs_database()
hs_compile(db, expressions = patterns)

cb_time <- time_it({
  ctx <- new.env()
  ctx$n <- 0L
  hs_scan(db, corpus,
    callback = function(id, from, to, flags, context) {
      context$n <- context$n + 1L
      FALSE
    },
    context = ctx
  )
}, n = 5L)

df_time <- time_it(hs_scan(db, corpus), n = 5L)

data.frame(
  mode = c("callback (counts only)", "data frame (collects all)"),
  seconds = round(c(cb_time, df_time), 4)
)
#>                        mode seconds
#> 1    callback (counts only)   0.121
#> 2 data frame (collects all)   0.002
```

On this corpus the data-frame path is dramatically faster — match
collection happens entirely in C, while the callback path pays the C → R
round-trip per match event. The callback is still the right tool when:

- You want **early termination** (return `TRUE` to stop scanning).
- The match set is enormous and you only need to fold over it (counts,
  sketches, sampling) without ever materializing it.
- You want to stream matches into another system as they arrive.

For everything else — including “just count them” — let the data frame
form and call [`nrow()`](https://rdrr.io/r/base/nrow.html).

## When Vectorscan is **not** the right tool

It is worth being explicit about where Vectorscan does not help or
actively hurts:

- **One simple pattern, one short string.** Base R or `stringi` is
  smaller, faster to set up, and has no native dependency.
- **You need capture groups.** Vectorscan reports overall match offsets
  only — it does not return capture text. Use PCRE.
- **You need backreferences or lookaround.** Not supported by
  Vectorscan’s core matcher. Use PCRE.
- **Replacement, not matching.** Vectorscan finds matches; it does not
  rewrite text. Combine with R-level substitution.
- **Pattern set changes per call.** If you cannot reuse a compiled
  database, the compile cost dominates and the comparison flips.

Vectorscan’s sweet spot is the opposite shape: **a stable, large rule
set scanned against a high volume of text**, which is exactly the
workload of log analysis, intrusion detection, secret scanners, and
network DPI — the use cases it was built for.

## Notes on methodology

A few things to keep in mind when reading these numbers:

- Times depend on CPU model and SIMD width. Vectorscan benefits more
  from AVX2/AVX-512 than base R does.
- The filler patterns are literal strings that never match. Different
  pattern shapes (anchored regexes, large alternations, Unicode classes)
  shift the absolute numbers, but the *scaling* story is the same.
- [`system.time()`](https://rdrr.io/r/base/system.time.html) is coarse;
  for serious benchmarking use `bench::mark()` or
  `microbenchmark::microbenchmark()`. The structural differences between
  engines are large enough that even a coarse measurement surfaces them
  clearly.
- Vectorscan reports a match *event* per accepted end offset; base R
  reports a single span per match. The engines are not strictly doing
  the same work, but for typical “find all hits” tasks the comparison is
  fair after the dedupe pass shown in the introductory vignette.
