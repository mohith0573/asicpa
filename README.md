# TSMC 65nm Digital Flow — Shift Register (and beyond)

This is a **direct adaptation of your actual ECE755 ASAP7 flow** (same
`.synopsys_dc.setup`/`.synopsys_pt.setup` department templates — which
already had a built-in `tcbn65gplustc` branch — same `apr_reference.tcl`
structure, same tools: **Design Compiler → Innovus → Virtuoso → PrimeTime**),
re-pointed at the TSMC 65nm PDK files you extracted and matched earlier.

## Confirmed vs. placeholder — read this before running MS3

Most of this flow is directly confirmed against real files you've already
inspected (library paths, LEF paths, the exact site/row-height numbers from
the cell LEF, the professor-confirmed HVH stack). A handful of items in
`MS3_APR/apr_reference.tcl` are still **placeholders** because I don't have
real TSMC-specific data for them — mostly exact cell names and DRC-derived
geometry. These are called out explicitly in `MS3_APR/README.md` as a
checklist, with the exact `grep` commands to resolve each one. **Do not run
MS3 without going through that checklist first** — most placeholders will
error out immediately, which is fine, but a couple (power-grid widths) will
run without erroring while possibly being physically wrong, so those need a
deliberate check rather than "run and see."

MS2, MS4, and MS5 have no unresolved placeholders — those are ready to run
once you fill in your actual RTL filename/module name and port names.

## Directory layout

```
tsmc65_flow/
  MS2_Synthesis/   RTL -> gate-level netlist (Design Compiler)
  MS3_APR/         netlist -> placed & routed layout (Innovus), GDS export
  MS4_PostAPR/     GDS -> Virtuoso view (manual GUI steps, README only)
  MS5_STA/         post-route static timing + power signoff (PrimeTime)
```

## Before running anything — edit these for your design

- `MS2_Synthesis/analyze.tcl` — your RTL file(s)
- `MS2_Synthesis/syn_script.tcl` — `set top` (line near the top)
- `MS2_Synthesis/constraints.tcl` — clock port name/period, if not literally
  `clk`
- `MS3_APR/apr_reference.tcl` — `init_verilog`/`init_top_cell` near the top,
  **plus the confirm checklist in `MS3_APR/README.md`**
- `MS5_STA/pt_script.tcl` — `set top`

## Flow order

1. `MS2_Synthesis/` — `dc_shell -f ./syn_script.tcl -output_log_file ./dc_output.txt`
2. `MS3_APR/` — after the confirm checklist: `innovus -no_gui -files apr_reference.tcl`
3. `MS4_PostAPR/` — Virtuoso GUI steps, see README
4. `MS5_STA/` — copy files into local `outputs/` (see README), then `pt_shell -f pt_script.tcl`

Post-layout **functional** verification (SDF back-annotated gate-level
simulation, which Prof. Zheng specifically asked for and ECE755 didn't
cover) is detailed in `MS5_STA/README.md`.

## Confirmed with Prof. Zheng

1. **Tech LEF row orientation: HVH** — aligns with the standard cells'
   horizontal power rails.
2. **Metal stack: `1p9m_6X1Z1U_ALRDL`** confirmed correct for the RF
   integration target (our `9M_6X1Z1U_UTRDL` tech LEF).

Still using the `typical` RC corner for now — multi-corner signoff can be
added later once the single-corner flow is proven to work.
