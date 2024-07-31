
namespace eval ::trails::misc::util {

	proc get_def {d args} {
		set def_val [lindex $args end]
		set argv [lrange $args 0 end-1]

		if {[dict exists $d {*}$argv]} {
			dict get $d {*}$argv
		} else {
			return $def_val
		}
	}

	proc filter_number {text} {
		regexp -all -inline -- {[0-9]+} $text
	}
}
