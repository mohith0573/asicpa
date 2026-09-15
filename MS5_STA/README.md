# MS5 — Static Timing / Power Signoff (PrimeTime)

Same tool, same script structure as your ECE755 MS5. Same manual step you
already did there too: PrimeTime reads from a **local `outputs/` folder in
this directory**, not directly from MS3/MS2 — so copy the files over first.

## Before running

```bash
mkdir -p outputs
cp ../MS3_APR/outputs/shift_register.apr.v   outputs/
cp ../MS3_APR/outputs/shift_register.apr.spef outputs/
cp ../MS2_Synthesis/outputs/shift_register.sdc outputs/
```

(Exactly the same pattern as your ECE755 run — you copied MS3's `outputs/`
folder and MS2's `top.sdc` into MS5's `outputs/` there too.)

## Running it

```bash
pt_shell -f pt_script.tcl
```

## Debugging (same lesson as ECE755)

**Check `reports/link.log` first.** If `link` fails, every report after it
(`report_timing`, `report_power`) will be garbage or empty — this is
exactly the `PLIB-162` failure you hit before, almost always caused by
`search_path` in `.synopsys_pt.setup` pointing at a folder name that
doesn't actually exist. Confirm:
```bash
ls /home/mthatikonda/tsmc65_work/FE_nldm/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65gplus_200a/tcbn65gplustc.db
```

## What to read once it's clean

- `reports/pt.timing.setup.rpt` / `pt.timing.hold.rpt` — worst-case paths.
- `reports/pt.power.rpt` / `pt.hier_power.rpt` — power breakdown. Expect the
  `PWR-246` "no switching activity data" warning — that's fine, PT falls
  back to statistical toggle-rate estimation without a VCD, same as before.
- `reports/pt.area.rpt` — total cell area.

## New step Prof. Zheng asked for: post-layout functional verification

ECE755 stopped at static timing analysis. Add this to the end of
`MS3_APR/apr_reference.tcl` (after `saveNetlist`) to get real per-gate
delays for simulation:
```tcl
write_sdf outputs/${init_top_cell}.apr.sdf
```
Then simulate the **gate-level netlist** (`shift_register.apr.v`) with your
existing testbench plus the TSMC functional models
(`~/tsmc65_work/FE_vlg/.../tcbn65gplus.v`), back-annotating the SDF:
```verilog
initial $sdf_annotate("shift_register.apr.sdf", dut_instance_name);
```
Compare results against your original RTL simulation — logic should match
exactly; only the timing (when signals settle) should differ, now showing
real gate + wire delay instead of zero-delay simulation.
