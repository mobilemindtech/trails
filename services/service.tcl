#!/bin/tclsh

package require logger

source $::env(TRAILS_HOME)/database/sql.tcl
source $::env(TRAILS_HOME)/database/db.tcl

namespace eval ::trails::services {

	#rename unknown __unknown__

	catch {
		oo::class create Service {
			variable domain slog	
		}		
	}

	namespace export Service

	oo::define Service {

		constructor {args} {
			my variable domain slog

			foreach {k v} $args {
				switch -regexp -- $v {
					-domain|domain {
						set domain $v
					}
				}
			}

			set slog [logger::init Service]
		}

		method get_domain_info {entity} {
			my variable domain
			
			set table [my get_table_name]
			set vals [dict create]
			set kname ""
			set kval ""
			set kfield ""
			set columns [my get_columns]

			foreach {fieldname defs} $columns {
				set colname [lindex $defs 0]		
				if {[lsearch -exact [string range $defs 1 end] key] >= 0} {
					set kname $colname
					set kfield $fieldname
					if {[dict exists $entity $fieldname]} {
						set kval [dict get $entity $fieldname]
					}
				}
				if {[dict exists $entity $fieldname]} {
					dict set vals $colname [dict get $entity $fieldname]
				}
			}

			dict create table $table vals $vals key [list $kname $kval]	kname $kname kval $kval kfield $kfield
		}

		method get_columns {} {
			my variable domain
			set columns [dict create]
			foreach {fieldname defs} [dict get $domain fields] { 
				set coldefs [lindex $defs 0]
				dict set columns $fieldname $coldefs 		
			}	

			return $columns
		}

		method get_table_name {} {
			my variable domain
			dict get $domain table_name
		}

		method row_to_domain {row} {
			set columns [my get_columns]
			set entity [dict create]
			set i 0
			foreach {field _} $columns {
				dict set entity $field [lindex $row $i]
				incr i
			}
			return $entity
		}

		method save args { 
			set entity [lindex $args 0]
			set data [my get_domain_info $entity]
			dict with data {		
				set id [::trails::database::db::insert $table $vals]				
				dict set entity $kfield $id
				return $entity
			}
		} 

		method update args {
			set entity [lindex $args 0]
			set data [my get_domain_info $entity]
			dict with data {		
				::trails::database::db::update $table $key $vals
			}
		}

		method delete args {
			set entity [lindex $args 0]
			set data [my get_domain_info $entity]
			dict with data {		
				::trails::database::db::delete $table $key
			}
		}

		method get args {
			set id [lindex $args 0]	
			set data [my get_domain_info {}]
			dict with data {
				my find "$kname = ?" $id
			}
		}

		method count args {
			set table_name [my get_table_name]
			set columns [my get_columns]

			set upl 2
			set idx [lsearch -exact $args -uplevel]
			if {$idx >= 0} {
				set upl [lindex $args [expr {$idx + 1}]]
			}

			set sql [::trails::database::sql::build $table_name $columns {*}$args -uplevel $upl -count]
			set row [::trails::database::db::raw_sql_first $sql] 
			if {$row == ""} {
				return 0
			}
			lindex $row 0   		
		}

		method exists args {
			set count [my count {*}$args]
			expr {$count > 0}
		}

		method with_transaction args {
			return {with_transaction}
		}

		method with_new_transaction args {
			return {with_new_transaction}
		}

		method find_all args {
			set table_name [my get_table_name]
			set columns [my get_columns]

			set upl 2
			set idx [lsearch -exact $args -uplevel]
			if {$idx >= 0} {
				set upl [lindex $args [expr {$idx + 1}]]
			}

			set sql [::trails::database::sql::build $table_name $columns {*}$args -uplevel $upl]
			set rows [::trails::database::db::raw_sql $sql] 
			if {$rows == ""} {
				return [list]
			}
			lmap row $rows { my row_to_domain $row }  	
		}

		method find args {
			set table_name [my get_table_name]
			set columns [my get_columns]

			lappend args {limit 1 offset 0}
			set sql [::trails::database::sql::build $table_name $columns {*}$args]
			set row [::trails::database::db::raw_sql_first $sql] 
			if {$row == ""} {
				return {}
			}
			my row_to_domain $row
		}		
	}	
}








#services::find {id = ? and name = ?} {$id $name} {group by name} {order by name}
#
#services::find_all {id = ? and name = ?} {$id $name} {group by name} {order by name} {limit 10 offset 10}