#=====================================================================
## Innovus APR — TSMC 65nm (tcbn65gplus_200a, HVH, 1p9m_6X1Z1U_ALRDL)
## Faithful adaptation of the ASAP7 apr_reference.tcl structure.
## Every ASAP7-specific number/name is called out explicitly below —
## some are CONFIRMED (from files you've already inspected), others are
## PLACEHOLDERS you must confirm before trusting the physical result
## (see the CONFIRM checklist in README.md).
#=====================================================================

file delete -force ./timingReports
file delete -force ./outputs
file delete -force ./reports
file delete -force {*}[glob -nocomplain *rpt*]
file mkdir ./reports
file mkdir ./outputs

set VERSION 21

set init_design_uniquify 1

## ---- EDIT: your design ----
set init_verilog {../MS2_Synthesis/outputs/shift_register.vg}
set init_design_netlisttype {Verilog}
set init_design_settop {1}
set init_top_cell {shift_register}

## ---- CONFIRMED paths (from the extraction/matching work already done) ----
set CELL_LEF "/home/mthatikonda/tsmc65_work/BE_sef/TSMCHOME/digital/Back_End/lef/tcbn65gplus_200a/lef/tcbn65gplus_9lmT2.lef"
set TECH_LEF "/home/mthatikonda/tsmc65_work/tech_lef/PRTF_EDI_65nm_001_Cad_V24a/PR_tech/Cadence/LefHeader/HVH/PRTF_EDI_N65_9M_6X1Z1U_UTRDL.24a.tlef"

# tech lef first, cell lef later (same order as ASAP7 flow)
set init_lef_file "$TECH_LEF $CELL_LEF"

set fp_core_cntl {aspect}
set fp_aspect_ratio {1.0000}
set extract_shrink_factor {1.0}
set init_assign_buffer {0}
set init_pwr_net {VDD}
set init_gnd_net {VSS}
## CONFIRM: VDD/VSS are the standard TSMC pin names and very likely correct,
## but verify with: grep -i "^PIN VDD\|^PIN VSS" $CELL_LEF

set init_cpf_file {}
set init_mmmc_file {./top.mmmc}

init_design

#############################################################
## Tech node / general settings
#############################################################
if {$VERSION <= 19} {
	setDesignMode -process 65
} else {
	setDesignMode -process 65 -node N65
}

setMultiCpuUsage -localCpu 8

## CONFIRM routing layer range against the actual TSMC stack (9 metal
## layers total here, vs ASAP7's 7 — the original used 2-7; for a 9-layer
## stack you likely want a wider or shifted range, e.g. 2-8, leaving the
## thick top metal (layer 9) reserved for power/RF routing rather than
## signal routing). Confirm against the tech LEF's LAYER list:
##   grep "^LAYER" $TECH_LEF
if {$VERSION <= 20} {
	setNanoRouteMode -routeBottomRoutingLayer 2
	setNanoRouteMode -routeTopRoutingLayer 8
} else {
	setDesignMode -bottomRoutingLayer 2
	setDesignMode -topRoutingLayer 8
}

globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *

#############################################################
## Floorplan
#############################################################
## ASAP7's ring geometry (FP_RING_OFFSET/WIDTH/SPACE below 1um) reflects
## 7nm-era minimum widths and is NOT valid at 65nm — reusing those exact
## numbers would very likely violate 65nm minimum width/spacing rules in
## the other direction (too thin) or waste area (if actually fine but
## overly conservative isn't checked). These are placeholder values in a
## plausible 65nm range; CONFIRM against the DRC deck
## (MSRF_General_Purpose_Plus/DRC_Command_File) before trusting verify_drc.
set FP_RING_OFFSET 1.0
set FP_RING_WIDTH 2.0
set FP_RING_SPACE 1.0
set FP_RING_SIZE [expr {$FP_RING_SPACE + 2*$FP_RING_WIDTH + $FP_RING_OFFSET + 1.0}]

## CONFIRMED from the standard cell LEF's SITE block:
##   SITE core  SIZE 0.200 BY 1.800 ;  SYMMETRY Y ; CLASS CORE ;
## i.e. placement grid pitch (X) = 0.200um, single-row height (Y) = 1.800um.
## Unlike ASAP7's cellheight formula (0.270*4, because ASAP7's "unit" was a
## quarter of the real row height), TSMC's SITE already reports the real
## row height directly — no multiplication needed.
set cellheight 1.800
set cellhgrid  0.200

## Floorplan size target — same utilization-style knob as ASAP7's FP_TARGET/
## FP_MUL, just using the confirmed TSMC grid numbers above. FP_TARGET
## controls total row count; tune this once you know your synthesized
## design's actual cell count (check ./reports/synth.area.rpt from MS2 —
## aim for roughly 65-75% utilization here, same lesson as the ECE755
## floorplan-too-empty issue).
set FP_TARGET 80
set FP_MUL 5

