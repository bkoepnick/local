#!/bin/sh

# after running score_decoys.pl script:
# 	cd to directory containing multiple .sc files and run this script
# 	prints a single score file with id, score, rmsd

rm score.sc;

awk 'FNR>1 {
	split(FILENAME,a,"."); 
	if (match($NF, /macro/)) {
		split($NF,b,".");
		sid = b[1];
	}
	else sid = substr($NF,1,length($NF)-5);
	print (a[1] "/" sid " " $2 " " $(NF-1))}' *sc |

sort > score.sc;
