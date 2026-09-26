#include <R.h>
#include <R_ext/Rdynload.h>
#include <Rinternals.h>

SEXP vctrsn_hs_available(void);
SEXP vctrsn_hs_compile(SEXP expressions,
                        SEXP ids,
                        SEXP flags,
                        SEXP mode,
                        SEXP ext);
SEXP vctrsn_hs_scan(SEXP database_xptr,
                    SEXP scratch_xptr,
                    SEXP data,
                    SEXP callback,
                    SEXP context);
SEXP vctrsn_hs_scan_vector(SEXP database_xptr,
                           SEXP scratch_xptr,
                           SEXP data,
                           SEXP callback,
                           SEXP context);
SEXP vctrsn_hs_stream_open(SEXP database_xptr, SEXP database_env);
SEXP vctrsn_hs_stream_scan(SEXP stream_xptr,
                           SEXP scratch_xptr,
                           SEXP data,
                           SEXP callback,
                           SEXP context);
SEXP vctrsn_hs_stream_close(SEXP stream_xptr,
                            SEXP scratch_xptr,
                            SEXP callback,
                            SEXP context);
SEXP vctrsn_hs_info(SEXP database_xptr);
SEXP vctrsn_hs_database_size(SEXP database_xptr);
SEXP vctrsn_hs_serialize(SEXP database_xptr);
SEXP vctrsn_hs_deserialize(SEXP bytes);

static const R_CallMethodDef CallEntries[] = {
    {"vctrsn_hs_available", (DL_FUNC)&vctrsn_hs_available, 0},
    {"vctrsn_hs_compile", (DL_FUNC)&vctrsn_hs_compile, 5},
    {"vctrsn_hs_scan", (DL_FUNC)&vctrsn_hs_scan, 5},
    {"vctrsn_hs_scan_vector", (DL_FUNC)&vctrsn_hs_scan_vector, 5},
    {"vctrsn_hs_stream_open", (DL_FUNC)&vctrsn_hs_stream_open, 2},
    {"vctrsn_hs_stream_scan", (DL_FUNC)&vctrsn_hs_stream_scan, 5},
    {"vctrsn_hs_stream_close", (DL_FUNC)&vctrsn_hs_stream_close, 4},
    {"vctrsn_hs_info", (DL_FUNC)&vctrsn_hs_info, 1},
    {"vctrsn_hs_database_size", (DL_FUNC)&vctrsn_hs_database_size, 1},
    {"vctrsn_hs_serialize", (DL_FUNC)&vctrsn_hs_serialize, 1},
    {"vctrsn_hs_deserialize", (DL_FUNC)&vctrsn_hs_deserialize, 1},
    {NULL, NULL, 0}};

void R_init_vectorscan(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
