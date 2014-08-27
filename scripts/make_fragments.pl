#!/usr/bin/perl

use strict;
use warnings;

use File::Path;
use File::Copy qw/ copy /;
use File::Basename;
use Sys::Hostname;
use Time::Local;

use FindBin qw( $Bin );

use lib "/work/robetta/src/rosetta_server/cm_scripts/perl_lib";

#http://search.cpan.org/CPAN/authors/id/D/DL/DLUX/Parallel-ForkManager-0.7.5.tar.gz
use Parallel::ForkManager;

our $host = hostname;
###############################################################################
# USER CONFIGURATION  -- ONLY CHANGE THIS SECTION.
#                        YOU MUST EDIT THESE PATHS BEFORE USING
###############################################################################

# change the following paths to point to the locations of your copies of these
# files, databases or directories.

# BLAST install path (Requires non-blast+ NCBI version)
# recommended: blast-2.2.17
# ftp://ftp.ncbi.nih.gov/blast/executables/release/2.2.17/
my $BLAST_DIR = "/work/robetta/src/shareware/blast"
  ;    # "/my_src_dir/blast-2.2.17_x64/blast-2.2.17";
my $BLAST_NUM_CPUS = 8;    # number of processors to use (blastpgp -a option)

# NR blast database filename
# Create blast db files using 'formatdb  -o T -i nr'
# ftp://ftp.ncbi.nih.gov/blast/db/FASTA/nr.gz
my $NR = "/work/robetta/databases/local_db/nr/nr"; #"/my_database_dir/blast/nr";

# RCSB PDB files for homolog detection and date filtering when benchmarking
my $PDB_SEQRES      = "/work/robetta/databases/pdb/pdb_seqres.txt";
my $PDB_ENTRIES_IDX = "/work/robetta/databases/pdb/entries.idx";

# DEFAULT PDB STRUCTURE, PSSM, and SPARTA (chemical shift) DATABASE (VALL)
# note: vall.jul19.2011 does not yet include SPARTA data
# '-vall_files' option overrides this
my $VALL = "$Bin/vall.jul19.2011"; #"/my_database_dir/vall.apr24.2008.extended";

# pdb2vall.py script for adding specific PDBs to the vall (-add_pdbs_to_vall)
#  --no_structure_profile option is added to reduce the run time
# This feature is not supported yet in the Rosetta release
my $PDB2VALL = "$Bin/pdb2vall/pdb2vall.py --no_structure_profile";
my $PDB2VALL_IGNORE_ERRORS = 1;    # ignore pdb2vall jobs that fail

# ROSETTA FRAGMENT PICKER
my $FRAGMENT_PICKER =
  "/work/robetta/src/rosetta/rosetta_source/bin/fragment_picker.linuxgccrelease"
  ;    #"/my_src_dir/mini/bin/picker.linuxgccrelease";

# fragment_picker must be built with extras=boost_thread for multiple threads
my $FRAGMENT_PICKER_NUM_CPUS = 8;    # number of processors to use

my $ROSETTA_DATABASE = "/work/robetta/src/rosetta/rosetta_database"
  ;                                  #"/my_database_dir/rosetta_database";

# This is an optional script that you can provide to launch picker and pdb2vall jobs on
# free nodes to run them in parallel. If left as an empty string, jobs will run serially.
# Make sure your script will run the command passed to it on another machine. If it is
# set up to run parallel jobs on the local machine, the local machine may run into CPU
# and memory issues when running multiple picker and pdb2vall jobs in parallel, the
# fragment_picker and blastpgp may be cpu and memory intense.
my $SLAVE_LAUNCHER =
  "/work/robetta/src/rosetta_server/python/launch_on_slave_strict.py";
my $SLAVE_LAUNCHER_MAX_JOBS = 40;    # depends on your available machines/cpus

# spine-x/sparks (for phi, psi, and solvent accessibility predictions)
# http://sparks.informatics.iupui.edu/index.php?pageLoc=Services
# Uses Spine-X for solvent accessibility, phi, and psi predictions.
# If left as an empty string, solvent accessibility, phi, and psi scores
# will not be used which may reduce fragment quality.
my $SPARKS =
  "/work/robetta/src/rosetta_server/bin/sparks-x/bin/buildinp_query.sh"
  ;    #"/work/robetta/src/sparks/sparks-x/bin/buildinp_query.sh";

# THE FOLLOWING IS NOT REQUIRED IF YOU RUN SECONDARY STRUCTURE PREDICTION(S)
# MANUALLY AND USE THE FOLLOWING OPTIONS:
# -psipredfile <psipred file>
# -porterfile  <porter file>
# -samfile     <sam file>
# The porter and sam files should be in psipred_ss2 format using
# 'ss_pred_converter.py'.

# PSIPRED install path (secondary structure prediction software)
# http://bioinfadmin.cs.ucl.ac.uk/downloads/psipred/
my $PSIPRED_DIR = "/work/robetta/src/shareware/psipred"
  ;    # "/my_src_dir/psipred";    # psipred installation directory

my $PSIPRED_USE_weights_dat4 = 1;    # set to 0 if using psipred version 3.2+

# pfilt filtered NR blast database filename used for PSIPRED (see PSIPRED readme)
my $PFILTNR = "/work/robetta/databases/local_db/nr/nr_pfilt"
  ;                                  #"/my_database_dir/blast/nr_pfilt";



# BY DEFAULT, Psipred is used only and the following can be ignored unless
# you want to use the secondary structure prediction quota system with SAM 
# and Porter.


# SAM install path
# http://compbio.soe.ucsc.edu/sam2src/
my $SAM_DIR =
  "/work/robetta/src/shareware/sam"; #"/my_src_dir/sam3.5.x86_64-linux_current";

# SAM predict-2nd install path
# Secondary structure prediction software using SAM sequence alignment
# http://users.soe.ucsc.edu/~karplus/predict-2nd/
my $SAM_PREDICT_2ND_DIR = "/work/robetta/src/shareware/sam.predict2nd"
  ;    # "/my_src_dir/predict-2nd";    # sam predict-2nd directory

# PORTER (secondary structure prediction software)
# http://distill.ucd.ie/porter/
my $PORTER = "/work/robetta/src/shareware/porter/runPorter.pl"
  ;    # "/my_src_dir/porter_current/runPorter.pl";

if ( $host =~ /nrb/ ) {
    $NR              = "/scratch/robetta/local_db/nr/nr";
    $PFILTNR         = "/scratch/robetta/local_db/nr/nr_pfilt";
    $PDB_SEQRES      = "/scratch/shared/genomes/pdb_seqres.txt";
    $PDB_ENTRIES_IDX = "/scratch/shared/genomes/entries.idx";
}

###############################################################################
#
# MAKE_FRAGMENTS.PL -- THE (PEN)ULTIMATE IN HOME FRAGMENT-PICKING SOFTWARE!
#
# CAUTION:  NO USER SERVICEABLE PARTS BELOW!
#
#           TO REDUCE RISK OF ELECTRIC SHOCK, DO NOT REMOVE THE COVER!
#           DO NOT ATTEMPT REPAIRS!  REFER SERVICING TO YOUR AUTHORIZED DEALER!
#           AVOID PROLONGED EXPOSURE TO HEAT OR SUNLIGHT!
#           TO REDUCE THE RISK OF FIRE OR ELECTRIC SHOCK, DO NOT EXPOSE THE
#            PRODUCT TO RAIN AND/OR MOISTURE!
#           DO NOT MOVE THE PRODUCT WHILE IN USE!
#           DO NOT LOOK AT THE PRODUCT WHILE IN USE!
#           DO NOT COMPLAIN ABOUT THE PRODUCT WHILE IN USE!
#           DO NOT DISCUSS THE PRODUCT WHILE IN USE!
#           DO NOT THINK ABOUT THE PRODUCT WHILE IN USE!
#           CLEAN ONLY WITH MILD DETERGENTS AND A SOFT CLOTH!
#           USE ONLY IN WELL-VENTILATED AREAS!
#
#           FOR EXTERNAL USE ONLY!  DO NOT TAKE INTERNALLY!
#           MAY PRODUCE STRONG MAGNETIC FIELDS!
#
#           DO NOT REMOVE THIS TAG UNDER PENALTY OF LAW.
#
#           THIS ARTICLE CONTAINS NEW MATERIAL ONLY.
#
#           THIS LABEL IS AFFIXED IN COMPLAINCE WITH THE UPHOLSTERED AND
#            STUFFED ARTICLES ACT.
#
#
# (IN OTHER WORDS:  DON'T EVEN *THINK* ABOUT CHANGING THINGS BELOW THIS POINT!)
#
###############################################################################

