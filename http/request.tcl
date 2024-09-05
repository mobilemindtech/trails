#!/bin/tclsh

package require TclOO

source $::env(TRAILS_HOME)/misc/props.tcl

namespace import ::trails::misc::props::Props

namespace eval ::trails::http {
	catch {
		oo::class create Request {
			superclass Props
		}
	}

	namespace export Request	

	oo::define Request {

		constructor {args} {
			my variable allowed_props
			
			set allowed_props [list method path raw_body body query params headers content-type roles]

			next 

			foreach {k v} $args {
				switch -regexp -- $k {
					-method|method {
						my prop method $v
					}
					-path|path {
						my prop path $v
					}
					-body|body {
						my prop body $v
					}	
					-raw-body|raw-body {
						my prop body $v
					}	
					-query|query {
						my prop query $v
					}
					-params|params {
						my prop params $v
					}					
					-headers|headers {
						my prop headers $v
					}
					-content-type|content-type {
						my prop content-type $v
					}					
				}
			}
		}
	}
}
