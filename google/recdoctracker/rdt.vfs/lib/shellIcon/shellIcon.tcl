# shell icon retrieval tool
load [file join [file dirname [info script]] shellicon0.1.dll]

#------------------------------------------------------------------------------
# Fix a bug where the image is returned twice in a string
#------------------------------------------------------------------------------
proc getShellIcon {file} {
   if {[catch {shellicon::get $file} icon] } then {
      puts "getShellIcon:$icon\n $file"
      set icon ""
   }
   return $icon
}


#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
proc testtest {args} {
   set img [getShellIcon .]
   image delete $img
}

package provide shellIcon 1.0