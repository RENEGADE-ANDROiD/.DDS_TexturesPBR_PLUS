rlassets instructions
------------------------------------------------------------------------------------------------------------------------
DO ONCE:

Install Python: https://www.python.org/downloads/

Once Python is installed, inside a command prompt window run the following:

	pip install omgifol

	pip install Pillow

	pip install pypng

Unzip/export the file rlassets\rlassets.py from Relighting to a new folder. Copy files to extract sprites from to the same folder. It isn't necessary to copy your game wad or pk3 file to this folder, but in doing so you don't have to pass the entire path on the command line.

------------------------------------------------------------------------------------------------------------------------
EXTRACT AND CREATE ASSETS

Inside a command prompt window run the following: python rlassets.py {wadfile/pk3} [{wadfile/pk3}...] [{blur}]

Examples:

python rlassets.py DOOM2.WAD

python rlassets.py HERETIC.WAD 3

python rlassets.py DOOM2.WAD brutaldoomv21.pk3


When that completes move crosswalk.zs and initsprites.zs from the sprites folder to Relighting root, overwriting those already there. Copy the remainder of the sprites folder to the Relighting root folder.

Depending on the game or mod, you may see GZDoom errors about missing frames, which means those sprite graphics are incomplete. You'll need to edit the file initsprites.zs and delete or comment out (precede with //) those lines referencing those sprites.

