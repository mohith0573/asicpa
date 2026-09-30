#=====================================================================
## Innovus APR -- TSMC 65nm (tcbn65gplus_200a, HVH, 9M_6X1Z1U_UTRDL)
## All TSMC PDK files are copied flat into this folder (no subfolders).
## Remaining unresolved placeholders (search "PLACEHOLDER" / "CONFIRM"):
##   - well-tap cell name
##   - tie-hi/tie-lo cell names
##   - power-grid width/spacing numbers (need DRC deck)
## See README.md checklist before running.
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
set init_verilog {./shiftregister.vg}
set init_design_netlisttype {Verilog}
set init_design_settop {1}
set init_top_cell {shiftregister}

## ---- Flat paths -- all files copied directly into this folder ----
set CELL_LEF "./tcbn65gplus_9lmT2.lef"
set TECH_LEF "./PRTF_EDI_N65_9M_6X1Z1U_UTRDL.24a.tlef"

# tech lef first, cell lef later (same order as the reference flow)
set init_lef_file "$TECH_LEF $CELL_LEF"

set fp_core_cntl {aspect}
set fp_aspect_ratio {1.0000}
set extract_shrink_factor {1.0}
set init_assign_buffer {0}
set init_pwr_net {VDD}
set init_gnd_net {VSS}
## CONFIRM: VDD/VSS pin names -- very likely correct (standard convention),
## verify with: grep -i "^PIN VDD\|^PIN VSS" $CELL_LEF

set init_cpf_file {}
set init_mmmc_file {./top.mmmc}

init_design

#############################################################
## Tech node / general settings
#############################################################
## Real error encountered: "N65" is not a valid -node enum in this Innovus
## version (v21.19) -- its -node list is entirely modern FinFET-era names
## (N7, N5, ...) plus a few foundry-specific advanced codes; there is no
## legacy-65nm-specific entry at all. "unspecified" is explicitly listed
## as a valid value, so -process 65 alone still sets the real numeric
## process node while -node stays generic/non-committal.
if {$VERSION <= 19} {
	setDesignMode -process 65
} else {
	setDesignMode -process 65 -node unspecified
}

setMultiCpuUsage -localCpu 8

## Routing layer range: our stack has 9 total metal layers (vs ASAP7's 7),
## so the top layer(s) reserved for power move up accordingly -- routing
## up to M8, reserving M9 (the ultra-thick top layer) for power/RF use.
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
## CONFIRMED from real M8/M9 layer data in the tech LEF:
##   M8: min WIDTH 0.400, SPACINGTABLE up to 1.500 (long runs, large widths)
##   M9: min WIDTH 2, flat SPACING 2 (no table)
## Ring sits on both M8 and M9, so must satisfy the stricter M9 rule.
set FP_RING_OFFSET 1.0
set FP_RING_WIDTH 2.5
set FP_RING_SPACE 2.5
set FP_RING_SIZE [expr {$FP_RING_SPACE + 2*$FP_RING_WIDTH + $FP_RING_OFFSET + 1.0}]

## CONFIRMED from the standard cell LEF's SITE block:
##   SITE core  SIZE 0.200 BY 1.800 ;  SYMMETRY Y ; CLASS CORE ;
## This is a 9-track library (vs ASAP7's 7.5-track "asap7sc7p5t"), which
## is exactly why the row height differs -- a real architectural fact of
## this specific library, not an arbitrary number. No 4x-scaling
## multiplication needed here (that was an ASAP7-specific convention);
## TSMC's SITE already reports the real usable row height directly.
set cellheight 1.800
set cellhgrid  0.200

## Floorplan size target -- tune FP_TARGET once you know your synthesized
## design's actual cell count (check ../MS2_Synthesis/reports/synth.area.rpt).
## Aim for roughly 65-75% utilization -- same lesson as the earlier
## empty-floorplan issue when this number didn't match the real design size.
set FP_TARGET 80
set FP_MUL 5

set fpxdim [expr $cellhgrid * $FP_TARGET*$FP_MUL]
set fpydim [expr $cellheight * $FP_TARGET]

fpiGetSnapRule

## CONFIRMED site name: "core" (from the LEF's own SITE definition --
## not a TSMC-branded name like ASAP7's "asap7sc7p5t").
floorPlan -site core -s $fpxdim $fpydim $FP_RING_SIZE $FP_RING_SIZE $FP_RING_SIZE $FP_RING_SIZE -noSnap

if {$VERSION >= 21} {
	add_tracks -snap_m1_track_to_cell_pins
	add_tracks -mode replace -offsets {M5 vertical 0}
	deleteAllFPObjects
}

## CONFIRMED via the real cell list (grep "^MACRO " on the cell LEF):
## this library has NO standalone tap/well-tie cell -- no TAP-named macro
## exists at all. Well-tie is most likely handled instead by the
## N-well-aware filler cells (FILL_NW_HH, FILL_NW_LL, FILL_NW_FA_LL), a
## common commercial-library approach ASAP7 (academic) didn't use. So: no
## explicit addWellTap step. Filler insertion using these FILL_NW_* cells
## should happen after placement, before routing (addFiller). Worth a
## quick confirmation with Colin/Prof. Zheng that this is correct for
## this specific library before assuming it's the final word.

