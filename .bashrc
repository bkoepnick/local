#Set $PATH and environment variables to use Fink
#source /sw/bin/init.sh

export PS1="[ \d \t \h:\W ] $ "
export CLICOLOR=1
#export LSCOLORS=exfxcxdxbxegedabagacad

export HISTSIZE=1000
export HISTFILESIZE=10000

export PATH=".:/usr/local/git/:/Users/koepnick/scripts/:$PATH"

alias game_static_sh="/Users/koepnick/rosetta_local/interactive/source/xcode_4/DerivedData/rosetta-interactive/Build/Products/Release/game_static_sh \
	-database /Users/koepnick/rosetta_local/interactive/database \
	-resources /Users/koepnick/rosetta_local/interactive/resources"

alias foldit="/Users/koepnick/rosetta_local/interactive/source/xcode_4/DerivedData/rosetta-interactive/Build/Products/Release/game_static.app/Contents/MacOS/game_static \
	-interactive_game novice \
	-dont_update -dont_quickstart \
	-resources resources -database database"

MAMEPATH="/Users/koepnick/things/mame/"
alias mame="$MAMEPATH/mame64 \
	-rp $MAMEPATH/roms \
	-sp $MAMEPATH/samples \
	-artpath $MAMEPATH/artwork \
	-ctrlrpath $MAMEPATH/ctrlr \
	-inipath $MAMEPATH \
	-fontpath $MAMEPATH \
	-cfg_directory $MAMEPATH/cfg \
	-state_directory $MAMEPATH/sta \
	-autosave"

export PYTHONPATH=".:/usr/lib:/opt/local/Library/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages/:/Users/koepnick/rosetta_local/lib/:/Users/koepnick/scripts/javier_pymol_scripts/:$PYTHONPATH"

export ROSETTA_INTERACTIVE_PATH="/Users/koepnick/rosetta_local/interactive/"

function title() {
    echo -ne "\033]0;"$*"\007"
}

function newdir() {
	DIR=$1; 
	mkdir ${DIR}; cd ${DIR};
}

function fetch_pdb() {
	PDB=$1;
	curl -O http://www.rcsb.org/pdb/files/$1.pdb
}
