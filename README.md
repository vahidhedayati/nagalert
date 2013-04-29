nagalert
========

nagios disable notifications for a host - a service script to be put in /etc/init.d/


/etc/init.d/nagalert 


If you are running on current host just issuing a stop or start will disable or enable scheduled down times so 2nd and 3rd values totally optional
/etc/init.d/nagalert  stop {10M|10H|10D} {hostname}


If how ever you wish to stop an alert for a remote host then you need to give how long for followed by hostname

/etc/init.d/nagalert  stop 1D apache01

This will schedule a down time for 1 day on hostname apache01 so long as it finds it on nagios server 

or to start for current host 

/etc/init.d/nagalert start  or /sbin/service nagalert start

for remote host

/etc/init.d/nagalert start apache01

The start process parses nagios html and tells you if it found the host in scheduled down time.


Also check out https://github.com/vahidhedayati/nagios-disable-host-notifications to get notifications on hosts with disabled active/notification checks or scheduled down time





Just executing the script returns:

        /etc/init.d/nagalert start 
        ----------------------------------
        stop value ie 10S for 10 Seconds
        stop value ie 10M for 10 Minutes
        stop value ie 10H for 10 Hours
        stop value ie 10D for 10 Days
        ----------------------------------

Hmm looks like the usage needs updating lol

