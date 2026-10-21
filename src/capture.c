/* PCRE2, the engine behind hs_capture(), reached through zuregex's C API
   (LinkingTo: zuregex). zuregex bundles one PCRE2 for the R ecosystem, so
   this package no longer bundles or links its own; see
   .agents/capture-groups.md. */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <string.h>

#include <zuregex-r.h>

/* list(version = "PCRE2 10.48 ...", jit = TRUE/FALSE, source = "zuregex").
   `jit` is whether a pattern can be JIT-compiled on this machine; a pattern
   can still fall back to the interpreter at run time. */
SEXP vctrsn_pcre2_info(void) {
  zr_pattern *probe = zr_compile("a", 1, 0, ZR_DIALECT_PCRE, NULL, 0);
  int jit = probe != NULL && zr_jit(probe);
  zr_free(probe);

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(names, 0, Rf_mkChar("version"));
  SET_STRING_ELT(names, 1, Rf_mkChar("jit"));
  SET_STRING_ELT(names, 2, Rf_mkChar("source"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  /* zr_version() is "PCRE2 x.y yyyy-mm-dd"; keep "x.y yyyy-mm-dd". */
  const char *version = zr_version();
  if (strncmp(version, "PCRE2 ", 6) == 0) version += 6;
  SET_VECTOR_ELT(out, 0, Rf_mkString(version));
  SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(jit));
  SET_VECTOR_ELT(out, 2, Rf_mkString("zuregex"));
  UNPROTECT(2);
  return out;
}

/* -- compiled patterns ------------------------------------------------------ */

static void pattern_finalizer(SEXP xptr) {
  zr_pattern *p = (zr_pattern *)R_ExternalPtrAddr(xptr);
  if (p != NULL) {
    zr_free(p);
    R_ClearExternalPtr(xptr);
  }
}

static zr_pattern *pattern_addr(SEXP xptr) {
  if (TYPEOF(xptr) != EXTPTRSXP) {
    Rf_error("Internal error: PCRE2 pattern pointer is invalid.");
  }
  zr_pattern *p = (zr_pattern *)R_ExternalPtrAddr(xptr);
  if (p == NULL) {
    Rf_error("PCRE2 pattern pointer is no longer valid.");
  }
  return p;
}

/* Compile `pattern` (a UTF-8 string) as base R's regexec(perl = TRUE) does:
   UTF-8 without Unicode properties, zuregex's default dialect. JIT-compile
   it when asked and the platform allows; a JIT failure only means the
   interpreter runs instead.

   Returns list(ptr, names, jit): `names` has one entry per capture group,
   "" for unnamed groups. */
SEXP vctrsn_pcre2_compile(SEXP pattern, SEXP use_jit) {
  const char *text = Rf_translateCharUTF8(STRING_ELT(pattern, 0));
  uint32_t flags = Rf_asLogical(use_jit) == TRUE ? 0 : ZR_NO_JIT;
  char message[256];
  zr_pattern *p = zr_compile(text, strlen(text), flags, ZR_DIALECT_PCRE,
                             message, sizeof(message));
  if (p == NULL) {
    Rf_error("Invalid pattern: %s", message);
  }

  SEXP xptr = PROTECT(R_MakeExternalPtr(p, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(xptr, pattern_finalizer, TRUE);

  int ncap = zr_group_count(p);
  SEXP names = PROTECT(Rf_allocVector(STRSXP, ncap));
  for (int g = 1; g <= ncap; ++g) {
    const char *name = zr_group_name(p, g);
    SET_STRING_ELT(names, g - 1,
                   name != NULL ? Rf_mkCharCE(name, CE_UTF8) : R_BlankString);
  }

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SEXP out_names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(out_names, 0, Rf_mkChar("ptr"));
  SET_STRING_ELT(out_names, 1, Rf_mkChar("names"));
  SET_STRING_ELT(out_names, 2, Rf_mkChar("jit"));
  Rf_setAttrib(out, R_NamesSymbol, out_names);
  SET_VECTOR_ELT(out, 0, xptr);
  SET_VECTOR_ELT(out, 1, names);
  SET_VECTOR_ELT(out, 2, Rf_ScalarLogical(zr_jit(p)));
  UNPROTECT(4);
  return out;
}

/* -- capturing over a character vector ------------------------------------- */

static void match_data_finalizer(SEXP xptr) {
  zr_match_data *md = (zr_match_data *)R_ExternalPtrAddr(xptr);
  if (md != NULL) {
    zr_match_data_free(md);
    R_ClearExternalPtr(xptr);
  }
}

/* Match every element of `x` once (the first match, as regexec() does) and
   fill one character column per capture group in place.

   Returns list(matched, groups, errors):
   - matched: TRUE / FALSE per element, NA for NA input or a match error;
   - groups:  list of character vectors, NA where the element did not match
              or the group did not participate;
   - errors:  the zuregex status code per element, 0 where there was none. */
SEXP vctrsn_pcre2_capture_many(SEXP code_xptr, SEXP x, SEXP match_limit,
                               SEXP depth_limit) {
  zr_pattern *p = pattern_addr(code_xptr);
  R_xlen_t n = XLENGTH(x);
  int ncap = zr_group_count(p);

  SEXP matched = PROTECT(Rf_allocVector(LGLSXP, n));
  SEXP errors = PROTECT(Rf_allocVector(INTSXP, n));
  SEXP groups = PROTECT(Rf_allocVector(VECSXP, ncap));
  for (int g = 0; g < ncap; ++g) {
    SET_VECTOR_ELT(groups, g, Rf_allocVector(STRSXP, n));
  }
  int *matched_p = LOGICAL(matched);
  int *errors_p = INTEGER(errors);

  /* The match data is held by an external pointer with a finalizer, so an
     error or an interrupt in the loop cannot leak it. */
  zr_match_data *md = zr_match_data_create(p);
  if (md == NULL) {
    Rf_error("Out of memory while preparing a PCRE2 match.");
  }
  SEXP md_xptr = PROTECT(R_MakeExternalPtr(md, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(md_xptr, match_data_finalizer, TRUE);
  /* NA leaves PCRE2's default. The match limit bounds the work per element
     in both the interpreter and JIT; the depth limit applies to the
     interpreter. */
  int ml = Rf_asInteger(match_limit), dl = Rf_asInteger(depth_limit);
  zr_set_limits(md, ml == NA_INTEGER ? 0 : (uint32_t)ml,
                dl == NA_INTEGER ? 0 : (uint32_t)dl, 0);

  /* Each subject is scanned from our own buffer with zeroed padding after
     it. PCRE2's JIT scans with wide loads that may read a little past the
     end of the subject (within the same page, so safely); from R's heap
     those bytes are neighbouring objects, which valgrind reports as
     uninitialised. The buffer is R_alloc()ed and only ever grown before the
     per-element vmax mark, so it survives the loop and cannot leak. */
  char *buffer = NULL;
  size_t capacity = 0;
  const size_t padding = 64;

  for (R_xlen_t i = 0; i < n; ++i) {
    if ((i & 1023) == 1023) {
      R_CheckUserInterrupt();
    }

    errors_p[i] = 0;
    SEXP element = STRING_ELT(x, i);
    int rc = ZR_NOMATCH;
    const char *text = NULL;

    if (element != NA_STRING) {
      /* An upper bound on the element's UTF-8 length: translation from any
         R encoding at most quadruples the byte count. */
      size_t need = 4 * (size_t)LENGTH(element) + padding;
      if (need > capacity) {
        capacity = need > 2 * capacity ? need : 2 * capacity;
        buffer = R_alloc(capacity, 1);
      }
    }

    const void *vmax = vmaxget();
    if (element == NA_STRING) {
      matched_p[i] = NA_LOGICAL;
    } else {
      const char *utf8 = Rf_translateCharUTF8(element);
      size_t length = strlen(utf8);
      if (length + padding > capacity) {
        Rf_error("Internal error: UTF-8 string longer than expected.");
      }
      memcpy(buffer, utf8, length);
      memset(buffer + length, 0, padding);
      text = buffer;
      rc = zr_match(p, text, length, 0, 0, md);
      /* JIT code has a fixed-size stack; a deeply nested match that
         exhausts it is retried in the interpreter, which has none. */
      if (rc == ZR_ERROR_JIT_STACK) {
        rc = zr_match(p, text, length, 0, ZR_NO_JIT_MATCH, md);
      }
      if (rc > 0) {
        matched_p[i] = TRUE;
      } else if (rc == ZR_NOMATCH) {
        matched_p[i] = FALSE;
      } else {
        matched_p[i] = NA_LOGICAL;
        errors_p[i] = rc;
      }
    }

    for (int g = 1; g <= ncap; ++g) {
      SEXP column = VECTOR_ELT(groups, g - 1);
      size_t start, end;
      if (rc > 0 && zr_offsets(md, g, &start, &end) == ZR_OK) {
        SET_STRING_ELT(column, i,
                       Rf_mkCharLenCE(text + start, (int)(end - start),
                                      CE_UTF8));
      } else {
        SET_STRING_ELT(column, i, NA_STRING);
      }
    }
    /* Releases what translateCharUTF8() took, never the buffer, which was
       allocated before the mark. */
    vmaxset(vmax);
  }

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(names, 0, Rf_mkChar("matched"));
  SET_STRING_ELT(names, 1, Rf_mkChar("groups"));
  SET_STRING_ELT(names, 2, Rf_mkChar("errors"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  SET_VECTOR_ELT(out, 0, matched);
  SET_VECTOR_ELT(out, 1, groups);
  SET_VECTOR_ELT(out, 2, errors);
  UNPROTECT(6);
  return out;
}

/* The message for a status code, for the warning hs_capture() gives. */
SEXP vctrsn_pcre2_error_message(SEXP code) {
  return Rf_mkString(zr_strerror(Rf_asInteger(code)));
}
