from pymol import cmd, CmdException
 
def split_chains(selection='(all)', prefix=None):
    '''
DESCRIPTION
 
    Create a single object for each chain in selection
 
SEE ALSO
 
    split_states, http://pymolwiki.org/index.php/Split_object
    '''
    count = 0
    models = cmd.get_object_list('(' + selection + ')')
    for model in models:
        for chain in cmd.get_chains('(%s) and model %s' % (selection, model)):
            count += 1
            if not prefix:
                name = '%s_%s' % (model, chain)
            else:
                name = '%s%04d' % (prefix, count)
            cmd.create(name, '(%s) and model %s and chain %s' % (selection, model, chain))
        renumber(name)
        cmd.disable(model)
 
cmd.extend('split_chains', split_chains)

def renumber(selection='all', start=1, startsele=None, quiet=1):
    '''
DESCRIPTION

    Set residue numbering (resi) based on connectivity.

ARGUMENTS

    selection = string: atom selection to renumber {default: all}

    start = integer: counting start {default: 1}

    startsele = string: residue to start counting from {default: first in
    selection}
    '''
    start, quiet = int(start), int(quiet)
    model = cmd.get_model(selection)
    cmd.iterate(selection, 'atom_it.next().model = model',
            space={'atom_it': iter(model.atom)})
    if startsele is not None:
        startidx = cmd.index('first (' + startsele + ')')[0]
        for atom in model.atom:
            if (atom.model, atom.index) == startidx:
                startatom = atom
                break
        else:
            print ' Error: startsele not in selection'
            raise CmdException
    else:
        startatom = model.atom[0]
    for atom in model.atom:
        atom.adjacent = []
        atom.visited = False
    for bond in model.bond:
        atoms = [model.atom[i] for i in bond.index]
        atoms[0].adjacent.append(atoms[1])
        atoms[1].adjacent.append(atoms[0])
    minmax = [start, start]
    def traverse(atom, resi):
        atom.resi = resi
        atom.visited = True
        for other in atom.adjacent:
            if other.visited:
                continue
            if (atom.name, other.name) in [('C','N'), ("O3'", 'P')]:
                minmax[1] = resi+1
                traverse(other, resi+1)
            elif (atom.name, other.name) in [('N','C'), ('P', "O3'")]:
                minmax[0] = resi-1
                traverse(other, resi-1)
            elif (atom.name, other.name) not in [('SG', 'SG')]:
                traverse(other, resi)
    traverse(startatom, start)
    cmd.alter(selection, 'resi = atom_it.next().resi',
            space={'atom_it': iter(model.atom)})
    if not quiet:
        print ' Renumber: range (%d to %d)' % tuple(minmax)

cmd.extend('renumber', renumber)

