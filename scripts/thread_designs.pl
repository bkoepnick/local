#!/usr/bin/perl -w

#   Brian Koepnick 04/21/2013

#   NAME of Program:  thread_designs.pl

#	Requires repack.xml RosettaScripts file

use warnings;
use strict;
use File::Basename;

if ($#ARGV != 2){
    print STDERR "\nImproper command\n";
    exit -1;
}

my $EXEC = "~/rosetta_benchmark/rosetta_source/bin/rosetta_scripts.default.linuxgccrelease";
my $ROSETTA_DATABASE = "/work/koepnick/rosetta_benchmark/rosetta_database";

my $xml_file = $ARGV[0];
my $native_dir = $ARGV[1];
my $fasta_dir = $ARGV[2];

my $native_content = `find $native_dir -name "*pdb"`;
my @native_list = split (/\n/, $native_content);
chomp(@native_list);

foreach my $native (@native_list){
	my @suffix_list = (".pdb");
	my ($pdb_id, $dir, $suffix) = fileparse($native, @suffix_list);

	open(my $fasta_file, $fasta_dir . "/" . $pdb_id . ".fasta") or die "Could not open file: $!\n";
	my $fasta_seq = <$fasta_file>;
	close($fasta_file);	
	chomp $fasta_seq;

	my @args = ("$EXEC",
		"-database $ROSETTA_DATABASE",
		"-parser:protocol $xml_file",
		"-in:file:s $native",
		"-parser:script_vars sequence=$fasta_seq",
		"-nstruct 1",
		"-ignore_unrecognized_res",
		"-out:path:pdb $fasta_dir");
	system("@args");
	if($?!=0){
		print "Command failed on $native";
	}
}
