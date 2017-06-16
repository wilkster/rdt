##+##########################################################################
#
# tileTable.tcl -- Creates multi-column table using tile's treeview widget
# by Keith Vetter, March 21, 2008
# KPV Jun 03, 2008 - added sort arrows on column headers
#

package require Tk
package require tile

namespace eval ::TileTable {
   variable font
   variable bias 0.6
   variable LU
   variable Tree
   variable extSel 0
   variable lastSortCol ""
   variable lastSortDir
   variable isaFolder
}

image create bitmap ::TileTable::arrow(0) -data {
    #define arrowUp_width 7
    #define arrowUp_height 4
    static char arrowUp_bits[] = {
        0x08, 0x1c, 0x3e, 0x7f
    };
}
image create bitmap ::TileTable::arrow(1) -data {
    #define arrowDown_width 7
    #define arrowDown_height 4
    static char arrowDown_bits[] = {
        0x7f, 0x3e, 0x1c, 0x08
    };
}
image create bitmap ::TileTable::arrowBlank -data {
    #define arrowBlank_width 7
    #define arrowBlank_height 4
    static char arrowBlank_bits[] = {
        0x00, 0x00, 0x00, 0x00
    };
}
##+##########################################################################
#
# ::TileTable::Create -- Creates a new tile table widget
#
proc ::TileTable::Create {w headers template data} {
   variable lastSortCol "xxx"
   variable lastSortDir
   variable font
   variable LU
   variable Tree $w.tree
# really only want verticle scrollbar
#   ::ttk::treeview $w.tree -columns $headers -show {tree headings} \
#       -yscroll "$w.vsb set" -xscroll "$w.hsb set" -selectmode browse
#   ::ttk::scrollbar $w.hsb -orient horizontal -command "$w.tree xview"
   ::ttk::treeview $w.tree -columns $headers -show {tree headings} \
       -yscroll "$w.vsb set" -selectmode extended ;# was browse
   ::ttk::scrollbar $w.vsb -orient vertical -command "$w.tree yview"

   grid $w.tree $w.vsb -sticky nsew
#   grid $w.hsb         -sticky nsew
   # only let the tree widget expand
   grid column $w 0 -weight 1
   grid row    $w 0 -weight 1

   set font [::ttk::style lookup [$w.tree cget -style] -font]
   foreach col $headers temp $template {
      set lastSortDir($col) 1
      set name [string totitle $col]
      $w.tree heading $col -text $name -image ::TileTable::arrowBlank \
      -command [list ::TileTable::SortBy $w.tree $col 1]
      # Adjust columns
      if {$temp ne ""} {
         set len [font measure $font $temp]
         $w.tree column $col -minwidth $len -width $len -anchor center -stretch 0
      } else {
         $w.tree column $col -anchor w
      }
   }
   TileTable::FixIcon $w
#    ::TileTable::BandTable $w.tree
    return $w.tree
}
#----------------------------------------------------------------------------
# Populate the tree based on rows of metakit data
#----------------------------------------------------------------------------
proc ::TileTable::Populate {w rows headers template isFolder sortCol sortDir} {
   variable LU
   variable isaFolder $isFolder
   unset -nocomplain LU
   $w.tree delete [$w.tree children {}]
   # Always sort on last (end) header element by default
   #ArrowHeadings $w.tree [lindex $headers end] 1
   ArrowHeadings $w.tree $sortCol $sortDir
   # Row is a number index into metakit database
   foreach {row} $rows {
      lassign [db::tvOneRow $row] name sdate mdate existing pinned excluded hits isopen
      # get the icon
      if {$isFolder} {
         if {$excluded} {
            set icon [iconDB::extToIcon "filter"]
         } elseif {$pinned} {
            set icon [iconDB::extToIcon "pinned"]
         } else {
            set icon [iconDB::extToIcon "folder"]
         }
         # folders have one less column
         set datum [list $name $hits $mdate $sdate]
      } else {
         if {$excluded} {
            set icon [iconDB::extToIcon "filter"]
         } elseif {$pinned} {
            set icon [iconDB::extToIcon "pinned"]
         } else {
            set img [iconDB::nameToIcon $name $isFolder]
            # if we couldn't read the icon then the file no longer exists, remove it
            if {$img eq ""} {
               db::removeFile $name
               log "No Icon Exists, removed $name"
               continue
            }
            set icon $img
         }
         # filename and tail of folder
         set folder [file tail [file dirname $name]]
         set tail [file tail $name]
         set datum [list $tail $folder $hits $mdate $sdate] 
      }
      # populate the tree now
      if {$icon ne ""} {
         if {!$existing} {
            set item [$w.tree insert {} end -values $datum -tags "missing" -image $icon]
         } elseif {$isopen} {
            set item [$w.tree insert {} end -values $datum -tags "isopen" -image $icon]
         } else {
            set item [$w.tree insert {} end -values $datum -image $icon]
         }
      } else {
         set item [$w.tree insert {} end -values $datum]
      }
      # added 3/7/2017 to handle % in file name
#     set name [string map {% %%} $name]
      # entry to lookup
      set LU($item) [list $name $existing]
   }
   $w.tree tag configure "missing" -foreground gray
   $w.tree tag configure "isopen" -foreground blue
   # On resize make sure col 0 is sized
   TileTable::FixIcon $w
   # bind mouse events
   bind $w.tree <Motion>                {::TileTable::Over %W %x %y}
   bind $w.tree <ButtonPress-1>         {::TileTable::Clicked %W %x %y}
   bind $w.tree <ButtonPress-3>         {::TileTable::RMB %W %x %y %X %Y}
   # extended selection
   bind $w.tree <Control-ButtonPress-1> {::TileTable::SelectToggle %W %x %y}
   bind $w.tree <Shift-ButtonPress-1>   {::TileTable::SelectExtend %W %x %y}
   bind $w      <Control-KeyPress-a>    {::TileTable::SelectAll}
}
#------------------------------------------------------------------------------
#  Make sure col #0 is fixed for the icon display
#------------------------------------------------------------------------------
proc ::TileTable::FixIcon {w} {
   variable bias
   $w.tree column #0 -width 40 -minwidth 40 -anchor w -stretch 0 ;# icon column
}
#------------------------------------------------------------------------------
#  Bias the relative width of the file and folder names
#  doesn't cause any issues for the folder only case
#------------------------------------------------------------------------------
proc ::TileTable::FixWidth {w} {
   variable bias
   # give the file col a little more width than the folder col
   # weight would be nice, but treeview widget doesn't support it
   if {$bias != 0.5} {
       set tw [expr {[$w.tree column #1 -width] + [$w.tree column #2 -width]}] 
       set nc1 [expr {round($tw * $bias)}]
       set nc2 [expr {round($tw - $nc1)}]
       #log "$c1 $c2 $nc1 $nc2"
       $w.tree column #1 -width $nc1
       $w.tree column #2 -width $nc2
   }
}
#---------------------------------------------------------------------------- 
# Select all visible entries
#---------------------------------------------------------------------------- 
proc ::TileTable::SelectAll {args} {
   variable LU
   variable Tree
   $Tree selection set [array names LU]
}
#------------------------------------------------------------------------------
#  Select the item under the mouse
#------------------------------------------------------------------------------
proc ::TileTable::SelectToggle {tree X Y} {
   variable LU
   set extSel 1
}
proc ::TileTable::SelectExtend {tree X Y} {
   variable LU
   variable extSel
   set extSel 1
}
#---------------------------------------------------------------------------- 
# Something was clicked, launch it or extend selection
#---------------------------------------------------------------------------- 
proc ::TileTable::Clicked {tree X Y} {
   variable LU
   variable extSel
   try {
      if {$extSel==0} {
         # ignore clicking on headers or anything not a cell
         set region [$tree identify region $X $Y]
         if {$region eq "cell"} {
            set item [$tree identify item $X $Y]
            if {$item ne ""} {
               treeSearch::clicked $LU($item)
            }
         }
      } else {
         set extSel 0
         set item [$tree identify item $X $Y]
         if {$item ne ""} {
            $tree selection set $item
            $tree see $item
            treeSearch::highlighted [lindex $LU($item) 0]
         }
      }
   } on error result {
      log $result
   }
}
#------------------------------------------------------------------------------
# Right Mouse button
#------------------------------------------------------------------------------
proc ::TileTable::RMB {tree x y X Y} {
   variable LU
   variable extSel
   try {
      set sel [$tree selection]
      # Extemded selection
      if {[llength $sel]>1} {
         foreach {item} $sel {
            lassign $LU($item) file exists
            lappend files $file
         }
         treeSearch::rmbMulti $files $X $Y
         set extSel 0
      } else {
         # single selection
         set item [$tree identify item $x $y]
         if {$item ne ""} {
            treeSearch::rmb $LU($item) $X $Y
         }
      }
   } on error result {
      puts $result
   }
}

#------------------------------------------------------------------------------
#  Select the item under the mouse
#------------------------------------------------------------------------------
proc ::TileTable::Over {tree X Y} {
   variable LU
   variable extSel
   try {
      if {$extSel==0 && [llength [$tree selection]] <= 1} {
         set item [$tree identify item $X $Y]
         if {$item ne ""} {
            if {[$tree selection] ne $item} {
               $tree selection set $item
               $tree see $item
               treeSearch::highlighted [lindex $LU($item) 0]
            }
         }
      }
   } on error result {
      puts $result
   }
}
#proc ::TileTable::Over {tree X Y} {
#}

############################################################################
#
# ::TileTable::SortBy -- Code to sort tree content when clicked on a header
#
proc ::TileTable::SortBy {tree col direction} {
   # Build something we can sort
   variable lastSortCol
   variable lastSortDir
   variable isaFolder
   # Switch the heading so that it will sort in the opposite direction
   # only if same col clicked twice in a row
   if {$col eq $lastSortCol} {
      set direction [expr {!$direction}]
   } else {
      set direction $lastSortDir($lastSortCol)
   }
   # if data is not limited then sort in place
   # note HACK reference to S namespace
   set inSort [expr {[llength [$tree children {}]] <  $S::S(treeLimit)}]
   if {$inSort} {
      # Sort the data inplace by moving it
      set data {}
      foreach row [$tree children {}] {
         lappend data [list [$tree set $row $col] $row]
      }
   
      set dir [expr {$direction ? "-decreasing" : "-increasing"}]
      set r -1
   
      # Now reshuffle the rows into the sorted order
      foreach info [lsort -dictionary -index 0 $dir $data] {
         $tree move [lindex $info 1] {} [incr r]
      } 
   }

   ##########################################
   set cmd [list ::TileTable::SortBy $tree $col $direction]
   $tree heading $col -command $cmd
   ::TileTable::ArrowHeadings $tree $col $direction
   set lastSortCol $col
   set lastSortDir($col) $direction
   # data is refreshed in sorted order vs. sorting inplace
   # use for larger datasets where needed data may not be in the tree
   # HACK calling higher level function - bad idea
   if {!$inSort} {
      treeSearch::populate $isaFolder 0
   }
}
##+##########################################################################
#
# ::TileTable::ArrowHeadings -- Puts in up/down arrows to show sorting
# Default value and data should populate initially this way
#
proc ::TileTable::ArrowHeadings {tree sortCol dir} {
   variable lastSortCol
   variable lastSortDir
   set idx -1
   foreach col [$tree cget -columns] {
      incr idx
      set img ::TileTable::arrowBlank
      if {$col eq $sortCol} {
         set img ::TileTable::arrow($dir)
         set lastSortCol $col
         set lastSortDir($col) $dir
      }
      $tree heading $idx -image $img
   }
}
#---------------------------------------------------------------------------- 
# Return the last commanded/default sort info
#---------------------------------------------------------------------------- 
proc ::TileTable::getLastSortInfo {args} {
   variable lastSortCol
   variable lastSortDir
   return [list $lastSortCol $lastSortDir($lastSortCol)]
}
##+##########################################################################
#
# ::TileTable::BandTable -- Draws bands on our table
#
proc ::TileTable::BandTable {tree} {
    array set colors {0 white 1 "ghost white"}

    set id 1
    foreach row [$tree children {}] {
        set id [expr {! $id}]
        set tag [$tree item $row -tag]
        $tree tag configure $tag -background $colors($id)
    }
}

package provide tileTable 1.0
