#------------------------------------------------------------------------------
# Support functions for windows based icons
# Mostly copied from winico.tcl part of winico package
#------------------------------------------------------------------------------
if {$::tcl_platform(platform)=="windows"} {
   if {[catch {package require Winico} result]} {
      puts "No built-in or available Winco, using local DLL"
      load [file join [file dirname [info script]] myWinico winico.dll]
   }
}
#------------------------------------------------------------------------------
# Function   : winTaskBar::init
# Description: Add icons in taskbar for Windows
# Author     : Tom Wilkason
# Date       : 1/9/2001
#------------------------------------------------------------------------------
namespace eval winTaskBar {
   variable iconDef
   variable fileTypes [list]
   variable iconTypes
   variable icons
   variable lastx
   variable lasty
   # mapping of extenion|type to image name
   variable iconTypes
   variable trayIcons
   variable priorIcon ""
   # mapping of extension to type
   variable extToType

}
#----------------------------------------------------------------------------
# Initialze the icons and build callbacks for taskbar icons
#----------------------------------------------------------------------------
proc winTaskBar::init {folders} {
   variable iconDef
   variable fileTypes
   variable iconTypes
   variable icons
   variable trayIcons
   variable extToType

   try {
      foreach {folder} $folders {
         # Icons for menus
         foreach iconFile [lsort [glob -nocomplain -directory $folder "*.png"]] {
            set icon [string tolower [file tail [file rootname $iconFile]]]
            winTaskBar::addIcon $icon [image create photo -file $iconFile]
         }
         # Icons for the taskbar, extract image for settings as well
         #format : "name ext1 ext2 ..."
         foreach iconFile [lsort [glob -nocomplain -directory $folder "*.ico"]] {
            set iconset [string tolower [file tail [file rootname $iconFile]]]
            set icon [lindex $iconset 0] ;# type
            # skip built in tclkit icon
            if {$icon eq "tclkit"} {
               continue
            }
            # Get icon for the settings menu (only reads generic icon)
            try {
               winTaskBar::addIcon $icon [ico::getIcon $iconFile 0]
            } on error result {
               logerr $result
               winTaskBar::addIcon $icon $iconTypes(rdt)
            }
            # map each extension to the icon type
            foreach {item} [lrange $iconset 1 end] {
               set extToType($item) $icon
            }
            # Create an icon to possibly show in taskbar
            try {
               set Icon [winico create $iconFile]
               set trayIcons($icon) $Icon
            } on error result {
               logerr $result
            }
            # restore state from settings
            set icons($icon)  [S::getIconState $icon]
            lappend fileTypes $icon

            set iconDef($Icon) "Recent $icon files\nLeft Button for list\nRight Button search"
            # Add the task bar icons (if enabled from settings)
            winTaskBar::TrayToggle $icon icons($icon)
            # menu to attach to the icon
            menu .$icon \
               -postcommand [list winTaskBar::postMenu $icon] \
               -tearoff 0
            # cascade setting menus for RMB
            menu .$icon.type -tearoff 0
            # settings cascade
            menu .$icon.settings          -tearoff 0
            menu .$icon.settings.type     -tearoff 0
            menu .$icon.settings.limitNum -tearoff 0
            menu .$icon.settings.age      -tearoff 0

         }
      }
   } on error result {
      debug $result
   }
   # update metakit of all the icon states
   winTaskBar::cacheIcons
}
#----------------------------------------------------------------------------
# Return an icon type (these two only called during file caching)
#----------------------------------------------------------------------------
proc winTaskBar::getAnType {name isDir} {
   variable extToType
   #get the type
   if {$isDir} {
      return "folder"
   } else {
      set ext [fileExt $name]
      if {[winTaskBar::typeExists $ext]} {
         return $extToType($ext)
      } else {
         return "Other"
      }
   }
 }
#----------------------------------------------------------------------------
# Return the icon for this file, look it up in the file if needed and cache it
#----------------------------------------------------------------------------
proc winTaskBar::getAnIcon {name isDir} {
   variable iconTypes
   if {$isDir} {
      return $iconTypes(folder)
   } else {
      set ext [fileExt $name]
      if {![iconExists $ext]} {
         # call the helper routine
         set iconTypes($ext) [getIcon $name]
      }
      return $iconTypes($ext)
   }
}

