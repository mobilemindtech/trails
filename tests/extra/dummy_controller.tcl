package require TclOO

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/tests/extra/dummy_service.tcl
source $trailsdir/controllers/controller.tcl

namespace import ::services::DummyService
namespace import ::trails::controllers::Controller

namespace eval ::controllers  {
	catch {
		oo::class create DummyController { 
			superclass Controller
		}
	}

	oo::define DummyController {
		constructor {args} {	
			next	
			my variable service scaffold route_prefix allowed_methods filters
			set service [DummyService new]	
			set scaffold true
			set route_prefix /api/v2

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
				}				
			}
		}
		
		method index {request} {
			Response new -status 200 -body {index override}
		}

		method custom {request} {
			Response new -status 200 -body {custom action}
		}
	}


	namespace export DummyController
}


