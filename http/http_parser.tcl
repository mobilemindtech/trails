
package require logger
package require coroutine

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/http/util.tcl

namespace eval ::trails::http::http_parser {
	variable log
	set log [logger::init http_parser]


	proc parse_request {socket} {
	    # Default request data, they are overwritten if explicitly specified in 
	    # the HTTP request
	    set requestMethod ""
	    set requestURI ""
	    set requestProtocol ""
	    set requestHeader [dict create connection "close" accept "text/plain" accept-encoding "" content-type "text/plain"]
	    set requestBody {}
	    set requestQuery {}
	    #set RequestAcceptGZip 0; # Indicates that the request accepts a gzipped response
	    set state connecting

	    # while {[gets $socket line]>=0}

	    while {1} {

	      set readCount [::coroutine::util::gets_safety $socket 4096 line]

	      # Decode the HTTP request line
	      if {$state == "connecting"} {
	        if {![regexp {^(\w+)\s+(/.*)\s+(HTTP/[\d\.]+)} $line {} requestMethod requestURI requestProtocol]} {
	          break }

	        #set path "/[string trim [lindex $line 1] /]"
	        set requestQuery [::trails::http::router::get_uri_query $requestURI]
	        
	        # remove query from URI
	        set parts [split $requestURI ?]
	        set requestURI [lindex $parts 0]

	        set state header

	      # Read the header/RequestData lines
	      } elseif {$state == "header"} {
	        if {$line != ""} {
	          if {[regexp {^\s*([^: ]+)\s*:\s*(.*)\s*$} $line {} AttrName AttrValue]} {
	            dict set requestHeader [string tolower $AttrName] $AttrValue
	          } else {
	            # RequestData not recognized, ignore it
	            ${log}::error {unable to interpret RequestData: $line}
	          }
	        } else {
	          set state body
	          # Header is completed, read now the body
	          break
	        }
	      }
	    }

	    if {$state == "connecting"} {
	      return -code error {no data received -> close socket}
	    }  

	    if {$state == "body"} {

	      #fconfigure $socket -translation {binary crlf}

	      
	      # Read the body in binary mode to match the content length and avoid
	      # any unwanted translation of binary data
	      fconfigure $socket -translation {binary crlf}

	      set transferEncoding ""
	      if {[dict exists $requestHeader transfer-encoding]} {
	        set transferEncoding [dict get $requestHeader transfer-encoding]
	      }

	      # RFC7230 - 3.3.3. Message Body Length
	      # If a Transfer-Encoding header field is present and the chunked
	      # transfer coding (Section 4.1) is the final encoding, the message
	      # body length is determined by reading and decoding the chunked
	      # data until the transfer coding indicates the data is complete.
	      if {[string match {*chunked} $transferEncoding]} {
	        while {![eof $socket]} {
	          set chunkHeader ""
	          while {$chunkHeader==""} {
	            gets $socket chunkHeader
	          }

	          # The chunk header can include "chunk extensions" after a semicolon
	          set chunkSizeHex [lindex [split $chunkHeader {;}] 0]
	          set chunkSize [expr 0x$chunkSizeHex]
	          if {$chunkSize==0} {
	            break}

	          set currentChunk {}
	          while {![eof $socket]} {
	            if {[string bytelength $currentChunk]>=$chunkSize} {
	              break}
	            append currentChunk [read $socket $chunkSize]
	          }

	          append requestBody $currentChunk
	        }

	        #dict set Response ErrorStatus 501
	        #dict set Response ErrorBody {Chunked transfer encoding not supported}
	        #Log {Chunked transfer encoding not supported} info 2
	      } elseif {[dict exists $requestHeader content-length]} {
	        # Read the number of bytes defined by the content-length header
	        set contentLength [dict get $requestHeader content-length]
	        while {![eof $socket]} {
	          if {[string bytelength $requestBody]>=$contentLength} {
	            break}
	          append requestBody [read $socket $contentLength]
	        }
	      
	      } else {
	        # No "content-length" and not "transfer-encoding" doesn't end
	        # in "chunked". So there should be no body.
	      }

	      # Switch back to the standard translation mode
	      fconfigure $socket -translation {auto crlf}

	      #if {$requestBody!=""} {
	      #  ${log}::debug {Received body length: [string bytelength $requestBody]}
	      #  ${log}::debug "requestBody = $requestBody"
	      #}
	       
	    }

	    set contentType [dict get $requestHeader "content-type"]

	    #puts "requestBody = $requestBody"
	    #puts "method=$requestMethod"
	    if {[lsearch [list "GET" "OPTIONS" "HEAD"] $requestMethod] == -1} {
	      set body [::trails::http::util::body_parse $requestBody $contentType]
	    } else {
	      set body {}
	    }

	    if {$body == "not_supported"} {	      	    
	      return -code error {content-type not supported}
	    }

	    #set requestURITail [string range $requestURI [lindex $ResponderDef 2] end]
	    Request new \
	  			-method $requestMethod \
	  			-path $requestURI \
	  			-headers $requestHeader \
	  			-body $body \
	  			-row-body $requestBody\
	  			-query $requestQuery\
	  			-content-type $contentType
	}

}