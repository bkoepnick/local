#!/usr/bin/perl -w

#    Firas Khatib  6/8/12

#    NAME of Program: addInfoZipPDBs.pl  

#    takes in a list of all the pdbs you are going to clean and send to players as well as the current directory

#    goes through the file and outputs the filename/score/player_name tag

#    then cleans it up for the players and zips it up

use warnings;
use strict;

if ($#ARGV < 1) {


    print STDERR "2 inputs: <list of pdbs before cleaning them> and current directory\n";
    print STDERR "just run pwd, then pass it the result so it can grab the target info\n"; 
    print STDERR "outputs info.txt then runs cleanPDB on all the pdbs in current directory\n"; 
    print STDERR "ls1 solution_* > list\n";

    print STDERR "\ndirectory hierarchy must be something like: CASP_ROLL/T0709/Puz574/X\n";
    exit -1;
}


open (FILE, $ARGV[0]) or die ("can't open input file!");

open (OUTPUT, ">tmp");

my $pwd = $ARGV[1];

my @line = split(/CASP_ROLL/,$pwd);
my $info = $line[1];
my @line2 = split(/\//,$info);
my $target = $line2[1];
my $puzzle = $line2[2];
my $groupname = $line2[3];
my @line3 = split(/Puz/,$puzzle);
my $number = $line3[1];

my $flag = 0;
my $group = 0;
my $p2 = "";

while (my $line = <FILE>) {
    if ($line =~ /solution/) { #then grab the line
	$line =~ /(\S+).pdb/;
	my $filename = $1;
	open (DECOY, "$filename.pdb");
	while (my $file = <DECOY>) {
            if (($file =~ /^IRDATA PDL/)&&($flag ==0)) {
		my @line = split(/,/,$file);
		my $player = $line[0];
		my @p1 = split(/\. /,$player);
		$p2 = $p1[1];
		$group = $line[1];
		print OUTPUT "$filename, $p2";
		$flag = 1;
	    }
            elsif (($file =~ /^IRDATA PDL/)&&($flag ==1)) {
                my @line = split(/,/,$file);
                my $player = $line[0];
                my @p1 = split(/\. /,$player);
                my $p3 = $p1[1];
		if ($p3 ne $p2) {
		    print OUTPUT " & $p3";
		    $p2 = $p3;
		}
            }
	    if ($file =~ /^IRDATA ENERGY/) {
		my @line = split(/,/,$file);
		my $e = $line[0];
		my @e1 = split(/IRDATA ENERGY/,$e);
		my $energy = $e1[1];
		print OUTPUT "$energy";
                last;
	    }
            if ($file =~ /^IRDATA STARTINGSTRUCTURE/) {
                my @line = split(/ /,$file);
                my $pid = $line[2];
                my $start = $line[3];
		chomp $start;
                print OUTPUT ": $pid, $start, $group:";
                $flag = 0;
            }
	}
	close (DECOY) or die;
    }
}
close (OUTPUT);
close (FILE);

open (INFO, "tmp") or die ("can't open tmp file!");

open (FINAL, ">info$number\_$groupname.txt");

while (my $line = <INFO>) {
    if ($line =~ /^solution_/) { #then grab the line                                                                                                                      \

        my @file = split(/solution_/,$line);
        my $rest = $file[1];
        print FINAL "$rest";
    }
}
close (INFO);
close (FINAL);

system("rm tmp");
system("/work/firas/scripts/cleanPDBs.pl list");
system("zip $target\_$puzzle\_$groupname.zip *clean.pdb");
system("rm *clean.pdb");
#print "\nscp $target\_$puzzle\_$groupname.zip info$number\_$groupname.txt fw.bakerlab.org:\n";
#print "\nscp $target\_$puzzle\_$groupname.zip info$number\_$groupname.txt joist:/Users/firas/CASP10/$target/final_submits/$groupname\n";
#print "\nscp *clean.pdb info.txt mars:/Users/firas/Dropbox/CASP10/\n";
