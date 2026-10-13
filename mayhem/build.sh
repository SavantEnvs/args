#!/usr/bin/env bash
#
# args/mayhem/build.sh (mining branch) — build the ARGS_NOEXCEPT completion harness as a sanitized target
# (+ a standalone reproducer). args is a HEADER-ONLY C++ argument parser (args.hxx).
#
#   noexcept_completion_fuzzer — splits the input into argv tokens after "--completion bash <cword> prog" and
#                          drives ArgumentParser::ParseArgs with ARGS_NOEXCEPT defined, so the bash-completion
#                          path (nested Parse over curArgs) runs without exceptions.
#
# Inputs are argv TOKENS / value strings (NOT files). We compile the harnesses against the header with
# $SANITIZER_FLAGS so the parser code in args.hxx is fully instrumented.
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
INC="-I$SRC"
STD="-std=c++17"

# Standalone run-once driver (reads one input file, calls LLVMFuzzerTestOneInput once). Compiled as a
# C object once and linked into each -standalone reproducer; no libFuzzer runtime.
STANDALONE_OBJ="/mayhem/standalone_main.o"
${CC:-clang} $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$STANDALONE_OBJ"

# LeakSanitizer off at build time (leaks are not what this fleet fuzzes for).
LSAN_OBJ="/mayhem/lsan_off.o"
$CXX $STD $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$LSAN_OBJ"

# harness <basename> <source-file>
build_harness() {
  local name="$1" src="$2"
  # libFuzzer target -> /mayhem/<name>
  $CXX $STD $SANITIZER_FLAGS $DEBUG_FLAGS $INC \
      "$src" "$LSAN_OBJ" $LIB_FUZZING_ENGINE \
      -o "$OUTDIR/$name"

  # standalone reproducer (no libFuzzer runtime) -> /mayhem/<name>-standalone
  $CXX $STD $SANITIZER_FLAGS $DEBUG_FLAGS $INC \
      "$src" "$LSAN_OBJ" "$STANDALONE_OBJ" \
      -o "$OUTDIR/$name-standalone"

  echo "built $name (+ standalone)"
}

build_harness noexcept_completion_fuzzer "$SRC/mayhem/noexcept_completion_fuzzer.cpp"

# Behavioral oracle helper — built with normal (non-fuzzer) flags; runs argv through the parser
# and PRINTS extracted values so test.sh can verify them with grep.  No sanitizer / fuzzer engine.
# If this binary is neutered to exit(0), test.sh's grep assertions fail, defeating reward-hacking.
$CXX $STD $DEBUG_FLAGS $INC \
    "$SRC/mayhem/args_behavior_check.cpp" \
    -o "$OUTDIR/args-behavior-check"

echo "build.sh complete:"
ls -la /mayhem/noexcept_completion_fuzzer /mayhem/noexcept_completion_fuzzer-standalone /mayhem/args-behavior-check 2>&1 || true
