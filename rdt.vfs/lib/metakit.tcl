# *************************************************************************
# * File   : metakit.tcl
# * Purpose: RDT Metakit Wrapper
# *
# * Author : Tom Wilkason
# * Dated  : 10/4/2010
# *
# *************************************************************************
set RH {
  Revision History:
  -----------------
  $Revision:$
  $Log:$
  #Image no longer saved, always computed dynamically
}
package require Mk4tcl
namespace eval db {
   variable dbObj
   variable DB "db.catalog"
   variable dbLocation
   variable fieldSpec
}
#----------------------------------------------------------------------------
# Function   : db::open
# Description: Create the user database if needed
# Author     : Tom Wilkason
# Date       : 9/21/2002
#----------------------------------------------------------------------------
proc db::openDB {args} {
   variable dbLocation
   variable dbObj
   variable fieldSpec
   variable DB
   set dbLocation [file nativename [file join $rdt::settingsDir "rdt.mk"]]
   set fieldSpec [list File Folder Ext IsFolder:I Ftime:I Sctime:I Mounted:I Exists:I Hits:I Pinned:I Excluded:I IsOpen:I IconType Image Checked:I stFtime stSctime]
   if {[catch {mk::file open db $dbLocation -nocommit} result]} {
      set res [tk_messageBox -title "Database Open Error" -type ok -icon warning \
         -message "The RDT database '$dbLocation' could not be opened\n\n$::errorInfo"]
      exit
   }

   ##
   # main db to hold data, uses blocking
   #
   mk::view layout db.catalog $fieldSpec
   mk::view open db.catalog __db_data ;# Don't touch __db_data command
   ##
   # db.catalog_map is secondary view for hashing
   #
   mk::view layout db.catalog_map {_H:I _R:I}
   ##
   # Create a hash map view for direct access on find
   # combines the base and hash map views
   mk::view open db.catalog_map __db_map
   # __db_data is raw command, __db_map is just map view, dbObj is hashed view
   # Create an ordered/hash view, all udpates are made in an ordered fashion
   # so we don't have to do any sorting during the query
   set dbObj [__db_data view hash __db_map 1]
}

#----------------------------------------------------------------------------
# Close the database
#----------------------------------------------------------------------------
proc db::closeDB {args} {
   mk::file commit db
   mk::file close db
}

#----------------------------------------------------------------------------
# Function   : db::Commit
# Description: Flush the data after cataloging
# Author     : Tom Wilkason
# Date       : 1/7/2001
#----------------------------------------------------------------------------
proc db::Commit {} {
   mk::file commit db
}

#----------------------------------------------------------------------------
# Return a list of mounted files that are no older than nn daysAgo, for background checking
#----------------------------------------------------------------------------
proc db::BGcheckList {daysAgoNew daysAgoOld lastChecked} {
   variable dbObj
   variable DB
   set result [list]
   set newTime [expr {[clock seconds] - $daysAgoNew*60*60*24}]
   set oldTime [expr {[clock seconds] - $daysAgoOld*60*60*24}]
   return [mk::select $DB -max Sctime $newTime -min Sctime $oldTime -max Checked $lastChecked -exact Mounted 1 -rsort Sctime]
}

#----------------------------------------------------------------------------
# Return a list of file in a tree sorted by shortcut access time
# used to populate a menu
# filtered by file extension
#----------------------------------------------------------------------------
proc db::menuList {pattern isfolder pinned limit} {
   variable DB
   variable dbObj
#  debug "[whocalled] db::menuList $pattern $isfolder $pinned"
   set opts [list -exact Excluded 0 -exact IsFolder $isfolder -exact Mounted 1 -rsort Sctime]
   if {$pattern ne "*"} {
      lappend opts -keyword IconType $pattern
   }
   if {$pinned ne ""} {
      lappend opts -exact Pinned $pinned
   }
   set rows  [mk::select $DB {*}$opts]
   # build the result
   return [lmap row [lrange $rows 0 $limit] {$dbObj get $row File Sctime Ftime Exists IsOpen}]
}
#----------------------------------------------------------------------------
# Return a list of files that are not mounted, used to clear out the old missing files
#----------------------------------------------------------------------------
proc db::missingList {type {pinned ""}} {
   variable DB
   variable dbObj
   set opts [list -exact Excluded 0 -exact Exists 0 -exact Mounted 1 -rsort Sctime]
   set result [list]
   if {$pinned ne ""} {
      lappend opts  -exact Pinned $pinned
   }
   if {$type ne "*"} {
      lappend opts -keyword IconType $type
   }
   return [lmap row [mk::select $DB {*}$opts] {$dbObj get $row File}]
}

