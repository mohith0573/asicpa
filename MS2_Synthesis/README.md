# Synthesis (MS2) — Setup and Run Guide

This folder synthesizes a Verilog/SystemVerilog design against the TSMC
65nm `tcbn65gplustc` standard cell library using Synopsys Design Compiler.
This guide is self-contained — no prior context needed.

## Folder contents

```
MS2_Synthesis/
  .synopsys_dc.setup   -- library configuration (auto-loaded by dc_shell)
  analyze.tcl           -- lists the RTL source files to synthesize
  constraints.tcl        -- clock, I/O timing, and load constraints
  syn_script.tcl          -- the synthesis flow itself
  lib/                     -- (you will place the library file here — see Step 1)
  <your RTL file(s)>
```

## Step 1 — Place the library file

Copy the compiled TSMC 65nm timing library into the `lib/` folder here:
```bash
cp /path/to/tcbn65gplustc.db ./lib/
```
(If you only have the `.lib` text version and not `.db`, Design Compiler
can generally read `.lib` directly as well — in that case update
`TECH_FILE` in `.synopsys_dc.setup` to `tcbn65gplustc.lib` instead.)

## Step 2 — Set up your environment

Load whatever makes `dc_shell` available on this server, e.g.:
```bash
module load synopsys/designvision
```
or, if this server uses manual environment variables instead of modules,
ask your system administrator for the equivalent `export`/`source` lines.
Confirm it worked:
```bash
which dc_shell
```

## Step 3 — Add your RTL

Copy your design's Verilog/SystemVerilog file(s) into this folder, then
edit `analyze.tcl` to list them:
```tcl
analyze -library work -format sverilog { ./your_design.sv }
```

## Step 4 — Set the top module name

Open `syn_script.tcl` and edit the line near the top:
```tcl
set top your_module_name
```
This must exactly match your design's actual top-level module name
(case-sensitive).

## Step 5 — Check constraints

Open `constraints.tcl` and confirm:
- The clock port name matches your design's actual clock port (default
  assumes a port named `clk`).
- The clock period is appropriate for your design (default is 10000 ps =
  100 MHz — a conservative starting point, can be tightened later once
  the flow is confirmed working).
- If your design has additional ports beyond clock and a single data
  path, review the input/output delay and load settings.

## Step 6 — Run synthesis

```bash
dc_shell -f ./syn_script.tcl -output_log_file ./dc_output.txt
```

## Step 7 — Check the results, in this order

If anything goes wrong, read these top to bottom and fix the *first*
error you find — later errors are often just consequences of the first
one, not separate problems:

1. `reports/analyze.log` — syntax errors in your source files
2. `reports/elaborate.log` — errors building the design hierarchy
3. `reports/link.log` — missing library references
4. `reports/check_design.*.log` — structural design issues
5. `reports/synth.timing.all_violators.rpt` — should be empty; if not,
   the clock period may be too aggressive for this design/library
6. `reports/synth.qor.rpt` — overall quality-of-results summary

## Step 8 — Outputs

On success, `outputs/` will contain:
- `<top>.vg` — the synthesized gate-level netlist
- `<top>.sdc` — the timing constraints, carried forward for place-and-route

These two files are everything the next stage (place & route) needs from
synthesis.

## Questions / issues

If you hit an error not covered above, the most useful first step is
usually: open the relevant `.log` file, find the *first* line starting
with `Error:`, and search on that exact error code (e.g. `UID-4`,
`VER-41`) — Design Compiler's error messages are generally specific enough
to point directly at the actual problem (wrong file path, missing port,
etc.).
