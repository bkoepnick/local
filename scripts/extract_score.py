#!/usr/bin/python

import os, argparse

parser = argparse.ArgumentParser()
parser.add_argument('infile')
args = parser.parse_args()

with open( args.infile, 'r' ) as infile:
    in_data = infile.readlines()
    infile.close()

description = args.infile.split('/')[-1].split('.')[0]
terms = []

for line in in_data:
	words = line.strip().split()
	if len(words) > 1 and words[1] == "SCORETYPEENERGIES":
		words.pop(0)
		words.pop(0)
		scores = []
		
		total = 0
		for word in words:
			tup = word.strip().split(':')
			name = tup[0]
			width = max( [len(name), 7] )
			weight = float(tup[1])
			weighted_value = weight*float(tup[2])

			terms.append( [name, '{:.2f}'.format( weight ), width+4] )
			scores.append( [name, '{:.2f}'.format( weight ), '{:.3f}'.format( weighted_value )] )
			total = total + weighted_value

print "TERM:  " + "".join( term[0].rjust( term[2] ) for term in terms)
print "WEIGHT:" + "".join( term[1].rjust( term[2] ) for term in terms)

print "SCORE: " + "".join( scores[i][2].rjust( terms[i][2] ) for i in range( len( scores ) ) if (scores[i][0] == terms[i][0] and scores[i][1] == terms[i][1]) )

print total