#----------------------------------------------------------------------------
# Return a list of files in a tree sorted by shortcut access time
# used to populate a menu
# filtered by file name  todo:pass in filtered
# todo: Use db::getIcon to return the icon and not Pinned, IsOpen
#       Exists and Excluded still needed
#----------------------------------------------------------------------------
proc db::fileListRows {pattern isfolder {type ""}} {
   variable DB
   variable dbObj
   set opts [list  -exact IsFolder $isfolder -exact Mounted 1 -rsort Sctime]
   set result [list]
   if {$pattern ne "*"} {
      lappend opts -globnc File $pattern
   }
   if {$type ne ""} {
      lappend opts -keyword IconType $type
   }
   return [mk::select $DB {*}$opts]
}
#---------------------------------------------------------------------------- 
# Return just the row indicies
#---------------------------------------------------------------------------- 
proc db::tvRowList {pattern isfolder filtered type limit srtOpt} {
   variable DB
   variable dbObj
   # skip if in exclucde list or it is not exists
   # if {($excluded || ! $exists) && $filtered==1}
   set opts [list -exact Mounted 1 -exact IsFolder $isfolder {*}$srtOpt]
   # if filtered exclude not-exists and excluded
   if {$pattern ne "*"} {
      lappend opts -globnc File $pattern
   }
   if {$type ne ""} {
      lappend opts -keyword IconType $type
   }
   if {$filtered} {
      lappend opts -exact Exists 1 -exact Excluded 0
   }
   return [lrange [mk::select $DB {*}$opts] 0 $limit]
}
#------------------------------------------------------------------------------
#  Return one row of data for the treeview
#------------------------------------------------------------------------------
proc db::tvOneRow {row} {
   variable DB
   variable dbObj
   return [$dbObj get $row File stSctime stFtime Exists Pinned Excluded Hits IsOpen]
}
#----------------------------------------------------------------------------
# Cache a single file name looking up info for it
# If it exists, just check/update the access time (sctime)
# destMtime is mod time of target
# sctime is mod time of shortcut
#----------------------------------------------------------------------------
proc db::cacheFile {File destMtime sctime type} {
   variable checkTime
   variable dbObj
   ;# If file not in db, then cache just basic part
   if {[catch {$dbObj find File $File} row] } then {
      if {$type eq "folder"} {
         set isFolder 1
      } else {
         set isFolder 0
      }
      set row [$dbObj size]
      $dbObj insert end \
         Ext      [string tolower [file extension $File]]  \
         File     $File        \
         Folder   [file dirname $File] \
         isFolder $isFolder \
         Ftime    $destMtime \
         stFtime  [txtTime $destMtime] \
         Exists   1        \
         IsOpen   0        \
         Mounted  1        \
         Hits     1        \
         Pinned   0        \
         Sctime    $sctime \
         stSctime [txtTime $sctime] \
         IconType  $type   \
         Checked  [clock seconds]
      return $row
   } else {
      # update access time and hit count if incoming is greater
#debug "  Update Access Time $File $destType $destMtime $sctime $type"
      lassign [$dbObj get $row Sctime Hits] esctime hits
      if {$sctime > $esctime} {
         $dbObj set $row Sctime $sctime stSctime [txtTime $sctime] Ftime $destMtime stFtime [txtTime $destMtime] Hits [incr hits] Exists 1
      }
      return $row
   }
}
#----------------------------------------------------------------------------
# Set a value
#----------------------------------------------------------------------------
proc db::setVal {File Field val} {
   variable dbObj
   variable mods
   try {
      set row [$dbObj find File $File]
      # update string value of times if necessary, and flag checked time
      if {$Field eq "Ftime"} {
         $dbObj set $row $Field $val stFtime [txtTime $val] Checked [clock seconds] Exists 1
      } elseif {$Field eq "Sctime"} {
         $dbObj set $row $Field $val stSctime [txtTime $val] Checked [clock seconds] Exists 1
      } elseif {$Field eq "Exists"} {
         $dbObj set $row $Field $val Checked [clock seconds]
      } else {
         $dbObj set $row $Field $val
      }
   } on error result {
      return ""
   }
   return $val
}
#----------------------------------------------------------------------------
# get value(s) for user specified fields
#----------------------------------------------------------------------------
proc db::getVal {File Fields} {
   variable dbObj
   if {[catch {$dbObj find File $File} row] } then {
      return ""
   }
   return [$dbObj get $row {*}$Fields]
}
#---------------------------------------------------------------------------- 
# Get a value knowing a row number
#---------------------------------------------------------------------------- 
proc db::getValbyRow {row Fields} {
   variable dbObj
   return [$dbObj get $row {*}$Fields]
}

