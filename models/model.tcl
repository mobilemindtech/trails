

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/misc/props.tcl

namespace import ::trails::misc::props::Props

namespace eval ::trails::models {

	variable Models
	set Models {}

	catch {
		oo::class create Model {
			superclass Props
		}
	}

	namespace export Model ActiveRecord


	oo::define Model {

		constructor {} {
			my variable table_name allowed_props
			set allowed_props [list id created_at updated_at]

			set fields [self get_fields]

			foreach {k _} $fields {
				lappend allowed_props $k
			} 
		}

		method to_json {} {

		}

		method to_model {} {

		}
	}


}