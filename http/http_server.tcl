
package require logger
package require coroutine

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/http/request.tcl
source $trailsdir/http/response.tcl
source $trailsdir/http/util.tcl
source $trailsdir/http/router.tcl
source $trailsdir/http/http_parser.tcl
source $trailsdir/configs/configs.tcl

namespace import ::trails::http::Response
namespace import ::trails::http::Request


namespace eval ::trails::http {
  variable Controllers
  variable Filters
  variable log
	set log [logger::init http_server]
  set Controllers {}
  set Filters {}

  proc init {} {
    variable Filters
    set filters_objects [::trails::configs::get web filters objects]

    foreach obj $filters_objects {
      lappend Filters [$obj new]
    }
  }

  proc accept {socket addr port} {
    chan configure $socket -blocking 0 -buffering line
    chan event $socket readable [list ::trails::http::handle $socket $addr $port]  
  }

  proc handle {socket addr port} {
    variable log

    if { [eof $socket]} {
      ${log}::debug {channel is closed}
      http_connecton_close $socket
      return
    }

    try {
      
      set request [::trails::http::http_parser::parse_request $socket]
      set response [filter_and_dispatch $request]

      if {[$response bool websocket]} {

        set wsServer [app::get_ws_socket]
        puts "do websocket upgrade ${wsServer}"
        set headers [websocket_app::check_headers $headers]        
        websocket_app::upgrade $wsServer $socket $headers      

      } else {
        ::trails::http::util::send_response $socket $response        
      }

    } on error err {

      ${log}::error "$err: $::errorInfo"

      if {$err != "no data received -> close socket"} {
        ::trails::http::util::server_error $socket -body $err
      }

    } finally {

      set has_response false
      set is_websocket false

      if {[info exists request] && [info object isa object $request]} {
        $request destroy
      }      

      if {[info exists response] && [info object isa object $response]} {
        set has_response true
      }

      if {$has_response} {
        set is_websocket [$response bool websocket]
        $response destroy
      }      

      if {!$is_websocket} {
        http_connecton_close $socket 
      }
    }
  }

  proc http_connecton_close {socket} {
    catch {close $socket}
  }

  proc is_response {result} {
    expr {[info object isa object $result] && [info object class $result Response]}
  }

  proc is_request {result} {
    expr {[info object isa object $result] && [info object class $result Request]}
  }
 
  proc filter_and_dispatch {request} {
    variable Filters
    set filters_enter [::trails::configs::getdef web filters enter {}]
    set filters_leave [::trails::configs::getdef web filters leave {}]
    set filters_recover [::trails::configs::getdef web filters recover {}]


    foreach filter $Filters {
      set methods [info object methods $filter]
      if {[lsearch -exact $methods enter] > -1} {
        set result [$filter enter $request]
        if {[is_response $result]} {
          return $result
        } elseif {[is_request $result]} {
          set request $result
        } else {
          return -code error {wrong filter result}
        }          
      }
    }

    foreach enter $filters_enter {
      set result [$enter $request]
      if {[is_response $result]} {
        return $result
      } elseif {[is_request $result]} {
        set request $result
      } else {
        return -code error {wrong filter result}
      }
    }  

    try {
      set response [dispatch $request]
    } on error err {

      foreach filter $Filters {
        set methods [info object methods $filter]
        if {[lsearch -exact $methods recover] > -1} {
          set result [$filter recover $request $err]
          if {[is_response $result]} {
            set response $result
          }                  
        }
      }      

      foreach recover $filters_recover {
        set result [$recover $request $err]

        if {[is_response $result]} {
          set response $result
        }
      }

      if {![info exists response]} {
        return -code error $err
      }

    }
 
    foreach filter $Filters {
      set methods [info object methods $filter]
      if {[lsearch -exact $methods leave] > -1} {
        set response [$filter leave $request $response]
        if {![is_response $response]} {
          return -code error {wrong filter result}
        }      
      }
    }      

    foreach leave $filters_leave {        
      set response [$leave $request $response]
      if {![is_response $response]} {
        return -code error {wrong filter result}
      }
    }



    if {![is_response $response]} {
      return -code error {wrong response}
    }

    return $response
  }

