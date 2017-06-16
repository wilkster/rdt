
#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#  Restore the icon image cache
#------------------------------------------------------------------------------
proc iconDB::unSpool {args} {
   variable extToImage
   foreach {img h} [array get extToImage] {
      set ::spool($img) [$h data -format png]
      image delete $h
   }
   array unset extToImage
   foreach {img h} [array get ::spool] {
      set extToImage($img) [image create photo -data $h]
   }
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
         array set Icons [read $fid]
         foreach {img h} [array get Icons] {
            set extToImage($img) [image create photo -data $h]
         }
      } on error result {
         logerr $result   
      } finally {
         close $fid
      }
   } else {
      logerr "$iconDB does not exist"
   }
}
#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
proc menuTest {args} {
   #Creating the menu
   destroy .tl
   toplevel .tl
   menu .tl.menu -tearoff 0
   .tl.menu add command -label "Copy" -command callback
   .tl.menu add command -label "Paste" -command callback
   .tl.menu add command -label "One"  -command callback
   .tl.menu add command -label "two"  -command callback
   
   #Creating the text area
   text .tl.t
   scrollbar .tl.sby -orient vert
   pack .tl.sby .tl.t -expand yes -fill both -side right 
   
   #Creating binding
   bind .tl.t <1> {popupMenu .tl.menu %x %y} 
   bind .tl.menu <3> [list callback %x %y]
   bind .tl.menu <FocusOut> {puts out}
   
   #A function to pop up the menu
}
proc popupMenu {theMenu theX theY} {
    set x [expr [winfo rootx .]+$theX]
    set y [expr [winfo rooty .]+$theY]
    tk_popup $theMenu {*}[winfo pointerxy .] 
}
#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
proc callback {args} {
   puts $args
}

set F {C:\Windows\explorer.exe}
twapi::generate_code_from_typelib $F
                                  
proc winTaskBar::comtest  {icon} {
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
               lappend open  [$ws $fName]
               $ws -destroy
            }
         } on error result {
            logerr $result
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
winTaskBar::comtest excel
proc winTaskBar::getComOpen {icon} {
   variable Com
   set open [list]
   set icon [string tolower $icon]
   # check array here
   if {[info exists Com($icon)]} {
      lassign $Com($icon) Object DocType fName
      try {
         set comObj [twapi::comobj $Object -active]
      } on error result {
         # app is not open, return null list
         return $open
      }
      # App was open, get the list of open files
      try {
         set DC [$comObj $DocType]
         $DC -iterate ws {
            lappend open  [$ws $fName]
            $ws -destroy
         }
      } on error result {
         logerr $result
      } finally {
         $DC -destroy
         $comObj -destroy
      }
   }
   return $open
}
proc test {args} {
   set comObj [twapi::comobj  "Excel.Application" -active]
   $comObj -with {
      $comObj "WorkBooks"
      -iterate ws {
         lappend open  Excel.Application WorkBooks FullName
      }
   }
   $comObj destroy
}
proc testxx {args} {
   try {
      foreach {pid} [::twapi::get_process_ids] {
         #set hwins [::twapi::get_toplevel_windows -pids $pid]
         set hwins [::twapi::find_windows -toplevel 1 -visible 1 -minimizebox 1 -pids $pid]
         if {$hwins ne ""} {
            log "[::twapi::get_process_info $pid -name]"
            foreach {hwin} $hwins {
               if {[::twapi::get_foreground_window] eq $hwin} {
                  log "     [::twapi::get_window_class $hwin] foreground"
               } else {
                  log "     [::twapi::get_window_class $hwin]"
               }
            }
            # log "[::twapi::get_process_info $pid -name] [::twapi::get_window_class $hwin]"
         }
      }
      
   } on error result {
      log $::errorInfo
   }   
}


#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
#::twapi::start_device_notifier deviceNotifier
proc deviceNotifier {args} {
   log $args
}

#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
proc whoIsMounted {args} {
   foreach {vol} [twapi::find_logical_drives] {
      puts $vol
      try {
         puts "  type: [twapi::get_drive_type $vol]"
         puts "  fstype: [twapi::get_volume_info $vol -fstype]"   ;# trigger error if offline
      } on error result {
         puts "  offline"
         # flag all datbase drives as not mounted
      }
   }
   foreach {cs} [twapi::get_client_shares] {
      set info [twapi::get_client_share_info $cs -status]
      puts "$cs -> $info"
      #-status connected
   }
}
#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
set hotKeyId [::twapi::register_hotkey {Alt-Space} toggleOnTop] ;#5
proc toggleOnTop {args} {
   set hwin [::twapi::get_foreground_window]
   if {$hwin ne ""} {
      set styles [::twapi::get_window_style $hwin]
      # toggle here
      if {"topmost" in $styles} {
         ::twapi::set_window_zorder $hwin "bottomlayer"
         ::twapi::flash_window $hwin -period 150
      } else {
         ::twapi::set_window_zorder $hwin "toplayer"
         ::twapi::flash_window $hwin -period 350
      }
   }
}
#http://nehe.gamedev.net/article/msdn_virtualkey_codes/15009/ w/o the VK_
::twapi::unregister_hotkey $hotKeyId
#    foreach {hwin} [::twapi::get_toplevel_windows -pids [::twapi::get_process_ids]] {
#       log "[::twapi::get_window_class $hwin] [::twapi::get_window_text $hwin]"
#       if {[lsearch [::twapi::get_window_style $hwin] "appwindow"] > 0} {
#          # log "[::twapi::get_window_class $hwin] [::twapi::get_window_text $hwin]"
#       }
#    }
}
# on top
# twapi::set_window_zorder HWIN POS
::twapi::get_window_text [::twapi::get_foreground_window]


