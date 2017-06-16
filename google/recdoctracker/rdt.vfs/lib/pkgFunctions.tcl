#---------------------------------------------------------------------------- 
# Handle local dll files
#---------------------------------------------------------------------------- 
namespace eval pkgFunctions {
}
proc pkgFunctions::overLoadLoad {args} {
   if {[namespace exists ::starkit]} {
      # Note: Dual dirname since SnackAmp/wrap is location
      # of info script
      set ::realRoot [file dirname $::starkit::topdir]
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
            #puts "load-local $newfilename $packageName $filename"
            eval [list ::_load $newfilename $packageName]
         } else {
            #puts "load-virtual $newfilename $packageName $filename"
            eval [list ::_load $filename $packageName]
         }
      }
   }
}
package provide pkgFunctions 1.0
