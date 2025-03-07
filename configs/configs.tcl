package require yaml

namespace eval ::trails::configs {

    variable cfg_data
    
    set cfg_data {}

    namespace export config


    proc config {cmd args} {
	switch $cmd {
	    init { init }
	    init_with { init_with_file {*}$args }
	    get { getcfg {*}$args }
	    getall { all }
	    exists { exists {*}$args }
	    getdef { getdef {*}$args }
	    getenv { getenv }
	    is_dev { is_dev }
	    is_prod { is_prod }
	    is_test {is_test }
	    default {
		return -code error "invalid option. use config <get|getdef|getall|exists|getenv|is_dev|is_prod|is_test|init|init_with>"
	    }
	}
    }
    
    proc all {} {
	variable cfg_data
	return $cfg_data
    }

    proc init {} {
	init_with_file ./app/conf/application.yaml
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

    proc getcfg {args} {
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

    proc getenv {} {
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
