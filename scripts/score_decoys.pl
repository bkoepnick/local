#!/usr/bin/perl -w

#    Brian Koepnick 05/31/2013

#    NAME of Program:  score_decoys.pl 

#    this script takes in a super-directory of files to score and
#    the native files to calc RMSD against

#    the subdirectories of the super-directory must be named in accordance
#    with the PDB id of the native files

#	 after this script, run combine_sc.sh and eval_scores.py 

use warnings;
use strict;
use File::Basename;
use Getopt::Long;

my $usage = "usage: score_decoys.pl
    -native_dir <native directory> | -native_list <native list>
    -decoy_dir <decoy directory>";

my %opts = ();
&GetOptions (\%opts,"native_dir=s","native_list=s","decoy_dir=s");

if(!defined($opts{decoy_dir}) || 
	(!defined($opts{native_dir}) && !defined($opts{native_list}))){
    die "$usage\n";
}

my $SCORER = "/work/koepnick/rosetta/source/bin/score.default.linuxgccrelease";
my $ROSETTA_DATABASE = "/work/koepnick/rosetta/database/";

my $decoy_dir = $opts{decoy_dir};
my @native_list;

if(defined($opts{native_dir})){
	my $native_dir = $opts{native_dir};

	my $native_content = `find $native_dir -name "*pdb"`;
	@native_list = split (/\n/, $native_content);
}
elsif(defined($opts{native_list})){
	open( my $native_file, $opts{native_list} );
	@native_list = <$native_file>;
	close $native_file;
}

chomp(@native_list);

foreach my $native (@native_list){
	
	my @suffix_list = (".pdb");
	my ($pdb_id, $dir, $suffix) = fileparse($native, @suffix_list);
	
	open(my $decoy_file, '>', 'decoy.list') or die "Could not open file: $!\n";

	my $decoy_list = `find $decoy_dir/$pdb_id -name "*.pdb"`;
	print $decoy_file $decoy_list;
	close $decoy_file;

	my @args = ("$SCORER",
		"-database $ROSETTA_DATABASE",
		"-score:weights score13_env_hb",
		"-in:file:l decoy.list",
		"-in:file:native", $dir.$pdb_id.$suffix,
		"-out:file:scorefile $pdb_id.sc",
		"-ignore_unrecognized_res");

	#print "Command: @args\n";
	system("@args");
	if ($?!=0){
		print "Command failed";
		exit;
	}
	system("rm","decoy.list");
}
