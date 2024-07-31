package require TclOO


set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/services/service.tcl

namespace import ::trails::services::Service


namespace eval ::services  {
	catch {
		oo::class create DummyService { 
			superclass Service 
		}
	}

	namespace export DummyService
	
	oo::define DummyService {
		constructor {} {
			next
			my variable domain

			set domain {
				table_name person
				fields {
					id {{id_ int key} {json ID string}}
					name {{name_ string} {json NAME string}}	
				}
			}

		}
	}

}