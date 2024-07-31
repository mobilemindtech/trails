#!/bin/tclsh

set trailsdir [expr {[file exists "./trails"] == 1 ? "./trails" : "./"}]

source $trailsdir/misc/props.tcl

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
			my variable allowed_props

			set allowed_props [list body headers status content-type file websocket]
			
			next

			foreach {k v} $args {
				switch -regexp -- $k {
					-status|status  {
						my prop status $v
					}
					-body|body {
						my prop body $v
					}
					-content-type|content-type {
						my prop content-type $v
					}				
					-headers|headers {
						my prop headers $v
					}
					-json|json {
						my props body $v content-type {application/json} 
					}				
					-text|text {
						my props body $v content-type {text/plain} 
					}				
					-html|html {
						my props body $v content-type {text/html} 
					}	
					-file|file {
						my prop file $v
					}
					-websocket|websocket {
						my prop websocket $v
					}			
				}
			}
		}
	}
}



