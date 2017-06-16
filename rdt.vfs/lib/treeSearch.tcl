#----------------------------------------------------------------------------
# Filterable search window
#----------------------------------------------------------------------------
namespace eval treeSearch {
   variable x
   variable y
   variable tv .tt
   variable wentry
   variable tentry
   variable filtered 1
   variable usetype 1
   variable info
   variable headers
   variable splash
   variable myIcon
   variable template
   variable sticky 0
   variable decoration 22

   package require tileTable
   menu .sbrmb -tearoff 0
   namespace import ::winTaskBar::*
   namespace export clicked highlighted rmb unload launch isOpen cursor
}
#----------------------------------------------------------------------------
# Create the search menu
#----------------------------------------------------------------------------
proc treeSearch::launch {isFolder icon} {
   variable headers
   variable template
   variable tv      ;## TFW->>>
   variable isfolder $isFolder
   if {$isFolder} {
      set template {"" "HitsXX" "2013-01-01 00:00XX" "2013-01-01 00:00XX"}
      set headers {"Folder" "Hits" "Mod Time" "Access Time"}
   } else {
      set template {"" "" "HitsXX" "2013-01-01 00:00XX" "2013-01-01 00:00XX"}
      set headers {"File" "Folder" "Hits" "Mod Time" "Access Time"}
   }
   # initialize
   treeSearch::init $isfolder $icon
   # fill with data
   treeSearch::populate $isfolder 1
   # show and move it
   treeSearch::locate
#   after idle treeSearch::locate
#wm withdraw $tv  ;## TFW->>>
#wm deiconify $tv ;## TFW->>>
}
#----------------------------------------------------------------------------
# Populate the tree when user types in text
#----------------------------------------------------------------------------
proc treeSearch::onChange {args} {
   set isFolder [lindex $args 0]
   treeSearch::populate $isFolder 0
}
#----------------------------------------------------------------------------
# Populate the tree when user presses a button
#----------------------------------------------------------------------------
proc treeSearch::refresh {args} {
   variable isfolder
   treeSearch::populate $isfolder 0
}

