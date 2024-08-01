
package require TclOO

namespace eval ::trails::misc::props {
	catch {
		oo::class create Props {
			variable my_props allowed_props
		}
	}

	namespace export Props

	oo::define Props {
		constructor {} {
			my variable my_props allowed_props
			set my_props [dict create]
			foreach prop $allowed_props {
				dict set my_props $prop {}
			}
		}

		method prop {args} {
			my variable my_props allowed_props
			set argc [llength $args]

			if {$argc == 0 || $argc > 2} {
				return -code error "use prop set or get to [info object class [self]]"
			}
			
			set prop_name [lindex $args 0]
			
			if {[lsearch -exact $allowed_props $prop_name] == -1} {
				return -code error "prop $prop_name not allowe to [info object class [self]]"
			} 

			if {$argc == 1} {
				dict get $my_props $prop_name
			} elseif {$argc == 2} {
				dict set my_props $prop_name [lindex $args 1]
			}
		}

		method propdef {args} {
			set v [my prop {*}[lrange $args 0 end-1]]
			if {$v != ""} {
				return $v
			}
			lindex $args end-1
		}

		method props {args} {
			my variable my_props allowed_props
			foreach {k v} $args {
				if {[lsearch -exact $allowed_props $k] == -1} {
					return -code error "prop $prop_name not allowed to [info object class [self]]"
				} 
				dict set my_props $k $v
			}
		}

		method bool {name} {
			set val [my prop $name]
			expr {$val == 1 || $val == true}
		}

		method present {name} {
			expr {[my prop $name] != ""}
		}		

		method to_dict {} {
			my variable my_props
			set d [dict create]
			dict for {k v} $my_props {
				dict set d $k $v
			}
			return $d
		}

		method from_dict {d} {
			my variable allowed_props
			foreach k $allowed_props {
				if {[dict exists $d $k]} {
					my prop $k [dict get $d $k]
				}
			}
			return [self]		
		}
	}

}