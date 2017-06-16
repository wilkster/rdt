#---------------------------------------------------------------------------- 
# Misc tools
#---------------------------------------------------------------------------- 

# Show a transient window, withdraw the usual window while that is visible
  #
proc center_transient_window { w } {

   tk::PlaceWindow $w [winfo parent $w]

#   set width [winfo reqwidth $w]
#   set height [winfo reqheight $w]
#   set x [expr { ( [winfo vrootwidth  $w] - $width  ) / 2 }]
#   set y [expr { ( [winfo vrootheight $w] - $height ) / 2 }]
#
#   # Hand the geometry off to the window manager
#
#   wm geometry $w ${width}x${height}+${x}+${y}
}


#------------------------------------------------------------------------------
# Flash a note on the screen
#------------------------------------------------------------------------------
proc flashNote {txt {duration 2000}} {
   set T .transient
   destroy $T 
   toplevel $T -background black
   wm overrideredirect $T 1
   wm transient        $T
   
   label $T.lab -text $txt -bg black -height 1 -fg cyan -font {-size -24}
   grid  $T.lab -sticky nsew -padx 6 -pady 6
   update
   tk::PlaceWindow $T [winfo parent $T]
   wm attributes $T -topmost

   #center_transient_window $T
   after $duration [list destroy $T]
}

#------------------------------------------------------------------------------
# Function   : Scrolled_Listbox
# Description: Utility function to create a scrolled listbox
# Author     : Tom Wilkason
#------------------------------------------------------------------------------
proc Scrolled_Listbox { f args } {
   frame $f
   listbox $f.list \
      -xscrollcommand [list scrollCmd $f.xscroll  [list grid $f.xscroll -row 1 -column 0 -sticky ew]] \
      -yscrollcommand [list scrollCmd $f.yscroll  [list grid $f.yscroll -row 0 -column 1 -sticky ns]]
   eval {$f.list configure} $args
   ::ttk::scrollbar $f.xscroll -orient horizontal -command [list $f.list xview]
   ::ttk::scrollbar $f.yscroll -orient vertical   -command [list $f.list yview]
   grid $f.list -sticky news
   ##
   # Only the data should expand, not the scroll bars
   #
   grid rowconfigure    $f 0 -weight 1
   grid columnconfigure $f 0 -weight 1
   ##
   # Modify to not resize when the scroll bars go away (make a minimum size)
   #
   grid columnconfigure $f 1 -minsize 0 ;#1
   grid rowconfigure    $f 1 -minsize 0 ;#1

   return $f.list
}
#------------------------------------------------------------------------------
# Function   : scrollCmd
# Description: Generic callback to show/hide scrollbars when needed
#              scroll bars if they aren't needed
# Author     : Tom Wilkason
#------------------------------------------------------------------------------
proc scrollCmd {scrollbar geoCmd offset size} {
   catch {
      if {$offset > 0.02 || $size != 1.0} {
         eval $geoCmd
         $scrollbar set $offset $size
      } else {
         set manager [lindex $geoCmd 0]
         $manager forget $scrollbar
      }
   }
}
#------------------------------------------------------------------------------
# return the file extension
#------------------------------------------------------------------------------
proc fileExt {name} {
   return [string tolower [string trimleft [file extension $name] "."]]
}
#----------------------------------------------------------------------------
# Needed to create a menu font that matches the current system font
#----------------------------------------------------------------------------
proc createMenuFont {args} {
   menu .temp
   array set fm [font actual [.temp cget -font]]
   font create menu \
      -size $fm(-size) \
      -family $fm(-family) \
      -slant $fm(-slant) \
      -weight normal
   destroy .temp
}
proc afters {args} {
   foreach after [after info] {puts "[after info $after]=$after"}
}
#------------------------------------------------------------------------------
# Background error, stack trace has callers
#------------------------------------------------------------------------------
proc bgerror {msg} {
   puts stderr "[clock format [clock seconds] -format {%D %T}] '$msg' $::errorCode\n$::errorInfo"
}
#------------------------------------------------------------------------------
#  Log functions
#------------------------------------------------------------------------------
proc log {str} {
   set who [lindex [split [info level [expr [info level] - 1]]] 0]
   if {$who eq [lindex [info level 0] 0]} {
      puts stdout "[clock format [clock seconds] -format {%D %T}] $str"
   } else {
      puts stdout "[clock format [clock seconds] -format {%D %T}] '$who' $str"
   }
}
#---------------------------------------------------------------------------- 
# Errors have more info
#---------------------------------------------------------------------------- 
proc logerr {str} {
   set who [lindex [split [info level [expr [info level] - 1]]] 0]
   if {$who eq [lindex [info level 0] 0]} {
      puts stderr "[clock format [clock seconds] -format {%D %T}] $str\n$::errorInfo"
   } else {
      puts stderr "[clock format [clock seconds] -format {%D %T}] '$who' $str\n$::errorInfo"
   }
}
#---------------------------------------------------------------------------- 
# Raw log for thread
#---------------------------------------------------------------------------- 
proc tlog {str} {
   puts stdout $str
}
proc tlogerr {str} {
   puts stderr $str
}
#---------------------------------------------------------------------------- 
# Thread error handlers
#---------------------------------------------------------------------------- 
proc logTerr {who error} {
   puts stderr "[clock format [clock seconds] -format {%D %T}] '$who' $error"
}
#----------------------------------------------------------------------------
# Return the function name of the caller
#----------------------------------------------------------------------------
proc whocalled { } {
    return [lindex [split [info level [expr [info level] - 2]]] 0]
}
#------------------------------------------------------------------------------
#  tk error built in error handler
#------------------------------------------------------------------------------
proc ::tkerror {args} {
   debug $args
   debug $::errorInfo
}

