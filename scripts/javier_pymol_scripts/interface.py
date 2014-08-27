from pymol import cmd

def get_interface(obj1, obj2, threshold=5.0):
	inter_name = obj1 + '_' + obj2 + '_interface' if obj1 and obj2 else 'interface'
	print inter_name
	cmd.select(inter_name, "(" + obj1 + " within " + str(threshold) + " of " + obj2 + ") or (" + obj2 + " within " + str(threshold) + " of " + obj1 + ")")
	return inter_name

cmd.extend('get_interface', get_interface)


def show_interface(obj1, obj2, threshold=5.0):
	inter = get_interface(obj1, obj2, threshold)
	cmd.hide('everything', inter)
	cmd.show('cartoon', inter)
	cmd.show('surface', inter)
	cmd.show('sticks', inter + ' and not name c+o+n+ca ')
	cmd.set('transparency', 0.3, inter)
	
cmd.extend('show_interface', show_interface)
