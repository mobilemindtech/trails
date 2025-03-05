	#!/bin/tclsh

package require logger 0.3
package require TclOO

source $::env(TRAILS_HOME)/misc/util.tcl
source $::env(TRAILS_HOME)/misc/props.tcl


namespace import ::trails::misc::props::Props

namespace eval ::trails::http::router {

	variable log
	variable routes
	
	set log [logger::init router]
	set routes {}

	catch {
		oo::class create Route {
			superclass Props
		}
	}

	namespace export Route

	oo::define Route {

		constructor {} {
			next routes \
				roles \
				methods \
				handler \
				enter \
				leave \
				websocket \
				path \
				controller \
				action \
				repath \
				variables \
				params
		}

		method has_subroutes {} {
			set l [llength [my prop routes] ]
			expr {$l > 0}
		}

		method has_method {method} {
			set methods [my prop methods]
			set methods [split $methods ,]

			if {[llength $methods] == 0} {
				return true
			}

			foreach m $methods {
				if {[string toupper $method] == [string toupper $m]} {
					return true
				}
			}
			return false
		}		

		method can_handle {} {
			expr {[my present handler] || ([my present controller] && [my present action])}
		}

		method has_handler {} {
			expr {[my present handler]}
		}

		method has_controller {} {
			expr {[my present controller]}
		}

		method clone {} {
			variable allowed_props
			set route [::trails::http::router::Route new]
			foreach name $allowed_props {
				$route prop $name [my prop $name]
			}
			return $route
		}
	}

	proc get_uri_query {uri} {
	  set parts [split $uri ?]
	  set queries [lindex $parts 1]
	  set requestQuery [dict create]

	  foreach var [split $queries "&"] {
	    if { [string trim $var] == "" } {
	      continue
	    }
	    set param [split $var "="]
	    set k [lindex $param 0] 
	    set v [lindex $param 1]
	    dict set requestQuery $k $v 
	  }  
	  return $requestQuery
	}


