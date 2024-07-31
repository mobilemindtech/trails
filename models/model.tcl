
source ./core/misc/props.tcl

namespace import ::trails::misc::props::Props

namespace eval ::trails::models {
	catch {
		oo::class create Model {
			superclass Props
			variable db_columns json_fields
		}
	}

	namespace export Model

	oo::define Model {

		constructor {} {
			my variable allowed_props db_columns json_fields
			set allowed_props [list id created_at updated_at]
			set db_columns {}
			set json_fields {}

			#my defcol id -column id -type int -default 0 -auto timestamp -format fn
			#my defjson id -field id -typein int -typeout int -default 0 -format fn
		}


		method defcol {field args} {
			my variable db_columns
			set defs {}

			foreach {k v} $args {
				switch -regexp -- $k {
					-column {
						dict set defs column $v	
					}
					-type {
						dict set defs type $v
					}
					-default {
						dict set defs default $v
					}
					-auto {
						dict set defs auto $v
					}
					-format {
						dict set defs format $v
					}
					default {
						return -code error "invalid defcol option: $k"
					}
				}
			}

			dict set db_columns $field $defs
		}

		method defjson {field args} {
			my variable json_fields
			set defs {}

			foreach {k v} $args {
				switch -regexp -- $k {
					-field {
						dict set defs field $v	
					}
					-typein {
						dict set defs typein $v
					}
					-typeout {
						dict set defs typeout $v
					}
					-default {
						dict set defs default $v
					}
					-format {
						dict set defs format $v
					}					
					default {
						return -code error "invalid defjson option: $k"
					}
				}
			}

			dict set json_fields $field $defs
		}


		method get_columns {} {

		}

		method to_json {} {

		}

		method to_model {} {

		}
	}
}