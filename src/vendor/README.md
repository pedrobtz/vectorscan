# Vendored Vectorscan

This directory contains the Vectorscan 5.4.12 source tree from:

<https://github.com/VectorCamp/vectorscan/tree/vectorscan/5.4.12>

Vectorscan is licensed under the BSD 3-Clause license. See
`vectorscan/LICENSE` and `vectorscan/COPYING` for the upstream license text.

The vendored tree is pruned to the files needed to build `libhs` for the R
package. Upstream unit tests, command-line tools, examples, benchmarks,
documentation, and Chimera sources are intentionally omitted.

The package `configure` script builds this source tree into a local static
`libhs` and links the R extension against it. Set `VECTORSCAN_USE_SYSTEM=true`
to use an externally installed compatible `libhs` during development.
