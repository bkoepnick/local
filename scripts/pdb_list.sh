#!/bin/bash

# makes a list of pdbs for each subdirectory in current directory

for dir in `ls`
do
	find $dir -name *pdb > $dir.list
done
