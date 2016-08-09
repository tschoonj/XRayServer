#!/usr/bin/perl -W
#--------------------------------------------------------------
# This example PERL script:
# - calls the TER_SL program from http://x-server.gmca.aps.anl.gov/
# - tracks calculation.
# - gets and saves the data.
# The example is equivalent to the following page:
# http://x-server.gmca.aps.anl.gov/cgi/WWW_form.exe?template=TER_sl_multilay_sw.htm&method=post
#
# PERL interpreter is available by default on UNIX and MAC OS. Freeware
# PERL distribution for Windows can be installed either as a part of Cygwin
# (http://www.cygwin.com), or as a standalone package available from
# ActiveState (http://www.activestate.com/).
#
# To access data from remote web site, this script makes use of PERL LWP
# module (WWW library for Perl). The latter is usually a part of standard
# PERL distribution; otherwise it can be freely downloaded from CPAN
# (http://www.cpan.org/).
#
# This example script can be freely distributed and modified without any
# restrictions.
#
#     		Author: Sergey Stepanov
#
# Version-1.0:  2015/10/30
#--------------------------------------------------------------
  use strict;
  use LWP::Simple;			# World-Wide Web library for Perl (libwww-perl)
  use LWP::UserAgent;

  select STDOUT; $|=1;			# set unbuffered output

  my ($url, $prg, $query, $unzip, %FORM);
  my ($request, $name, $buffer, $jobID);
  my ($error_text, $status, $ua, $response);
  my ($progress, $start_time, $end_time, $data_found);

  $start_time = time();

### General parameters:
  $url   = 'http://x-server.gmca.aps.anl.gov';
  $prg   = $url.'/cgi/TER_form.pl';
  $query = $url.'/cgi/WWWwatch.exe?';
  $unzip = $url.'/cgi/WWWunzip.exe?';

  $FORM{'comment1'} = 'Template: script getTER_sw_query_post';

### X-rays:
  $FORM{'xway'}     = 1;		# 1=wavelength, 2=energy, 3=line type
  $FORM{'wave'}     = 1.540562;		# works with xway=1 or xway=2
# $FORM{'line'}     = 'Cu-Ka1';		# works with xway=3 only
  $FORM{'line'}     = '';		# works with xway=3 only
  $FORM{'ipol'}     = 1;		# 1=sigma-polarization, 2=pi-polarization

### Substrate:
  $FORM{'subway'}   = 1;		# 1=database_code, 2=chemical_formula, 3=x0_value
  $FORM{'code'}     = 'GaAs';		# crystal code
  $FORM{'chem'}     = '';		# Chemical formula: works with subway=2 only
  $FORM{'rho'}      = '';		# Density (g/cm3): required for chemical formula
  $FORM{'x0'}       = '(0.,0.)';	# Direct input of chi_0: x0=2*delta (subway=3)
  $FORM{'w0'}       = 1.;		# Debye-Waller type correction for x0

### Substrate surface:
### (only one of the two parameters can be non-zero):
  $FORM{'sigma'}    = 4.;		# rms roughness at surface (Angstrom)
  $FORM{'tr'}       = 0.;		# transition layer thickness (Angstrom)

### Database Options for dispersion corrections df1, df2:
### -1 - Automatically choose DB for f',f"
###  0 - Use X0h data (5-25 keV or 0.5-2.5 A) -- recommended for Bragg diffraction.
###  2 - Use Henke data (0.01-30 keV or 0.4-1200 A) -- recommended for soft x-rays.
###  4 - Use Brennan-Cowan data (0.03-700 keV or 0.02-400 A)
  $FORM{'df1df2'}   = -1;

### Scan range:
  $FORM{'scanmin'}  = 0.;		# minimum scan angle (range)
  $FORM{'scanmax'}  = 3.;		# maximum scan angle (range)
  $FORM{'unis'}     = 0;		# scan angle units: 0=degr.,1=min,2=mrad,3=sec,4=urad
  $FORM{'nscan'}    = 601;		# number of scan points

### Standing waves request:
  $FORM{'swflag'}   = 1;		# 0=do not print standing waves; 1=print
  $FORM{'swref'}    = 0;		# reference interface (only needed if swflag=1)
  $FORM{'swmin'}    = 0.0;		# start offset        (only needed if swflag=1)
  $FORM{'swmax'}    = 1000.0;		# end offset          (only needed if swflag=1)
  $FORM{'swpts'}    = 101;		# number of offsets   (only needed if swflag=1)

  $FORM{'watch'}    = 1;		# job watching option

### Surface layer profile
### (can also be read from
## a filename specified in
### the command line):
  $FORM{'profile'} = '
t=20 w0=0.5 sigma=5   ;surface oxide, organic contamination or dust
period=20
t=100 code=GaAs sigma=4
t=70 code=AlAs sigma=4
end period
';

#-----------------------------------------------------------
### Request data from the server:
  print STDOUT 'Request string:'."\n".$prg."\n";

  $ua = LWP::UserAgent->new;
