# Milestone 4: Post-APR (adapted from README_PostAPR.md)

The GDS export is already included at the end of `MS3_APR/apr_reference.tcl`
(no separate "add this command and rerun" step needed, unlike the ASAP7
version — it's built into the confirmed run from the start). Once MS3
finishes successfully, you'll have `MS3_APR/outputs/shift_register.gds.gz` —
unzip it:
```bash
cd ../MS3_APR/outputs
gunzip shift_register.gds.gz
```

## Set up TSMC PDK for Virtuoso

This is a genuine **install** step (registers the Cadence tech library),
not just untarring — same conceptual role as `setup_asap7.csh` in your
ECE755 flow.

```bash
csh
mkdir -p tsmc65_rundir
cd tsmc65_rundir

## CONFIRM the exact install command/flags with Colin or the PDK's own
## readme before running — install scripts often need specific arguments:
cat /volumes/research-localdata/PDKs/TSMC65_05_12_26/MSRF_General_Purpose_Plus/PDK/CadenceOA/tn65cmsp018k3_1_0c/readme
```

## Import GDS into Virtuoso

1. Connect to a CAE machine with GUI access (same as ECE755).
2. Open Virtuoso:
   ```bash
   csh
   cd MS4_PostAPR/tsmc65_rundir
   # source whatever the PDK install step above told you to source
   virtuoso &
   ```
3. In Virtuoso:
   - **File -> New -> Library** — create your own library (e.g. `MS4`),
     choose **"Attach to an existing technology library"** (not "compile a
     new technology library" — you don't have write access to the shared
     PDK, same lesson as the earlier stream-in lock error).
   - **File -> Import -> Stream**
     - Stream File: `../../MS3_APR/outputs/shift_register.gds`
     - `Library`: your new library (e.g. `MS4`)
     - `Attach Tech Library`: the TSMC tech library name (confirm exact
       name from the PDK install output — Cadence-native equivalent of
       `asap7_TechLib` from ECE755)
     - Click **Translate**, ignore layer/text-drop warnings (same as
       ECE755's harmless `XSTRM-333`/`XSTRM-58` warnings)
   - **File -> Open** — select your library, the top cell, `layout` view.
   - You should see the layout of your design.

## What to check

- Utilization should look reasonable (not the ~10% empty-floorplan issue
  from ECE755) — if it looks very sparse, revisit `FP_TARGET` in
  `apr_reference.tcl` and rerun MS3.
- Power ring visible around the perimeter on the top two metal layers.

## Looking ahead: DRC / LVS (for real tapeout signoff)

Not covered in ECE755, but needed for Prof. Zheng's eventual tapeout goal:
- **DRC deck**: `MSRF_General_Purpose_Plus/DRC_Command_File`
- **LVS deck**: `MSRF_General_Purpose_Plus/LVS_Command_File`
- Confirm with Colin whether the server runs Calibre or Cadence Pegasus —
  the command files may be tool-specific.

This is a separate, dedicated session once the basic RTL-to-GDS loop is
proven to work end to end.