#=============================================================================
proc K {a b} {set a}
##
# Pop an item off a list, left or right
#
proc lpop {how listName} {
   upvar $listName list
   switch -- $how {
      "right" {
   #      K [lindex $list end] [set list [lrange $list 0 end-1]]
         set r [lindex $list end]
         set list [lreplace $list [set list end] end] ; # Make sure [lreplace] operates on unshared object
         return $r
      }
      "left" {
   #      K [lindex $list 0] [set list [lrange $list 1 end]]
         set r [lindex $list 0]
         set list [lreplace $list [set list 0] 0] ; # Make sure [lreplace] operates on unshared object
         return $r
      }
      default {
         return -code error "lpop right|left listName"
      }
   }
}

##
# Push an item onto a list, left or right
#
proc lpush {how listName item} {
   upvar $listName list
   switch -- $how {
      "right" {
         lappend list $item
      }
      "left" {
         # Note: list must exist first
         set list [linsert [K $list [set list {}]] 0 $item]
      }
      default {
         return -code error "lpush right|left listName item"
      }
   }
}
proc getOpenApps {args} {
   foreach {hwnd} [twapi::find_windows -caption 1 -toplevel 1 -visible 1] {
      set pid [twapi::get_window_process $hwnd]
      set app [twapi::get_process_name $pid]
      set caption [twapi::get_window_text $hwnd]
      if {$caption ne ""} {
         set opts [twapi::get_window_style $hwnd]
         #log "$app - $opts"
         # ignore toolwindows
         if {"toolwindow" ni $opts} {
            log "$app - $caption"
         }
      }
   }
}

