#!/bin/tclsh

package require logger

source $::env(TRAILS_HOME)/http/request.tcl
source $::env(TRAILS_HOME)/http/response.tcl

namespace import ::trails::http::Response
namespace import ::trails::http::Request

namespace eval ::trails::controllers {

	variable CtrlConfigs

	#rename unknown __unknown__
	
	catch {
		oo::class create AppController {			
			# controller logger
			variable Log 
			# controller in debug mode, default is false
			variable debug_mode

			# if is scaffold controller, default is false. actions: create/:id|index/:id|save/:id|show/:id|edit/:id|update/:id|delete/:id
			variable scaffold 
			# service controler, find by servico with same controller name
			variable service 
			# route path, default is controller name
			variable route_path 
			# route prefix, default is empty. eg.: 
			#/api/v2
			#
			variable route_prefix 
			# allowed methods. eg.: 
			# {<action> <methods>}
			# {	remove delete 
			#	index get,post
			#	save post 
			#	update put}
			#
			variable allowed_methods 
			# filters to apply by action. filters are controller methods. eg: 
			# { <action> {<method or proc> <filter type: enter|leave|recover> <methods: get|post|delete|put|*>} }
			#{	index {JsonFilter leave *} 
			#	save {ValidationFilter enter post}
			#	remove {ValidationExists enter post,get}
			#   * {Other enter *}}
			#
			variable filters
		}
	}

	oo::define AppController {

		
		constructor {} {			
		}

		method controller_configure {} {
 			my variable Log scaffold service route_prefix allowed_methods route_path filters debug_mode
			set Log [logger::init AppController]			
			set scaffold false
			set service {}
			set route_prefix {}
			set allowed_methods {}
			set route_path {}
			set debug_mode false
			set filters {}

			set cls [info object class [self]]
			set params [dict get $::trails::controllers::CtrlConfigs $cls]

			foreach {k v} {*}$params {
				switch -regexp -- $k {
					-scaffold|scaffold {
						set scaffold $v
					}
					-route-prefix|route-prefix {
						set route_prefix $v
					}
					-controller|controller {
						set controller $v
					}
					-allowed-methods|allowed-methods {
						set allowed_methods $v
					}
					-filters|filters {
						set filters $v
					}
					-route-path|route-path {
						set route_path $v
					}
					-debug-mode|debug-mode {
						set route_path $v
					}
				}				
			}
		}

		# list controller actions
		method Get_actions {} {
			info object methods [self] -all
		}

		# list default scaffold actions
		method Get_scaffold_action_name {action} {
			return "[string toupper [string index $action 0]][string range $action 1 end]"
		}

		method get_routes {} {
			my variable route_prefix route_path scaffold allowed_methods Log debug_mode
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

			if {$prefix != ""} {
				set controller_name $prefix$controller_name
			}


			set scaffold_actions [list index save show edit update delete]

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

						if {$debug_mode} {
							${Log}::debug "::> add route $path => $controller $method, $methods"
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
						
						if {$debug_mode} {
							${Log}::debug "::> add route $path => $controller $method, $methods"
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

				if {$debug_mode} {
					${Log}::debug "::> add route $path => $controller $method, $methods"
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

				if {$debug_mode} {
					${Log}::debug "::> add route $path => $controller $method, $methods"
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

				set filters [my Get_filters $method]					
				set fenter [dict get $filters enter]
				set fleave [dict get $filters leave]
				set frecover [dict get $filters recover]
			
				if {[llength $fenter] > 0} {
					foreach enter_name $fenter { 
						set result [my $enter_name $request]
						if {[::trails::http::is_response $result]} {
							return $result
						} elseif {[::trails::http::is_request $result]} {
							set request $result
						} else {
							return -code error {wrong filter result}
						}
					}
				}

				try {
					set response [my $action_exec $request]					
				} on error err {
					if {[llength $frecover] > 0} {
						foreach recover_name $frecover {
							set result [my $recover_name $request $err]
							if {[::trails::http::is_response $response]} {
								return $result
							}						
						}
					}

					return -code error $err					
				}

				if {[llength $fleave] > 0} {
					foreach leave_name $fleave {
						set response [my $leave_name $request $response]
						if {![::trails::http::is_response $response]} {
							return -code error {wrong filter result}						
						}
					}
				}
			}

			if {$response == ""} {
				set response [Response new -status 404 -body {not found}]
			} 

			return $response	
		}

		method Get_filters {method} {
			my variable filters

			set filters_to_apply {}
			set keys [dict keys $filters]

			foreach key $keys {
				if {$key == "*" || $key == $action} {
					lappend filters_to_apply [dict get $filters $key]
				}
			}

			set filter_enter {}
			set filter_leave {}
			set filter_recover {}


			if {[llength $filters_to_apply] > 0} {

				foreach filter $filters_to_apply {
					
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
								lappend filter_enter $filter_name
							}
							leave {
								lappend filter_leave $filter_name
							}
							recover {
								lappend filter_recover $filter_name
							}
							default { return -code error "invalid filter type: $filter_type" }
						}
					}
				}
			} 

			set methods [info object methods [self]]
			
			# apply default filter only custom filter not is defined
			
			if {[llength $filter_enter] == 0} {	
				if {[lsearch -exact $methods enter] > -1} {
					lappend filter_enter enter
				}
			}

			if {[llength $filter_leave] == 0} {
				if {[lsearch -exact $methods leave] > -1} {
					lappend filter_leave leave
				}
			}

			if {[llength $filter_recover] == 0} {
				if {[lsearch -exact $methods recover] > -1} {
					lappend filter_recover recover
				}
			}

			dict create \
				enter $filter_enter \
				leave $filter_leave \
				recover $filter_recover
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

	proc Controller {args} {
		variable CtrlConfigs 
		
		uplevel 1 {superclass ::trails::controllers::AppController}		
		
		set CtrlConfigs {}
		set cls [lindex [info level -1] 1]
		dict set CtrlConfigs $cls $args
	}

	namespace export Controller AppController
}

