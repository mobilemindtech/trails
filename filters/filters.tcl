

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/json/json.tcl


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
					set json_srt [::trails::json::tcl2json [$response prop body] [$response prop template]]
					$response prop body $json_srt
				}
			}
			return $response
		}
		
		method recover {request err} {
			if {[$response prop content-type] == "application/json"} {
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