package provide miscTools 1.0
#
# # same as lpop right 25x faster though
# proc rshift {listVar} {
#    upvar 1 $listVar lst
#    set r [lindex $lst end]
#    # this is magic to me
#    set lst [lreplace $lst [set lst end] end] ; # Make sure [lreplace] operates on unshared object
#    return $r
# }
# proc lshift {listVar} {
#    upvar 1 $listVar lst
#    set r [lindex $lst 0]
#    set lst [lreplace $lst [set lst 0] 0] ; # Make sure [lreplace] operates on unshared object
#    return $r
# }
#
#
# # this is all test code below
#
# #----------------------------------------------------------------------------
# # Measure file check times, TS1 is a little faster than TS2 ~5%
# #----------------------------------------------------------------------------
# # proc testTS1 {args} {
# #    foreach row [db::fileListRows *Col* 0] {
# #       set File [db::getValbyRow $row "File"]
# #       try {
# #          file stat $File T
# #       } on error result {
# #          puts $result
# #       }
# #    }
# # }
# #
# # proc testTS2 {args} {
# #    foreach row [db::fileListRows *Col* 0] {
# #       set File [db::getValbyRow $row "File"]
# #       try {
# #          set T [twapi::get_file_times $File -all]
# #       } on error result {
# #          puts $result
# #       }
# #    }
# # }
#
# #----------------------------------------------------------------------------
# # Measure file check times, TS1(a) is a little faster that TS2 ~10%
# #----------------------------------------------------------------------------
# proc testTS0 {args} {
#    foreach row [db::fileListRows * 0] {
#       set File [db::getValbyRow $row "File"]
#    }
# }
# proc testTS1 {args} {
#    foreach row [db::fileListRows * 0] {
#       set File [db::getValbyRow $row "File"]
#       tsv::lpush T Q $File end
#    }
#    while {[tsv::llength T Q] > 0} {
#       tsv::lpop T Q 0
#    }
# }
# ##
# # Same speed as above, just reverse direction
# #
# proc testTS1a {args} {
#    foreach row [db::fileListRows * 0] {
#       set File [db::getValbyRow $row "File"]
#       tsv::lpush T Q $File 0
#    }
#    while {[tsv::llength T Q] > 0} {
#       tsv::lpop T Q end
#    }
# }
# # TS2 is about 10% faster than TS2A
# proc testTS2 {args} {
#    foreach row [db::fileListRows * 0] {
#       set File [db::getValbyRow $row "File"]
#       lpush right T $File
#    }
#    while {[llength $T] > 0} {
#       lpop left T
#    }
# }
# # this is the slowest by a wide margin
# proc testTS2a {args} {
#    set T [list]
#    foreach row [db::fileListRows * 0] {
#       set File [db::getValbyRow $row "File"]
#       lpush left T $File
#    }
#    while {[llength $T] > 0} {
#       lpop right T
#    }
# }
# #------------------------------------------------------------------------------
# #
# #------------------------------------------------------------------------------
# proc tst {args} {
#    set tlst [list]
#    for {set i 0} {$i < 100000} {incr i} {
#       lappend tlst $i
#    }
#    log [time {lpop left tlst} 90000]
#    puts [llength $tlst]
#    set tlst [list]
#
#    for {set i 0} {$i < 100000} {incr i} {
#       lappend tlst $i
#    }
#    log [time {lshift tlst} 90000]
#    puts [llength $tlst]
#    for {set i 0} {$i < 100000} {incr i} {
#       lappend tlst $i
#    }
#    log [time {rshifts tlst} 90000]
#    puts [llength $tlst]
# }
#
# #------------------------------------------------------------------------------
# #
# #------------------------------------------------------------------------------
# proc tst {args} {
#    foreach {tst} {testTS0 testTS1 testTS1a testTS2 testTS2a} {
#       log "$tst [time $tst 5]"
#    }
# }
# # recursive test
# # recTest "C:/users/tom"
# proc recTest {base} {
#    foreach {file} [glob -nocomplain -directory $base *] {
#       set file [file nativename $file]
#       if {[file isdirectory $file]} {
#          recTest $file
#          update
#       }
#    }
# }
# proc recTesta {base} {
#    foreach {dir} [dirList $base] {
#       foreach {fl} [glob -nocomplain -directory $dir -types f *] {
#          puts [file nativename $fl]
#       }
#    }
# }
# # set base {"C:/Users/tom/Google Drive"}
#
# proc dirList {{dirs .}} {
#    set dirs [list [string map {\\ /} $dirs]]
#    while {[llength $dirs]} {
#       set name [lindex $dirs 0]
#       # replace the first folder with a list of child folders, then consume each one replacing it with any children
#       set dirs [lreplace $dirs 0 0 {*}[glob -nocomplain -directory $name -type {d r} *]]
#       lappend dirNames [file nativename $name]
#    }
#    return $dirNames
# }
