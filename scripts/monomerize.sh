#!/bin/bash

#single argument: pdb file
#writes chain A for pdb

awk '{
	n=split(FILENAME,a,"/");
	split(a[n],id,".");
	if ($1 == "ATOM" && $5 == "A") print > (id[1] "_mono.pdb")}' $1
