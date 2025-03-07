
namespace eval ::trails::misc::util {
    proc filter_number {text} {
	regexp -all -inline -- {[0-9]+} $text
    }
}
