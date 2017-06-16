##
# File Scanning Utilities
#
package require twapi
package require tooltip
namespace eval fileScan {
   variable useOwner 1
   variable pb
   variable count 
   variable T 
   variable matches
   variable selIcon
   variable selEnabled
   variable selIncSub
   variable ScanFolders
   variable ScanFoldersMaster
   variable LBEntries
   variable LB
}
#------------------------------------------------------------------------------
# Scan a folder recursively and add to the database
#------------------------------------------------------------------------------
proc fileScan::scanFolder {_lastIcon} {
   upvar $_lastIcon li
   variable lastIcon $li
   variable fileList [list]
   variable pb
   variable count 0
   variable matches 0
   variable cutoff
   set baseFolder [tk_chooseDirectory \
      -initialdir [twapi::get_shell_folder CSIDL_PERSONAL] \
      -title "Please select base folder to scan" \
      -parent .]

   if {[string is integer -strict $S::S(age)]} {
      set cutoff [expr {[clock seconds] - $S::S(age)*60*60*24}]
   } else {
      set cutoff 0
   }
   if {[file readable $baseFolder]} {
      set baseFolder [rdt::mapLocal $baseFolder]
      if {$baseFolder ne  ""} {
         flashNote "RDT - Adding $baseFolder to index for $lastIcon files"
         #fire off worker thread to scan and queue for database
         set Globber [iconDB::getGlobber $lastIcon]
         thread::send -async  $rdt::threadScanFolder [list scanFolders $baseFolder $cutoff $lastIcon $Globber $S::S(useAll)] 
      }
   }
}

#------------------------------------------------------------------------------
# Gui to setup file monitoring/scanning
#------------------------------------------------------------------------------
proc fileScan::Gui {args} {
   # one row with
   #  Remove Button | combo Icon | Enabled | Include Sub | Folder Name | Full Scan
   # Bottom
   #  Add Folder | Apply and Close | Cancel
   variable T .fileMon
   variable LB .fileMon.fr.lb
   variable selIcon "everything"
   variable selEnabled 0
   variable selIncSub 0
   variable scanStart 0
   variable ScanFolders
   variable ScanFoldersMaster
   variable LBEntries
   variable LB
   destroy $T
   toplevel $T
   # get entries
   array set ScanFolders [array get ScanFoldersMaster]
   set LBEntries [lsort [array names ScanFolders]]

   wm title $T "Add/Remove Folders to Monitor"
   wm protocol $T WM_DELETE_WINDOW {fileScan::Cancel}
   wm protocol $T WM_SAVE_YOURSELF {fileScan::Cancel}
   # Frame for listbox
   set fr [ttk::labelframe $T.fr -text "Folders to Monitor"]
   #tk::listbox $LB -height 10 -listvariable fileScan::LBEntries
   set LB [Scrolled_Listbox $T.fr.fr \
      -selectmode      "single"          \
      -listvariable    fileScan::LBEntries \
      -exportselection no                  \
      -activestyle     dotbox              \
      -height          6                  ]

   bind $LB  <<ListboxSelect>> [list fileScan::lbSelection %W] 
   pack $fr -expand true -fill both
   pack $fr.fr -expand true -fill both

   set Icons [lsort [S::getTrayIcons]]
   # Frame for Selection Buttons
   set fs [ttk::labelframe $T.fs -text "Folder Settings"]
   ttk::button $fs.remove -text "Remove" -command fileScan::removeFolder
   tooltip::tooltip $fs.remove "Remove the selected folder from monitoring"

   ttk::button $fs.scan -text "Scan" -command fileScan::scanSelectedFolder
   tooltip::tooltip $fs.scan "Scan the selected folder and add any user owned files to the index"
   ttk::combobox $fs.icons -values $Icons -textvariable fileScan::selIcon
   tooltip::tooltip $fs.icons "Restrict the files to be monitored to some type"
   ttk::checkbutton $fs.enabled -text "Enabled" -variable fileScan::selEnabled
   tooltip::tooltip $fs.enabled "Enable or disable the monitoring of the selected folder"
   ttk::checkbutton $fs.includSub -text "Include Subfolders" -variable fileScan::selIncSub
   tooltip::tooltip $fs.includSub "Include monitoring of subfolders for the selected folder"
   ttk::checkbutton $fs.scanStart -text "Rescan on startup" -variable fileScan::scanStart
   tooltip::tooltip $fs.includSub "Rescan the folder on startup"
   grid $fs.remove $fs.scan $fs.icons $fs.enabled $fs.includSub $fs.scanStart -sticky ew -padx 8 -pady 6
   foreach {num} {0 1 2 3 4 5} {
      grid columnconfigure $fs $num -weight 1
   }
   pack $fs -expand false -fill x

   # Frame for Commmand Buttons
   set frb [ttk::frame $T.buttons -padding 3]
   grid  \
      [ttk::button $frb.add -text "Add Folder" -command fileScan::addFolder] \
      [ttk::button $frb.apply -text "Apply" -command fileScan::Apply] \
      [ttk::button $frb.close -text "Apply & Close" -command fileScan::Close] \
      [ttk::button $frb.cancel -text "Cancel" -command fileScan::Cancel] \
      -sticky ew -padx 8 -pady 6
   pack $frb -expand false -fill x
   tooltip::tooltip $frb.add "Add a new folder to be monitored"
   tooltip::tooltip $frb.apply "Apply changes made to the selected folder"
   tooltip::tooltip $frb.close "Apply changes and close the form"
   tooltip::tooltip $frb.cancel "Cancel any changes made and close the form"
   # expand the buttons
   foreach {num} {0 1 2 3} {
      grid columnconfigure $frb $num -weight 1
   }
   fileScan::selectionSet 0
   # don't let it shrink beyound default so buttons don't get covered up
   update
   scan [wm geometry $T] "%dx%d+%d+%d" w h x y
   wm minsize $T $w $h
}


