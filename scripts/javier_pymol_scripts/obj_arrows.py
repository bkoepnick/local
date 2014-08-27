from pymol import cmd
import re

is_axis = re.compile('.*axes')

def move_down( orient=True ):
    def move( ):
        enabled_objs = filter(lambda x: not is_axis.match(x), cmd.get_names("objects",enabled_only=1))
        all_objs = filter(lambda x: not is_axis.match(x), cmd.get_names("objects",enabled_only=0))
        has_enabled_axis = False;
        for n in cmd.get_names("objects",enabled_only=1):
            if is_axis.match( n ):
                has_enable_axis = True
                break
        for obj in enabled_objs:
            cmd.disable(obj)
            last_obj=obj
            for i in range(0,len(all_objs)):
                if all_objs[i] == obj:
                    if i+1 >= len(all_objs):
                        cmd.enable( all_objs[0] )
                    else:
                        cmd.enable( all_objs[i+1] )
        if not has_enabled_axis:
            if(orient):
                cmd.zoom('visible')
                cmd.orient()
        cmd.zoom('visible')
    return move

def move_up( orient=True):
    def move():
        enabled_objs = filter(lambda x: not is_axis.match(x), cmd.get_names("objects",enabled_only=1))
        all_objs = filter(lambda x: not is_axis.match(x), cmd.get_names("objects",enabled_only=0))
        for obj in enabled_objs:
            cmd.disable(obj)
            last_obj=obj
            for i in range(0,len(all_objs)):
                if all_objs[i] == obj:
                    if i-1 < 0:
                        cmd.enable( all_objs[-1] )
                    else:
                        cmd.enable( all_objs[i-1] )
        if not has_enabled_axis:
            if(orient):
                cmd.zoom('visible')
                cmd.orient()
        cmd.zoom('visible')
    return move

cmd.set_key('pgup', move_up() )
cmd.set_key('pgdn', move_down() )
cmd.set_key('CTRL-pgup', move_up(0) )
cmd.set_key('CTRL-pgdn', move_down(0) )
#cmd.set_key('up', move_up)
#cmd.set_key('down', move_down)
#cmd.set_key('left', move_up)
#cmd.set_key('right', move_down)