#----------------------------------------------------------------------------
# File Exists
#----------------------------------------------------------------------------
proc db::entryExists {File} {
   variable dbObj
   variable mods
   if {[catch {$dbObj find File $File} row] } then {
      return 0
   } else {
      return 1
   }
}

#----------------------------------------------------------------------------
# Function   : db::removeFile
# Description: Remove a file from the database
# Author     : Tom Wilkason
# Date       : 1/19/2003
#----------------------------------------------------------------------------
proc db::removeFile {File} {
   variable dbObj
   variable mods
   if {[string is integer -strict $File]} {
       $dbObj delete $File ;# Make sure row indicies work here
   } else {
      if {[catch {$dbObj find File $File} row] } then {
         return 0
      } else {
         $dbObj delete $row ;# Make sure row indicies work here
      }
   }
   return 1
}
#----------------------------------------------------------------------------
# Remove entries older than "days" old in database
#----------------------------------------------------------------------------
proc db::purgeOldShortCut {cutoff} {
   variable dbObj
   variable DB
   #remove oldest first
   set rows [lsort -integer -decreasing [mk::select $DB -max Sctime $cutoff]]
   foreach row $rows {
      $dbObj delete $row
   }
   mk::file commit db
   return [llength $rows]
}

#------------------------------------------------------------------------------
# Close the reopen the database
#------------------------------------------------------------------------------
proc db::purgeDB {args} {
   mk::file close db
   variable dbLocation
   file delete -force $dbLocation
   db::openDB
}
#---------------------------------------------------------------------------- 
# Clear duplicate and misnammed entires (due to file case) from database
#---------------------------------------------------------------------------- 
proc db::clearDups {pattern} {
   variable dbObj
   variable DB
   set changes 0
   # last entries will be processed first
   set rows [lsort -integer -decreasing [mk::select $DB -glob File $pattern]]
   foreach row $rows {
      set ofile [$dbObj get $row File]
      set ufile [string toupper $ofile]
      if {[info exists hash($ufile)]} {
         debug "$ofile is a duplicate"
         $dbObj delete $row ;# Make sure row indicies work here
         incr changes
      } else {
         incr hash($ufile)
         # make sure name is mapped to local and in native name format
         set mfile [rdt::mapLocal [file nativename $ofile]]
         if {$ofile ne $mfile} {
            $dbObj set $row File $mfile
            incr changes
            debug "$ofile -> $mfile"
         }
      }
   }
   unset -nocomplain hash
   return $changes
}

