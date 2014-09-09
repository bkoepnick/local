#!/opt/local/bin/perl

# The three score are:
# 1) minimal distance of 5
# 2) cb-cb distance of 8
# 3) cb-cb distance dependent on amino acid type

# with sequence separation >=  6


my @decoy;
my $d = 0;
while ($arg = shift())
{
	if ($arg =~ m/^-/)
	{
		$arg = lc($arg);
		if ($arg eq "-pdb1") { $pdb1 = shift();next; }
		if ($arg eq "-pdb2") { $pdb2 = shift();next; }
		#if ($arg eq "-nchain") { $N_chain = shift();next; }
		#if ($arg eq "-dchain") { $D_chain = shift();next; }
		
		if ($arg eq "-smin") { $smin = shift();next; }
		if ($arg eq "-scb") { $scb = shift();next; }
		if ($arg eq "-seqsep") { $seqsep = shift();next; }
	}
	else{$decoy[$d] = $arg; $d++; }
}

unless(-e $pdb1){die("-pdb1 '$pdb1' is missing");}
unless(-e $pdb2){die("-pdb2 '$pdb2' is missing");}

sub norm
{
    my ($mean, $stdev, $x) = @_;
	if($x <= $mean){return 1;}
	else{return exp(-($x - $mean)**2/(2 * ($stdev**2)));}
}

#unless(defined $N_chain){die("-nchain '$N_chain' native chain missing");}
#unless(defined $D_chain){die("-dchain '$D_chain' decoy chain missing");}
		
unless(defined $smin){$smin = 4.5;}
unless(defined $scb){$scb = 8.0;}
unless(defined $seqsep){$seqsep = 6;}

