# ============================================================================
# LOC constraints for idelay_dtc_top_cascade2 (2-stage dedicated IDELAYE3 cascade)
# ============================================================================
# The dedicated cascade route (CASC_OUT -> CASC_IN) exists ONLY between
# ADJACENT IDELAYE3 BITSLICE sites in the SAME IO bank. If the two IDELAYE3s
# are not placed in adjacent sites, implementation fails with Route 35-19
# ("no CASC path").
#
# Replace the site names below with two ADJACENT IDELAYE3 sites in your target
# IO bank (use the Device window / report_drc to pick valid neighbours).
# The instance names u_master / u_slave come from idelay_dtc_top_cascade2.v.
#
# If the top-level instance name of idelay_dtc_top_cascade2 is unknown, use the
# hierarchical filter form instead:
#   set_property LOC IDELAY_X0Y0 [get_cells -hierarchical -filter {NAME =~ *u_master}]
#   set_property LOC IDELAY_X0Y1 [get_cells -hierarchical -filter {NAME =~ *u_slave}]

set_property LOC IDELAY_X0Y0 [get_cells {*/u_master}]
set_property LOC IDELAY_X0Y1 [get_cells {*/u_slave}]
