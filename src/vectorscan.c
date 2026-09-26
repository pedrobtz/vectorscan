#include <R.h>
#include <R_ext/Memory.h>
#include <R_ext/Utils.h>
#include <Rinternals.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifndef HAVE_HS

static SEXP unavailable(void) {
  Rf_error("Vectorscan/Hyperscan is not available in this build.");
  return R_NilValue;
}

SEXP vctrsn_hs_available(void) { return Rf_ScalarLogical(FALSE); }

SEXP vctrsn_hs_compile(SEXP expressions,
                        SEXP ids,
                        SEXP flags,
                        SEXP mode,
                        SEXP ext) {
  return unavailable();
}

SEXP vctrsn_hs_scan(SEXP database_xptr,
                    SEXP scratch_xptr,
                    SEXP data,
                    SEXP callback,
                    SEXP context) {
  return unavailable();
}

SEXP vctrsn_hs_scan_vector(SEXP database_xptr,
                           SEXP scratch_xptr,
                           SEXP data,
                           SEXP callback,
                           SEXP context) {
  return unavailable();
}

SEXP vctrsn_hs_stream_open(SEXP database_xptr, SEXP database_env) {
  return unavailable();
}

SEXP vctrsn_hs_stream_scan(SEXP stream_xptr,
                           SEXP scratch_xptr,
                           SEXP data,
                           SEXP callback,
                           SEXP context) {
  return unavailable();
}

SEXP vctrsn_hs_stream_close(SEXP stream_xptr,
                            SEXP scratch_xptr,
                            SEXP callback,
                            SEXP context) {
  return unavailable();
}

SEXP vctrsn_hs_info(SEXP database_xptr) { return unavailable(); }

SEXP vctrsn_hs_database_size(SEXP database_xptr) { return unavailable(); }

SEXP vctrsn_hs_serialize(SEXP database_xptr) { return unavailable(); }

SEXP vctrsn_hs_deserialize(SEXP bytes) { return unavailable(); }

#else

#include <hs/hs.h>

typedef struct {
  hs_stream_t *stream;
  hs_scratch_t *scratch;
  int closed;
} vctrsn_stream_t;

typedef struct {
  int collect;
  SEXP callback;
  SEXP context;
  unsigned int *ids;
  double *from;
  double *to;
  unsigned int *flags;
  R_xlen_t count;
  R_xlen_t capacity;
  int callback_error;
} vctrsn_scan_context_t;

static void database_finalizer(SEXP xptr) {
  hs_database_t *database = (hs_database_t *)R_ExternalPtrAddr(xptr);
  if (database != NULL) {
    hs_free_database(database);
    R_ClearExternalPtr(xptr);
  }
}

static void scratch_finalizer(SEXP xptr) {
  hs_scratch_t *scratch = (hs_scratch_t *)R_ExternalPtrAddr(xptr);
  if (scratch != NULL) {
    hs_free_scratch(scratch);
    R_ClearExternalPtr(xptr);
  }
}

static void stream_finalizer(SEXP xptr) {
  vctrsn_stream_t *stream = (vctrsn_stream_t *)R_ExternalPtrAddr(xptr);
  if (stream != NULL) {
    if (!stream->closed && stream->stream != NULL && stream->scratch != NULL) {
      hs_close_stream(stream->stream, stream->scratch, NULL, NULL);
    }
    stream->closed = 1;
    R_Free(stream);
    R_ClearExternalPtr(xptr);
  }
}

static hs_database_t *database_addr(SEXP xptr) {
  if (TYPEOF(xptr) != EXTPTRSXP) {
    Rf_error("Internal error: database pointer is invalid.");
  }

  hs_database_t *database = (hs_database_t *)R_ExternalPtrAddr(xptr);
  if (database == NULL) {
    Rf_error("Database pointer is no longer valid.");
  }

  return database;
}

static hs_scratch_t *scratch_addr(SEXP xptr) {
  if (TYPEOF(xptr) != EXTPTRSXP) {
    Rf_error("Internal error: scratch pointer is invalid.");
  }

  hs_scratch_t *scratch = (hs_scratch_t *)R_ExternalPtrAddr(xptr);
  if (scratch == NULL) {
    Rf_error("Scratch pointer is no longer valid.");
  }

  return scratch;
}

