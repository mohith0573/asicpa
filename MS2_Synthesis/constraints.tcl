## Clock with frequency of 10000ps = 100MHz. EDIT period/port name for your design.
## Shift registers aren't usually timing-aggressive — start loose, tighten later.
create_clock -name "clk" -period 10000 { clk }
set_dont_touch_network [find port clk]

## Pointer to all inputs except clk
set prim_inputs [remove_from_collection [all_inputs] [find port clk]]
## If you have a reset port, uncomment and adjust:
## set prim_inputs_no_rst [remove_from_collection $prim_inputs [find port rst_n]]

## Set clk uncertainty (skew) and transition (slew)
set_clock_uncertainty 0.01 clk
set_clock_transition 32 clk

## Set input delay & drive on all inputs
set_input_delay -clock clk 0.1 [copy_collection $prim_inputs]

## Set output delay & load on all outputs
set_output_delay -clock clk 0.100 [all_outputs]
set_load 0.010 [all_outputs]

## Wire load model — lets DC estimate internal parasitics before real routing exists
set_wire_load_mode "segmented"

set_max_fanout 128 top

set_host_options -max_cores 8
