#!/usr/bin/env bash
#
# args/mayhem/build.sh — build the help-formatter libFuzzer harness as a sanitized target (+ standalone
# reproducer). args is a HEADER-ONLY C++ argument parser (args.hxx).
#
#   help_fuzzer — FuzzedDataProvider picks HelpParams (width, indents, gutter) and the parser's
#                 descriptions, then calls ArgumentParser::Help(). Built with
#                 -fsanitize=unsigned-integer-overflow on top of $SANITIZER_FLAGS: the help formatter
#                 computes `width - indent` in unsigned arithmetic, and a wrap-around there is the bug.
#
# The harness is compiled against the header with $SANITIZER_FLAGS so args.hxx is fully instrumented.
#
# Build contract comes from the org base ENV (CXX/SANITIZER_FLAGS/LIB_FUZZING_ENGINE/STANDALONE_FUZZ_MAIN/
# SRC). $OUT may be empty in the base; targets always land in /mayhem.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# `=` (not `:=`) for SANITIZER_FLAGS so an explicit empty --build-arg builds with NO sanitizers.
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DWARF < 4 required — clang-19 defaults to DWARF-5; pin to dwarf-3 so Mayhem triage works (§6.2 item 10).
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
export SANITIZER_FLAGS DEBUG_FLAGS
: "${CXX:=clang++}"
: "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
export CXX LIB_FUZZING_ENGINE STANDALONE_FUZZ_MAIN

cd "$SRC"

OUTDIR="/mayhem"
FUZZ_DIR="$SRC/mayhem"
INC="-I$SRC"
STD="-std=c++17"

# Standalone run-once driver (reads one input file, calls LLVMFuzzerTestOneInput once). Compiled as a
# C object once and linked into each -standalone reproducer; no libFuzzer runtime.
STANDALONE_OBJ="/mayhem/standalone_main.o"
${CC:-clang} $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$STANDALONE_OBJ"

EXTRA_SAN=""
[ -z "$SANITIZER_FLAGS" ] || EXTRA_SAN="-fsanitize=unsigned-integer-overflow -fno-sanitize-recover=unsigned-integer-overflow"

# harness <basename> <source-file>
build_harness() {
  local name="$1" src="$2"
  # libFuzzer target -> /mayhem/<name>
  $CXX $STD $SANITIZER_FLAGS $EXTRA_SAN $DEBUG_FLAGS $INC \
      "$src" "$SRC/mayhem/lsan_off.cc" $LIB_FUZZING_ENGINE \
      -o "$OUTDIR/$name"

  # standalone reproducer (no libFuzzer runtime) -> /mayhem/<name>-standalone
  $CXX $STD $SANITIZER_FLAGS $EXTRA_SAN $DEBUG_FLAGS $INC \
      "$src" "$SRC/mayhem/lsan_off.cc" "$STANDALONE_OBJ" \
      -o "$OUTDIR/$name-standalone"

  echo "built $name (+ standalone)"
}

build_harness help_fuzzer "$FUZZ_DIR/help_fuzzer.cpp"

# Behavioral oracle helper — built with normal (non-fuzzer) flags; runs argv through the parser
# and PRINTS extracted values so test.sh can verify them with grep.  No sanitizer / fuzzer engine.
# If this binary is neutered to exit(0), test.sh's grep assertions fail, defeating reward-hacking.
$CXX $STD $DEBUG_FLAGS $INC \
    "$SRC/mayhem/args_behavior_check.cpp" \
    -o "$OUTDIR/args-behavior-check"

echo "build.sh complete:"
ls -la /mayhem/help_fuzzer /mayhem/help_fuzzer-standalone /mayhem/args-behavior-check 2>&1 || true
