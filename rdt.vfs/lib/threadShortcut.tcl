package provide threadShortcut 1.0
####################################################################
#------------------------------------------------------------------------------
# Establish folders for monitoring
# http://twapi.sourceforge.net/v3.1/disk.html#begin_filesystem_monitor
#------------------------------------------------------------------------------
namespace eval sc {
  variable SCHASH
  variable folderID [list]
  variable _settingsFile 
}

#------------------------------------------------------------------------------
# get/set the SCHASH array, can also be done from main
#------------------------------------------------------------------------------
proc sc::clearSCHASH {args} {
   variable SCHASH
   array unset SCHASH
}
#---------------------------------------------------------------------------- 
# Stop monitoring, called at shutdown
#---------------------------------------------------------------------------- 
proc sc::stopMonitoring {args} {
   variable folderID
   foreach {id} $folderID {
      catch {
         twapi::cancel_filesystem_monitor  $id
      }
   }
   set folderID [list]
}

#------------------------------------------------------------------------------
# Setup initial monitoring
#------------------------------------------------------------------------------
proc sc::setupMonitoring {folders} {
  variable SCHASH
  variable folderID
  foreach {folder} $folders {
     if {[file isdirectory $folder] && [file readable $folder]} {
        try {
           log "installing shortcut folder monitor for $folder"
           lappend folderID [twapi::begin_filesystem_monitor $folder [list sc::monitorCallback $folder] \
               -subtree 0 -filename 1 -write 1 -patterns {*.lnk}]
        } on error result {
           logerr $result
        }
     }
  }
}
#---------------------------------------------------------------------------- 
# Perform the initial scan on startup, working in a thread async
#---------------------------------------------------------------------------- 
proc sc::initialScan {folders} {
   variable SCHASH
   variable folderID
   variable _settingsFile 
   set patterns [list]
   set files    [list]
   set added    0
   #
   # Initialize SCHASH values to 0 then scan (reverify)
   #
   foreach {key} [array names SCHASH] {
      set SCHASH($key) 0
   }
   foreach {folder} $folders {
      try {
         if {[file isdirectory $folder]} {
            set files [glob -directory $folder -nocomplain "*.lnk"]
            set total [llength $files]
            log "Scanning Shortcut Folder $folder with $total files"
            foreach {link} $files {
               set row [getHashShortcut $link]
               # push into queue for main thread to process into database
               # could perhaps just send a send -async but there may be many many entries first time
               if {[llength $row] > 1} {
                  tsv::lpush rdt fgHashOutQueue $row
                  incr added
               }
            } 
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
         #debug "removed $key"
      }
   }
   # saveHash
   sc::saveHash $_settingsFile
   if {$added > 0} {
      log "$added files added to cache"
   }
}
#----------------------------------------------------------------------------
# callback when a recent file shortcut is added,modified or removed, update the menu hash
# On a change, first a removed is called then an add is called (remove -> add -> modify)
#----------------------------------------------------------------------------
proc sc::monitorCallback {args} {
   variable SCHASH
   set folder [lindex $args 0]
   set method [lindex $args 2 0]
   set file [lindex $args 2 1]
   set shortcut [file join $folder $file]
   switch -- $method {
      "added" {
         try {
            #
            # tell main thread to process immediately
            # 
            set added [getHashShortcut $shortcut]
            if {[llength $added] > 1} {
               thread::send -async [tsv::get rdt H] [list rdt::cbAddShortcut $added]
            }
         } on error result {
            logerr $result
         }
         # save the datbase in the near future
         # todo need to flag the SCHASH as dirty
      }
      "modified" {
         # shouldn't matter, file may be renamed but not the shortcut
      }
      "removed" {
         # note, the original file and shortcut is still in the database
         array unset SCHASH "*|$shortcut"
         # todo need to flag the SCHASH as dirty
      }
      default {
         log "$method monitorCallback $shortcut"
      }
   }
}
#------------------------------------------------------------------------------
# getHashShortcut is called from both the file monitor and in a loop during initialization
# will get called for the file and the shortcut, possibly multiple times for windows and office recent
#------------------------------------------------------------------------------
proc sc::getHashShortcut {shortcut} {
   variable SCHASH
   set added [list]
   # add file to queue to be processed
   if {[string equal -nocase ".lnk" [file extension $shortcut]] && [file exists $shortcut]} {
      set stime [file mtime $shortcut]
      set sckey "$stime|$shortcut"
      # if already hashed, then assume the destination file is good
      if {![info exists SCHASH($sckey)]} {
         # determine the target file name of the shortcut
         try {
            array set scArray [twapi::read_shortcut $shortcut -nosearch -noui -nolinkinfo -timeout 500] ;# keyed list
            set dest $scArray(-path)
            # send the target file info to worker thread to check detailed file status
            if {$dest ne ""} {
               # URL links will have a blank path
               if {[catch {file stat $dest data} error]} then {
                  #ignore files when I can't check the timestamp
                  #tfw added back in 3/18/2017 to delete link if settings permit
                  set added [list $dest $shortcut $stime $sckey "" ""]
               } else {
                  if {$data(type) eq "directory"} {
                     set type "folder"
                  } else {
                     set type $data(type)
                  }
                  set added [list $dest $shortcut $stime $sckey $type $data(mtime)]
               }
               set SCHASH($sckey) 1
            }
         } on error result {
            logerr $result
         }
      } else {
         set SCHASH($sckey) 1
      }
   }
   return $added
}

#------------------------------------------------------------------------------
#  Save the shortcut hash file for next time
#------------------------------------------------------------------------------
proc sc::saveHash {hashFile} {
   variable SCHASH
   # todo, can we move this function into thread?
   if {[catch {open $hashFile w} fod] } then {
      logerr $fod
   } else {
      puts $fod [array get SCHASH]
      close $fod
   }
}
#------------------------------------------------------------------------------
#  Restore the shortcut hash file for next time
#------------------------------------------------------------------------------
proc sc::restoreHash {hashFile} {
   variable SCHASH
   variable _settingsFile $hashFile
   array unset SCHASH
   ##
   # Load prior shortcut hash file
   #
   set settingsDir [file dirname $hashFile]
   if {![file isdirectory $settingsDir]} {
      file mkdir $settingsDir
   } elseif {[file exists $hashFile]} {
      if {[catch {open $hashFile r} fid] } then {
         logerr $fid
      } else {
         if {[catch {array set SCHASH [read $fid]} result] } then {
            logerr $result
         }
         close $fid
      }
   }
}

#---------------------------------------------------------------------------- 
# File monitor namespace
#---------------------------------------------------------------------------- 
namespace eval fm {
   variable folderID [list]
   variable folderIcons
}

#---------------------------------------------------------------------------- 
# Stop monitoring, called at shutdown
#---------------------------------------------------------------------------- 
proc fm::stopMonitoring {args} {
   variable folderID
   variable folderIcons
   foreach {id} $folderID {
      try {
         twapi::cancel_filesystem_monitor  $id
      } on error result {
         logerr $result
      }
   }
   set folderID [list]
   unset -nocomplain folderIcons
}

#------------------------------------------------------------------------------
# Setup initial monitoring
#------------------------------------------------------------------------------
proc fm::setupMonitoring {monSets} {
   variable folderID
   variable folderIcons
   fm::stopMonitoring
   foreach {monSet} $monSets {
      lassign $monSet folder icon usesub Globber
      if {[file isdirectory $folder] && [file readable $folder]} {
        try {
           set ID [twapi::begin_filesystem_monitor $folder [list fm::monitorCallback $folder] \
               -create 1 -access 1 -write 1 -subtree $usesub -filename 1 -patterns $Globber]
            if {$usesub} {
               log "installing $icon folder monitor for $folder and subfolders"
            } else {
               log "installing $icon folder monitor for $folder"
            }
           lappend folderID $ID
           set folderIcons($ID) $icon
        } on error result {
           logerr $result
        }
     }
   }
}

#----------------------------------------------------------------------------
# callback when a recent file shortcut is added,modified or removed, update the menu hash
# On a change, first a removed is called then an add is called (remove -> add -> modify)
#----------------------------------------------------------------------------
proc fm::monitorCallback {args} {
   variable folderID
   variable folderIcons
   set folder [lindex $args 0]
   set method [lindex $args 2 0]
   set file [lindex $args 2 1]
   set fullPath [joinFile $folder $file]
   set handle [lindex $args 1]
   set H [tsv::get rdt H]
   # ignore temp office files
   if {[string first "~" $file]>=0} {
      return
   }
#log "$method -> $fullPath"
   switch -- $method {
      "added" -
      "modified" -
      "renamenew"
       {
      # 'C:/Users/tomwi/Documents/TMB {1352 HANDLE} {modified {TMB Beginners Guide - Copy.docx}}'
      # 'C:/Users/tomwi/Documents/TMB {1352 HANDLE} {renamenew {TMB Beginners Guide - Copy.docx}}'
         try {
            tryAddFile $fullPath $folderIcons($handle)
         } on error result {
            logerr $result
         }
      }
      "removed" {
         # note, the original file and fullPath is still in the database
         # 'C:/Users/tomwi/Documents/TMB {1352 HANDLE} {removed {~$B Beginners Guide.docx}}'
         thread::send -async $H [list rdt::cbSetMissing $fullPath]
      }
      "renameold" {
      # renameold monitorCallback 'C:/Users/tomwi/Documents/TMB {1352 HANDLE} {renameold {TMB Beginners Guide - Copy.docx} renamenew {TMB Beginners Guide C.docx}}'
         thread::send -async $H [list rdt::cbRemoveFile $fullPath]
         # new file
         set fullPath [joinFile $folder [lindex $args 2 3]]
         tryAddFile $fullPath $folderIcons($handle)
      }
      default {
         log "$method monitorCallback $fullPath\n$args"
      }
   }
}

#------------------------------------------------------------------------------
# Get file or folder
#------------------------------------------------------------------------------
proc fm::ftype {fname} {
   if {[file isdirectory $fname]} {
      return "folder"
   } else {
      return "file"
   }
}
#------------------------------------------------------------------------------
# Add or update a file info in the database
#------------------------------------------------------------------------------
proc fm::tryAddFile {fullPath icon} {
   set H [tsv::get rdt H]
   if {[catch {file stat $fullPath data} result]} then {
      # file may have changed quickly, so not really an error
      log $result
   } else {
      if {$data(type) eq "directory"} {
         set type "folder"
      } else {
         set type $data(type)
      }
      thread::send -async $H [list rdt::cbAddFile $fullPath $type $data(mtime) $data(atime) $icon]
   }
}
