#!/bin/sh

awk '{if ($1 == "CRYST1" ||
	$1 ~ /ORIGX/ ||
	$1 ~ /SCALE/ ||
	$1 == "ATOM" ||
	$1 == "ANISOU" ||
	$1 == "TER" ||
	$1 == "END") print }' $1
