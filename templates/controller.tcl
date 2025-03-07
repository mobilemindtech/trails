package require TclOO

namespace import ::trails::controllers::Controller

namespace eval ::controllers {

    oo::class create __DOMAIN_NAME__Controller {
	Controller {
	    scaffold true
	}

	constructor {} {
	    
	}

	# enter filter
	# method enter {req} {}

	# leave filter
	# method leave {req resp} {}

	# simple action
	# method stuff {} {
	#  render -text "hello, world"
	#}
    }

    namespace export __DOMAIN_NAME__Controller
}
