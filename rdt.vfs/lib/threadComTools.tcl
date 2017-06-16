#---------------------------------------------------------------------------- 
# Common tools for threads
#---------------------------------------------------------------------------- 
proc log {txt} {
   set H [tsv::get rdt H]
   set txt "[clock format [clock seconds] -format {%D %T}] [thread::id]: $txt"
   thread::send -async $H [list tlog $txt]
}
proc debug {txt} {
#   set H [tsv::get rdt H]
#   set txt "[clock format [clock seconds] -format {%D %T}] [thread::id]: $txt"
#   thread::send -async $H [list tlog $txt]
}
proc logerr {txt} {
   set H [tsv::get rdt H]
   set txt "[clock format [clock seconds] -format {%D %T}] [thread::id]: $txt\n$::errorInfo"
   thread::send -async $H [list tlogerr $txt]
}
#------------------------------------------------------------------------------
# Join the folder and file
#------------------------------------------------------------------------------
proc joinFile {folder fname} {
   return [file nativename [file join $folder $fname]]
}
#------------------------------------------------------------------------------
# return time formatted
#------------------------------------------------------------------------------
proc ftime {secs} {
   return [clock format $secs -format {%D %T}]
}
package provide threadComTools 1.0

