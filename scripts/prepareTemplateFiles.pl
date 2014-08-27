#!/usr/bin/perl -w

#    Firas Khatib 5/15/2012

#    NAME of Program: prepareTemplateFiles.pl

#    takes in a puzzle.align file and
#    takes in a list with each line containing the template .pdb files

#    grabs the names from the puzzle.align file and creates .template.pdb files accordingly


use warnings;
use strict;

if ($#ARGV < 0) {
    print STDERR "1 input: puzzle.align file \n";
    print STDERR "NOTE: pdbs must be in current directory\n";
    exit -1;
}


 open (ALIGN, $ARGV[0]) or die ("can't open the puzzle.align file $!");

my $i = 1;

system("mkdir original_template_files");

while(my $alignFile = <ALIGN>) {
  if ($alignFile =~ /1/) { 
    $alignFile =~ /^(\S+)\s+1\s+/;
    if ($1 ne "query") {
      my @line = split(/_/,$alignFile);
      my $ID = $line[0];
      if ($i > 1) {
		system("cp $ID.pdb $ID.$i.template.pdb");
      }
      else {
		system("cp $ID.pdb $ID.template.pdb");
      }	 
      system("mv $ID.pdb original_template_files");
      $i++;
    }	
  }
}
close (ALIGN) or die $!;




