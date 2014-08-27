#!/bin/sh

sort -k1.1,1.4 -k1.7 -k1.8,1.12n $1 | \

awk 'BEGIN{
		FIELDWIDTHS = "4 3 5 4 4 6 3"
		longres="";
		shortres="";
		seq="";
		pdb="";
	}
	{
		if($1 != pdb && pdb != ""){
			print seq > (pdb ".fasta");
			seq = "";
		}
		pdb = $1;
		longres = $5;
		sub(/^ */, "", longres);

		if(longres == "ALA") res = "A";
		else if(longres == "CYS") res = "C";
		else if(longres == "ASP") res = "D";
		else if(longres == "GLU") res = "E";
		else if(longres == "PHE") res = "F";
		else if(longres == "GLY") res = "G";
		else if(longres == "HIS") res = "H";
		else if(longres == "ILE") res = "I";
		else if(longres == "LYS") res = "K";
		else if(longres == "LEU") res = "L";
		else if(longres == "MET") res = "M";
		else if(longres == "ASN") res = "N";
		else if(longres == "PRO") res = "P";
		else if(longres == "GLN") res = "Q";
		else if(longres == "ARG") res = "R";
		else if(longres == "SER") res = "S";
		else if(longres == "THR") res = "T";
		else if(longres == "VAL") res = "V";
		else if(longres == "TRP") res = "W";
		else if(longres == "TYR") res = "Y";

		seq = seq res;
	}
	END{
		print seq > (pdb ".fasta")
	}'
