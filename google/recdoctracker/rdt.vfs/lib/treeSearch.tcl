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
   variable Pattern
   variable caption 0
   variable splash
   variable ftype "*"
   variable myIcon
   package require tileTable
   menu .sbrmb -tearoff 0

}
#----------------------------------------------------------------------------
# Create the search menu
#----------------------------------------------------------------------------
proc treeSearch::launch {Pattern isFolder icon} {
   variable headers
   variable pattern  $Pattern
   variable isfolder $isFolder
   if {$isFolder} {
      set headers {"Folder" "Hits" "Mod Time" "Access Time"}
   } else {
      set headers {"File" "Folder" "Hits" "Mod Time" "Access Time"}
   }
   treeSearch::init $pattern $isfolder $icon
   treeSearch::populate $pattern $isfolder
}
#----------------------------------------------------------------------------
# Populate the tree when user types in text
#----------------------------------------------------------------------------
proc treeSearch::onChange {args} {
   variable pattern
   set isFolder [lindex $args 0]
   treeSearch::populate $pattern $isFolder
}
#----------------------------------------------------------------------------
# Populate the tree when user presses a button
#----------------------------------------------------------------------------
proc treeSearch::refresh {args} {
   variable pattern
   variable isfolder
   treeSearch::populate $pattern $isfolder
}

