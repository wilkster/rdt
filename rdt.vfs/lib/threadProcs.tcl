#
######################################################################################################
#                           Spawn Worker Threads & main thread looping
######################################################################################################
#------------------------------------------------------------------------------
# Create a thread to perform background file existance checks
#------------------------------------------------------------------------------
proc rdt::makeThread {args} {
   variable threadFull
   variable threadHash
   variable threadMenu
   variable threadVol
   variable threadScanFolder
   #------------------------------------------------------------------------------
   # Append the file status to a global variable, this can be slow on
   # remote networks so we do it in a thread to allow the gui to always work
   # a function on the main thread loops over the results and processes them
   #------------------------------------------------------------------------------
######################## Folder Monitor/Recent Scan Check Thread ##############################################################
   set threadHash [thread::create {
      ####################################################################
      # ready up for packages
      set ::auto_path [tsv::get rdt auto_path]
      package require pkgFunctions
      pkgFunctions::overLoadLoad [tsv::get rdt topdir]
      # load packages and wait
      package require twapi
      package require threadComTools
      # meat is here
      package require threadShortcut
      thread::wait

   }]
######################## Menu and Full File Background Check Thread ##############################################################
   
   #------------------------------------------------------------------------------
   # Thread functions to grab timestamps on files, this can be a slow process
   # on remote networks and we don't want to tie up the event queue and slow down
   # user interface.
   #------------------------------------------------------------------------------
   foreach Thr {threadFull threadMenu} {

      set $Thr [thread::create {
         ####################################################################
         # ready up for packages
         set  ::auto_path [tsv::get rdt auto_path]
         package require threadComTools
         ####################################################################
         # check the hash queue
         proc threadFtime {file} {
            if {[catch {file mtime $file} t] } then {
               return 0
            } else {
               return $t
            }
         }
         # User has pushed a list of files to process, start pulling them off
         # getting the timestamp and put the on a completed list when done
         # when commplete leave the function and wait for next call
         proc threadCheckStamp {mem} {
            while {[tsv::llength rdt $mem] > 0} {
               set file [tsv::lpop rdt $mem end]
               tsv::lpush rdt bgHashOutQueue [list $file [threadFtime $file]]
            }
         }
         thread::wait
      }]
   }
######################## Volume Check Thread ##############################################################
   set threadVol [thread::create {
      ####################################################################
      # ready up for packages
      set ::auto_path [tsv::get rdt auto_path]
      package require pkgFunctions
      pkgFunctions::overLoadLoad [tsv::get rdt topdir]
      # load packages and wait
      package require twapi
      package require threadComTools
      ####################################################################
      #----------------------------------------------------------------------------
      # Create an array of mounted/unmounted drives
      #
      # twapi::get_client_shares -> {\\Mediaserver\e} {\\MEDIASERVER\Bittorrent}
      # need to add client shares to handle files accessed via that method or
      #----------------------------------------------------------------------------
      proc cbCheckMounts {Vols} {
         #
         # do this in a thread since it can be slow when drives come on/off line
         # This will poke the volumes in a thread so any blocking when they go offline is done in the thread
         # not sure if necessary: todo: want to poke network drive letters 
         # that may be missing (newly booted but not connected)
         # what is passed in is a list of all known volumes/shares on this system since last reset
         # 
# commented out due to prompt for unmounted volumes possible
#         foreach {Vol} $Vols {
#            set res [file readable $Vol]
#         }
         #
         # at this point windows should know the state of each volume
         # bug: on bootup some letters won't show up unless the user has "touched" them, since we don't
         # know about the driver letters we can't do it here.
         #
         # Use twapi calls to get details on all the mounted volumes/drive letters
         #
         set shareMapping [list]
         # drive letters    [file volumes]
         foreach {vol} [twapi::find_logical_drives] {
            try {
               set fstype [twapi::get_volume_info $vol -fstype]   ;# trigger error if offline
               set Volumes($vol) 1
            } on error result {
               set Volumes($vol) 0
            }
         }
         # client shares
         lassign [twapi::get_client_shares -level 0] xx pairs
         foreach {pair} $pairs {
            lassign $pair local cs
            lassign [twapi::get_client_share_info $cs -status] xx info
            if {$info eq "connected"} {
               set Volumes($cs) 1
            } else {
               set Volumes($cs) 0
            }
            # set local [lindex [twapi::get_client_share_info $cs -localdevice] 1]
            # sometimes we can lose the mapping info returning a blank local device!!
            if {$local ne ""} {
               lappend shareMapping $cs $local
            }
         }
         # push info into main thread where it will be pulled off
         thread::send -async [tsv::get rdt H] [list rdt::cbSetVolumes [array get Volumes] $shareMapping]
         return ""
      }
      thread::wait
   }]


############## Adding a one-time user folder to  the database###############################
   set threadScanFolder [thread::create {
      ####################################################################
      # ready up for packages
      set  ::auto_path [tsv::get rdt auto_path]
      package require pkgFunctions
      package require threadComTools
      ####################################################################
      #---------------------------------------------------------------------------- 
      # Return a list of folders (not recursive)
      # do so in an efficient manner (minimize memory)
      #  thread::send -async $rdt::threadScanFolder [list scanFolders "C:/users/tom" 0 "excel" [iconDB::getGlobber "excel"] 0]
      #---------------------------------------------------------------------------- 
      proc scanFolders {base cutoff lastIcon Globber useAll} {
         # must be in unix format and in a list
         set dirs [list [string map {\\ /} $base]]
         debug "Started Scanning $base with $Globber"
         set pushed 0
         while {[llength $dirs]} {
            set name [lindex $dirs 0]   ;# this folder
            # keep replacing the first folder name with it's children to build deep list
            # 5. Iterative, depth-first traversal, Tcl 8.5,
            set dirs [lreplace $dirs 0 0 {*}[glob -nocomplain -directory $name -type {d r} *]]
            if {$lastIcon eq "folder"} {
               set folder [file nativename $name]
               file stat $folder T
               set atime  $T(atime)
               if {$atime > $cutoff} {
                  tsv::lpush rdt bgScanOutQueue [list $folder $T(mtime) $atime "folder" $lastIcon]
                  incr pushed
               }
            } else {
               # for this folder, process all the user owned files that match the Globber/Icon
               incr pushed [pushOneFolder $name $cutoff $lastIcon $Globber $useAll]
            }
         }
         log "Completed Scanning folders $base with $pushed $lastIcon files/folders"
      }
      # Scan a single folder
      proc scanFolder {base cutoff lastIcon Globber useAll} {
         # must be in unix format and in a list
         set dir [list [string map {\\ /} $base]]
         debug "Started Scanning $dir with $Globber"
         set pushed [pushOneFolder $dir $cutoff $lastIcon $Globber $useAll]
         log "Completed Scanning folder $base with $pushed $lastIcon files/folders"
         return $pushed
      }
      #------------------------------------------------------------------------------
      # Scan one folder and push results on thread queue
      #------------------------------------------------------------------------------
      proc pushOneFolder {dir cutoff lastIcon Globber useAll} {
         # must be in unix format and in a list
         set pushed 0
         # for this folder, process all the user owned files that match the Globber/Icon
         foreach {file} [glob -nocomplain -directory $dir -types {f r} $Globber] {
            if {$useAll || [file owned $file]} {
               file stat $file T
               set atime  $T(atime)
               if {$atime > $cutoff} {
                  set file [file nativename $file]
                  tsv::lpush rdt bgScanOutQueue [list $file $T(mtime) $atime "" $lastIcon]
                  incr pushed
               }
            }
         }
         return $pushed
      }


      thread::wait
   }]
}