#------------------------------------------------------------------------------
# Indicate whether an icon exists for some type
#------------------------------------------------------------------------------
proc winTaskBar::iconExists {ext} {
   variable iconTypes
   if {![info exists iconTypes($ext)] || $iconTypes($ext) eq ""} {
      return 0
   } else {
      return 1
   }
}
#---------------------------------------------------------------------------- 
# See if the mapping for some extension exists
#---------------------------------------------------------------------------- 
proc winTaskBar::typeExists {ext} {
   variable extToType
   if {![info exists extToType($ext)] || $extToType($ext) eq ""} {
      return 0
   } else {
      return 1
   }
}
#------------------------------------------------------------------------------
# Indicate whether an icon exists for some type
#------------------------------------------------------------------------------
proc winTaskBar::addIcon {ext icon} {
   variable iconTypes
   set iconTypes($ext) $icon
}
#----------------------------------------------------------------------------
# Cache the default icons, including special menu icons
#----------------------------------------------------------------------------
proc winTaskBar::cacheIcons {args} {
   variable iconTypes
   variable extToType
   # Cache the folder icons and types
   foreach hashSet [db::fileList * 1] {
      lassign $hashSet name sdate mdate mounted img hits
      db::setVal $name IconType "folder"
      db::setVal $name Image $iconTypes(folder)
   }
   # Cache the file icons and types
   foreach hashSet [db::fileList * 0] {
      lassign $hashSet name sdate mdate mounted img hits
      # look for match pattern if not directly exists
      set ext [fileExt $name]

      # check for pinned and filtered here and set icon?? or do it a populate time?

      if {[winTaskBar::typeExists $ext]} {
         db::setVal $name IconType $extToType($ext)
      } else {
         db::setVal $name IconType "Other"
      }
      if {![winTaskBar::iconExists $ext]} {
         set img [getIcon $name]
         set iconTypes($ext) $img
         db::setVal $name Image $img
      }  else {
         db::setVal $name Image $iconTypes($ext)
      }
   }
}