set fpxdim [expr $cellhgrid * $FP_TARGET*$FP_MUL]
set fpydim [expr $cellheight * $FP_TARGET]

fpiGetSnapRule

## CONFIRM the site name below — from the LEF this is literally "core"
## (not a TSMC-branded name like ASAP7's "asap7sc7p5t"):
floorPlan -site core -s $fpxdim $fpydim $FP_RING_SIZE $FP_RING_SIZE $FP_RING_SIZE $FP_RING_SIZE -noSnap

if {$VERSION >= 21} {
	add_tracks -snap_m1_track_to_cell_pins
	add_tracks -mode replace -offsets {M5 vertical 0}
	deleteAllFPObjects
}

## PLACEHOLDER: TSMC well-tap cell name is NOT confirmed. ASAP7's
## "TAPCELL_ASAP7_75t_R" name obviously doesn't exist in this library.
## Find the real name with:
##   grep -i "^CELL.*TAP" $CELL_LEF
## or check the Verilog models: grep -i "tap" tcbn65gplus.v
set TAPCELL_NAME "TSMC_TAPCELL_PLACEHOLDER"
addWellTap -cell $TAPCELL_NAME -cellInterval 12.960 -inRowOffset 1.296

if {$VERSION >= 21} {
	addWellTap -cell $TAPCELL_NAME -cellInterval 12.960 -inRowOffset 1.296
}

#############################################################
## Pin assignment — generic (works for any port list, unlike the
## original's hardcoded DNN port names x0/w04/out0 etc.)
#############################################################
setPinAssignMode -pinEditInBatch true
set allPins [dbGet top.terms.name]
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -spreadType center -spacing 2.016 -pin $allPins
editPin -snap TRACK -pin *
setPinAssignMode -pinEditInBatch false
legalizePin

#############################################################
## Power ring (top two metal layers of the stack)
#############################################################
## CONFIRM the actual top-layer names in this 9-metal stack — ASAP7's ring
## used M6/M7 (its top two of seven). For a 9-layer stack the equivalent
## "top two" would likely be M8/M9, but the thick top metal (the "U"/"Z"
## layers in the stack code) may have different names in the tech LEF
## (e.g. AP, RDL) rather than plain M8/M9. Check with:
##   grep "^LAYER" $TECH_LEF
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer Pad -stacked_via_bottom_layer M1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top M9 bottom M9 left M8 right M8} -width $FP_RING_WIDTH -spacing $FP_RING_SPACE -offset $FP_RING_OFFSET -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None

#############################################################
## M2 follow-pin rails (one per standard cell row) — same concept as
## ASAP7, generic across any 65nm cell library since it just needs the
## confirmed row height, not any ASAP7-specific pitch number.
#############################################################
## PLACEHOLDER widths (0.1-0.2um range is a plausible starting guess for
## 65nm M2, but NOT derived from TSMC's actual minimum width/spacing rule
## the way ASAP7's 0.072 was derived from its DRC deck). Confirm against
## DRC_Command_File before trusting verify_drc results.
addStripe  -skip_via_on_wire_shape blockring \
    -direction horizontal \
    -set_to_set_distance [expr 2*$cellheight] \
    -skip_via_on_pin Standardcell \
    -stacked_via_top_layer  M1 \
    -layer M2 \
    -width 0.15 \
    -nets {VDD} \
    -stacked_via_bottom_layer M1 \
    -start_from bottom \
    -snap_wire_center_to_grid None \
    -start_offset -0.05 \
    -stop_offset -0.05

addStripe  -skip_via_on_wire_shape blockring \
    -direction horizontal \
    -set_to_set_distance [expr 2*$cellheight] \
    -skip_via_on_pin Standardcell \
    -stacked_via_top_layer  M1 \
    -layer M2 \
    -width 0.15 \
    -nets {VSS} \
    -stacked_via_bottom_layer M1 \
    -start_from bottom \
    -snap_wire_center_to_grid None \
    -start_offset [expr $cellheight - 0.05] \
    -stop_offset -0.05

#############################################################
## M3 vertical power stripes
#############################################################
## PLACEHOLDER — same caveat as above, refine against DRC deck.
set m3pwrwidth 1.0
set m3pwrspacing 0.5
set m3pwrset2setdist 20.0

addStripe  -skip_via_on_wire_shape Noshape \
    -set_to_set_distance $m3pwrset2setdist \
    -skip_via_on_pin Standardcell \
    -stacked_via_top_layer Pad \
    -spacing $m3pwrspacing \
    -xleft_offset 0.5 \
    -layer M3 \
    -width $m3pwrwidth \
    -nets {VDD VSS} \
    -stacked_via_bottom_layer M2 \
    -start_from left