#############################################################
## Pin assignment -- fully dynamic, driven by the actual synthesized
## netlist, per Prof. Zheng's floorplan spec:
##   - output ports, in order: even index -> LEFT, odd index -> RIGHT
##     (channel 0 left, channel 1 right, channel 2 left, ... matches
##      "channel N sits below channel N-2 on the same side")
##   - every input port (including clk) -> BOTTOM
## No channel count or port-naming assumption needed -- this reads
## whatever ports actually exist in the netlist at APR time.
#############################################################
set outPins {}
set inPins  {}
foreach t [dbGet top.terms] {
    set dir [dbGet $t.direction]
    set nm  [dbGet $t.name]
    if {$dir == "output"} {
        lappend outPins $nm
    } else {
        ;# covers "input" and "inout" -- everything not an output goes
        ;# to the bottom per the spec (clk included)
        lappend inPins $nm
    }
}

set leftPins  {}
set rightPins {}
for {set idx 0} {$idx < [llength $outPins]} {incr idx} {
    set pinName [lindex $outPins $idx]
    if {[expr {$idx % 2}] == 0} {
        lappend leftPins $pinName
    } else {
        lappend rightPins $pinName
    }
}

setPinAssignMode -pinEditInBatch true

editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side LEFT   -layer 3 -spreadType center -spacing 2.016 -pin $leftPins
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side RIGHT -layer 3 -spreadType center -spacing 2.016 -pin $rightPins
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side BOTTOM -layer 3 -spreadType center -spacing 2.016 -pin $inPins

editPin -snap TRACK -pin *
setPinAssignMode -pinEditInBatch false
legalizePin

#############################################################
## Power ring -- top two metal layers of the (9-layer) stack
#############################################################
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer AP -stacked_via_bottom_layer M1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top M9 bottom M9 left M8 right M8} -width $FP_RING_WIDTH -spacing $FP_RING_SPACE -offset $FP_RING_OFFSET -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None

#############################################################
## M2 follow-pin rails (one per standard cell row)
#############################################################
## PLACEHOLDER widths -- confirm against DRC_Command_File.
addStripe  -skip_via_on_wire_shape blockring \
    -direction horizontal \
    -set_to_set_distance [expr 2*$cellheight] \
    -skip_via_on_pin Standardcell \
    -stacked_via_top_layer  M1 \
    -layer M2 \
    -width 0.2 \
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
    -width 0.2 \
    -nets {VSS} \
    -stacked_via_bottom_layer M1 \
    -start_from bottom \
    -snap_wire_center_to_grid None \
    -start_offset [expr $cellheight - 0.05] \
    -stop_offset -0.05

#############################################################
## M3 vertical power stripes
#############################################################
## PLACEHOLDER -- refine against DRC deck.
set m3pwrwidth 1.0
set m3pwrspacing 0.5
set m3pwrset2setdist 20.0

addStripe  -skip_via_on_wire_shape Noshape \
    -set_to_set_distance $m3pwrset2setdist \
    -skip_via_on_pin Standardcell \
    -stacked_via_top_layer AP \
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
sroute -connect { corePin } -layerChangeRange { M1(1) M9(1) } -blockPinTarget { nearestTarget } -floatingStripeTarget { blockring padring ring stripe ringpin blockpin followpin } -deleteExistingRoutes -allowJogging 0 -crossoverViaLayerRange { M1(1) AP(10) } -nets { VDD VSS } -allowLayerChange 0 -targetViaLayerRange { M1(1) AP(10) }

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
## Filler cells -- fills gaps left between placed standard cells.
## Includes both plain fillers (FILL1/2/4/8/16/32/64) and the N-well-aware
## variants (FILL_NW_HH/LL/FA_LL) that likely provide well-tie/well
## continuity, per the earlier finding that this library has no separate
## standalone tap cell.
## HONEST CAVEAT: addFiller only fills leftover gaps -- it does NOT
## guarantee a fixed maximum distance-to-tap the way addWellTap did for
## ASAP7 (that used -cellInterval to force regular placement regardless
## of gaps). If this library's actual well-tie requirement needs a
## guaranteed max spacing (not just "wherever a gap happens to exist"),
## this may be insufficient -- worth confirming with Colin/Prof. Zheng,
## and checking the DRC deck for any "tap cell spacing" rule specifically.
## Fixed: real flag is "-core" (not "-core_cell"), and it takes a list
## of lists (grouped cell priority sets), confirmed from Innovus's own
## usage message when the wrong flag errored out.
setFillerMode -core {{FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1 FILL1_LL FILL_NW_HH FILL_NW_LL FILL_NW_FA_LL}}
addFiller -cell {FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1 FILL1_LL FILL_NW_HH FILL_NW_LL FILL_NW_FA_LL} -prefix FILLER

#############################################################
## Tie cells
#############################################################
## CONFIRMED via the real cell list: plain TIEH / TIEL macros exist
## (also GTIEH/GTIEL gated variants exist, if a gated tie is ever needed).
set TIE_LO_CELL "TIEL"
set TIE_HI_CELL "TIEH"
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
## GDS export -- flat paths, confirmed files
#############################################################
setStreamOutMode -reset

streamOut outputs/${init_top_cell}.gds.gz \
    -mapFile {./PRTF_EDI_N65_gdsout_6X1Z1U.24a.map} \
    -libName DesignLib \
    -uniquifyCellNames \
    -outputMacros \
    -stripes 1 \
    -mode ALL \
    -units 2000 \
    -reportFile ./reports/gds_stream_out_final.rpt \
    -merge { ./tcbn65gplus.gds }

# final notes:
# - Well-tap and tie-cell names are placeholders -- must be confirmed via
#   grep on the cell LEF before this script will run past floorplan.
# - Power-grid ring/stripe width/spacing numbers are placeholders in a
#   plausible 65nm range, not yet confirmed against TSMC's actual DRC deck.
# - Pin assignment is fully dynamic (reads real ports from the netlist at
#   run time) -- no channel count or naming convention needs to be known
#   ahead of time.