#----------------------------------------------------------------------------
# Return the number of tracks indexed
# Note: Should limit to media folders
#----------------------------------------------------------------------------
proc db::numTracks {how} {
   variable dbObj
   variable DB
   switch -- $how {
      0 {set active [llength [mk::select $DB -exact Exists 1 -exact Mounted 1]]}
      1 {set total [$dbObj size]}
      2 {set unmounted [llength [mk::select $DB -exact Exists 1 -exact Mounted 0]]}
      3 {set missing [llength [mk::select $DB -exact Exists 0 -exact Mounted 1]]}
      4 {set missing [llength [mk::select $DB -exact Exists 0 -exact Mounted 0]]}
      default {}
   }
}
#---------------------------------------------------------------------------- 
# Update the database to asscoate each file type to a list of tray icons
#---------------------------------------------------------------------------- 
# to use -> db::setTypes winTaskBar::extToType
proc db::setTypes {_hash} {
   upvar $_hash hash
   variable DB
   variable dbObj
   foreach {row} [mk::select $DB -exact IsFolder 0] {
      set ext [string tolower [string range [$dbObj get $row Ext] 1 end]]
      if {[info exists hash($ext)]} {
         $dbObj set $row IconType $hash($ext)
         #debug "Setting file extension $ext to $hash($ext)"
      } else {
         $dbObj set $row IconType ""
         #debug "Unknown file extension $ext"
      }
   }
   return 1
}
# #----------------------------------------------------------------------------
# # Update the database to associate each file type to a list of tray icons
# # Not yet implemented, need cleaner way to pass in incon info and
# # to ensure database icon is in sync with database changes.
# # may be easier to continue to do this dymanimically
# #----------------------------------------------------------------------------
# proc db::setIcons {args} {
#    variable DB
#    variable dbObj
#    set I 0
#    foreach {row} [mk::select $DB] {
#       lassign [$dbObj get $row File Ext IsFolder Pinned Excluded IsOpen] File Ext IsFolder Pinned Excluded IsOpen
#       set img [db::getIcon $File $IsFolder $Pinned $Excluded $IsOpen]
#       $dbObj set $row Image $img
#       incr I
#    }
#    return $I
# }
#
# #------------------------------------------------------------------------------
# # Return an icon based on settings (todo: update database with this info)
# #------------------------------------------------------------------------------
# proc db::getIcon {File isFolder pinned excluded isopen} {
#    set icons ""
#    if {$isFolder} {
#       if {$excluded} {
#          set icons [iconDB::extToIcon "filter"]
#       } elseif {$pinned} {
#          set icons [iconDB::extToIcon "pinned"]
#       } else {
#          set icons [iconDB::extToIcon "folder"]
#       }
#    } else {
#       if {$excluded} {
#          set icons [iconDB::extToIcon "filter"]
#       } elseif {$isopen} {
#          set icons [iconDB::extToIcon "fopen"]
#       } elseif {$pinned} {
#          set icons [iconDB::extToIcon "pinned"]
#       } else {
#          set ext [string tolower [file extension $File]]
#          set icons [iconDB::extToIcon $ext]
#       }
#    }
#    return $icons
# }

