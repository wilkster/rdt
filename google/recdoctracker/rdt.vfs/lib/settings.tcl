#----------------------------------------------------------------------------
# Save the settings contained in variable S::S
#----------------------------------------------------------------------------
namespace eval S {
   variable S
   variable settingsDir
   variable settingsFile
   set S(exclude) "xxx"
   set S(minwid) 300
   set S(minheight) 500
   set S(myRecent) 0
   set S(hashFolder) 0
}

#------------------------------------------------------------------------------
#  Set the home folder
#------------------------------------------------------------------------------
proc S::setHome {where} {
   variable settingsDir $where
}
proc S::readSettings {args} {
   global env
   global SCHASH
   variable settingsDir
   variable S
   variable settingsFile [file join $settingsDir settings.txt]
   ##
   # Load prior shortcut hash file
   #
   if {![file isdirectory $settingsDir]} {
      file mkdir $settingsDir
   } elseif {[file exists $settingsFile]} {
      if {[catch {open $settingsFile r} fid] } then {
         puts $fod
      } else {
         array set S [read $fid]
         close $fid
      }
   }
}
#------------------------------------------------------------------------------
#  Save the shortcut hash file for next time
#------------------------------------------------------------------------------
proc S::saveSettings {args} {
   variable S
   variable settingsFile
   if {[catch {open $settingsFile w} fod] } then {
      puts $fod
   } else {
      puts $fod [array get S]
      close $fod
   }
}
#----------------------------------------------------------------------------
# Set the Icon type
#----------------------------------------------------------------------------
proc S::setIconState {icon value} {
   variable S
   set S(icon,$icon) $value
}
#----------------------------------------------------------------------------
# Return the Icon type
#----------------------------------------------------------------------------
proc S::getIconState {icon} {
   variable S
   if {[info exists S(icon,$icon)] && ($S(icon,$icon) == 0)} {
      set S(icon,$icon) 0
   } else {
      # special case for kits, don't want the kit icon
      if {$icon eq "tclkit"} {
         set S(icon,$icon) 0
      }  else {
         set S(icon,$icon) 1
      }
   }
   return $S(icon,$icon)
}
package provide settings 1.0