	proc extract_route_and_variables {cfg_route} {

		set variables {}

		set parts [split $cfg_route /]
		set n [llength $parts]
		set route ""
		
		for {set i 0} {$i < $n} {incr i} {

			set part [lindex $parts $i]

			if {$part == ""} {
				continue
			}

			# if path starts with : is path var
			if {[string match :* $part]} {

				set param ""
				set re ""

				# find path var and regex
				regexp -nocase {:([a-zA-Z_]*\(?/?)(\(.+\))?} $part -> param re

				# empty regex
				if {$re == ""} {
					set re {.+}
				} else {
					# remve ()
					set re [regsub {\(} $re ""]
					set re [regsub {\)} $re ""]								
				}

				set route "$route/($re)"

				lappend variables $param $re
			} else {
				# no path var
				set route "$route/$part"
			}
		}

		if {[string match {*/\*} $route]} {
			set route "^${route}"
		} else {
			set route "^${route}(/?)$"
		}


		return [list $route $variables]
	}

	proc prepare_route {cfg_route route_key {main false}} {

		variable log

		set routes {}

		set path [dict get $cfg_route path]
		set route [Route new] 
		$route props \
			routes [::trails::misc::util::get_def $cfg_route routes {}] \
			roles [::trails::misc::util::get_def $cfg_route roles {}] \
			methods [::trails::misc::util::get_def $cfg_route methods {}] \
			handler [::trails::misc::util::get_def $cfg_route handler {}] \
			enter [::trails::misc::util::get_def $cfg_route enter {}] \
			leave [::trails::misc::util::get_def $cfg_route leave {}] \
			websocket [::trails::misc::util::get_def $cfg_route websocket false] \
			controller [::trails::misc::util::get_def $cfg_route controller {}] \
			action [::trails::misc::util::get_def $cfg_route action {}] \
			path $path


		set route_path $route_key$path

		#${log}::debug "route = $route_key, subs =([llength $subRoutes])"
		
		if {[$route has_subroutes]} {
		

			if {[$route present handler]} {
				$route prop path $route_path
				lappend routes $route
			}

			set enter [$route prop enter]
			set leave [$route prop leave]
			set roles [$route prop roles]

			foreach subroute_cfg [$route prop routes] {
				#set path [$subroute prop path]

				# merge with base route
				set enter_all [list {*}$enter {*}[::trails::misc::util::get_def $subroute_cfg enter {}]]
				set leave_all [list {*}$leave {*}[::trails::misc::util::get_def $subroute_cfg leave {}]]
				set roles_all [list {*}$roles {*}[::trails::misc::util::get_def $subroute_cfg roles {}]] 

				set subroute [Route new]
				$subroute props \
							routes [::trails::misc::util::get_def $subroute_cfg routes {}] \
							roles $roles_all \
							methods [::trails::misc::util::get_def $subroute_cfg methods {}] \
							handler [::trails::misc::util::get_def $subroute_cfg handler {}] \
							enter $enter_all \
							leave $leave_all \
							websocket [::trails::misc::util::get_def $subroute_cfg websocket false] \
							path [dict get $subroute_cfg path]

				#if {[$subroute present handler]} {
				#	if {![configs::is_test]} {
				#		if {[info procs ::[$subroute prop handler]] == ""} {
				#			error "route handler [$subroute prop handler] does not exists"
				#		}
				#	}
				#}

				set rds [prepare_route [$subroute to_dict] $route_path]

				foreach r $rds {
					lappend routes $r
				}			
			} 

		} else {
			
			set result [extract_route_and_variables $route_path]
			set rePath [lindex $result 0]
			set variables [lindex $result 1]

			# remove end / if need, and add regex to do / optional
			if {[string match -nocase */ $route_path]} {
				#set rePath "[string range $rePath 0 end-1](/?)$"
				set route_path [string range $route_path 0 end-1]
			} 

			$route prop path $route_path
			$route prop repath $rePath
			$route prop variables $variables
			lappend routes $route
		}

		return $routes
	}

	proc build_config_routes {} {

		variable routes

		set items [::trails::configs::get web routes]

		set n [llength $items]	
		set all_routes {}

		foreach route $items {
			set path [dict get $route path]
			set results [prepare_route $route "" true]
			foreach r $results {			
				lappend all_routes $r
			}
		}	

		set routes [list {*}$routes {*}$all_routes]
	}

	proc build_scaffold_routes {scaffold_routes} {
		variable routes

		set all_routes {}

		#puts "::> build scaffold routes: [llength $scaffold_routes]"

		foreach scaffold_route $scaffold_routes {
			set scaffold_path [dict get $scaffold_route path]
			set skip false

			foreach route $routes {
				if {[$route prop path] == $scaffold_path} {
					#puts "::> skip route $scaffold_path"
					set skip true
					break
				}
			}

			if {!$skip} {
				#puts "::> prepare route $scaffold_path"
				set results [prepare_route $scaffold_route "" true]
				#puts "::> routes for $scaffold_path: [llength $results]"
				foreach r $results {			
					lappend all_routes $r
				}			
			}
			
		}

		set routes [list {*}$routes {*}$all_routes]
	}

	proc get_routes {} {
		variable routes
		return $routes
	}

	proc set_routes {r} {
		variable routes
		set routes $r
	}

	proc print {} {
		variable log
		variable routes

		${log}::info ":: routes"
		foreach route $routes {
			set method [string toupper [$route prop methods]]
			if {$method == ""} {
				set method ANY
			}
			${log}::info ": $method [$route prop path] -> [$route prop repath]"
		}
		${log}::info "::"	
	}

	proc match {path method} {

		variable routes
		variable log

		set variables {}

		#puts "match $path $method, [llength $routes]"

		set routes_match {}
		
		foreach route $routes {
			

			set repath [$route prop repath]
			set results [regexp -nocase -all -inline $repath $path]
			if {[llength $results] == 0} {
				#puts "not match $reqPath == $route_repath"
				continue
			}			
			
			if {![$route has_method $method]} {
				continue
			}

			lappend routes_match $route
		}

		set route_found {}

		if {[llength $routes_match] == 1} {
			set route_found [lindex $routes_match 0]
		} elseif {[llength $routes_match] > 1} {

			# search exact route
			foreach route $routes_match {
				if {[$route prop path] == $path} {
					set route_found $route
					break
				}
			}

			# or else get first route
			if {![info object isa object $route_found] || ![info object class $route_found Route]} {
				set route_found [lindex $routes_match 0]
			}
		}	

		if {[info object isa object $route_found] && [info object class $route_found Route]} {
			set variables [$route_found prop variables]
			set n [llength $variables]
			set vars {}

			set i 0
			foreach {var _} $variables {
				set val [lindex $results [incr i]]
				lappend vars $var $val			
			}


			set ret [$route_found clone]
			$ret prop params $vars
			return $ret					
		}

		return {}
	}
}
