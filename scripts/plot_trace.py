#!/usr/bin/python

#===============================================================================
# Brian Koepnick
# June 17, 2014
#
#===============================================================================


import os, sys
import argparse
import re
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description='')
parser.add_argument( 'datafile', type=str, nargs='+', help='data file containing columns of data' )
parser.add_argument( '-title', type=str, help='title of plot' )
parser.add_argument( '-xkey', type=str, default='ml', help='value to plot on x-axis' )
parser.add_argument( '-ykey', type=str, default='215_signal', help='value to plot on y-axis' )
parser.add_argument( '-xlabel', type=str, help='label for x-axis' )
parser.add_argument( '-ylabel', type=str, help='label for y-axis' )
parser.add_argument( '-out', type=str, default='out.png', help='name of output file' )
parser.add_argument( '-y_min', type=float )
args = parser.parse_args()

COLOR = [ "b", "r", "g", "c", "m", "y", "k" ]

def parse_file( flines ):
	data_x = []
	data_y = []
	
	xi = 0
	if args.xkey:
		xi = flines[0].strip().split().index( args.xkey )
	
	yi = 1
	if args.ykey:
		yi = flines[0].strip().split().index( args.ykey )
	
	for i, record in enumerate( flines[1:] ):
		fields = record.strip().split()
		data_x.append( float( fields[xi] ) )
		data_y.append( float( fields[yi] ) )

	return data_x, data_y

# plot trace
def plot_trace( datafile, plot ):
	for i, fname in enumerate( datafile ):
		f = open( fname, 'r' )
		flines = f.readlines()
		f.close()

		x, y = parse_file( flines )
			
		plot.plot( x, y, color=COLOR[i%len( COLOR )] )

	if args.y_min:
		plot.set_ylim( args.y_min, plot.get_ylim()[1] )
	if args.xlabel:
		plot.set_xlabel( args.xlabel )
	if args.ylabel:
		plot.set_ylabel( args.ylabel )

	#plot.legend()

fig = plt.figure()

plot = plt.subplot(111)
plot_trace( args.datafile, plot )

if args.title:
	fig.suptitle( args.title )

fig.savefig( args.out )
