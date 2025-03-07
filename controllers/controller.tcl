#!/bin/tclsh

package require logger


namespace import ::tfast::http::Response
namespace import ::tfast::http::Request
namespace import ::tools::Props
namespace import ::tools::lists::*

namespace eval ::trails::controllers {

    variable CtrlConfigs

    #rename unknown __unknown__
    
    catch {
	oo::class create AppController {			
	    superclass Props
	    # controller logger
	    variable Log 
	    # controller in debug mode, default is false
	    variable DebugMode

	    # if is scaffold controller, default is false. actions: create/:id|index/:id|save/:id|show/:id|edit/:id|update/:id|delete/:id
	    variable Scaffold 
	    # route path, default is controller name
	    variable RoutePath 
	    # route prefix, default is empty. eg.: 
	    #/api/v2
	    #
	    variable RoutePrefix 
	    # allowed methods. eg.: 
	    # {<action> <methods>}
	    # {	remove delete 
	    #	index get,post
	    #	save post 
	    #	update put}
	    #
	    variable AllowedMethods 
	    # filters to apply by action. filters are controller methods. eg: 
	    # { <action> {<method or proc> <filter type: enter|leave|recover> <methods: get|post|delete|put|*>} }
	    #{	index {JsonFilter leave *} 
	    #	save {ValidationFilter enter post}
	    #	remove {ValidationExists enter post,get}
	    #   * {Other enter *}}
	    #
	    variable Filters
	}
    }

