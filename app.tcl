#!/bin/tclsh

package require logger

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

namespace eval ::trails {}

foreach f [glob ./controllers/*.tcl] {
	set fname [lindex [split $f /] end]
	if {$fname != "controller.tcl"} {
		#puts "::> load controller $f"
		source $f
	}
}

foreach f [glob $trailsdir/filters/*.tcl] {
	set fname [lindex [split $f /] end]
	puts "::> load filter $f"
	source $f
}


source $trailsdir/database/migrations.tcl
source $trailsdir/configs/configs.tcl
source $trailsdir/http/http_server.tcl
source $trailsdir/http/router.tcl
source $trailsdir/controllers/controller.tcl
source $trailsdir/database/db.tcl

namespace import ::trails::controllers::Controller


namespace eval ::trails::app {
	
	variable ServerSocket
	variable log
	set log [logger::init app]

	proc configure_routes {} {
		variable log
		::trails::http::router::build_config_routes

		foreach cls [info class subclasses Controller] {
			set obj [$cls new]
			::trails::http::router::build_scaffold_routes [$obj get_routes]
		}

		::trails::http::router::print	
	}

	proc http_serve {} {

		variable log
		variable ServerSocket

		set port [::trails::configs::get web server port]	
		set workers [::trails::configs::get web server workers]
		set pool_size [::trails::configs::get datasource [::trails::configs::get_env] pool_size]

		${log}::info "workers=$workers, pool size=$pool_size"
		${log}::info "http server started on http://localhost:$port"


		if {$workers > 1} {
			httpworker::init $workers
			set socket [socket -server httpworker::accept $port]  
		} else {
			::trails::database::pool::init $pool_size
			::trails::http::init
			set socket [socket -server ::trails::http::accept $port]  
		}


		set ServerSocket $socket

		#websocket_init $socket

		vwait forever	
	}


	proc run {} {		
		configure_routes
		http_serve
	}
}



proc main {} {
	global argc
	global argv

	::trails::configs::init
	set opt ""

	if {$argc > 0} {
		set opt [lindex $argv 0]
	}

	switch $opt {
		migrate {
			::trails::database::migrations::run
		}
		run {
			set ::env(ENV) prod
			::trails::app::run	
		}
		dev {
			set ::env(ENV) dev
			::trails::app::run	
		}
		default {
			puts "USAGE: \[migrate\]"
		}
	}
}


main