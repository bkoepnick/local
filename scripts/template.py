#!/usr/bin/python

import os,argparse    

parser = argparse.ArgumentParser(description='')

# basic argument types
parser.add_argument('-out' , type=str, default="fold.png", help='name of the output png file')
parser.add_argument('-x_min', type=float, default=0, help='X-Axis minimun limit')
parser.add_argument('-autoscale', type=bool, default="True", help='force autoscale')
parser.add_argument('-gdt', action='store_true', help='plot against GDTMM')

# flag with multiple arguments
parser.add_argument('-infiles', type=str, nargs='*', help='files to process')

# mutually exclusive arguments
in_format = parser.add_mutually_exclusive_group( required=True )
in_format.add_argument("-table", type=str, help="name of table file")
in_format.add_argument("-matrix", type=str, help="name of matrix file")

args = parser.parse_args()
