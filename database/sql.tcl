package require logger

namespace eval ::trails::database::sql {
    set debug false
    set log [logger::init sql_builder]


    #
    # Build a SQL
    # 
    # @param table_name table name
    # @param columns { id {id_ int key} name {name_ string}} 
    # @param args {conditions} {replacements} {group by} {order by} {limit offset} {uplevel 1}
    # @param -stmt not replace replacements on string
    # @return SQL 
    proc build {table_name columns args} {

	variable debug 
	variable log

	if {$debug} {
	    ${log}::debug "ARGS: $args"
	}

	set where {}
	set replacements {}
	set order_by {}
	set group_by {}
	set limit -1
	set offset -1
	set use_stmt false
	set upl 1
	set count false
	set cols {}
	set alias X0
	set joins {}
	set natives {}

	set argc [llength $args]
	set argv [list]
	for {set i 0} {$i < $argc} {incr i} {
	    set arg [lindex $args $i]

	    switch $arg {
		-uplevel {
		    incr i
		    set upl [lindex $args $i]
		    continue
		}
		-count {
		    set count true
		    continue
		}
		-stmt {
		    set use_stmt true
		    continue
		}
		-cols {
		    incr i
		    set cors [lindex $args $i]
		    continue
		}
		-limit {
		    incr i
		    set limit [lindex $args $i]
		    continue
		}
		-offset {
		    incr i
		    set offset [lindex $args $i]
		    continue
		}
		-group_by {
		    incr i
		    set group_by [lindex $args $i]
		    continue
		}
		-order_by {
		    incr i
		    set order_by [lindex $args $i]
		    continue
		}
		-where {
		    incr i
		    set where [lindex $args $i]
		    continue
		}			
		-replacements {
		    incr i
		    set replacements [lindex $args $i]
		    continue
		}	
		-alias {
		    incr i
		    set alias [lindex $args $i]
		    continue
		}		
		-join {
		    incr i
		    lappend joins [lindex $args $i]
		    continue
		}	
		-native {
		    incr i
		    lappend natives [lindex $args $i] 
		    continue					
		}	
	    } 	

	    lappend argv $arg
	} 

	set argc [llength $argv]

	if {$argc == 1} {
	    set where [lindex $argv 0]	
	} elseif {$argc > 1} {

	    set idx [lsearch -exact $argv limit]
	    if {$idx > 0} {
		set limit [lindex $argv [expr {$idx + 1}]]
	    }

	    set idx [lsearch -exact $argv offset]
	    if {$idx > 0} {
		set offset [lindex $argv [expr {$idx + 1}]]
	    }

	    set where [lindex $args 0]		
	    set replacements [lindex $args 1]

	    foreach arg [lrange $args 2 end] {
		set size [llength $arg]

		if {$size > 1} {
		    set k [lindex $arg 0]
		    if {$k == "limit"} {
			set limit [lindex $arg 1]
		    } elseif {$k == "offset"} {
			set offset [lindex $arg 1]
		    }				
		}

		if {$size > 2} {
		    set typ "[lindex $arg 0] [lindex $arg 1]"

		    switch $typ {
			{group by} {
			    set group_by {GROUP BY}
			    set vals {GROUP BY}
			    foreach field $arg {
				if {[lsearch -exact [string toupper $field] $vals]} {
				    set group_by "$group_by [string toupper $field]" 
				} else {
				    foreach {k v} $columns {
					if {$k == $field} {
					    set group_by "$group_by [lindex $v 0]"
					    continue
					}
				    }
				}
			    }
			    continue
			}
			{order by} {
			    set order_by {ORDER BY}
			    set vals {ORDER BY ASC DESC}
			    foreach field $arg {
				if {[lsearch -exact [string toupper $field] $vals]} {
				    set order_by "$order_by [string toupper $field]" 
				} else {
				    foreach {k v} $columns {
					if {$k == $field} {
					    set order_by "$order_by [lindex $v 0]"
					    continue
					}
				    }
				}
			    }
			    continue
			}
		    }
		}		
	    }
	}

	set where_body $where	

	if {[string match *\$* $where]} {
	    set where_body [list]

	    foreach  var {*}$where {
		if {[string match \$* $var]} {
		    set val [uplevel $upl "set $var $var"]
		    lappend where_body $val
		} else {
		    lappend where_body $var
		}
	    }		
	}

	foreach {k v} $columns {
	    set col_name [lindex $v 0]
	    
	    if {[string match "* $k *" $where_body]} {
		set where_body [regsub " $k " $where_body " $alias.$col_name "]
	    } elseif {[string match "$k *" $where_body]} {
		set where_body [regsub "$k " $where_body "$alias.$col_name "] 
	    }

	    if {[string match "* $k *" $order_by]} {
		set order_by [regsub " $k " $order_by " $alias.$col_name "]
	    } 

	    if {[string match "* $k *" $group_by]} {
		set group_by [regsub " $k " $group_by " $alias.$col_name "]
	    } 
	}	

	if {!$use_stmt} {
	    set where_params [list]

	    foreach repl $replacements {
		if {[string match *\$* $repl]} {
		    lappend where_params [uplevel $upl "set $repl $repl"]
		} else {
		    lappend where_params $repl
		}
	    }

	    set where [load_where_params $where_body $where_params]
	}

	set query "SELECT"

	if {$count} {
	    set query "$query COUNT(*)"
	} else {
	    if {[llength $cols] > 0} {
		foreach col $cols {
		    set query "$query $alias.$col,"
		}
	    } else {
		foreach {_ v} $columns {
		    set col_name [lindex $v 0]
		    set query "$query $alias.$col_name,"
		}
	    }
	    set query [string range $query 0 end-1]
	}


	if {[llength $where] > 0} {
	    set where "WHERE $where"
	}

	if {[llength $natives ] > 0} {
	    if {[llength $where] > 0} {
		set where "$where AND [join $natives]" 
	    } else {
		set where "WHERE [join $natives]"
	    }
	}

	
	if {[llength $joins] > 0} {
	    set joins [join $joins " "] 
	}

	set from "$table_name $alias"

	set query [string trim "$query FROM $from $joins $where $group_by $order_by"]

	if {$limit > 0} {
	    set query "$query LIMIT $limit"
	}

	if {$offset > 0} {
	    set query "$query OFFSET $offset"
	}
	
	if {$debug} {
	    ${log}::debug "SQL: $query"
	}

	return $query
    }

    proc load_where_params {where where_params} {
	set where_with_params {}
	set j 0
	for {set i 0} {$i < [llength $where]} {incr i} {
	    set c [lindex $where $i]
	    if {$c == "?"} {
		set c '[lindex $where_params $j]'
		incr j
	    }
	    lappend where_with_params $c
	}	
	return [join $where_with_params " "]
    }
}
