package require logger

source $::env(TRAILS_HOME)/database/db.tcl
source $::env(TRAILS_HOME)/misc/util.tcl
source $::env(TRAILS_HOME)/configs/configs.tcl

namespace eval ::trails::database::migrations {
	set log [logger::init migrations]

	set table_create_sql {
		create table if not exists migrations (
			id int primary key auto_increment,
			version varchar(10) not null,
			created_at datetime default now()
		)
	}

	proc create_table {} {
		variable log
		variable table_create_sql
		#${log}::debug "CREATE TABLE migrations"
		::trails::database::db::exec $table_create_sql
	}

	proc list_migrations {} {
		set rows [::trails::database::db::raw_sql {SELECT version FROM migrations}]
		lmap row $rows { lindex $row 0 }
	}

	proc run {} {
		variable log

		create_table

		set base ./migrations
		set migrations [list_migrations]

		set data [dict create]

		foreach f [glob "${base}/*.sql"] {            	
	    	set version [::trails::misc::util::filter_number $f]
	    	dict set data $version $f
		}

		set versions [lsort -integer [dict keys $data]]

		foreach version $versions {
	    	if {[lsearch -exact $migrations $version] < 0} {
	    		set f [dict get $data $version]
	    		set fd [open $f]
	    		set contents [read $fd]
	    		close $fd
	    		run_migration $version $contents
	    	} else {
	    		${log}::debug "skip migration $version"
	    	}		
		}
	}

	proc run_migration {version contents} {
		variable log

		${log}::debug "run migration $version"

		set sqls {}
		set sql {}
		foreach line [split $contents \n] {
			set line [string trim $line]
			if [string match --* $line] {
				continue
			}

			set sql "$sql $line"

			if [string match *\; $line] {
				lappend sqls $sql
				set sql {}
			}
		}

		if {[llength $sqls] == 0} {
			${log}::debug "no sqls found to migration $version"
		}

		foreach sql $sqls {
			set sql [string range [string trim $sql] 0 end-1]
			::trails::database::db::exec $sql
		}

		migration_done $version
	}

	proc migration_done {version} {
		::trails::database::db::exec "INSERT INTO migrations (version) values ('$version')"
	}
}
