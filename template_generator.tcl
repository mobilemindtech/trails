
set ::env(TRAILS_HOME) [expr {[file exists "./.tcl/trails"] == 1 ? "./.tcl/trails" : "./"}]


namespace eval ::trails::template::generator {

    namespace export \
	generate-all \
	generate-domain \
	generate-service \
	generate-controller \
	generate-views
    
    proc generate-all {name} {
	generate-domain $name
	generate-service $name
	generate-controller $name
	generate-views $name
    }

    proc generate-domain {name} {

	set src  $::env(TRAILS_HOME)/templates/domain.tcl
	set src_test $::env(TRAILS_HOME)/templates/domain-test.tcl

	copy $src ./app/domain/$name.tcl $name
	copy $src_test ./tests/domain/$name.test $name
    }

    proc generate-service {name} {

	set src  $::env(TRAILS_HOME)/templates/service.tcl
	set src_test $::env(TRAILS_HOME)/templates/service-test.tcl

	copy $src ./app/services/[get_domain_name $name]Service.tcl $name
	copy $src_test ./tests/services/[get_domain_name $name]Service.test $name
    }

    proc generate-controller {name} {

	set src  $::env(TRAILS_HOME)/templates/controller.tcl
	set src_test $::env(TRAILS_HOME)/templates/controller-test.tcl

	copy $src ./app/controllers/[get_domain_name $name]Controller.tcl $name
	copy $src_test ./tests/controllers/[get_domain_name $name]Controller.test $name
    }

    proc generate-views {name} {

	set index $::env(TRAILS_HOME)/templates/index.html
	set create $::env(TRAILS_HOME)/templates/create.html
	set edit $::env(TRAILS_HOME)/templates/edit.html
	set show $::env(TRAILS_HOME)/templates/show.html
	set form $::env(TRAILS_HOME)/templates/form.html

	set viewspath ./app/views/$name

	if {![file exists $viewspath]} {
	    file mkdir $viewspath
	}

	copy $index $viewspath/index.html $name
	copy $create $viewspath/create.htm $name
	copy $edit $viewspath/edit.html $name
	copy $show $viewspath/show.html $name
	copy $form $viewspath/form.html $name
    }

    proc copy {src dst name} {

	if {[file exists $dst]} {
	    set max 3
	    while 1 {
		puts -nonewline "::> File $dst already exists, what do you want to do? Type replace (r), skip (s) or cancel (c): "
		flush stdout
		set resp [gets stdin]
		switch $resp {
		    r {
			puts "::> File will be overritten"
			file delete $dst
			break
		    }
		    s {
			puts "::> File will be skipped"
			return
		    }
		    c {
			puts "::> Cancelled"
			exit
		    }
		    default {
			puts "::> Invalid input"
			incr {$max -1}
			if {$max < 0} {
			    puts "::> Maximum attempts achieved"
			    exit
			}
		    }
		}
	    }
	}

	set dir [file dirname $dst]

	if {![file exists $dir]} {
	    file mkdir $dir
	}
	
	set fds [open $src r]
	set fdd [open $dst w+]

	set domain_var $name
	set domain_name [get_domain_name $name]


	foreach line [split [read $fds] \n] {
	    set newline [regsub __DOMAIN_NAME__ $line $domain_name]
	    set newline [regsub __DOMAIN_VAR__ $newline $domain_var]
	    puts $fdd $newline
	}

	close $fds
	close $fdd

	puts "::> File $dst was generated successfully!"
	
    }


    proc get_domain_name {name} {
	return [string toupper [string index $name 0]][string range $name 1 end]
    }
}

