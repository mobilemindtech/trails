package require yaml

namespace eval ::trails::configs {
	set cfg_data {}

	namespace export get_cfg get_env

	proc all {} {
		variable cfg_data
		return $cfg_data
	}

	proc init {} {
		init_with_file ./cfg/application.yaml
	}

	proc init_with_file {cfg_file} {
		variable cfg_data
		if {![file exists $cfg_file]} {
			return -code error "$cfg_file dows not exists"
		}

		set fd [open $cfg_file]
		set cfg_data [yaml::yaml2dict [read $fd]]
		close $fd

	}

	proc get_cfg {args} {
		get {*}$args
	}

	proc get {args} {
		variable cfg_data
		dict get $cfg_data {*}$args
	}

	proc exists {args} {
		variable cfg_data
		dict exists $cfg_data {*}$args
	}

	proc getdef {args} {
		set def_val [lindex $args end]
		set argv [lrange $args 0 end-1]	
		if {[exists {*}$argv]} {
			get {*}$argv
		} else {
			return $def_val
		}		
	}

	proc get_or {args} {
		getdef {*}$args
	}

	proc get_env {} {
		if {[info exists ::env(ENV)]} {
	    switch $::env(ENV) {
	      test {
	        return test
	      }
	      prod {
	        return prod
	      }
	    }
	  }	
	  return dev
	}

	proc is_test {} {
		expr {[get_env] == "test"}
	}

	proc is_prod {} {
		expr {[get_env] == "prod"}
	}

	proc is_dev {} {
		expr {[get_env] == "dev"}
	}
}
