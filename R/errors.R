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
