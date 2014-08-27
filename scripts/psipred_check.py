#!/work/koepnick/local/bin/python

import os,argparse	
import subprocess
from multiprocessing import Pool, Queue
import re
import random
import pdb_util

parser = argparse.ArgumentParser(description='')

group_in = parser.add_mutually_exclusive_group( required = True )
group_in.add_argument( '-s', type=str, nargs='+', help='input pdb_file' )
group_in.add_argument( '-l', type=str, help='list of pdb files' )

parser.add_argument( '-out', type=str, default='psichk.out', help='output filename' )
parser.add_argument( '-j', type=int, default=1, help='number of processors to use' )
parser.add_argument( '-tolerant', action='store_true', help='map [BGI] also to loop' )
parser.add_argument( '-irdata_energy', action='store_true', help='grab IRDATA ENERGY data from pdb_files' )

args = parser.parse_args()

pdb_list = []
if args.s:
	pdb_list = args.s
elif args.l:
	infile = open( args.l, 'r' )
	pdb_list = [ line.strip() for line in infile.readlines() ]
	infile.close()	

# dssp paths
EXEC_DSSP = os.path.abspath( '/work/koepnick/local/bin/dssp' )

# psipred paths
PSIPRED_ROOT = os.path.abspath( '/work/koepnick/local/apps/psipred/' )

EXEC_seq2mtx = os.path.join( PSIPRED_ROOT, 'bin/seq2mtx' )
EXEC_psipred = os.path.join( PSIPRED_ROOT, 'bin/psipred' )
#EXEC_psipass2 = os.path.join( PSIPRED_ROOT, 'bin/psipass2' )

PSIPRED_WEIGHTS = []
PSIPRED_WEIGHTS.append( os.path.join( PSIPRED_ROOT, 'data/weights.dat' ) )
PSIPRED_WEIGHTS.append( os.path.join( PSIPRED_ROOT, 'data/weights.dat2' ) )
PSIPRED_WEIGHTS.append( os.path.join( PSIPRED_ROOT, 'data/weights.dat3' ) )

# ss definitions
RE_HELIX = re.compile( '[GHI]' )
RE_SHEET = re.compile( '[BE]' )
RE_LOOP = re.compile( '[CST ]' )
if args.tolerant:
	RE_LOOP = re.compile( '[CSTBGI ]' )

random.seed()

MAXTASKS = 1000

# run dssp and return ss profile
def dssp( pdb_file ):
	cmd_dssp = [ EXEC_DSSP, pdb_file ]
	dssp_out = subprocess.Popen( cmd_dssp, stdout=subprocess.PIPE, stderr=subprocess.PIPE ).communicate()
	if dssp_out[1]:
		print 'Error during dssp!\nERROR: ' + dssp_out[1]
		exit(1)
	dssp_lines = dssp_out[0].splitlines()
	
	# toss the header lines
	while not ( re.compile( ' *#' ).match( dssp_lines.pop(0) ) ):
		continue

	# store dssp data in array of 3-tuples:
	# 	data[0] = residue number
	#	data[1]	= one-letter AA code
	#	data[2] = secondary structure code [HBEGITS ]
	dssp_data = [ ( int( dssp_line[1:5] ), dssp_line[13], dssp_line[16] ) for dssp_line in dssp_lines ]

	return dssp_data

# run psipred and return ss predictions
def psipred( pdb_file ):
	temp_id = 'psitmp' + str( random.randrange( 999999 ) )

	# generate fasta, write to temp file
	fasta = pdb_util.pdb2fasta( pdb_file )

	fasta_filename = temp_id + '.fasta'
	fasta_file = open( fasta_filename, 'w' )
	fasta_file.write( fasta )
	fasta_file.close()


	# generate mtx, write to temp file
	mtx_filename = temp_id + '.mtx'
	mtx_file = open( mtx_filename, 'w' )

	cmd_seq2mtx = [ EXEC_seq2mtx, fasta_filename ]
	seq2mtx_out = subprocess.Popen( cmd_seq2mtx, stdout=mtx_file, stderr=subprocess.PIPE ).communicate()
	if seq2mtx_out[1]:
		print 'Error during seq2mtx!\nERROR: ' + seq2mtx_out[1]
		exit(1)	


	# generate ss predictions
	cmd_psipred = [ EXEC_psipred ]
	cmd_psipred.append( mtx_filename )
	cmd_psipred.extend( PSIPRED_WEIGHTS )
	psipred_out = subprocess.Popen( cmd_psipred, stdout=subprocess.PIPE, stderr=subprocess.PIPE ).communicate()
	if psipred_out[1]:
		print 'Error during psipred!\nERROR: ' + psipred_out[1]
		exit(1)	

	
	# store psipred data in array of 6-tuples:
	#	data[0] = residue number
	#	data[1] = one-letter AA code
	#	data[2] = secondary structure code [HEC]
	#	data[3] = loop propensity
	#	data[4] = helical propensity
	#	data[5] = sheet propensity
	psipred_data = [ psipred_line.strip().split() for psipred_line in psipred_out[0].splitlines() ]
		
	os.remove( mtx_filename )
	os.remove( fasta_filename )

	return psipred_data

# return IRDATA ENERGY 
def irdata_energy( pdb_file ):
	pdb = open( pdb_file, 'r' )
	pdb_lines = pdb.readlines()
	pdb.close()

	for line in pdb_lines:
		if re.compile( "IRDATA ENERGY" ).match( line ):
			return line.strip().split()[2]
	
	return ''

# compare two ss characters
def compare_ss_char( i, j ):
	if RE_HELIX.match( i ) and RE_HELIX.match( j ):
		return 1
	if RE_SHEET.match( i ) and RE_SHEET.match( j ):
		return 1
	if RE_LOOP.match( i ) and RE_LOOP.match( j ):
		return 1
	return 0

# compare two ss profiles
def compare_ss_profiles( a, b ):
	if not len( a ) == len( b ):
		print 'SS profiles have different length!'
		return 0.0
	
	count = 0.0
	for i, j in zip( a, b ):
		count += compare_ss_char( i, j )

	return count/len( a )

# worker function
def evaluate_psipred( pdb_file ):
	psipred_data = psipred( pdb_file )
	dssp_data = dssp( pdb_file )

	psipred_profile = [ data[2] for data in psipred_data ]
	dssp_profile = [ data[2] for data in dssp_data ]

	ss_match = '{0:.3f}'.format( compare_ss_profiles( psipred_profile, dssp_profile ) )
	result = ( pdb_file, ss_match )
	#outstring = '{0}\t{1:.3f}'.format( pdb_file, compare_ss_profiles( psipred_profile, dssp_profile ) )

	if ( args.irdata_energy ):
		result += ( irdata_energy( pdb_file ), )
		#outstring += '\t{0}'.format( irdata_energy( pdb_file ) )
	
	#return result
	#print '\t'.join( result )
	evaluate_psipred.queue.put( result )

# intiator process defines queue for multiprocessing
def init_evaluate_psipred( queue ):
	evaluate_psipred.queue = queue

queue = Queue()
eval_pool = Pool( processes = args.j, init_evaluator_psipred, (queue, ), maxtasksperchild = MAXTASKS )
results = eval_pool.map( evaluate_psipred, [pdb.strip() for pdb in pdb_list] )

#outfile = open( args.out, 'w' )
#for result in results:
#	outfile.write( '\t'.join( result ) + '\n' )
#outfile.close()