#------------------------------------------------------------------------------
#  When automatically changing position, sync the info with the selection
#------------------------------------------------------------------------------
proc fileScan::selectionSet {where} {
   variable selIcon
   variable selEnabled
   variable selIncSub
   variable ScanFolders
   variable LB
   variable LBEntries
   if {[llength $LBEntries]} {
      $LB selection clear 0 end
      $LB selection set $where
      focus $LB
      fileScan::lbSelection
   }
}
#------------------------------------------------------------------------------
# Update the listbox item on a change
#------------------------------------------------------------------------------
proc fileScan::Apply {args} {
   variable selIcon
   variable selEnabled
   variable scanStart
   variable selIncSub
   variable ScanFolders
   variable LB
   variable LBEntries
   if {[llength $LBEntries] > 0} {
      try {
         set ScanFolders([getLBFolder]) [list $selIcon $selEnabled $selIncSub $scanStart]
      } on error result {
         log $result
      }
   }
}
#------------------------------------------------------------------------------
# When listbox selection changes
#------------------------------------------------------------------------------
proc fileScan::lbSelection {args} {
   variable selIcon
   variable selEnabled
   variable selIncSub
   variable ScanFolders
   variable LB
   variable scanStart
   variable LBEntries
   focus $LB
   set val [getLBFolder]
   try {
      lassign $ScanFolders($val) selIcon selEnabled selIncSub scanStart
   } on error result {
      if {$val ne ""} {
         # new entry, set defaults
         set ScanFolders($val) [list "everything" 1 0]
      } else {
         logerr $result
      }
   }
}
#------------------------------------------------------------------------------
# Update the listbox item on a change
#------------------------------------------------------------------------------
proc fileScan::removeFolder {args} {
   variable selIcon
   variable selEnabled
   variable selIncSub
   variable ScanFolders
   variable LB
   variable LBEntries
   if {[llength $LBEntries] > 0} {
      try {
         set key [$LB curselection]
         set val [$LB get $key]
         unset -nocomplain ScanFolders($val)
         $LB delete $key
         fileScan::selectionSet end
         focus $LB
      } on error result {
         logerr $result
      }
   }
}
#------------------------------------------------------------------------------
# Add a folder to monitor
#------------------------------------------------------------------------------
proc fileScan::addFolder {args} {
   variable LB
   variable selIcon
   variable selEnabled
   variable selIncSub
   variable scanStart
   variable LBEntries
   variable ScanFolders
   set addFolder [tk_chooseDirectory \
      -initialdir [twapi::get_shell_folder CSIDL_PERSONAL] \
      -title "Please select base folder to monitor" \
      -parent .]
   if {$addFolder ne ""} {
      if {$addFolder in $LBEntries} {
         tk_messageBox -title "Duplicate entry" -type ok -icon warning -message "$addFolder\n\nDuplicate entry!"
         focus $LB
         return
      }
      lappend LBEntries $addFolder
      set selEnabled 1
      set selIncSub  0
      set scanStart  0
      set selIcon    "everything"
      fileScan::selectionSet end
   }
   focus $LB
}

