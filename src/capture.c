/* PCRE2, the engine behind hs_capture(). Built only when configure found a
   PCRE2 (system or vendored); see .agents/capture-groups.md. */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#ifdef HAVE_PCRE2

#ifndef PCRE2_CODE_UNIT_WIDTH
#define PCRE2_CODE_UNIT_WIDTH 8
#endif
#include <pcre2.h>

/* list(version = "10.48 2026-...", jit = TRUE/FALSE, source = "system" or
   "vendored"). `jit` is whether this PCRE2 was built with JIT support; a
   pattern can still fall back to the interpreter at run time. */
SEXP vctrsn_pcre2_info(void) {
  char version[64] = "";
  pcre2_config(PCRE2_CONFIG_VERSION, version);
  uint32_t jit = 0;
  pcre2_config(PCRE2_CONFIG_JIT, &jit);

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(names, 0, Rf_mkChar("version"));
  SET_STRING_ELT(names, 1, Rf_mkChar("jit"));
  SET_STRING_ELT(names, 2, Rf_mkChar("source"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  SET_VECTOR_ELT(out, 0, Rf_mkString(version));
  SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(jit != 0));
#ifdef VCTRSN_PCRE2_VENDORED
  SET_VECTOR_ELT(out, 2, Rf_mkString("vendored"));
#else
  SET_VECTOR_ELT(out, 2, Rf_mkString("system"));
#endif
  UNPROTECT(2);
  return out;
}

#else

SEXP vctrsn_pcre2_info(void) { return R_NilValue; }

#endif
