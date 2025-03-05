
package require TclOO

namespace eval ::trails::misc::props {
	catch {
		oo::class create Props {
			variable MyProps allowed_props PermitsNew
		}
	}

	namespace export Props

	oo::define Props {

		# Contruct new Props
		#
		# @param args list of allowed props
		# <code>
		# oo:define MyClass {
		#	constructor {
		#		next prop1 prop2 prop3
		#   }	
		# }
		# Uuse -permits-new to permitir add new props after object created. The default
		# behavior is throw error when props not found
		# </code>
		constructor {args} {
			my set_allowed_props {*}$args
		}

		# create list of allowed props
		method set_allowed_props {args} {
			my variable MyProps PermitsNew allowed_props
			set MyProps [dict create]
			set allowed_props $args
			set PermitsNew [expr {[llength $args] == 0}]
			foreach prop $args {

				if {$prop == "-permits-new"} {
					set PermitsNew true
					continue
				}

				dict set MyProps $prop {}
			}
		}		

		# Get or set prop
		# <code>
		# set name [$obj prop name]
		# $obj prop name {John Doo}
		# </code>
		method prop {args} {
			my variable MyProps PermitsNew allowed_props
			set argc [llength $args]

			if {$argc == 0 || $argc > 2} {
				return -code error "use prop set or get to [info object class [self]]"
			}
			
			set prop_name [lindex $args 0]
			
			if {!$PermitsNew && [lsearch -exact $allowed_props $prop_name] == -1} {
				return -code error "prop $prop_name not allowed to [info object class [self]]"
			} 
				
			if {$argc == 2} {
				dict set MyProps $prop_name [lindex $args 1]
			}

			dict get $MyProps $prop_name
		}

		# Get prop or default value
		# <code>
		# set name [$obj propdef name {John Doo}]
		# </code>
		method propdef {args} {
			set v [my prop {*}[lrange $args 0 end-1]]
			if {$v != ""} {
				return $v
			}
			lindex $args end-1
		}

		# Map prop value to apply lambda result
		# <code>
		# set i [$obj propmap counter {i { expr {i + 1} }}]
		# </code>		
		method propmap {name body} {
			apply $body [my prop $name]
		}

		# Change prop value to apply lambda result
		# <code>
		# set i [$obj propmap counter {i { expr {i + 1} }}]
		# </code>		
		method propapply {name body} {
			my prop $name [my propmap $name $body]
		}

		# Set props from dict
		method props {args} {
			my variable MyProps PermitsNew allowed_props
			foreach {k v} $args {
				if {!$PermitsNew && [lsearch -exact $allowed_props $k] == -1} {
					return -code error "prop $prop_name not allowed to [info object class [self]]"
				} 
				dict set MyProps $k $v
			}
		}

		# Get value from boolean prop
		method bool {name} {
			set val [my prop $name]
			expr {$val == 1 || $val == true}
		}

		# check prop was defined
		method present {name} {
			expr {[my prop $name] != ""}
		}		

		method to_dict {} {
			my variable MyProps
			set d [dict create]
			dict for {k v} $MyProps {
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