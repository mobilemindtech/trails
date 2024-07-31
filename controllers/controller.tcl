#!/bin/tclsh

package require logger

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/http/request.tcl
source $trailsdir/http/response.tcl

namespace import ::trails::http::Response
namespace import ::trails::http::Request

namespace eval ::trails::controllers {

	#rename unknown __unknown__
	
	catch {
		oo::class create Controller {
			#variable scaffold service route_path route_prefix allowed_methods filters slog sdebug			
		}
	}

	oo::define Controller {

		constructor {} {			
			my variable scaffold service route_path route_prefix allowed_methods filters slog sdebug
			set scaffold false
			set service {}
			set route_prefix {}
			set allowed_methods {}
			set route_path {}
			set slog [logger::init Controller]
			set sdebug false
			set filters {}
		}


		method Get_actions {} {
			info object methods [self] -all
		}

		method Get_scaffold_action_name {action} {
			return "[string toupper [string index $action 0]][string range $action 1 end]"
		}

		method define {args} {
			my variable filters
			set defs {methods "" action "" type before}
			foreach {k v} $args {
				switch -regexp -- $k {					
					-filter {
						dict set defs filter $v
					} 
					-action {
						dict set defs action $v
					} 
					-methods {
						dict set defs methods $v
					}
					-type {
						dict set defs type $v
					}
					default {
						return -code error "wrong filter option: $k"
					}
				}
			}
			lappend filters $defs

		}

		method get_routes {} {
			my variable route_prefix route_path scaffold allowed_methods slog sdebug
			set reserved_actions [list dispatch_action get_routes destroy render]
			set prefix $route_prefix
			set actions [my Get_actions]
			set routes {}
			set controller [info object class [self]]

			if {$route_path == ""} {
				set controller_name [string range [lindex [split $controller ::] end] 0 end-10]
				set controller_name [string tolower $controller_name]
			} else {
				set controller_name $route_path
			}

			set scaffold_actions [list index save show edit update delete]

			if {$scaffold} {
				foreach action $scaffold_actions {
					if {[lsearch -exact $actions $action] == -1} {

						set route_action /$action

						if {$action == "index"} {
							set route_action {}
						}

						set idx [lsearch -exact $allowed_methods $action]
						set methods {}
						if {$idx > -1} {
							set methods [lindex $allowed_methods [incr $idx]]
						}

						set path $prefix/$controller_name$route_action
						set method [my Get_scaffold_action_name $action]

						if {$sdebug} {
							${slog}::debug "::> add route $path => $controller $method, $methods"
						}

						lappend routes [dict create path $path \
													methods $methods \
													controller $controller \
													action $action]
						
						set path $prefix/$controller_name$route_action/:id
						
						if {$sdebug} {
							${slog}::debug "::> add route $path => $controller $method, $methods"
						}
						
						lappend routes [dict create path $path \
													methods $methods \
													controller $controller \
													action $action]
					}
				}
			}

			foreach action $actions {

				set route_action /$action

				if {$action == "index"} {
					set route_action {}
				}

				if {[lsearch -exact $reserved_actions $action] > -1} {
					continue
				}

				set idx [lsearch -exact $allowed_methods $action]
				set methods {}
				if {$idx > -1} {
					set methods [lindex $allowed_methods [incr $idx]]
				}

				set path $prefix/$controller_name$route_action
				set method $action

				if {$sdebug} {
					${slog}::debug "::> add route $path => $controller $method, $methods"
				}
				
				lappend routes [dict create path $path \
											methods $methods \
											controller $controller \
											action $method]
				
				set path $prefix/$controller_name$route_action/:id

				if {$sdebug} {
					${slog}::debug "::> add route $path => $controller $method, $methods"
				}
				
				lappend routes [dict create path $path \
											methods $methods \
											controller $controller \
											action $method]
				

			}

			return $routes
		}

		method Check_allowed_methods {action request} {
			my variable allowed_methods
			set idx [lsearch $allowed_methods $action]

			if {$idx > -1} {
				set methods [lindex $allowed_methods [incr idx]]
				set methods [split $methods ,]
				set method [$request prop method]
				if {[lsearch -exact $methods $method] == -1} {
					return [Response new -status 405 -body {method not allowed}]
				}
			}
			return {}
		}		

		method dispatch_action {action request} {

			my variable scaffold
			set actions [my Get_actions]
			set response {}		
			set action_exec {}

			switch -regexp -- $action {
				index|save|show|edit|update|delete {

					set not_allowed_resp [my Check_allowed_methods $action $request]

					if {$not_allowed_resp != ""} {
						return $not_allowed_resp
					}

					if {[lsearch -exact $actions $action] > -1} {
						set action_exec $action
					} else {
						if {$scaffold} {
							set action_exec [my Get_scaffold_action_name $action]
						}
					}
				}
				default {
					if {[lsearch -exact $actions $action] > -1} {

						set not_allowed_resp [my Check_allowed_methods $action $request]

						if {$not_allowed_resp != ""} {
							return $not_allowed_resp
						}

						set action_exec $action
					}
				}
			}

			if {$action_exec != ""} {

				set filters [my Get_filters $request $action]
				set filters_after [dict get $filters filters_after]
				set filters_before [dict get $filters filters_before]
				
				foreach filter_action $filters_before {
					set next [my $filter_action $request]
					if {[info object class $next Request]} {
						set request $next
					} elseif {[info object class $next Response]} {
						return $next
					} else {
						return -code error {filter before should return req or resp object}
					}
				}

				set response [my $action_exec $request]

				foreach filter_action $filters_after {
					set response [my $filter_action $request $response]
					if {![info object class $response Response]} {
						return -code error {filter after should return resp object}
					}
				}
			}

			if {$response == ""} {
				set response [Response new -status 404 -body {not found}]
			} 

			return $response	
		}

		method Get_filters {request action} {
			my variable filters

			set filters_before {}
			set filters_after {}
			set method [$request prop method]

			foreach item $filters {
				set filter_action [dict get $item action]
				set methods [lmap it [split [dict get $item methods] ,] {[string toupper $it]}]
				set type [dict get $item type]
				set filter [dict get $item filter]
				set any_action [expr {$filter_action == ""}]
				set any_method [expr {[llength $methods] == 0}]
				set add false
				
				if {$any_action && $any_method} {
					set add true
				} elseif {$any_action} {
					if {[lsearch -exact $methods $method] > -1} {
						set add true
					}
				} elseif {$any_method} {
					if {$action == $filter_action} {
						set add true
					}
				} 

				if {$add} {
					if {$type == "before"} {
						lappend filters_before $filter
					} else {
						lappend filters_after $filter
					}	
				}
			}	

			dict create filters_after $filters_after filters_before $filters_before		
		}

		method Index {request} {
			Response new -status 200 -text index
		}

		method Save {request} {
			Response new -status 200 -text save
		}

		method Show {request} {
			Response new -status 200 -text show
		}

		method Edit {request} {
			Response new -status 200 -text edit
		}

		method Update {request} {
			Response new -status 200 -text update
		}

		method Delete {request} {
			Response new -status 200 -text delete
		}

		method render {args} {
			Response new {*}$args
		}		
	}

	namespace export Controller
}