#------------------------------------------------------------------------------
#  Scan the folder being monitored from scratch
#------------------------------------------------------------------------------
proc fileScan::scanSelectedFolder {args} {
   variable LB
   variable LBEntries
   variable ScanFolders
   if {[llength $LBEntries] == 0} {
      return
   }
   try {
      scanAFolder [getLBFolder]
   } on error result {
      logerr $result
   }
}
#---------------------------------------------------------------------------- 
# Fire off the thread to initiate a scan on a folder
#---------------------------------------------------------------------------- 
proc fileScan::scanAFolder {folder} {
   variable ScanFolders
   try {
      lassign $ScanFolders($folder) icon enabled usesub doscan
      if {[string is integer -strict $S::S(age)]} {
         set cutoff [expr {[clock seconds] - $S::S(age)*60*60*24}]
      } else {
         set cutoff 0
      }
      if {[file readable $folder]} {
         set baseFolder [rdt::mapLocal $folder]
         if {$baseFolder ne  ""} {
            #flashNote "RDT - Scanning $baseFolder to index for $icon files"
            #fire off worker thread to scan and queue for database
            if {$usesub} {
               set useProc scanFolders
            } else {
               set useProc scanFolder
            }
            thread::send -async  $rdt::threadScanFolder  [list $useProc $baseFolder $cutoff $icon [iconDB::getGlobber $icon] $S::S(useAll)]
         }
      }
   } on error result {
      logerr $result
   }
}
#------------------------------------------------------------------------------
#  Apply and Close
#------------------------------------------------------------------------------
proc fileScan::Close {args} {
   variable T
   variable ScanFolders
   variable ScanFoldersMaster
   variable LB
   variable LBEntries
   # Save current entry
   Apply
   # save stuff to master
   array unset ScanFoldersMaster
   array set ScanFoldersMaster [array get ScanFolders]
   fileScan::initMonitoring
   destroy $T
}
#------------------------------------------------------------------------------
#  Cancel
#------------------------------------------------------------------------------
proc fileScan::Cancel {args} {
   variable T
   variable LBEntries
   array unset ScanFolders
   array set ScanFolders [array get ScanFoldersMaster]
   # don't save stuff
   destroy $T
}

#------------------------------------------------------------------------------
# Get the folder for the selection
#------------------------------------------------------------------------------
proc fileScan::getLBFolder {args} {
   variable LB
   set key [$LB curselection]
   set val [$LB get $key]
   return $val
}
#------------------------------------------------------------------------------
#  Initialize monitoring on startup
#------------------------------------------------------------------------------
proc fileScan::initMonitoring {args} {
   variable ScanFoldersMaster
   variable ScanFolders
   variable LBEntries
   # startup new monitors
   set monSets [list]
   array set ScanFolders [array get ScanFoldersMaster]
   foreach {folder} [array names ScanFoldersMaster] {
      lassign $ScanFoldersMaster($folder) icon enabled usesub doscan
      # add to monitoring
      if {$enabled} {
         set Globber [iconDB::getGlobList $icon]
         lappend monSets [list $folder $icon $usesub $Globber]
      }
      # fire off a folder to scan
      if {$doscan && [rdt::onACPower]} {
         scanAFolder $folder
      }
   }
   # send them all at once and don't block
   if {[llength $monSets] > 0} {
      thread::send -async $rdt::threadHash [list fm::setupMonitoring $monSets]
   }
}
package provide fileScan 1.0
