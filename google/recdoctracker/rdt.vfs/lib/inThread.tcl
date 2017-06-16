namespace eval inThread {
}

proc inThread::listMissing {files} {
   set result [list]
   foreach {file} $files {
      if {![file exists $file]} {
         lappend result $file
      }
   }
   return $result
}
package provide inThread 1.0

