

source $::env(TRAILS_HOME)/database/result_set.tcl
source $::env(TRAILS_HOME)/configs/configs.tcl

namespace import ::trails::configs::*
namespace import ::trails::database::ResultSet

namespace eval ::trails::database::pool {
  variable MysqlPool
  variable log
  variable showsql
  set MysqlPool [list]
  set log [logger::init pool]

  namespace export acquire release show_sql

  proc show_sql {} {
    variable showsql
    return $showsql
  }

  proc print_size {} {
    variable MysqlPool
    variable log
    set size [llength $MysqlPool]
    ${log}::debug "pool size $size"
  }

  proc init {{count 1}} {
    variable MysqlPool
    variable log
    variable showsql

    set showsql [get_cfg datasource [get_env] show_sql]
    set id [llength $MysqlPool]

    for {set i 0} {$i < $count} {incr i} {
      incr $id
      set conn [connect false]
      $conn set_id $id
      lappend MysqlPool [dict create conn $conn busy false]
    }
  }

  proc acquire {} {
    variable MysqlPool

    set len [llength $MysqlPool]

    for {set i 0} {$i < $len} {incr i} {

      set item [lindex $MysqlPool $i]
      set conn [dict get $item conn]

      if {![dict get $item busy]} {
        dict set item busy true
        lset MysqlPool $i $item
        return $conn
      }
    }

    init 10

    acquire
  }

  proc release {currConn} {
    variable MysqlPool


    tx_complete $currConn

    set id [$currConn get_id]
    set len [llength $MysqlPool]

    for {set i 0} {$i < $len} {incr i} {
      set item [lindex $MysqlPool $i]
      set conn [dict get $item conn]

      if {[$conn get_id] == $id} {
        dict set item busy false      
        lset MysqlPool $i $item
        break
      }
    }
  }  

  proc tx_complete {rconn} {
    variable log 
    set handle [$rconn get_dbhandle]

    if {![$rconn is_autocommit]} {
      if {[$rconn has_error]} {
        if {[catch {::mysql::rollback $handle} err]} {
          if {$err != ""} {
            ${log}::error "error mysql rollback: $err"
          }
        }
      } else {
        if {[catch {::mysql::commit $handle} err]} {
          if {$err != ""} {
            ${log}::error "error mysql commit: $err"
          }
        }      
      }
    }
  }

  proc connect {{autocommit true}} {
    variable log
    set dbhandle {}
    set result [ResultSet new]
    set params [get_cfg datasource [get_env] database]
    set user [dict get $params user]
    set password [dict get $params password]
    set database [dict get $params db]
    set host [dict get $params host]
    set port [dict get $params port]

    if {[catch {set dbhandle [mysqlconnect -host $host \
                                            -port $port \
                                            -user $user \
                                            -password $password \
                                            -db $database]} err]} {    
      #$result set_error $err
      ${log}::error "database connect: $err"
      return -code error $err

    } else {
      ::mysql::autocommit $dbhandle $autocommit
      ::mysql::use $dbhandle $database
      $result set_dbhandle $dbhandle
      $result set_autocommit $autocommit
    }

    return $result
  } 

  proc close {rconn} {
    variable log 
    set handle [$rconn get_dbhandle]

    if {![$rconn is_autocommit]} {
      if {[$rconn has_error]} {
        if {catch {::mysql::rollback $handle} err} {
          ${log}::error "database rollback: $err"
          return -code error $err
        }
      } else {
        if {catch {::mysql::commit $handle} err} {
          ${log}::error "database commit: $err"
          return -code error $err
        }      
      }
    }

    if {catch {::mysql::close $handle} err} {
        ${log}::error "database close: $err"
        return -code error $err
    }        
  }
}