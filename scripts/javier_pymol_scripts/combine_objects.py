from pymol import cmd
import os


def combine_objects( new_object='multistate' ):
    state = 1
    for obj in cmd.get_names('objects', enabled_only=1):
        cmd.create( new_object, obj, 0, state )
        state += 1
    

cmd.extend('combine_objects', combine_objects)