    oo::define AppController {
	
	constructor {args} {
	    next -permits-new
	    my Merge_contoller_configs {*}$args
	}		

	method Get_contoller_configs {} {
	    set cls [info object class [self]]
	    dict get $::trails::controllers::CtrlConfigs $cls
	}

	method Merge_contoller_configs {args} {
	    set cls [info object class [self]]
	    set configs [dict get $::trails::controllers::CtrlConfigs $cls]

	    foreach {k v} $args {
		dict set $configs $k $v
	    }

	    dict set ::trails::controllers::CtrlConfigs $cls $configs
	}

	method controller_configure {} {
	    my variable Log Scaffold RoutePrefix AllowedMethods RoutePath Filters DebugMode
	    set Log [logger::init AppController]			
	    set Scaffold false
	    set RoutePrefix {}
	    set AllowedMethods {}
	    set RoutePath {}
	    set DebugMode false
	    set Filters {}

	    try {
		set service_name [my Get_service_name]
		set service_var_name [my Get_service_var_name]

		if {[info object isa object ::services::$service_name]} {
		    oo::define [self class] variable $service_var_name
		    set $service_var_name [::services::$service_name new]
		}

	    } on error err {
		puts "::> error in inject service on controller: $err"
	    }

	    set params [my Get_contoller_configs]

	    foreach {k v} {*}$params {
		switch -regexp -- $k {
		    -scaffold|scaffold {
			set Scaffold $v
		    }
		    -route-prefix|route-prefix {
			set RoutePrefix $v
		    }
		    -allowed-methods|allowed-methods {
			set AllowedMethods $v
		    }
		    -filters|filters {
			set Filters $v
		    }
		    -route-path|route-path {
			set RoutePath $v
		    }
		    -debug-mode|debug-mode {
			set RoutePath $v
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

	method Get_controller_name {} {
	    set controller [info object class [self]]
	    return [string range [lindex [split $controller ::] end] 0 end-[string length Controller]]
	}

	method Get_controller_path {} {
	    set controller [my Get_controller_name]
	    return [string tolower [string index $controller 0]][string range $controller 1 end]
	}
	
	method Get_template_file {action} {
	    set controller [info object class [self]]
	    set folder  [my Get_controller_path]
	    set viewsdir [config get web template views]

	    # search on templates path
	    if {[file exists $viewsdir/$folder/$action.html]} {
		return $viewsdir/$folder/$action.html
	    }

	    # index template can be on views/index.html
	    if {$folder == "index" && $action == "index"} {
		if {[file exists $viewsdir/index.html]} {
		    return $viewsdir/index.html
		}
	    }

	    # use default template
	    if {[file exists ./.tcl/trails/templates/$action.html]} {
		return ./.tcl/trails/templates/$action.html
	    }
	    
	    return ""
	}

	method Get_service_name {} {
	    set controller_name [my Get_controller_name]			
	    return "${controller_name}Service"
	}

	method Get_service_var_name {} {
	    set controller_name [my Get_service_name]
	    return "[string tolower [string index $controller_name 0]][string range $controller_name 1 end]"
	}

	method get_routes {} {
	    my variable RoutePrefix RoutePath Scaffold AllowedMethods Log DebugMode
	    set reserved_actions [list dispatch_action get_routes destroy render enter leave recover define]
	    set prefix $RoutePrefix
	    set actions [my Get_actions]
	    set routes {}
	    set controller [info object class [self]]

	    if {$RoutePath == ""} {
		set controller_name [my Get_controller_path]
		#set controller_name [string tolower $controller_name]

		if {$controller_name == "index"} {
		    set controller_name {}
		} else {
		    set controller_name /$controller_name
		}

	    } else {
		set controller_name $RoutePath
	    }

	    if {$prefix != ""} {
		set controller_name $prefix$controller_name
	    }


	    set scaffold_actions [list index save show edit update delete]

	    if {$Scaffold} {
		# override default actions if need
		foreach action $scaffold_actions {
		    if {[lsearch -exact $actions $action] == -1} {

			set route_action /$action

			if {$action == "index"} {
			    set route_action /
			}

			set idx [lsearch -exact $AllowedMethods $action]
			set methods {}
			if {$idx > -1} {
			    set methods [lindex $AllowedMethods [incr $idx]]
			}

			set path $controller_name$route_action						
			set method [my Get_scaffold_action_name $action]

			if {$DebugMode} {
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
			
			if {$DebugMode} {
			    ${Log}::debug "::> add route $path => $controller $method, $methods"
			}
			
			lappend routes [dict create path $path \
					    methods $methods \
					    controller $controller \
					    action $action]
		    }
		}
	    }

	    # get controllers actions
	    foreach action $actions {

		set route_action /$action

		if {$action == "index"} {
		    set route_action /
		}

		if {[lsearch -exact $reserved_actions $action] > -1} {
		    continue
		}

		set idx [lsearch -exact $AllowedMethods $action]
		set methods {}
		if {$idx > -1} {
		    set methods [lindex $AllowedMethods [incr $idx]]
		}

		set path $controller_name$route_action
		set method $action

		if {$DebugMode} {
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

		if {$DebugMode} {
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
	    my variable AllowedMethods
	    set idx [lsearch $AllowedMethods $action]

	    if {$idx > -1} {
		set methods [lindex $AllowedMethods [incr idx]]
		set methods [split $methods ,]
		set method [$request prop method]
		if {[lsearch -exact $methods $method] == -1} {
		    return [Response new -status 405 -body {method not allowed}]
		}
	    }
	    return {}
	}		

	method dispatch_action {action request} {

	    my variable Scaffold
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
			if {$Scaffold} {
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
		set fts [my Get_filters $action $method]					
		set fenter [dict get $fts enter]
		set fleave [dict get $fts leave]
		set frecover [dict get $fts recover]
		
		if {[llength $fenter] > 0} {
		    foreach enter_name $fenter { 
			set result [my $enter_name $request]
			if {[::tfast::http::is_response $result]} {
			    return $result
			} elseif {[::tfast::http::is_request $result]} {
			    set request $result
			} else {
			    return -code error {wrong filter result}
			}
		    }
		}

		try {
		    set response [my $action_exec $request]
		    $response props \
			controller [my Get_controller_path] \
			action $action
		} on error err {
		    if {[llength $frecover] > 0} {
			foreach recover_name $frecover {
			    set result [my $recover_name $request $err]
			    if {[::tfast::http::is_response $response]} {
				return $result
			    }						
			}
		    }

		    return -code error $err					
		}

		if {[llength $fleave] > 0} {
		    foreach leave_name $fleave {
			set response [my $leave_name $request $response]
			if {![::tfast::http::is_response $response]} {
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

	method Get_filters {action method} {
	    my variable Filters

	    set filters_to_apply {}
	    set keys [dict keys $Filters]

	    foreach key $keys {
		if {$key == "*" || $key == $action} {
		    lappend filters_to_apply [dict get $Filters $key]
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

	    set methods [my Get_actions]

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

	method Render_default_action_tpl {action ctx} {
	    set tplfile  [my Get_template_file $action]

	    if {$tplfile != ""} {
		Response new -status 200 -tpl-path $tplfile -ctx $ctx
	    } else {
		Response new -status 200 -text "template not found"
	    }			
	}

	method Index {request} {

	    set headers [$request prop headers]
	    set accept text/html

	    if {[dict exists $headers http-accept]} {
		set accept [dict get headers http-accept]
	    } 

	    if {$accept == "applicaton/json"} {
		# TODO render json
		Response new -status 200 -json {message NotImplemented}
	    } else {
		# TODO 
		set ctx {}
		my Render_default_action_tpl index $ctx
	    }
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
	    Response new -content-type text/html {*}$args
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

