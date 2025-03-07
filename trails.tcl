
package provide trails 0.1


set ::env(TRAILS_HOME) [expr {[file exists "./.tcl/trails"] == 1 ? "./.tcl/trails" : "./"}]

package require tfast
package require logger
package require SimpleTemplater

source $::env(TRAILS_HOME)/configs/configs.tcl
source $::env(TRAILS_HOME)/dev/watch.tcl
source $::env(TRAILS_HOME)/database/migrations.tcl
source $::env(TRAILS_HOME)/controllers/controller.tcl
source $::env(TRAILS_HOME)/services/service.tcl
source $::env(TRAILS_HOME)/database/db.tcl
source $::env(TRAILS_HOME)/template_generator.tcl
source $::env(TRAILS_HOME)/domain/active_record.tcl

namespace import ::trails::configs::*
namespace import ::tfast::*
namespace import ::trails::controllers::AppController
namespace import ::trails::template::generator::*

namespace eval ::trails {
    namespace export run_app
}

# load controllres

foreach f [glob ./app/domain/*.tcl] {
    set fname [file tail $f]
    if {[config getenv] == "dev"} {
	puts "::> load domain $f"
    }
    source $f
}

foreach f [glob ./app/services/*.tcl] {
    set fname [file tail $f]
    if {[config getenv] == "dev"} {
	puts "::> load service $f"
    }
    source $f
}

foreach f [glob ./app/controllers/*.tcl] {
    set fname [file tail $f]
    if {[config getenv] == "dev"} {
	puts "::> load controller $f"
    }
    source $f
}

# load filters
foreach f [glob $::env(TRAILS_HOME)/filters/*.tcl] {
    set fname [file tail $f]
    if {[config getenv] == "dev"} {
	puts "::> load filter $f"
    }
    source $f
}

namespace import ::trails::filters::*

namespace eval ::trails::app {
	
    variable log
    set log [logger::init ::trails::app]

    proc configure_routes {} {
	variable log

	tfast register routes [config get web routes]
	
	foreach cls [info class subclasses AppController] {
	    set obj [$cls new]
	    $obj controller_configure
	    tfast register scaffold $obj
	}

	tfast print -all
    }

    proc configure_public {} {

	set public_paths [config get web public assets]
	set public_exts [config get web public extensions]

	foreach dir $public_paths {
	    tfast register public dir $dir
	}
	tfast register public extension $public_exts	
    }

    proc register_filters {} {
	tfast register filter instance [FilterJson new]
	tfast register filter instance [FilterHtmlTemplate new]
    }

    proc http_serve {} {

	variable log
	variable ServerSocket

	set port [config get web server port]	
	set workers [config get web server workers]
	set hostname [config get web server workers]
	set backend [config get web server backend]
	set pool_size [config get datasource [config getenv] pool_size]

	
	set backendfs .tcl/tfast/http/backend/$backend.tcl
	uplevel #0 source $backendfs
	
	${log}::info "workers=$workers, pool size=$pool_size"
	${log}::info "http server started on http://localhost:$port"

	::trails::database::pool::init $pool_size

	tfast serve \
	    -port $port \
	    -host $hostname \
	    -workers $workers \
	    -backend $backend       
    }


    proc run {} {		
	configure_public
	register_filters
	configure_routes
	http_serve
    }

    proc test {argc argv} {
	
	set params $argv

	if {$argc > 0 && [lindex $argv 0] == "--help"} {
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
	
	set testdir $::env(TRAILS_HOME)/tests

	set cmd [list sh -c "tclsh $testdir/all.tcl -testdir $testdir $params | tee /dev/tty"]
	exec {*}$cmd
    }	
}

proc get_all_files_to_watch {path {files ""}} {

    foreach f [exec {*}[list ls $path]] {	
	set fpath $path/$f	
	if {[file isdirectory $fpath]} {
	    set files [get_all_files_to_watch $fpath $files]
	} else {
	    #puts "::> add file watch $fpath"
	    lappend files $fpath
	}
    }

    return $files
}

proc app_restart {} {
    set cmd [list $::argv0 {*}$::argv &]
    exec {*}$cmd

    set cmd [list kill [pid]]	
    exec {*}$cmd
}

proc watcher_start {} {	
    set curr_path [file dirname [file normalize [info script]]]
    set files [get_all_files_to_watch $curr_path]
    set files [get_all_files_to_watch $curr_path/.tcl $files]

    puts "::> watching changes into $curr_path"

    foreach f $files {
	watch::FSChange $f 1000 {
	    puts "::> file %O changed!"
	    app_restart
	}
    }
}


proc trails::show_usage {} {
    puts "::"
    puts ":: Usage:"
    puts "::"
    puts ":: migrate:  migrate database"
    puts ":: dev:      run app prod mode"
    puts ":: prod:     run app dev mode"
    puts ":: test:     run app tests"
    puts ":: generate <domain|service|controller|views|all> <domain name>: generate code by templates"
    puts "::"
}

proc trails::run_app {} {
    global argc
    global argv
    set opt ""

    config init

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
	    watcher_start
	    ::trails::app::run
	}
	test {
	    set ::env(ENV) test
	    ::trails::app::test	[expr {$argc - 1}] [lrange $argv 1 end]
	}
	generate {
	    foreach {_ opt domain} $argv {

		if {$opt == ""} {
		    puts "::> invalid option"
		    exit 1
		}
		
		if {$domain == ""} {
		    puts "::> domain name is required"
		    exit 1
		}

		switch $opt {
		    domain {
			generate-domain $domain
		    }
		    service {
			generate-service $domain
		    }
		    controller {
			generate-controller $domain
		    }
		    views {
			generate-views $domain
		    }
		    all {
			generate-all $domain
		    }
		    default {
			puts "::> invalid option"
		    }
		}
		
	    }
	}
	help {
	    show_usage
	}
	default {
	   show_usage
	}
    }
}
