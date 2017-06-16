#------------------------------------------------------------------------------
# 
#------------------------------------------------------------------------------
set DI [twapi::start_device_notifier hwMonitor -deviceinterface {6fe69556-704a-47a0-8f24-c28d936fda47}]
set HI [twapi::start_power_monitor hwMonitor]

proc hwMonitor {args} {
   log $args
}

