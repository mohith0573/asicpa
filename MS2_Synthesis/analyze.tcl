lappend search_path "."

## EDIT: point at your actual shift register file(s). If split across
## multiple files, list them all here — order doesn't matter, DC resolves
## hierarchy at elaborate time, not analyze time.
analyze -library work -format sverilog { ./shift_register.sv }
