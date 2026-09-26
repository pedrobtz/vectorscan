# vectorscan 0.0.0.9000

- Initial package implementation with native bindings for compiling databases,
  block scanning, vectored scanning, streaming, database metadata, and database
  serialization.
- The package now vendors the Vectorscan source and builds the native library
  from source by default during configuration.
- The bundled Vectorscan is updated to 5.4.13, which fixes a stack buffer
  overflow in `rvermicelliDoubleExecReal()`, an AVX-512 scanning bug, SVE
  accelerator bugs, an integer overflow, a wrong page-size assumption on Apple
  Silicon, and compiler errors with clang 21 and GCC 15/16. Invalid character
  classes are now a compile error.
- Compile errors now report Vectorscan's message correctly; it was read after
  being freed.