#----------------------------------------------------------------------------
# Initialize the search menu
#----------------------------------------------------------------------------
proc treeSearch::init {pattern isFolder icon} {
   variable tv
   variable headers
   variable wentry
   variable tentry
   variable isfolder $isFolder
   variable info
   variable caption 0
   variable myIcon $icon
   variable ftype [file extension $pattern]
   # first time create the toplevel
   if {[winfo exists $tv]} {
      #wm geometry $tv +100000+100000
      wm withdraw $tv
      # children should already be cleared out here
      foreach {child} [winfo children $tv] {
         destroy $child
      }
   } else {
      toplevel $tv
      wm withdraw $tv
      update
      # remove caption, need update first
      if {[twapi::get_version] < 3.0} {
         twapi::configure_window_titlebar [twapi::get_parent_window [winfo id $tv]] -visible 0
      }  else {
         twapi::configure_window_titlebar [twapi::get_parent_window [list [winfo id $tv] "HWND"]] -visible 0
      }
      wm attributes $tv -topmost
   }
   wm minsize $tv $S::S(minwid) $S::S(minheight)
   # Bug, the minsize is growing
   #wm title $tv "Filter Recent Document History"
   wm protocol $tv WM_DELETE_WINDOW [list treeSearch::unload]
   bind $tv <Escape> [list treeSearch::unload]
   TileTable::Create $tv $headers {}


   ttk::button $tv.exit -text "Close" -command [list treeSearch::unload]
   checkbutton $tv.filter \
      -variable treeSearch::filtered \
      -selectimage $winTaskBar::extToImage(filter) \
      -image $winTaskBar::extToImage(filteroff) \
      -indicatoron 0 \
      -command [list treeSearch::refresh]
   checkbutton $tv.type \
      -variable treeSearch::usetype \
      -selectimage $winTaskBar::extToImage($icon) \
      -image $winTaskBar::extToImage($icon) \
      -indicatoron 0 \
      -command [list treeSearch::refresh]
   grid [ttk::label $tv.info -textvariable treeSearch::info] $tv.type -sticky nsew
   grid [ttk::entry $tv.ent -textvariable treeSearch::tentry] $tv.filter -sticky nsew
   grid $tv.exit  -sticky nsew
   # into label used to move window around
   bind $tv.info <ButtonPress-1> [list treeSearch::drag_start %W %X %Y]
   bind $tv.info <B1-Motion>     [list treeSearch::drag_motion %W %X %Y]

   trace vdelete ::treeSearch::tentry w {treeSearch::onChange 0}
   trace vdelete ::treeSearch::tentry w {treeSearch::onChange 1}
   set tentry ""
   # monitor changes to variable treeSearch::tentry and repopulate pasted on pattern
   trace variable ::treeSearch::tentry w [list treeSearch::onChange $isFolder]
   after idle treeSearch::locate
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
##
# Motion process
#
proc treeSearch::drag_motion {W X Y} {
   variable splash
   set x [expr {$X - $splash(X)}]
   set y [expr {$Y - $splash(Y)}]
   wm geometry [winfo toplevel $W] "+$x+$y"
   destroy .miniPlayer.mpframe.tb.tt.title.balloon
}

# Put the search window near the mouse
#------------------------------------------------------------------------------
proc treeSearch::locate {args} {
   variable tv
   variable caption
   try {
      # get the work area
      lassign [twapi::get_desktop_workarea] XT YT XB YB
      wm deiconify $tv
      # get both inner and outer window coordinates now that the window is full
      lassign [innerGeometry $tv] wg hg x y
      lassign [outerGeometry $tv] w h x y
#puts "w=$w h=$h x=$x y=$y"
      lassign [twapi::get_mouse_location] WX WY
      # position the box in the correct corner
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
      incr wg -2  ;# some sort of bug, grows by 2 pixels
# puts "caption=$caption wg=$wg hg=$hg WX=$WX WY=$WY XT=$XT YT=$YT XB=$XB YB=$YB w=$w h=$h deltax=$deltax deltay=$deltay"
      #puts "wm geometry $tv +$WX+$WY"
      #wm geometry $tv +$WX+$WY
      wm geometry $tv ${wg}x${hg}+${WX}+${WY}
#puts "$tv ${wg}x${hg}+${WX}+${WY}"
      focus $tv.ent
   } on error result {
      log $result
      log $::errorInfo
      return
   }
   # let the user make it smaller than default larger size
   after idle [list wm minsize $tv 50 50]
}
#------------------------------------------------------------------------------
# Return the normal (inner geometry) of the window
#------------------------------------------------------------------------------
proc treeSearch::innerGeometry {{w .}} {
   scan [wm geometry $w] "%dx%d+%d+%d" w h x y
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
   return [list $width $height $decorationLeft $decorationTop]
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
   variable caption
   variable tentry
   variable isfolder
   if {[winfo exists $tv]} {
      # save window height for next time launch
      lassign [innerGeometry $tv] S::S(minwidth) S::S(minheight) x y
      wm withdraw $tv
      # clear out children so we have a hull
      foreach {child} [winfo children $tv] {
         destroy $child
      }
      trace vdelete ::treeSearch::tentry w {treeSearch::onChange 0}
      trace vdelete ::treeSearch::tentry w {treeSearch::onChange 1}
      set tentry ""
   }
}
#----------------------------------------------------------------------------
# Post the right mouse button menu here
#----------------------------------------------------------------------------
proc treeSearch::rmb {data x y} {
   lassign $data file mounted
   set ext [string tolower [string trim [file extension $file] .]]
   set folder [file nativename [file dirname $file]]
   .sbrmb delete 0 end
   if {[file isdirectory $file]} {
      set ext "folder"
   }
   if {[info exists winTaskBar::extToImage($ext)]} {
      .sbrmb add command -label "Open $file" -command [list treeSearch::clicked $data] \
         -compound left -image $winTaskBar::extToImage($ext)
   } else {
      .sbrmb add command -label "Open $file" -command [list treeSearch::clicked $data]
   }
   .sbrmb add command -label "Open $folder" -command [list treeSearch::clicked [list $folder 1]] \
      -compound left -image $winTaskBar::extToImage(folder)
   .sbrmb add separator

   # todo: bring in filtered and pinned state, then be smart about what options are shown
   # for this file

   .sbrmb add command -label "Purge $file" -command [list treeSearch::purge $file] \
      -compound left -image $winTaskBar::extToImage(purge)
   .sbrmb add separator
   .sbrmb add command -label "Filter out $file" -command [list treeSearch::exclude $file 1] \
      -compound left -image $winTaskBar::extToImage(filter)
   .sbrmb add command -label "Include $file" -command [list treeSearch::exclude $file 0] \
      -compound left -image $winTaskBar::extToImage(filteroff)
   .sbrmb add separator
   .sbrmb add command -label "Pin $file" -command [list treeSearch::pin $file] \
      -compound left -image $winTaskBar::extToImage(pinned)
   .sbrmb add command -label "UnPin $file" -command [list treeSearch::unpin $file] \
      -compound left -image $winTaskBar::extToImage(unpinned)
#   .sbrmb add command -label "Filter out extension *$ext" -command {}
#   .sbrmb add separator
#   .sbrmb add command -label "File Properties" -command {}
   .sbrmb post $x $y
}

#------------------------------------------------------------------------------
# add file to the exclude list
#------------------------------------------------------------------------------
proc treeSearch::purge {file} {
   db::removeFile $file
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
#----------------------------------------------------------------------------
# Launch the file
#----------------------------------------------------------------------------
proc treeSearch::clicked {data} {
   variable isfolder
   lassign $data file mounted
   if {[rdt::launch $file]} {
      unload
   }
}
#----------------------------------------------------------------------------
# Populate the treeview
#----------------------------------------------------------------------------
proc treeSearch::populate {Pattern isFolder} {
   variable isfolder $isFolder
   variable filtered
   variable usetype
   variable tentry
   variable ftype
   variable pattern $Pattern
   variable myIcon

   set pattern "*${tentry}*"

   variable tv
   variable headers
   if {$usetype} {
      set matches [db::fileList $pattern $isFolder $myIcon]
   } else {
      set matches [db::fileList $pattern $isFolder]
   }
   set data [list]
   set files [list]
   set icons [list]
   foreach {hashSet} $matches {
      lassign $hashSet name sdate mdate mounted pinned excluded hits
      set img [winTaskBar::getAnIcon $name $isFolder]
      # if we couldn't read the icon then the file no longer exists, remove it
      if {$img eq ""} {
         db::removeFile $name
         log "No Icon Exists, removed $name"
         continue
      }

      # skip if in exclucde list or it is not mounted
      if {($excluded || ! $mounted) && $filtered==1} {
         continue
      }
      set ext [fileExt $name]
      set sdate [clock format $sdate -format {%Y-%m-%d  %H:%M}]
      set mdate [clock format $mdate -format {%Y-%m-%d  %H:%M}]

      # todo: img should have all this info so skip this logic, first
      # need to set it during init and updated files (cachefile)

      if {$isFolder} {
         if {$excluded} {
            lappend icons $winTaskBar::extToImage(filter)
         } elseif {$pinned} {
            lappend icons $winTaskBar::extToImage(pinned)
         } else {
            lappend icons $winTaskBar::extToImage(folder)
         }
         set folder $name
         lappend data [list $folder $hits $mdate $sdate]
      } else {
         set tail [file tail $name]
         if {$excluded} {
            lappend icons $winTaskBar::extToImage(filter)
         } elseif {$pinned} {
            lappend icons $winTaskBar::extToImage(pinned)
         } else {
            lappend icons $img
         }
         set folder [file tail [file dirname $name]]
         lappend data [list $tail $folder $hits $mdate $sdate]
      }
      lappend files [list $name $mounted]
   }
   # todo: pass in icons here, also for folders
   TileTable::Populate $tv $files $headers $data $icons
}
#----------------------------------------------------------------------------
# Return the border and caption thickness for positioning a window
#----------------------------------------------------------------------------
# proc treeSearch::getBorderWidth {{w .}} {
#    set geom [wm geometry $w]
#    #regexp -- {([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)} $geom -> \
#    # width height decorationLeft decorationTop
#    scan $geom "%dx%d+%d+%d" width height decorationLeft decorationTop
#    set contentsTop [winfo rooty $w]
#    set contentsLeft [winfo rootx $w]
#    # Measure left edge, and assume all edges except top are the
#    # same thickness
#    set decorationThickness [expr {$contentsLeft - $decorationLeft}]
#    # Find titlebar and menubar thickness
#    set menubarThickness [expr {$contentsTop - $decorationTop}]
#    return [list $decorationThickness  $menubarThickness]
# }

package provide TreeSearch 1.0