  proc dispatch {request} {

    variable log
    variable Controllers

    ${log}::debug dispatch

    set path [$request prop path]
    set query [$request prop query]
    set method [$request prop method]
    set contentType [$request prop content-type]
    set headers [$request prop headers]
    set is_websocket false

    ${log}::debug "HTTP REQUEST: $method $path"

    if {[string match "/public/assets/*" $path]} {
      
      set path [::trails::configs::get assets]
      set map {} 
      lappend map "/public/assets" $path
      return Response new -file [string map $map $path]

    } else {

      try {

        set route [::trails::http::router::match $path $method]

        if { $route == "" } {
          ${log}::debug "404 $method $path"
          return Response new -status 404 -content-type $contentType
        }

        set is_websocket [$route prop websocket]

        if { ![$route can_handle] && !$is_websocket } {
          return Response new -status 500 -body {route can't be handled} -content-type $contentType
        }

        $request props \
                  params [$route prop params] \
                  roles [$route prop roles]

        set enter_handlers [$route prop enter]
        set leave_handlers [$route prop leave]

        foreach action $enter_handlers {

          set next [$action $request]

          if {[info object class $next Request]} {
            set request $next
          } elseif {[info object class $next Response]} {
            return $next
          } else {
            return Response new -status 500 -body {wrong filter return type} -content-type $contentType
          }
        }

        if {$is_websocket} {
          return Response new -websocket true
        }
        

        if {[$route has_handler]} {
        
          set handler [$route prop handler]
          set response [$handler $request]
        
        } elseif {[$route has_controller]} {
          
          set ctrl [$route prop controller]
          set action [$route prop action]

          if {[dict exists $Controllers $ctrl]} {
            set crtl_instance [dict get $Controllers $ctrl]
          } else {
            set crtl_instance [$ctrl new]
            dict set Controllers $ctrl $crtl_instance
          }

          set response [$crtl_instance dispatch_action $action $request]

        } else {
          return Response new -status 500 -body {route handler not found} -content-type $contentType
        }

        if {![info object isa object $response] || ![info object class $response Response]} {

          set response [parse_response $request $response]
          
        } 

        foreach action $leave_handlers {
          set response [$action $request $response]  
          if {![info object class $response Response]} {
            return Response new -status 500 -body {wrong filter return type} -content-type $contentType
          }        
        }

        return $response

      } finally {
        if {[info exists route] && [info object isa object $route]} {
          $route destroy

        }      
      }
    }        
  }
  # {200 {body content} text/plain {headers}}
  # {text {bdody} -headers {} -status {}}
  # {json {bdody} -headers {} -status {}}
  # {html {bdody} -headers {} -status {}}
  # {template name context}
  proc parse_response {request response} {
    variable log
    
    #puts "::> response $response"

    set n [llength $response]

    if {$n == 0 || $n > 4} {      
      ${log}::debug "response list expect count > 0 and < 4, but receive count $n"
      return -code error {invalid response}            
    }

    set first [lindex $response 0]
    set resp [Response new -content-type [$request prop content-type] -status 200]

    switch -regexp -- $first {
      text|json|html {
        if {$n == 1} {
          ${log}::debug "response list expect count > 1, but receive count $n"
          return -code error {invalid response}
        }

        set ctype text/plain

        switch $first {
          json { set ctype application/json }
          html { set ctype text/html }
        }

        $resp prop content-type $ctype
        $resp prop body [lindex $response 1]

        set idx [lsearch -exact $response -headers]
        if {$idx > -1} {
          $resp prop headers [lindex $response [incr idx]]                
        }

        set idx [lsearch -exact $response -status]
        if {$idx > -1} {
          $resp prop status [lindex $response [incr idx]]                
        }

      }
      template {
        # TODO  implements template
      }
      {[0-9]+} {
        $resp prop status $first
        if {$n > 1} {
          $resp prop body [lindex $response 1]
        }
        if {$n > 2} {
          $resp prop content-type [lindex $response 2]
        }
        if {$n > 3} {
          $resp prop headers [lindex $response 3]
        }
      } 
      default {
        ${log}::debug {wrong response list}
        return -code error {invalid response}
      }
    }

    return $resp    
  }

}

