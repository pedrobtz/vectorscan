#!/usr/bin/env Rscript
#
# Exercise the C layer under a sanitizer, using nothing but base R.
#
# The sanitizer jobs care about the compiled code: memory errors, undefined
# behaviour, and leaks on the unwind path. They do not care about testthat's
# assertions, and depending on testthat would make the ASan containers build
# it and its dependencies from source under a sanitizer. So this script has
# no dependencies at all.
#
# It spends most of its effort on error paths. An R error is a longjmp out of
# the C layer: a failed compile raises after Vectorscan has allocated a
# compile error, and an error in a scan callback is caught by R_tryEval and
# re-raised once the scan has returned. Anything those paths fail to free is
# what a leak checker is best placed to catch.
#
# Usage:  Rscript tools/sanitizer-exercise.R

library(vectorscan)

if (!hs_available()) {
  stop("vectorscan was built without Vectorscan; nothing to exercise.")
}

failures <- 0L
checked <- 0L

check <- function(label, expr) {
  checked <<- checked + 1L
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    message("  ERROR in ", label, ": ", conditionMessage(e))
    FALSE
  })
  if (!ok) {
    failures <<- failures + 1L
    message("  FAILED: ", label)
  }
  invisible(ok)
}

# An R error is expected on these paths; a crash is not, and the sanitizer
# reports memory problems independently of what this returns.
raises <- function(expr) {
  tryCatch(
    {
      force(expr)
      FALSE
    },
    error = function(e) TRUE
  )
}

cat("-- compile, including every error path ---------------------------\n")

good <- list(
  "foo",
  c("foo", "bar", "baz"),
  "^foobar$",
  "a.*b",
  "[a-z]+[0-9]{2,4}",
  "(foo|bar)+baz",
  paste0("w", 1:200),
  "\\bword\\b",
  "café"
)
for (expr in good) {
  db <- hs_database()
  hs_compile(db, expr)
  check(paste("compile", expr[[1]]), hs_database_size(db) > 0)
}

bad <- c("(", "[a-", "a{2,1}", "(?<name", "\\", "a**")
for (expr in bad) {
  db <- hs_database()
  check(paste("compile error", expr), raises(hs_compile(db, expr)))
  # a database whose compile failed must still be collectable
}
db <- hs_database()
check("error in second of many", raises(hs_compile(db, c("ok", "(", "fine"))))

cat("-- block scans ---------------------------------------------------\n")

db <- hs_database()
hs_compile(
  db,
  c("foo", "bar", "o+", "^f"),
  flags = c(HS_FLAG_NONE, HS_FLAG_SOM_LEFTMOST, HS_FLAG_NONE, HS_FLAG_CASELESS)
)
inputs <- list(
  "",
  "foobar",
  "FOOBAR",
  strrep("foo", 10000),
  charToRaw("foobar"),
  as.raw(0:255),
  "日本語 foo"
)
for (x in inputs) {
  check("scan returns a data frame", is.data.frame(hs_scan(db, x)))
}

cat("-- callbacks, including errors and early termination -------------\n")

check("callback counts", {
  n <- hs_scan(db, "foobar", callback = function(id, from, to, flags, ctx) {
    FALSE
  })
  n > 0
})
check("callback terminates", {
  hs_scan(db, "foobar", callback = function(...) TRUE) == 1L
})
for (i in 1:50) {
  check(
    "callback error",
    raises(hs_scan(
      db,
      strrep("foobar", 100),
      callback = function(...) stop("boom")
    ))
  )
  check("scan after callback error", is.data.frame(hs_scan(db, "foobar")))
}
# Whether a non-logical return is an error is the R layer's business; the
# point here is only to run the path.
invisible(raises(hs_scan(db, "foobar", callback = function(...) list(1, 2))))
check("callback context", {
  seen <- NULL
  hs_scan(
    db,
    "foo",
    callback = function(id, from, to, flags, ctx) {
      seen <<- ctx$tag
      FALSE
    },
    context = list(tag = "x")
  )
  identical(seen, "x")
})

cat("-- vectored and streaming ----------------------------------------\n")

vdb <- hs_database(HS_MODE_VECTORED)
hs_compile(vdb, c("foobar", "o+b"))
check("vectored", is.data.frame(hs_scan_vector(vdb, c("foo", "bar"))))
check(
  "vectored empty blocks",
  is.data.frame(hs_scan_vector(vdb, c("", "", "x")))
)
check(
  "vectored callback error",
  raises(hs_scan_vector(
    vdb,
    c("foo", "bar"),
    callback = function(...) stop("boom")
  ))
)

# SOM in stream mode needs a SOM horizon mode, which the package does not
# expose, so this is a compile error -- the path that once read Vectorscan's
# message after freeing it.
check(
  "stream SOM compile error",
  raises(hs_compile(
    hs_database(HS_MODE_STREAM),
    "foo.*bar",
    flags = HS_FLAG_SOM_LEFTMOST
  ))
)

sdb <- hs_database(HS_MODE_STREAM)
hs_compile(sdb, c("foo.*bar", "baz"))
for (i in 1:20) {
  s <- hs_stream_open(sdb)
  hs_stream_scan(s, "foo and ")
  hs_stream_scan(s, strrep("x", 1000))
  check("stream match across chunks", nrow(hs_stream_scan(s, " then bar")) >= 1)
  check(
    "stream callback error",
    raises(hs_stream_scan(
      s,
      "baz",
      callback = function(...) stop("boom")
    ))
  )
  hs_stream_close(s)
  check("closed stream rejects scans", raises(hs_stream_scan(s, "foo")))
}
# Streams that are never closed are reclaimed by their finalizers.
for (i in 1:20) {
  s <- hs_stream_open(sdb)
  hs_stream_scan(s, "foo")
}
rm(s)
invisible(gc())

