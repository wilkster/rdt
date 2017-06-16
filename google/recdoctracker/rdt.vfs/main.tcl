##
# Main startkit entry for RDT
# If user runs this as a script, then just
# source the main application.
if {[catch {
   package require starkit
   if {[starkit::startup] eq "sourced"} {
      return
   }
} result] } then {
   source [file join [file dirname [info script]] rdt.tcl]
} else {
   source [file join $starkit::topdir rdt.tcl]
}