#---------------------------------------------------------------------------- 
# Return hash of all files and their count
#---------------------------------------------------------------------------- 
proc db::getTypes {_hash} {
   upvar $_hash hash
   variable DB
   variable dbObj
   foreach {row} [mk::select $DB -exact IsFolder 0] {
      set ext [string tolower [string range [$dbObj get $row Ext] 1 end]]
      incr hash($ext)
   }
   return 1
}
#------------------------------------------------------------------------------
# flag files as online or offline
#------------------------------------------------------------------------------
proc db::flagMounted {what how} {
   variable DB
   variable dbObj
   set count 0
   # flag all the ones that don't meet the condition
   foreach {row} [mk::select $DB -globnc File "${what}*" -exact Mounted [expr {! $how}]] {
      $dbObj set $row Mounted $how
      incr count
   }
   return $count
}
#------------------------------------------------------------------------------
# Reset all files flagged as open, very fast
#------------------------------------------------------------------------------
proc db::resetOpen {args} {
   variable DB
   variable dbObj
   set count 0
   # flag all the ones that don't meet the condition
   foreach {row} [mk::select $DB -exact IsOpen 1] {
      $dbObj set $row IsOpen 0
   }
   # fixup missing times
   foreach {row} [mk::select $DB -exact stFtime ""] {
      set tm [$dbObj get $row Ftime]
      $dbObj set $row stFtime [txtTime $tm]
   }
   foreach {row} [mk::select $DB -exact stSctime ""] {
      set tm [$dbObj get $row Sctime]
      $dbObj set $row stSctime [txtTime $tm]
   }
}

#------------------------------------------------------------------------------
#  Return a standard string time
#------------------------------------------------------------------------------
proc db::txtTime {tm} {
   return [clock format $tm -format {%Y-%m-%d  %H:%M}]
}

#############################UNUSED OR MANUALLY USED #################################
#----------------------------------------------------------------------------
# Return a list of files that are missing
#----------------------------------------------------------------------------
proc db::notExist {args} {
   variable DB
   variable dbObj
   return [lmap row [mk::select $DB -exact Exists 0 -exact Mounted 0 -rsort Sctime] {$dbObj get $row File}]

}
#---------------------------------------------------------------------------- 
# Force sync the text times with the actual times
#---------------------------------------------------------------------------- 
proc db::syncTime {args} {
   variable DB
   variable dbObj
   set count 0
   foreach {row} [mk::select $DB] {
      lassign [$dbObj get $row Ftime Sctime] ft st
      $dbObj set $row stFtime [txtTime $ft] stSctime [txtTime $st]
   }
}
#---------------------------------------------------------------------------- 
# Manual use only , play with select to clean out cruft
#---------------------------------------------------------------------------- 
proc db::delNotMounted {args} {
   variable dbObj
   variable DB
   set rows [lsort -integer -decreasing [mk::select $DB -exact Exists 0]]
   foreach row $rows {
      $dbObj delete $row
   }
   return [llength $rows]
}

#----------------------------------------------------------------------------
# Remove a branch from the database, work backwards
#----------------------------------------------------------------------------
proc db::clearDatabase {pattern} {
   variable dbObj
   variable DB
   set rows [lsort -integer -decreasing [mk::select $DB -glob File $pattern]]
   foreach row $rows {
      $dbObj delete $row
   }
   return [llength $rows]
}

#----------------------------------------------------------------------------
# Verify that each Exists file exists, if not then remove from the database.
#----------------------------------------------------------------------------
proc db::verifyFiles {pattern} {
   variable dbObj
   variable DB
   set rows [lsort -integer -decreasing [mk::select $DB -glob File $pattern -exact Mounted 1]]
   set i 0
   set removed 0
   foreach {row} $rows {
      set File [$dbObj get $row File]
      update
      if {![file exists $File]} {
         $dbObj delete $row ;# Make sure row indicies work here
         incr i
      } else {
#debug "File:$File"
      }
   }
   return  $i
}
#----------------------------------------------------------------------------
# Remove entries flagged without any particular icon
#----------------------------------------------------------------------------
proc db::purgeEverything {args} {
   variable dbObj
   variable DB
   #remove oldest first
   set rows [lsort -integer -decreasing [mk::select $DB -exact IconType "+everything+"]]
   foreach row $rows {
      set File [$dbObj get $row File]
      log $File
      $dbObj delete $row
   }
   mk::file commit db
   return [llength $rows]
}
#---------------------------------------------------------------------------- 
# Return true if the database exists
#---------------------------------------------------------------------------- 
proc db::exists {args} {
   variable dbLocation
   return [file exists $dbLocation]
}
######################################################################################

package provide rdtMetakit 1.0

