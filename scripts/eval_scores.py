#!/usr/bin/python

# takes as arguments two score files

# both files must be sorted, and
# every pdb scored in macro_scores file must also be scored in control_scores file

import re
import sys
import argparse, math

parser = argparse.ArgumentParser()
parser.add_argument("control_scores")
parser.add_argument("macro_scores")
parser.add_argument("-merge", action='store_true', default=False)
parser.add_argument("-concise", action='store_true', default=False)
args = parser.parse_args()

file1 = open(args.control_scores, "r")
file2 = open(args.macro_scores, "r")

f1 = file1.readlines()
f2 = file2.readlines()

file1.close()
file2.close()

if( args.merge ):
	outfile = open("score_merge.txt","w")
	if not( args.concise ):
		outfile.write( "ID" + "\t" + "control_dE" + "\t" + "control_dRMSD" + "\t" + "macro_dE" + "\t" + "macro_dRMSD" + "\n" )
else:
	outfile = open("score_gain.txt", "w")
	if not( args.concise ):
		outfile.write( "ID" + "\t" + "sc_diff" + "\t" + "rms_diff" + "\n" )

d_sc_array = []
d_rms_array = []
d_sc_sum = 0
d_rms_sum = 0
i = 0
mismatch_str = ""
mismatch_count = 0

for control_line in f1:
	control_data = control_line.strip().split()
	macro_data = f2[i].strip().split()

	if( control_data[0] != macro_data[0] ):
		mismatch_count += 1
		mismatch_str += control_data[0] + '\n'

	elif( args.merge ):
		outfile.write( macro_data[0] + "\t" + control_data[1] + "\t" + control_data[2] + "\t" + macro_data[1] + "\t" + macro_data[2] + "\n" )
		if(i < len(f2)-1):
			i += 1

	else:	
		sc_diff = float(macro_data[1]) - float(control_data[1])
		rms_diff = float(macro_data[2]) - float(control_data[2])

		d_sc_sum += sc_diff
		d_sc_array.append(sc_diff)

		d_rms_sum += rms_diff
		d_rms_array.append(rms_diff)

		outfile.write( macro_data[0] + "\t" + str(sc_diff) + "\t" + str(rms_diff) + "\n" )
		if(i < len(f2)-1):
			i += 1

count = i+1
d_sc_avg = d_sc_sum/count
d_rms_avg = d_rms_sum/count

dev_sum = 0
for x in d_sc_array:
	dev_sum += (x - d_sc_avg) ** 2
d_sc_stdev = math.sqrt(dev_sum/count)

dev_sum = 0
for x in d_rms_array:
	dev_sum += (x - d_rms_avg) ** 2
d_rms_stdev = math.sqrt(dev_sum/count)


if not( args.merge ):
	outfile.write( "\nFor " + str(count) + " score comparisons:" + "\n")
	outfile.write( "Average change in score: " + str(d_sc_avg) + "\n" + "Std dev: " + str(d_sc_stdev) + "\n\n")
	outfile.write( "Average change in rmsd: " + str(d_rms_avg) + "\n" + "Std dev: " + str(d_rms_stdev) + "\n\n")

if not( args.concise ):
	outfile.write( '{0}'.format(mismatch_count) + " scores not found:\n" + mismatch_str )

outfile.close()
