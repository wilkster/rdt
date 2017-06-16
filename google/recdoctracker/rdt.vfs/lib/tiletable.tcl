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
   variable lastCol
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
proc ::TileTable::Create {w headers data} {
   variable lastCol "xxx"
   variable font

    ::ttk::treeview $w.tree -columns $headers -show {tree headings} \
        -yscroll "$w.vsb set" -xscroll "$w.hsb set" -selectmode browse
    scrollbar $w.vsb -orient vertical -command "$w.tree yview"
    scrollbar $w.hsb -orient horizontal -command "$w.tree xview"

    grid $w.tree $w.vsb -sticky nsew
    grid $w.hsb         -sticky nsew
    grid column $w 0 -weight 1
    grid row    $w 0 -weight 1

    set font [::ttk::style lookup [$w.tree cget -style] -font]
    foreach col $headers {
        set name [string totitle $col]
        $w.tree heading $col -text $name -image ::TileTable::arrowBlank \
            -command [list ::TileTable::SortBy $w.tree $col 1]
        $w.tree column $col -anchor c -width [font measure $font xxx$name]
    }

 #   ::TileTable::BandTable $w.tree
    return $w.tree
}
#----------------------------------------------------------------------------
# Populate the tree
#----------------------------------------------------------------------------
proc ::TileTable::Populate {w files headers data icons} {
   variable font
   variable extToImage
   set lnum -1
   $w.tree delete [$w.tree children {}]
   # Always sort on last header element by default
   ArrowHeadings $w.tree [lindex $headers end] 1

   foreach datum $data file $files icon $icons {
      lassign $file fl mounted
      incr lnum
      if {$icon ne ""} {
         if {!$mounted} {
            set item [$w.tree insert {} end -values $datum -tags [list tag$lnum "unmounted"] -text "" -image $icon]
         } else {
            set item [$w.tree insert {} end -values $datum -tags tag$lnum -text "" -image $icon]
         }
      } else {
         set item [$w.tree insert {} end -values $datum -tags tag$lnum]
      }
      $w.tree tag bind tag$lnum <1> [list treeSearch::clicked $file]
      $w.tree tag bind tag$lnum <Double-1> [list treeSearch::clicked $file]
      #$w.tree tag bind tag$lnum <1> [list treeSearch::highlighted [lindex $file 0]]
      #$w.tree tag bind tag$lnum <1> [list treeSearch::highlighted [lindex $file 0]]
      $w.tree tag bind tag$lnum <3> [list treeSearch::rmb $file %X %Y]
      $w.tree tag bind tag$lnum <Motion> [list ::TileTable::Over $w.tree $item $file]
      $w.tree tag configure unmounted -foreground gray

      #tooltip::tooltip $w.tree -items tag$lnum "This is some help for $file"
      #http://wiki.tcl.tk/24636  (enter/leave events)


      # Fix up column widths
       $w.tree column #0 -width 50  ;# icon column
       foreach col $headers value $datum {
          if {$col eq ""} break
          $w.tree column $col -anchor w
          set len [font measure $font "$value  "]
          if {[$w.tree column $col -width] < $len} {
             $w.tree column $col -width $len
          }
       }
   }
}

#------------------------------------------------------------------------------
#  Select the item under the mouse
#------------------------------------------------------------------------------
proc ::TileTable::Over {tree item file} {
   try {
      if {[$tree selection] ne $item} {
         $tree selection set $item
         $tree see $item
         treeSearch::highlighted [lindex $file 0]
      }
   } on error result {
      puts $result
   }
}
##+##########################################################################
#
# ::TileTable::SortBy -- Code to sort tree content when clicked on a header
#
proc ::TileTable::SortBy {tree col direction} {
    # Build something we can sort
    variable lastCol
    # Switch the heading so that it will sort in the opposite direction
    # only if same col clicked twice in a row
    if {$col eq $lastCol} {
      set direction [expr {!$direction}]
    } else {
      set direction 1
    }
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

    set cmd [list ::TileTable::SortBy $tree $col $direction]
    $tree heading $col -command $cmd
#    ::TileTable::BandTable $tree
    ::TileTable::ArrowHeadings $tree $col $direction
    set lastCol $col
}
##+##########################################################################
#
# ::TileTable::ArrowHeadings -- Puts in up/down arrows to show sorting
#
proc ::TileTable::ArrowHeadings {tree sortCol dir} {
    set idx -1
    foreach col [$tree cget -columns] {
        incr idx
        set img ::TileTable::arrowBlank
        if {$col == $sortCol} {
            set img ::TileTable::arrow($dir)
        }
        $tree heading $idx -image $img
    }
}
##+##########################################################################
#
# ::TileTable::BandTable -- Draws bands on our table
#
proc ::TileTable::BandTable {tree} {
    array set colors {0 white 1 \#aaffff}

    set id 1
    foreach row [$tree children {}] {
        set id [expr {! $id}]
        set tag [$tree item $row -tag]
        $tree tag configure $tag -background $colors($id)
    }
}

package provide tileTable 1.0
