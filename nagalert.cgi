#!/usr/bin/perl
##############################################################################
# Perl script written by Vahid Hedayati May 2013
# nagalert.cgi - uses backend nagalert (service script - other script part of this project)
# Provides a web interface to stop/start alerts for selected host
# Script must be made available in the cgi-bin folder of the host running nagios 
# Ensure you configure the first two variables to match your current setup
# status.dat and nagalert (bash script)
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


use CGI;


my $q = CGI->new;

my $config_file="/var/nagios/status.dat"; 
my $nagios_service="/etc/init.d/nagalert";

print "Content-type: text/html\n\n";
print "<html><head><title>Nagios Host Alert Controller</title><body>";

my $action=$q->param('action');
my $timevalue=$q->param('timevalue');
my $timeperiod=$q->param('timeperiod');
my @hostnames = $q->param('hostname');
  
sub uniq {
    return keys %{{ map { $_ => 1 } @_ }};
}

sub gen_action() { 
	print "<select name=action size=1>\n";
	print "<option value=stop>DISABLE Services/Host Alerts for -&gt;</option>\n";
	print "<option value=start>ENABLE Services/Host Alerts for -&lt;</option>\n";
	print "</select>\n";
}
sub gen_time() { 
	print "<table>";
	print "<tr><td>";
	print "<select name=timevalue size=1>\n";
	for ($i=1; $i < 25; $i++) { 
		print "<option value=\"$i\">$i</option>\n";
	}
	print "</select>\n";
	print "</td><td>";
	print "<select name=timeperiod size=1>\n";
	print "<option value=M>Minutes</option>\n";
	print "<option value=H>Hours</option>\n";
	print "<option value=D selected>Days</option>\n";
	print "</select>\n";
	print "</td></tr>";
	print "</table>";
}
sub gather_servers() { 
	open(FILE1, $config_file);
	print "<select name=hostname multiple size=30>\n";
	#print "<select name=hostname size=10>\n";
	while (<FILE1>) {
    		$line=$_;
    		$host=$2 if /(.*)host_name=(.*)/;
		if ( $hosts !~  "" )  {
    			push @hosts,"<option value=\"$host\">$host</option>\n";
		}
	}
	print join(" ", uniq(@hosts)), "\n";
	print "</select>\n";
}
sub gen_page() { 
	print "--> Please note time definition not used by start action<br>";
	print "<form method=post>\n";
	print "<table><tr><td valign=top>";
	&gen_action;
	print "</td><td valign=top>";
	&gather_servers;
	print "</td><td valign=top>";
	&gen_time;
	print "</td><td valign=top>";
	print "<input type=submit value=\"Do it\">";
	print "</td></tr></table>";
	print "</form>";
}

if ($action eq 'start') {
	foreach $hostname (@hostnames) {
  		print "Enabling alerts for $hostname";
		print "<pre>";
  		system("$nagios_service start $hostname");
		print "</pre>";

	}
}elsif ($action eq 'stop') { 
	my $stoptime="";
	if  ( ($timeperiod ne '' ) && ($timevalue ne '' ) )  {
		$stoptime="$timevalue$timeperiod";
	} else { 
		$stoptime="10M";
	}
 	foreach $hostname (@hostnames) {
  		print "Disabling alerts for $hostname for $stoptime";
		print "<pre>";
  		system("$nagios_service stop $stoptime $hostname");
		print "</pre>";
	}

	
}else{
	&gen_page;
}
