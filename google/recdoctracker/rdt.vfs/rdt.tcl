#----------------------------------------------------------------------------
# Recent Document Track program
# Tracks the shortcut files that windows creates for recent document
# access and puts this in a database. The user is then presented with
# organized menus and searching functions to launch the shortcuts
# inspired by jumplists in windows 7
#
# (c) 2010 Tom Wilkason
# GUN 2.0 Licence, enjoy for your unlimted use but please cite my work
#----------------------------------------------------------------------------
#package require tooltip
wm withdraw .
set VERSION 0.8.4
set HOME [file dirname [info script]]
lappend ::auto_path [file join $HOME lib]
package require pkgFunctions
pkgFunctions::overLoadLoad
# load the packages now
package require Tk
package require dde
# Only allow one instance
if {[llength [dde services TclEval rdt]] > 0} {
   exit
} else {
   dde servername rdt
}

package require rdtMetakit
package require settings
package require WinTaskBar
package require TreeSearch
package require shellIcon
package require ico
# a couple commands are different
package require twapi

set notes {
enhance
   - first time install, dialog allow user to set settings
   - Setting dialog to allow user to change the icon associations, check if icon is shown
     and display the icon. ico::writeIcon can create icons
     -- change what extensions go for some icon
     -- change what file command is used to open that file extension (sub dialog)
     -- winTaskBar::init process would read this rather than the file directory
   - Don't enable all types on initial run, put up a dialog with check boxes linked
     to each type to allow the user to enable/disable each.
   - option to put in different program to launch folders with (now that we build the shortcut)
     Really helpful with office 2003/2007 installed (still may not work if app is running)
     executable can be put into the link when it is created, maybe a config file that
     associates a file extension with an executable.

   - If lots or old shortcuts are found then prompt user to delete them or set a limit
   - Would still like a tool that indexes all folder names then can filter on them using this tool
     then easily jump to one of them. Will have 1000's of entries
   - Track urls as well as files, slightly different TWAPI shortcut and monitor handling
   - Mounted flag is currently kept a 1, not used

   - Add new button for start menu
      - Add following folders to it, build dynamically reading shortcut icons
      - Support RMB for searching as well, use existing search box
      csidl_common_favorites
      csidl_common_startmenu
      csidl_favorites
      csidl_startmenu
      Can use existing logic with changes for
      - exe ext should always query lnk icon
      - will need to scan start menu folders deeply, not at first level
      - Start menus will still have to be built dynamically

expand (twapi)
   - global hot keys
   - sleep/suspend/lock/shutdown
   - move_window / resize_window  may work better than geom
   - get_input_idle_time to determine if we should hold off on rescanning
     (last time since mouse or keyboard input)
bugs

cleanup
   - would dicts make more sense than the hash arrays?
     they can also handle structured data better using nesting.
   - clean up call back order on menus, too complex, too nested
   - png needed for each icon type to enable/disable, can we extract menu png from ico file?
     I know, just rerverse look it up in the IconTypes, use the first one found
   - rdt::purgeOld should also remove files from .rdt/rdtRecent Places as well as original source location
    in fact probably should only have last 30 days there
database / hash in use
   ext is file extension as well as special icons such as pinned and folder
   - winTaskBar::extToImage(ext) -> imagexx  (xls->image90)                ->Image in db
   - winTaskBar::extToType(ext)  -> IconType (xls->excel , folder->folder) ->IconType in db

   IconType is used in database for glob filtering
   - winTaskBar::typeToIco(IconType) -> ico#x (excel->ico#9)
   - winTaskBar::tbIconState(IconType) -> 1/0 (excel->1), seems same as S::S
   - S::S(icon,IconType) -> 1/0 (icon,excel->1)

   - winTaskBar::iconDef(ico#x) -> "Recent 'type' files\nLeft Button...."
}
# clean exit handlers
wm protocol . WM_DELETE_WINDOW {rdt::unload}
wm protocol . WM_SAVE_YOURSELF {rdt::unload}

#------------------------------------------------------------------------------
#  tk error handler
#------------------------------------------------------------------------------
proc ::tkerror {args} {
   debug $args
   debug $::errorInfo
}
#------------------------------------------------------------------------------
#  error message
#------------------------------------------------------------------------------
proc debug {str} {
   console show
   puts stderr "[clock format [clock seconds] -format %T] $str"
}

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
proc log {str} {
   puts stdout "[clock format [clock seconds] -format %T] $str"
}
proc logerr {str} {
   puts stderr "[clock format [clock seconds] -format %T] $str"
}

#------------------------------------------------------------------------------
# return the file extension
#------------------------------------------------------------------------------
proc fileExt {name} {
   return [string tolower [string trimleft [file extension $name] "."]]
}

#------------------------------------------------------------------------------
# Callback for the file monitor
#------------------------------------------------------------------------------
namespace eval rdt {
   variable folders [list]
   variable folderID [list]
   variable settingsDir ""
   variable settingsFile ""
   variable shareMapping
   variable T
   variable missing [list]
   variable once 0
   variable paramNum
   variable extIcons

   # param offset for monitor callback changes with version
   if {[twapi::get_version] >= 3.0} {
      set paramNum 2
   } else {
      set paramNum 1
   }
   trace variable ::rdt::missing w [list rdt::purge]

   # Folders to monitor, should work on all systems
   # set recent [file normalize [twapi::get_shell_folder csidl_recent]] will get windows recent
   lappend folders [file join $env(APPDATA) Microsoft/Office/Recent]
   #lappend folders [file join $env(APPDATA) Microsoft/Windows/Recent]
   #lappend folders [file join $env(USERPROFILE) Recent]
   lappend folders [file normalize [twapi::get_shell_folder csidl_recent]]

   #lappend folders [file normalize [twapi::get_shell_folder csidl_favorites]]
   #lappend folders [file normalize [twapi::get_shell_folder csidl_common_favorites]]
   #lappend folders [file normalize [twapi::get_shell_folder csidl_startmenu]]
   #lappend folders [file normalize [twapi::get_shell_folder csidl_common_startmenu]]

   #   csidl_common_favorites
   #   csidl_common_startmenu
   #   csidl_favorites
   #   csidl_startmenu


   variable settingsDir [file join $env(USERPROFILE) .rdt]
   variable myRecentFiles [file join $settingsDir "rdtRecent Files"]
   variable myRecentPlaces [file join $settingsDir "rdtRecent Places"]
   S::setHome $settingsDir
   set S::S(deleteDead) 1
   set S::S(deleteStale) 0
   set S::S(bgCheckFile) 0
   set S::S(limit) 25
   set S::S(age) "never"

   variable scReuseName [file join $settingsDir launch.lnk]
}
#------------------------------------------------------------------------------
# Retrieve the value of the hide extensions
#------------------------------------------------------------------------------
proc rdt::writeStartup {args} {
   variable startmenu
}
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
proc rdt::getExtProgram {file} {
   package require registry
   set ext [string tolower [file extension $file]]
   # find extention and name for extension
   if {[catch {registry get "HKEY_CLASSES_ROOT\\$ext" ""} value]} {
      logerr "$file: $value"
      return ""
   } else {
      # lookup shell program for extenion name in the usual places
      if {[catch {registry get "HKEY_CLASSES_ROOT\\$value\\shell\\open\\command" ""} prog]} {
         if {[catch {registry get "HKEY_CLASSES_ROOT\\$value\\shell\\edit\\command" ""} prog]} {
            logerr "$file: $prog"
            return ""
         } else {
            return [string map {\\ /} $prog]
         }
      } else {
         return [string map {\\ /} $prog]
      }
   }
}

#------------------------------------------------------------------------------
# test program
#------------------------------------------------------------------------------
proc testExt {pat} {
   foreach {entry} [db::fileList $pat 0] {
      lassign $entry name sdate mdate mounted hits
      puts "[rdt::getExtProgram $name]->$name"
   }
}
#----------------------------------------------------------------------------
# Create a network share mapping to convert network files to local files if possible
#----------------------------------------------------------------------------
proc rdt::getMapping {args} {
   variable shareMapping
   set shareMapping [list]
   # {\\wro-nt\office} K: {\\wro-nt.wrb.us.ray.com\projects} P: {\\CASEY\IPC$} {} {\\es-eng-esnfile\flics} L:
   foreach {share} [twapi::get_client_shares] {
      lassign $share local network
      lappend shareMapping $network $local
   }
   after cancel rdt::getMapping
   after 20000 rdt::getMapping
}
#------------------------------------------------------------------------------
#  About
#------------------------------------------------------------------------------
proc rdt::About {args} {
   global VERSION
   tk_messageBox -type ok -icon info \
       -message "Recent Document Tracker (RDT) $VERSION, twapi [twapi::get_version] \nGroups recent documents by type for easy access\n\nCopyright Tom Wilkason (c) 2010"

}
#----------------------------------------------------------------------------
# Limit ages in database
#----------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Remove old entries in the database
# also remove old shortcuts
#------------------------------------------------------------------------------
proc rdt::purgeOld {args} {
   variable folders
   if {[string is integer -strict $S::S(age)]} {
      set daysAgo [expr {[clock seconds] - $S::S(age)*60*60*24}]
      foreach {folder} $folders {
         try {
            if {[file readable $folder]} {
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
      set removed [db::purgeOld $daysAgo]
      if {$removed > 0} {
         log "Removed $removed database entries"
      }
   }
   after cancel rdt::purgeOld
   # once a day schedule
   after [expr {1000*60*60*24}] rdt::purgeOld
}
#----------------------------------------------------------------------------
# Launch the shortcut, callback from menu
#----------------------------------------------------------------------------
proc rdt::launch {name} {
   variable scReuseName
   set ok 0
   if {[file exists $name]} {
      set name [file nativename $name]
      try {
         # how to launch specific app on a file to override defaults
         # set app {C:\Program Files (x86)\Microsoft Office\OFFICE11\WINWORD.EXE}
         # set doc {C:\Users\Tom\Documents\GT Essay.E.doc}
         # shell_execute -path $app -params \"$doc\" ;#"

         # launch default
         twapi::shell_execute -path $name
         set ok 1
      } on error result {
         logerr $result
      }
   } else {
      if {[tk_messageBox -type yesno -icon question -message "$name no longer exists\nRemove the entry?"] == "yes"} {
         db::removeFile $name
      }
   }
   return $ok
}
#----------------------------------------------------------------------------
# Register the folder monitors for changes in recent files
#----------------------------------------------------------------------------
proc rdt::registerMonitors {args} {
   variable folders
   variable folderID
   foreach {folder} $folders {
      if {[file isdirectory $folder] && [file readable $folder]} {
         try {
            log "installing folder monitor for $folder"
            lappend folderID [twapi::begin_filesystem_monitor $folder [list rdt::monitorCallback $folder] -patterns "*.lnk"]
         } on error result {
            logerr $result
         }
      }
   }
}
#----------------------------------------------------------------------------
# callback when a file is added, update the menu hash
# On a change, first a removed is called then an added is called
#----------------------------------------------------------------------------
proc rdt::monitorCallback {args} {
   global SCHASH
   variable paramNum
   set folder [lindex $args 0]
   set method [lindex $args $paramNum 0]
   set file [lindex $args $paramNum 1]
   set shortcut [file join $folder $file]
   #debug "$args, folder=$folder, method=$method, file=$file, sc=$shortcut"
   switch -- $method {
      "added" {
         try {
            ;# wait a bit for the shortcut to be created by the OS
            after cancel [list rdt::hashShortcut $shortcut]
            after 500 [list rdt::hashShortcut $shortcut]

         } on error result {
            logerr $result
         }
         #debug "Adding shortcut $shortcut"
         # save the datbase in the near future
         after cancel rdt::saveHash
         after 10000 rdt::saveHash
      }
      "modified" {
      }
      "removed" {
         # note, the original file and shortcut is still in the database
         array unset SCHASH "*|$shortcut"
         #puts "Cleaned deleted shortcut $shortcut"
      }
      default {
         log "$method monitorCallback $shortcut"
      }
   }
}
#------------------------------------------------------------------------------
#  Save the shortcut in the hash
#------------------------------------------------------------------------------
proc rdt::hashShortcut {shortcut} {
   # this will cause a file search if it doesn't exist
   variable shareMapping
   variable myRecentFiles
   variable myRecentPlaces
   # SCHASH holds a list of recent shortcuts, obviates need to keep checking
   # the link destination when the link gets scanned on startup
   global SCHASH
   # ignore url links (for now)
   if {[file exists $shortcut] && [string equal -nocase ".lnk" [file extension $shortcut]]} {
      try {
         set stime [file mtime $shortcut]
         set sckey "$stime|$shortcut"
         # if already hashed, then assume the destination file is good
         if {![info exists SCHASH($sckey)]} {
            ;# this command can take a while on network links
            array set scArray [twapi::read_shortcut $shortcut -nosearch -noui -nolinkinfo -timeout 500] ;# keyed list
            set dest $scArray(-path)
            # if path doesn't exist then remove the shortcut
            if {![file exists $dest]} {
               if {$S::S(deleteDead)} {
                  file delete -force $shortcut
                  log "removing $shortcut since $dest no longer exists"
               } else {
                  log "skipping $shortcut since $dest no longer exists"
               }
            } else {
               # convert to local (vs unc) mapping if possible
               if {[llength $shareMapping]} {
                  set dest [string map $shareMapping $dest]
               }
               set isDir [file isdirectory $dest]
               # get type
               set type [winTaskBar::getAnType $dest $isDir]
               # hash file, type and icon
               db::cacheFile $dest $stime $type
               # cache the path as well if needed
               if {$S::S(hashFolder) && !$isDir} {
                  set path [file nativename [file dirname $dest]]
                  # cache the parent folder
                  set img [winTaskBar::getAnIcon $path 1]
                  db::cacheFile $path $stime "folder"
               }
               set SCHASH($sckey) 1
               # copy shortcut to myRecent folder as well (if not excluded already)
               if {$S::S(myRecent)} {
                  set excluded [db::getVal $dest "Excluded"]
                  if {$excluded ne "1"} {
                     if {$isDir} {
                        file copy -force $shortcut [file join $myRecentPlaces [file tail $shortcut]]
                     } else {
                        file copy -force $shortcut [file join $myRecentFiles [file tail $shortcut]]
                     }
                     #puts "adding $dest"
                  } else {
                     #puts "skipping $dest"
                  }
               }
            }
         } else {
            # exists, flag as good
            set SCHASH($sckey) 1
         }

      } on error result {
         logerr "hashShortcut $result -> $shortcut\n$::errorInfo"
      }
   }
   update idletasks
}
#----------------------------------------------------------------------------
# Initial scan of the folders to populate hash
#----------------------------------------------------------------------------
proc rdt::initialScan {args} {
   global SCHASH
   variable folders
   variable folderID
   set patterns [list]
   set files [list]
   toplevel .scan
   set pb .scan.scan
   wm attributes .scan -toolwindow 1
   wm title  .scan "RDT Scanning Shortcuts..."
   pack [ttk::progressbar $pb -mode determinate -length 600] -expand true -fill both
   #
   # Initialize SCHASH values to 0 then scan (reverify)
   #
   foreach {key} [array names SCHASH] {
      set SCHASH($key) 0
   }
   foreach {folder} $folders {
      try {
         if {[file readable $folder]} {
            log "Scanning Shortcut Folder $folder"
            set files [glob -directory $folder -nocomplain "*.lnk"]
            set total [llength $files]
            wm title  .scan "RDT Scanning $folder"
            $pb configure -maximum $total
            set count 0
            foreach {link} $files {
               hashShortcut $link
               $pb configure -value [incr count]
               update
            } ;#end foreach file
         } else {
            logerr "Unreadable folder $folder (may be a system hardlink folder)"
         }
      } on error result {
         logerr $result
      }
   } ;# end foreach folder
   #
   # clear out old SCHASH values (ones not hashed)
   #
   foreach {key} [array names SCHASH] {
      if {$SCHASH($key) == 0} {
         unset SCHASH($key)
         #puts "removed $key"
      }
   }
   destroy .scan
   saveHash
}

#----------------------------------------------------------------------------
# Restore the saved links from a prior session to help speed up launching
#----------------------------------------------------------------------------
proc rdt::restoreHash {args} {
   global env
   global SCHASH
   variable settingsDir
   variable myRecentFiles
   variable myRecentPlaces
   variable settingsFile [file join $settingsDir rdt.txt]
   ##
   # Load prior shortcut hash file
   #
   if {![file isdirectory $settingsDir]} {
      file mkdir $settingsDir
   } elseif {[file exists $settingsFile]} {
      if {[catch {open $settingsFile r} fid] } then {
         logerr $fid
      } else {
         if {[catch {array set SCHASH [read $fid]} result] } then {
            logerr $result
         }
         close $fid
      }
   }
   if {![file isdirectory $myRecentFiles]} {
      file mkdir $myRecentFiles
   }
   if {![file isdirectory $myRecentPlaces]} {
      file mkdir $myRecentPlaces
   }
}
#------------------------------------------------------------------------------
#  Save the shortcut hash file for next time
#------------------------------------------------------------------------------
proc rdt::saveHash {args} {
   variable settingsFile
   if {[catch {open $settingsFile w} fod] } then {
      logerr $fod
   } else {
      puts $fod [array get ::SCHASH]
      close $fod
   }
   mk::file commit db
}
#------------------------------------------------------------------------------
#  exit the program
#------------------------------------------------------------------------------
proc rdt::unload {args} {
   variable folders
   variable folderID
   winico_delall
   foreach {id} $folderID {
      try {
         twapi::cancel_filesystem_monitor $id
      } on error result {
         logerr $result
      }
   }
   # save the hash file
   rdt::saveHash
   db::closeDB
   # Save limit
   S::saveSettings
   exit
}

#------------------------------------------------------------------------------
#  Remove then rescan everything
#------------------------------------------------------------------------------
proc rdt::restart {args} {
   global SCHASH
   if {[tk_messageBox -title "Please Confirm"  -type yesno -icon question -message "Are you want sure you want to rescan all Recent File shortcuts?\nthis will reset the database first."] == "yes"} {
      db::purgeDB
      unset -nocomplain SCHASH
      initialScan
      winTaskBar::cacheIcons
   }

}
#----------------------------------------------------------------------------
# Clear all settings
#----------------------------------------------------------------------------
proc rdt::resetSettings {args} {
   global SCHASH
   if {[tk_messageBox -title "Please Confirm" -type yesno -icon question -message "Are you sure you want to clear all history?\nthis will reset the database."] == "yes"} {
      db::purgeDB
      unset -nocomplain SCHASH
   }
}
#------------------------------------------------------------------------------
#  Initializion Routines
#------------------------------------------------------------------------------
proc rdt::Init {args} {
   variable hideExt
   S::setIconState "tclkit" 0
   rdt::getMapping
   rdt::restoreHash
   set hideExt [getExtSetting]
}
#----------------------------------------------------------------------------
# Background remove files that no longer exist from database
# Since file exists can be slow on a network, run this in a different thread
#----------------------------------------------------------------------------
proc rdt::bgCheckFile {{_once 0}} {
   variable missing
   variable T
   variable once $_once
   # filles & folders
   after cancel rdt::bgCheckFile
   set tocheck [list]
   array set powerstat [twapi::get_power_status]
   if {$powerstat(-acstatus) eq "on"} {
      #check files and folders
      foreach {fld} {0 1} {
         foreach {entry} [db::menuList * $fld] {
            lassign $entry file sctime ftime mounted
            lappend tocheck $file
         }
         # run in a different thread, a trace is set on the result
      }
#log "Starting bgcheck for [llength $tocheck] files"
# 2:20 min for 1884 files
      thread::send -async $T [list listMissing $tocheck] ::rdt::missing
      # every 60 minutes
      after 6000000 rdt::bgCheckFile
   } else {
      # every 2 minutes
      after 120000 rdt::bgCheckFile
   }
}
#----------------------------------------------------------------------------
# Purge files if they are missing
# called from a trace on ::rdt::missing
#----------------------------------------------------------------------------
proc rdt::purge {_var args} {
   upvar #0 $_var fileList
   variable once
#log "Processing purge for files from background check"
   foreach {file ftime} $fileList {
      if {! $ftime && ($S::S(deleteStale) || $once)} {
         db::removeFile $file
         # also need to clean the SCHASH which contains the shortcut, not the file name
         # get missing should also return the shortcut
         log "purged $file"
      } else {
         # update the file time
         if {$ftime > 0} {
            db::setVal $file Mounted 1
            db::setVal $file Ftime $ftime
         } else {
            db::setVal $file Mounted 0
            #log "Taken offline $file"
         }
      }
   }
   set once 0
}
#------------------------------------------------------------------------------
# Create a thread to perform background file existance checks
#------------------------------------------------------------------------------
proc rdt::makeThread {args} {
   variable T
   package require Thread
   set T [thread::create {
       proc ftime {file} {
         if {[catch {file mtime $file} t] } then {
            return 0
         } else {
            return $t
         }
       }
       proc listMissing {files} {
          set result [list]
          foreach {file} $files {
             lappend result $file [ftime $file]
             after 10
          }
          return $result
       }
      # keep thread alive
      thread::wait
   }]
}
#----------------------------------------------------------------------------
# Needed to create a menu font that matches the current system font
#----------------------------------------------------------------------------
proc createMenuFont {args} {
   menu .temp
   array set fm [font actual [.temp cget -font]]
   font create menu \
      -size $fm(-size) \
      -family $fm(-family) \
      -slant $fm(-slant) \
      -weight normal
   destroy .temp
}
#----------------------------------------------------------------------------
# Start the code here
#----------------------------------------------------------------------------

createMenuFont
rdt::Init
db::openDB
# allow other icons in settings dir
S::readSettings
winTaskBar::init [list $HOME $rdt::settingsDir]
rdt::initialScan
rdt::registerMonitors
rdt::makeThread
#after 5000 rdt::CleanSC
# background clean out dead files
after 30000 rdt::bgCheckFile
# look to remove old shortcuts
after 60000 rdt::purgeOld
log "RDT Ready"

#rdt::bgCleanSC



