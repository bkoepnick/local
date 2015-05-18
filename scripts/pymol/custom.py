from pymol import cmd
from itertools import izip
import math
 
'''
DESCRIPTION: Radius of gyration

USAGE
rgyrate [ selection ]
'''
def rgyrate(selection='(all)', quiet=1):
    quiet = int(quiet)
    model = cmd.get_model(selection).atom
    x = [i.coord for i in model]
    mass = [i.get_mass() for i in model]
    xm = [(m*i,m*j,m*k) for (i,j,k),m in izip(x,mass)]
    tmass = sum(mass)
    rr = sum(mi*i+mj*j+mk*k for (i,j,k),(mi,mj,mk) in izip(x,xm))
    mm = sum((sum(i)/tmass)**2 for i in izip(*xm))
    rg = math.sqrt(rr/tmass - mm)
    if not quiet:
        print "Radius of gyration: %.2f" % (rg)
    return rg

'''
DESCRIPTION: Create a png of each object with label, and save to working directory
USAGE
save_images
'''
def save_images(title=1):
	cmd.set( 'ray_opaque_background', 0 )
	for x in cmd.get_names( 'all' ):
		rg = rgyrate( x , 1 )

		cmd.disable( 'all' )
		cmd.enable( x )
		cmd.zoom( x, buffer=0.0, state=0, complete=1 )
		if title:
			cmd.set( 'label_size', 25 )
			#cmd.set( 'label_position', (0,-25,0) )
			cmd.set( 'label_position', (0,(-10-rg),0) )
			cmd.pseudoatom( 'pa', label=x )
		cmd.zoom( 'visible', buffer=5, state=0, complete=1 )
		cmd.png( x+'.png', dpi=300, ray=1 )
		cmd.delete( 'pa' )

'''
DESCRIPTION: Rainbow spectrum for all objects
USAGE
rainbow
'''
def rainbow():
	for i in cmd.get_object_list():
		to_color = i + ' and e. c'
		cmd.spectrum( 'count', 'rainbow', to_color )

'''
DESCRIPTION: Pairwise TMalign of every two structures
USAGE
tmalign_pairs
'''
def tmalign_pairs():
	all_pdbs = cmd.get_names( 'all' )

	pdb_pairs = []
	while ( len( all_pdbs ) > 1 ):
		pdb_pairs.append( all_pdbs[:2] )
		all_pdbs = all_pdbs[2:]

	for pdb_pair in pdb_pairs:
		tmalign( pdb_pair[0], pdb_pair[1] )
		cmd.spectrum( 'count', 'rainbow', pdb_pair[0] + ' and e. c' )
		cmd.color( 'white', pdb_pair[1] )
	
		cmd.create( pdb_pair[0] + '/' + pdb_pair[1], pdb_pair[0], 0, 1 )
		cmd.create( pdb_pair[0] + '/' + pdb_pair[1], pdb_pair[1], 0, 2 )
		cmd.delete( pdb_pair[0] )
		cmd.delete( pdb_pair[1] )

	cmd.set( 'all_states', 1 )
