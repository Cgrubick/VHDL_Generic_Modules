"""
run_sim.py  –  cocotb runner for packet_tx (no Makefile; Windows + ModelSim/Questa)

Requirements:
  pip install cocotb
  ModelSim or Questa on PATH (vcom, vsim)

Usage:
  python run_sim.py                                # run all 4 tests
  python run_sim.py --test test_single_small_packet  # single test
"""

import os
import subprocess
import sys
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
COCOTB_DIR = Path(__file__).resolve().parent
SIMS_DIR   = COCOTB_DIR.parent
RTL_DIR    = SIMS_DIR.parent
BUILD_DIR  = RTL_DIR / "sim_build" / "cocotb"

SOURCES = [
    RTL_DIR / "ip_defs_pkg.vhd",
    RTL_DIR / "crc_gen.vhd",
    RTL_DIR / "async_fifo.vhd",
    RTL_DIR / "packet_tx.vhd",
]

TOPLEVEL    = "packet_tx"
TEST_MODULE = "test_packet_tx"

# cocotb FLI library for ModelSim VHDL
import cocotb as _cocotb
COCOTB_LIBS  = Path(_cocotb.__file__).parent / "libs"
FLI_LIB      = COCOTB_LIBS / "cocotbfli_modelsim.dll"


def run_cmd(cmd, **kwargs):
    """Run a command, print it, and raise on failure."""
    print("  $", " ".join(str(c) for c in cmd))
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        sys.exit(result.returncode)


def compile_sources():
    """Compile all VHDL sources into the sim_build work library."""
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    # Create / map the work library
    run_cmd(["vlib", "work"],                  cwd=BUILD_DIR)
    run_cmd(["vmap", "work", str(BUILD_DIR / "work")], cwd=BUILD_DIR)

    # Compile each source in order
    for src in SOURCES:
        run_cmd(["vcom", "-2008", str(src)], cwd=BUILD_DIR)


def run_tests(testcase=None):
    """Launch vsim with cocotb FLI and the chosen test(s)."""
    if not FLI_LIB.exists():
        print(f"ERROR: FLI library not found at {FLI_LIB}")
        print("  Make sure cocotb is installed: pip install cocotb")
        sys.exit(1)

    env = os.environ.copy()
    env["MODULE"]             = TEST_MODULE
    env["TOPLEVEL"]           = TOPLEVEL
    env["TOPLEVEL_LANG"]      = "vhdl"
    env["COCOTB_RESULTS_FILE"] = str(COCOTB_DIR / "results.xml")
    env["PYTHONPATH"]         = str(COCOTB_DIR) + os.pathsep + env.get("PYTHONPATH", "")
    if testcase:
        env["TESTCASE"] = testcase

    vsim_cmd = [
        "vsim",
        "-c",                                    # batch / no GUI
        f"work.{TOPLEVEL}",
        "-foreign", f"cocotb_init {FLI_LIB}",
        "-do", "run -all; quit -f",
    ]
    run_cmd(vsim_cmd, cwd=BUILD_DIR, env=env)

    # Print pass/fail summary from results.xml
    results_file = COCOTB_DIR / "results.xml"
    if results_file.exists():
        import xml.etree.ElementTree as ET
        tree = ET.parse(results_file)
        passes  = sum(1 for tc in tree.iter("testcase")
                      if tc.find("failure") is None and tc.find("error") is None)
        failures = sum(1 for tc in tree.iter("testcase")
                       if tc.find("failure") is not None or tc.find("error") is not None)
        print(f"\n  Results: {passes} passed, {failures} failed")
        if failures:
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="cocotb runner for packet_tx")
    parser.add_argument("--test", default=None,
                        help="Run a single test by name (default: all)")
    parser.add_argument("--no-compile", action="store_true",
                        help="Skip recompilation (use existing sim_build)")
    args = parser.parse_args()

    print("=== Compiling VHDL sources ===")
    if not args.no_compile:
        compile_sources()
    else:
        print("  (skipped)")

    print("\n=== Running cocotb tests ===")
    run_tests(testcase=args.test)


if __name__ == "__main__":
    main()
