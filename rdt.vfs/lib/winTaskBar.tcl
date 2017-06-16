#------------------------------------------------------------------------------
# Function   : winTaskBar::init
# Description: Add icons in taskbar for Windows
# Author     : Tom Wilkason
# Date       : 1/9/2001
#------------------------------------------------------------------------------
namespace eval winTaskBar {
   variable priorIcon ""
   variable sendTo [list]
   variable Com
   variable lastIcon
   array set Com {
      excel      {Excel.Application WorkBooks FullName}
      powerpoint {Powerpoint.Application Presentations FullName}
      word       {Word.Application Documents FullName}
      project    {MSProject.Application Projects FullName}
      visio      {Visor.Application Documents FullName}
      publisher  {Publisher.Application Documents FullName}
   }

}
#------------------------------------------------------------------------------
#  Return a color for open files
#------------------------------------------------------------------------------
proc winTaskBar::menuOpenColor {isOpen} {
   if {$isOpen} {
      return "blue"
   } else {
      return "black"
   }
}
#---------------------------------------------------------------------------- 
# Initialze or re-initialize the icon tray
# TODO: support changing icon name
#---------------------------------------------------------------------------- 
proc winTaskBar::initTray {args} {
   variable sendTo
   set totalChanges 0
   try {
      #remove any existing icons first
      iconDB::clearTypes
      # Icons for the taskbar, extract image for settings as well (user setting)
      # create icon instance if they don't exist
      foreach {iconName} [lsort [S::getTrayIcons]] {
         lassign [S::getTrayIconData $iconName] show iconFile iconExts
         if {[info command ::cL$iconName] ne ""} {
            ::cL$iconName sync $show $iconFile $iconExts
         } else {
            ClsTrayIcon ::cL$iconName $iconName $show $iconFile $iconExts $S::Tip($S::S(SwapButton))
         }
         # Make sure we have a copy of the icon image for other uses
         iconDB::addIcon $iconName [::cL$iconName image]
      }
      # Icon was removed (deleted)
      foreach {iconName} [lsort [S::getSavedTrayIcons]] {
         lassign [S::getTrayIconData $iconName] check xx xx
         if {$check eq ""} {
            delete object ::cL$iconName
         }
      }
      # Make sure database syncs with changes to extensions
      iconDB::setupTypes
      S::saveIcons
   } on error result {
      logerr "winTaskBar::initTray $result"
   }
}