## THESE FILE LOCATIONS DEPEND ON THE SOFTWARE PACKAGE
my $PSIBLAST = "$BLAST_DIR/bin/blastpgp -a $BLAST_NUM_CPUS ";
my $MAKEMAT = "$BLAST_DIR/bin/makemat";   # makemat utility (part of NCBI tools)
my $PSIPRED = "$PSIPRED_DIR/bin/psipred"; # psipred
my $PSIPASS2 = "$PSIPRED_DIR/bin/psipass2";    # psipass2 (part of psipred pkg)
my $PSIPRED_DATA = "$PSIPRED_DIR/data";    # dir containing psipred data files.

my $SAM           = "$SAM_DIR/bin/target99";     # sam target99
my $SAM_uniqueseq = "$SAM_DIR/bin/uniqueseq";    # sam uniqueseq

my $VALL_BLAST_DB =
  "$VALL.blast";    # blast database of VALL sequences for homolog detection
$VALL_BLAST_DB =~ s/\.gz\.blast$/\.blast/;

## for SLAVE_LAUNCHER parallel jobs
my $SLAVE_MAX_WAIT     = 96 * 60 * 60;
my $SLAVE_MAX_ATTEMPTS = 2;

use Cwd qw/ cwd abs_path /;
use bytes;

my %options;
$options{DEBUG} = 1;
use constant VERSION => 3.01;    # works with standard & warnings

$| = 1;                          # disable stdout buffering

# initialize options
my %opts = &getCommandLineOptions();
$options{fastafile} = abs_path( $opts{f} );
$options{rundir}      = cwd();     # get the full path (needed for sam stuff)
$options{homs}        = 1;
$options{frags}  = 1;
$options{psipredfile} = "";
$options{samfile}     = "";
$options{porterfile}  = "";
$options{psipred}     = 1;         # use psipred by default
$options{porter}      = 0;         # skip porter by default
$options{sam}         = 0;         # skip sam by default
$options{id}          = "temp";
$options{chain}       = "_";
$options{runid}       = "temp_";
$options{cleanup}     = 1;
$options{torsion_bin} = 0;
$options{exclude_homologs_by_pdb_date} = 0;
$options{old_name_format}              = 0;
$options{add_pdbs_to_vall}             = "";
$options{cst_file} = "";

my @cleanup_files  = ();
my @fragsizes      = ( 3, 9 );  #4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20 );
my @add_vall_files = ();
my @use_vall_files = ();
my @pdbs_to_vall   = ();
$options{n_frags}      = 200;
$options{n_candidates} = 1000;

foreach my $key ( keys %opts ) {
    $options{$key} = $opts{$key};
}

# special option parsing
if ( $options{verbose} ) {
    $options{DEBUG} = 1;
    print_debug("Run options:");
    print_debug("be verbose.");
}

if ( defined( $opts{frag_sizes} ) ) {
    @fragsizes = split( /,/, $opts{frag_sizes} );
    print_debug( "fragment sizes: " . join( " ", @fragsizes ) );
}

if ( exists $opts{add_vall_files} ) {
    foreach my $vall ( split( /,/, $opts{add_vall_files} ) ) {
        push( @add_vall_files, $vall ) if ( -s $vall );
    }
}

if ( exists $opts{use_vall_files} ) {
    foreach my $vall ( split( /,/, $opts{use_vall_files} ) ) {
        push( @use_vall_files, $vall ) if ( -s $vall );
    }
}

if ( defined $opts{add_pdbs_to_vall} ) {
    if ( !$PDB2VALL ) {
        print_debug(
            "ignoring -add_pdbs_to_vall option: PDB2VALL not configured");
    }
    else {
        @pdbs_to_vall = split( /,/, $opts{add_pdbs_to_vall} );
        print_debug( "pdbs to vall: " . join( " ", @pdbs_to_vall ) );
    }
}
mkpath( $options{rundir} );
$options{rundir} = abs_path( $options{rundir} );
chop( $options{rundir} ) if ( substr( $options{rundir}, -1, 1 ) eq '/' );
&checkExist( 'd', $options{rundir} );

if ( !defined( $opts{id} ) ) {
    print_debug("no id specified. parsing filename instead.");

    ( $options{id} ) = $options{fastafile} =~ /(\w+\.\w+)$/;
    print_debug("INTERMEDIATE: $options{id}");
    ( $options{id} ) = $options{id} =~ /^(\w+)/;

    if ( length( $options{id} ) != 5 ) {
        $options{id} = 't001_';
    }

    $options{chain} = substr( $options{id}, 4, 1 );
    $options{id}    = substr( $options{id}, 0, 4 );
    print_debug("ID: $options{id} CHAIN: $options{chain}");
}
else {
    chomp $opts{id};

    print_debug("id specified by user: $opts{id}");

    if ( length( $opts{id} ) != 5 ) {
        die("The id you specify must be 5 characters long.\n");
    }

    if ( $opts{id} =~ /\W+/ ) {
        die("Only alphanumeric characters and _ area allowed in the id.\n");
    }

    $options{id}    = substr( $opts{id}, 0, 4 );
    $options{chain} = substr( $opts{id}, 4, 1 );

    if ( -s "$options{id}$options{chain}.fasta" ) {
        my @diff = `diff $options{id}$options{chain}.fasta $options{fastafile}`;
        if ( scalar @diff ) {
            die
"ERROR! $options{id}$options{chain}.fasta already exists but does not match $options{fastafile}: $options{id}$options{chain}.fasta is autogenerated and should not exist\n";
        }
    }
    print_debug("using $options{fastafile} as query fasta");
    print_debug("ID: $options{id} CHAIN: $options{chain}");
}

$options{runid} = "$options{id}$options{chain}";

if ( abs_path( $options{fastafile} ) ne abs_path("$options{runid}.fasta") ) {
    copy( $options{fastafile}, "$options{runid}.fasta" );
    $options{fastafile} = "$options{runid}.fasta";
}

# determine what ss predictions to run
foreach my $ss_pred (qw/ porter sam psipred /) {
    if ( $options{$ss_pred} ) {
        my $fn_key = join '', ( $ss_pred, 'file' );
        my $fn = $options{$fn_key};
        $options{$ss_pred} = file_overrides_option( $fn, $ss_pred );
    }
}

my $abs_path_fasta = abs_path( $options{fastafile} );
$options{fastafile} = basename( $options{fastafile} );
if ( $abs_path_fasta ne abs_path("$options{rundir}/$options{fastafile}") ) {
    copy( $options{fastafile}, "$options{rundir}/" )
      or die "Error copying $options{fastafile} into $options{rundir}!\n";
}

print "picking fragments with options:\n", options_to_str( \%options ), "\n";
print_debug("FILENAME: $options{fastafile}");

# main

chdir( $options{rundir} );

if ( -f "$options{runid}.make_fragments.success" ) {
    print_debug("done! $options{runid}.make_fragments.success exists");
    exit(0);
}

# get the sequence from the fasta file
my $sequence = read_fasta( $options{fastafile} );
print_debug("Sequence: $sequence");

# run sparks
if ($SPARKS) {
    unless ( &nonempty_file_exists( $options{fastafile} . ".phipsi" ) ) {
        print_debug(
            "running sparks for phi, psi, and solvent accessibility predictions"
        );
        ( system("$SPARKS $options{fastafile}") == 0
              && -s $options{fastafile} . ".phipsi" )
          or die("sparks failed!\n");
    }
}

# run blast
unless ( &nonempty_file_exists("$options{runid}.check") ) {
    print_debug("running psiblast for sequence profile");
    if (
        !&try_try_again(
"$PSIBLAST -t 1 -i $options{fastafile} -F F -j2 -o $options{runid}.blast -d $NR -v10000 -b10000 -K1000 -h0.0009 -e0.0009 -C $options{runid}.check -Q $options{runid}.pssm",
            2,
            ["$options{runid}.check"],
            [
                "$options{runid}.check", "$options{runid}.blast",
                "$options{runid}.pssm",  "error.log"
            ]
        )
      )
    {
        die("checkpoint psi-blast failed!\n");
    }
}

