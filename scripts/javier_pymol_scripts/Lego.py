from pymol import *
def lego(selection, with_side_chains = False):
    cmd.hide()
    cmd.show("cartoon",selection)
    cmd.show("spheres", "name ca and "+ selection)
    cmd.set("sphere_scale",0.3)
    cmd.set("cartoon_flat_sheets",False)
    cmd.set("cartoon_throw", 0)
    cmd.color("red","ss h and " + selection)
    cmd.color("yellow", "ss s " + selection)
    cmd.color("green", "ss l " + selection)
    if with_side_chains:
        cmd.show("sticks", "! symbol h and " + selection)
        util.cbag("!name ca+c and " + selection)
        cmd.show("spheres", "name o+ and " + selection)

cmd.extend("lego",lego)
