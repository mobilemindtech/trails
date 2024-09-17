package require TclOO


source $::env(TRAILS_HOME)/tests/extra/dummy_service.tcl
source $::env(TRAILS_HOME)/controllers/controller.tcl

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
			next {*}$args

			my variable scaffold
			set scaffold true

			foreach {k v} $args {
				switch -regexp -- $k {
					-scaffold|scaffold {
						set scaffold $v
					}
				}
			}
		}

		method MyFilterLeave {req resp} {
			my render -text "filter"
		}
		
		method index {request} {
			Response new -status 200 -body {index override}
		}

		method custom {request} {
			Response new -status 200 -body {custom action}
		}

		method withrender {request} {
			my render -status 200 -text {withrender}
		}

		method list1 {request} {
			return {200 list1 text/plain}
		}

		method list2 {request} {
			return {text list2}
		}

		method withjson {request} {
			return {json {[{"x": 3}]}}
		}

		method withhtml {request} {
			return {html {<html><body><h1>hello, trails!</h1></body></html>}}
		}		
	}

	catch {
		oo::class create IndexController { 
			superclass Controller
		}
	}

	oo::define IndexController {
		constructor {args} {
			next {*}$args

			my variable scaffold
			set scaffold true

			foreach {k v} $args {
				switch -regexp -- $k {
					-scaffold|scaffold {
						set scaffold $v
					}
				}
			}
		}

		method index {req} {
			my render -text {default index}
		}
	}


	
	namespace export DummyController IndexController
}


