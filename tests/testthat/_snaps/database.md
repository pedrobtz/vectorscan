# mode validation rejects ambiguous modes

    Code
      hs_database(bitwOr(HS_MODE_BLOCK, HS_MODE_STREAM))
    Condition
      Error:
      ! `mode` must contain exactly one of HS_MODE_BLOCK, HS_MODE_STREAM, or HS_MODE_VECTORED.

# compile validates expressions before native calls

    Code
      hs_compile(db, character())
    Condition
      Error:
      ! `expressions` must contain at least one pattern.

# native stubs fail clearly when unavailable

    Code
      hs_compile(db, "foo")
    Condition
      Error in `hs_compile()`:
      ! Vectorscan/Hyperscan is not available in this build.