#----------------------------------------------------------------------------
# Initialize the search menu, called each time it is launched
#----------------------------------------------------------------------------
proc treeSearch::init {isFolder icon} {
   variable tv
   variable headers
   variable template
   variable wentry
   variable tentry
   variable isfolder $isFolder
   variable info
   variable myIcon $icon
   variable sticky
   variable decoration
   package require tooltip
   # first time create the toplevel, otherwise withdraw it for now
   if {[winfo exists $tv]} {
      wm withdraw $tv
      # children should already be cleared out here
      foreach {child} [winfo children $tv] {
         destroy $child
      }
   } else {
      toplevel $tv
      wm withdraw $tv
      # move window to where mouse is so we don't get the first time "jump"
      lassign [twapi::get_mouse_location] WX WY
      wm geometry $tv +${WX}+${WY}
      update
      # get dimensions of the borders and decoration (edge > men on orka)
      lassign [outerGeometry $tv] w h x y men edge
      # added 3/24/17 to stop growing by caption height on startup
      set decoration [expr {$men-$edge}]
      # save the decoration thickness for later (still off by 2 pixels, but much better)
      incr S::S(minheight) [expr {-$decoration}]

      # remove caption, need update first
      twapi::configure_window_titlebar [twapi::get_parent_window [list [winfo id $tv] "HWND"]] -visible 0
      wm attributes $tv -topmost
      # restore a minimum size based on last use
      wm minsize $tv $S::S(minwidth) $S::S(minheight)
   }
   wm protocol $tv WM_DELETE_WINDOW [list treeSearch::unload]

   bind $tv <Escape> [list treeSearch::unload]
   if {$S::S(Focus)} {
      bind $tv <FocusOut> [list treeSearch::unload]
   } else {
      bind $tv <FocusOut> {}
   }
   # create my treeview
   TileTable::Create $tv $headers $template {}
   ttk::button $tv.exit -text "Close" -command [list treeSearch::unload]
   ttk::checkbutton $tv.filter \
      -variable treeSearch::filtered \
      -image [list [iconDB::extToIcon "filteroff"] selected [iconDB::extToIcon "filter"]] \
      -style "Toolbutton" \
      -command [list treeSearch::refresh]
   tooltip::tooltip $tv.filter "Toggles filter on/off hidden files of this type"

   # Additional button to toggle everything on specific icons
   if {$isFolder || $icon eq "everything"} {
      # folder doesn't support all files toggle
      grid [ttk::label $tv.info -textvariable treeSearch::info -cursor fleur] -sticky nsew
   } else {
      set img [::cL$icon image]
      ttk::checkbutton $tv.type \
         -variable treeSearch::usetype \
         -image [list [iconDB::extToIcon "everything"] selected $img] \
         -style "Toolbutton" \
         -command [list treeSearch::refresh]
      tooltip::tooltip $tv.type "Toggles filter on/off for this file type"
      grid [ttk::label $tv.info -textvariable treeSearch::info -cursor fleur] $tv.type -sticky nsew
   }
   tooltip::tooltip $tv.info "Full name of highlighted file, you may drag search window by clicking dragging in here"

   grid [ttk::entry $tv.ent -textvariable treeSearch::tentry] $tv.filter -sticky nsew
   tooltip::tooltip $tv.ent "Enter text here for case insensitive incremental search, wildcards are allowed"
   # 
   ttk::checkbutton $tv.sticky \
      -variable treeSearch::sticky \
      -image [list [iconDB::extToIcon "unpinned"] selected [iconDB::extToIcon "pinned"]] \
      -style "Toolbutton" 
   tooltip::tooltip $tv.sticky "Check to not close search window after launching file"
   grid $tv.exit  $tv.sticky -sticky nsew

   # into label used to move window around
   bind $tv.info <ButtonPress-1> [list treeSearch::drag_start %W %X %Y]
   bind $tv.info <B1-Motion>     [list treeSearch::drag_motion %W %X %Y]

   trace vdelete ::treeSearch::tentry w {treeSearch::onChange 0}
   trace vdelete ::treeSearch::tentry w {treeSearch::onChange 1}
   set tentry ""
   # monitor changes to variable treeSearch::tentry and repopulate pasted on matches
   trace variable ::treeSearch::tentry w [list treeSearch::onChange $isFolder]
}
#----------------------------------------------------------------------------
# Highlighted entry, show on label
#----------------------------------------------------------------------------
proc treeSearch::highlighted {file} {
   variable info
   set info $file
}
#------------------------------------------------------------------------------
proc treeSearch::drag_start {W X Y} {
   variable splash
   set W [winfo toplevel $W]
   set splash(X) [expr {$X - [winfo x $W]}]
   set splash(Y) [expr {$Y - [winfo y $W]}]
   destroy .miniPlayer.mpframe.tb.tt.title.balloon
}
#------------------------------------------------------------------------------
# Motion process
#------------------------------------------------------------------------------
proc treeSearch::drag_motion {W X Y} {
   variable splash
   set x [expr {$X - $splash(X)}]
   set y [expr {$Y - $splash(Y)}]
   wm geometry [winfo toplevel $W] "+$x+$y"
   destroy .miniPlayer.mpframe.tb.tt.title.balloon
}
#------------------------------------------------------------------------------
# Put the search window near the mouse, done as an after idle event
#------------------------------------------------------------------------------
proc treeSearch::locate {args} {
   variable tv
   try {
      # get the work area
      lassign [twapi::get_desktop_workarea] XT YT XB YB
      # get both inner and outer window coordinates now that the window is full
## TFW->>>#wm deiconify $tv
      wm deiconify $tv
      lassign [innerGeometry $tv] wg hg x y
      lassign [outerGeometry $tv] w h x y
#log "w=$w/$wg h=$h/$hg x=$x y=$y"
      lassign [twapi::get_mouse_location] WX WY
      # position the box in the correct corner
      set deltax 0
      if {$WX < $XT} {
         set deltax [expr {$XT-$WX}]
      } elseif {($WX+$w) > $XB} {
         set deltax [expr {$XB-($WX+$w)}]
      }
      if {$WY < $YT} {
         set deltay [expr {$YT-$WY}]
      } elseif {($WY+$h) > $YB} {
         set deltay [expr {$YB-($WY+$h)}]
      }
      incr WX $deltax
      incr WY $deltay
# puts "wg=$wg hg=$hg WX=$WX WY=$WY XT=$XT YT=$YT XB=$XB YB=$YB w=$w h=$h deltax=$deltax deltay=$deltay"
      #puts "wm geometry $tv +$WX+$WY"
#      wm deiconify $tv
      wm geometry $tv ${wg}x${hg}+${WX}+${WY}
#log "$tv ${wg}x${hg}+${WX}+${WY}"
      focus $tv.ent
#      deiconify $tv
   } on error result {
      log $result
      log $::errorInfo
   }
   after idle [list wm minsize $tv 250 400]
}
#------------------------------------------------------------------------------
# Return the normal (inner geometry) of the window
#------------------------------------------------------------------------------
proc treeSearch::innerGeometry {{w .}} {
   scan [wm geometry $w] "%dx%d+%d+%d" w h x y
   # this is to fix a bug, inner geometry seems to be two pixels too wide
   incr w -2   
   return [list $w $h $x $y]
}
#----------------------------------------------------------------------------
# Return the total geometry of the window
#----------------------------------------------------------------------------
proc treeSearch::outerGeometry {{w .}} {
   set geom [wm geometry $w]
   scan $geom "%dx%d+%d+%d" width height decorationLeft decorationTop
   #regexp -- {([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)} $geom -> \
   #width height decorationLeft decorationTop
   set contentsTop [winfo rooty $w]
   set contentsLeft [winfo rootx $w]
   # Measure left edge, and assume all edges except top are the
   # same thickness
   set decorationThickness [expr {$contentsLeft - $decorationLeft}]
#puts "decorationThickness=$decorationThickness"
   # Find titlebar and menubar thickness
   set menubarThickness [expr {$contentsTop - $decorationTop}]
   incr width [expr {2 * $decorationThickness}]
   incr height $decorationThickness
   incr height $menubarThickness
   return [list $width $height $decorationLeft $decorationTop $menubarThickness $decorationThickness]
}
#------------------------------------------------------------------------------
# unload the tree search, remove any traces
#------------------------------------------------------------------------------
proc treeSearch::isOpen {args} {
   variable tv
   if {[winfo exists $tv] && ([wm state $tv] eq "normal")} {
      scan [wm geometry $tv] "%dx%d+%d+%d" w h x y
      if {$x < 32766} {
         return 1
      } else {
         return 0
      }
   } else {
      return 0
   }
}
#------------------------------------------------------------------------------
# unload the tree search, remove any traces
#------------------------------------------------------------------------------
proc treeSearch::unload {args} {
   variable tv
   variable tentry
   variable isfolder
   variable sticky
   variable decoration

   if {[winfo exists $tv]} {
      # save window height for next time launch
      lassign [innerGeometry $tv] S::S(minwidth) S::S(minheight) x y
      # Remove the height of the menu bar since we had removed it from view and resotring will put it back
####      incr S::S(minheight) [expr {-$decoration}]
      wm withdraw $tv
      # clear out children so we have a hull
      foreach {child} [winfo children $tv] {
         destroy $child
      }
      trace vdelete ::treeSearch::tentry w {treeSearch::onChange 0}
      trace vdelete ::treeSearch::tentry w {treeSearch::onChange 1}
      set tentry ""
      set sticky 0
      #Note: toplevel is not deleted
   }
}
#----------------------------------------------------------------------------
# Post the right mouse button menu here (multiple items)
#----------------------------------------------------------------------------
proc treeSearch::rmbMulti {files x y} {
   .sbrmb delete 0 end
   .sbrmb add command -label "Purge [llength $files] Items" -command [list treeSearch::purge $files] \
      -compound left -image [iconDB::extToIcon purge]
   .sbrmb post $x $y
}
#----------------------------------------------------------------------------
# Post the right mouse button menu here (single item)
#----------------------------------------------------------------------------
proc treeSearch::rmb {data x y} {
   lassign $data file exists
   set folder [file nativename [db::getVal $file "Folder"]]
   .sbrmb delete 0 end
   set isDir [db::getVal $file "IsFolder"]
   if {$isDir eq 1} {
      set ext "folder"
   } else {
      set ext [fileExt $file]
   }
   if {[iconDB::iconExists $ext]} {
      .sbrmb add command -label "Open $file" -command [list treeSearch::clicked $data] \
         -compound left -image [iconDB::extToIcon $ext]
   } else {
      .sbrmb add command -label "Open $file" -command [list treeSearch::clicked $data]
   }
   if {$file ne $folder} {
   .sbrmb add command -label "Open $folder" -command [list treeSearch::clicked [list $folder 1]] \
      -compound left -image [iconDB::extToIcon "folder"]
   }
   .sbrmb add separator

   # Bring in filtered and pinned state, then be smart about what options are shown
   # for this file

   set isFiltered [db::getVal $file "Excluded"]
   if {! $isFiltered} {
      .sbrmb add command -label "Filter out $file" -command [list treeSearch::exclude $file 1] \
         -compound left -image [iconDB::extToIcon "filter"]
   } else {
      .sbrmb add command -label "Include $file" -command [list treeSearch::exclude $file 0] \
         -compound left -image [iconDB::extToIcon "filteroff"]
   }
   set isPinned [db::getVal $file "Pinned"]
   if {! $isPinned} {
      .sbrmb add command -label "Pin $file" -command [list treeSearch::pin $file] \
         -compound left -image [iconDB::extToIcon "pinned"]
   } else {
      .sbrmb add command -label "UnPin $file" -command [list treeSearch::unpin $file] \
         -compound left -image [iconDB::extToIcon "unpinned"]
   }
   .sbrmb add command -label "Purge $file" -command [list treeSearch::purge [list $file]] \
      -compound left -image [iconDB::extToIcon purge]
   .sbrmb add separator
   .sbrmb add command -label "Clipboard Path: $file" -command [list treeSearch::clipname $file] \
      -compound left -image [iconDB::extToIcon "clipboard"]
   .sbrmb add command -label "Clipboard Name: [file tail $file]" -command [list treeSearch::clipname [file tail $file]] \
      -compound left -image [iconDB::extToIcon "clipboard"]
   # if there were shortcuts in the sendTo folder, use them to launch the file
   if {[llength $winTaskBar::sendTo]} {
      .sbrmb add separator
      foreach {row} $winTaskBar::sendTo {
         lassign $row title CL img
         .sbrmb add command \
            -label "$title $file" \
            -command [list twapi::shell_execute -logusage 1 -path $CL -params "\"$file\""] \
            -compound left -image $img
      }
   }
      #lappend sendTo [list [file rootname [file tail $shortcut]] $commandLine [iconDB::extToIcon $shortcut] ]

#   .sbrmb add separator
#   .sbrmb add command -label "Filter out extension *$ext" -command {}
#   .sbrmb add separator
#   .sbrmb add command -label "File Properties" -command {}
   .sbrmb post $x $y
}

