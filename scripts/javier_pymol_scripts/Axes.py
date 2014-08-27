# axes.py
from pymol.cgo import *
from pymol import cmd
from pymol.vfont import plain
import center_of_mass
 
import numpy as np

def plot_axis(center_obj=None, length=20, radius=0.1):
	# create the axes object, draw axes with cylinders coloured red, green,
	#blue for X, Y and Z
	com = (0.0, 0.0, 0.0)
	if center_obj:
	 	com = center_of_mass.get_com(center_obj)
	u_vec = com/np.linalg.norm(com)

	print 'Origin ', com
	print 'Unit vector ', u_vec

	obj = [
	   CYLINDER, com[0] - length, com[1], com[2], com[0] + length, com[1], com[2], radius, 1, 0, 0, 1, 0, 0,
	   CYLINDER, com[0], com[1] - length, com[2], com[0], com[1] + length, com[2], radius, 0, 1, 0, 0, 1, 0, 
	   CYLINDER, com[0], com[1], com[2]  - length, com[0], com[1], com[2] + length, radius,0, 0, 1, 0, 0, 1,
	   ]
	 
	# add labels to axes object (requires pymol version 0.8 or greater, I
	# believe
	 
	cyl_text(obj,plain,[com[0] - length, com[1], com[2]],'X',0.20,axes=[[3,0,0],[0,3,0],[0,0,3]])
	cyl_text(obj,plain,[com[0], com[1] - length, com[2]],'Y',0.20,axes=[[3,0,0],[0,3,0],[0,0,3]])
	cyl_text(obj,plain,[com[0], com[1], com[2]  - length],'Z',0.20,axes=[[3,0,0],[0,3,0],[0,0,3]])
	 
	# then we load it into PyMOL
	if center_obj:
		cmd.load_cgo(obj, center_obj + '_axes')
	else:
		cmd.load_cgo(obj,  'axes')

cmd.extend('axes', plot_axis)
