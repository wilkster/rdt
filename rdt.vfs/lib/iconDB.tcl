#---------------------------------------------------------------------------- 
# Icon database/hash for mapping
#---------------------------------------------------------------------------- 
namespace eval iconDB {
   # mapping of extension to type
   variable extToType
   # mapping of extenion|type to image name
   variable extToImage
}
#------------------------------------------------------------------------------
# Create all of the icon types based on the icon bar
# TODO: Support ! or ~ function for extensions in settings, i.e. ignore those patterns
# Called after scan is complete, database should have all files in it
#------------------------------------------------------------------------------
proc iconDB::setupTypes {args} {
   variable extToType
   unset -nocomplain extToType
   # Make sure database syncs with changes to extensions
   # Preload the extensions from the user settings
   foreach {iconName} [lsort [S::getTrayIcons]] {
      lassign [S::getTrayIconData $iconName] show iconFile iconExts
      foreach {iconExt} $iconExts {
         # just set the hash
         incr extHash($iconExt)
      }
   }
   # Include a unique list of all the extensions in the database appended to the hash
   db::getTypes extHash
   # extHash is now a list of all possible extensions (including wildcards) specified by the user or found n the database
   if {[array size extHash] == 0} {
      log "No database entries available yet to create icon types for"
   }
   # Create a mapping from each icons to the extensions mapped to it
   # Support wildcards in the icon iconExt definitions
   foreach {iconName} [lsort [S::getTrayIcons]] {
      lassign [S::getTrayIconData $iconName] show iconFile iconExts
      set icn  "+${iconName}+"
      # for each extension in that icon (can contain wildcards)
      foreach {iconExt} $iconExts {
         # if iconExt is a wildcard, add to those extensions as well
         append extToType($iconExt) $icn
         # iconExt can have wildcards, for all existing files in database handle their extension
         foreach {fileExt} [array names extHash $iconExt] {
            if {![info exists extToType($fileExt)]} {
               set extToType($fileExt) $icn
            } elseif {[string first $icn $extToType($fileExt)] < 0} {
               append extToType($fileExt) $icn
            }
         }
      }
   }
   # Update the database with this data
   db::setTypes iconDB::extToType
   # not implemented
   #db::setIcons
}
#------------------------------------------------------------------------------
# Clear out old types
#------------------------------------------------------------------------------
proc iconDB::clearTypes {args} {
   variable extToType
   unset -nocomplain extToType
}
#----------------------------------------------------------------------------
# Return an icon type (these two only called during new file caching)
#----------------------------------------------------------------------------
proc iconDB::nameToType {name isDir} {
   variable extToType
   #get the type
   if {$isDir == 1 || $isDir eq "folder"} {
      return "folder"
   } else {
      set ext [fileExt $name]
      if {[iconDB::typeExists $ext]} {
         return $extToType($ext)
      } else {
         # must be a new extension not seen before
         # see if one of the icon extensions, as a pattern, match this extension and add it if so
         set st ""
         foreach {iconExt} [array names extToType] {
            # if (xl* match xls) for example
            # the longest string will most likely match the most icons (better to count +'s)
            if {[string match $iconExt $ext]} {
               set stt $extToType($iconExt)
               if {[string length $stt] > [string length $st]} {
                  set st $stt
               }
            }
         }
         # if no match just assume everything
         if {$st eq ""} {
            set st "+everything+"
         }   
         # save the new extension
         set extToType($ext) $st
         #update the database entry
         db::setVal $name IconType $st
         return $st
      }
   }
}

#------------------------------------------------------------------------------
# get a glob pattern for monitoring (as a list)
#------------------------------------------------------------------------------
proc iconDB::getGlobList {Icon} {
   # Return the speficied patterns, not all the ones captured
   set gPat [list]
   foreach {type} [S::getTrayIcons] {
      if {[string equal -nocase $type $Icon]} {
         lassign [S::getTrayIconData $type] x xx iconExts
         foreach {ext} $iconExts {
            lappend gPat *.$ext
         }
      }
   }
   return $gPat
}
#------------------------------------------------------------------------------
# get a glob pattern between commas for glob
#------------------------------------------------------------------------------
proc iconDB::getGlobber {Icon} {
   return \{[join [getGlobList $Icon] ","]\}
}

#----------------------------------------------------------------------------
# See if the mapping for some extension exists
#----------------------------------------------------------------------------
proc iconDB::typeExists {ext} {
   variable extToType
   if {![info exists extToType($ext)] || $extToType($ext) eq ""} {
      return 0
   } else {
      return 1
   }
}
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#----------------------------------------------------------------------------
# Return the icon for this file, look it up in the file if needed and cache it
#----------------------------------------------------------------------------
proc iconDB::nameToIcon {name isDir} {
   variable extToImage
   if {$isDir} {
      # would be nice to return the native folder icon, esp if is overwritten, but it isn't efficient
      return $extToImage(folder)
   } else {
      set ext [fileExt $name]
      if {![iconExists $ext]} {
         set extToImage($ext) [getShellIcon $name]
      }
      return $extToImage($ext)
   }
}

