#!/usr/bin/python
# Brian Koepnick 
# Dec 18, 2013

# Input: A text file with two columns, listing pairs of fragment.dat files to compare
# Output: A plot for each pair of fragment.dat files


import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('infile')
parser.add_argument('-ps', action='store_true')
args = parser.parse_args()

ext = 'png'
term = 'pngcairo'
if args.ps:
	ext = 'ps'
	term = 'postscript color'

with open( args.infile, 'r' ) as infile:
	in_data = infile.readlines()
	infile.close()

for data in in_data:
	pair = data.strip().split()
	fragsA = pair[0]
	fragsB = pair[1]

	fileID = fragsA.split('_')[0]	
	outfile = fileID + '_compare.' + ext

	
	os.system( 'gnuplot -e \"set term ' + term + '; set output \'' + outfile + '\'; set yrange [0:5.0]; plot \'' + fragsB + '\' u 2:4 lt 3 pt 6 ps 1.0, \'' + fragsA + '\' u 2:4 lt 1 pt 6 ps 1.0\"' )
