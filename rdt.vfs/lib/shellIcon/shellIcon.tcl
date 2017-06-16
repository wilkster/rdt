# shell icon retrieval tool
load [file join [file dirname [info script]] shellicon0.2.dll]

#------------------------------------------------------------------------------
# Fix a bug where the image is returned twice in a string
#------------------------------------------------------------------------------
proc getShellIcon {file} {
   if {[catch {shellicon::get $file} icon] } then {
      debug "$file->$icon"
      set icon ""
   }
   return $icon
}

#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
proc usedImages {args} {
   set used 0
   set nonused 0
   foreach name [image names] {
      if {![image inuse $name]} {
         # image delete $name 
         log "$name not used"
         incr nonused
      } else {
         incr used
      }
   }
   log "used=$used, unused=$nonused"
}
#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
proc testtest {args} {
   set img [getShellIcon .]
   image delete $img
}

package provide shellIcon 1.0