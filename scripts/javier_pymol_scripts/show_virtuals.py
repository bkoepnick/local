from pymol import cmd,util
from Axes import plot_axis

def show_virtuals():
    cmd.hide('all')
    cmd.show('spheres', 'n. ORIG')
    cmd.set('sphere_scale', 0.6, 'n. ORIG')
    util.color_objs()
    plot_axis()

cmd.extend('virtuals', show_virtuals)
