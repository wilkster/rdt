#----------------------------------------------------------------------------
# Save the settings contained in variable S::S
#----------------------------------------------------------------------------
namespace eval S {
   variable S
   variable Icons
   variable IconsSave
   variable Stemp
   variable settingsDir
   variable settingsFile
   variable monitorFile
   variable iconsFile
   variable lastKey
   variable Tip
   variable hotKeyId ""
   variable done
   set Tip(0) "Recent IconName files\nLeft Button for menu list\nRight Button search window"
   set Tip(1) "Recent IconName files\nRight Button for menu list\nLeft Button search window"
   set S(exclude)        "xxx"
   set S(minwidth)       700
   set S(minheight)      500
   set S(Focus)          0
   set S(SwapButton)     0
   set S(deleteDead)     0
   set S(resetIconCache) 0
   set S(deleteStale)    0
   set S(bgCheckFile)    0
   set S(bias)           0.8
   set S(limitOnBattery) 1
   set S(ontop)          0
   set S(limit)          25
   set S(treeLimit)      500
   set S(age)            "never"
   set S(checkOpen)      1
   set S(useAll)         0
   set S(autoStart)      1
   set S(editTrayIcons)  0
   set S(saveVols)       [list]
   set S(Hotkey)         {Control-Space}
   namespace export saveSettings setIconState getTrayIconData getTrayIcons readSettings saveIcons
   # To detect changes to future button settings
   trace variable ::S::S(SwapButton) w S::ButtonSwapped
}

#------------------------------------------------------------------------------
# The setting for the RMB was updated, change the help text
#------------------------------------------------------------------------------
proc S::ButtonSwapped {args} {
   variable Tip
   variable S
   foreach {iconName} [lsort [S::getTrayIcons]] {
      ::cL$iconName updateTip $Tip($S(SwapButton))
   }
}
#------------------------------------------------------------------------------
#  Set the home folder
#------------------------------------------------------------------------------
proc S::setHome {where} {
   variable settingsDir $where
}
proc S::readSettings {args} {
   variable S
   variable Icons
   variable settingsDir
   variable settingsFile  [file join $settingsDir "settings.txt"]
   variable settings2File [file join $settingsDir "settings2.txt"]
   variable iconsFile     [file join $settingsDir "trayIcons.txt"]
   variable monitorFile   [file join $settingsDir "monitors.txt"]
   ##
   # Load prior shortcut hash file
   #
   if {![file isdirectory $settingsDir]} {
      file mkdir $settingsDir
   } elseif {[file exists $settings2File]} {
      try {
         set fid [open $settings2File r]
         set settingsData [read $fid]
         # old or new style?
         if {[string match "#*" $settingsData]} {
            try {
               eval $settingsData
            } on error result {
               tk_messageBox -icon warning -type ok -title "Open Error" \
               -message "Error interpreting $settingsFile\n$::errorInfo"
               logerr $result
            }
         } else {
            array set S $settingsData
         }
      } on error result {
         logerr $result
      } finally {
         close $fid
      }
   } elseif {[file exists $settingsFile]} {
      try {
         set fid [open $settingsFile r]
         set settingsData [read $fid]
         array set S $settingsData
      } on error result {
         tk_messageBox -icon warning -type ok -title "Open Error" \
         -message "Error interpreting $settingsFile\n$::errorInfo"
         logerr $result
      } finally {
         close $fid
      }
   } else {
      after idle S::newUser
   }

   if {[file exists $monitorFile]} {
      try {
         set fid [open $monitorFile r]
         set settingsData [read $fid]
         try {
            eval $settingsData
         } on error result {
            tk_messageBox -icon warning -type ok -title "Open Error" \
            -message "Error interpreting $monitorFile\n$::errorInfo"
            logerr $result
         } finally {
            close $fid
         }
      } on error result {
         logerr $result
      }
   }

   ##
   # Check for default file, copy it an icons to settings folder as default
   #
   if {! [file exists $iconsFile]} {
      set defFile [file join $::HOME "trayIcons.txt"]
      file copy -force $defFile $iconsFile
      # copy over icons as needed
      foreach iconFile [lsort [glob -nocomplain -directory $::HOME "*.ico"]] {
         set target [file join $settingsDir [file tail $iconFile]]
         if {![file exists $target]} {
            file copy -force $iconFile $target
         } else {
            set sTime [file mtime $iconFile]
            set tTime [file mtime $target]
            if {$sTime > $tTime} {
               log "Replacing $target icon"
               file copy -force $iconFile $target
            }
         }
      }
   }
   ##
   # Load icons file
   #
   if {[file exists $iconsFile]} {
      try {
         set fid [open $iconsFile r]
         set settingsData [read $fid]
         # old or new style?
         if {[string match "#*" $settingsData]} {
            try {
               eval $settingsData
            } on error result {
               tk_messageBox -icon warning -type ok -title "Open Error" \
               -message "Error interpreting $iconsFile\n$::errorInfo"
               logerr $result
            }
         } else {
            array set Icons $settingsData
         }
         # make sure each icon exists and is fully qualified
         foreach {icon} [array names Icons] {
            lassign $Icons($icon) show iconFile exts
            # fully qualifty it
            if {[file dirname $iconFile] eq "."} {
               set iconFile [file join $settingsDir [file tail $iconFile]]
               # if it exists in user settings dir then change it
               if {[file exists $iconFile]} {
                  set Icons($icon) [list $show $iconFile $exts]
               }
            }
         }
      } on error result {
         logerr $result
      } finally {
         close $fid
      }
   }
}

