#----------------------------------------------------------------------------
# Recent Document Track program
# Tracks the shortcut files that windows creates for recent document
# access and puts this in a database. The user is then presented with
# organized menus and searching functions to launch the shortcuts
# inspired by jumplists in windows 7
#
# (c) 2010-2017 Tom Wilkason
# GNU 2.0 Licence, enjoy for your unlimted use but please cite my work
#----------------------------------------------------------------------------
#console show
set VERSION 1.36
console title "Recent Document Tracker"
wm withdraw .
set DEBUG 0
set HOME [file dirname [info script]]
lappend ::auto_path [file join $HOME lib]
package require pkgFunctions
# Overload load to use real or virtual folder for dll's
pkgFunctions::overLoadLoad
# load the packages now
package require Tk
package require dde
# Kill the prior instance then restart
# in case the icons disappeared
if {[llength [dde services TclEval rdt]] > 0} {
   #exit
   try {
      dde execute TclEval rdt {rdt::unload}
   } on error result {
      # will expect a "remote interpreter did not respond"
      # since the other app shutdown
      puts $result                                       
   }
   # wait to unload
   after 1000
   dde servername rdt
} else {
   dde servername rdt
}
package require miscTools
package require rdtMetakit
package require settings
package require WinTaskBar
package require TreeSearch
package require shellIcon
package require ico  ;# used to extract images from icons for menus, can twapi do this as well?
# a couple commands are different
package require twapi
package require fileScan
# clean exit handlers

wm protocol . WM_DELETE_WINDOW {rdt::unload}
wm protocol . WM_SAVE_YOURSELF {rdt::unload}
ttk::style configure Treeview -background "ghost white"


# initialize the common file stat hash
#------------------------------------------------------------------------------
#  error message
#------------------------------------------------------------------------------
proc debug {str} {
   if {$::DEBUG} {
      set who [lindex [split [info level [expr [info level] - 1]]] 0]
      if {$who eq [lindex [info level 0] 0]} {
         puts stderr "[clock format [clock seconds] -format {%D %T}] debug: '$who' $str"
      } else {
         puts stderr "[clock format [clock seconds] -format {%D %T}] debug: $str"
      }
   }
}
#------------------------------------------------------------------------------
# Main RDT namespace
#------------------------------------------------------------------------------
namespace eval rdt {
   package require Thread
   variable folders          [list]
   variable folderID         [list]
   variable settingsDir      ""
   variable hashFile     ""
   variable iconCache        ""
   variable shareMapping     [list]
   variable threadFull
   variable threadHash
   variable threadMenu
   variable threadVol
   variable threadScanFolder
   variable extIcons
   variable Volumes
   variable ACStatus         1
   variable ageCutoff        3
   variable lastEvent   [clock seconds]


   #home thread and set bgerror proc
   tsv::set rdt H [thread::id] ;# Home Thread
   tsv::set rdt auto_path $::auto_path

   # pass starkit information to a thread if it needs it
   if {[info exists ::starkit::topdir]} {
      tsv::set rdt topdir $::starkit::topdir
   } else {
      tsv::set rdt topdir ""
   }
   # redirect thred bgerrors back to main thread
   thread::errorproc ::logTerr

   # Folders to monitor for shortcuts, should work on all systems
   lappend folders [file join $env(APPDATA) Microsoft/Office/Recent]         ;# 90% redundant
   lappend folders [file normalize [twapi::get_shell_folder csidl_recent]]   ;# windows/Recent

   # settings file(s) location
   if {[file exists [file join $env(USERPROFILE) ".rdt"]]} {
      variable settingsDir [file join $env(USERPROFILE) ".rdt"]
   } else {
      # migrate to appdata -> CSIDL_APPDATA
      variable settingsDir [file join $env(LOCALAPPDATA) "RDT"]
   }
   S::setHome $settingsDir
   set iconCache [file join $settingsDir "IconCache.bin"]
}
#------------------------------------------------------------------------------
# Retrieve the value of the hide extensions
#------------------------------------------------------------------------------
proc rdt::getExtSetting {args} {
   package require registry
   if {[catch {registry get "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced" "HideFileExt"} value]} {
      logerr $value
      return 1
   } else {
      return $value
   }
}

