#!/bin/bash

##############################################################################
# Bash script written by Vahid Hedayati April 2013
# Nagalert can be run as a service on your device so it auto 

# schedules nagios downtime and also cancels schedule if start is run
# This can work in conjunction of
# https://github.com/vahidhedayati/nagios-disable-host-notifications
# Which emails out any notifications - scheduled down time in 
# html email clickable format


# This is an updated version of nagalert - will work with multiple nagios server
# installations - 
# checks to see if host is marked down or up depending on action 
# if not found it will attempt the check on other nagios servers within array 

###############################################################################
# DOWNLOAD THIS SCRIPT AND PLACE IN: /etc/init.d/
# chmod +x /etc/init.d/nagalert
# sudo /sbin/chkconfig nagalert on
# and before you enjoy !
# DON'T FORGET TO CONFIGURE NAGIOS SERVER DETAILS BELOW DISCLAIMER HAHA
##############################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
##############################################################################

PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

## Ensure you provide your nagios server name username and admin password 
# and ensure url matches your nagios cgi-bin path
nagios_url="/nagios/cgi-bin";
username="nagiosadmin"
password="PASSWORD"
naghost="nagios_server1.yourdomain.com"
base_url="http://"$username:$password"@"$naghost$nagios_url

#####################################
# Amount of arrays rows below
X=2;

# Environments or Data Centres
s[1]="datacentre1";
s[2]="datacentre2";

# URLS
u[1]="nagios_server1.yourdomain.com"
u[2]="nagios_server2.yourdomain.com"

# Nagios authentication details
up[1]="nagiosadmin:PASSWORD"
up[2]="nagiosadmin:PASSWORD"

######################################

#Define start variable as 0
# Set to 1 when we need to start
# for reusing parseHTML function
START=0;
FOUND=0;



# Now this is how long you want your default if not defined time value to be
# 10 M = 10 Minutes You can set a numeric value followed by M Minutes, H Hours or D  Days 
DEFAULT_TIME="10M"

# These two are the input values but depending on call 
# if stop it can be 2 values after stop - so stop 10M {hostname} -
# start is always one extra value start {hostname} 
# {hostname always optional - non given it gets set to current host executing nagalert
val2=$2;
val3=$3;

# Tmp file created with random id just incase other are executing nagalert
# at the same time - the file is used only when starting service which disables enabled notifications
# The tmp file stores the wget content of downtime link on the web interface called by parseHTML
RAND="$$";
tmpfile="/tmp/nagios-status.html.$RAND"


#######################################################################################
#  MAIN CODE
#######################################################################################
# Set date changes user input of 10M to 10 minutes and returns it in format understood
# by nagios html web front end used by init_stop
function set_date() { 
  if [[ $input_time =~ D ]]; then
        	input_time=$(echo $input_time|sed -e 's/D/ days/g')
	elif [[ $input_time =~ M ]]; then
        	input_time=$(echo $input_time|sed -e 's/M/ minutes/g')
	elif [[ $input_time =~ H ]]; then
        	input_time=$(echo $input_time|sed -e 's/H/ hours/g')
	elif [[ $input_time =~ S ]]; then
        	input_time=$(echo $input_time|sed -e 's/S/ SECONDS/g')
	fi
	amp="%%3A"
	now=$(date +%m-%d-%Y"+"%H$amp%M$amp%S)
	end=$(date +%m-%d-%Y"+"%H$amp%M$amp%S  -d "$input_time")
}


# This initialises the stop function by setting hostname and input time values
# calls above to generate nagios format start end dates
function init_stop() { 
	input_time=$val2;
	if [ "$input_time" == "" ]; then
		input_time=$DEFAULT_TIME
	fi
	set_date
	HOST_NAME=$val3;
	# If no hostname set in either start/stop make it this host
	if [ "$HOST_NAME" == "" ]; then
		HOST_NAME=(`hostname -s`)
	fi
}

