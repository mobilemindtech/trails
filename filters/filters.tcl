
package require TclOO

source $::env(TRAILS_HOME)/json/json.tcl

namespace import ::sjson::*

namespace eval ::trails::filters {

    namespace export FilterJson FilterHtmlTemplate
    
    oo::class create FilterJson {

	method enter {request} {
	    if {[$request prop content-type] == "application/json"} {
		switch -regexp -- [$request prop method] {
		    POST|PUT|DELETE {
			set json_body [decode [$request prop body]]
			$request prop body $json_body
		    }
		}
	    }
	    return $request
	}

	method leave {request response} {
	    if {[$response prop content-type] == "application/json"} {
		if {[$response present body]} {

		    set json_srt ""
		    
		    if {[$response present tpl-json-list]} {
			set json_srt [encode list [$response prop body] -tpl [$response prop tpl-json-list]]
		    } else if {[$response present tpl-json]} {
			set json_srt [encode dict [$response prop body] -tpl [$response prop tpl-json]]
		    } else {
			set json_srt [encode value [$response prop body]]
		    }
		    
		    $response prop body $json_srt
		}
	    }
	    return $response
	}
	
	method recover {request err} {
	    if {[$request prop content-type] == "application/json"} {
		set response [Response new]
		set json_srt [encode value [dict create message $err]]
		$response prop body $json_srt
		return $response
	    } 
	}
    }
    
    oo::class create FilterHtmlTemplate {
	
	variable render_file render_text template_path errors

	constructor {} {
	    my variable render_file render_text template_path errors
	    set template_path [config get web template views]
	    set render_file [config get web template render file]
	    set render_text [config get web template render text]
	    set errors [config get web template errors]
	}

	method leave {request response} {

	    my variable render_file render_text template_path

	    set tplpath $template_path
	    set controller [$response prop controller]
	    set action [$response prop action]

	    if {[$response prop content-type] == "text/html"} {

		set ctx [$response prop ctx]

		if {[$response present tpl-name]} {
		    set tplname [$response prop tpl-name]

		    if {[string match /* $tplname]} {
			# full path
			set tplpath $tplpath$tplname.html
		    } else {
			# relative path
			set tplpath $tplpath/$controller/$tplname.html
		    }
		    puts "::> 1 $tplpath"
		    $response prop body [$render_file $tplpath $ctx]
		} elseif {[$response present tpl-path]} {
		    # full path
		    set file [$response prop tpl-path]
		    $response prop body [$render_file $file $ctx]
		} elseif {[$response present tpl-text]} {
		    set tpl [$response prop tpl-text]
		    $response prop body [$render_text $tpl $ctx]
		} else {

		    if {$controller == "index" && $action == "index"} {
			if {[file exists $tplpath/index.html]} {
			    set tplpath $tplpath/index.html
			} elseif {[file exists $tplpath/index/index.html]} {
			    set tplpath $tplpath/index/index.html
			} else {
			    return -code error "template index.html,index/index.html not found"
			}
		    } else {
			set tplpath $tplpath/$controller/$action.html
		    }
		    

		    if {![file exists $tplpath]} {
			return -code error "template ${tplpath} not found"
		    }

		    puts "::> $tplpath"
		    $response prop body [$render_file $tplpath $ctx]
		    
		}
	    }
	    
	    return $response
	}
	
	method recover {request err} {
	    if {[$request prop content-type] == "application/json"} {
		set response [Response new]
		set json_srt [encode value [dict create message $err]]
		$response prop body $json_srt
		return $response
	    } 
	}
    }	

    proc filter_json_enter {request} {

    }

    proc filter_json_leave {request response} {

    }


    proc filter_json_recover {request err} {

    }
}