#----------------------------------------------------------------------------
# Get the default program for a file extension
#----------------------------------------------------------------------------
# proc rdt::getFileProgram {file} {
#    package require registry
#    set ext [string tolower [file extension $file]]
#    return [rdt::getExtProgram $ext]
# }
# proc rdt::getExtProgram {ext} {
#    package require registry
#    # find extention and name for extension
#    if {[catch {registry get "HKEY_CLASSES_ROOT\\$ext" ""} value]} {
#       logerr "$file: $value"
#       return ""
#    } else {
#       # lookup shell program for extenion name in the usual places
#       if {[catch {registry get "HKEY_CLASSES_ROOT\\$value\\shell\\open\\command" ""} prog]} {
#          if {[catch {registry get "HKEY_CLASSES_ROOT\\$value\\shell\\edit\\command" ""} prog]} {
#             logerr "$file: $prog"
#             return ""
#          } else {
#             return [string map {\\ /} $prog]
#          }
#       } else {
#          return [string map {\\ /} $prog]
#       }
#    }
# }

#----------------------------------------------------------------------------
# Limit ages in database
#----------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Remove old entries in the database
# also remove old shortcuts
# Called from settings menus
#------------------------------------------------------------------------------
proc rdt::purgeOldShortCuts {args} {
   variable folders
   if {[string is integer -strict $S::S(age)]} {
      set daysAgo [expr {[clock seconds] - $S::S(age)*60*60*24}]
      foreach {folder} $folders {
         try {
            if {[file isdirectory $folder]} {
               set files [glob -directory $folder -nocomplain "*.lnk"]
               foreach {file} $files {
                  set stime [file mtime $file]
                  if {$stime < $daysAgo} {
                     log "Removed old shortcut [clock format $stime] $file "
                     file delete -force $file
                  }
               }
            }
         } on error result {
            logerr $result
         }
      }
      set removed [db::purgeOldShortCut $daysAgo]
      if {$removed > 0} {
         log "Removed $removed database entries"
      }
   }
   # clear out duplicate/misnamed entries in the database (due to case)
   set cleaned [db::clearDups *]
   if {$cleaned > 0} {
      log "Corrected $cleaned database issues"
   }

   after cancel rdt::purgeOldShortCuts
   # once a day schedule check
   after [expr {24*60*60*1000}] rdt::purgeOldShortCuts
}
#----------------------------------------------------------------------------
# Launch the shortcut, callback from menu
#----------------------------------------------------------------------------
proc rdt::launch {name} {
   set ok 0
   set hnds [list]
   catch {treeSearch::cursor watch}
   update
   if {[file exists $name]} {
      set hcnt 0
      set name [file nativename $name]
      # Folders need full path, otherwise only name will suffice
      if {[db::getVal $name "IsOpen"]==1} {
         if {! [file isdirectory $name]} {
            set tomatch "*[file tail $name]*"
         } else {
            set tomatch "*$name*"
         }
         set hnds [twapi::find_windows -text $tomatch -match glob -toplevel 1 -visible 1 -caption 1]
         set hcnt [llength $hnds]
      }
      # If file already open, just bring up the active window, assuming
      # we can find it called out in a window title like office does
      if {$hcnt} {
         set hnd [lindex $hnds 0]
         if {$hcnt > 1} {
            # if multiple windows open with this name, ignore certain ones
            foreach {h} $hnds {
               set txt [twapi::get_window_text $h]
               # Office may also have a VBA window open for macro enabled worksheets, ignore it
               switch -glob -- $txt {
                  "*Visual Basic*" {continue}
                  default {set hnd $h}
               }
            }
         }
         # have a handle, restore it and bring to the front vs. launching it
         try {
            if {[twapi::window_minimized $hnd]} {
               twapi::restore_window $hnd -activate
            }
            twapi::show_window $hnd -activate 
            twapi::set_foreground_window $hnd
         } on error result {
            logerr $result
         }
      } else {
         try {
            # how to launch specific app on a file to override defaults
            # set app {C:\Program Files (x86)\Microsoft Office\OFFICE11\WINWORD.EXE}
            # set doc {C:\Users\Tom\Documents\GT Essay.E.doc}
            # shell_execute -path $app -params \"$doc\" ;#"
   
            # launch default
            twapi::shell_execute -logusage 1 -path $name  -asyncok true
         } on error result {
            logerr $result
         }
      }
      set ok 1
   } else {
      catch {treeSearch::cursor ""}
      #force a mount check here in case we lost a lot of them due to network going down or unplugged
      rdt::checkMounts
      rdt::forceCheckMenu
      if {[tk_messageBox -type yesno -icon question -message "$name no longer exists\nRemove the entry?"] eq "yes"} {
         db::removeFile $name
      }
   }
   catch {treeSearch::cursor ""}
   return $ok
}
#----------------------------------------------------------------------------
# Register the folder monitors for changes in recent files
#----------------------------------------------------------------------------
proc rdt::registerMonitors {args} {
   variable folders
   variable folderID
   variable threadHash
   thread::send -async $threadHash [list sc::setupMonitoring $folders]
}
#------------------------------------------------------------------------------
# Map a URL file to a local drive if possible
#------------------------------------------------------------------------------
proc rdt::mapLocal {dest} {
   variable shareMapping
   if {[llength $shareMapping]} {
      set dest [string map -nocase $shareMapping $dest]
   }
   return $dest
}

