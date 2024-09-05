package require mysqltcl
package require logger
package require TclOO

source $::env(TRAILS_HOME)/database/result_set.tcl
source $::env(TRAILS_HOME)/database/pool.tcl

namespace import ::trails::database::pool::*

namespace eval ::trails::database::db {
  variable log
  set log [logger::init db]

  proc sanitaze {value} {
    #set regex1 {\D}
    #set regex2 {[^[:alpha:]]}
    #set regex {[^[:alnum:][:space:]]}
    #regsub -all $regex $value ""
    
    set value [regsub -all {'} $value {\'}]
    set value [regsub -all {"} $value {\"}]
    set value [regsub -all {;} $value {\;}]
    set value [regsub -all {\-} $value {\-}]

    return $value
  }

  proc replace_statements {query params} {

    set chars [split $query  ""]
    set len [llength $chars]
    set sql {}
    set pindex 0
    set skipAtIdx -1

    for {set i 0} {$i < $len} {incr i} {

      if {$skipAtIdx > 0 && $i <= $skipAtIdx} { continue }
      
      set char [lindex $chars $i]

      if {"$char" == "?"} {

        if {$pindex >= [llength $params]} {
          return -code error "wrong param index $pindex"
        }

        set param [lindex $params $pindex]
        set param [sanitaze $param]

        #if {$param eq "null"} {
        #  continue
        #}

        switch "$param" {
          "true" {
            set sql $sql'1'
          }
          "false" {
            set sql $sql'0'
          }
          "null" {
            set sql "${sql}null"
          }
          default {
            set sql $sql'$param'
          }
        }

        incr pindex

      } elseif {"$char" == ":"} {
        
        set restOfQuery [string range $query $i+1 end]
        set nextArg [split $restOfQuery " "]
        set argKey [lindex $nextArg 0]
        set skipAtIdx [expr $i + [string length $argKey]]

        if {![dict exists $params $argKey]} {
          return -code error "wrong param key $argKey"
        }

        set param [dict get $params $argKey]
        set param [sanitaze $param]

        #if {$param eq "null"} {
        #  continue
        #}

        switch "$param" {
          "true" {
            set sql $sql'1'
          }
          "false" {
            set sql $sql'0'
          }
          "null" {
            set sql "${sql}null"
          }        
          default {
            set sql $sql'$param'
          }
        }

      } else {
        set sql $sql$char
      }
    }

    return $sql
  }

  proc compile_query {query params} {
    switch -regexp -- $query {
      {\?} {
        return [replace_statements $query $params]
      }
      {:} {
        return [replace_statements $query $params]
      }   
      default {
        return $query
      } 
    }
  }

  proc exec {sql {trans {}}} {
    variable log
    set is_trans [expr { $trans != ""}]

    if {$is_trans} {
      set rconn $trans
    } else {
      set rconn [acquire]
    }

    set handle [$rconn get_dbhandle]

    if {[show_sql]} {
      ${log}::debug "SQL: $sql"
    }

    try {
      ::mysql::exec $handle $sql
    } finally {  
      if {!$is_trans} {
        release $rconn
      }
    }
  }

  proc raw_sql {sql {trans {}}} {
    variable log
    set is_trans [expr { $trans != ""}]

    if {$is_trans} {
      set rconn $trans
    } else {
      set rconn [acquire]
    }

    set handle [$rconn get_dbhandle]

    if {[show_sql]} {
      ${log}::debug "SQL: $sql"
    }

    set rows [list]
    try {
      set rows [::mysql::sel $handle $sql -list]
    } finally {  
      if {!$is_trans} {
        release $rconn
      }
    }
    return $rows
  }

  proc raw_sql_first {sql {trans {}}} {

    set result [raw_sql $sql $trans]

    if {[llength $result] == 0} {
      return {}
    }

    lindex $result 0
  }

  proc select {query {params {}} {trans {}}} {
    set sql [compile_query $query $params]
    return [raw_sql $sql $trans]
  }

  proc select_one {query {params {}} {trans {}}} {
    set sql [compile_query $query $params]
    return [raw_sql_first $sql $trans]
  }

  proc execute_query {query {params {}} {trans {}}} {
    set sql [compile_query $query $params]
    return [raw_sql $sql $trans]
  }

  proc execute_batch {query {params {}} {trans {}}} {
    variable log
    set is_trans [expr {$trans != ""}]


    set sqls [list $query]

    if {[string match {*;*} $query]} {
      set vals [split $query \;]
      set sqls {}
      foreach s $vals {
        if {[string trim $s] != ""} {
          lappend sqls $s
        }
      }
    }
    
    set hasArgs [expr [llength $params] > 0]

    if {$hasArgs && [llength $params] != [llength $sqls]} {
      return -code error {wrong params count}
    }

    set idx 0

    if {$is_trans} {
      set rconn $conn
    } else {
      set rconn [acquire]
    }

    try{
      set handle [$rconn get_dbhandle]  

      foreach sql $sqls {      
        set arg {}
        
        if {$hasArgs} {
          set arg [lindex $params $idx]
          incr idx
        }

        set sql [compile_query $sql $params]

        if {[show_sql]} {
          ${log}::debug "SQL: $sql"
        }

        ::mysql::exec $handle $sql    
      }

    } finally {
      if {!$is_trans} {
        release $rconn
      }    
    }
  }

  proc tx {lambda args} {
    variable log

    if {[show_sql]} {
      ${log}::debug "TX: open"
    }

    set conn [acquire]
    set result ""

    try {
      set params [list $conn {*}$args]
      set result [apply $lambda {*}$params]      
    } finally {
      if {[show_sql]} {
        ${log}::debug "TX: close"
      }
      release $conn
    }
    
    return $result
  }

  proc get_last_id {{trans ""}} {
    set row [raw_sql_first {SELECT LAST_INSERT_ID()} $trans]
    lindex $row 0 
  }

  #
  # run database insert, return new ID generated
  #
  proc insert {table entity {trans {}}} {

    variable log

    set fields ""
    set stmts ""
    set values {}

    dict for {k v} $entity {
      set fields "${fields}${k}, "
      set stmts "${stmts}?, "
      lappend values $v
    }

    set fields [string range $fields 0 end-2]
    set stmts [string range $stmts 0 end-2]

    set sql_insert "INSERT INTO $table ( $fields ) VALUES ( $stmts );"

    if {[show_sql]} {
      ${log}::debug "SQL: $sql_insert"
    }

    if {$trans == ""} {
      set result [tx { {t values sql_insert} {
        ::trails::database::db::execute_query $sql_insert $values $t
        ::trails::database::db::get_last_id $t
      }} $values $sql_insert]
    } else {
      execute_query $sql_insert $values $t
      set result [get_last_id]    
    }

    return $result
  }

  proc update {table key entity {trans {}}} {

    set fields ""
    set values {}
    set kname [lindex $key 0]
    set kval [lindex $key 1]

    dict for {k v} $entity {
      if {$k == $kname} { continue }
      set fields "${fields}${k} = ?, "
      lappend values $v
    }

    lappend values $kval

    set fields [string range $fields 0 end-2]

    set sql "UPDATE $table SET $fields WHERE $kname = ?"

    if {$trans == ""} {
      tx { {t values sql} {
        ::trails::database::db::execute_query $sql $values $t
      }} $values $sql
    } else {
      execute_query $sql $values $t
    }  
  }

  proc count {table key {trans {}}} {
    set kname [lindex $key 0]
    set kval [lindex $key 1]
    set sql "SELECT COUNT(*) FROM $table WHERE $kname = ?"
    set r [select_one $sql $kval $trans]
  }

  proc delete {table key {trans {}}} {
    set kname [lindex $key 0]
    set kval [lindex $key 1]
    set sql "DELETE FROM $table WHERE $kname = ?"
    return [execute_query $sql $kval $trans]
  }

  proc first {table cols key {trans {}}} {
    set kname [lindex $key 0]
    set kval [lindex $key 1]  
    set fields [join $cols ", "]
    set sql "SELECT $fields FROM $table WHERE $kname = ? LIMIT 1"
    return [select_one $sql $kval $trans]
  }

  proc all {table cols {trans {}}} {
    set fields [join $cols ", "]
    set sql "SELECT $fields FROM $table"
    return [select $sql "" $trans]
  }

  proc where {table cols cond params {more {}} {trans {}}} {
    set fields [join $cols ", "]
    set orderBy [util::get_or $more orderBy ""]
    set limit [util::get_or $more limit 0 ]
    set offset [util::get_or $more offset 0 ]

    if {[expr {$limit > 0}]} {
      set limit "LIMIT $limit"
    } else {
      set limit ""
    }

    if {[expr {$offset > 0}]} {
      set offset "OFFSET $offset"
    } else {
      set offset ""
    }

    if {$orderBy ne ""} {
      set orderBy "ORDER BY $orderBy"
    }

    set sql "SELECT $fields FROM $table WHERE $cond $orderBy $limit $offset"
    return [select $sql $params $trans]
  }

  proc where_first {table cols cond params {trans {}}} {
    set fields [join $cols ", "]
    set sql "SELECT $fields FROM $table WHERE $cond LIMIT 1"
    return [select_one $sql $params $trans]
  }
}
