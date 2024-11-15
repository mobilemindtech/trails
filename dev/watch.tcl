###############################################################################
 # Modul    : watch.tcl                                                        #
 # Changed  : 28.02.2008                                                       #
 # Purpose  : observing directories or files for changes, triggering callback. #
 # Author   : M.Hoffmann                                                       #
 # Remarks  : callback(scripts) are evaluated in the scope of the caller.      #
 # Todo     : stop watching if command/callback returns error/break.           #
 # History  :                                                                  #
 # 28.02.08 : v1.0  1st version made out of several of my progs.               #
 ###############################################################################

 namespace eval watch {
      variable nextHandle 0
      variable activeIDs
      array set activeIDs {}
 }

 proc watch::FSChange {obj intv script {lastMTime ""} {handle 0}} {
      variable nextHandle
      variable activeIDs      
      # Att: obj, intv and script are not fully checked by us yet
      catch {file mtime $obj} nowMTime
      if [string eq $lastMTime ""] {
         # new call, no recursion
         incr nextHandle; # caution: no reuse yet, simply increment each time
         set handle $nextHandle
         set lastMTime $nowMTime
      } elseif {$nowMTime != $lastMTime} {
         if {[uplevel info procs [lindex $script 0]] != ""} {
            catch {uplevel $script $obj};# append objectname to callback proc
         } else {
            catch {uplevel [string map [list %O $obj] $script]}
         }
         set lastMTime $nowMTime
      }
      set activeIDs($handle) \
       [after $intv [list watch::FSChange $obj $intv $script $lastMTime $handle]]
      return $handle
 }

 proc watch::Cancel {handle} {
      variable activeIDs
      set script ""
      catch {
         set script [lrange [join [after info $activeIDs($handle)]] 1 end-3]
         after cancel $activeIDs($handle)
         unset activeIDs($handle)
      }
      return $script
 }

 #==============================================================================