unless ( &nonempty_file_exists("$options{runid}.checkpoint") ) {

    # parse & fortran-ify the checkpoint matrix.
    my @checkpoint_matrix;
    @checkpoint_matrix = &parse_checkpoint_file("$options{runid}.check");
    @checkpoint_matrix =
      &finish_checkpoint_matrix( $sequence, @checkpoint_matrix );
    &write_checkpoint_file( "$options{runid}.checkpoint", $sequence,
        @checkpoint_matrix );
}

push( @cleanup_files,
    ( "$options{runid}.blast", "$options{runid}.pssm", "error.log" ) );

# Secondary Structure Prediction methods
if ( $options{psipred}
    || ( $options{psipredfile} && -s $options{psipredfile} ) )
{
    print_debug("running psipred");

    if ( $options{psipredfile} && -s $options{psipredfile} ) {
        $options{psipred} = 1;
        system("cp $options{psipredfile} $options{runid}.psipred_ss2");
    }
    else {

        # run psi-blast for psipred
        unless ( &nonempty_file_exists("sstmp.chk")
            && &nonempty_file_exists("sstmp.ascii")
            && &nonempty_file_exists("ss_blast") )
        {
            if (
                !&try_try_again(
"$PSIBLAST -t 1 -b10000 -v10000 -j3 -h0.001 -d $PFILTNR -i $options{fastafile} -C sstmp.chk -Q sstmp.ascii -o ss_blast",
                    2,
                    [ "sstmp.chk", "sstmp.ascii" ],
                    [ "sstmp.chk", "sstmp.ascii", "ss_blast" ]
                )
              )
            {
                die("psipred psi-blast failed!\n");
            }
            push( @cleanup_files, ( "ss_blast", "sstmp.chk", "sstmp.ascii" ) );
        }

        unless ( &nonempty_file_exists("psitmp.sn") ) {
            &run( "echo $options{fastafile} > psitmp.sn", ("psitmp.sn") );
        }
        unless ( &nonempty_file_exists("psitmp.pn") ) {
            &run( "echo sstmp.chk > psitmp.pn", ("psitmp.pn") );
        }

        unless ( &nonempty_file_exists("sstmp.mtx") ) {
            if (
                !&try_try_again(
                    "$MAKEMAT -P psitmp",
                    2, ["sstmp.mtx"], ["sstmp.mtx"]
                )
              )
            {
                die("psipred: makemat failed.");
            }
        }

        unless ( &nonempty_file_exists("psipred_ss") ) {
            my $psipredcmd =
              ($PSIPRED_USE_weights_dat4)
              ? "$PSIPRED sstmp.mtx $PSIPRED_DATA/weights.dat $PSIPRED_DATA/weights.dat2 $PSIPRED_DATA/weights.dat3 $PSIPRED_DATA/weights.dat4 > psipred_ss"
              : "$PSIPRED sstmp.mtx $PSIPRED_DATA/weights.dat $PSIPRED_DATA/weights.dat2 $PSIPRED_DATA/weights.dat3 > psipred_ss";
            if (
                !&try_try_again(
                    $psipredcmd, 2, ["psipred_ss"], ["psipred_ss"]
                )
              )
            {
                die("psipred failed.");
            }
        }

        unless ( &nonempty_file_exists("$options{runid}.psipred_ss2") ) {
            if (
                !&try_try_again(
"$PSIPASS2 $PSIPRED_DATA/weights_p2.dat 1 1 1 psipred_ss2 psipred_ss > psipred_horiz",
                    2,
                    [ "psipred_ss2", "psipred_horiz" ],
                    [ "psipred_ss2", "psipred_horiz" ]
                )
              )
            {
                die("psipred/psipass2 failed.");
            }

            rename( "psipred_horiz", "$options{runid}.psipred" )
              or die(
                "couldn't move psipred_horiz to $options{runid}.psipred: $!\n");

            if ( !scalar(`grep 'PSIPRED VFORMAT' psipred_ss2`) ) {
                open( FILE, "psipred_ss2" );
                my @ss2 = <FILE>;
                close(FILE);
                open( FILE, ">$options{runid}.psipred_ss2" );
                print FILE
                  "# PSIPRED VFORMAT (PSIPRED V2.6 by David Jones)\n\n";
                print FILE @ss2;
                close(FILE);
            }
            else {
                rename( "psipred_ss2", "$options{runid}.psipred_ss2" )
                  or die(
"couldn't move psipred_ss2 to $options{runid}.psipred_ss2: $!\n"
                  );
            }
        }

    }

    if ( &nonempty_file_exists("$options{runid}.psipred_ss2") ) {
        print_debug("psipred file ok.");
    }
    else {
        print "psipred run failed!\n";
    }

    push( @cleanup_files, ( glob("psitmp*"), "psipred_ss", "sstmp.mtx" ) );
}

if ( $options{porter} || ( $options{porterfile} && -s $options{porterfile} ) ) {
    print_debug("running porter.");
    if ( $options{porterfile} && -s $options{porterfile} ) {
        $options{porter} = 1;
        system("cp $options{porterfile} $options{runid}.porter_ss2");
    }
    if ( &nonempty_file_exists("$options{runid}.porter_ss2") ) {
        print_debug("porter file ok.");
    }
    elsif (
        !&try_try_again(
            "$PORTER $options{fastafile}", 2,
            ["$options{runid}.porter_ss2"], ["$options{runid}.porter_ss2"]
        )
      )
    {
        die("porter failed!\n");
    }
}

# sam -- target99 alignment and predict2nd with 6 state neural net - condensed output to 3 state
if ( $options{sam} || ( $options{samfile} && -s $options{samfile} ) ) {
    print_debug("running sam.");
    if ( $options{samfile} && -s $options{samfile} ) {
        $options{sam} = 1;
        system("cp $options{samfile} $options{runid}.rdb_ss2");
    }
    if ( &nonempty_file_exists("$options{runid}.rdb_ss2") ) {
        print_debug("sam file ok.");
    }
    else {
        my $target99_out      = "$options{runid}.target99";
        my $target99_a2m_file = $target99_out . ".a2m";

        if (
            !&try_try_again(
                "$SAM -seed $options{fastafile} -out " . $target99_out, 2,
                [$target99_a2m_file], []
            )
          )
        {
            die "sam target99 failed!\n";
        }

        ## run uniqueseq
        my $uniqueseq_a2m_id   = "$options{runid}.uniqueseq";
        my $uniqueseq_a2m_file = $uniqueseq_a2m_id . ".a2m";
        if (
            !&try_try_again(
                "$SAM_uniqueseq $uniqueseq_a2m_id -percent_id 0.9 -alignfile "
                  . $target99_a2m_file,
                2,
                [$uniqueseq_a2m_file],
                [$uniqueseq_a2m_file]
            )
          )
        {
            die "sam uniqueseq failed!\n";
        }

        ## run predict-2nd
        chop($SAM_PREDICT_2ND_DIR)
          if ( substr( $SAM_PREDICT_2ND_DIR, -1, 1 ) eq '/' );

        # create samscript
        my $sam_6state = "$options{rundir}/$options{runid}.sam_6state";
        my $sam_ebghtl = "$options{rundir}/$options{runid}.sam_ebghtl";
        my $sam_log    = "$options{rundir}/$options{runid}.sam_log";
        my $samscript_txt_buf =
          qq{ReadAlphabet $SAM_PREDICT_2ND_DIR/std.alphabet
		ReadAlphabet $SAM_PREDICT_2ND_DIR/DSSP.alphabet
		ReadNeuralNet $SAM_PREDICT_2ND_DIR/overrep-3617-IDaa13-7-10-11-10-11-7-7-ebghtl-seeded3-stride-trained.net
		ReadA2M $options{rundir}/$uniqueseq_a2m_file
		PrintRDB $sam_6state
		PrintPredictionFasta $sam_ebghtl
	};
        my $samscript_txt = "$options{rundir}/$options{runid}.samscript.txt";
        open( SAMSCRIPT, '>' . $samscript_txt );
        print SAMSCRIPT $samscript_txt_buf;
        close(SAMSCRIPT);

        # get into $SAM_PREDICT_2ND_DIR so sam can read file recode3.20comp
        chdir $SAM_PREDICT_2ND_DIR;
        if (
            !&try_try_again(
"$SAM_PREDICT_2ND_DIR/predict-2nd -noalph < $samscript_txt >& $sam_log",
                2,
                [$sam_6state],
                [$sam_6state]
            )
          )
        {
            die "sam predict-2nd failed!\n";
        }
        chdir $options{rundir};

        # condense to 3 state prediction
        # formerly a separate perl script: condense_6state.pl
        my $rows;
        open IN, "<$sam_6state" or die "Cannot open file $sam_6state: $!\n";
        @{$rows} = <IN>;
        close(IN);
        $rows = &condense_rdb6_rdb($rows);
        open OUT, ">$options{runid}.rdb"
          or die "Cannot open file $options{runid}.rdb: $!\n";
        print OUT @{$rows};
        close(OUT);

        # convert rdb to rdb_ss2
        &convert_sam_ss("$options{runid}.rdb");
        if ( !-s "$options{runid}.rdb_ss2" ) {
            die("SAM failed!\n");
        }

        print_debug("sam file ok.");

        push @cleanup_files,
          (
            $samscript_txt, $sam_log, $sam_6state, $sam_ebghtl,
            $target99_a2m_file, $uniqueseq_a2m_file, "$target99_out.cst"
          );
    }
}

