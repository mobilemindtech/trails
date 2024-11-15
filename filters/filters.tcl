

source $::env(TRAILS_HOME)/json/json.tcl


namespace eval ::filters {

	oo::class create FilterJson {
		
		method enter {request} {
			if {[$request prop content-type] == "application/json"} {
				switch -regexp -- [$request prop method] {
					POST|PUT|DELETE {
						set json_body [::trails::json::json2dict [$request prop body]]
						$request prop body $json_body
					}
				}
			}
			return $request
		}

		method leave {request response} {
			if {[$response prop content-type] == "application/json"} {
				if {[$response present body]} {
					set json_srt [::trails::json::tcl2json [$response prop body] [$response prop tpl-json]]
					$response prop body $json_srt
				}
			}
			return $response
		}
		
		method recover {request err} {
			if {[$request prop content-type] == "application/json"} {
				set response [Response new]
				set json_srt [::trails::json::tcl2json [dict create message $err]]
				$response prop body $json_srt
				return $response
			} 
		}
	}
	
	oo::class create FilterHtmlTemplate {
		
		variable render_file render_text template_path errors

		constructor {} {
			my variable render_file render_text template_path errors
			set template_path [::trails::configs::get web template views]
			set render_file [::trails::configs::get web template render file]
			set render_text [::trails::configs::get web template render text]
			set errors [::trails::configs::get web template errors]
		}

		method leave {request response} {

			my variable render_file render_text template_path

			if {[$response prop content-type] == "text/html"} {

				set ctx [$response prop ctx]

				if {[$response present tpl-name]} {
					set file [$response prop tpl-name]
					$response prop body [$render_file $template_path/$file $ctx]
				} elseif {[$response present tpl-path]} {
					set file [$response prop tpl-path]
					$response prop body [$render_file $file $ctx]
				} elseif {[$response present tpl-text]} {
					set tpl [$response prop tpl-text]
					$response prop body [$render_text $tpl $ctx]
				} else {
					return -code error {invalid template}
				}

			}
			return $response
		}
		
		method recover {request err} {
			if {[$request prop content-type] == "application/json"} {
				set response [Response new]
				set json_srt [::trails::json::tcl2json [dict create message $err]]
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
