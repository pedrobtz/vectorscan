## Submission

Not yet submitted. This is a draft for the first submission; complete the
check results and test environments from the release run before submitting.

vectorscan wraps Vectorscan, the portable fork of Intel Hyperscan, for
high-performance multi-pattern regular expression matching from R. The
Vectorscan sources are bundled, so no system regex library is required.

## R CMD check results

To be filled in from the release run. The expected result for a first
submission is:

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Pedro Baltazar <pedrobtz@gmail.com>'
  New submission

## Test environments

To be filled in. Continuous integration currently runs R CMD check --as-cran
on Ubuntu (R release) and in R-hub's clang23 container (clang 23,
-std=gnu23, libc++) on every pull request, and on macOS, Windows and Ubuntu
(R release and oldrel-1) after merge.

## Bundled sources

src/vendor/vectorscan/ is Vectorscan 5.4.12 under the BSD-3-Clause licence,
trimmed to what is needed to build its library, with four small local
patches (build without Ragel, build-flag and build-script fixes, and removal
of diagnostic-suppressing pragmas). Intel Corporation, VectorCamp PC and Arm
Limited are credited in Authors@R as copyright holders, the upstream licence
ships as src/vendor/vectorscan/LICENSE, and the provenance and patches are
recorded in inst/COPYRIGHTS.

## Installation

The bundled library is built with CMake (SystemRequirements: cmake) using
R's own C and C++ compilers, two parallel jobs by default. Boost headers come
from the BH package (LinkingTo). Nothing is downloaded during installation.

## Compiled code

The package contains C code and is checked under AddressSanitizer,
UndefinedBehaviorSanitizer, valgrind, rchk, LTO and gctorture in continuous
integration.
