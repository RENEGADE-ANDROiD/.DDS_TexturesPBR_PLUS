# get-assets.py

######################################################################################################################
# environment
from omg import *
from PIL import ImageFile, ImageFilter
import subprocess
import zipfile
import tempfile
import re
import os
import random
import string
import sys
import png
import struct
import time
startTime = time.time()

ImageFile.LOAD_TRUNCATED_IMAGES = True

if not os.path.exists('temp'):
    os.mkdir('temp')
if not os.path.exists('sprites'):
    os.mkdir('sprites')


######################################################################################################################
# variables
sbase = []
sswap = []
offsets = []

blur = 1

######################################################################################################################
# functions

# extract images from a PK3 file
def getzipsprites(fname):
    zip = zipfile.ZipFile(fname)
    ziplist = zip.namelist()
    sprites = [x for x in ziplist if re.match('SPRITES.*\/.*\.PNG', x, re.IGNORECASE)]
    for s in sprites:
        if "WEAPONS" in s or "PLAYER" in s:
            continue
        img = zip.read(s)
        with open('temp\{0}'.format(os.path.basename(s)), 'wb') as f:
            f.write(img)
    zip.close()

# get base names and offsets
def getbasedata(fname = None):
    scheck = "ZZZZ"
    if fname is None:
        list = sorted(os.listdir('temp'))
    else:
        wad = WAD(fname)
        list = wad.sprites
    for s in list:
        sucase = s.upper()
        if not re.match('[A-Z0-9]{6}', sucase[:6]):
            print('{0} not a valid frame, ignored'.format(sucase))
            continue
        if fname is None:
            img = png.Reader(filename='{0}\{1}'.format('temp',s))
            while True:
                try:
                    chunk = img.chunk(lenient=True)
                    if str(chunk[0], 'utf-8') == 'grAb':
                        offsets.append({
                            "sprite" : sucase,
                            "x" : chunk[1][3],
                            "y" : chunk[1][7]
                        })
                        break
                except Exception as e:
                    print(sucase, str(chunk[0], 'utf-8'), e)
                    break
        else:
            offsets.append({
                "sprite" : sucase,
                "x" : wad.sprites[s].x_offset,
                "y" : wad.sprites[s].y_offset,
            })
        print(offsets[len(offsets)-1])
        if sucase[:4] != scheck:
            scheck = sucase[:4]
            sbase.append(sucase[:4])

# get unique swap names
def getswapnames():
    for s in sbase:
        while True:
            f = '{0}{1}'.format(random.choice(string.ascii_uppercase), s[1:])
            if f not in sbase and f not in sswap:
                sswap.append(f)
                break

# blur and save sprites
def blurandsavesprites(fname = None):
    if fname is None:
        list = sorted(os.listdir('temp'))
    else:
        wad = WAD(fname)
        list = wad.sprites
    for s in list:
        sucase = s.upper()
        if not re.match('[A-Z0-9]{6}', sucase[:6]):
            print('{0} not a valid frame, ignored'.format(sucase))
            continue
        for i in range(0, len(offsets)):
            if offsets[i]['sprite'] == s.upper():
                x_offset = offsets[i]['x']
                y_offset = offsets[i]['y']

        if fname is None:
            try:
                img = Image.open('{0}\{1}'.format('temp',s))
                img = img.convert('RGBA')
            except Exception as e:
                print(e)
                continue
        else:
            img = wad.sprites[s].to_Image('RGBA')

        if '.PNG' not in s.upper():
            pngname = '{0}.png'.format(s.upper())
        else:
            pngname = s

        try:
            img_blurred = img.filter(ImageFilter.GaussianBlur(radius=blur))
            f = 'sprites\{0}'.format(pngname.replace(pngname[:4], sswap[sbase.index(pngname[:4])]))
            print(s, f)
            img_blurred.save(f)

            # insert grAb chunk
            grAb = [b'grAb', struct.pack(">II", abs(x_offset), abs(y_offset))]
            reader = png.Reader(f)
            chunks = [*reader.chunks()]
            chunks.insert(1, grAb)
            with open(f, 'wb') as file:
                png.write_chunks(file, chunks)

        except Exception as e:
            print(s, e)
            continue

# write hd_crosswalk.zs
def writecrosswalk():
    with open('hd_crosswalk.zs', 'w') as f:
        f.write('class crosswalk\n')
        f.write('{\n')
        f.write('   Array<string> sbase;\n')
        f.write('   Array<string> sswap;\n')
        f.write('   crosswalk init()\n')
        f.write('   {\n')

        for i in range(0, len(sbase)):
            f.write('      self.sbase.Push("' + sbase[i] + '"); self.sswap.Push("' + sswap[i] + '");')
            if i % 5 == 0:
                f.write('\n')

        f.write('\n')
        f.write('       return self;\n')
        f.write('   }\n')
        f.write('   string getswap(string s)\n')
        f.write('   {\n')
        f.write('       if (self.sbase.Find(s) != self.sbase.size())\n')
        f.write('       {\n')
        f.write('           return self.sswap[self.sbase.Find(s)];\n')
        f.write('       }\n')
        f.write('       else\n')
        f.write('       {\n')
        f.write('           return "NOTFOUND";\n')
        f.write('       }\n')
        f.write('   }\n')
        f.write('}\n')

