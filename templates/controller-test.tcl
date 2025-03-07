package require tcltest
package require tools

namespace import ::tools::assert::*
namespace import ::tcltest::*

proc setup {} {
    
}

proc cleanup {} {
    
}

test __DOMAIN_NAME__Controller_test {} \
    -setup { setup } \
    -cleanup { cleanup } \
    -body {
	return 1
    } \
    - result 1

cleanupTests
