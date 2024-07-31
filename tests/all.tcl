

package require tcltest
namespace import ::tcltest::*


#configure -verbose {skip pass error body}

if {$argc != 0} {

	if {[lindex $::argv 0] eq "configure"} {

		foreach {action arg1 arg2} $::argv {
			$action $arg1 arg2
		}

	} else {

	    foreach {action arg} $::argv {
	        if {[string match -* $action]} {
	            configure $action $arg
	        } else {
	            $action $arg
	        }
	    }
	}

}

runAllTests