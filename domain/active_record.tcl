
source $::env(TRAILS_HOME)/database/db.tcl
source $::env(TRAILS_HOME)/database/sql.tcl

namespace import ::tools::Props

namespace eval ::trails::models {

    variable log
    variable Models
    set log [logger::init active_record]
    set Models {}

    namespace export ActiveRecord

    catch {
	oo::class create Model {
	    superclass Props
	    variable table_name
	} 
    }

    oo::define Model {

	constructor {} {
	    my variable table_name
	    set allowed_props {}

	    set fields [my get_fields]
	    foreach {k _} $fields {
		lappend allowed_props $k
	    }
	    set table_name [my get_table_name]
	    next {*}$allowed_props
	}

	method get_table_name {} {
	    ::trails::models::Dispatch [info object class [self]] get_table_name 
	}

	method get_fields {} {
	    ::trails::models::Dispatch [info object class [self]] get_fields 
	}

	method save {} {
	    ::trails::models::DispatchWihtArgs [info object class [self]] save [self]
	}

	method update {} {
	    ::trails::models::DispatchWihtArgs [info object class [self]] update [self]
	}

	method delete {} {
	    ::trails::models::DispatchWihtArgs [info object class [self]] delete [self]
	}
	
	method to_json {} {			
	    ::trails::models::DispatchWihtArgs [info object class [self]] to_json [self]
	}

	method to_json_data {} {			
	    ::trails::models::DispatchWihtArgs [info object class [self]] to_json_data [self]
	}

	method to_json_tpl {} {			
	    ::trails::models::DispatchWihtArgs [info object class [self]] to_json_tpl [self]
	}
    }

    proc ActiveRecord {cfg} {
	variable Models
	variable log
	

	# add inherits Model
	uplevel 1 {superclass ::trails::models::Model}

	# static methods
	set actions [list get count exists with_transaction with_new_transaction find_all find find_by_key]
	foreach action $actions {
	    set body { ::trails::models::DispatchWihtClass [self] [self method] {*}$args }
	    uplevel 1 [list self method $action {args} $body]
	}
	
	# get class
	set cls [lindex [info level -1] 1]


	set table_name {}
	set fields {}

	foreach {k v} $cfg {
	    switch $k {
		table_name {
		    set table_name $v
		}
		fields {
		    set fields $v
		} 
	    }
	}
	
	# configure model info
	dict set Models $cls [Domain new -table_name $table_name -fields $fields -class $cls]
    }

    catch {
	oo::class create Domain {
	    variable domain
	}
    }

    # dispatch action without args
    proc Dispatch {cls action} {
	variable Models
	set domain [dict get $Models $cls]
	$domain $action
    }

    # dispatch action with args
    proc DispatchWihtArgs {cls action args} {
	variable Models
	set domain [dict get $Models $cls]
	$domain $action {*}$args
    }

    # dispatch action without args and call method with class on first arg
    proc DispatchWihtClass {cls action args} {
	variable Models
	set domain [dict get $Models $cls]
	$domain $action $cls {*}$args
    }