######################################################################################################
#                           In Primary Thread
######################################################################################################

#----------------------------------------------------------------------------
# Background remove files that no longer exist from database
# Since file exists can be slow on a network, run this in a different thread
#----------------------------------------------------------------------------
proc rdt::bgCheckFile {args} {
   variable threadFull
   variable ageCutoff
   variable ACStatus
   # Check every 24 hours
   set minutes [expr {24*60}]
   # filles & folders
   after cancel rdt::bgCheckFile
   # Check all non-menu shown files at a slower rate
   if {$ACStatus} {
      # don't check files more often than once a day that aren't in the menu
      set lastCheck [expr {[clock seconds] - $minutes*60}]
      checkFiles $threadFull "toCheckFull" $ageCutoff 1000 $lastCheck
   }
   # once an hour
   after [expr 60*60*1000] rdt::bgCheckFile
}
#----------------------------------------------------------------------------
# Check the files in the menu as missing or not, do more routinely
# merge with bgCheckFile and maybe do a module type interleave
# menu check needs to be done much more often
#----------------------------------------------------------------------------
proc rdt::bgCheckMenu {args} {
   variable threadMenu
   variable ACStatus
   variable ageCutoff
   # Check every 30 minutes
   set minutes 30
   after cancel rdt::bgCheckMenu
   # Check files back 5 days (0 to $ageCutoff)
   if {$ACStatus} {
      # cutoff is last checked time
      # don't check files more often than 30 min that are in the menu
      set lastCheck [expr {[clock seconds] - $minutes*60}]
      checkFiles $threadMenu "toCheckMenu" 0 $ageCutoff $lastCheck
   }
   # flush the database routinely
   db::Commit
   # every 5 minutes
   after [expr 5*60*1000] rdt::bgCheckMenu
}
#---------------------------------------------------------------------------- 
# Force check the menu now
#---------------------------------------------------------------------------- 
proc rdt::forceCheckMenu {args} {
   variable threadMenu
   variable ACStatus
   variable ageCutoff
   checkFiles $threadMenu "toCheckMenu" 0 $ageCutoff [clock seconds]
}
#---------------------------------------------------------------------------- 
# Force check all files
#---------------------------------------------------------------------------- 
proc rdt::forceCheckAll {args} {
   variable threadMenu
   variable ACStatus
   variable ageCutoff
   checkFiles $threadMenu "toCheckMenu" 0 10000 [clock seconds]
}

