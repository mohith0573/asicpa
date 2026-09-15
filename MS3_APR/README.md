# MS3 — Place & Route (Innovus)

`apr_reference.tcl` is a faithful adaptation of your ECE755 `apr_reference.tcl`
structure (same version-compatibility branches, same power-grid/CTS/route
sequence), substituting TSMC 65nm paths wherever they're **confirmed**, and
clearly marking a few things as **placeholders** where I don't have real
TSMC-specific data (mostly: exact cell names, and DRC-rule-derived
width/spacing numbers).

**Do not run this script start-to-finish yet.** Work through the checklist
below first — most placeholders will cause a hard error early (before any
real damage/wasted runtime), but the power-grid width/spacing placeholders
will run without erroring while producing possibly-wrong (too tight or too
loose) geometry, so those need a deliberate check, not just "run and see
what breaks."

## Confirm checklist, in the order they'll actually block you

1. **Well-tap cell name** (script will error immediately without this):
   ```bash
   grep -i "^CELL.*TAP" /home/mthatikonda/tsmc65_work/BE_sef/TSMCHOME/digital/Back_End/lef/tcbn65gplus_200a/lef/tcbn65gplus_9lmT2.lef
   ```
   Update `TAPCELL_NAME` near the top of `apr_reference.tcl`.

2. **Tie-hi/tie-lo cell names** (needed once you reach `addTieHiLo`, later
   in the script):
   ```bash
   grep -i "^CELL.*TIE" /home/mthatikonda/tsmc65_work/BE_sef/TSMCHOME/digital/Back_End/lef/tcbn65gplus_200a/lef/tcbn65gplus_9lmT2.lef
   ```
   Update `TIE_LO_CELL`/`TIE_HI_CELL`.

3. **VDD/VSS pin names** (used from `init_pwr_net`/`init_gnd_net` onward —
   very likely already correct, standard convention, but cheap to confirm):
   ```bash
   grep -i "^PIN VDD\|^PIN VSS" /home/mthatikonda/tsmc65_work/BE_sef/TSMCHOME/digital/Back_End/lef/tcbn65gplus_200a/lef/tcbn65gplus_9lmT2.lef
   ```

4. **Real metal layer names** (affects routing layer range, ring layers,
   and every `addStripe -layer` call):
   ```bash
   grep "^LAYER" /home/mthatikonda/tsmc65_work/tech_lef/PRTF_EDI_65nm_001_Cad_V24a/PR_tech/Cadence/LefHeader/HVH/PRTF_EDI_N65_9M_6X1Z1U_UTRDL.24a.tlef
   ```
   The script currently assumes plain `M1`...`M9` naming with the ring on
   `M8`/`M9` and routing up to `M8` — **confirm this matches what actually
   comes back**, since thick top metal layers sometimes have different
   names (e.g. `AP`, `RDL`) rather than continuing the `Mn` sequence.

5. **Power grid width/spacing numbers** (`addStripe` calls for M2/M3/M4,
   and the `FP_RING_*` values) — these are **placeholder values in a
   plausible 65nm range**, not derived from TSMC's actual design rules the
   way the ASAP7 numbers were derived from ASAP7's DRC deck. `verify_drc`
   near the end of the script will catch outright violations, but passing
   `verify_drc` doesn't mean these are *good* values (could be needlessly
   conservative, wasting area). Once you're past a first working run,
   revisit these against `MSRF_General_Purpose_Plus/DRC_Command_File`'s
   actual minimum width/spacing rules per layer.

## Why some of the original ASAP7 numbers couldn't just carry over

`cellheight`/`cellhgrid` **are** confirmed and correctly adapted — pulled
directly from the standard cell LEF's `SITE core` block (`SIZE 0.200 BY
1.800`), the same way you'd look them up for any new library. The power-grid
width/spacing numbers, though, were originally derived from ASAP7's specific
7nm design rules (scaled 4x in that particular academic kit) — copying those
exact numbers to a 65nm process would be physically meaningless, since 65nm
minimum widths are generally larger, not smaller. That's why those are
flagged placeholders rather than confidently reused.

## Running it (once the checklist above is done)

```bash
csh
source /cae/apps/env/<innovus env script — confirm exact name with Colin>
innovus -no_gui -files apr_reference.tcl
```

## Debugging (same lessons as ECE755)

- Read the log top-to-bottom, fix the first real error.
- If `floorPlan` or `addWellTap` errors immediately, that's almost
  certainly the tap-cell name placeholder — check item 1 above first.
- If `verify_drc` reports violations, check the specific layer/rule it
  names against the DRC deck, and adjust the corresponding placeholder
  width/spacing rather than guessing again.