#----------------------------------------------------------------------------
# Create an array of mounted/unmounted drives
#
# twapi::get_client_shares -> {\\Mediaserver\e} {\\MEDIASERVER\Bittorrent}
# need to add client shares to handle files accessed via that method or
#----------------------------------------------------------------------------
proc rdt::checkMounts {{flash 0}} {
   variable threadVol
   # saveVols is a total list of volumes found
   thread::send -async $threadVol [list cbCheckMounts $S::S(saveVols)]
   if {$flash} {
      flashNote "RDT - Refreshing Drive Mount Status"
   }

}
#----------------------------------------------------------------------------
# Reset all the mounted status
# This is pretty darn fast since only differences are changed
#----------------------------------------------------------------------------
proc rdt::FlagMountedStatus {args} {
   variable Volumes
   foreach {vol status} [array get Volumes] {
      set done [db::flagMounted $vol $status]
      if {$done > 0} {
         if {$status} {
            log "Volume $vol now online - $done files effected"
         } else {
            log "Volume $vol now offline - $done files effected"
         }
      }
   }
}
#----------------------------------------------------------------------------
# Clear out unmounted files from database
# Use background task to do it
#----------------------------------------------------------------------------
proc rdt::clearMissing {args} {
   variable Volumes
   variable threadVol
   variable shareMapping
   # check mounts, but wait for it to finish
   thread::send -async $threadVol [list cbCheckMounts $S::S(saveVols)]
   # shareMapping will be updated in this thread by (rdt::cbSetVolumes)
   vwait ::rdt::shareMapping

   # return mounted files that may be missing
   set files [db::missingList * ""]
   set toClean [llength $files]
   # Note: This will be based on last background scan, which could be 4 hours ago
   if {$toClean > 0 && [tk_messageBox -title "Please Confirm"  -type yesno -icon question \
      -message "Are you sure you want to remove stale database entries?\n\nTotal of $toClean entries to remove"] eq "yes"} {
      flashNote "RDT - Removing [llength $toClean] Stale Entries"
      foreach {name} $files {
         db::removeFile $name
      }
   }
}
#------------------------------------------------------------------------------
# Dump a list of names
#------------------------------------------------------------------------------
proc rdt::dumpNames {image} {
   foreach {item} [db::menuList $image 0 0 25] {
      puts $item
   }
}
#----------------------------------------------------------------------------
# Initial scan of the folders to populate hash
#----------------------------------------------------------------------------
proc rdt::initialScan {args} {
   variable folders
   variable folderID
   variable threadHash
   thread::send -async $threadHash [list sc::initialScan $folders]
   #todo save schash at some point after scan complete
}

#----------------------------------------------------------------------------
# Restore the saved links from a prior session to help speed up launching
#----------------------------------------------------------------------------
proc rdt::restoreHash {args} {
   variable settingsDir
   variable threadHash
   variable hashFile [file join $settingsDir "rdt.txt"]
   thread::send $threadHash [list sc::restoreHash $hashFile]
}


