
from  pymol import cmd
from pymol import stored
import string

def secstruct(selection):
	'''returns a string with the secondary structure'''
	stored.ss = ""
	cmd.split_states(selection, prefix='model')
	cmd.dss('model0001')
	cmd.iterate('model0001 and n. CA', 'stored.ss = stored.ss + ss')
	cmd.delete('model*')
	ss  =  stored.ss
	print ss
	return ss

cmd.extend('secstuct', secstruct)

def ss_segments(selection):
	'''returns a list of tuples ss, start and end position'''
	ss_tuples = [ ]
	ss = secstruct(selection)

	last = ' '
	start = 0
	end = 0
	for x in ss:
		if x == last:
			end += 1
		else:
			ss_tuples.append( (last, start, end) )
			last = x
			start = end + 1
			end = start
	print len(ss_tuples), ' secondary structure elements found'
	return ss_tuples


cmd.extend('ss_segments', ss_segments)

