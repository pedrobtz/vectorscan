#' Errors raised by vectorscan
#'
#' Every error the package raises is a condition of class `vectorscan_error`,
#' so `tryCatch(..., vectorscan_error = ...)` catches them all. More specific
#' classes sit in front of it:
#'
#' * `vectorscan_error_compile`: a pattern did not compile. The condition has
#'   fields `expression` (the zero-based index of the offending pattern) and
#'   `reason` (Vectorscan's message).
#' * `vectorscan_error_native`: any other error returned by the Vectorscan
#'   library, with fields `code` and `operation`, and one class per error
#'   code: `vectorscan_error_invalid`, `_nomem`, `_scan_terminated`,
#'   `_db_version`, `_db_platform`, `_db_mode` (for example, a stream opened
#'   on a block-mode database), `_bad_align`, `_bad_alloc`,
#'   `_scratch_in_use`, `_arch`, `_insufficient_space` and `_unknown`.
#' * `vectorscan_error_mode`, `vectorscan_error_platform` and
#'   `vectorscan_error_unavailable`: invalid arguments and builds without
#'   Vectorscan.
#'
#' An error raised inside a match callback is not wrapped: the scan stops
#' and the callback's own condition is re-raised, with its class and
#' message.
#'
#' @name vectorscan-errors
#' @examples
#' if (hs_available()) {
#'   err <- tryCatch(hs_compile("a(b"), vectorscan_error_compile = function(e) e)
#'   err$expression
#'   err$reason
#' }
NULL

stop_vectorscan <- function(
  message,
  class = "vectorscan_error",
  call. = FALSE
) {
  condition <- structure(
    list(message = message, call = if (call.) sys.call(-1) else NULL),
    class = c(class, "vectorscan_error", "error", "condition")
  )
  stop(condition)
}

stop_unavailable <- function() {
  stop_vectorscan(
    paste(
      "Vectorscan/Hyperscan is not available in this build.",
      "Install Vectorscan or set VECTORSCAN_INCLUDE_DIR and",
      "VECTORSCAN_LIB_DIR before installing the package."
    ),
    class = "vectorscan_error_unavailable"
  )
}

# Vectorscan's error codes (hs_common.h) and what each means.
native_errors <- data.frame(
  code = -(1:13),
  class = c(
    "invalid",
    "nomem",
    "scan_terminated",
    "compiler",
    "db_version",
    "db_platform",
    "db_mode",
    "bad_align",
    "bad_alloc",
    "scratch_in_use",
    "arch",
    "insufficient_space",
    "unknown"
  ),
  text = c(
    "a parameter was invalid",
    "memory allocation failed",
    "the scan was terminated by a callback",
    "pattern compilation failed",
    "the database was built for a different version of Vectorscan",
    "the database was built for a different platform",
    "the database was built for a different mode",
    "a parameter was not correctly aligned",
    "the memory allocator returned misaligned memory",
    "the scratch space is already in use",
    "the CPU does not support the instructions Vectorscan needs",
    "a buffer was too small",
    "an unexpected internal error occurred"
  ),
  stringsAsFactors = FALSE
)

# Raised from C (stop_hs_error() in src/vectorscan.c).
stop_native_error <- function(code, operation) {
  row <- match(code, native_errors$code)
  class <- if (is.na(row)) "unknown" else native_errors$class[[row]]
  text <- if (is.na(row)) {
    "an unknown error occurred"
  } else {
    native_errors$text[[row]]
  }
  condition <- structure(
    list(
      message = sprintf(
        "Vectorscan %s failed: %s (error %d).",
        operation,
        text,
        code
      ),
      call = NULL,
      code = code,
      operation = operation
    ),
    class = c(
      paste0("vectorscan_error_", class),
      "vectorscan_error_native",
      "vectorscan_error",
      "error",
      "condition"
    )
  )
  stop(condition)
}

# Raised from C when hs_compile_ext_multi() rejects a pattern.
stop_compile_error <- function(expression, reason) {
  condition <- structure(
    list(
      message = sprintf(
        "Vectorscan compile error at expression %d: %s",
        expression,
        reason
      ),
      call = NULL,
      expression = expression,
      reason = reason
    ),
    class = c(
      "vectorscan_error_compile",
      "vectorscan_error",
      "error",
      "condition"
    )
  )
  stop(condition)
}