# This initialises start variables
function init_start() { 
	HOST_NAME=$val2;
	# If no hostname set in either start/stop make it this host
	if [ "$HOST_NAME" == "" ]; then
		HOST_NAME=(`hostname -s`)
	fi
}

# This works out who is logged in - if not found it will use root
# also try capture their real name if defined properly in passwd entry
function script_user() { 
      echo $(logname)  | grep "[a-z]" > /dev/null
      if [ $? = 0 ]; then
          loginname=$(logname);
      else
	  loginname="root";
      fi
      person=$(getent  passwd $loginname|awk -F":" '{print $5}')
      userlogin=$loginname;
}

# This is the main core function of start service
# it simply parses for hostname in downtime link of nagios web interface
# It then generates relevant links and wgets them to enable alerts
function parseHTML() {
        if [ "$HOST_NAME" == "" ]; then
                echo "Hostname: -->$HOST_NAME<-- is blank";
                exit 2;
        fi
        IFS=$'\n'
        go=0;
        return_string="";
        start="<TABLE BORDER=0 CLASS='downtime'>";
        fin="</TABLE>";
        surl="$base_url/cmd.cgi?cmd_typ=79&cmd_mod=2&down_id="
        hurl="$base_url/cmd.cgi?cmd_typ=78&cmd_mod=2&down_id="
        wget -q "$base_url/extinfo.cgi?type=6" -O $tmpfile
        for lines in $(cat $tmpfile); do
                if [[ $lines =~ "$start" ]]; then go=1; fi
                if [[ $lines =~ "$fin" ]]; then go=0; fi
                if [[ $go == 1 ]]; then
                        if [[ $lines =~ "$HOST_NAME</A>" ]]; then
                                return_string="Enabling Nagios Alerts for $HOST_NAME";
                                if [[ $lines =~ "downtimeOdd" ]]; then
                                        if [[ $lines =~ "service" ]]; then
                                                servicedownid=$(echo $lines|awk -F"downtimeOdd" '{print $12}'|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
                                                url="$surl$servicedownid"
                                                ((FOUND++));
                                                if [[ $START == 1 ]]; then
                                                        echo "Enabling SERVICEID:$servicedownid Alert $url";
                                                        wget -O - -q -t 1 "$url" >/dev/null 2>&1
                                                fi
                                        else
                                                hostdownid=$(echo $lines|awk -F"downtimeOdd" '{print $11}'|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
                                                url="$hurl$hostdownid"
                                                ((FOUND++));
                                                if [[ $START == 1 ]]; then
                                                        echo "Enabling HOSTDOWNID:$hostdownid Alert $url";
                                                        wget -O - -q -t 1 "$url" >/dev/null 2>&1
                                                fi
                                        fi
                                fi
                                if [[ $lines =~ "downtimeEven" ]]; then
                                        if [[ $lines =~ "service" ]]; then
                                                servicedownid=$(echo $lines|awk -F"downtimeEven" '{print $12}'|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
                                                url="$surl$servicedownid"
                                                ((FOUND++));
                                                if [[ $START == 1 ]]; then
                                                        echo "Enabling SERVICEID:$servicedownid Alert $url";
                                                        wget -O - -q -t 1 "$url" >/dev/null 2>&1
                                                fi
                                        else
                                                hostdownid=$(echo $lines|awk -F"downtimeEven" '{print $11}'|awk -F">" '{print $2}'|awk -F"<" '{print $1}')
                                                url="$hurl$hostdownid"
                                                ((FOUND++))
                                                if [[ $START == 1 ]]; then
                                                        echo "Enabling HOSTDOWNID:$hostdownid Alert $url";
                                                        wget -O - -q -t 1 "$url" >/dev/null 2>&1
                                                fi
                                        fi
                                fi
                        else
                                if [[ $FOUND -le 0 ]]; then
                                        return_string="No pattern matching $HOST_NAME was found on $current_naghost"
                                fi
                        fi
                fi
        done
        if [[ $START == 1 ]]; then
                echo $return_string
        fi
        rm $tmpfile
}



# This is used by the stop function 
# It calls the nagios web front end ur's and sets up comments to disable alerts
function stop_nagging() { 
	script_user
        message="$userlogin aka $person Disabled Nagios SERVICE Alerts for $HOST_NAME for $input_time";
        echo "$message -- $current_naghost";
	url="$base_url/cmd.cgi?cmd_typ=86&cmd_mod=2&host=$HOST_NAME&com_data=$message&trigger=0&start_time=$now&end_time=$end&fixed=1&hours=0&minutes=0&btnSubmit=Commit"
	wget -O - -q -t 1 "$url" >/dev/null 2>&1
	message="$userlogin aka $person Disabled Nagios HOST Alert for $HOST_NAME for $input_time";
        echo "$message -- $current_naghost"
	url1="$base_url/cmd.cgi?cmd_typ=55&cmd_mod=2&host=$HOST_NAME&com_data=$message&trigger=0&start_time=$now&end_time=$end&fixed=1&hours=0&minutes=0&childoptions=0&btnSubmit=Commit"
	wget -O - -q -t 1 "$url1" >/dev/null 2>&1	
}


function check_others()  {
        for ((i=1; i <= $X; i++)); do
                # For each array item expand members - these should map to each id above
                datacentre=${s[$i]};
                nagios_host=${u[$i]}
                userpass=${up[$i]}
                # Check to see if the current nagios host matches this host
                # if it does no point in script checking itself and trying to take over its own config
                if [[ $nagios_host =~ $naghost ]]; then
                        echo "$nagios_host matches $naghost ignoring $datacentre"
                else
			echo "Trying $HOST_NAME under $nagiost_host -- $datacentre"
                        base_url="http://"$userpass"@"$nagios_host$nagios_url
                        current_naghost=$nagios_host;
                        if [[ $START -ge 1 ]]; then
                                parseHTML;
                        else
                                stop_nagging
                                echo "Sleeping for 10 seconds & checking if host is been marked down under $current_naghost";
                                sleep 10;
                                 parseHTML;
                                if [[ $FOUND -ge 1 ]]; then
                                        echo "Success $HOST_NAME found with $FOUND entries under downtime in $current_naghost -- $datacentre";
                                        exit 0;
                                else
                                        echo "Could not find $HOST_NAME under $current_naghost -- $datacentre "
                                fi
                        fi
                fi
        done
}

# Help option to return help
function usage() { 
 	echo "$0  stop {10M|10H|10D) {hostname}"
 	echo "$0 start {hostname}"
 	echo "----------------------------------"
 	echo "stop value ie 10S for 10 Seconds" 
 	echo "stop value ie 10M for 10 Minutes"
 	echo "stop value ie 10H for 10 Hours" 
 	echo "stop value ie 10D for 10 Days" 
	echo "stop time {hostname} - this will stop the given hostname for the given time"
	echo "start  {hostname} - this will start alerts for the given hostname"
 	echo "----------------------------------"
		
}



# Main program case function
case "$1" in
  start)
                init_start;
                current_naghost=$naghost;
                START=1;
                parseHTML;
                if [[ $FOUND -ge 1 ]]; then
                        echo "Success $HOST_NAME found with $FOUND entries under downtime in $current_naghost";
                else
                        echo "Could not find $HOST_NAME on $current_naghost - will attempt other nagios hosts";
                        check_others;
                fi
                ;;
  stop)
                current_naghost=$naghost;
                init_stop;
                stop_nagging
                echo "Sleeping for 10 seconds & checking if host is been marked down";
                sleep 10;
                parseHTML;
                if [[ $FOUND -ge 1 ]]; then
                        echo "Success $HOST_NAME found with $FOUND entries under downtime in $current_naghost";
                else
                        echo "Failed did not find $HOST_NAME on $current_naghost - will need to attempt other nagios hosts"
                        check_others;
                fi
                 ;;
  *)
        usage
        exit 1
esac

exit 0
