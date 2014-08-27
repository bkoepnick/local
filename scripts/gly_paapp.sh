#!/bin/sh

awk '{if ($3 == "GLY"){
	a = $6*$6/0.57353;
	printf "%4s %4s %3s %7s %7s %7.5f\n", $1, $2, $3, $4, $5, a; 
	} else print;
}' $1
