#!/usr/bin/python

#====================================================================
# Brian Koepnick
# June 3, 2014
#
# Quick script to process sparse NMR constraints provided for CASP11
# 	Ts targets
#
# Input: One argument: file containing ambiguous NMR constraints
# Output: Writes normalized contacts to out.contact
#
#	Contact weights are normalized so that each peak contains one
# 		constraint with weight=1.00. Not ideal, but provides some 
#		way to limit the number of possible points awarded for huge
#		number of contacts.
#====================================================================

import sys
import re
import operator

def print_peak_norm( peak, max_weight, dest ):
	for fields in peak:
		fields[4] = "{0:.2f}".format( float( fields[4] ) / max_weight )
		dest.write( '\t'.join( fields ) + '\n' )

def rename_atom( name ):
	if name == 'H':
		return 'N'
	elif re.compile( 'HA' ).search( name ):
		return 'CA'
	else:
		return 'CB'

def peak_unique( peak, contacts ):
	#print "length: {0:d}".format( len( peak ) )
	if len(peak) == 1:
		#print "writing peak {0}...".format( peak[0][2] )
		contact = peak[0]
		contact[4] = "1.00"
		contact[3] = "{0:.2f}".format( float( contact[3] ) + 3.00 )
		contact[5] = rename_atom( contact[5] )
		contact[6] = rename_atom( contact[6] )
		if int( contact[1] ) < int( contact[0] ):
			temp = contact[0]
			contact[0] = contact[1]
			contact[1] = temp
	
		contacts.append( contact )
		return 1
	
	return 0

# print contacts file and cnstr file, avoiding duplicate contacts
def print_contacts( contacts, contact_dest, constr_dest ):
	sorted_contacts = sorted( contacts, key=lambda res: (int(res[0]), int(res[1])) )
	i = 0
	j = 0

	for contact in sorted_contacts:
		if contact[0] == i and contact[1] == j:
			continue
		contact_dest.write( '\t'.join( contact ) + '\n' )
		constr_dest.write( "AtomPair {0[5]} {0[0]} {0[6]} {0[1]} SCALARWEIGHTEDFUNC {0[4]} SUMFUNC 2 SIGMOID {0[3]} 3 CONSTANTFUNC -0.5\n".format( contact ) )
		i = contact[0]
		j = contact[1]

infile = open( sys.argv[1], 'r' )
inlines = infile.readlines()
infile.close()

contact_outfile = open( 'out.contacts', 'w' )
contact_outfile.write ( '##i\tj\tpeak\tdist\tweight\ta1\ta2\n' )
contact_outfile.write ( '1\t2\t0\t1.00\t0.00\tCB\tCB\n' )
cnstr_outfile = open( 'out.cnstr', 'w' )

contacts = []
peak = []
peak_num = '0'
peak_count = 0
max_weight = 0

for line in inlines:
	if re.compile( "##" ).match( line ):
		outfile.write( line )
		continue

	fields = line.strip().split()
	#print fields[2]
	if fields[2] != peak_num:
		#print peak_num + ' <=== '
		#print_peak_norm( peak, max_weight, outfile )
		#peak_count += 1

		peak_count += peak_unique( peak, contacts )

		peak_num = fields[2]
		peak = [ fields ]

		#max_weight = float( fields[4] )
		
	
	else:
		peak.append( fields )
		#max_weight = max( max_weight, float( fields[4] ) )
		
#print_peak( peak, max_weight, outfile ) 
peak_count += peak_unique( peak, contacts )
print_contacts( contacts, contact_outfile, cnstr_outfile )

contact_outfile.close()
cnstr_outfile.close()