#------------------------------------------------------------------------------
# build list of files to check, add them to the apprpriate queue then
# trigger the correct thread to go process them
#------------------------------------------------------------------------------
proc rdt::checkFiles {thread mem ageNew ageOld cutoff} {
   # 4 hours
   set count 0
   if {[tsv::llength rdt $mem] < 1} {
      # Return entries no more than age days ago
      foreach {index} [db::BGcheckList $ageNew $ageOld $cutoff] {
         tsv::lpush rdt $mem [db::getValbyRow $index "File"]
         incr count
      }
      # if thread already working a list then this will go in it's queue
      # and when it is finally services the queue will most likely be empty
      # then and the process will complete. So no redudant cheks will take place
      # since there is only one queue per thread.
      if {$count > 0} {
         thread::send -async $thread [list threadCheckStamp $mem]
      }
   } else {
      debug "Skipping $mem check, backlog of [tsv::llength rdt $mem] files in queue"
   }
}

#------------------------------------------------------------------------------
# Called from shortcut callback to add a row to the database
# Called from shortcut monitoring thread and local function during initial scan
#------------------------------------------------------------------------------
proc rdt::cbAddShortcut {row} {
   # pull data off shared variable
   lassign $row dest shortcut stime sckey destType destMtime

   # in: $dest $shortcut $stime $sckey out: $dest $shortcut $stime $sckey $destType $destMtime
   if {$destType eq ""} then {
      if {$S::S(deleteDead)} {
         file delete -force $shortcut
         debug "removing $shortcut since $dest no longer exists"
      } else {
         debug "skipping $shortcut since $dest no longer exists"
      }
   } else {
      # convert to local (vs unc) mapping if possible
      set dest [rdt::mapLocal $dest]
      # get type
      set type [iconDB::nameToType $dest $destType]
      # hash file, type and icon
      # During monitoring: this will be called 2-3 or 4 times for the same file, 
      # the data is redundant. Shouldn't be a performance issues.
      db::cacheFile $dest $destMtime $stime $type
   }
}

