#---------------------------------------------------------------------------- 
# Handle local dll files
#---------------------------------------------------------------------------- 
namespace eval pkgFunctions {
}
proc pkgFunctions::overLoadLoad {{usedir ""}} {
   if {$usedir ne ""} {
      set ::realRoot [file dirname $usedir]
   } elseif {[info exists ::starkit::topdir]} {
      set ::realRoot [file dirname $::starkit::topdir]
   } else {
      return
   }

   if {[info exists ::realRoot] && [file isdirectory $::realRoot]} {
   
      #------------------------------------------------------------------------------
      # Function   : load
      # Description: If files can be loaded locally, load them if possible
      # Author     : Tom Wilkason
      # Date       : 1/15/2003
      #------------------------------------------------------------------------------
      rename ::load ::_load
      proc ::load {args} {
         set packageName {}
         foreach {filename packageName} $args {break}
         set newfilename [file join $::realRoot [file tail $filename]]
         if {[file exists $newfilename] && [string length $filename]} {
            eval [list ::_load $newfilename $packageName]
         } else {
            eval [list ::_load $filename $packageName]
         }
      }
   }
}
package provide pkgFunctions 1.0