#------------------------------------------------------------------------------
#  Save the shortcut hash file for next time
#------------------------------------------------------------------------------
proc rdt::saveHash {args} {
   variable hashFile
   variable threadHash
   thread::send $threadHash [list sc::saveHash $hashFile]
}
#------------------------------------------------------------------------------
#  exit the program
#------------------------------------------------------------------------------
proc rdt::unload {args} {
   variable folders
   variable folderID
   variable settingsDir
   variable iconCache
   variable threadHash
   #Stop moniotring
   thread::send $threadHash sc::stopMonitoring
   thread::send $threadHash fm::stopMonitoring
   winTaskBar::RemoveIcons
   # save the hash file
   catch {
      rdt::saveHash
      db::closeDB
      # Save User Settings
      S::saveSettings
      # save icon images
      iconDB::saveDB $iconCache
      rdt::powerMonitorStop
      S::unRegisterHotKey
   }
   #release threads (that aren't me)
   foreach {T} [thread::names] {
      if {$T ne [thread::id]} {
         thread::release $T
      }
   }
   after 100 exit
}
#------------------------------------------------------------------------------
#  Remove then rescan everything
#------------------------------------------------------------------------------
proc rdt::restart {args} {
   variable threadHash
   variable folders
   if {[tk_messageBox -title "Please Confirm"  -type yesno -icon question -message "Are you want sure you want to rescan all Recent File shortcuts?\nthis will reset the database first."] eq "yes"} {
      flashNote "Resetting Database and reindexing"
      set S::S(saveVols) [list]
      db::purgeDB
      thread::send $threadHash [list sc::clearSCHASH]
      thread::send -async $threadHash [list sc::initialScan $folders]
      #todo: whey clear after a scan??
      # clear out and rebuild all the icons
      iconDB::clearIconData   
      iconDB::loadPngFiles [list $::HOME]
      iconDB::cacheIcons
   }

}
#----------------------------------------------------------------------------
# Clear the shortcut hash (currently used)
#----------------------------------------------------------------------------
proc rdt::resetHash {args} {
   variable threadHash
   thread::send $threadHash [list sc::clearSCHASH]
}
#------------------------------------------------------------------------------
#  Initializion Routines
#------------------------------------------------------------------------------
proc rdt::RestoreIcons {args} {
   variable hideExt
   variable iconCache
   # restore the png images used for all the file icons
   if {$S::S(resetIconCache)} {
      # skip reading the cache, it will rebuild automatically
      set S::S(resetIconCache) 0
      log "Rebuilding icon cache"
   } else {
      iconDB::restoreDB $iconCache
   }
   # if user wants extension shown
   set hideExt [getExtSetting]
}

#------------------------------------------------------------------------------
#  Determine if computer is plugged in
# if settings clear then always return 1
#------------------------------------------------------------------------------
proc rdt::onACPower {args} {
   variable ACStatus
   if {$S::S(limitOnBattery)} {
      array set powerstat [twapi::get_power_status]
      if {$powerstat(-acstatus) eq "on"} {
         set ACStatus 1
      } else {
         set ACStatus 0
      }
   } else {
      set ACStatus 1
   }
   return $ACStatus
}

#------------------------------------------------------------------------------
# 
# Called when power monitor changes
# 
#------------------------------------------------------------------------------
proc rdt::powerMonitor {args} {
   variable powerHandle
   variable lastEvent
   set now [clock seconds]
   # don't process duplicate events
   if {abs($lastEvent-$now) <=1} { 
      return
   }
   set lastEvent $now
   #http://twapi.magicsplat.com/power.html
   array set lu {on AC off Battery}
   lassign $args powerType powerValue
   switch -- $powerType {
      "apmpowerstatuschange" {
         array set powerstat [twapi::get_power_status]
         set pmode $powerstat(-acstatus)
         log "Power Status Change, now on $lu($pmode) power"
         rdt::onACPower
      }
      "apmsuspend" {
         # Cancel any afters and clear any queues
         rdt::cancelLoops
         log "Sleepy Time!"

      }
      "apmresumesuspend" {
         # works, resume all bgchecks here and unmount if necessary
         log "Awake from Sleep"
         rdt::onACPower
         after idle rdt::fireLoops
      }
      "apmresumeautomatic" {
         # not sure if bug, but gets called with regular resume
         log "Awake from Sleep" 
         rdt::onACPower
         after idle rdt::fireLoops
      }
      "apmresumecritical" {
         log "Awake from Sleep (critical)" 
         rdt::onACPower
         after idle rdt::fireLoops
      }
      default {
         log "$powerType=$powerValue"
      }
   }
}

