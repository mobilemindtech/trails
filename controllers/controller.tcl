#!/bin/tclsh

package require logger

source $::env(TRAILS_HOME)/http/request.tcl
source $::env(TRAILS_HOME)/http/response.tcl

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

		constructor {args} {			
			my variable scaffold service route_path route_prefix allowed_methods filters slog sdebug
			set scaffold false
			set service {}
			set route_prefix {}
			set allowed_methods {}
			set route_path {}
			set slog [logger::init Controller]
			set sdebug false
			set filters {}

			foreach {k v} $args {
				switch -regexp -- $k {
					-scaffold|scaffold {
						set scaffold $v
					}
					-route_prefix|route_prefix {
						set route_prefix $v
					}
					-controller|controller {
						set controller $v
					}
					-allowed_methods|allowed_methods {
						set allowed_methods $v
					}
					-filters|filters {
						set filters $v
					}
					-route_path|route_path {
						set route_path $v
					}
				}				
			}			
		}


		method Get_actions {} {
			info object methods [self] -all
		}

		method Get_scaffold_action_name {action} {
			return "[string toupper [string index $action 0]][string range $action 1 end]"
		}

		method define {args} {
			my variable filters
			set defs {methods "" action "" type enter}
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
			set reserved_actions [list dispatch_action get_routes destroy render enter leave recover define]
			set prefix $route_prefix
			set actions [my Get_actions]
			set routes {}
			set controller [info object class [self]]

			if {$route_path == ""} {
				set controller_name [string range [lindex [split $controller ::] end] 0 end-10]
				set controller_name [string tolower $controller_name]

				if {$controller_name == "index"} {
					set controller_name {}
				} else {
					set controller_name /$controller_name
				}

			} else {
				set controller_name $route_path
			}


			set scaffold_actions [list index save show edit update delete]

			puts "::> controller_name = $controller_name"

			if {$scaffold} {
				foreach action $scaffold_actions {
					if {[lsearch -exact $actions $action] == -1} {

						set route_action /$action

						if {$action == "index"} {
							set route_action /
						}

						set idx [lsearch -exact $allowed_methods $action]
						set methods {}
						if {$idx > -1} {
							set methods [lindex $allowed_methods [incr $idx]]
						}

						set path $controller_name$route_action						
						set method [my Get_scaffold_action_name $action]

						if {$sdebug} {
							${slog}::debug "::> add route $path => $controller $method, $methods"
						}

						lappend routes [dict create path $path \
													methods $methods \
													controller $controller \
													action $action]
						
						if {"$controller_name$route_action" == "/"} {
							set path /:id
						} else {
							set path $controller_name$route_action/:id
						}
						
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
					set route_action /
				}

				if {[lsearch -exact $reserved_actions $action] > -1} {
					continue
				}

				set idx [lsearch -exact $allowed_methods $action]
				set methods {}
				if {$idx > -1} {
					set methods [lindex $allowed_methods [incr $idx]]
				}

				set path $controller_name$route_action
				set method $action

				if {$sdebug} {
					${slog}::debug "::> add route $path => $controller $method, $methods"
				}
				
				lappend routes [dict create path $path \
											methods $methods \
											controller $controller \
											action $method]
				
				if {"$controller_name$route_action" == "/"} {
					set path /:id
				} else {
					set path $controller_name$route_action/:id
				}

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

			my variable scaffold filters
			set actions [my Get_actions]
			set response {}		
			set action_exec {}
			set method [$request prop method]

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


				set methods [info object methods [self]]
				set has_enter false
				set has_leave false
				set has_recover false
				set enter_name enter
				set leave_name leave
				set recover_name recover

				if {[lsearch -exact $methods enter] > -1} {
					set has_enter true
				}

				if {[lsearch -exact $methods leave] > -1} {
					set has_leave true
				}

				if {[lsearch -exact $methods recover] > -1} {
					set has_recover true
				}

				if {[dict exists $filters $action]} {
					set filter [dict get $filters $action]
					foreach {filter_name filter_type filter_methods} $filter {}

					set any [expr {$filter_methods == "*"}]
					set method_enabled false
					if {$any} {
						set method_enabled true
					} else {
						set filter_methods [split $filter_methods ,]
						set method_enabled [expr {[lsearch -exact $filter_methods $method] > -1}]
					}

					if {$method_enabled} {
						switch $filter_type {
							enter { 
								set has_enter true 
								set enter_name $filter_name
							}
							leave { 
								set has_leave true 
								set leave_name $filter_name
							}
							recover { 
								set has_recover true 
								set recover_name $filter_name
							}
							default { return -code error "invalid filter type: $filter_type" }
						}
					}
				}

				if {$has_enter} {
					set result [my $enter_name $request]
					if {[::trails::http::is_response $result]} {
						return $result
					} elseif {[::trails::http::is_request $result]} {
						set request $result
					} else {
						return -code error {wrong filter result}
					}
				}

				try {
					set response [my $action_exec $request]					
				} on error err {
					if {$has_recover} {
						set result [my $recover_name $request $err]
						if {[::trails::http::is_response $response]} {
							return $result
						}						
					}

					return -code error $err					
				}

				if {$has_leave} {
					set response [my $leave_name $request $response]
					if {![::trails::http::is_response $response]} {
						return -code error {wrong filter result}						
					}
				}				

			}

			if {$response == ""} {
				set response [Response new -status 404 -body {not found}]
			} 

			return $response	
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

