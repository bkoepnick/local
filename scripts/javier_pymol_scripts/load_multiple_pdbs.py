from pymol import cmd
from glob import glob

def load_pdbs( fn ):
	"""Load multiple pdbs:
			load_pdbs glob_expression
	"""
	for f in glob( fn ):
		cmd.load( f )
	
cmd.extend('load_pdbs', load_pdbs)