# $ua = LWP::UserAgent->new(keep_alive=>1);
### Get/set the timeout value in seconds. The default timeout()
### value is 180 seconds, i.e. 3 minutes.
# $ua->timeout(650);

### Request data from the server:
  $response = $ua->post($prg,\%FORM);
  if (! $response->is_success) {
     print STDOUT "\n".'*** getTER: Error reading response from the server: %s'."\n", $response->status_line;
     $end_time = time();
     printf STDOUT 'Elapsed time=%ds'."\n", int($end_time-$start_time);
#    die $response->status_line;
     exit 1;
  }

  $buffer = $response->content;
  $buffer =~ s/[\015\012]//g;			# remove CR/LF

### Find job ID on the server:
  $jobID = $buffer;
  if ($buffer =~ /Download ZIPped results:/i) {
### Remove all text before and after job name in the string like:
### Download ZIPped results: <A HREF="x-ray/TERxxxxx.zip">TERxxxxx.zip</A>
     $jobID =~ s/^.*Download ZIPped results: <A HREF=\"x-ray\///i;
     $jobID =~ s/\.zip.*$//i;
  }
  elsif ($buffer =~ /Job ID:/i) {
### Job is in progress:
### Remove all text before and after job name in the string like:
### Job ID: <b>TER70410</b>
     $jobID =~ s/^.*Job ID: <b>//i;
     $jobID =~ s/<\/b>.*$//i;
     print STDOUT 'Job ID = '.$jobID."\n";
     $request = $query.'jobname='.$jobID;    # utility to track job progress
### Track and print the progress until the results page is received:
     do {
        $response = $ua->get($request);
        if (! $response->is_success) {
           printf STDOUT "\n".'*** getTER: Error reading response from the server: %s'."\n",$response->status_line;
           exit 1;
        }
        $buffer = $response->content;
        $buffer =~ s/[\015\012]//g;		# remove CR/LF
	if ($buffer =~ /Points done =/i) {
	   $progress = $buffer;
	   $progress =~ s/^.*Points done/Points done/i;
	   $progress =~ s/<br>.*$//i;
	   print STDOUT $progress."\n";
	}
	if ($buffer !~ /Download ZIPped results:/i) {sleep(5);}
     } while ($buffer !~ /Download ZIPped results:/i);
  }
  else {
     die 'Unexpected completion, no job ID found';
  }

  $data_found = 0;
  $error_text = 'images/stop1.gif';
  $status = 0;

### Analyze server response and download the data:
  if ($buffer =~ /${error_text}/i) {
### Erroneous completion:
     print STDOUT 'Request was unsuccessful, job ID='.$jobID."\n";
     $buffer =~ s/^.*${error_text}//i;		# remove all before error message
     $buffer =~ s/^.*<font size=\+1>//i;	# remove all before error message
     $buffer =~ s/<\/font>.*$//i;		# remove all after  error message
     $buffer =~ s/<br>/\n/ig;			# replace HTML tags
     $buffer =~ s/\&nbsp;/ /ig;			# replace HTML tags
     print STDOUT 'Saving log: '.$jobID.'.tbl'."\n";
     &getstore($unzip.'jobname='.$jobID.'&filext=tbl',$jobID.'.tbl');
     print STDOUT "\n".'ERROR message:'."\n".$buffer."\n";
     $status = 1;
  }
  else {
### Normal completion:
     print STDOUT 'Request was successful, job ID='.$jobID."\n";
     if ($buffer =~ /Display DAT file/i) {
        $status = &getcheckstore($unzip,$jobID,'dat');
	if (! $status) {$data_found++;}
     }
     if ($buffer =~ /Display SW-DAT file/i) {
         $status = &getcheckstore($unzip,$jobID.'_sw','dat');
	 if (! $status) {$data_found++;}
     }
     if ($buffer =~ /Display SW-GRD file/i) {
         $status = &getcheckstore($unzip,$jobID.'_sw','grd');
	 if (! $status) {$data_found++;}
     }
     if ($data_found == 0) {$status = 1;}	# no data
  }

  print STDOUT 'Saving packed results: '.$jobID.'.zip'."\n";
  &getstore($url.'/x-ray/'.$jobID.'.zip',$jobID.'.zip');
  print STDOUT 'Done!'."\n";
  exit $status;

############################################################################

#sub getcheckstore ($$$);
sub  getcheckstore {
  my $unzip   = shift(@_);
  my $prefix  = shift(@_);
  my $ext     = shift(@_);
  my $file = $prefix.'.'.$ext;
  print STDOUT 'Saving data: '.$file."\n";
  my $data = get($unzip.'jobname='.$prefix.'&filext='.$ext);
  $data =~ s/\015//g;			# Perl for Windows workaround
  if ($data =~ /stop/i) {		# stop1.gif is returned when no data
     print STDOUT '!!! No data on server!'."\n";
     return 1;
  } else {
     open (DAT,'> '.$file) or die 'Cannot open '.$file;
     print DAT ${data};
     close(DAT);
     return 0;
  }
}

############################################################################
