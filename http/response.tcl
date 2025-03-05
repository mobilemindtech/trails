#!/bin/tclsh

source $::env(TRAILS_HOME)/misc/props.tcl

namespace import ::trails::misc::props::Props

namespace eval ::trails::http {
	catch {
		oo::class create Response {
			superclass Props
		}
	}	

	namespace export Response

	oo::define Response {

		constructor {args} {
			
			next body \
				headers \
				status \
				content-type \
				file \
				websocket \
				tpl-name \
				tpl-path \
				tpl-text \
				tpl-json \
				ctx
			
			foreach {k v} $args {
				switch $k {
					-status -
					status  {
						my prop status $v
					}
					-body -
					body {
						my prop body $v
					}
					-content-type -
					content-type {
						my prop content-type $v
					}				
					-headers -
					headers {
						my prop headers $v
					}
					-json -
					json {
						my props body $v content-type {application/json} 
					}				
					-text -
					text {
						my props body $v content-type {text/plain} 
					}				
					-html -
					html {
						my props body $v content-type {text/html} 
					}	
					-file -
					file {
						my prop file $v
					}
					-ctx -
					ctx {
						my prop ctx $v
					}
					-tpl-name -
					tpl-name {
						my props tpl-name $v content-type {text/html}
					}
					-tpl-path -
					tpl-path {
						my props tpl-path $v content-type {text/html}
					}
					-tpl-text -
					tpl-text {
						my props tpl-text $v content-type {text/html}
					}		
					-tpl-json -
					tpl-json {
						my props tpl-json $v content-type {application/json}
					}								
					-websocket -
					websocket {
						my prop websocket $v
					}			
				}
			}
		}
	}
}



