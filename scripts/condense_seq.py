#!/usr/bin/python

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("filelist")
args = parser.parse_args()

infile = open(args.filelist)
filelist = infile.readlines()
infile.close()

outfile = open("condense.seq", "w")

for entry in filelist:
	filename = entry.strip().split()[0]
	seqfile = open(filename)

	seqlines = seqfile.readlines()

	seqfile.close()
	#header = seqlines.pop()

	outfile.write( seqlines[0] )

	for i in range(1, len(seqlines)):
		outfile.write( seqlines[i].strip() )
	outfile.write("\n")

	#for line in seqlines:
	#	outfile.write( line.strip().split()[0] )

outfile.close()