static vctrsn_stream_t *stream_addr(SEXP xptr) {
  if (TYPEOF(xptr) != EXTPTRSXP) {
    Rf_error("Internal error: stream pointer is invalid.");
  }

  vctrsn_stream_t *stream = (vctrsn_stream_t *)R_ExternalPtrAddr(xptr);
  if (stream == NULL || stream->closed || stream->stream == NULL) {
    Rf_error("Stream pointer is no longer valid.");
  }

  return stream;
}

static SEXP make_external_database(hs_database_t *database) {
  SEXP xptr = PROTECT(R_MakeExternalPtr(database, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(xptr, database_finalizer, TRUE);
  UNPROTECT(1);
  return xptr;
}

static SEXP make_external_scratch(hs_scratch_t *scratch) {
  SEXP xptr = PROTECT(R_MakeExternalPtr(scratch, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(xptr, scratch_finalizer, TRUE);
  UNPROTECT(1);
  return xptr;
}

static SEXP get_named(SEXP list, const char *name) {
  SEXP names = Rf_getAttrib(list, R_NamesSymbol);
  if (names == R_NilValue) {
    return R_NilValue;
  }

  for (R_xlen_t i = 0; i < XLENGTH(list); ++i) {
    if (strcmp(CHAR(STRING_ELT(names, i)), name) == 0) {
      return VECTOR_ELT(list, i);
    }
  }

  return R_NilValue;
}

static unsigned long long scalar_ull(SEXP x) {
  if (TYPEOF(x) == INTSXP) {
    return (unsigned long long)INTEGER(x)[0];
  }

  return (unsigned long long)REAL(x)[0];
}

static unsigned int scalar_uint(SEXP x) {
  if (TYPEOF(x) == INTSXP) {
    return (unsigned int)INTEGER(x)[0];
  }

  return (unsigned int)REAL(x)[0];
}

static void fill_ext(SEXP ext, hs_expr_ext_t *out) {
  memset(out, 0, sizeof(hs_expr_ext_t));

  out->flags = scalar_ull(get_named(ext, "flags"));
  out->min_offset = scalar_ull(get_named(ext, "min_offset"));
  out->max_offset = scalar_ull(get_named(ext, "max_offset"));
  out->min_length = scalar_ull(get_named(ext, "min_length"));
  out->edit_distance = scalar_uint(get_named(ext, "edit_distance"));
  out->hamming_distance = scalar_uint(get_named(ext, "hamming_distance"));
}

static SEXP make_compiled_database(hs_database_t *database,
                                   hs_scratch_t *scratch) {
  SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
  SET_STRING_ELT(names, 0, Rf_mkChar("database"));
  SET_STRING_ELT(names, 1, Rf_mkChar("scratch"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  SET_VECTOR_ELT(out, 0, make_external_database(database));
  SET_VECTOR_ELT(out, 1, make_external_scratch(scratch));
  UNPROTECT(2);
  return out;
}

static void stop_hs_error(hs_error_t hs_err, const char *operation) {
  Rf_error("Vectorscan %s failed with error code %d.", operation, hs_err);
}

static void ensure_scan_capacity(vctrsn_scan_context_t *ctx) {
  if (ctx->count < ctx->capacity) {
    return;
  }

  R_xlen_t capacity = ctx->capacity == 0 ? 16 : ctx->capacity * 2;
  ctx->ids = R_Realloc(ctx->ids, capacity, unsigned int);
  ctx->from = R_Realloc(ctx->from, capacity, double);
  ctx->to = R_Realloc(ctx->to, capacity, double);
  ctx->flags = R_Realloc(ctx->flags, capacity, unsigned int);
  ctx->capacity = capacity;
}

static int match_handler(unsigned int id,
                         unsigned long long from,
                         unsigned long long to,
                         unsigned int flags,
                         void *context) {
  vctrsn_scan_context_t *ctx = (vctrsn_scan_context_t *)context;
  ctx->count++;

  if (ctx->collect) {
    ensure_scan_capacity(ctx);
    R_xlen_t index = ctx->count - 1;
    ctx->ids[index] = id;
    ctx->from[index] = (double)from;
    ctx->to[index] = (double)to;
    ctx->flags[index] = flags;
    return 0;
  }

  SEXP id_s = PROTECT(Rf_ScalarInteger((int)id));
  SEXP from_s = PROTECT(Rf_ScalarReal((double)from));
  SEXP to_s = PROTECT(Rf_ScalarReal((double)to));
  SEXP flags_s = PROTECT(Rf_ScalarInteger((int)flags));
  SEXP call = PROTECT(
      Rf_lang6(ctx->callback, id_s, from_s, to_s, flags_s, ctx->context));

  int eval_error = 0;
  SEXP result = R_tryEval(call, R_GlobalEnv, &eval_error);
  UNPROTECT(5);

  if (eval_error) {
    ctx->callback_error = 1;
    return 1;
  }

  return Rf_asLogical(result) == TRUE;
}

static vctrsn_scan_context_t make_scan_context(SEXP callback, SEXP context) {
  vctrsn_scan_context_t ctx;
  ctx.collect = callback == R_NilValue;
  ctx.callback = callback;
  ctx.context = context;
  ctx.ids = NULL;
  ctx.from = NULL;
  ctx.to = NULL;
  ctx.flags = NULL;
  ctx.count = 0;
  ctx.capacity = 0;
  ctx.callback_error = 0;
  return ctx;
}

static void free_scan_context(vctrsn_scan_context_t *ctx) {
  if (ctx->ids != NULL) {
    R_Free(ctx->ids);
  }
  if (ctx->from != NULL) {
    R_Free(ctx->from);
  }
  if (ctx->to != NULL) {
    R_Free(ctx->to);
  }
  if (ctx->flags != NULL) {
    R_Free(ctx->flags);
  }
}

static SEXP scan_context_result(vctrsn_scan_context_t *ctx) {
  if (!ctx->collect) {
    return Rf_ScalarInteger((int)ctx->count);
  }

  SEXP ids = PROTECT(Rf_allocVector(INTSXP, ctx->count));
  SEXP from = PROTECT(Rf_allocVector(REALSXP, ctx->count));
  SEXP to = PROTECT(Rf_allocVector(REALSXP, ctx->count));
  SEXP flags = PROTECT(Rf_allocVector(INTSXP, ctx->count));

  for (R_xlen_t i = 0; i < ctx->count; ++i) {
    INTEGER(ids)[i] = (int)ctx->ids[i];
    REAL(from)[i] = ctx->from[i];
    REAL(to)[i] = ctx->to[i];
    INTEGER(flags)[i] = (int)ctx->flags[i];
  }

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 4));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 4));
  SET_STRING_ELT(names, 0, Rf_mkChar("id"));
  SET_STRING_ELT(names, 1, Rf_mkChar("from"));
  SET_STRING_ELT(names, 2, Rf_mkChar("to"));
  SET_STRING_ELT(names, 3, Rf_mkChar("flags"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  SET_VECTOR_ELT(out, 0, ids);
  SET_VECTOR_ELT(out, 1, from);
  SET_VECTOR_ELT(out, 2, to);
  SET_VECTOR_ELT(out, 3, flags);
  UNPROTECT(6);

  return out;
}

static SEXP finish_scan(hs_error_t hs_err,
                        vctrsn_scan_context_t *ctx,
                        const char *operation) {
  if (ctx->callback_error) {
    free_scan_context(ctx);
    Rf_error("R callback failed during Vectorscan scan.");
  }

  if (hs_err != HS_SUCCESS && hs_err != HS_SCAN_TERMINATED) {
    free_scan_context(ctx);
    stop_hs_error(hs_err, operation);
  }

  SEXP out = PROTECT(scan_context_result(ctx));
  free_scan_context(ctx);
  UNPROTECT(1);
  return out;
}

SEXP vctrsn_hs_available(void) { return Rf_ScalarLogical(TRUE); }

SEXP vctrsn_hs_compile(SEXP expressions,
                        SEXP ids,
                        SEXP flags,
                        SEXP mode,
                        SEXP ext) {
  R_xlen_t n = XLENGTH(expressions);
  const char **exprs = R_Calloc(n, const char *);
  unsigned int *ids_c = R_Calloc(n, unsigned int);
  unsigned int *flags_c = R_Calloc(n, unsigned int);

  hs_expr_ext_t *ext_c = NULL;
  const hs_expr_ext_t **ext_ptrs = NULL;

  for (R_xlen_t i = 0; i < n; ++i) {
    exprs[i] = CHAR(STRING_ELT(expressions, i));
    ids_c[i] = (unsigned int)INTEGER(ids)[i];
    flags_c[i] = (unsigned int)INTEGER(flags)[i];
  }

  if (ext != R_NilValue) {
    ext_c = R_Calloc(n, hs_expr_ext_t);
    ext_ptrs = R_Calloc(n, const hs_expr_ext_t *);
    for (R_xlen_t i = 0; i < n; ++i) {
      fill_ext(VECTOR_ELT(ext, i), &ext_c[i]);
      ext_ptrs[i] = &ext_c[i];
    }
  }

  hs_database_t *database = NULL;
  hs_compile_error_t *compile_error = NULL;
  hs_error_t hs_err = hs_compile_ext_multi(
      exprs, flags_c, ids_c, ext_ptrs, (unsigned int)n,
      (unsigned int)INTEGER(mode)[0], NULL, &database, &compile_error);

  R_Free(exprs);
  R_Free(ids_c);
  R_Free(flags_c);
  if (ext_c != NULL) {
    R_Free(ext_c);
  }
  if (ext_ptrs != NULL) {
    R_Free(ext_ptrs);
  }

  if (hs_err != HS_SUCCESS) {
    if (compile_error != NULL) {
      const char *message = compile_error->message == NULL
                                ? "unknown compiler error"
                                : compile_error->message;
      int expression = compile_error->expression;
      hs_free_compile_error(compile_error);
      Rf_error("Vectorscan compile error at expression %d: %s", expression,
               message);
    }
    stop_hs_error(hs_err, "compile");
  }

  hs_scratch_t *scratch = NULL;
  hs_err = hs_alloc_scratch(database, &scratch);
  if (hs_err != HS_SUCCESS) {
    hs_free_database(database);
    stop_hs_error(hs_err, "scratch allocation");
  }

  return make_compiled_database(database, scratch);
}

SEXP vctrsn_hs_scan(SEXP database_xptr,
                    SEXP scratch_xptr,
                    SEXP data,
                    SEXP callback,
                    SEXP context) {
  hs_database_t *database = database_addr(database_xptr);
  hs_scratch_t *scratch = scratch_addr(scratch_xptr);
  vctrsn_scan_context_t scan_context = make_scan_context(callback, context);

  hs_error_t hs_err = hs_scan(database, (const char *)RAW(data),
                              (unsigned int)XLENGTH(data), 0, scratch,
                              match_handler, &scan_context);

  return finish_scan(hs_err, &scan_context, "block scan");
}

SEXP vctrsn_hs_scan_vector(SEXP database_xptr,
                           SEXP scratch_xptr,
                           SEXP data,
                           SEXP callback,
                           SEXP context) {
  hs_database_t *database = database_addr(database_xptr);
  hs_scratch_t *scratch = scratch_addr(scratch_xptr);
  R_xlen_t n = XLENGTH(data);

  const char **blocks = R_Calloc(n, const char *);
  unsigned int *lengths = R_Calloc(n, unsigned int);
  for (R_xlen_t i = 0; i < n; ++i) {
    SEXP block = VECTOR_ELT(data, i);
    blocks[i] = (const char *)RAW(block);
    lengths[i] = (unsigned int)XLENGTH(block);
  }

  vctrsn_scan_context_t scan_context = make_scan_context(callback, context);
  hs_error_t hs_err = hs_scan_vector(database, blocks, lengths, (unsigned int)n,
                                     0, scratch, match_handler, &scan_context);

  R_Free(blocks);
  R_Free(lengths);

  return finish_scan(hs_err, &scan_context, "vectored scan");
}

SEXP vctrsn_hs_stream_open(SEXP database_xptr, SEXP database_env) {
  hs_database_t *database = database_addr(database_xptr);

  hs_stream_t *stream = NULL;
  hs_error_t hs_err = hs_open_stream(database, 0, &stream);
  if (hs_err != HS_SUCCESS) {
    stop_hs_error(hs_err, "stream open");
  }

  SEXP scratch = Rf_findVarInFrame(database_env, Rf_install("scratch"));
  vctrsn_stream_t *wrapper = R_Calloc(1, vctrsn_stream_t);
  wrapper->stream = stream;
  wrapper->scratch = scratch_addr(scratch);
  wrapper->closed = 0;

  SEXP xptr = PROTECT(R_MakeExternalPtr(wrapper, R_NilValue, database_env));
  R_RegisterCFinalizerEx(xptr, stream_finalizer, TRUE);
  UNPROTECT(1);
  return xptr;
}

SEXP vctrsn_hs_stream_scan(SEXP stream_xptr,
                           SEXP scratch_xptr,
                           SEXP data,
                           SEXP callback,
                           SEXP context) {
  vctrsn_stream_t *stream = stream_addr(stream_xptr);
  hs_scratch_t *scratch = scratch_addr(scratch_xptr);
  vctrsn_scan_context_t scan_context = make_scan_context(callback, context);

  hs_error_t hs_err = hs_scan_stream(
      stream->stream, (const char *)RAW(data), (unsigned int)XLENGTH(data), 0,
      scratch, match_handler, &scan_context);

  return finish_scan(hs_err, &scan_context, "stream scan");
}

SEXP vctrsn_hs_stream_close(SEXP stream_xptr,
                            SEXP scratch_xptr,
                            SEXP callback,
                            SEXP context) {
  vctrsn_stream_t *stream = stream_addr(stream_xptr);
  hs_scratch_t *scratch = scratch_addr(scratch_xptr);
  vctrsn_scan_context_t scan_context = make_scan_context(callback, context);

  hs_error_t hs_err =
      hs_close_stream(stream->stream, scratch, match_handler, &scan_context);
  stream->closed = 1;
  stream->stream = NULL;

  return finish_scan(hs_err, &scan_context, "stream close");
}

SEXP vctrsn_hs_info(SEXP database_xptr) {
  hs_database_t *database = database_addr(database_xptr);
  char *info = NULL;
  hs_error_t hs_err = hs_database_info(database, &info);
  if (hs_err != HS_SUCCESS) {
    stop_hs_error(hs_err, "database info");
  }

  SEXP out = PROTECT(Rf_mkString(info));
  free(info);
  UNPROTECT(1);
  return out;
}

SEXP vctrsn_hs_database_size(SEXP database_xptr) {
  hs_database_t *database = database_addr(database_xptr);
  size_t size = 0;
  hs_error_t hs_err = hs_database_size(database, &size);
  if (hs_err != HS_SUCCESS) {
    stop_hs_error(hs_err, "database size");
  }

  return Rf_ScalarReal((double)size);
}

SEXP vctrsn_hs_serialize(SEXP database_xptr) {
  hs_database_t *database = database_addr(database_xptr);
  char *bytes = NULL;
  size_t length = 0;
  hs_error_t hs_err = hs_serialize_database(database, &bytes, &length);
  if (hs_err != HS_SUCCESS) {
    stop_hs_error(hs_err, "database serialization");
  }

  SEXP out = PROTECT(Rf_allocVector(RAWSXP, length));
  memcpy(RAW(out), bytes, length);
  free(bytes);
  UNPROTECT(1);
  return out;
}

SEXP vctrsn_hs_deserialize(SEXP bytes) {
  hs_database_t *database = NULL;
  hs_error_t hs_err = hs_deserialize_database((const char *)RAW(bytes),
                                              (size_t)XLENGTH(bytes),
                                              &database);
  if (hs_err != HS_SUCCESS) {
    stop_hs_error(hs_err, "database deserialization");
  }

  hs_scratch_t *scratch = NULL;
  hs_err = hs_alloc_scratch(database, &scratch);
  if (hs_err != HS_SUCCESS) {
    hs_free_database(database);
    stop_hs_error(hs_err, "scratch allocation");
  }

  return make_compiled_database(database, scratch);
}

#endif