sub SR{my $str = $_[0]; $str =~ s/ //g; return $str;}
sub distance{return sqrt((($_[0]-$_[3])**2)+(($_[1]-$_[4])**2)+(($_[2]-$_[5])**2));}

my %AA = (	ALA => 'A', ARG => 'R', ASN => 'N', ASP => 'D', CYS => 'C',
	GLU => 'E', GLN => 'Q', GLY => 'G', HIS => 'H', ILE => 'I',
	LEU => 'L', LYS => 'K', MET => 'M', PHE => 'F', PRO => 'P',
	SER => 'S', THR => 'T', TRP => 'W', TYR => 'Y', VAL => 'V');

my %AT;	
@{$AT{G}} = ("CA");
@{$AT{A}} = ("CA","CB");
@{$AT{V}} = ("CA","CB","CG1","CG2");
@{$AT{I}} = ("CA","CB","CG1","CG2","CD1");
@{$AT{L}} = ("CA","CB","CG","CD1","CD2");
@{$AT{M}} = ("CA","CB","CG","SD","CE");
@{$AT{F}} = ("CA","CB","CG","CD1","CD2","CE1","CE2","CZ");
@{$AT{Y}} = ("CA","CB","CG","CD1","CD2","CE1","CE2","CZ","OH");
@{$AT{W}} = ("CA","CB","CG","CD1","CD2","NE1","CE2","CE3","CZ2","CZ3","CH2");
@{$AT{R}} = ("CA","CB","CG","CD","NE","CZ","NH1","NH2");
@{$AT{H}} = ("CA","CB","CG","ND1","CD2","CE1","NE2");
@{$AT{K}} = ("CA","CB","CG","CD","CE","NZ");
@{$AT{D}} = ("CA","CB","CG","OD1","OD2");
@{$AT{E}} = ("CA","CB","CG","CD","OE1","OE2");
@{$AT{N}} = ("CA","CB","CG","OD1","ND2");
@{$AT{Q}} = ("CA","CB","CG","CD","OE1","NE2");
@{$AT{C}} = ("CA","CB","SG");
@{$AT{S}} = ("CA","CB","OG");
@{$AT{T}} = ("CA","CB","OG1","CG2");
@{$AT{P}} = ("CA","CB","CG","CD");

my $db = "/Users/koepnick/scripts/database/final_distribution_21Feb2013.list";
#my $db = "/work/krypton/projects/for_hetu/tools/CB_CB_45_fix_03Jan2013";
my $pair;
my $pcount;
open(FILE,$db);
while($line = <FILE>)
{
	chomp($line);
	my @t = split("\t",$line);

	# SY	CA_CA	4.58507709854014	0.262083120079056	10.6507477189781	0.479992874913171
	@{$pair{$t[0]}{$t[1]}} = ($t[4],$t[5]);
	$pcount{$t[0]} += 1;

	my $rev = reverse($t[0]);
	if($t[0] ne $rev)
	{
		my @pa = split("_",$t[1]);
		@{$pair{$rev}{$pa[1]."_".$pa[0]}} = ($t[4],$t[5]);
		$pcount{$rev} += 1;
	}
}
close(FILE);

## get native
my @ident;
my $res_n;
my $N_seq;
my @col;
my $r = 0;
open(PDB,$pdb1);
my $model = 0;
while($line = <PDB> and $model < 2)
{
	chomp($line);
	my $record = SR(substr($line,0,6));
	if($record eq "MODEL"){$model++;}
	if($record eq "ATOM" and (substr($line,21,1))) # eq $N_chain or substr($line,21,1) eq " "))
	{
		my $atom = SR(substr($line,12,4));
		my $resi = substr($line,17,3);
		my $resn = SR(substr($line,22,5));
	
		if($res_n eq "" or $resn ne $res_n){if($col[$r]){$r++;}$res_n = $resn;}
		my $x_coord = SR(substr($line,30,8));
		my $y_coord = SR(substr($line,38,8));
		my $z_coord = SR(substr($line,46,8));
		@{$col[$r]{$atom}} = ($x_coord,$y_coord,$z_coord);
		unless(exists $ident[$r])
		{
			$ident[$r][0] = $resn;
			$ident[$r][1] = $AA{$resi};
			$N_seq .= $ident[$r][1];
		}
	}
}
close(PDB);
########################################################################
# get pdb distances
my $smin1 = 0;
my $scb1 = 0;
my $scbdy1 = 0;
my @dist;
my $m = 0;
my $a1 = 0;
while(exists $col[$a1])
{
	my $a2 = $a1 + 1;
	while(exists $col[$a2])
	{
		if(exists $col[$a1]{CA} and exists $col[$a2]{CA} and $ident[$a1][1] ne "" and $ident[$a2][1] ne "" and abs($ident[$a1][0]-$ident[$a2][0]) >= $seqsep)
		{
			my $CA_CA = distance($col[$a1]{CA}[0],$col[$a1]{CA}[1],$col[$a1]{CA}[2],$col[$a2]{CA}[0],$col[$a2]{CA}[1],$col[$a2]{CA}[2]);
			if($CA_CA <= 20)
			{
				my $min;
				my $CB_CB;
				for my $at1 (@{$AT{$ident[$a1][1]}})
				{
					for my $at2 (@{$AT{$ident[$a2][1]}})
					{
						if(exists $col[$a1]{$at1}[0] and exists $col[$a2]{$at2}[0])
						{
							my $DIST = distance($col[$a1]{$at1}[0],$col[$a1]{$at1}[1],$col[$a1]{$at1}[2],$col[$a2]{$at2}[0],$col[$a2]{$at2}[1],$col[$a2]{$at2}[2]);
							if($DIST < $min or !$min){$min = $DIST;}
							if(
								($at1 eq "CB" or ($ident[$a1][1] eq "G" and $at1 eq "CA")) and
								($at2 eq "CB" or ($ident[$a2][1] eq "G" and $at2 eq "CA"))
							){$CB_CB = $DIST;}
						}
					}
				}
				my $at1 = "CB";if($ident[$a1][1] eq "G"){$at1 = "CA";}
				my $at2 = "CB";if($ident[$a2][1] eq "G"){$at2 = "CA";}
				my $sCBdy_avg = $pair{$ident[$a1][1].$ident[$a2][1]}{$at1."_".$at2}[0];
				my $sCBdy_std = $pair{$ident[$a1][1].$ident[$a2][1]}{$at1."_".$at2}[1];
	
				#if($min <= $smin){$chk_min = 1;}else{$chk_min = 0;}
				#if($CB_CB <= $scb){$chk_cb = 1;}else{$chk_cb = 0;}
				#if($CB_CB <= $sCBdy_avg){$chk_cbdy = 1;}else{$chk_cbdy = 0;}
				my $chk_min = norm($smin,0.5,$min);
				my $chk_cb = norm($scb,0.5,$CB_CB);
				my $chk_cbdy = norm($sCBdy_avg,$sCBdy_std,$CB_CB);

				if($chk_min > 0.1 or $chk_cb > 0.1 or $chk_cbdy > 0.1)
				{
					@{$dist[$m]} = ($a1,$a2,$chk_min,$chk_cb,$chk_cbdy);
					$smin1 += $chk_min**2;
					$scb1 += $chk_cb**2;
					$scbdy1 += $chk_cbdy**2;
					$m++;
				}
			}
		}
		$a2++;
	}
	$a1++;
}

#my $j = 0;
#while(exists $decoy[$j])
#{
	#my $D = $decoy[$j];
	my $res_n;
	my $D_seq;
	my @D_ident;
	my @D_col;
	my $r = 0;
	open(PDB,$pdb2);
	my $model = 0;
	while($line = <PDB> and $model < 2)
	{
		chomp($line);
		my $record = SR(substr($line,0,6));
		if($record eq "MODEL"){$model++;}
		if($record eq "ATOM" and (substr($line,21,1))) # eq $D_chain or substr($line,21,1) eq " "))
		{
			my $atom = SR(substr($line,12,4));
			my $resi = substr($line,17,3);
			my $resn = SR(substr($line,22,5));

			if($res_n eq "" or $resn ne $res_n){if($D_col[$r]){$r++;}$res_n = $resn;}
			my $x_coord = SR(substr($line,30,8));
			my $y_coord = SR(substr($line,38,8));
			my $z_coord = SR(substr($line,46,8));
			@{$D_col[$r]{$atom}} = ($x_coord,$y_coord,$z_coord);
			unless(exists $D_ident[$r])
			{
				$D_ident[$r][0] = $resn;
				$D_ident[$r][1] = $AA{$resi};
				$D_seq .= $D_ident[$r][1];
			}
		}
	}
	close(PDB);
	my @NWalign = `/usr/local/bin/NWalign $N_seq $D_seq 3`;
	chomp($NWalign[7]); my @NNN = split (//,$NWalign[7]);
	chomp($NWalign[9]); my @DDD = split (//,$NWalign[9]);
	
	my $n = 0;
	my $d = 0;

	my @n2d;my @d2n;

	my $i = 0;
	while(exists $NNN[$i] and exists $DDD[$i])
	{
		if($NNN[$i] ne "-" and $DDD[$i] ne "-")
		{
			$n2d[$n] = $d;
			$d2n[$d] = $n;
		}
		if($NNN[$i] ne "-"){$n++;}
		if($DDD[$i] ne "-"){$d++;}
		$i++;
	}
	
	my $m = 0;
	my $smin2 = 0;
	my $scb2 = 0;
	my $scbdy2 = 0;
	
	while(exists $dist[$m])
	{		
		if(exists $n2d[$dist[$m][0]] and exists $n2d[$dist[$m][1]])
		{
			my $d1 = $n2d[$dist[$m][0]];
			my $d2 = $n2d[$dist[$m][1]];
			
			my $CA_CA = distance($D_col[$d1]{CA}[0],$D_col[$d1]{CA}[1],$D_col[$d1]{CA}[2],$D_col[$d2]{CA}[0],$D_col[$d2]{CA}[1],$D_col[$d2]{CA}[2]);
			if($CA_CA <= 20)
			{
				my $min;
				my $CB_CB;
				for my $at1 (@{$AT{$D_ident[$d1][1]}})
				{
					for my $at2 (@{$AT{$D_ident[$d2][1]}})
					{
						if(exists $D_col[$d1]{$at1}[0] and exists $D_col[$d2]{$at2}[0])
						{
							my $DIST = distance($D_col[$d1]{$at1}[0],$D_col[$d1]{$at1}[1],$D_col[$d1]{$at1}[2],$D_col[$d2]{$at2}[0],$D_col[$d2]{$at2}[1],$D_col[$d2]{$at2}[2]);
							if($DIST < $min or !$min){$min = $DIST;}
							if(
								($at1 eq "CB" or ($D_ident[$d1][1] eq "G" and $at1 eq "CA")) and
								($at2 eq "CB" or ($D_ident[$d2][1] eq "G" and $at2 eq "CA"))
							){$CB_CB = $DIST;}
						}
					}
				}
				my $at1 = "CB";if($D_ident[$d1][1] eq "G"){$at1 = "CA";}
				my $at2 = "CB";if($D_ident[$d2][1] eq "G"){$at2 = "CA";}
				my $sCBdy_avg = $pair{$D_ident[$d1][1].$D_ident[$d2][1]}{$at1."_".$at2}[0];
				my $sCBdy_std = $pair{$D_ident[$d1][1].$D_ident[$d2][1]}{$at1."_".$at2}[1];
                                        #@{$dist[$m]} = ($a1,$a2,$chk_min,$chk_cb,$chk_cbdy);
                                        #$smin1 += $chk_min**2;
                                        #$scb1 += $chk_cb**2;
                                        #$scbdy1 += $chk_cbdy**2;

				if(defined $dist[$m][2])
				{
					$smin2 += $dist[$m][2]*norm($smin,0.5,$min);
				}
				if(defined $dist[$m][3])
				{
					$scb2 += $dist[$m][3]*norm($scb,0.5,$CB_CB);
				}
				if(defined $dist[$m][4])
				{
					$scbdy2 += $dist[$m][4]*norm($sCBdy_avg,$sCBdy_std,$CB_CB);
				}
			}
		}
		$m++;
	}
	print $pdb1."\t".$pdb2."\t".sprintf("%.6f",(($smin2)/$smin1))."\t".sprintf("%.6f",(($scb2)/$scb1))."\t".sprintf("%.6f",(($scbdy2)/$scbdy1))."\n";
	$j++;
#}