#------------------------------------------------------------------------------
#  Build entries for Send To menu
#------------------------------------------------------------------------------
proc winTaskBar::initSendTo {args} {
   variable sendTo
   set sendTo [list]
   # build up the extra send to menus for the RMB
   set sendTos [glob -nocomplain -directory [twapi::get_shell_folder CSIDL_SENDTO] "*.lnk"]
   foreach {shortcut} $sendTos {
      try {
         set shortcut [file nativename $shortcut]
         array set sendSC [twapi::read_shortcut $shortcut -nosearch -noui -timeout 500] ;# keyed li
#log "$shortcut -> $sendSC(-path)"
         set img [getShellIcon $sendSC(-path)]
         if {$img ne ""} {
            # launch the shortcut itself vs the target (shouldn't matter)
            lappend sendTo [list [file rootname [file tail $shortcut]] $shortcut $img]
            #lappend sendTo [list [file rootname [file tail $shortcut]] $sendSC(-path) $img]
         }
      } on error result {
         logerr $result
      }
   }
}
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
package require iconDB
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#------------------------------------------------------------------------------
# Build the settings menu
#------------------------------------------------------------------------------
proc winTaskBar::buildSettingMenu {Menu} {
   set state [console eval {wm state .}]
#----------------------------------TOP ICONS -----------------------------------------
   $Menu delete 0 end
   $Menu add command -label "Manage Tray Icons..." \
      -command S::settingsGUI \
      -compound left -image [iconDB::extToIcon "filter"]
   $Menu add command -label "Manage Folder Monitoring..." \
      -command fileScan::Gui \
      -compound left -image [iconDB::extToIcon "monitor"]
   $Menu add separator
   $Menu add command -label "Remove stale entries now" \
      -command rdt::clearMissing \
      -compound left -image [iconDB::extToIcon erase]

   $Menu add command -label "Select folder to add $winTaskBar::lastIcon files to database" \
      -command [list fileScan::scanFolder winTaskBar::lastIcon] \
      -compound left -image [iconDB::extToIcon find]
   # Cascade Menu for settings
#   $suSettings add checkbutton -variable S::S(autoStart) -label "RDT is auto started on login" -command S::makeShortcut
#   $bgSettings add checkbutton -variable S::S(deleteStale) -label "Background Remove Stale Entries from Database"
   $Menu.rtSettings delete 0 end
   $Menu.suSettings delete 0 end
   $Menu.bgSettings delete 0 end
#----------------------------------RUN TIME -----------------------------------------
   $Menu.rtSettings.limitNum delete 0 end
   $Menu.rtSettings.bias delete 0 end
   foreach {num} {5 10 15 25 30 35 40 50 60} {
      $Menu.rtSettings.limitNum add radiobutton -value $num -label $num -variable S::S(limit)
   }
   $Menu.rtSettings add cascade  -label "Limit Menu Entries to..." -menu $Menu.rtSettings.limitNum \
      -compound left -image [iconDB::extToIcon "limit"]

   foreach {num} {0.4 0.5 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95} {
      $Menu.rtSettings.bias add radiobutton -value $num -label "[expr {$num*100.0}]%" -variable S::S(bias) 
   }
   $Menu.rtSettings add command -label "Set limit for search results" -command [list S::getTreeLimit "Enter Search Limit\n0 to N, or end for all"] \
      -compound left -image [iconDB::extToIcon "search"]

   $Menu.rtSettings add cascade  -label "Bias file name width in Search Table..." -menu $Menu.rtSettings.bias  \
      -compound left -image [iconDB::extToIcon bias]
   $Menu.rtSettings add separator

   $Menu.rtSettings add checkbutton -variable S::S(useAll)    -label "Scan adds all files vs. owned by $::env(USERNAME)"
   $Menu.rtSettings add checkbutton -variable S::S(Focus)     -label "Close Search Table when it loses Focus"
   $Menu.rtSettings add checkbutton -variable S::S(checkOpen) -label "Check for open files and flag in Menu/Search Table"
   $Menu.rtSettings add checkbutton -variable S::S(ontop)     -label "Bind '$S::S(Hotkey)' to toggle active window stay on top" \
      -command S::setupOnTop
   $Menu.rtSettings add checkbutton -variable S::S(SwapButton) -label "Reverse function of left and right Mouse buttons"
   $Menu.rtSettings add command -label "Refresh drive mount status" -command [list ::rdt::checkMounts 1] \
      -compound left -image [iconDB::extToIcon "volcheck"]
   $Menu.rtSettings add separator
   
   if {$state eq "normal"} {
      $Menu.rtSettings add command -label "Hide Console" -command "console hide" \
      -compound left -image [iconDB::extToIcon console]
   } else {
      $Menu.rtSettings add command -label "Show Console" -command "console show" \
      -compound left -image [iconDB::extToIcon console]
   }

#----------------------------------BACKGROUND -----------------------------------------

   $Menu.bgSettings.age delete 0 end
   foreach {num} {7 14 30 60 90 120 180 365 1000 never} {
      $Menu.bgSettings.age add radiobutton -value $num -label $num -variable S::S(age) \
      -command rdt::purgeOldShortCuts
   }
   $Menu.bgSettings add cascade  -label "Remove entries older than (days)..." -menu $Menu.bgSettings.age \
      -compound left -image [iconDB::extToIcon clock]
   $Menu.bgSettings add checkbutton -variable S::S(deleteDead) -label "Remove Shortcuts when file missing"

#----------------------------------STARTUP -----------------------------------------

   $Menu.suSettings add command -label "Reset Database and rescan shortcuts" \
      -command rdt::restart \
      -compound left -image [iconDB::extToIcon scan]
   $Menu.suSettings add checkbutton -variable S::S(resetIconCache) -label "Rebuild icon cache on next startup"
   $Menu.suSettings add checkbutton -variable S::S(limitOnBattery) -label "Limit scanning when on battery power"
   $Menu.suSettings add checkbutton -variable S::S(autoStart)      -label "RDT is auto started on login" -command S::makeShortcut

   # assumes submenu type already created (which they are in init)
   # $Menu.type delete 0 end

   $Menu add separator
   $Menu add cascade -label "Runtime Settings..."    -menu $Menu.rtSettings 
   $Menu add cascade -label "Background Settings..." -menu $Menu.bgSettings 
   $Menu add cascade -label "Startup Settings..."    -menu $Menu.suSettings 
   # can this be done once during init and reused?
#----------------------------------BOTTOM ICONS -----------------------------------------
   $Menu add separator
   $Menu add command -label "About..." -command "rdt::About" \
      -compound left -image [iconDB::extToIcon about]

   $Menu add command -label "Exit RDT" -command "rdt::unload" \
      -compound left -image [iconDB::extToIcon exit]
   return $Menu

}
#------------------------------------------------------------------------------
# Handle the case where a menu is being posted
#------------------------------------------------------------------------------
proc winTaskBar::postMenu {iconName} {
   variable lastIcon
   set lastIcon $iconName
   #-------------------------
   #-------------------------
   set Menu [::cL$iconName mymenu]
   if {[treeSearch::isOpen]} {
      treeSearch::unload
   }
   # Create threholds at yesterday, last week, last month
   set n [clock seconds]
   # last sunday at midnight for example
   # clock format [clock add [clock scan sunday] -7 days]
   #midnight today
   #clock format [clock scan 0000]
   set m [clock scan 0000]
   set yest [clock add $m -1 days]
   #set dby [clock add $m -2 days]
   #set ddby [clock add $m -3 days]
   # depends on day of week? Always want last monday midnight
   if {[clock scan monday] > $n} {
      set sow [clock add [clock scan monday] -7 days]
   } else {
      set sow [clock scan monday]
   }

   set thresholds [lsort -unique -decreasing -integer [list $m $yest $sow]]
#   set thresholds [lsort -unique -decreasing -integer [list $m $yest $dby $ddby $sow]]
   $Menu delete 0 end
   set menuList [list]
   # handle either folder or file type differently
   # todo: insert pinned items at the top
   #
   # Check for files open in office apps or folders in explorer, for these we color code
   #
   winTaskBar::flagComOpen $iconName
   if {$iconName eq "folder"} {
      set isFolder 1
      set pinList [db::menuList "*" 1 1 $S::S(limit)]
      set menuList [db::menuList "*" 1 0 $S::S(limit)]
   } else {
      set isFolder 0
      set pinList [db::menuList $iconName 0 1 $S::S(limit)]
      set menuList [db::menuList $iconName 0 0 $S::S(limit)]  ;# was 0 to only include pinned items
   }
   set counter 0
   #----------------------------NORMAL----------------------------------------------------
   # For each return file/folder
   foreach hashSet $menuList {
      lassign $hashSet name sdate fdate existing isopen
#debug "  menu $name $sdate $fdate $existing"
      set color [winTaskBar::menuOpenColor $isopen]
      set img [iconDB::nameToIcon $name $isFolder]
      # if we couldn't read the iconName then the file no longer exists, remove it
      if {$img eq ""} {
         db::removeFile $name
         log "No icon for $name exists"
         continue
      }
      ;# separators based on time
      if {[llength $thresholds]} {
         if {$sdate < [lindex $thresholds 0]} {
            $Menu add separator
#$Menu add command -label "[clock format [lindex $thresholds 0] -format {%Ex}]=================================="
            lpop left thresholds
            # handle multiple crosses (e.g. at beginning of week or month)
            while {$sdate < [lindex $thresholds 0] && [llength $thresholds]} {
               lpop left thresholds
            }
         }
      }
      incr counter
      addItem $Menu $isFolder $hashSet $img $color
   }
   #----------------------------PINNED----------------------------------------------------
   # Ad separater if warranted
   if {[llength $pinList] > 0 && $counter > 0} {
      $Menu add separator
   }
   foreach hashSet $pinList {
      lassign $hashSet name sdate fdate existing isopen
      #pinned items (icon is overwritten with pin)
      if {$isopen} {
         # change the image here if the file is open in the app
         set color "blue"
      }  else {
         set color "black"
      }
      set img [iconDB::extToIcon "pinned"]
      addItem $Menu $isFolder $hashSet $img $color
   }
   $Menu add separator
   # Settings menu (created during init)
#      $Menu add command \
#         -label "Sleep Computer" \
#         -command [list twapi::suspend_system -state standby -disablewakeevents true]  \
#         -compound left -image [iconDB::extToIcon hibernate]
   $Menu add cascade -label "Settings..." -menu $Menu.settings \
      -compound left -image [iconDB::extToIcon settings]
   $Menu.settings configure \
      -postcommand [list winTaskBar::buildSettingMenu $Menu.settings]

   if {$isFolder} {
      $Menu add command \
         -label "Search Folder Table" \
         -command [list treeSearch::launch $isFolder $iconName] \
         -compound left -image [iconDB::extToIcon search]
   } else {
      $Menu add command \
         -label "Search File Table" \
         -command [list treeSearch::launch $isFolder $iconName] \
         -compound left -image [iconDB::extToIcon search]
   }
}