# Vall and homolog searches
if ( !$options{homs} ) {

    print_debug("excluding homologs.");
    unless ( &nonempty_file_exists("$options{runid}.outn") ) {
        if (
            !&try_try_again(
"$PSIBLAST -t 1 -i $options{fastafile} -j 1 -R $options{runid}.check -o $options{runid}.outn -e 0.05 -d $VALL_BLAST_DB",
                2,
                ["$options{runid}.outn"],
                ["$options{runid}.outn"]
            )
          )
        {
            die("homolog vall blast failed!\n");
        }
    }

    unless ( &nonempty_file_exists("$options{runid}.outn.pdb") ) {
        if (
            !&try_try_again(
"$PSIBLAST -t 1 -i $options{fastafile} -j 1 -R $options{runid}.check -o $options{runid}.outn.pdb -e 0.05 -d $PDB_SEQRES",
                2,
                ["$options{runid}.outn.pdb"],
                ["$options{runid}.outn.pdb"]
            )
          )
        {
            die("homolog pdb blast failed!\n");
        }
    }

    &exclude_blast( $options{runid} );
    &exclude_pdbblast( $options{runid} );
    &exclude_outn( $options{runid} );
}

if ( $options{exclude_homologs_by_pdb_date} ) {
    my $exclude_homologs_by_pdb_date_epoch;
    my $exclude_homologs_by_pdb_date = $options{exclude_homologs_by_pdb_date};
    print_debug("exclude_homologs_by_pdb_date: $exclude_homologs_by_pdb_date");
    if ( $exclude_homologs_by_pdb_date =~ /^(\d\d)\/(\d\d)\/(\d\d)$/ ) {
        my @dt = split( /\//, $exclude_homologs_by_pdb_date );
        $dt[0] =~ s/^0//;
        $dt[1] =~ s/^0//;
        $dt[2] =~ s/^0//;
        if ( $dt[2] < 30 ) {    # good till 2030
            $dt[2] += 2000;
        }
        else {
            $dt[2] += 1900;
        }
        $exclude_homologs_by_pdb_date_epoch =
          timelocal( 0, 0, 0, $dt[1], $dt[0] - 1, $dt[2] - 1900 );
        open( HOMF, ">>$options{runid}.homolog" );
        print HOMF
"# excluded by date $options{exclude_homologs_by_pdb_date} from $PDB_ENTRIES_IDX\n";
        open( F, $PDB_ENTRIES_IDX )
          or die "ERROR! cannot open $PDB_ENTRIES_IDX: $!\n";
        foreach my $l (<F>) {
            chomp $l;
            my @cols = split( /\t/, $l );
            if ( $#cols > 2 && $cols[2] =~ /^(\d\d)\/(\d\d)\/(\d\d)$/ ) {
                my $m = $1;
                my $d = $2;
                my $y = $3;
                $m =~ s/^0//;
                $d =~ s/^0//;
                $y =~ s/^0//;
                if ( $y < 30 ) {    # good till 2030
                    $y += 2000;
                }
                else {
                    $y += 1900;
                }
                my $epoch = timelocal( 0, 0, 0, $d, $m - 1, $y - 1900 );
                if ( $epoch > $exclude_homologs_by_pdb_date_epoch ) {
                    my $hit_pdb = lc $cols[0];    # pdb code
                    print HOMF "$hit_pdb\n";
                }
            }
            else {
                warn "Skipping line from $PDB_ENTRIES_IDX: $l\n";
            }
        }
        close(HOMF);
        close(F);
    }
    else {
        die
"ERROR! $exclude_homologs_by_pdb_date date format is incorrect: must be mm/dd/yy\n";
    }
}

if ( !$options{frags} ) {
    cleanup(@cleanup_files);
    exit 0;
}

# picker
my @valls = ($VALL);
if ( scalar @use_vall_files ) {
    @valls = @use_vall_files;
}
push( @valls, @add_vall_files ) if ( scalar @add_vall_files );

my $nativeexists = 0;
if ( -s "$options{runid}.pdb" ) {
    print_debug("native pdb exists: $options{runid}.pdb.");
    $nativeexists = 1;
}

# pdbs to vall
if ( scalar @pdbs_to_vall ) {
    print_debug("pdbs_to_vall");
    my $pdbs2valldir = "$options{rundir}/$options{runid}\_pdbs_to_vall";
    ( -d $pdbs2valldir || mkdir($pdbs2valldir) )
      or die "ERROR! cannot mkdir $pdbs2valldir: $!\n";
    chdir($pdbs2valldir);

    if ( !-s "$options{runid}\_pdbs_to_vall.vall" ) {
        if ( !$SLAVE_LAUNCHER ) {    # run in series
            foreach my $pdb (@pdbs_to_vall) {
                my $cmd = "$PDB2VALL -p $pdb";
                produce_output_with_cmd( $cmd, "$pdb.vall",
                    $PDB2VALL_IGNORE_ERRORS );
            }
        }
        else {
            my ( @commands, @results );
            foreach my $pdb (@pdbs_to_vall) {
                push( @commands, "$SLAVE_LAUNCHER $PDB2VALL -p $pdb" );
                push( @results,  "$pdb.vall" );
            }
            &run_in_parallel(
                \@commands,              \@results,
                "pdb2vall_parallel_job", $SLAVE_LAUNCHER_MAX_JOBS,
                $SLAVE_MAX_WAIT,         $SLAVE_MAX_ATTEMPTS,
                $PDB2VALL_IGNORE_ERRORS
            );
        }
    }

    # create one template vall - overwrite if exists
    open( F, ">$options{runid}\_pdbs_to_vall.vall" )
      or die "ERROR! cannot open $options{runid}\_pdbs_to_vall.vall: $!\n";
    foreach my $pdb (@pdbs_to_vall) {
        next if ( $PDB2VALL_IGNORE_ERRORS && !-s "$pdb.vall" );
        print_debug("adding $pdb.vall");
        open( NF, "$pdb.vall" ) or die "ERROR! cannot open $pdb.vall: $!\n";
        foreach my $nf (<NF>) {
            print F $nf;
        }
        close(NF);
    }
    close(F);

    if ( -s "$options{runid}\_pdbs_to_vall.vall" ) {
        push( @valls, "$pdbs2valldir/$options{runid}\_pdbs_to_vall.vall" );
    }
    else {
        warn
"WARNING! pdb2vall output $options{runid}\_pdbs_to_vall.vall does not exist.\n";
    }
}

my $valls_str = join ' ', @valls;

chdir("$options{rundir}");

foreach my $size (@fragsizes) {
    my $ss_pred_cnt = 0;
    my $score_def;
    my $sparkscmd = "";
    my $nativecmd = "";

    # score file (small fragments)
    if ( $size <= 4 ) {
        $score_def = <<SCORE;
# score name         priority  wght   min_allowed  extras
ProfileScoreL1           700     1.0     -
ProfileScoreStructL1     100     1.4     -
SCORE

        if ($SPARKS) {
            $score_def .= "SolventAccessibility     500     0.5     -\n";
            $score_def .= "Phi                      300     3.9     -\n";
            $score_def .= "Psi                      200     0.9     -\n";
            $sparkscmd =
              "-spine_x                  $options{fastafile}.phipsi\n";
        }

        $ss_pred_cnt = 0;
        foreach my $ss_pred (qw/ psipred sam porter /) {
            if ( $options{$ss_pred} ) {
                $ss_pred_cnt++;
                $score_def .=
                  "SecondarySimilarity      600     1.0     -    $ss_pred\n";
                $score_def .=
                  "RamaScore                400     6.0     -    $ss_pred\n";
            }
        }

        # score file (large fragments)
    }
    else {
        $score_def = <<SCORE;
# score name         priority  wght   min_allowed  extras
ProfileScoreL1           700     1.0     -
ProfileScoreStructL1     100     4.0     -
SCORE

        if ($SPARKS) {
            $score_def .= "SolventAccessibility     500     1.5     -\n";
            $score_def .= "Phi                      300     1.0     -\n";
            $score_def .= "Psi                      200     0.6     -\n";
            $sparkscmd =
              "-spine_x                  $options{fastafile}.phipsi\n";
        }

        $ss_pred_cnt = 0;
        foreach my $ss_pred (qw/ psipred sam porter /) {
            if ( $options{$ss_pred} ) {
                $ss_pred_cnt++;
                $score_def .=
                  "SecondarySimilarity      600     1.0     -    $ss_pred\n";
                $score_def .=
                  "RamaScore                400     0.8     -    $ss_pred\n";
            }
        }
    }

    if ( $options{torsion_bin} && -f $options{torsion_bin} ) {
        $score_def .= "TorsionBinSimilarity    100     1.0     -\n";
    }

    if ($nativeexists) {
        $score_def .= "FragmentCrmsd            30      0.0     -\n";
        $score_def .= "FragmentDME              30      0.0     -\n";
        $nativecmd = "-in:file:s $options{runid}.pdb\n";
    }

    my $cstcmd = "";
    if ($options{cst_file} && -s $options{cst_file}) {
        $FRAGMENT_PICKER_NUM_CPUS = 1; # fragment_picker does not work multi-threaded with constraints yet
        $score_def .= "AtomPairConstraintsScore 800     1.0     -\n";
        $cstcmd = "-cst_file $options{cst_file} -cst_weight 1.0\n";
    }

    my $score_file_name = "$options{runid}\_scores$size.cfg";
    open FILE, ">$score_file_name";
    print FILE $score_def;
    close FILE or die $!;

    open( PATH_DEFS, ">$options{runid}\_picker_cmd_size$size.txt" );
    my $cmdtxt = <<CMDTXT;
-in:file:fasta          $options{fastafile}
-in:path:database       $ROSETTA_DATABASE
-in:file:vall           $valls_str
-frags:n_candidates     $options{n_candidates}
-frags:n_frags          $options{n_frags}
-frags:frag_sizes       $size
-out:file:frag_prefix   $options{runid}
-frags:scoring:config   $score_file_name
#-out:level 2000
-in:file:checkpoint     $options{runid}.checkpoint
-frags:write_ca_coordinates
-frags:describe_fragments $options{runid}\_frags.$size.score
$sparkscmd
$nativecmd
$cstcmd
CMDTXT

    # add fragment secondary structure predictions
    my @frag_ss_tokens;
    if ( -s "$options{runid}.psipred_ss2" ) {
        push @frag_ss_tokens, ( "$options{runid}.psipred_ss2", "psipred" );
    }
    if ( -s "$options{runid}.rdb_ss2" ) {
        push @frag_ss_tokens, ( "$options{runid}.rdb_ss2", "sam" );
    }
    if ( -s "$options{runid}.porter_ss2" ) {
        push @frag_ss_tokens, ( "$options{runid}.porter_ss2", "porter" );
    }
    $cmdtxt .= join ' ', ( '-frags:ss_pred', @frag_ss_tokens );
    $cmdtxt .= "\n";
    if ( $options{torsion_bin} && -f $options{torsion_bin} ) {
        $cmdtxt .= "-in:file:torsion_bin_probs $options{torsion_bin}\n";
    }

    # auto-generate quota votes if more than 1 ss_pred is used
    if ( $ss_pred_cnt > 1 ) {
        my %votes;
        foreach my $ss_pred (qw/ psipred porter sam /) {
            if ( $options{$ss_pred} ) {
                $votes{$ss_pred} = get_ss_quota_vote($ss_pred);
            }
        }

        if ( scalar( keys %votes ) > 0 ) {
            my $quota_fn = "$options{runid}\_quota.def";
            open QUOTA, ">$quota_fn" or die $!;
            print QUOTA "#pool_id        pool_name       fraction\n";
            my $count = 1;

            use List::Util qw/ sum /;
            my $sum = sum( values %votes );
            foreach my $ss_pred ( keys %votes ) {
                my $pct = sprintf( "%4.2f", $votes{$ss_pred} / $sum );
                print QUOTA "$count          $ss_pred        $pct\n";
                $count++;
            }
            $cmdtxt .= "-frags:picking:quota_config_file $quota_fn\n";
        }
    }

    if ( !$options{homs} || $options{exclude_homologs_by_pdb_date} ) {
        $cmdtxt .= "-frags:denied_pdb  $options{runid}.homolog\n";
    }

    print PATH_DEFS $cmdtxt;
    close(PATH_DEFS);

    if ( !$SLAVE_LAUNCHER ) {    # run in series
        my $cmd =
"$FRAGMENT_PICKER \@$options{runid}\_picker_cmd_size$size.txt -j $FRAGMENT_PICKER_NUM_CPUS";
        produce_output_with_cmd( $cmd,
            "$options{runid}.$options{n_frags}.$size" . "mers" );
    }
}

if ($SLAVE_LAUNCHER) {           # run in parallel
    my ( @commands, @results );
    foreach my $size (@fragsizes) {
        push( @results, "$options{runid}.$options{n_frags}.$size" . "mers" );
        push( @commands,
"$SLAVE_LAUNCHER $FRAGMENT_PICKER \@$options{runid}\_picker_cmd_size$size.txt -j $FRAGMENT_PICKER_NUM_CPUS"
        );
    }
    &run_in_parallel( \@commands, \@results, "picker_parallel_job",
        $SLAVE_LAUNCHER_MAX_JOBS, $SLAVE_MAX_WAIT, $SLAVE_MAX_ATTEMPTS );
}

if ( $options{old_name_format} ) {
    foreach my $size (@fragsizes) {
        my $resultfile = "$options{runid}.$options{n_frags}.$size" . "mers";
        my $fragsize = sprintf( "%2.2d", $size );
        my $fragname = "aa$options{runid}$fragsize\_05.$options{n_frags}\_v1_3";

   # just in case scripts use rsync -a make the old_name_format the actual file
   # and then create a link for the original name (for parallel job checkpoints)
        if ( !-s $fragname ) {
            print_debug("mv $resultfile $fragname");
            ( system("mv $resultfile $fragname") == 0 && -s $fragname )
              or die "ERROR! attempt to move $resultfile to $fragname failed\n";
            print_debug("ln -s $fragname $resultfile");
            ( system("ln -s $fragname $resultfile") == 0 && -s $resultfile )
              or die "ERROR! attempt to link $fragname to $resultfile failed\n";
        }
    }
}

# create a success "checkpoint" file if all fragments are generated
my $success = 1;
foreach my $size (@fragsizes) {
    my $resultfile = "$options{runid}.$options{n_frags}.$size" . "mers";
    $success = 0 if ( !-s $resultfile );
}
system("touch $options{runid}.make_fragments.success") if ($success);

# done
print_debug("done!");
exit 0;

# subroutines

# getCommandLineOptions()
# rets: \%opts  pointer to hash of kv pairs of command line options
sub getCommandLineOptions {
    use Getopt::Long;

    my $usage =
      qq{usage: $0  [-rundir <full path to run directory (default = ./)>
		\t-verbose  specify for chatty output
		\t-id  <5 character pdb code/chain id, e.g. 1tum_>
		\t-nopsipred  don\'t run psipred. (run by default)
		\t-sam  run sam.
		\t-porter  run porter.
		\t-nohoms  specify to omit homologs from search
		\t-exclude_homologs_by_pdb_date <mm/dd/yy>
		\t-psipredfile  <path to file containing psipred ss prediction>
		\t-samfile  <path to file containing sam ss prediction>
		\t-porterfile  <path to file containing porter ss prediction>
		\t-nocleanup  specify to keep all the temporary files
		\t-add_vall_files <vall1,vall2,...> add extra Vall files
		\t-use_vall_files <vall1,vall2,...> use only the following Vall files
		\t-add_pdbs_to_vall <codechain,codechain,...> add extra pdb Vall files
		\t-frag_sizes <size1,size2,...n>
		\t-n_frags <number of fragments>
		\t-n_candidates <number of candidates>
		\t-nofrags specify to not make fragments and just run SS predictions
		\t-old_name_format  use old name format e.g. aa1tum_05.200_v1_3
		\t-cst_file <atom pair constraint file>
		\t<fasta file>
	};
    $usage = "$usage\n\n" . join ' ', ( 'Version:', VERSION, "\n" );

    # Get args
    my %opts;
    &GetOptions(
        \%opts,             "psipred!",
        "sam!",             "homs!",
        "frags!",           "porter!",
        "psipredfile=s",    "samfile=s",
        "porterfile=s",     "verbose!",
        "rundir=s",         "id=s",
        "cleanup!",         "frag_sizes=s",
        "n_frags=i",        "n_candidates=i",
        "add_vall_files=s", "use_vall_files=s",
        "torsion_bin=s",    "exclude_homologs_by_pdb_date=s",
        "old_name_format!", "add_pdbs_to_vall=s", "cst_file=s",
    );

    if ( scalar(@ARGV) != 1 ) {
        die "$usage\n";
    }

    $opts{f} = $ARGV[0];

    if ( $opts{f} =~ /[^\w\.\/]/ ) {
        die(
"Only alphanumeric characters, . and _ are allowed in the filename.\n"
        );
    }

    &checkExist( "f", $opts{f} );
    if ( defined $opts{frag_sizes} && $opts{frag_sizes} !~ /^[\d\,]+$/ ) {
        die "Fragment sizes are invalid\n";
    }

    if (wantarray) { return %opts; }
    return \%opts;
}

sub checkExist {
    my ( $type, $path ) = @_;
    if ( $type eq 'd' ) {
        if ( !-d $path ) {
            print STDERR "$0: dirnotfound: $path\n";
            exit -3;
        }
    }
    elsif ( $type eq 'f' ) {
        if ( !-f $path ) {
            print STDERR "$0: filenotfound: $path\n";
            exit -3;
        }
        elsif ( !-s $path ) {
            print STDERR "$0: emptyfile: $path\n";
            exit -3;
        }
    }
}

sub nonempty_file_exists {
    my $file = shift;
    return ( -f $file && !-z $file );
}

sub run {
    my ( $cmd, @files ) = @_;
    my $pid;

    print_debug("cmd is: $cmd");

  FORK: {
        if ( $pid = fork ) {

            # parent
            local $SIG{TERM} = sub {
                kill 9, $pid;
                `rm -f @files`;
                exit;
            };

            local $SIG{INT} = sub {
                kill 9, $pid;
                `rm -f @files`;
                exit;
            };

            wait;

            return $?;
        }
        elsif ( defined $pid ) {

            # child process
            exec($cmd);
        }
        elsif ( $! =~ /No more process/ ) {

            # recoverable error
            sleep 5;
            redo FORK;
        }
        else {

            # unrecoverable error
            die("couldn't fork: $!\n");
        }
    }
}

sub try_try_again {
    my ( $cmd, $max_tries, $success_files, $cleanup_files ) = @_;
    my $try_count     = 0;
    my $missing_files = 1;
    my $f;

    # if at first you don't succeed in running $cmd, try, try again.
    while ( ( $try_count < $max_tries ) && ( $missing_files > 0 ) ) {
        sleep 10;
        &run( $cmd, @$cleanup_files );
        ++$try_count;

        $missing_files = 0;

        foreach $f (@$success_files) {
            if ( !&nonempty_file_exists($f) ) {
                ++$missing_files;
            }
        }
    }

    # but if you've tried $max_tries times, give up.
    # there's no use being a damn fool about things.
    if ( $missing_files > 0 ) {
        return 0;
    }

    return 1;
}

sub exclude_outn {
    my ($runid) = @_;
    my @hits;
    my $hit;
    my $hit_pdb;
    my $hit_chain;
    my %uniq_hits;

    open( EXCL,  ">$runid.homolog_vall" );
    open( EXCL2, ">>$runid.homolog" );

    print_debug("exclude_outn: excluding homologs from $runid.outn");
    open( OUTN, "$runid.outn" );
    @hits = grep( /^>/, <OUTN> );
    close(OUTN);

    foreach $hit (@hits) {
        $uniq_hits{$hit} = 1;
    }

    foreach $hit ( sort keys %uniq_hits ) {
        ($hit_pdb) = $hit =~ /^>\s*(\w+)/;
        $hit_chain = substr( $hit_pdb, 4, 1 );
        $hit_pdb   = substr( $hit_pdb, 0, 4 );

        $hit_pdb =~ tr/[A-Z]/[a-z]/;
        $hit_chain = '_' if ( $hit_chain eq ' ' );
        $hit_chain = '_' if ( $hit_chain eq '0' );

        print EXCL "$hit_pdb$hit_chain\n";
        print EXCL2 "$hit_pdb$hit_chain\n";
    }

    close(EXCL);
    close(EXCL2);
}

sub exclude_pdbblast {
    my ($runid) = @_;
    my @hits;
    my $hit;
    my $hit_pdb;
    my $hit_chain;
    my %uniq_hits;

    open( EXCL,  ">$runid.homolog_pdb" );
    open( EXCL2, ">>$runid.homolog" );

    print_debug("exclude_pdbblast: excluding homologs from $runid.outn.pdb");
    open( OUTN, "$runid.outn.pdb" );
    @hits = grep( /^>/, <OUTN> );
    close(OUTN);

    foreach $hit (@hits) {
        $uniq_hits{$hit} = 1;
    }

    foreach $hit ( sort keys %uniq_hits ) {
        ($hit_pdb) = $hit =~ /^>\s*(\w+)/;
        $hit_chain = substr( $hit_pdb, 4, 1 );
        $hit_pdb   = substr( $hit_pdb, 0, 4 );

        $hit_pdb =~ tr/[A-Z]/[a-z]/;
        $hit_chain = '_' if ( $hit_chain eq ' ' );
        $hit_chain = '_' if ( $hit_chain eq '0' );

        print EXCL "$hit_pdb$hit_chain\n";
        print EXCL2 "$hit_pdb$hit_chain\n";
    }

    close(EXCL);
    close(EXCL2);
}

sub exclude_blast {
    my ($runid) = @_;
    my @hits;
    my $hit;
    my $hit_pdb;
    my $hit_chain;
    my %uniq_hits;

    open( EXCL,  ">$runid.homolog_nr" );
    open( EXCL2, ">>$runid.homolog" );

    print_debug("exclude_blast: excluding homologs from $runid.blast");
    open( BLAST, "$runid.blast" );
    @hits = grep( /pdb\|/, <BLAST> );
    close(BLAST);

    foreach $hit (@hits) {
        $uniq_hits{$hit} = 1;
    }

    foreach $hit ( sort keys %uniq_hits ) {
        while ( $hit =~ s/pdb\|(\w{4})\|(.?)// ) {
            $hit_pdb   = $1;
            $hit_chain = $2;

            $hit_pdb =~ tr/[A-Z]/[a-z]/;
            $hit_chain = '_' if ( $hit_chain =~ /^\s*$/ );

            print EXCL "$hit_pdb$hit_chain\n";
            print EXCL2 "$hit_pdb$hit_chain\n";
        }
    }

    close(EXCL);
    close(EXCL2);
}

## parse_checkpoint_file -- parses a PSI-BLAST binary checkpoint file.
#
# args:  filename of checkpoint file.
# rets:  N x 20 array containing checkpoint weight values, where N
#        is the size of the protein that BLAST thought it saw...

sub parse_checkpoint_file {
    my $filename = shift;
    my $buf;
    my $seqlen;
    my $seqstr;
    my $i;
    my $j;
    my @aa_order = split( //, 'ACDEFGHIKLMNPQRSTVWY' );
    my @altschul_mapping =
      ( 0, 4, 3, 6, 13, 7, 8, 9, 11, 10, 12, 2, 14, 5, 1, 15, 16, 19, 17, 18 );
    my @w;
    my @output;

    open( INPUT, $filename ) or die("Couldn't open $filename for reading.\n");

    read( INPUT, $buf, 4 ) or die("Couldn't read $filename!\n");
    $seqlen = unpack( "i", $buf );

    print_debug("Sequence length: $seqlen");

    read( INPUT, $buf, $seqlen ) or die("Premature end: $filename.\n");
    $seqstr = unpack( "a$seqlen", $buf );

    for ( $i = 0 ; $i < $seqlen ; ++$i ) {
        read( INPUT, $buf, 160 ) or die("Premature end: $filename, line: $i\n");
        @w = unpack( "d20", $buf );

        for ( $j = 0 ; $j < 20 ; ++$j ) {
            $output[$i][$j] = $w[ $altschul_mapping[$j] ];
        }
    }

    return @output;
}

## finish_checkpoint_matrix -- "finishes" the parsed PSI-BLAST checkpoint matrix,
##                             by adding pseudo-counts to any empty columns.
#
# args:  1) sequence string  2) array returned by parse_checkpoint_file
# rets:  "finished" array.  suitable for printing, framing, etc.

sub finish_checkpoint_matrix {
    my ( $s, @matrix ) = @_;
    my @sequence = split( //, $s );
    my $i;
    my $j;
    my $sum;
    my @words;
    my @b62;
    my @blos_aa =
      ( 0, 14, 11, 2, 1, 13, 3, 5, 6, 7, 9, 8, 10, 4, 12, 15, 16, 18, 19, 17 );

    my %aaNum = (
        A => 0,
        C => 1,
        D => 2,
        E => 3,
        F => 4,
        G => 5,
        H => 6,
        I => 7,
        K => 8,
        L => 9,
        M => 10,
        N => 11,
        P => 12,
        Q => 13,
        R => 14,
        S => 15,
        T => 16,
        V => 17,
        W => 18,
        Y => 19,
        X => 0
    );

    ( length($s) == scalar(@matrix) )
      or die("Length mismatch between sequence and checkpoint file!\n");

    my $blosum62 = <<BLOSUM;
#  BLOSUM Clustered Target Frequencies=qij
#  Blocks Database = /data/blocks_5.0/blocks.dat
#  Cluster Percentage: >= 62
   A      R      N      D      C      Q      E      G      H      I      L      K      M      F      P      S      T      W      Y      V
0.0215
0.0023 0.0178
0.0019 0.0020 0.0141
0.0022 0.0016 0.0037 0.0213
0.0016 0.0004 0.0004 0.0004 0.0119
0.0019 0.0025 0.0015 0.0016 0.0003 0.0073
0.0030 0.0027 0.0022 0.0049 0.0004 0.0035 0.0161
0.0058 0.0017 0.0029 0.0025 0.0008 0.0014 0.0019 0.0378
0.0011 0.0012 0.0014 0.0010 0.0002 0.0010 0.0014 0.0010 0.0093
0.0032 0.0012 0.0010 0.0012 0.0011 0.0009 0.0012 0.0014 0.0006 0.0184
0.0044 0.0024 0.0014 0.0015 0.0016 0.0016 0.0020 0.0021 0.0010 0.0114 0.0371
0.0033 0.0062 0.0024 0.0024 0.0005 0.0031 0.0041 0.0025 0.0012 0.0016 0.0025 0.0161
0.0013 0.0008 0.0005 0.0005 0.0004 0.0007 0.0007 0.0007 0.0004 0.0025 0.0049 0.0009 0.0040
0.0016 0.0009 0.0008 0.0008 0.0005 0.0005 0.0009 0.0012 0.0008 0.0030 0.0054 0.0009 0.0012 0.0183
0.0022 0.0010 0.0009 0.0012 0.0004 0.0008 0.0014 0.0014 0.0005 0.0010 0.0014 0.0016 0.0004 0.0005 0.0191
0.0063 0.0023 0.0031 0.0028 0.0010 0.0019 0.0030 0.0038 0.0011 0.0017 0.0024 0.0031 0.0009 0.0012 0.0017 0.0126
0.0037 0.0018 0.0022 0.0019 0.0009 0.0014 0.0020 0.0022 0.0007 0.0027 0.0033 0.0023 0.0010 0.0012 0.0014 0.0047 0.0125
0.0004 0.0003 0.0002 0.0002 0.0001 0.0002 0.0003 0.0004 0.0002 0.0004 0.0007 0.0003 0.0002 0.0008 0.0001 0.0003 0.0003 0.0065
0.0013 0.0009 0.0007 0.0006 0.0003 0.0007 0.0009 0.0008 0.0015 0.0014 0.0022 0.0010 0.0006 0.0042 0.0005 0.0010 0.0009 0.0009 0.0102
0.0051 0.0016 0.0012 0.0013 0.0014 0.0012 0.0017 0.0018 0.0006 0.0120 0.0095 0.0019 0.0023 0.0026 0.0012 0.0024 0.0036 0.0004 0.0015 0.0196
BLOSUM

    $i = 0;
    my @blosum62 = split( /\n/, $blosum62 );

    # read/build the blosum matrix
    foreach my $blosumline (@blosum62) {
        next if ( $blosumline !~ /^\d/ );
        chomp $blosumline;
        @words = split( /\s/, $blosumline );

        for ( $j = 0 ; $j <= $#words ; ++$j ) {
            $b62[ $blos_aa[$i] ][ $blos_aa[$j] ] = $words[$j];
            $b62[ $blos_aa[$j] ][ $blos_aa[$i] ] = $words[$j];
        }

        ++$i;
    }

    # normalize the blosum matrix so that each row sums to 1.0
    for ( $i = 0 ; $i < 20 ; ++$i ) {
        $sum = 0.0;

        for ( $j = 0 ; $j < 20 ; ++$j ) {
            $sum += $b62[$i][$j];
        }

        for ( $j = 0 ; $j < 20 ; ++$j ) {
            $b62[$i][$j] = ( $b62[$i][$j] / $sum );
        }
    }

    # substitute appropriate blosum row for 0 rows
    for ( $i = 0 ; $i <= $#matrix ; ++$i ) {
        $sum = 0;

        for ( $j = 0 ; $j < 20 ; ++$j ) {
            $sum += $matrix[$i][$j];
        }

        if ( $sum == 0 ) {
            for ( $j = 0 ; $j < 20 ; ++$j ) {
                $matrix[$i][$j] = $b62[ $aaNum{ $sequence[$i] } ][$j];
            }
        }
    }

    return @matrix;
}

sub write_checkpoint_file {
    my ( $filename, $sequence, @matrix ) = @_;
    my $row;
    my $col;
    my @seq = split( //, $sequence );

    open( OUTPUT, ">$filename" );

    die("Length mismatch between sequence and checkpoint matrix!\n")
      unless ( length($sequence) == scalar(@matrix) );

    print OUTPUT scalar(@matrix), "\n";

    for ( $row = 0 ; $row <= $#matrix ; ++$row ) {
        print OUTPUT "$seq[$row] ";
        for ( $col = 0 ; $col < 20 ; ++$col ) {
            printf OUTPUT "%6.4f ", $matrix[$row][$col];
        }
        print OUTPUT "\n";
    }

    print OUTPUT "END";

    close(OUTPUT);
}

## convert 6 state rdb file to 3 state
sub condense_rdb6_rdb {
    my ($rows) = @_;
    my ( $outrows, @parts, $line );
    for ( @{$rows} ) {
        if (/^#/) {
            push( @{$outrows}, $_ );
        }
        elsif (/^Pos/) {
            push( @{$outrows}, "Pos\tAA\tE\tH\tL\n" );
        }
        elsif (/^10N/) {
            push( @{$outrows}, "10N\t1S\t5N\t5N\t5N\n" );
        }
        elsif (/^[0-9]/) {
            @parts = split;
            die "Wrong number of columns in results row: $_\n" if $#parts != 7;
            $line = sprintf "%8s\t%1s\t%8s\t%8s\t%8s\n", $parts[0] - 1,
              $parts[1], $parts[2] + $parts[3], $parts[4] + $parts[5],
              $parts[6] + $parts[7];
            push( @{$outrows}, $line );
        }
        else {
            die "Unrecognized row: $_\n";
        }
    }
    return $outrows;
}

sub convert_sam_ss {
    my $ss_pred = shift;
    my ( $e, $h, $c, @ss );
    my $plusOne = 0;
    open( SAM, $ss_pred ) or die "ERROR! cannot open $ss_pred: $!\n";
    open( SAMCONV, ">$ss_pred\_ss2" )
      or die "ERROR! cannot open $ss_pred\_ss2: $!\n";
    print SAMCONV "# PSIPRED VFORMAT (PSIPRED V2.6 by David Jones)\n\n";
    while (<SAM>) {
        $_ =~ s/^\s+|\s+$//;
        next if ( $_ =~ /^#/ || $_ =~ /^\s*$/ );
        my @cols = split( /\s+/, $_ );
        next if ( scalar @cols != 5 || $cols[0] !~ /^\d+$/ );
        $e       = $cols[2];
        $h       = $cols[3];
        $c       = $cols[4];
        $plusOne = 1 if ( $cols[0] eq '0' );

        if ( $e >= $h && $e >= $c ) {
            printf SAMCONV "%4d $cols[1] E   %5.3f  %5.3f  %5.3f\n",
              $cols[0] + $plusOne, $c, $h, $e;
        }
        elsif ( $h > $e && $h >= $c ) {
            printf SAMCONV "%4d $cols[1] H   %5.3f  %5.3f  %5.3f\n",
              $cols[0] + $plusOne, $c, $h, $e;
        }
        elsif ( $c > $e && $c > $h ) {
            printf SAMCONV "%4d $cols[1] C   %5.3f  %5.3f  %5.3f\n",
              $cols[0] + $plusOne, $c, $h, $e;
        }
    }
    close(SAMCONV);
    close(SAM);
}

sub print_debug {
    if ( $options{DEBUG} ) {
        foreach my $line (@_) {
            print "$line\n";
        }
    }
}

sub cleanup {
    if ( $options{cleanup} ) {
        foreach my $file (@cleanup_files) {
            print_debug("removing file $file");
            unlink($file);
        }
    }
}

sub options_to_str {
    my $options = shift;

    my $str = '';

    use List::Util qw/ max /;
    my $max_width = max map { length($_) } keys %$options;
    my $format_str = "%" . $max_width . "s";
    foreach my $key ( sort keys %$options ) {
        my $val_str = $options->{$key};
        if ( ref( $options->{$key} ) eq 'ARRAY' ) {
            $val_str = join ' ', @{ $options->{$key} };
        }
        elsif ( ref( $options->{$key} ) eq 'HASH' ) {
            my @keys = keys %{ $options->{$key} };
            $val_str = join ', ',
              map { join ': ', ( $_, $options->{$key}{$_} ) } @keys;
        }
        $str .= join ': ', ( sprintf( $format_str, $key ), $val_str );
        $str .= "\n";
    }
    $str .= '-' x 80 . "\n";
    return $str;
}

sub produce_output_with_cmd {
    my $cmd          = shift;
    my $output_fn    = shift;
    my $no_output_ok = 0;
    $no_output_ok = shift if ( scalar @_ );

    print_debug("Command: $cmd");
    if ( -f $output_fn ) {
        print_debug("Skipping command, $output_fn exists!");
        return;
    }

    my $output = `$cmd`;
    print_debug("Finished running command: $cmd");
    if ( defined $output ) {
        print_debug("Output: $output");
    }

    if ( !$no_output_ok && !-f $output_fn ) {
        die "Error: expected creation of $output_fn after running '$cmd'!\n";
    }
}

sub read_fasta {
    my $fn = shift;

    open( SEQFILE, $fn ) or die "Error opening fasta file $fn!\n";
    my $has_comment = 0;
    my $eof;
    my $seq = '';
    while ( my $line = <SEQFILE> ) {
        $eof = $line;
        $line =~ s/\s//g;
        if ( $line =~ /^>/ ) {
            $has_comment = 1;
        }
        else {
            chomp $line;
            $seq .= $line;
        }
    }

    my $has_eof = ( $eof =~ /\n$/ );
    ( $has_comment && $has_eof )
      or die
      "fasta file (given $fn) must have a comment and end with a new line!\n";
    close SEQFILE or die $!;

    return $seq;
}

sub get_ss_quota_vote {
    my $ss_pred_name = shift;

    if ( $ss_pred_name eq 'psipred' ) {
        return 3;
    }
    elsif ( $ss_pred_name eq 'sam' ) {
        return 1;
    }
    elsif ( $ss_pred_name eq 'porter' ) {
        return 1;
    }
    else {
        die "Error: don't recognize ss_pred_name $ss_pred_name!\n";
    }
}

sub file_overrides_option {
    my $fn  = shift;
    my $tag = shift;

    if ( nonempty_file_exists($fn) ) {
        my $fn_base = basename($fn);
        if ( abs_path("$options{rundir}/$fn_base") ne abs_path($fn) ) {
            copy( $fn, "$options{rundir}/$fn_base" )
              or die "Error copying $fn -> $options{rundir}/$fn_base";
            push( @cleanup_files, $fn_base );
        }

        print "Assuming $options{rundir}/$fn_base is a $tag file.\n";
        return 0;
    }
    print "File for $tag not found! Generating from scratch instead.\n";
    if ( length($fn) ) {
        print "(given fn $fn)\n";
    }
    return 1;
}

sub run_in_parallel {
    my $commands_array_ref    = shift;
    my $resultfiles_array_ref = shift;
    my $runid                 = shift;
    my $maxparalleljobs       = shift;
    my $maxwait               = shift;
    my $maxattempts           = shift;
    my $ignore_errors         = 0;
    $ignore_errors = shift if ( scalar @_ );
    my @commands = @$commands_array_ref;
    my @results  = @$resultfiles_array_ref;
    return if ( !scalar @commands );
    ( scalar @commands == scalar @results )
      or die
      "ERROR! number of commands does not match results in run_in_parallel\n";

    my $logprefix = "$runid-$host";
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $maxwait;
        foreach my $attempt ( 1 .. $maxattempts ) {
            print_debug("Attempt $attempt");
            my $pm = Parallel::ForkManager->new($maxparalleljobs);
            for ( my $i = 0 ; $i <= $#commands ; ++$i ) {
                my $resultfile = $results[$i];
                next if ( -s $resultfile );
                $pm->start and next;
                my $PID     = $$;
                my $logfile = "$logprefix\_$i.log";
                my $command = "$commands[$i] >& $logfile";
                eval {
                    alarm $maxwait;
                    print_debug("starting process $PID to make $resultfile.");
                    system($command)
                      ; # keep in mind the command can be orphaned if this is timed out
                    print_debug("finished process $PID.");
                    alarm 0;
                };
                if ($@) { alarm 0; }
                $pm->finish;
            }
            $pm->wait_all_children;

            my %checkdone;
            for ( my $i = 0 ; $i <= $#results ; ++$i ) {
                my $resultfile = $results[$i];
                if ( -s $resultfile ) {
                    $checkdone{$resultfile} = 1;
                    print_debug("$resultfile exists!");
                }
                else {
                    print_debug("$resultfile missing!");
                }
            }
            last if ( scalar( keys %checkdone ) == scalar(@results) );
            if ( $attempt >= $maxattempts ) {
                if ($ignore_errors) {
                    warn
"WARNING! all result files do not exist after attempt $attempt.\n";
                    last;
                }
                else {
                    die
                      "ERROR! failed run_in_parallel after $attempt attempts\n";
                }
            }
            warn
"WARNING! all result files do not exist after attempt $attempt, attempting run_in_parallel again\n";
        }
        alarm 0;
    };
    if ($@) {
        alarm 0;
        if ($ignore_errors) {
            warn "WARNING! timed out run_in_parallel!\n";
        }
        else {
            die "ERROR! timed out run_in_parallel\n";
        }
    }
}