#------------------------------------------------------------------------------
# Build the settings menu
#------------------------------------------------------------------------------
proc winTaskBar::buildSettingMenu {Menu} {
   variable lastCommand
   variable iconTypes
   variable icons

   set state [console eval {wm state .}]

   $Menu delete 0 end
   if {$state eq "normal"} {
      $Menu add command -label "Hide Console" -command "console hide" \
      -compound left -image $iconTypes(console)
   } else {
      $Menu add command -label "Show Console" -command "console show" \
      -compound left -image $iconTypes(console)
   }
   $Menu add command -label "Rescan Shortcuts" -command rdt::restart \
      -compound left -image $iconTypes(scan)
   $Menu add command -label "Clear Shortcuts" -command rdt::resetSettings \
      -compound left -image $iconTypes(erase)

   $Menu add separator
   # Cascade Menu for settings
   $Menu add command -label "Trim Database for Deleted Targets" -command [list rdt::bgCheckFile 1]
   $Menu add checkbutton -variable S::S(deleteDead) -label "Delete Shortcuts when Target Missing"
   $Menu add checkbutton -variable S::S(deleteStale) -label "Background Trim Database for Deleted Targets"
   $Menu add checkbutton -variable S::S(hashFolder) -label "Track Folders for all File Targets"
   $Menu add checkbutton -variable S::S(myRecent) -label "Copy shortcuts to .rdt/rdtRecent folder"
   # can this be done once during init and reused?
   $Menu.limitNum delete 0 end
   foreach {num} {5 10 15 25 30 35 40 50 60} {
      $Menu.limitNum add radiobutton -value $num -label $num -variable S::S(limit)
   }
   $Menu.age delete 0 end
   foreach {num} {7 14 30 60 90 120 180 365 never} {
      $Menu.age add radiobutton -value $num -label $num -variable S::S(age) \
      -command rdt::purgeOld
   }

   
   $Menu add cascade  -label "Limit Entries to..." -menu $Menu.limitNum \
      -compound left -image $iconTypes(limit)
   $Menu add cascade  -label "Remove Entries older than (days)..." -menu $Menu.age \
      -compound left -image $iconTypes(clock)
   # assumes submenu type already created (which they are in init)
   $Menu.type delete 0 end
   $Menu add cascade  -label "Include File Types..." -menu $Menu.type \
     -compound left  -image $iconTypes(filter)

   foreach {icon} [array names icons] {
      #dynamically turn on/off icons rather than require a restart
      if {[winTaskBar::iconExists $icon]} {
         $Menu.type add checkbutton -compound left -image $iconTypes($icon) \
            -label $icon -variable winTaskBar::icons($icon) \
            -command [list winTaskBar::TrayToggle $icon winTaskBar::icons($icon)]
      } else {
         $Menu.type add checkbutton -label $icon -variable winTaskBar::icons($icon) \
            -command [list winTaskBar::TrayToggle $icon winTaskBar::icons($icon)]
      }
   }
   $Menu add separator
   $Menu add command -label "About" -command "rdt::About" \
      -compound left -image $iconTypes(about)

   $Menu add command -label "Exit RDT" -command "rdt::unload" \
      -compound left -image $iconTypes(exit)
   return $Menu

}
#------------------------------------------------------------------------------
# post command that is called when the .$icon menus are posted
# todo split this up and call at a higher level
#------------------------------------------------------------------------------
proc winTaskBar::postMenu {icon} {
#puts "postMenu $icon"
   variable lastCommand
   variable iconTypes
   variable icons
   variable priorIcon
   #-------------------------
   #-------------------------
   set Menu .$icon
   if {$lastCommand eq "WM_RBUTTONDOWN"} {
 #     buildSettingMenu $Menu
      #$Menu unpost
      if {[treeSearch::isOpen]} {
         treeSearch::unload
         # open a new window if different
         if {$icon ne $priorIcon} {
            if {$icon eq "folder"} {
               treeSearch::launch * 1 $icon
            } else {
               treeSearch::launch "$icon" 0 $icon
            }
            set priorIcon $icon
         } else {
            # remain closed
            set priorIcon ""
         }
      } else {
         # was closed, open new window
         if {$icon eq "folder"} {
            treeSearch::launch * 1 $icon
         } else {
            treeSearch::launch "$icon*" 0 $icon
         }
         set priorIcon $icon
      }

   } elseif {$lastCommand eq "WM_LBUTTONDOWN"} {
      if {[treeSearch::isOpen]} {
         treeSearch::unload
      }
      # Create threholds at yesterday, last week, last month
      set n [clock seconds]
      set sow [clock add $n -[clock format $n -format %u] days]
      set yest [clock add $n -1 days]
      # make sure no leading 0's in day of month
      scan [clock format $n -format %d] %d dom
      set som [clock add $n -$dom days]
      set thresholds [lsort -decreasing -integer [list $yest $sow $som]]
      $Menu delete 0 end
      set menuList [list]
      # handle either folder or file type differently
      # todo: insert pinned items at the top
      if {$icon eq "folder"} {
         set isFolder 1
         set pinList [db::menuList "*" 1 1]
         set menuList [db::menuList "*" 1 0]
      } else {
         set isFolder 0
         set pinList [db::menuList $icon 0 1]
         set menuList [db::menuList $icon 0 0]
      }
      set counter 0
      foreach hashSet $menuList {
         lassign $hashSet name sdate fdate mounted img
         ;# separators based on time
         if {[llength $thresholds]} {
            if {$sdate < [lindex $thresholds 0]} {
               $Menu add separator
               lpop left thresholds
               # handle multiple crosses (e.g. at beginning of week or month)
               while {$sdate < [lindex $thresholds 0] && [llength $thresholds]} {
                  lpop left thresholds
               }
            }
         }

         addItem $Menu $icon $isFolder $hashSet $img 0

         #tooltip::tooltip $Menu -index $label $name
         # Limit results on the menu
         if {[incr counter] > $S::S(limit)} {
            break
         }
      }
      # Scan through entire hash and build entries
      if {[llength $pinList] > 0} {
         $Menu add separator
      }
      foreach hashSet $pinList {
         #pinned items
         addItem $Menu "pinned" $isFolder $hashSet $img 1
      }
      $Menu add separator
      # Settings menu (created during init)
      $Menu add cascade -label "Settings" -menu $Menu.settings \
         -compound left -image $winTaskBar::iconTypes(settings)
      $Menu.settings configure \
         -postcommand [list winTaskBar::buildSettingMenu $Menu.settings]

      if {$isFolder} {
         $Menu add command \
            -label "Search Dialog" \
            -command [list treeSearch::launch * $isFolder $icon] \
            -compound left -image $iconTypes(search)
      } else {
         $Menu add command \
            -label "Search Dialog" \
            -command [list treeSearch::launch "*.${icon}*" $isFolder $icon] \
            -compound left -image $iconTypes(search)
      }
   } else {
      # some other command
   }
}
#------------------------------------------------------------------------------
# Enable / disable icon in task bar
#------------------------------------------------------------------------------
proc winTaskBar::TrayToggle {icon _var} {
   upvar $_var state
   variable trayIcons
   variable iconDef
   set Icon $trayIcons($icon)
   # save setting for restore
   S::setIconState $icon $state
   if {$state} {
      # icon should have 1 16x16 icon at 32BPP in it
      winico taskbar add $Icon \
         -callback [list winTaskBar::Callback %m $Icon [list winTaskBar::postIconMenu $icon %m %x %y]] \
         -text $iconDef($Icon)
   } else {
      winico taskbar delete $Icon
   }
}
#------------------------------------------------------------------------------
#  Add an item to the menu, folder or file
#------------------------------------------------------------------------------
proc winTaskBar::addItem {Menu icon isFolder hashSet img pinned} {
   variable iconTypes
   lassign $hashSet name sdate fdate mounted
   ##
   # Folder gets a slightly different menu
   #
   if {$isFolder} {
#            set label "[clock format $sdate -format {%D %H:%M:%S}]   $name"
      set label "[clock format $sdate -format {%D}]   $name"
      set ext "folder"
   } else {
      set folder [file tail [file dirname $name]]
      set ext [fileExt $name]
      set file [file tail $name]
      if {$rdt::hideExt} {
         set file [file rootname $file]
      }
#            set label "[clock format $fdate -format {%D %H:%M:%S}]    $file   ($folder)"
      set label "[clock format $fdate -format {%D}]    $file   ($folder)"
   }
   # Add a document type icon if one is available
   if {$mounted} {
      set state "normal"
   } else {
      set state "disabled"
   }
   #icon should be based on ext, not on icon
   if {$pinned} {
      $Menu add command \
         -label $label -state $state \
         -compound left -image $iconTypes(pinned) \
         -command [list rdt::launch $name]

   } elseif {$img ne ""} {
      $Menu add command \
         -label $label -state $state \
         -compound left -image $img \
         -command [list rdt::launch $name]
   } else {
      $Menu add command \
         -label $label -state $state\
         -command [list rdt::launch $name]
   }
   #tooltip::tooltip $Menu -index $label "This is some help for $name"
}
#----------------------------------------------------------------------------
# Called from winTaskBar::Callback
# type is file type, m is command, x/y is mouse location
#----------------------------------------------------------------------------
proc winTaskBar::postIconMenu {type m x y} {
   variable lastx $x
   variable lasty $y
#puts "postIconMenu $type $m $x $y"
   switch -- $m {
      "WM_LBUTTONDOWN" {
         # this will call the postMenu command bound to the icon
         # triggers the postMenu event
         .$type post $x $y
      }
      "WM_RBUTTONDOWN" {
         # don't post the menu, launch the search box
         winTaskBar::postMenu $type
      }
      default {}
   }
}
#----------------------------------------------------------------------------
# Callback fired when mouse over or clicked on one of the icons (windows only)
# order is as follows
# Callback WM_LBUTTONDOWN ico#4 winTaskBar::postIconMenu mp WM_LBUTTONDOWN 2241 1578
# ->postIconMenu mp WM_LBUTTONDOWN 2241 1578
# -->postMenu mp (not for search)
#----------------------------------------------------------------------------
proc winTaskBar::Callback {message icon command args} {
   # Todo, handle volume control on certain button, can even do a winicon taskbar modify $icon ...
   #winTaskBar::postIconMenu ppt WM_LBUTTONDOWN 1577 1180
   variable lastx
   variable lasty
   variable lastCommand
   set lastCommand $message
   switch -- $message {
      WM_LBUTTONDOWN {
#puts "Callback $message $icon $command $args"
         eval $command
      }
      WM_LBUTTONUP {}
      WM_MOUSEMOVE {
      }
      WM_RBUTTONUP {}
      WM_RBUTTONDOWN {
#puts "Callback $message $icon $command $args"
         eval $command
      }
      default {}
   }
}
proc K {a b} {set a}
##
# Pop an item off a list, left or right
#
proc lpop {how listName} {
   upvar $listName list
   switch -- $how {
      "right" {
         K [lindex $list end] [set list [lrange $list 0 end-1]]
      }
      "left" {
         K [lindex $list 0] [set list [lrange $list 1 end]]
      }
      default {
         return -code error "lpop right|left listName"
      }
   }
}
##
# Pop an item onto a list, left or right
#
proc lpush {how listName item} {
   upvar $listName list
   switch -- $how {
      "right" {
         lappend list $item
      }
      "left" {
         set list [linsert [K $list [set list ""]] 0 $item]
      }
      default {
         return -code error "lpush right|left listName item"
      }
   }
}

package provide IconSupport 1.0
#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
proc test {args} {
   treeSearch::launch * 0

}
# check the number of missing
proc winTaskBar::check {args} {
   variable iconDef
   variable fileTypes
   variable iconTypes
   variable icons
   variable trayIcons
   variable extToType
   foreach {hashSet} [db::fileList * 0] {
      lassign $hashSet name sdate mdate mounted img hits
      set ext [fileExt $name]
      if {![info exists extToType($ext)]} {
         incr missing($ext)
      }
   }
   foreach {ext} [array names missing] {
      debug "$ext=$missing($ext)"
   }
}