cat("-- vectorized verbs ----------------------------------------------\n")

# vctrsn_hs_scan_many(): one scan per element, NA elements skipped, match
# buffers grown with realloc() and freed on every exit path.
words <- c("foo", "bar", NA, "", strrep("foobar ", 2000), "caf\u00e9 foo")
rules <- c(a = "foo", b = "o+b", c = "\\w+")
check("detect", identical(length(hs_detect(rules, words)), length(words)))
check(
  "detect per pattern",
  is.matrix(hs_detect(rules, words, per_pattern = TRUE))
)
check("count", is.integer(hs_count(rules, words)))
check("match", is.data.frame(hs_match(rules, words)))
check("extract", is.list(hs_extract(rules, words)))
check("many elements", sum(hs_detect("foo", rep(words, 500)), na.rm = TRUE) > 0)
check("no elements", identical(hs_detect("foo", character()), logical()))
check("verbs on a stream db", raises(hs_detect(sdb, "foo")))

cat("-- PCRE2 capture loop --------------------------------------------\n")

# vctrsn_pcre2_capture_many(): columns filled in place, match data from
# R_alloc(), unset groups and errors per element.
if (!is.null(vectorscan:::pcre2_info())) {
  cap <- vectorscan:::capture_many
  lines <- c(
    "a=1",
    NA,
    "",
    "bad \xff utf",
    "caf\u00e9=\u00e9t\u00e9",
    strrep("k=v;", 3000)
  )
  check("capture", is.list(cap("^(\\w+)=(\\S*)(;)?", lines)))
  check("capture no groups", is.list(cap("=", lines)))
  check(
    "capture many elements",
    sum(cap("(k)=(v)", rep(lines, 400))$matched, na.rm = TRUE) > 0
  )
  check("capture bad pattern", raises(cap("(", "x")))
  check(
    "hs_capture typed",
    is.data.frame(suppressWarnings(hs_capture(
      "^(\\w+)=(\\d+)",
      lines,
      data.frame(k = character(), v = integer())
    )))
  )
  for (i in 1:50) {
    cap("(a)(b)?(c)", c("abc", "ac", NA))
  }
  check(
    "hs_capture match limit",
    is.data.frame(suppressWarnings(hs_capture(
      "^(a+)+$",
      c(paste0(strrep("a", 26), "!"), "aa"),
      match_limit = 5000
    )))
  )
  check(
    "hs_capture depth limit, interpreter",
    is.data.frame(suppressWarnings(hs_capture(
      hs_capture_compile("^(a(?1)?b)$", jit = FALSE),
      paste0(strrep("a", 2000), strrep("b", 2000)),
      depth_limit = 20
    )))
  )
  check(
    "hs_capture rules",
    is.data.frame(suppressWarnings(hs_capture(
      c(kv = "^(?<k>\\w+)=(?<v>\\S*)", reset = "^(?|(\\d+)|([a-z]+))$", "(x)"),
      rep(lines, 50)
    )))
  )
  invisible(gc())
}

cat("-- stream extras and native errors -------------------------------\n")

hdb <- hs_database(bitwOr(HS_MODE_STREAM, HS_MODE_SOM_HORIZON_SMALL))
hs_compile(hdb, c("foo.*bar", "x"), flags = HS_FLAG_SOM_LEFTMOST)
check("stream size", hs_stream_size(hdb) > 0)
for (i in 1:20) {
  s <- hs_stream_open(hdb)
  hs_stream_scan(s, strrep("foo ", 100))
  hs_stream_scan(s, "bar")
  hs_stream_close(s)
}
check(
  "typed native error",
  inherits(
    tryCatch(hs_stream_open(hs_compile("a")), error = function(e) e),
    "vectorscan_error_native"
  )
)
check(
  "callback condition kept",
  identical(
    tryCatch(
      hs_scan(hs_compile("a"), "aa", callback = function(...) stop("mine")),
      error = conditionMessage
    ),
    "mine"
  )
)

cat("-- literals, flag strings, pattern files --------------------------\n")

lit <- hs_compile(c("a.b", "(x", "caf\u00e9"), flags = "iL", literal = TRUE)
for (i in 1:20) {
  m <- hs_match(lit, rep(c("A.B (X", "un caf\u00e9", ""), 200))
}
check("literal matches", nrow(m) == 600)
rules <- hs_read_patterns(textConnection(c(
  "1:/foo(bar)?/i",
  "2:/abc/{edit_distance=1}",
  "3:/x+/L{min_offset=2,max_offset=5000000000}"
)))
check(
  "pattern file scan",
  sum(hs_detect(rules, c("FOO", "abd", "..xx", "q"))) == 3
)

cat("-- serialization -------------------------------------------------\n")

bytes <- hs_serialize(db)
check("round trip", is.data.frame(hs_scan(hs_deserialize(bytes), "foobar")))
check("empty bytes", raises(hs_deserialize(raw())))
check("junk bytes", raises(hs_deserialize(as.raw(sample(0:255, 64, TRUE)))))
check(
  "truncated bytes",
  raises(hs_deserialize(bytes[seq_len(length(bytes) %/% 2)]))
)
path <- tempfile(fileext = ".hsdb")
hs_save(db, path)
check("save and load", is.data.frame(hs_scan(hs_load(path), "foo")))
unlink(path)

cat("-- finalizers ----------------------------------------------------\n")

for (i in 1:100) {
  tmp <- hs_database()
  hs_compile(tmp, c("foo", "bar"))
  hs_scan(tmp, "foobar")
}
rm(tmp, db, vdb, sdb)
invisible(gc())
invisible(gc())

cat(sprintf("\n%d checks, %d failed\n", checked, failures))
if (failures > 0L) {
  quit(status = 1L)
}
