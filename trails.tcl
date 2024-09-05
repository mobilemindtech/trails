
package provide trails 0.1


set ::env(TRAILS_HOME) [expr {[file exists "./.tcl/trails"] == 1 ? "./.tcl/trails" : "./"}]

#source ./.tcl/deps.tcl

package require logger
package require SimpleTemplater

source $::env(TRAILS_HOME)/configs/configs.tcl
namespace import ::trails::configs::get_env

namespace eval ::trails {}

foreach f [glob ./controllers/*.tcl] {
	set fname [lindex [split $f /] end]
	if {$fname != "controller.tcl"} {
		if {[get_env] == "dev"} {
			puts "::> load controller $f"
		}
		source $f
	}
}

foreach f [glob $::env(TRAILS_HOME)/filters/*.tcl] {
	set fname [lindex [split $f /] end]
	if {[get_env] == "dev"} {
		puts "::> load filter $f"
	}
	source $f
}

source $::env(TRAILS_HOME)/database/migrations.tcl
source $::env(TRAILS_HOME)/http/http_server.tcl
source $::env(TRAILS_HOME)/http/router.tcl
source $::env(TRAILS_HOME)/controllers/controller.tcl
source $::env(TRAILS_HOME)/database/db.tcl

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

	proc test {argc argv} {
	    
	    set params ""

	    if {$argc > 1} {

	        if {[lindex $argv 1] == "--help"} {
	            puts "::> Test usage:"
	            puts "::> configure -file patternList"
	            puts "::> configure -notfile patternList"
	            puts "::> configure -match patternList"
	            puts "::> configure -skip patternList"
	            puts "::> matchFiles patternList = shortcut for configure -file"
	            puts "::> skipFiles patternList = shortcut for configure -notfile"
	            puts "::> match patternList = shortcut for configure -match"
	            puts "::> skip patternList = shortcut for configure -skip"
	            puts "::> See more at https://wiki.tcl-lang.org/page/tcltest"
	            return
	        }

	        set params [lrange $argv 1 end]
	    }

	    
	    set testdir $::env(TRAILS_HOME)/tests

	    set cmd [list sh -c "tclsh $testdir/all.tcl -testdir $testdir $params | tee /dev/tty"]
	    exec {*}$cmd
	}	
}



proc trails_run_app {} {
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
		prod {
			set ::env(ENV) prod
			::trails::app::run	
		}
		dev {
			set ::env(ENV) dev
			::trails::app::run	
		}
		test {
			set ::env(ENV) test
			::trails::app::test	[expr {$argc - 1}] [lrange $argv 1 end]
		}
		default {
			puts "Usage:"
			puts ":: migrate => migrate database"
			puts ":: dev => run app prod mode"
			puts ":: prod => run app dev mode"
			puts ":: test => run app tests"
		}
	}
}