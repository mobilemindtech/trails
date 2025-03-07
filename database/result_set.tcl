

namespace eval ::trails::database  {
    catch {
	oo::class create ResultSet {
	    variable err state dbhandle data autocommit
	}
    }
  
    namespace export ResultSet

    oo::define ResultSet {

	constructor {} {
	    my variable err state dbhandle data autocommit
	    set err {}
	    set state success
	    set dbhandle {}
	    set data {}
	    set autocommit true
	    set id {}
	}

	method set_id {val} {
	    my variable id
	    set id $val
	}

	method get_id {} {
	    my variable id
	    return $id
	}

	method set_autocommit {val} {
	    my variable autocommit
	    set autocommit $val
	}

	method set_error {err_info} {
	    my variable err 
	    my variable state
	    set state error
	    set err $err_info
	}

	method set_data {d} {
	    my variable data
	    set data $d
	}

	method set_dbhandle {hdlr} {
	    my variable dbhandle
	    set dbhandle $hdlr
	}

	method has_error {} {
	    my variable state 
	    return [expr {$state == "error"}]
	}

	method is_ok {} {
	    my variable state 
	    return [expr {$state == "success"}]
	}

	method get_data {} {
	    my variable data
	    return $data
	}

	method get_error_info {} {
	    my variable err
	    return $err
	}

	method get_dbhandle {} {
	    my variable dbhandle
	    return $dbhandle
	}

	method is_autocommit {} {
	    my variable autocommit
	    return $autocommit
	}
    }  
}
