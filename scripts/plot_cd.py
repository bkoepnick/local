#!/usr/bin/python

#===============================================================================
# Brian Koepnick
# May 22, 2014
#
# plot_cd.py plots the wavelength scans and melting curves from Baker Lab AVIV 
#	CD spectrometer
#
# usage: plot_cd.py [-h] [-wave [WAVE [WAVE ...]]] [-melt [MELT [MELT ...]]]
# 			[-title TITLE] [-key KEY] [-out OUT] [-y_min Y_MIN] [-average]
#			[-jasco]
#
#===============================================================================


import os, sys
import argparse
import re
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description='')
parser.add_argument( '-wave', type=str, nargs='*', help='wavelength scan input files' )
parser.add_argument( '-melt', type=str, nargs='*', help='melting curve input files' )
parser.add_argument( '-title', type=str, help='title of plot' )
parser.add_argument( '-key', type=str, default='CD_Signal', help='value to plot on y-axis' )
parser.add_argument( '-out', type=str, default='out.png', help='name of output file' )
parser.add_argument( '-y_min', type=float )
parser.add_argument( '-average', action='store_true', help='average multiple datasets per file' )
parser.add_argument( '-jasco', action='store_true', help='input files are JASCO .txt format' )
args = parser.parse_args()

if not args.wave and not args.melt:
	print "Must provide -wave or -melt arguments"
	exit(1)

COLOR = [ "b", "r", "g", "c", "m", "y", "k" ]

# simple function to extract single CD data set from a JASCO .txt file
# returns a list of tuples, where each tuple is (x-coords, y-coords)
# if no data are found, returns empty list
def parse_jasco_file( flines ):
	data = []
	data_x = []
	data_y = []

	for j, line in enumerate( flines ):

		# only care about lines after XYDATA
		if re.compile( 'XYDATA' ).match( line ):
			#assuming JASCO CD signal is always second column
			index = 1		

			for k, record in enumerate( flines[j+1:] ):	
				# when we encounter escape sequence, add information to data[] and return
				if re.compile( '#' ).match( record ):
					data.append( (data_x, data_y) )
					return data
				
				fields = record.strip().split()
				if fields:
					data_x.append( float( fields[0] ) )
					data_y.append( float( fields[ index ] ) )
			
			# if we don't encounter escape sequence, add information to data[] and return
			data.append( (data_x, data_y) )
			return data
		
	# if we never match the RE for data header
	return data

# recursive function to extract multiple CD data sets from an AVIV .dat file (probably not the best way to do this)
# returns a list of tuples, where each tuple is (x-coords, y-coords)
# if no data are found, returns empty list
def parse_aviv_file( flines ):
	data = []
	data_x = []
	data_y = []

	for j, line in enumerate( flines ):

		# only care about lines after $DATA
		if re.compile( '/$DATA' ).match( line ):
			return parse_aviv_file( flines[j+1:] )
		
		# locate data by 'CD_Signal' string and determine index of key
		if re.compile( "CD_Signal" ).search( line ):
			index = line.strip().split().index( args.key )
		
			for k, record in enumerate( flines[j+1:] ):	
				# when we encounter escape sequence, add information to data[]
				# recursive call to collect additional datasets
				if re.compile( '\$' ).match( record ):
					data.append( (data_x, data_y) )
					data.extend( parse_aviv_file( flines[k+1:] ) )
					break
				
				fields = record.strip().split()
				if fields:
					data_x.append( float( fields[0] ) )
					data_y.append( float( fields[ index ] ) )
			break
	return data

# handle multiple file formats
def parse_file( flines ):
	if args.jasco:
		return parse_jasco_file( flines )
	else:
		return parse_aviv_file( flines )	

# average multiple datasets
def average( datasets ):
	x_master, y_master = datasets[0]
	for x, y in datasets[1:]:
		for i, value in enumerate( x ):
			if value == x_master[i]:
				y_master[i] += y[i]
			else:
				print "Mismatched x coordinates among multiset data"
				exit(1)
	
	y_avg = []
	for y in y_master:
		y_avg.append( y/len( datasets ) )
	
	return x_master, y_avg

# plot wavelength scans
def plot_waves( waves, plot ):
	for i, fname in enumerate( waves ):
		f = open( fname, 'r' )
		flines = f.readlines()
		f.close()
		label = os.path.splitext( fname )[0].split('_')[2]	

		datasets = parse_file( flines )
		if args.average:
			x, y = average( datasets )
		else:
			x, y = datasets[0]
			
		plot.plot( x, y, color=COLOR[i%len( COLOR )], label=label )

	if args.y_min:
		plot.set_ylim( bottom=args.y_min )
	plot.legend()
	plot.set_xlabel( 'Wavelength (nm)' )
	plot.set_ylabel( 'Ellipticity (mdeg)' )

# plot melting curve
def plot_melts( melts, plot ):
	for i, fname in enumerate( melts ):
		f = open( fname, 'r' )
		flines = f.readlines()
		f.close()

		x, y = parse_file( flines )[0]
			
		plot.plot( x, y, color=COLOR[i%len( COLOR )] )

	plot.set_xlabel( 'Temperature (C)' )
	plot.set_ylabel( 'Ellipticity at 220nm (mdeg)' )
	plot.set_ylim( top=0 )

fig = plt.figure()
if args.wave and args.melt:
	wave = plt.subplot2grid((2,1), (0,0))
	melt = plt.subplot2grid((2,1), (1,0))
	plot_waves( args.wave, wave )
	plot_melts( args.melt, melt )
	fig.set_size_inches(8, 10)

elif args.wave:
	wave = plt.subplot(111)
	plot_waves( args.wave, wave )
elif args.melt:
	melt = plt.subplot(111)
	plot_melts( args.melt, melt )

if args.title:
	fig.suptitle( args.title )

fig.savefig( args.out )
