#!/bin/sh -e
# This is used for renaming symbols for the fat runtime, don't call directly
# TODO: make this a lot less fragile!
cleanup () {
    rm -f ${SYMSFILE} ${KEEPSYMS}
}

PREFIX=$1
KEEPSYMS_IN=$2
shift 2
# $@ contains the actual build command
# R package patch: take the object from the argument after -o rather than
# parsing the command line with rev(1), which minimal images lack; without
# it the rename silently did nothing and left the dispatcher's prefixed
# symbols undefined.
OUT=""
prev=""
for arg in "$@"; do
    if [ "$prev" = "-o" ]; then
        OUT="$arg"
    fi
    prev="$arg"
done
if [ -z "$OUT" ]; then
    echo "build_wrapper.sh: no -o output in: $*" >&2
    exit 1
fi
trap cleanup INT QUIT EXIT
SYMSFILE=$(mktemp -p /tmp ${PREFIX}_rename.syms.XXXXX)
KEEPSYMS=$(mktemp -p /tmp keep.syms.XXXXX)
# find the libc used by gcc
LIBC_SO=$("$@" --print-file-name=libc.so.6)
NM_FLAG="-f"
if [ `uname` = "FreeBSD" ]; then
    # for freebsd, we will specify the name, 
    # we will leave it work as is in linux
    LIBC_SO=/lib/libc.so.7
    # also, in BSD, the nm flag -F corresponds to the -f flag in linux.
    NM_FLAG="-F"
fi
cp ${KEEPSYMS_IN} ${KEEPSYMS}
# get all symbols from libc and turn them into patterns
nm ${NM_FLAG} p -g -D ${LIBC_SO} | sed 's/\([^ @]*\).*/^\1$/' >> ${KEEPSYMS}
# build the object
"$@"
if [ ! -f "${OUT}" ]; then
    echo "build_wrapper.sh: ${OUT} was not built" >&2
    exit 1
fi
# rename the symbols in the object
nm ${NM_FLAG} p -g ${OUT} | cut -f1 -d' ' | grep -v -f ${KEEPSYMS} | sed -e "s/\(.*\)/\1\ ${PREFIX}_\1/" >> ${SYMSFILE}
if test -s ${SYMSFILE}
then
    objcopy --redefine-syms=${SYMSFILE} ${OUT}
fi