#------------------------------------------------------------------------------
# add file to the exclude list
#------------------------------------------------------------------------------
proc treeSearch::purge {files} {
   foreach {file} $files {db::removeFile $file}
   treeSearch::refresh
}
proc treeSearch::exclude {file how} {
   db::setVal $file Excluded $how
   treeSearch::refresh
}
proc treeSearch::pin {file} {
   db::setVal $file Pinned 1
   treeSearch::refresh
}
proc treeSearch::unpin {file} {
   db::setVal $file Pinned 0
   treeSearch::refresh
}
proc treeSearch::clipname {file} {
   clipboard clear
   #clipboard append [file nativename $file]
   clipboard append $file
}
#----------------------------------------------------------------------------
# Launch the file
#----------------------------------------------------------------------------
proc treeSearch::clicked {data} {
   variable isfolder
   variable sticky
   lassign $data file exists
   if {[rdt::launch $file]} {
      if {! $sticky} {
         after idle treeSearch::unload
      }
   }
}
#---------------------------------------------------------------------------- 
# Populate the tree view
#---------------------------------------------------------------------------- 
proc treeSearch::populate {isFolder isInit} {
   variable isfolder $isFolder
   variable filtered
   variable usetype
   variable tentry
   variable myIcon
   variable tv
   variable headers
   variable template
   # allow backslashes in searching (native file names)
   set pattern [string map {\\ \\\\ / \\\\} "*${tentry}*"]

   if {$isInit} {
      set SortCol [lindex $headers end]
      set SortDir 1
   } else {
      lassign [::TileTable::getLastSortInfo] SortCol SortDir
   }
   set srtOpt [treeSearch::sortLookup $SortCol $SortDir]

   if {$usetype} {
      winTaskBar::flagComOpen $myIcon
      set matches [db::tvRowList $pattern $isFolder $filtered $myIcon $S::S(treeLimit) $srtOpt]
   } else {
      winTaskBar::flagComOpen ""
      set matches [db::tvRowList $pattern $isFolder $filtered "" $S::S(treeLimit) $srtOpt]
   }

   set TileTable::bias $S::S(bias)
   TileTable::Populate $tv $matches $headers $template $isFolder $SortCol $SortDir
   # Fix the widths for bias the first tie
   if {$isInit} {
      TileTable::FixWidth $tv
   }
}


#------------------------------------------------------------------------------
# Map a column name into a sort index
#------------------------------------------------------------------------------
proc treeSearch::sortLookup {Col Dir} {
   switch -- $Col {
      "File" {set C "File"}
      "Folder" {set C  "File"}
      "Mod Time" {set C  "Ftime"}
      "Access Time" {set C  "Sctime"}
      "Hits" {set C  "Hits"}
      default {set C "Sctime"}
   }
   if {$Dir} {
      return "-rsort $C"
   } else {
      return "-sort $C"
   }
}
#------------------------------------------------------------------------------
# Change the busy cursor
#------------------------------------------------------------------------------
proc treeSearch::cursor {how} {
   variable tv
   $tv configure -cursor $how
}

package provide TreeSearch 1.0

