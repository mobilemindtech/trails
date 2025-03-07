package require TclOO

namespace import ::trails::models::ActiveRecord 

namespace eval ::domain {

    oo::class create __DOMAIN_NAME__ {
	ActiveRecord {
	    table_name __TABLE_NAME__
	    fields {
		# id {{id int key} {json id string}}
		# name {{name string} {json name string}}
	    }
	}
    }
}