def writeinitsprites():
    with open('hd_initsprites.zs', 'w') as f:
        f.write('class Blurred_Assets: Actor')
        f.write('{\n')
        f.write('   States\n')
        f.write('   {\n')
        f.write('   Spawn:\n')
        for i in range(0, len(sbase)):
            try:
                f.write('       {0} A 1;\n'.format(sswap[i]))
            except Exception as e:
                print(e)
                continue
        f.write('   }\n')
        f.write('}\n')
        f.write('\n')

# update zip file
def updateZip(zipname, filename, newfilename):
    # create temp file
    tmpfd, tmpname = tempfile.mkstemp(dir=os.path.dirname(zipname))
    os.close(tmpfd)

    # create a temp copy of the archive without filename            
    with zipfile.ZipFile(zipname, 'r') as zin:
        with zipfile.ZipFile(tmpname, 'w') as zout:
            zout.comment = zin.comment # preserve the comment
            for item in zin.infolist():
                if item.filename != filename:
                    zout.writestr(item, zin.read(item.filename))

    # replace with the temp archive
    os.remove(zipname)
    os.rename(tmpname, zipname)

    # now add revised filename
    with zipfile.ZipFile(zipname, mode='a', compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(filename)

######################################################################################################################
# help

def help():
    return """
______        _      _  _          
| ___ \      | |    (_)| |         
| |_/ /  ___ | |     _ | |_   ___  
|    /  / _ \| |    | || __| / _ \\
| |\ \ |  __/| |____| || |_ |  __/ 
\_| \_| \___|\_____/|_| \__| \___| 

Instructions for building shadow assets. 
Recommended Usage: python rlassets.py -i {wadfile/pk3} [{wadfile/pk3}...] [{blur}] [-o] [{pk3}] [-m] [{pk3}]
-i    follow with one or more sprite source file name(s). 
-o    (optional) follow with name of output file to be run with ReLite. 
-m    (optional) follow with the ReLite source file to be modified. 
Notes 
1. If you choose not to include -o, then the sprites directory has to be zipped to a pk3 OR added to the mod root. 
2. If you choose not to include -m, then hd_initsprites.zs & hd_crosswalk.zs have to be added to the mod root.
3. If you see GZDoom errors about missing frames, edit hd_initsprites.zs to delete or comment out lines referencing the sprite.
"""

######################################################################################################################
# main

if len(sys.argv) == 1:
    print(help())
    exit()

# parse command line
bin = False
infiles = []
bout = False
outfile = ''
bmod = False
modfile = ''
for i in range(1, len(sys.argv)):
    arg = sys.argv[i].upper()
    argo = sys.argv[i]
    if arg in ['-I','-O','-M']:
        bin = arg == '-I'
        bout = arg == '-O'
        bmod = arg == '-M'
        continue
    if bin:
        if arg[-4:] in ['.PK3','.ZIP','.WAD']:
            infiles.append(arg)
        else:
            try:
                blur = float(arg)
            except:
                print('Unknown argument {0}'.format(arg))
    if bout:
        if arg[-4:] == '.PK3':
            outfile = argo

    if bmod:
        if arg[-4:] == '.PK3':
            modfile = argo


if len(infiles) == 0:
    print('Usage: python rlassets.py -i {wadfile/pk3} [{wadfile/pk3}...] [{blur}] [-o] [{pk3}] [-m] [{pk3}]')
    exit()

# extract sprites from input files
for f in infiles:
    if f[-4:] in ['.PK3','.ZIP']:
        getzipsprites(f)
        getbasedata()
    elif f[-4:] == '.WAD':
        getbasedata(f)

getswapnames()

# blur the sprites
for f in infiles:
    if f[-4:] in ['.PK3','.ZIP']:
        blurandsavesprites()
    elif f[-4:] == '.WAD':
        blurandsavesprites(f)

writeinitsprites()
writecrosswalk()

# create pk3 of blurred sprites
if outfile != '':
    with zipfile.ZipFile(outfile, 'w') as zipf:
        for root, dirs, files in os.walk('sprites'):
            for file in files:
                zipf.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), os.path.join('sprites', '..')))

# update mod file
if modfile != '':
    updateZip(modfile, 'hd_crosswalk.zs', 'hd_crosswalk.zs')
    updateZip(modfile, 'hd_initsprites.zs', 'hd_initsprites.zs')

runtime = time.time() - startTime
print('Completed in {0} seconds'.format(runtime))

exit()

