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
   variable dbLocation [file nativename [file join $::env(USERPROFILE) ".rdt" "rdt.mk"]]
   variable fieldSpec [list File Folder Ext IsFolder:I Ftime:I Sctime:I Mounted:I Hits:I Pinned:I Excluded:I IconType Image]
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
# Return a list of file in a tree sorted by shortcut access time
# used to populate a menu
# filtered by file extension
#----------------------------------------------------------------------------
proc db::menuList {pattern isfolder {pinned ""}} {
   variable DB
   variable dbObj
   set result [list]
   if {$pinned ne ""} {
      foreach {row} [mk::select $DB -globnc IconType $pattern -exact Excluded 0 -exact Pinned $pinned -exact IsFolder $isfolder -rsort Sctime] {
         lappend result [$dbObj get $row File Sctime Ftime Mounted]
      }
   }  else {
      foreach {row} [mk::select $DB -globnc IconType $pattern -exact Excluded 0 -exact IsFolder $isfolder -rsort Sctime] {
         lappend result [$dbObj get $row File Sctime Ftime Mounted]
      }
   }
   return $result
}
#----------------------------------------------------------------------------
# Return a list of files in a tree sorted by shortcut access time
# used to populate a menu
# filtered by file name
#----------------------------------------------------------------------------
proc db::fileList {pattern isfolder {type ""}} {
   variable DB
   variable dbObj
   set result [list]
   if {$type ne ""} {
      foreach {row} [mk::select $DB -globnc File $pattern -globnc IconType $type -exact IsFolder $isfolder -rsort Sctime] {
         lappend result [$dbObj get $row File Sctime Ftime Mounted Pinned Excluded Hits]
      }
   } else {
      foreach {row} [mk::select $DB -globnc File $pattern -exact IsFolder $isfolder -rsort Sctime] {
         lappend result [$dbObj get $row File Sctime Ftime Mounted Pinned Excluded Hits]
      }
   }
   return $result
}

#----------------------------------------------------------------------------
;# Cache a single file name looking up info for it
;# If it exists, just check/update the access time (sctime)
#----------------------------------------------------------------------------
proc db::cacheFile {File sctime type} {
   variable checkTime
   variable dbObj
   ;# If file not in db, then cache just basic part
   if {[catch {$dbObj find File $File} row] } then {
      #not found
      if {[catch {file mtime $File} ftime]} {
         debug $ftime
         return -1
      } else {

         set row [$dbObj size]
         $dbObj insert end \
            Ext      [file extension $File]  \
            File     $File        \
            Folder   [file dirname $File] \
            isFolder [file isdirectory $File] \
            Ftime     $ftime \
            Mounted  1        \
            Hits     1        \
            Pinned   0        \
            Sctime    $sctime \
            IconType  $type
      }
      return $row
   } else {
      # update access time and hit count if incoming is greater
      lassign [$dbObj get $row Sctime Hits] esctime hits
      if {$sctime > $esctime} {
         if {[catch {file mtime $File} ftime]} {
            debug $ftime
            $dbObj set $row Sctime $sctime Hits [incr hits]
         } else {
            $dbObj set $row Sctime $sctime Ftime $ftime Hits [incr hits]
         }
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
   if {[catch {$dbObj find File $File} row] } then {
      return ""
   }
   $dbObj set $row $Field $val
   return $val
}
#----------------------------------------------------------------------------
# get a value
#----------------------------------------------------------------------------
proc db::getVal {File Field} {
   variable dbObj
   variable mods
   if {[catch {$dbObj find File $File} row] } then {
      return ""
   }
   set val [$dbObj get $row $Field]
   return $val
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
# Close the database
#----------------------------------------------------------------------------
proc db::closeDB {args} {
   mk::file commit db
   mk::file close db
}
#----------------------------------------------------------------------------
# Remove entries older than "days" old in database
#----------------------------------------------------------------------------
proc db::purgeOld {daysAgo} {
   variable dbObj
   variable DB
   set rows [lsort -integer -decreasing [mk::select $DB -max Sctime $daysAgo]]
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
#================= U N U S E D ==============================================
proc db::exists {args} {
   variable dbLocation
   return [file exists $dbLocation]
}
#----------------------------------------------------------------------------
# Verify that each Mounted file exists, if not then remove from the database.
#----------------------------------------------------------------------------
proc db::verifyFiles {pattern} {
   variable dbObj
   variable DB
   set rows [lsort -integer -decreasing [mk::select $DB -glob File $pattern]]
   set i 0
   set removed 0
   foreach {row} $rows {
      set File [$dbObj get $row File]
      update
      if {![file exists $File]} {
         $dbObj delete $row ;# Make sure row indicies work here
         incr i
      }
   }
   return  $i
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
# Function   : db::Commit
# Description: Flush the data after cataloging
# Author     : Tom Wilkason
# Date       : 1/7/2001
#----------------------------------------------------------------------------
proc db::Commit {} {
   mk::file commit db
}
#----------------------------------------------------------------------------
# Return the number of tracks indexed
# Note: Should limit to media folders
#----------------------------------------------------------------------------
proc db::numTracks {args} {
   variable dbObj
   return [$dbObj size]
}


package provide rdtMetakit 1.0