#############################################################
## M4 horizontal power stripes
#############################################################
set m4pwrwidth 1.0
set m4pwrspacing 1.0
set m4pwrset2setdist 25.0

addStripe  -skip_via_on_wire_shape Noshape \
    -direction horizontal \
    -set_to_set_distance $m4pwrset2setdist \
    -skip_via_on_pin Standardcell \
    -stacked_via_top_layer M8 \
    -spacing $m4pwrspacing \
    -layer M4 \
    -width $m4pwrwidth \
    -nets {VDD VSS} \
    -stacked_via_bottom_layer M3 \
    -start_from bottom

setSrouteMode -reset
setSrouteMode -viaConnectToShape { noshape }
sroute -connect { corePin } -layerChangeRange { M1(1) M9(1) } -blockPinTarget { nearestTarget } -floatingStripeTarget { blockring padring ring stripe ringpin blockpin followpin } -deleteExistingRoutes -allowJogging 0 -crossoverViaLayerRange { M1(1) Pad(10) } -nets { VDD VSS } -allowLayerChange 0 -targetViaLayerRange { M1(1) Pad(10) }

editPowerVia -add_vias 1 -orthogonal_only 0

verify_drc

#############################################################
## Placement + optimization
#############################################################
setOptMode -holdTargetSlack  0.020
setOptMode -setupTargetSlack 0.020

colorizePowerMesh

place_opt_design

#############################################################
## Tie cells
#############################################################
## PLACEHOLDER: TSMC tie-hi/tie-lo cell names, NOT confirmed. Find real
## names with:
##   grep -i "^CELL.*TIE" $CELL_LEF
set TIE_LO_CELL "TSMC_TIELO_PLACEHOLDER"
set TIE_HI_CELL "TSMC_TIEHI_PLACEHOLDER"
setTieHiLoMode -maxFanout 5
addTieHiLo -prefix TIE -cell [list $TIE_LO_CELL $TIE_HI_CELL]

#############################################################
## Clock tree synthesis
#############################################################
ccopt_design

set_interactive_constraint_modes [all_constraint_modes -active]
reset_propagated_clock [all_clocks]
set_propagated_clock [all_clocks]

legalizePin

#############################################################
## Routing
#############################################################
routeDesign

setAnalysisMode -analysisType onChipVariation
setSIMode -enable_glitch_report true
setSIMode -enable_glitch_propagation true
setSIMode -enable_delay_report true
optDesign -postRoute
optDesign -postRoute -hold

report_noise -threshold 0.2
report_noise -bumpy_waveform

#############################################################
## Reports
#############################################################
report_power > ./reports/post_route.power.rpt
report_timing > ./reports/post_route.timing.rpt
report_area > ./reports/post_route.area.rpt
report_analysis_summary > ./reports/post_route.summary.rpt

verify_drc > ./reports/post_route.drc.rpt

#############################################################
## Extract parasitics + save outputs
#############################################################
rcOut -rc_corner rc_typ -spef outputs/${init_top_cell}.apr.spef

saveNetlist outputs/${init_top_cell}.apr.v
write_sdc outputs/${init_top_cell}.apr.sdc
saveNetlist outputs/${init_top_cell}.apr_pg.v -includePowerGround -excludeLeafCell
saveDesign outputs/${init_top_cell}.final.enc

#############################################################
## GDS export — CONFIRMED paths (GDS kit is revision 140a, not 200a;
## see README for why that's correct, not stale)
#############################################################
setStreamOutMode -reset

streamOut outputs/${init_top_cell}.gds.gz \
    -mapFile {/home/mthatikonda/tsmc65_work/tech_lef/PRTF_EDI_65nm_001_Cad_V24a/PR_tech/Cadence/GdsOutMap/PRTF_EDI_N65_gdsout_6X1Z1U.24a.map} \
    -libName DesignLib \
    -uniquifyCellNames \
    -outputMacros \
    -stripes 1 \
    -mode ALL \
    -units 4000 \
    -reportFile ./reports/gds_stream_out_final.rpt \
    -merge { /home/mthatikonda/tsmc65_work/BE_gds/TSMCHOME/digital/Back_End/gds/tcbn65gplus_140a/tcbn65gplus.gds }

# final notes — same caveats as the ASAP7 reference script, plus:
# - Several power-grid/ring numbers above are placeholders needing DRC-deck
#   confirmation before this is trustworthy for real tapeout (see README).
# - Well-tap and tie-cell names are placeholders — must be confirmed via
#   grep on the cell LEF before this script will even run past floorplan.
# - Routing layer range (2-8) and ring layers (M8/M9) assume a plain M1-M9
#   naming convention; confirm actual LAYER names in the tech LEF.
