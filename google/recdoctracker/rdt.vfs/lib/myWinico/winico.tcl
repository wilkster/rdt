;# *************************************************************************
;# * File   : winico.tcl
;# * Purpose: Provide wrapper functions for the winico package
;# *          Loads the winico dll first.
;# *************************************************************************
load [file join [file dirname [info script]] winico.dll]
###############################################################################
# Function   : winico_seticon
# Description: Be smart about selecting the most appropriate icon from the
#              icon file.
###############################################################################
proc winico_seticon { w icofile } {
   set ico [winico create $icofile]
   set screendepth [winfo screendepth .]
   set bigsize "32x32"
   set bigpos -1
   set bigdepth 0
   set smallsize "16x16"
   set smallpos -1
   set smalldepth 0
   set tki ""
   foreach i [winico info $ico] {
      array set opts $i
      set depth    $opts(-bpp)
      set pos      $opts(-pos)
      set geometry $opts(-geometry)
      if { $geometry=="$bigsize" && $depth<=$screendepth } {
         if { $depth>$bigdepth } {
            set bigpos $pos
            set bigdepth $depth
         }
      } elseif { $geometry=="$smallsize" && $depth<=$screendepth } {
         if { $depth>$smalldepth } {
            set smallpos $pos
            set smalldepth $depth
         }
      }
   }
   if { $bigpos==-1 && $smallpos==-1 } {
      puts stderr "couldn't find $bigsize and $smallsize icons in $icofile"
      return $ico
   } elseif { $bigpos==-1 } {
      set bigpos $smallpos
      puts stderr "couldn't find $bigsize icons in $icofile"
   } elseif { $smallpos==-1 } {
      set smallpos $bigpos
      puts stderr "couldn't find $smallsize icons in $icofile"
   }
   #puts stderr "big icon is $bigsize,bpp:$bigdepth,pos:$bigpos"
   #puts stderr "small icon is $smallsize,bpp:$smalldepth,pos:$smallpos"
   # set the window icon along with returning the icon itself for the tray
   winico setwindow $w $ico big   $bigpos
   winico setwindow $w $ico small $smallpos
   return $ico
}
###############################################################################
# Function   : winico_delall
# Description: Remove all icon instances
###############################################################################
proc winico_delall {} {
   foreach i [winico info] { winico delete $i }
}
###############################################################################
# Function   : winico_loadicon
# Description: Set up all big/small icons for a specified window
###############################################################################
proc winico_loadicon { w symbol } {
   set ico [winico load $symbol]
   winico setwindow $w $ico big
   winico setwindow $w $ico small
}
package provide Winico 0.6