#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
proc S::newUser {args} {
   variable S
   variable settingsDir

   set res [tk_messageBox -message "Welcome to Recent Document Tracker!

This program will allow you to quickly find/launch your
most recent documents by file type. You have complete
control on how to group your recent files using the
icons in the task tray. Use left or right mouse buttons
on each icon to launch a quick menu or more powerful
search table.  You can also adjust settings from then menu.
New icons/settings will be created in '$settingsDir' for you.

To uninstall you may remove the application folder and all
files in '$settingsDir'. The windows registry is not used.     

Use the settings->Manage Tray Icons option to modify the tray icons
and their file settings. Use settings->Manage Folder Monitoring  
to add addtional folders to monitor/scan.

The inital scan may take a few moments to populate the database.

Autostart with login is enabled, you can disable from the settings menu.

Select Yes to edit the tray icons now, or No to skip this step.

Enjoy!
" -type yesno -title "Press OK when done" -icon info]
      if {$res eq "yes"} {
         # will launch after everything settled
         S::settingsGUI   
      }
      # Create an autostart (if user wants it)
      S::makeShortcut

      # Todo: this is a HACK below, need better way to know when inital scan is done
      after 10000 iconDB::setupTypes
}
#------------------------------------------------------------------------------
#  Save the shortcut hash file for next time
#------------------------------------------------------------------------------
proc S::saveSettings {args} {
   variable S
   variable settingsDir
   variable settings2File [file join $settingsDir "settings2.txt"]
   variable settingsFile
   variable iconsFile
   variable monitorFile
   # User Settings
   try {
      set fod [open $settings2File w]
      fconfigure $fod -buffersize 20000
      set result "#######\n"
      append result "# RDT Settings File Saved [clock format [clock seconds]]\n"
      append result "#\n"
      append result "array set S::S \{\n"
      foreach {index} [lsort -dictionary [array names S::S *]] {
         set value [string trim $S::S($index)]
         # Format the line real pretty
         set line [format "   %-25s %s\n" [list $index] [list $value]]
         append result $line
      }
      append result "\}\n"
      puts $fod $result
   } on error result {
      tk_messageBox -icon warning -type ok -title "Open Error" \
      -message "Error opening $settingsFile\n$::errorInfo"
      logerr $result
   } finally {
      close $fod
   }
   # Icon Settings
   try {
      set fod [open $iconsFile w]
      fconfigure $fod -buffersize 20000
      set result "#######\n"
      append result "# RDT Icon Settings File Saved [clock format [clock seconds]]\n"
      append result "#\n"
      append result "array set S::Icons \{\n"
      foreach {index} [lsort -dictionary [array names S::Icons *]] {
         set value [string trim $S::Icons($index)]
         # Format the line real pretty
         set line [format "   %-25s %s\n" [list $index] [list $value]]
         append result $line
      }
      append result "\}\n"
      puts $fod $result
   } on error result {
      tk_messageBox -icon warning -type ok -title "Open Error" \
      -message "Error opening $iconsFile\n$::errorInfo"
      logerr $result
   } finally {
      close $fod
   }
   # File Monitor Settings
   try {
      set fod [open $monitorFile w]
      fconfigure $fod -buffersize 20000
      set result "#######\n"
      append result "# RDT File Monitor Settings File Saved [clock format [clock seconds]]\n"
      append result "#\n"
      append result "array set fileScan::ScanFoldersMaster \{\n"
      foreach {index} [lsort -dictionary [array names fileScan::ScanFoldersMaster *]] {
         set value [string trim $fileScan::ScanFoldersMaster($index)]
         # Format the line real pretty
         set line [format "   %s %s\n" [list $index] [list $value]]
         append result $line
      }
      append result "\}\n"
      puts $fod $result
   } on error result {
      tk_messageBox -icon warning -type ok -title "Open Error" \
      -message "Error opening $iconsFile\n$::errorInfo"
      logerr $result
   } finally {
      close $fod
   }

}
#------------------------------------------------------------------------------
#  Return the tray icon data
#------------------------------------------------------------------------------
proc S::getTrayIconData {iconName} {
   variable Icons
   try {
      return $S::Icons($iconName)
   } on error result {
      return [list "" "" ""]
   }
}
#---------------------------------------------------------------------------- 
# Get old data
#---------------------------------------------------------------------------- 
proc S::getOldIconData {iconName} {
   variable Icons
   try {
      return $S::IconsSave($iconName)
   } on error result {
      return [list "" "" ""]
   }
}
#----------------------------------------------------------------------------
# Set the Icon type
#----------------------------------------------------------------------------
proc S::setIconState {icon value} {
   variable Icons
   try {
      lassign $Icons($icon) show iconFile exts
      set show $value
      set Icons($icon) [list $show $iconFile $exts]
   } on error result {
     logerr "$result\n$::errorInfo"
   }
}
#----------------------------------------------------------------------------
# Return the Icon type
#----------------------------------------------------------------------------
# proc S::getIconState {icon} {
#    variable Icons
#    set show 0
#    try {
#       lassign $Icons($icon) show iconFile exts
#    } on error result {
#      logerr "$result\n$::errorInfo"
#    }
#    return $show
# }

#------------------------------------------------------------------------------
# unspool and spool icon data to support linked variables
#------------------------------------------------------------------------------
proc S::unSpoolIconData {args} {
   variable Stemp
   variable Icons
   variable lastKey
   unset -nocomplain Stemp
   set i 0
   foreach {iconName} [array names Icons] {
      incr i
      set Stemp(iconName,$i) $iconName
      lassign $Icons($iconName) Stemp(iconShow,$i) Stemp(iconFile,$i) Stemp(iconExts,$i)
      # incase of an add or change
      if {![iconDB::iconExists $iconName]} {
         set h [iconDB::readIconFile $Stemp(iconFile,$i)]
         iconDB::addIcon $iconName $h      ;# check in unspool if a new one
      }
   }

   set lastKey $i
}
#---------------------------------------------------------------------------- 
# After saving the data put it back into original settings format
#---------------------------------------------------------------------------- 
proc S::SpoolIconData {args} {
   variable Stemp
   variable Icons
   variable IconsSave
   variable settingsDir
   # since we use a number as key, this will fix any renamed icons
   set prior [list]
   array unset Icons *
   foreach {tag value} [lsort -stride 2 [array get S::Stemp "iconName,*"]] {
      #handle case where name is changed
      set i 0
      set key [lindex [split $tag ","] 1]
      set iconName [string tolower $Stemp(iconName,$key)]
      # make sure there aren't any duplicates
      while {[lsearch $prior $iconName] >= 0} {
         set iconName ${iconName}[incr i]
      }
      set iconFile $Stemp(iconFile,$key)
      if {![string equal -nocase [file dirname $iconFile] $settingsDir]} {
         # if iconfile not a .ico then
         # 1. create a copy as .ico in settings
         # 2.
         # set h [iconDB::readIconFile $file]
         #::ico::writeIcon bubba.ico 1 32 <image>
         try {
            #set img [getShellIcon $iconFile]
            set img [iconDB::readIconFile $iconFile]

            if {$img ne ""} {
               set target [file join $settingsDir ${iconName}.ico]
               ::ico::writeIcon $target 0 32 $img
               set iconFile $target
            } else {
               logerr "Could not read icon from $iconFile"
            }
            iconDB::addIcon $iconName $img

         } on error result {
            logerr $result
         }
      }
      # clean up extensions
      set exts [string map {. ""} [string tolower $Stemp(iconExts,$key)]]
      # point to new iconfile perhaps
      set Icons($iconName) [list $Stemp(iconShow,$key) $iconFile $exts]
      lappend prior $iconName
   }
}

#------------------------------------------------------------------------------
# Snapshot the current icon state
#------------------------------------------------------------------------------
proc S::saveIcons {args} {
   variable Icons
   variable IconsSave
   array unset -nocomplain IconsSave
   array set IconsSave [array get Icons]
}

#------------------------------------------------------------------------------
#  Return the list of active and saved icon Names
#------------------------------------------------------------------------------
proc S::getTrayIcons {args} {
   variable Icons
   return [array names Icons]
}

#------------------------------------------------------------------------------
#  Return the active tray icon names
#------------------------------------------------------------------------------
proc S::getActiveTrayIcons {args} {
   variable Icons
   set Res [list]
   foreach {icon} [array names Icons] {
      if {[lindex $Icons($icon) 0] == 1} {
         lappend Res $icon
      }
   }
   return $Res
}
#------------------------------------------------------------------------------
#  Return the saved tray icon names
#------------------------------------------------------------------------------
proc S::getSavedTrayIcons {args} {
   variable IconsSave
   return [array names IconsSave]
}
#------------------------------------------------------------------------------
# Bring up the settings GUI allowing the icon types to be modified
#------------------------------------------------------------------------------
proc S::settingsGUI {args} {
   variable S
   variable Stemp
   variable Icons
   variable IconsSave

   package require tooltip
   # save pre icon changes
   saveIcons

   destroy .settings
   toplevel .settings
   wm title .settings "Alter Tray Icons Below"
   wm protocol .settings WM_DELETE_WINDOW {S::sgCancel}
   wm protocol .settings WM_SAVE_YOURSELF {S::sgCancel}
   set fr [ttk::labelframe .settings.fr -text "Tray Icon Settings"]
   pack $fr -expand true -fill both
   unSpoolIconData
   # Show sorted by icon name
   foreach {tag value} [lsort -index 1 -stride 2 [array get S::Stemp "iconName,*"]] {
      set key [lindex [split $tag ","] 1]
      set iconExts $S::Stemp(iconExts,$key)
      set iconFile $S::Stemp(iconFile,$key)
      set iconName $S::Stemp(iconName,$key)
      # S::S(iconShow,$iconName)
      if {$iconName ne "folder"} {
         try {
            grid [ttk::checkbutton $fr.${key}-cb -variable S::Stemp(iconShow,$key)] \
                 [ttk::button $fr.${key}-remove -image [iconDB::extToIcon exit] -command [list S::removeIcon $key $fr]] \
                 [ttk::button $fr.${key}-icon -image [::cL$iconName image] -command [list S::openIconFile $fr.${key}-icon $key $iconFile]] \
                 [ttk::entry $fr.${key}-lbl -textvariable S::Stemp(iconName,$key) -width 20]  \
                 [ttk::entry $fr.${key}-ext -textvariable S::Stemp(iconExts,$key) -width 100] \
                 -sticky ew
           # this is very slow
           tooltip::tooltip $fr.${key}-cb "Check to show icon in the tray (after Save & Close)"
           tooltip::tooltip $fr.${key}-remove "Press to permanently remove this icon and its file extensions"
           tooltip::tooltip $fr.${key}-icon "Press icon to change the tooltip icon"
           tooltip::tooltip $fr.${key}-lbl "Name the icon"
           tooltip::tooltip $fr.${key}-ext "Add file extensions associated with this icon (wildcards allowed)"
         } on error result {
            logerr "$result\ - $::errorInfo  "
         }
      }
   }
   # expand the file types
   grid columnconfigure $fr 4 -weight 1
   set frb [ttk::frame .settings.buttons -padding 3]
   pack $frb -expand true -fill both
   grid  \
      [ttk::button $frb.add -text "Add Icon" -command [list S::sgAdd $fr]] \
      [ttk::button $frb.save -text "Apply" -command S::sgSave] \
      [ttk::button $frb.close -text "Apply & Close" -command S::sgClose] \
      [ttk::button $frb.cancel -text "Cancel" -command S::sgCancel] \
      -sticky ew -padx 12 -pady 6
   # expand the buttons
   grid columnconfigure $frb 0 -weight 1
   grid columnconfigure $frb 1 -weight 1
   grid columnconfigure $frb 2 -weight 1
   grid columnconfigure $frb 3 -weight 1
}
#----------------------------------------------------------------------------
# Remove an icon
#----------------------------------------------------------------------------
proc S::removeIcon {iconName parent} {
   variable S
   variable Stemp
   if {[tk_messageBox -title "Please Confirm" -type yesno -icon question -message "Are you sure you remove the icon"] eq "yes"} {
      foreach {child} [winfo children $parent] {
         if {[string match "$parent.$iconName-*" $child]} {
            grid remove $child
         }
      }
      # remove from memory
      array unset Stemp "icon*$iconName"
   # unmap from memory and remove from tray
   }
}
#----------------------------------------------------------------------------
# Add an icon
#----------------------------------------------------------------------------
proc S::sgAdd {fr} {
   variable Stemp
   variable lastKey
   incr lastKey
   set key $lastKey
   set types {
      {{All Files}  {.*} }
      {{Icon Files}  {.ico .dll .exe} }
   }
   set iconFile [tk_getOpenFile \
      -filetypes $types \
      -title "Please select 16x16 iconfile"]
   if {[file exists $iconFile]} {
      set iconName [string tolower [file rootname [file tail $iconFile]]]
      if {[info exists Stemp(iconFile,$iconName)]} {
         if {[tk_messageBox -title "Please Confirm" -type yesno -icon question -message "Are you sure you replace the icon $iconName"] eq "no"} {
            return
         }
      }
      set Stemp(iconExts,$lastKey) ""
      set Stemp(iconFile,$lastKey) $iconFile
      set Stemp(iconShow,$lastKey) 1
      set Stemp(iconName,$lastKey) $iconName
      # get icon for selected file
      set h [getShellIcon $iconFile]
      #set h [iconDB::readIconFile $iconFile]
      #iconDB::addIcon $iconName $h
      grid [ttk::checkbutton $fr.${key}-cb -variable S::Stemp(iconShow,$key)] \
           [ttk::button $fr.${key}-remove -image [iconDB::extToIcon exit] -command [list S::removeIcon $key $fr]] \
           [ttk::button $fr.${key}-icon -image $h -command [list S::openIconFile $fr.${key}-icon $key $iconFile]] \
           [ttk::entry $fr.${key}-lbl -textvariable S::Stemp(iconName,$key) -width 20]  \
           [ttk::entry $fr.${key}-ext -textvariable S::Stemp(iconExts,$key) -width 120]
      # Note - The tray icon doesn't exist yet, only have settings are closed will it exist
      # write out icon to the settings folder so we have it for later?
   }
}
#------------------------------------------------------------------------------
#  Select a new icon for this type
#------------------------------------------------------------------------------
proc S::openIconFile {button key iconFile} {
   variable Stemp
   # todo, later add exe after twapi issues sorted out reading icons from exe files
   set types {
      {{All Files}  {.*} }
      {{Icon Files}  {.ico .dll .exe} }
   }
   set file [tk_getOpenFile -initialdir \
      [file dirname $iconFile] \
      -initialfile $iconFile \
      -filetypes $types \
      -title "Please select 16x16 iconfile"]
   if {[file exists $file]} {
      set Stemp(iconFile,$key) $file
      set h [iconDB::readIconFile $file]
      $button configure -image $h
   }
   # write out icon to the settings folder so we have it for later?
}

#
#------------------------------------------------------------------------------
proc S::sgCancel {args} {
   destroy .settings
}
proc S::sgSave {args} {
   SpoolIconData
   winTaskBar::initTray
}
proc S::sgClose {args} {
   variable S
   variable Stemp
   # Restore Icon Data
   # Any changes will show up in difference of Icons and IconsSave
   SpoolIconData
   destroy .settings
   winTaskBar::initTray
}


#------------------------------------------------------------------------------
#  Create an uninstall file in app folder
#------------------------------------------------------------------------------
proc S::createUninstall {args} {
   variable S
   variable settingsDir
   set meu [info nameofexecutable]
   set me [file nativename $meu]
   set rdt [file tail $meu]
   set AppDir [file nativename [file dirname $meu]]
   set SettingsDir [file nativename $settingsDir]
   set MyAutoStartFile [file nativename [file join [twapi::get_shell_folder CSIDL_STARTUP] "RDT.lnk"]]
   set MyStart [file nativename [file join [twapi::get_shell_folder CSIDL_STARTMENU] "Programs" "RDT"]]

   if {$rdt eq "rdt.exe"} {
      # If running from a wrapped program
      set unInstall [subst {
echo Uninstall RDT
set /p c= Do you want to uninstall RDT?(Y/N):
if /I "%c%" EQU "N" goto :exit
  Taskkill /IM rdt.exe /f
  timeout /t 3
  del "$MyAutoStartFile" /q /f
  rmdir "$MyStart" /q /s
  rmdir "$SettingsDir" /q /s
  cd ..
  rmdir "$AppDir" /q /s
  pause
:exit
      }]
      try {
         set oFile [file join [file dirname $meu] uninstall.bat]
         set fod [open $oFile w] 
      } on error result {
         logerr $result
         return
      }
      try {
         puts $fod $unInstall
      } on error result {
         logerr $result
      } finally {
         close $fod
      }
   }
}
#------------------------------------------------------------------------------
#  Create an autostart entry if one doesn't exist
#------------------------------------------------------------------------------
proc S::makeShortcut {args} {
   variable S
   set meu [info nameofexecutable]
   set me [file nativename $meu]
   set rdt [file tail $meu]
   set shortCutExists 0
   # If running from a wrapped program
   if {$rdt eq "rdt.exe"} {
      # uninstall Script
      S::createUninstall
      # Start Menu Entry
      set MyStart [file join [twapi::get_shell_folder CSIDL_STARTMENU] "Programs" "RDT"]
      try {
         file mkdir $MyStart
      } on error result {
         logerr $result
      }
      try {
         set target [file join $MyStart "RDT.lnk"]
         twapi::write_shortcut $target \
            -desc "Recent Document Tracker (RDT)" \
            -iconpath $me \
            -path $me \
            -workdir [file nativename [file dirname $meu]]
        log "Created $target"
      } on error result {
         logerr $result
      }
      # Auto Start Entry
      set MyStartup [twapi::get_shell_folder csidl_startup]
      foreach {startupfile} [glob -nocomplain -directory $MyStartup "*.lnk"] {
         array set shortcut [twapi::read_shortcut $startupfile -nosearch -noui -timeout 500]
         set target $shortcut(-path)
         #debug "$startupfile->$target"
         if {$target eq $me} {
            #debug "Found Me"
            set shortCutExists 1
            break
         }
      }
      # see if we found a shortcut
      if {! $shortCutExists} {
         # shortcut doesn't exist, ask if we need to add it
         if {$S(autoStart)} {
            set res [tk_messageBox -title "Please Confirm" -type yesno -icon question -message "Do you want to have RDT start at login?"]
            if {$res eq "yes"} {
               set target [file join $MyStartup "RDT.lnk"]
               try {
                  twapi::write_shortcut $target \
                     -desc "Recent Document Tracker (RDT)" \
                     -iconpath $me \
                     -path $me \
                     -workdir [file nativename [file dirname $meu]]
                 log "Created $target"
               } on error result {
                  logerr $result
               }
            } else {
               set S(autoStart) 0
            }
         }
      } else {
         # shortcut exists, see if we need to remove it
         if {! $S(autoStart)} {
            set target [file join $MyStartup "RDT.lnk"]
            if {[file exists $target]} {
               file delete -force $target
               log "Removed $target"
            } else {
               log "Did not find $target to remove"
            }
         }
      }
   } else {
      log "Running as a script - autostart not enabled for scripts"
   }
}

#---------------------------------------------------------------------------- 
# Test Routine
#---------------------------------------------------------------------------- 
proc S:dumpSendto {args} {
   set meu [info nameofexecutable]
   set me [file nativename $meu]
   set rdt [file tail $meu]
   set shortCutExists 0
   # If running from a wrapped program
   set sendTos [glob -nocomplain -directory [twapi::get_shell_folder CSIDL_SENDTO] "*.lnk"]

   foreach {startupfile} $sendTos {
      array set shortcut [twapi::read_shortcut $startupfile -nosearch -noui -timeout 500]
      set target $shortcut(-path)
      log "$startupfile->$target"
   }
}
#
# Respond to hotkey to toggle onTop status of active window
#
proc S::setupOnTop {args} {
   if {$S::S(ontop)} {
      S::registerHotKey   
   } else {
      S::unRegisterHotKey
   }
}
#------------------------------------------------------------------------------
#  register/unregister the hotkey
#------------------------------------------------------------------------------
proc S::toggleOnTop {args} {
   set hwin [::twapi::get_foreground_window]
   if {$hwin ne ""} {
      set styles [::twapi::get_window_style $hwin]
      #e.g. overlapped minimizebox maximizebox caption visible clipsiblings clipchildren sysmenu thickframe left ltrreading rightscrollbar topmost windowedge
      # toggle here
      if {"topmost" in $styles} {
         ::twapi::set_window_zorder $hwin "bottomlayer"
         ::twapi::flash_window $hwin -period 100
         #after idle [list flashNote "Window Reset" 500]
      } else {
         ::twapi::set_window_zorder $hwin "toplayer"
         ::twapi::flash_window $hwin -period 350
         #after idle [list flashNote "Window OnTop" 500]
      }
   }
}
proc S::registerHotKey {args} {
   #http://nehe.gamedev.net/article/msdn_virtualkey_codes/15009/ w/o the VK_
   variable hotKeyId
   try {
      set hotKeyId [::twapi::register_hotkey $S::S(Hotkey) S::toggleOnTop] ;#Alt-Space
   } on error result {
      log $result
   }
}
proc S::unRegisterHotKey {args} {
   variable hotKeyId
   try {
      if {$hotKeyId ne ""} {
         ::twapi::unregister_hotkey $hotKeyId
         set hotKeyId ""
      }
   } on error result {
      log $result
   }
}


#------------------------------------------------------------------------------
#  Have the user set the tree limit
#------------------------------------------------------------------------------
proc S::getTreeLimit {string} {
   variable S   
   variable done
   variable treeLimit
   destroy .edit
   set w [toplevel .edit]
   wm resizable $w 0 0
   wm title $w ""  ;# no room for title
   
   ttk::label  $w.l -text    $string
   ttk::entry  $w.e -textvar S::S(treeLimit) -width 10  -justify center
   set old  $S(treeLimit)
   
   ttk::button $w.ok     -text "  OK  " -command {set S::done 0}
   ttk::button $w.cancel -text "Cancel" -command "set ::S::S(treeLimit) $old; set S::done 1"
   
   bind   $w.e <Return> {set S::done 1}
   bind   $w.e <Escape> "$w.cancel invoke"
   
   grid $w.l  -    -        -sticky news -padx 6 -pady 2
   grid $w.e  -    -        -sticky news -padx 6 -pady 2
   grid $w.ok  $w.cancel    -padx 8 -pady 6
   
   raise $w .
   focus $w.e
   tk::PlaceWindow $w [winfo parent $w]
   wm attributes $w -topmost
   
   vwait S::done
   if {($S(treeLimit) eq "end") || ([string is integer -strict $S(treeLimit)])} {
   } else {
      set S(treeLimit) $old
   }
   destroy $w
}

package provide settings 1.0