#------------------------------------------------------------------------------
# Be smart about reading an icon from a file
#------------------------------------------------------------------------------
proc iconDB::readIconFile {file} {
   variable extToImage
   try {
      #set h [shellicon::get $file]
      # use this instead of shell icon (which also works but won't throw an error)
      set h [::ico::getFileIcon $file -res 16]
   } on error result {
      try {
         # try shell icon if we got an error
         set h [getShellIcon $file]
      } on error result {
         logerr $result
         set h $extToImage(rdt) 
      }
   }
   return $h
}
#------------------------------------------------------------------------------
# Create an icon from an image file
#------------------------------------------------------------------------------
# proc winTaskBar::writeIcon {image file} {
#    variable extToImage
#    try {
#       ::ico::writeIcon $file 0 32 $image
#    } on error result {
#       logerr $result
#    }
# }

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Add an extension to tcl image lookup
#------------------------------------------------------------------------------
proc iconDB::extToIcon {ext} {
   variable extToImage
   if {[info exists extToImage($ext)]} {
      return $extToImage($ext)
   } else {
      return $extToImage(rdt)
   }
}
#------------------------------------------------------------------------------
# Add an extension to tcl image lookup
# assumes a new one was created just before
#------------------------------------------------------------------------------
proc iconDB::addIcon {ext img} {
   variable extToImage
   # remove any existing images if the are different
   if {[info exists extToImage($ext)]} {
      try {
         if {$img ne $extToImage($ext)} {
            image delete $extToImage($ext)
         }
      } on error result {
         logerr $result   
      }
   }
   set extToImage($ext) $img
}
#------------------------------------------------------------------------------
# Indicate whether an icon exists for some type
#------------------------------------------------------------------------------
proc iconDB::iconExists {ext} {
   variable extToImage
   return [expr {[info exists extToImage($ext)] && ($extToImage($ext) ne "")}]
}
#------------------------------------------------------------------------------
#  Save the icon image cache
#------------------------------------------------------------------------------
proc iconDB::saveDB {iconDB} {
   variable extToImage
   foreach {img h} [array get extToImage] {
      set Icons($img) [$h data -format png]
      image delete $h
   }
   try {
      set fod [open $iconDB w] 
      fconfigure $fod -translation binary
      puts $fod [array get Icons]
   } on error result {
      logerr $result   
   } finally {
      close $fod
   }
}
#------------------------------------------------------------------------------
#  Restore the icon database from a settings file
#------------------------------------------------------------------------------
proc iconDB::restoreDB {iconDB} {
   variable extToImage
   if {[file exists $iconDB]} {
      try {
         set fid [open $iconDB r]
         fconfigure $fid -translation binary
         array set Icons [read $fid]
         foreach {img h} [array get Icons] {
            #rebuild the image from the data
            try {
               set extToImage($img) [image create photo -data $h]
            } on error result {
               log "note: $img->$result"   
            }
         }
      } on error result {
         log "note: $result"   
      } finally {
         close $fid
      }
   } else {
      log "$iconDB does not exist - not an issue"
   }
}
#----------------------------------------------------------------------------
# Cache the default icons, including special menu icons
# Generally called once upon initialization
#----------------------------------------------------------------------------
proc iconDB::cacheIcons {args} {
   # Cache the file icons and types
   # since image names are not persistant between runs, we
   # must recreate them all, but hold them also in a extToImage hash file
   foreach row [db::fileListRows * 0] {
      set File [db::getValbyRow $row "File"]
      # look for match pattern if not directly exists
      set ext [fileExt $File]

      # is there an imagexx already for this file extension?
      # if not, create one.
      # like: iconDB::nameToIcon, called from hashShortcut
      if {![iconExists $ext]} {
         set imgx [getShellIcon $File]
         addIcon $ext $imgx
       }
   }
}
#----------------------------------------------------------------------------
# Initialze the icons and build callbacks for taskbar icons
# This whole function can be replaced from a config file/gui
#----------------------------------------------------------------------------
# todo, split into two parts
# 2. Then read user settings and append/replace by hash
# 3. Then loop over the settings and create the icon images and taskbar icons
#
proc iconDB::loadPngFiles {folders} {
   variable extToImage
   foreach {folder} $folders {
      #
      # Icons for menus, these are not for file type but custom menus (not a user setting)
      # User can override these, so we don't used cached version
      #
      foreach pngFile [lsort [glob -nocomplain -directory $folder "*.png"]] {
         set imgName [string tolower [file tail [file rootname $pngFile]]]
         # Remove any existing images to allow overwriting them by user
         addIcon $imgName [image create photo -file $pngFile]
      }
   }
}

#
# Clear out the image cache
#
proc iconDB::clearIconData {args} {
   variable extToImage
   foreach {ext img} [array get extToImage] {
      image delete $img
      unset extToImage($ext)
   }
}

package provide iconDB 1.0
