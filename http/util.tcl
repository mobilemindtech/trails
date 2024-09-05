
source $::env(TRAILS_HOME)/http/codes.tcl
source $::env(TRAILS_HOME)/http/mimes.tcl

namespace eval ::trails::http::util {

  proc body_parse { body contentType } {

    switch -regexp -- $contentType {
      application/json {
        return [json2dict $body]
      }
      application/x-www-form-urlencoded {
        set d [dict create]
        foreach pair [split $body "&"]  {
          set kv [split $pair "="]
          set k [lindex $kv 0]
          set v [split [lindex $kv 1] ,]
          if {[llength $v] == 1} {
          	set v [lindex $v 0]
          } elseif {[llength $v] == 0} {
          	set v {}
          }
          dict set d $k $v
        }
        return $d
      }
      default {
        return $body
      }
    }
  }

  proc send_file {chan path {download false}} {
    set assetFile $path
    #puts "assetFile = $assetFile, exists = [file exists $assetFile]"

    if {[file exists $assetFile] == 0 } {
      response_write $chan 404    
    } else {
      if {[catch {
        

        if {$download} {
          set contentType "application/octet-stream"
        } else {
          set splited [split $path .]
          set ext [lindex $splited end]
          set contentType [get_mime .$ext application/octet-stream]       
        }

        set fsize [file size $assetFile]
        set assetFile [open $assetFile r]
        fconfigure $assetFile -translation binary
        set assetContent [read $assetFile]

        close $assetFile 
        
        set headers [dict create content-length $fsize] 

        chan configure $chan -translation binary
        response_write $chan -body $assetContent -status 200 -content-type $contentType -headers $headers

      } err]} {
        response_write $chan -body {server error} -status 500
      }
    }  
  }

  proc not_found {chan args} {
    set data [list -body {not found} -status 404]
    send $chan {*}[list {*}$data {*}$args]
  }

  proc server_error {chan args} {
    set data [list -body {server error} -status 500]
    send $chan {*}[list {*}$data {*}$args]
  }

  proc bad_request {chan args} {
    set data [list -body {bad request} -status 400]
    send $chan {*}[list {*}$data {*}$args]
  }

  proc unauthorized {chan args} {
    set data [list -body {bad request} -status 401]
    send $chan {*}[list {*}$data {*}$args]
  }

  proc unauthorized {chan args} {
    set data [list -body {forbiden} -status 403]
    send $chan {*}[list {*}$data {*}$args]
  }

  proc ok {chan args} {
    send $chan {*}$args
  }

  proc send_response {chan response} {

    if {[$response present file]} {
      send_file chan [$response prop file]
      return
    }

    send  $chan \
              -status [$response prop status] \
              -body [$response prop body] \
              -content-type [$response prop content-type] \
              -headers [$response prop headers]
  }

  proc send {chan args} {

    set contentType text/plain
    set headers {}
    set find_ctype true
    set body {}
    set status 200

    foreach {k v} $args {
      switch -regexp -- $k {
        -content-type|content-type {
          set contentType $v
          set find_ctype false
        }
        -headers|headers {
          set headers $v
        }
        -body|body {
          set body $v
        }      
        -status|status {
          set status $v
        }      
      } 
    }

    if {$find_ctype} {
      set idx [lsearch -nocase [dict keys $headers] content-type]
      if {$idx > 0} {
        set key [lindex [dict keys $headers] $idx]
        set contentType [dict get $headers $key]
      }
    }

    response_write $chan \
                    -body $body \
                    -status $status \
                    -content-type $contentType \
                    -headers $headers
  }

  proc response_write {chan args} {
    	
  	set body {}
  	set status {}
  	set contentType text/plain
  	set headers {}

  	foreach {k v} $args {
  		switch -regexp -- $k {
  			-body|body {
  				set body $v
  			}
  			-status|status {
  				set status $v
  			}
  			-content-type|content-type {
  				set contentType $v
  			}			
  			-headers|headers {
  				set headers $v
  			}			
  		}
  	}

  	set codes [get_codes]


  	if {[dict exists $codes $status]} {
  		set status_text "$status [dict get $codes $status]"
  	} else {
  		set status_text {500 server error}
  	}

  	if {[lsearch -nocase [dict keys $headers] "content-type"] == -1} {
  		dict set headers "Content-Type" $contentType
  	}

    #puts "::> send $status_text"
    #puts "::> send $headers"
    #puts "::> send $body"


  	puts $chan "HTTP/1.0 $status_text"

  	foreach {k v} $headers {
  		puts $chan "$k: $v"    
  	}

  	puts $chan ""
  	puts $chan $body
  }
}
