#!/usr/bin/env python2.7

# October 9, 2013 Brian Koepnick
# koepnick@uw.edu

# Input file is either a table with: <res> <res> <contact_wt>
# 	or a matrix file with all residue-residue contact weights

import re
import sys
import argparse
import math

parser = argparse.ArgumentParser()
in_format = parser.add_mutually_exclusive_group( required=True )
in_format.add_argument("-table", type=str, help="name of table file")
in_format.add_argument("-matrix", type=str, help="name of matrix file")
parser.add_argument("-nres", type=int, required=True, help="number of residues in sequence")
parser.add_argument("-linear", action='store_true', default=False, help="scale the contact weights linearly, instead of parabolically")
args = parser.parse_args()

contacts = {}
contact_map = []
max_value = 0
min_value = 100
nres = args.nres

header = "version: 1\n{\n"
header += "\"version\" : \"2\"\n"
header += "\"multi_max\" : \"3\"\n"
header += "\"multi_offset\" : \"1\"\n"
header += "\"exploration_limit\" : \"55\"\n"
header += "\"angs_thresh\" : \"0\"\n"
	
if( args.matrix ):
	matrix_file = open(args.matrix, "r")
	matrix_lines = matrix_file.readlines()
	matrix_file.close()

	counter = 0
	for row in matrix_lines:
		counter += 1

		contact_row = []
		row_data = row.strip().split()
		for datum in row_data:
			value = float(datum)
			if value > max_value:
				max_value = value
			if value < min_value:
				min_value = value
			contact_row.append( value )
			print value
		assert len( contact_row ) == nres, "%d entries found in row %d for %d residues" % (len( contact_row ), counter, nres)
		contact_map.append( contact_row )

	assert len(contact_map) == nres, "%d rows found in matrix for %d residues" % (len( contact_map ), nres)

if( args.table ):
	table_file = open(args.table, "r")
	table_lines = table_file.readlines()
	table_file.close()	

	#initialize contact_map
	for i in range( nres ):
		contact_row = []
		for j in range( nres ):
			contact_row.append( 0 )
		
		contact_map.append( contact_row )

	for line in table_lines[1:]:
		y,x,value = (int(line.split()[0]), int(line.split()[1]), float(line.split()[5]))

		#y,x,value = (int(line.split()[0].split("_")[0]), int(line.split()[1].split("_")[0]), float(line.split()[3]))
		
		#x = int(x)
		#y = int(y)
		#value = float(value)
		#data = line.strip().split()
		#value = float(data[3])
		contact_map[ x-1 ][ y-1 ] = value
		contact_map[ y-1 ][ x-1 ] = value
		
		if value > max_value:
			max_value = value
		if value < min_value:
			min_value = value
		contacts[(x,y)] = value

outfile = open( "default.contact_heatmap", "w" )

begun_str = False

map_string = "\"heatmap\" : \""
#for contact_row in contact_map:
#	for value in contact_row:

for i in range(1, nres+1 ):
	for j in range(1, i):
		#if i == j:
		#	continue
		#value = contact_map[i-1][j-1]

		#normalize and invert
		if (i,j) in contacts:
			value = contacts[(i,j)]
			if args.linear:
				score_factor = 300 * (1 - (value-min_value)/(max_value-min_value) )
			else: 
				score_factor = 300 * math.sqrt(1 - (value-min_value)/(max_value-min_value) )
			print "%d %d %f" % (i, j, value)
		else:
			score_factor = 300	
	
		if not begun_str:
			map_string += "%d" % score_factor
			begun_str = True
		else:
			map_string += ",%d" % score_factor				

map_string += "\"\n"
outfile.write( header )
outfile.write( map_string )
outfile.write( "}" )
outfile.close()
