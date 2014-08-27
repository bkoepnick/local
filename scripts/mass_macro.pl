#!/usr/bin/perl -w

#   Brian Koepnick 04/16/2013

#   NAME of Program:  mass_macro.pl 

#   IMPORTANT: Before running macros on the DIGs, must open a virtual display and port to it
# 	>	Xvfb :20
#	> 	export DISPLAY=:20

use warnings;
use strict;
use Getopt::Long;
use File::Basename;

if ($#ARGV < 1){
    print STDERR "\nImproper command\n";
    exit -1;
}

my $EXEC = "~/rosetta/mini-interactive/rosetta_source/cmake/build_release/game_static";
my $ROSETTA_DATABASE = "/work/koepnick/rosetta/mini-interactive/rosetta_database/";
my $ROSETTA_RESOURCES = "/work/koepnick/rosetta/mini-interactive/resources/";
my $BOINC_URL = "https://fold.it/";

my $macro_file = $ARGV[0];
my $pdb_list_file = $ARGV[1];

my $np = 1;
my $m_rep = 1;
my $m_iter = 1;
&GetOptions( "np=i" => \$np,
	"m_rep=i" 	=> \$m_rep,
	"m_iter=i"	=> \$m_iter );


my $p = 1;
my $pid;
my $pdb;
my %proc;

open( my $FILE, $pdb_list_file ) or die "Could not open file: $!\n";
my @pdb_list = <$FILE>; 
close( $FILE );
chomp(@pdb_list);


for($p = 1; $p <= $np; $p++){
	if(@pdb_list){
		 $pdb = shift(@pdb_list);
	}
	fork_macro( $p, $pdb );
}

do{
	$pid = wait();
	#print "Child process ", $proc{ $pid }, " returned\n";
	if(@pdb_list) {
		$pdb = shift(@pdb_list);
		fork_macro( $proc{ $pid } );
	}
} while($pid>0);

sub fork_macro{
	$pid = fork();
	die "fork() failed $!" unless defined $pid;
	if($pid == 0){
		#print "Child process ", $_[0], "\n";
		my @args = ("$EXEC",
			"-database $ROSETTA_DATABASE",
			"-resources $ROSETTA_RESOURCES",
			"-headless",
			"-boinc_url $BOINC_URL",
			"-interactive_game run_macro",
			"-inputs $macro_file $m_rep $m_iter",
			"-in:file:s $pdb");
		system("@args");
		if($?!=0){
			print "Command failed on $pdb";
		}
		exit();
	}
	$proc{ $pid } = $_[0];
}