#------------------------------------------------------------------------------
# Flag a open files for this icon  ~10ms per office app with open files, < 1ms otherwise
# ~6ms to test all apps if they are closed
#------------------------------------------------------------------------------
proc winTaskBar::flagComOpen {icon} {
   variable Com
   db::resetOpen
   if {$S::S(checkOpen) } {
      # folders we search windows for caption matching name
      if {$icon eq "folder"} {
         foreach {hwnd} [twapi::find_windows -caption 1 -toplevel 1 -visible 1] {
            set pid [twapi::get_window_process $hwnd]
            set app [twapi::get_process_name $pid]
            if {$app eq "explorer.exe"} {
               set file [twapi::get_window_text $hwnd]
               # if $file is bogus, the setVal will silently fail
               db::setVal $file IsOpen 1
            }
         }
      } else {
         # files we look for office apps with file in caption
         if {[info exists Com($icon)]} {
            foreach {file} [winTaskBar::getComOpen $icon] {
               db::setVal $file IsOpen 1
            }
         } else {
         # generic office/everything icon, look for all types
            foreach {icn} [array names Com] {
               foreach {file} [winTaskBar::getComOpen $icn] {
                  db::setVal $file IsOpen 1
               }
            }
         }
      }
   }
}
#------------------------------------------------------------------------------
# Return any active files in office applications
#------------------------------------------------------------------------------
proc winTaskBar::getComOpen {icon} {
   variable Com
   set open [list]
   set icon [string tolower $icon]
   # check array here
   if {[info exists Com($icon)]} {
      lassign $Com($icon) Object DocType fName
      try {
         set comObj [twapi::comobj $Object -active]
         try {
            $comObj -with $DocType -iterate ws {
               lappend open [rdt::mapLocal [$ws $fName]]
               $ws -destroy
            } on error result {
               log $result
            }
         } on error result {
            log $result
         } finally {
            $comObj -destroy
         }
      } on error result {
         # app is not open, return null list
         return $open
      }
   }
   return $open
}
#------------------------------------------------------------------------------
#  Add an item to the menu, folder or file
#------------------------------------------------------------------------------
proc winTaskBar::addItem {Menu isFolder hashSet img color} {
   lassign $hashSet name sdate fdate existing
   ##
   # Folder gets a slightly different menu
   #
   if {$isFolder} {
      set label "[clock format $sdate -format {%Ex}]   $name"
      set ext "folder"
   } else {
      set folder [file tail [file dirname $name]]
      set ext [fileExt $name]
      set file [file tail $name]
      if {$rdt::hideExt} {
         set file [file rootname $file]
      }
      set label "[clock format $fdate -format {%Ex}]    $file   ($folder)"
   }
   # Add a document type icon if one is available
   if {$existing} {
      set state "normal"
   } else {
      set state "disabled"
   }
   #icon should be based on ext, not on icon
   if {$img ne ""} {
      $Menu add command \
         -label $label -state $state \
         -compound left -image $img -foreground $color \
         -command [list rdt::launch $name]
   } else {
      $Menu add command \
         -label $label -state $state -foreground $color \
         -command [list rdt::launch $name]
   }
   #tooltip::tooltip $Menu -index $label "This is some help for $name"
}
#------------------------------------------------------------------------------
# Handle the case where a search box is being posted
#------------------------------------------------------------------------------
proc winTaskBar::postSearchBox {iconName} {
   variable priorIcon
   #-------------------------
   #-------------------------
   set Menu [::cL$iconName mymenu]
#     buildSettingMenu $Menu
   #$Menu unpost
   if {[treeSearch::isOpen]} {
      treeSearch::unload
      # open a new window if different
      if {$iconName ne $priorIcon} {
         if {$iconName eq "folder"} {
            treeSearch::launch  1 $iconName
         } else {
            treeSearch::launch  0 $iconName
         }
         set priorIcon $iconName
      } else {
         # remain closed
         set priorIcon ""
      }
   } else {
      # was closed, open new window
      if {$iconName eq "folder"} {
         treeSearch::launch  1 $iconName
      } else {
         treeSearch::launch 0 $iconName
      }
      set priorIcon $iconName
   }
}
#----------------------------------------------------------------------------
# Remove all of the icons
#----------------------------------------------------------------------------
proc winTaskBar::RemoveIcons {args} {
   foreach {iconName} [S::getTrayIcons] {
      try {
         delete object ::cL$iconName
      } on error result {
         logerr $result
      }
   }
   unset -nocomplain S::getTrayIcons
}

