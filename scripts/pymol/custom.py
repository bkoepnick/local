from pymol import cmd
from itertools import izip
import math

class PDB:
	def __init__( self, name ):
		# make a dictionary of residues
		self.residues = {}
		self.name = name

	def __repr__( self ):
		return self.name
	
	# add residue to dictionary
	def add_res( self, chain, resv ):
		self.residues[ ( chain, resv ) ] = 1


# dictionary of PDB objects
class PDB_list:
	def __init__( self ):
		self.pdbs = {}
	
	def add_pdb( self, pdb_name ):
		pdb = PDB( pdb_name )
		self.pdbs[ pdb_name ] = pdb

	def add_res( self, pdb_name, chain, resv ):
		if pdb_name not in self.pdbs:
			self.add_pdb( pdb_name )
		self.pdbs[ pdb_name ].add_res( chain, resv )

'''
DESCRIPTION: color residues based on ABEGO type

USAGE:
	color_abego [ enabled_only ]
'''
def color_abego( opt_enabled_only=True ):
	pdb_list = PDB_list()
	
	# make a namespace for iterate()
	myspace = { 'pdb_list' : pdb_list }
	cmd.iterate( 'n. ca', 'pdb_list.add_res( model, chain, resv )', space=myspace )

	# loop over each object
	for key, pdb in pdb_list.pdbs.iteritems():
		if pdb.name in cmd.get_names( 'objects', enabled_only=opt_enabled_only ):
			
			# list of residues for each ABEGO type
			bb_a = []
			bb_b = []
			bb_e = []
			bb_g = []
			bb_o = []
			
			# loop over each residue and calculate ABEGO type
			for res in pdb.residues:
				if ( res[0], res[1] - 1 ) in pdb.residues and ( res[0], res[1] + 1 ) in pdb.residues:
					a1 = '{0} and chain {1} and resi {2} and name {3}'.format( pdb, res[0], res[1] - 1, 'C' )
					a2 = '{0} and chain {1} and resi {2} and name {3}'.format( pdb, res[0], res[1]    , 'N' )
					a3 = '{0} and chain {1} and resi {2} and name {3}'.format( pdb, res[0], res[1]    , 'CA' )
					a4 = '{0} and chain {1} and resi {2} and name {3}'.format( pdb, res[0], res[1]    , 'C' )
					a5 = '{0} and chain {1} and resi {2} and name {3}'.format( pdb, res[0], res[1] + 1, 'N' )
					a6 = '{0} and chain {1} and resi {2} and name {3}'.format( pdb, res[0], res[1] + 1, 'CA' )
					phi = cmd.get_dihedral( a1, a2, a3, a4 )
					psi = cmd.get_dihedral( a2, a3, a4, a5 )
					omega = cmd.get_dihedral( a3, a4, a5, a6 )
					if abs( omega ) < 90 or abs( omega ) > 270:
						bb_o.append( res )
						continue

					if phi > 0:
						if psi < 100 and psi > -100:
							bb_g.append( res )
							continue
						else:
							bb_e.append( res )	
							continue
					else:
						if psi < 50 and psi > -72:
							bb_a.append( res )
							continue
						else:
							bb_b.append( res )
							continue

			# color carbons based on residue ABEGO type
			cmd.color( 'gray', '{0} and e. c'.format( pdb ) )
			if bb_a:
				cmd.select( 'bb_a', ' OR '.join( '{0} and chain {1[0]} and resi {1[1]} and e. c'.format( pdb, x ) for x in bb_a ) )
				cmd.color( 'red', 'bb_a' )
			if bb_b:
				cmd.select( 'bb_b', ' OR '.join( '{0} and chain {1[0]} and resi {1[1]} and e. c'.format( pdb, x ) for x in bb_b ) )
				cmd.color( 'blue', 'bb_b' )
			if bb_e:
				cmd.select( 'bb_e', ' OR '.join( '{0} and chain {1[0]} and resi {1[1]} and e. c'.format( pdb, x ) for x in bb_e ) )
				cmd.color( 'yellow', 'bb_e' )
			if bb_g:
				cmd.select( 'bb_g', ' OR '.join( '{0} and chain {1[0]} and resi {1[1]} and e. c'.format( pdb, x ) for x in bb_g ) )
				cmd.color( 'green', 'bb_g' )
			if bb_o:
				cmd.select( 'bb_o', ' OR '.join( '{0} and chain {1[0]} and resi {1[1]} and e. c'.format( pdb, x ) for x in bb_o ) )
				cmd.color( 'orange', 'bb_o' )
	
	# delete selections
	cmd.delete( 'bb_a' )
	cmd.delete( 'bb_b' )
	cmd.delete( 'bb_e' )
	cmd.delete( 'bb_g' )
	cmd.delete( 'bb_o' )

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

USAGE:
	save_images [ show_title ]
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

USAGE:
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

cmd.extend( 'abego', color_abego )
cmd.extend( 'rgyrate', rgyrate )
cmd.extend( 'save_images', save_images )
cmd.extend( 'rainbow', rainbow )