##+##########################################################################
#
# tileTable.tcl -- Creates multi-column table using tile's treeview widget
# by Keith Vetter, March 21, 2008
# KPV Jun 03, 2008 - added sort arrows on column headers
#

package require Tk
package require tile

namespace eval ::TileTable {}

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

    ::ttk::treeview $w.tree -columns $headers -show headings \
        -yscroll "$w.vsb set" -xscroll "$w.hsb set" -selectmode browse
    scrollbar $w.vsb -orient vertical -command "$w.tree yview"
    scrollbar $w.hsb -orient horizontal -command "$w.tree xview"

    grid $w.tree $w.vsb -sticky nsew
    grid $w.hsb          -sticky nsew
    grid column $w 0 -weight 1
    grid row    $w 0 -weight 1

    set font [::ttk::style lookup [$w.tree cget -style] -font]
    foreach col $headers {
        set name [string totitle $col]
        $w.tree heading $col -text $name -image ::TileTable::arrowBlank \
            -command [list ::TileTable::SortBy $w.tree $col 0]
        $w.tree column $col -anchor c -width [font measure $font xxx$name]
    }

    set lnum -1
    foreach datum $data {
        $w.tree insert {} end -values $datum -tag tag[incr lnum]

        # Fix up column widths
        foreach col $headers value $datum {
            if {$col eq ""} break
            set len [font measure $font "$value  "]
            if {[$w.tree column $col -width] < $len} {
                $w.tree column $col -width $len
            }
        }
    }
    ::TileTable::BandTable $w.tree
}
##+##########################################################################
#
# ::TileTable::SortBy -- Code to sort tree content when clicked on a header
#
proc ::TileTable::SortBy {tree col direction} {
    # Build something we can sort
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

    # Switch the heading so that it will sort in the opposite direction
    set cmd [list ::TileTable::SortBy $tree $col [expr {!$direction}]]
    $tree heading $col -command $cmd
    ::TileTable::BandTable $tree
    ::TileTable::ArrowHeadings $tree $col $direction
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

#
# Demo code
#
set headers {country capital currency}
set data {
    {Argentina          "Buenos Aires"          ARS}
    {Australia          Canberra                AUD}
    {Brazil             Brazilia                BRL}
    {Canada             Ottawa                  CAD}
    {China              Beijing                 CNY}
    {France             Paris                   EUR}
    {Germany            Berlin                  EUR}
    {India              "New Delhi"             INR}
    {Italy              Rome                    EUR}
    {Japan              Tokyo                   JPY}
    {Mexico             "Mexico City"           MXN}
    {Russia             Moscow                  RUB}
    {"South Africa"     Pretoria                ZAR}
    {"United Kingdom"   London                  GBP}
    {"United States"    "Washington, D.C."      USD}
}
console show
update
toplevel .top
::TileTable::Create .top $headers $data
set tree .top.tree
set ent [grid [entry .top.ent -textvariable -ent -text "hello"] -sticky nsew]
return




proc totalGeometry {{w .}} {
   set geom [wm geometry $w]
   regexp -- {([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)} $geom -> \
    width height decorationLeft decorationTop
   set contentsTop [winfo rooty $w]
   set contentsLeft [winfo rootx $w]
   # Measure left edge, and assume all edges except top are the
   # same thickness
   set decorationThickness [expr {$contentsLeft - $decorationLeft}]
   # Find titlebar and menubar thickness
   set menubarThickness [expr {$contentsTop - $decorationTop}]
puts  "$decorationThickness  $menubarThickness"
   incr width [expr {2 * $decorationThickness}]
   incr height $decorationThickness
   incr height $menubarThickness
   return [list $width $height $decorationLeft $decorationTop]
}
proc getBorderWidth {{w .}} {
   set geom [wm geometry $w]
   regexp -- {([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)} $geom -> \
    width height decorationLeft decorationTop
   set contentsTop [winfo rooty $w]
   set contentsLeft [winfo rootx $w]
   # Measure left edge, and assume all edges except top are the
   # same thickness
   set decorationThickness [expr {$contentsLeft - $decorationLeft}]
   # Find titlebar and menubar thickness
   set menubarThickness [expr {$contentsTop - $decorationTop}]
   return [list $decorationThickness  $menubarThickness]
}




#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
proc test {app} {
   # Get all pids with that app name
   set pids [twapi::get_process_ids -glob -name $app]
   log $pids
   # Only minimize if they are marked as visible. This is important
   # else hidden windows will be placed on the taskbar as icons
   foreach h [twapi::find_windows -pids $pids -visible true -match glob -toplevel 1] {
      set txt [twapi::get_window_text $h]
      log $txt
      #twapi::minimize_window $hwin
   }
}