package provide WinTaskBar 1.0
#------------------------------------------------------------------------------
# Test Functions
# check the number of missing
#------------------------------------------------------------------------------
proc winTaskBar::checkMissing {args} {
   foreach row [db::fileListRows * 0] {
      set File [db::getValbyRow $row "File"]
      set ext [fileExt $File]
      if {![iconDB::typeExists $ext]} {
         incr missing($ext)
      }
   }
   foreach {ext} [array names missing] {
      log "$ext=$missing($ext)"
   }
}
#---------------------------------------------------------------------------- 
# Incrtcl class of tray iccon
#---------------------------------------------------------------------------- 
package require Itcl
namespace import -force itcl::*
;# Delete old definition
catch {delete class trayIcon}
#################################################################################
# Class Definition for trayIcon
# Usage: Create an icon passing in file name for icon and if it is to be shownn
#  methods to sync to a new settings data and to destroy an icon
# 
# 
# 
#################################################################################

class ClsTrayIcon {
   variable IconName
   variable Show
   variable IconFile
   variable FileExts

   variable IconTrayHICON
   variable IconMenuImage
   variable IsShown
   variable IdTrayIcon
   variable Tip
   #
   private variable timestamp
   private variable myMenu
   private variable isShown
   #  ----------------------------------------------------------------------------
   #  Constructor
   #  ClsTrayIcon bubba <name> <show> <iconfile> <fileext>
   #  ----------------------------------------------------------------------------
   constructor {_iconName _show _iconFile _fileExts {_Tip ""}} {
      #log "Creating $_iconName"
      set IconName $_iconName
      set Show $_show
      set IconFile $_iconFile
      set FileExts $_fileExts
      set Tip $_Tip
      # Read icon Files
      try {
         set timestamp [file mtime $IconFile]
         set IconMenuImage [iconDB::readIconFile $IconFile]
         set IconTrayHICON [twapi::load_icon_from_file $IconFile]
      } on error result {
        console show
        logerr $result
      }
      # Create the menus
      try {
         set myMenu .$IconName
         # HACK: TODO postMenu to static method or pass in the menu to post
         menu $myMenu \
            -postcommand [list winTaskBar::postMenu $IconName] -tearoff 0
         # cascade setting menus for RMB
         #menu $myMenu.type -tearoff 0
         # settings cascade
         menu $myMenu.settings          -tearoff 0
         #menu $myMenu.settings.type     -tearoff 0
         menu $myMenu.settings.rtSettings -tearoff 0
         menu $myMenu.settings.bgSettings -tearoff 0
         menu $myMenu.settings.suSettings -tearoff 0
         menu $myMenu.settings.bgSettings.age      -tearoff 0
         menu $myMenu.settings.rtSettings.limitNum -tearoff 0
         menu $myMenu.settings.rtSettings.bias     -tearoff 0
         menu $myMenu.settings.wid      -tearoff 0
      } on error result {
        console show
        logerr $result
      }
      # Show the icon
      if {$Show} {
         try {
            set IdTrayIcon [twapi::systemtray addicon $IconTrayHICON [list ClsTrayIcon::twapiTrayIconClicked $IconName]] 
            set Tip [string map [list "IconName" $IconName] $Tip]
            twapi::systemtray modifyicon $IdTrayIcon -tip $Tip
            # can use -balloon <message> to temporarly put up a message, then it will fade
            set isShown 1
         } on error result {
           console show
           logerr $result
         }
      } else {
         set IdTrayIcon ""
      }
      # all done
   }
   #  ----------------------------------------------------------------------------
   #  Destructor
   #  ----------------------------------------------------------------------------
   destructor {
      if {$IdTrayIcon ne ""} {
         # remove icon resources
         twapi::systemtray removeicon $IdTrayIcon
         twapi::free_icon $IconTrayHICON
         # remove menu
         destroy $myMenu
         image delete $IconMenuImage
         set IdTrayIcon ""
      }
   }
   #  ----------------------------------------------------------------------------
   #  Private Methods
   #  ----------------------------------------------------------------------------
   private {
   }
   #  ----------------------------------------------------------------------------
   #  public Methods
   #  ----------------------------------------------------------------------------
   public {
      # Called after settings change
      method sync {show iconFile fileExts} {
         set ts [file mtime $iconFile]
         # file or file timestamp changed (see if image changed)
         if {($IconFile ne $iconFile) || ($timestamp ne $ts)} {
            try {
               twapi::free_icon $IconTrayHICON
               set IconMenuImage [iconDB::readIconFile $iconFile]
               set IconTrayHICON [twapi::load_icon_from_file $iconFile]
               set IconFile $iconFile

               if {$show} {
                  twapi::systemtray modifyicon $IdTrayIcon -tip $Tip -hicon $IconTrayHICON
               }
            } on error result {
               logerr $result
            }
         }
         # visibility changed
         if {$Show != $show} {
            if {$Show == 1 && $show == 0} {
               # disable
               twapi::systemtray removeicon $IdTrayIcon
               set IdTrayIcon ""
            } else {
               # enable
               set IdTrayIcon [twapi::systemtray addicon $IconTrayHICON [list ClsTrayIcon::twapiTrayIconClicked $IconName]] 
               #fix Tip
               set Tip [string map [list "IconName" $IconName] $Tip]
               twapi::systemtray modifyicon $IdTrayIcon -tip $Tip
               #save state
               set Show $show
            }
         }
         # This is handled outside this class
         set FileExts $fileExts
      }
      # Return the state for saving offline
      method state {args} {
         return [list $IconName $Show $IconFile $FileExts]
      }
      # Return the image name
      method image {args} {
         return $IconMenuImage
      }
      #
      method mymenu {args} {
         return $myMenu
      }
   }
   #---------------------------------------------------------------------------- 
   # Update the tip if changed in user settings, called from settings
   #---------------------------------------------------------------------------- 
   method updateTip {Tip} {
      if {$IdTrayIcon ne ""} {
         set Tip [string map [list "IconName" $IconName] $Tip]
         twapi::systemtray modifyicon $IdTrayIcon -tip $Tip
      }
   }
   #  ----------------------------------------------------------------------------
   #  Static methods
   #  ----------------------------------------------------------------------------
   proc comProc {args} {}
}
#----------------------------------------------------------------------------
# Callback fired when mouse over or clicked on one of the icons (windows only)
# order is as follows
# Callback wmMenuButton ico#4 winTaskBar::postIconMenu mp wmMenuButton 2241 1578
# ->postIconMenu mp wmMenuButton 2241 1578
# -->mouseClicked mp (not for search)
#----------------------------------------------------------------------------
proc ClsTrayIcon::twapiTrayIconClicked {args} {
# cmd num lbuttondown {x y} num
   #winTaskBar::postIconMenu ppt wmMenuButton 1577 1180
   lassign $args iconName num message XY ticks
   lassign $XY x y
   # Handle swapped buttons
   set s $S::S(SwapButton)
   if {($s && $message=="lbuttondown") || (!$s && $message=="contextmenu")} {
      # this will close menu if open or toggle search window
      ###winTaskBar::mouseClicked $iconName
      winTaskBar::postSearchBox $iconName
   } elseif {(!$s && $message=="lbuttondown") || ($s && $message=="contextmenu")} {
      # a couple steps needed for twapi implementation
      # read mouse location directly
      lassign [twapi::get_mouse_location] x y
      set hwin [twapi::Twapi_GetNotificationWindow]
      twapi::set_foreground_window $hwin
      # this even will indirectly call the winTaskBar::postMenu function for this icon
      # since a -postcommand is registered to this menu in the class instance
      [::cL$iconName mymenu] post $x $y
      twapi::PostMessage $hwin 0 0 0
   }
}
#  ----------------------------------------------------------------------------
#  Object Methods
#  ----------------------------------------------------------------------------
#body trayIcon::method1 {args} {
#}
#  ----------------------------------------------------------------------------
#  Static Methods (procs)
#  ----------------------------------------------------------------------------
#proc trayIcon::comProc {args} {
#}