#------------------------------------------------------------------------------
# Add a file from file monitoring
#------------------------------------------------------------------------------
proc rdt::cbAddFile {dest type mtime atime icon} {
   set dest [rdt::mapLocal $dest]
   set type [iconDB::nameToType $dest $type]
   if {[string first $icon $type]>=0} {
      db::cacheFile $dest $mtime $atime $type
#log "cbAddFile $dest $mtime $atime $type"
   } else {
#log "skip cbAddFile $dest $mtime $atime $type"
   }
}
#------------------------------------------------------------------------------
# Add a file from file monitoring
#------------------------------------------------------------------------------
proc rdt::cbSetMissing {dest} {
   set dest [rdt::mapLocal $dest]
   # if isn't in database then will return OK
   db::setVal $dest Exists 0
#log "cbSetMissing $dest"
}
#------------------------------------------------------------------------------
# Add a file from file monitoring
#------------------------------------------------------------------------------
proc rdt::cbRemoveFile {dest} {
   set dest [rdt::mapLocal $dest]
   # if isn't in database then will return OK
   db::removeFile $dest
#log "cbRemoveFile $dest"
}


#------------------------------------------------------------------------------
# async callback to set volume/sharemapping inf
# called from checkVolumes in another thread
#------------------------------------------------------------------------------
proc rdt::cbSetVolumes {rowVol rowShare} {
   variable shareMapping
   variable Volumes
   # save volumes for later so we have a superset of them
   # this will merge both version into a superset
   foreach {vol} $S::S(saveVols) {
      set Volumes($vol) 0
   }
   # if volume offline it will be missing, so assume it is 0 above
   array set Volumes $rowVol
   set S::S(saveVols) [array get Volumes]
   set shareMapping $rowShare
   rdt::FlagMountedStatus
}
#------------------------------------------------------------------------------
#  Periodically pull new hashes off the queue(s) and process them
#------------------------------------------------------------------------------
proc rdt::loopHashes {args} {
   variable shareMapping
   variable Volumes
   set processed 0
   #
   # Background file check, either the menu or non-menu
   #
   while {[tsv::llength rdt bgHashOutQueue] > 0} {
      incr processed
      lassign [tsv::lpop rdt bgHashOutQueue end] file ftime
      # only deal with mounted files
      if {[db::getVal $file "Mounted"] == 1} {
         if {! $ftime && ($S::S(deleteStale))} {
            # Only checked mounted folders, so it must really be missing
            db::removeFile $file
            # also need to clean the SCHASH which contains the shortcut, not the file name
            # get missing should also return the shortcut
            log "purged $file"
         } else {
            # update the file time or flag the file as missing
            if {$ftime > 0} {
               # will also flag as exists
               db::setVal $file Ftime $ftime
            } else {
               db::setVal $file Exists 0
               #log "Taken offline $file"
            }
         }
      }
   }
   #
   # shortcut queue for initial shortut scan
   #
   while {[tsv::llength rdt fgHashOutQueue] > 0} {
      incr processed
      # pull data off shared variable
      rdt::cbAddShortcut [tsv::lpop rdt fgHashOutQueue end]
   } 
   #
   # Files added by a user scan
   #
   while {[tsv::llength rdt bgScanOutQueue] > 0} {
      incr processed
      # pull data off shared variable and push to database
      lassign [tsv::lpop rdt bgScanOutQueue end] fl mt at ft lastIcon
      if {! [db::entryExists $fl]} {
         # this check is not redundant
         set type [iconDB::nameToType $fl $ft]
         # don't add files that don't match icons
         if {[string first $lastIcon $type]>=0} {
            db::cacheFile $fl $mt $at $type
         }
      }
   }

   # reschedule according to activity
   after cancel rdt::loopHashes
   if {$processed > 0} {
      # just proessed some, tighter loop till done
      set next 500
   } else {
      # idle loop
      set next 10000
   }
   after $next rdt::loopHashes
}

package provide threadProcs 1.0
