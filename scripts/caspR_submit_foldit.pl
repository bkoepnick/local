#!/opt/local/bin/perl

# To email solutions from commandline:

# Run this script with flag: -email koepnick@uw.edu
# Pipe contents to sendmail: 
# 	less mail.model1.R0046.caspR.pdb | sendmail -v casprol@predictioncenter.org


use strict;
use warnings;

if ($#ARGV < 0) {
    print STDERR "casp_submit_foldit.pl file1 file2 file3 file4 file5 -target 0001 -parent N/A -remark \"Top scoring solution from Foldit Player\(s\): \"\n"; 
    exit -1;
}

use Getopt::Long;

my $options = {};
$options->{target_id} = 0;
$options->{parent}    = [];
$options->{quick}     = 0;
$options->{dir}       = $ENV{PWD};
$options->{remark}    = 0;
$options->{email}	  = 0;

&GetOptions(
	$options,
	"quick!",
	"parent=s",
	"target_id=i",
	"remark=s",
	"email=s"
);

# format target_id properly
$options->{target_id} = sprintf( "%04d", $options->{target_id} );

my @files = @ARGV;

my $x = 1;
foreach my $file (@files) {
	if ( !$options->{quick} ) {
		my $fn = "model$x.R$options->{target_id}.caspR.pdb";
		if ( $options->{email} ) {
			$fn = "mail." . $fn;
		}
		
		my $out_fn = "$options->{dir}/" . $fn;
		$options->{model} = $x;
		open FILE, "<$file" or die $!;
		open OUT, ">$out_fn" or die $!;

		my $header = generate_header( $options );
		my $last_chain   = 'A';
		my $last_resi    = 0;
		my $current_resi = 0;
		print OUT $header;
		while ( my $line = <FILE> ) {
			if ( $line =~ /^ATOM/ ) {
				my $chain = chain_from_line($line);
				my $resi  = resi_from_line($line);
				if ( $chain ne $last_chain ) {
					$current_resi = 0;
					$last_chain   = $chain;
				}

				if ( $resi != $last_resi ) {
					$current_resi++;
				}

				$last_resi = $resi;
				$line = replace_resi( $line, $resi );
				print OUT $line;
			}
		}
		print OUT "TER\n";
		print OUT "END\n";
		close OUT  or die $!;
		close FILE or die $!;

		print join ' ', ( $file, '->', $out_fn );
		print "\n";

		$x++;
	}
}

sub generate_header {
	my $options = shift;
	my $target_id = $options->{target_id};
	my $parents   = join ' ', @{ $options->{parent} };
	my $model     = $options->{model};
	my $remark_line = '';
	if ( $options->{remark} ) {
	    $remark_line = $options->{remark};
	}
	my $header = <<HEADER;
PFRMAT TS
TARGET R$target_id
AUTHOR 1995-8105-3259
REMARK $remark_line
METHOD Models were constructed using Foldit, the online 
METHOD multi-player Rosetta game at http://fold.it.
METHOD Quality and ranking of individual models is determined entirely 
METHOD by the Rosetta full-atom energy. 
METHOD Foldit submissions are selected from the highest-scoring Foldit
METHOD submissions by score and diversity.
MODEL  $model
PARENT $parents
HEADER

	if ( $options->{email} ) {
		$header = "From: $options->{email}\n" . $header;
	}

	return $header;
}

sub chain_from_line {
	my $line = shift;

	my $chain = substr( $line, 21, 1 );
	return $chain;
}

sub replace_resi {
	my $line = shift;
	my $resi = shift;

	my $copy = join '', (
		substr ( $line, 0, 22 ),
		sprintf( "%4d", $resi ),
		substr ( $line, 26 ),
	);
	return $copy;
}

sub resi_from_line {
	my $line = shift;
	my $resi = substr( $line, 22, 4 );
	$resi += 0;
	return $resi;
}
