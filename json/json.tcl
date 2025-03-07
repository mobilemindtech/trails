

source $::env(TRAILS_HOME)/misc/util.tcl

package require sjson

namespace import ::sjson::*

namespace eval ::trails::json {

  namespace export \
    model_to_json \
    model_list_to_json

  proc model_to_json {model args} {
    set json [$model to_json]
    dict with json {
      encode dict $data -tpl $tpl
    }    
  }

  proc model_list_to_json {models args} {
    set items [lmap it $models {$it to_json_data}]

    if {[llength $models] == 0} {
      return {[]}
    }

    set tpl [[lindex $models 0] to_json_tpl]

    encode list $items -tpl $tpl
  }
}