#------------------------------------------------------------------------------
# Stop the power monitoring of power
#------------------------------------------------------------------------------
proc rdt::powerMonitorStop {args} {
   variable powerHandle
   catch {
      twapi::stop_power_monitor $powerHandle
   }
}
#------------------------------------------------------------------------------
#  On time fire loops or after resume
#------------------------------------------------------------------------------
proc rdt::cancelLoops {args} {
   after cancel rdt::bgCheckFile
   after cancel rdt::bgCheckMenu
   after cancel rdt::purgeOldShortCuts
   tsv::set rdt fgHashOutQueue [list]
   tsv::set rdt bgHashOutQueue [list]
   tsv::set rdt toCheckFull    [list]
   tsv::set rdt toCheckMenu    [list]
   tsv::set rdt bgScanOutQueue [list]
}
#------------------------------------------------------------------------------
# Run from an after loop so checkMounts doesn't block
#------------------------------------------------------------------------------
proc rdt::fireLoops {args} {
   rdt::cancelLoops
   # checkMounts includes a vwait so blocks but doesn't stop menu ops   
   rdt::checkMounts 

   #30 sec to check the full file list
   after 30000 rdt::bgCheckFile
   #3 sec to check the menu, then 10 min thereafter
   after 3000 rdt::bgCheckMenu
   # look to remove old shortcuts
   after 60000 rdt::purgeOldShortCuts
}
#------------------------------------------------------------------------------
#  Dump the values of the buffers out
#------------------------------------------------------------------------------
proc showBuffers {args} {
   log "Database files to be queued = [tsv::llength rdt toCheckFull]"
   log "Menu Files to be queued = [tsv::llength rdt toCheckMenu]"
   log "Database/Menu files being checked = [tsv::llength rdt bgHashOutQueue]"
   log "User Files being scanned = [tsv::llength rdt bgScanOutQueue]"
   #maybe make a simple gui?
}
#------------------------------------------------------------------------------
#  About
#------------------------------------------------------------------------------
proc rdt::About {args} {
   global VERSION
   tk_messageBox -type ok -icon info \
-message "Recent Document Tracker (RDT) $VERSION, twapi [twapi::get_version] / Tcl $::tcl_patchLevel 
Groups recent documents by type for easy access

[db::numTracks 1] Total Indexed
[db::numTracks 0] Active Files
[db::numTracks 2] Existing but Unmounted
[db::numTracks 4] Missing and Unmounted
[db::numTracks 3] Missing or Deleted
[expr {[tsv::llength rdt toCheckFull]+[tsv::llength rdt toCheckMenu]}] Queued for check
[tsv::llength rdt bgHashOutQueue] Being Checked
[tsv::llength rdt bgScanOutQueue] User Files being added

Copyright Tom Wilkason (c) 2017"

}
package require threadProcs

#----------------------------------------------------------------------------
# Initialization code here
#----------------------------------------------------------------------------
log "RDT Initializing"
#createMenuFont
# create the threads
rdt::makeThread
# Create the threads and do initial scan
# background clean out dead files
rdt::fireLoops
# Restore prior hash an get drive mappings
rdt::restoreHash
###rdt::comVariable
# open the database
db::openDB
# read settings file
S::readSettings
# bind the hotkey if necessary
S::setupOnTop
# Restore Icon images
rdt::RestoreIcons
# get default icons for menus (overload cache)
iconDB::loadPngFiles [list $::HOME]
# Initialize the taskbar icons
# Create thread queues
# fire up the background scanning threads
rdt::loopHashes
# Perform initial scan, show progress bar
# Skip rescan if on battery or doing initial scan
#console show
# monitor power
twapi::start_power_monitor rdt::powerMonitor

# Plugged in or none to a few indexed entries
if {[rdt::onACPower] || [db::numTracks 1]<5} {
   rdt::initialScan
} else {
   log "On Battery Power, Using prior database"
}
# Event based recent file monitors
rdt::registerMonitors
# monitor power
# Initialize the sendto menu addons
winTaskBar::initSendTo
# this shouldn't cache any since they are restored now
iconDB::cacheIcons
# Initialize the taskbar icons
winTaskBar::initTray
# User folder monitoring (if any)
fileScan::initMonitoring
# flush the database after we settle
log "RDT Ready"




