#!/bin/sh

# Autoscale y-axis
#gnuplot -e "set term png; set output 'frag_qual.png'; plot 'frag_qual.dat' u 2:4 lt 1 pt 6"

# Set y-axis 
# gnuplot -e "set term png; set output 'frag_qual.png'; set yrange [0:5.0]; plot 'frag_qual.dat' u 2:4 lt 1 pt 6"
gnuplot -e "set term png; set output 'frag_qual.png'; set yrange [0:5.0]; plot '$1' u 2:4 lt 1 pt 6"