    oo::define Domain {
	
	constructor {args} {
	    my variable domain

	    set domain {}

	    foreach {k v} $args {
		switch -regexp -- $k {
		    -table_name|table_name {
			dict set domain table_name $v
		    }
		    -fields|fields {
			dict set domain fields $v
		    }
		    -class {
			dict set domain cls $v
		    }
		} 
	    }
	}

	method get_domain_info {entity} {
	    my variable domain
	    
	    set table [my get_table_name]
	    set vals [dict create]
	    set kname ""
	    set kval ""
	    set kfield ""
	    set columns [my get_columns]
	    set is_entity [expr {[info object isa object $entity] && [info object class $entity Props]}]

	    foreach {fieldname defs} $columns {
		set colname [lindex $defs 0]		
		if {[lsearch -exact [string range $defs 1 end] key] >= 0} {
		    set kname $colname
		    set kfield $fieldname
		    if {$is_entity && [$entity present $fieldname]} {
			set kval [$entity prop $fieldname]
		    }
		}
		if {$is_entity && [$entity present $fieldname]} {
		    dict set vals $colname [$entity prop $fieldname]
		}
	    }

	    dict create \
		table $table \
		vals $vals \
		key [list $kname $kval]	\
		kname $kname \
		kval $kval \
		kfield $kfield
	}

	method get_fields {} {
	    my variable domain
	    dict get $domain fields
	}

	method get_columns {} {
	    my variable domain
	    set columns {}
	    foreach {fieldname defs} [dict get $domain fields] { 
		set coldefs [lindex $defs 0]
		dict set columns $fieldname $coldefs 		
	    }	

	    return $columns
	}

	method get_columns_json {} {
	    my variable domain
	    set columns {}
	    foreach {fieldname defs} [dict get $domain fields] {

		if {[llength $defs] <= 1} { continue } 

		set coldefs [lindex $defs 1]
		dict set columns $fieldname $coldefs 		
	    }	

	    return $columns
	}

	method get_table_name {} {
	    my variable domain
	    dict get $domain table_name
	}

	method row_to_domain {cls row} {
	    set columns [my get_columns]
	    set entity [$cls new]
	    set i 0
	    foreach {field _} $columns {
		$entity prop $field [lindex $row $i]
		incr i
	    }
	    return $entity
	}

	method save args { 
	    set entity [lindex $args 0]
	    set data [my get_domain_info $entity]			
	    dict with data {		
		set id [::trails::database::db::insert $table $vals]				
		$entity prop $kfield $id
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

	method count {cls args} {
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

	method exists {cls args} {
	    set count [my count $cls {*}$args]
	    expr {$count > 0}
	}

	method with_transaction {cls args} {
	    return {with_transaction}
	}

	method with_new_transaction {cls args} {
	    return {with_new_transaction}
	}

	method find_all {cls args} {
	    set table_name [my get_table_name]
	    set columns [my get_columns]

	    set upl 2
	    set idx [lsearch -exact $args -uplevel]
	    if {$idx >= 0} {
		set upl [lindex $args [expr {$idx + 1}]]
	    }

	    set sql [::trails::database::sql::build $table_name $columns {*}$args -uplevel $upl]
	    set rows [::trails::database::db::raw_sql $sql] 
	    if {$rows == ""} { return [list] }
	    lmap row $rows { my row_to_domain $cls $row }  	
	}

	method find {cls args} {
	    set table_name [my get_table_name]
	    set columns [my get_columns]

	    set sql [::trails::database::sql::build $table_name $columns {*}$args -limit 1]
	    set row [::trails::database::db::raw_sql_first $sql] 
	    if {$row == ""} { return {} }
	    my row_to_domain $cls $row
	}		

	method find_by_key {cls args} {
	    set table_name [my get_table_name]
	    set data [my get_domain_info {}]
	    set columns [my get_columns]			
	    dict with data {				
		set where [list $kfield = ?]
		set sql [::trails::database::sql::build $table_name $columns $where {*}$args -limit 1]
		set row [::trails::database::db::raw_sql_first $sql] 
		if {$row == ""} { return {} }
		my row_to_domain $cls $row			
	    }
	}

	method to_json_data {args} {
	    dict get [my to_json {*}$args] data
	}

	method to_json_tpl {args} {
	    dict get [my to_json {*}$args] tpl
	}

	method to_json args {
	    set columns [my get_columns_json]
	    set entity [lindex $args 0]
	    set data {}
	    set tpl {}

	    
	    dict for {k defs} $columns {

		set name [lindex $defs 1]
		set typ [lindex $defs 2]

		set val [$entity prop $k]
		dict set data $name $val
		dict set tpl $name $typ
	    }

	    dict create data $data tpl $tpl
	}
    }	
}
