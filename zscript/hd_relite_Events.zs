class EndCam : SecurityCamera
{
	Default
	{
		Radius 128;
		CameraHeight 0;
	}
}

class hd_relite_Events : EventHandler
{
	mixin mGeo;
	mixin mColor;
	crosswalk cwalk;
	int rotimer;
	string info;

override void NetworkProcess(ConsoleEvent e)
{
    let pmo = players[consoleplayer].mo;
    if (e.Name == "ReLiteOn" || e.Name == "ReLiteOff")
    {
        // Find the EventHandler instance
        let reLiteHandler = hd_relite_Events(EventHandler.Find("hd_relite_Events"));
        if (reLiteHandler)
        {
            if (e.Name == "ReLiteOn")
            {
                console.printf("ReLite Enabled");
                reLiteHandler.IsReLiteOn = true;
            }
            else
            {
                console.printf("ReLite Disabled");
                reLiteHandler.IsReLiteOn = false;
            }
        }
    }
}

bool IsReLiteOn;  // Now this is an instance variable

	override void WorldLoaded(WorldEvent e)
	{
		rotimer = 0;
		find_pnames("TEXTURE1", 0, 0);
		// cvars used in this event handler
		get_globals();
		readgldefs();
		// average back sector lighting with a bias to dark
		if (CVar.FindCvar("rl_bias").GetBool()) bias_lighting();
		// common structures
		build_hd_sectors();
		build_hd_grid();
		if (CVar.FindCvar("rl_platform").GetBool() && !CVar.FindCvar("rl_performance").GetBool()) add_platform_lights();
		// based on data lumps analyze colors
		find_palette();
		find_textures();
		find_texture_colors();
		find_texture_color_lux();
		find_flats();
		find_flat_colors();
		find_flat_color_lux();
		// add lights
		if (CVar.FindCvar("rl_flat").GetFloat() > 0) add_flatlights();
		if (CVar.FindCvar("rl_decorative").GetFloat() > 0) add_decorativelights();
		if (CVar.FindCvar("rl_texture").GetFloat() > 0) add_texturelights();
		if (CVar.FindCvar("rl_window").GetBool()) add_windowlights();
		add_outsidelights();
		if (CVar.FindCvar("rl_morelights").GetBool()) add_morelights();
		smooth_lights();
		// for Quake-style end cam
		placeCameras();
		// add reflections
		if (CVar.FindCvar("rl_ceilreflections").GetBool() && !CVar.FindCvar("rl_performance").GetBool())
		{
			if (reflection_tag_OK(Sector.Ceiling))
			{
				Sector_SetPlaneReflection(CVar.FindCvar("rl_ceil_tag").GetInt(), 0, CVar.FindCvar("rl_ceilstrength").GetInt());
			}
			else
			{
				info = "ceiling tag not unique and needs to be changed";
			}
		}
		if (CVar.FindCvar("rl_floorreflections").GetBool() && !CVar.FindCvar("rl_performance").GetBool())
		{
			if (reflection_tag_OK(Sector.Floor))
			{
				Sector_SetPlaneReflection(CVar.FindCvar("rl_floor_tag").GetInt(), CVar.FindCvar("rl_floorstrength").GetInt(), 0);
			}
			else
			{
				info = "floor tag not unique and needs to be changed";
			}
		}
	}
	bool reflection_tag_OK(int dir)
	{
		Texman texture;
		string flatcheck = "|";

		if (dir == Sector.Ceiling)
		{
			Array<string> cvars = {"rl_ceil1","rl_ceil2","rl_ceil3","rl_ceil4","rl_ceil5","rl_ceil6","rl_ceil7","rl_ceil8","rl_ceil9","rl_ceil10"};
			foreach (s: cvars) flatcheck = String.Format("%s%s|",flatcheck,CVar.FindCvar(s).GetString());
		}
		else
		{
			Array <string> cvars = {"rl_floor1","rl_floor2","rl_floor3","rl_floor4","rl_floor5","rl_floor6","rl_floor7","rl_floor8","rl_floor9","rl_floor10"};
			foreach (s: cvars) flatcheck = String.Format("%s%s|",flatcheck,CVar.FindCvar(s).GetString());
		}
		int tag = dir == Sector.Ceiling ? CVar.FindCvar("rl_ceil_tag").GetInt() : CVar.FindCvar("rl_floor_tag").GetInt();
		// make sure that all tagged sectors have reflective floors
		let it = LevelLocals.CreateSectorTagIterator(tag);
		int secnum;
		while ((secnum = it.Next()) != -1) if (flatcheck.IndexOf(String.Format("|%s|",texture.GetName(Level.Sectors[secnum].GetTexture(dir)))) == -1) return false;
		return true;
	}
	override void WorldThingSpawned(WorldEvent e)
	{
		if (!e.thing || !rl_shadows) return;

		string cname = e.thing.GetClassName();
		cname = cname.MakeUpper();
		if (e.thing == players[consoleplayer].mo || e.thing.Alpha < 0.75 || cname.IndexOf("HD_") != -1 || cname.IndexOf("FAKE") == 0) return;

		Texman texture;
		string sname = texture.GetName(e.thing.CurState.GetSpriteTexture(0));
		int sprite_height = texture.CheckRealHeight(e.thing.CurState.GetSpriteTexture(0));

		if (cname == "FLASHLIGHTPLUSLIGHT" || (e.thing.bMissile && e.thing.Height >= 8 && e.thing.Damage && (sname != "" && sname != "TNT1A0")))
		{
			e.thing.A_GiveInventory("hd_flashlight", 1);
			return;
		}
		if ((sprite_height < 10 && !(e.thing is "Inventory")) || sname == "" || sname == "TNT1A0" || e.thing.bNoBlockMap || e.thing.bNoClip || e.thing.bInvisible || e.thing.bThruActors) return;
		e.thing.bCastSpriteShadow = false;
		e.thing.A_GiveInventory("hd_shade", 1);
	}

	Array<int> TxTy;
	Array<string> TxTy_flat;
	override void WorldLineActivated(WorldEvent e)
	{
		Line lin = e.ActivatedLine;

if (rl_debug) console.printf("lin %i special %i tag %i %i %i %i %i", lin.index(), lin.special, lin.args[0], lin.args[1], lin.args[2], lin.args[3], lin.args[4] );

		if ((lin.special == 241 ||  lin.special == 242) && lin.args[0] > 0) // lower to lowest and transfer floor texture
		{
			Texman texture;
			let it = LevelLocals.CreateSectorTagIterator(lin.args[0]);
			int secnum;
			while ((secnum = it.Next()) != -1)
			{
				TxTy.Push(secnum);
				TxTy_flat.Push(texture.GetName(Level.Sectors[secnum].GetTexture(Sector.Floor)));
			}
		}
	}

	override void WorldTick()
	{
		if (CVar.FindCvar("rl_restart").GetBool())
		{
			CVar.FindCvar("rl_restart").ResetToDefault();
			ACS_NamedExecuteWithResult("restart", 0);
		}
		if (rotimer < 300) rotimer++;
		// check for sectors affected by line specials
		Texman texture;
		for (int i = 0; i < TxTy.Size(); i++)
		{
			Sector sec = Level.Sectors[TxTy[i]];
			string flat = TxTy_flat[i];
			string newflat = texture.GetName(sec.GetTexture(Sector.Floor));
			if (flat != newflat)
			{
				foreach (lin: sec.Lines)
				{
					if (lin.Flags & Line.ML_TWOSIDED)
					{
						Sector bsec = backSector(sec, lin);
						if (bsec)
						{
							if (newflat == texture.GetName(bsec.GetTexture(Sector.Floor)))
							{
								sec.SetPlaneLight(Sector.Floor, bsec.GetFloorLight());
								sec.SetColor(bsec.ColorMap.LightColor);
								TxTy.Delete(i);
								TxTy_flat.Delete(i);
								break;
							}
						}
					}
				}
			}
		}
		bool ec_enabled = CVar.FindCvar("ec_enabled").GetBool();
		int tid = ACS_NamedExecuteWithResult("getcameratid", 0);
		bool bEndCam = camtid.Size() > 1 ? (tid == camtid[0] || tid == camtid[1]) : camtid.Size() == 1 ? (tid == camtid[0]) : false;
		if (bEndCam && endlevel && ec_enabled)
		{
			endlevel = false;
			// spawn camera at exit point at 180 degree offset
			vector3 p3 = (player.mo.pos.x, player.mo.pos.y, player.mo.pos.z + player.mo.height + 16);
			int exittid = ACS_NamedExecuteWithResult("gettid");
			if (addCamera(p3, exittid, 180.0))
			{
				camtid.Push(exittid);
				player.mo.ACS_NamedExecuteAlways("settid", 0, exittid);
			}
			vector3 v3 = (hd_map_grid.maxx + 10, hd_map_grid.maxy + 10, 0);
			player.mo.SetOrigin(v3, false);
			if (tid == camtid[0])
			{
				player.mo.ACS_NamedExecute("showstats", 0, 0);
			}
			else
			{
				player.mo.ACS_NamedExecute("showstats", 0, 1);
			}
		}
	}

/****************************************************************************************************************************/
// cvars - only used during setup

	double rl_additive, rl_saturation;
	int rl_perceived, rl_howred, rl_howgreen, rl_howblue;
	bool rl_shadows, rl_debug;
	void get_globals()
	{
		if (CVar.FindCvar("reset").GetBool())
		{
			Array<string> cvars = { "ec_enabled", "ec_intermissions", "ec_chance", "rl_shadows" , "rl_bias", "rl_darken", "rl_brighten", "rl_decorative", "rl_texture", "rl_flat", "rl_ceiling_grid","rl_platform","rl_window","rl_eave",
				"rl_fluid","rl_maxlight", "rl_morelights","rl_area","rl_length","rl_performance","rl_color_sec","rl_color_spr","rl_color_txt", "rl_color_val","rl_palette_shade", "rl_palette_sat", "rl_additive", "rl_saturation", "rl_shader","rl_bleeding","rl_ceilreflections",
				"rl_ceil_tag","rl_ceilstrength","rl_floorreflections","rl_floor_tag","rl_floorstrength","rl_perceived", "rl_howred", "rl_howgreen", "rl_howblue", "reset", "rl_restart","rl_debug"};
			foreach (s: cvars) Cvar.FindCvar(s).ResetToDefault();
		}
		rl_shadows = CVar.FindCvar("rl_shadows").GetBool(); rl_debug = CVar.FindCvar("rl_debug").GetBool();
		rl_additive =  CVar.FindCvar("rl_additive").GetFloat(); rl_saturation =  CVar.FindCvar("rl_saturation").GetFloat();
		rl_perceived = CVar.FindCvar("rl_perceived").GetInt(); rl_howred = CVar.FindCvar("rl_howred").GetInt(); rl_howgreen = CVar.FindCvar("rl_howgreen").GetInt(); rl_howblue = CVar.FindCvar("rl_howblue").GetInt();
	}

/****************************************************************************************************************************/
// common structures

	Array<Sector> bias;
	void bias_lighting()
	{
		double rl_darken = CVar.FindCvar("rl_darken").GetFloat();
		double rl_brighten = CVar.FindCvar("rl_brighten").GetFloat();
		foreach (sec: Level.Sectors)
		{
			if (bias.Find(sec) != bias.Size())  continue;
			foreach (lin: sec.Lines)
			{
				if (lin.Flags & Line.ML_TWOSIDED)
				{
					Sector bsec = backSector(sec, lin);
					if (bsec && (bias.Find(bsec) == bias.Size()))
					{
						vector2 v2 = GetMiddle(lin);
						double diff = abs(sec.FloorPlane.ZAtPoint(v2) - bsec.FloorPlane.ZAtPoint(v2));
						if (diff < 96.0)
						{
							bias.Push(bsec);
							if (bsec.LightLevel != sec.LightLevel) bsec.LightLevel = int((bsec.LightLevel + sec.LightLevel) * (bsec.LightLevel > sec.LightLevel ? rl_darken : bsec.LightLevel < sec.LightLevel ? rl_brighten : 0.5));
						}
					}
				}
			}
		}
	}

	Array<hd_sector> hd_sectors;
	void build_hd_sectors()
	{
		Texman texture;
		// build sector structures
		foreach (sec: Level.Sectors)
		{
			if (sec.Lines.Size() < 3) continue;
			hd_sector hd = new ("hd_sector").init(sec);
			if (!hd.special) sec.SetPlaneLight(Sector.Floor, -int(sec.LightLevel * (1 -  rl_additive) * 0.2));
			if (!hd.special) sec.SetPlaneLight(Sector.Ceiling, -int(sec.LightLevel * (1.0 - rl_additive) * 0.2));
			if (!hd.special) sec.LightLevel = clamp(sec.LightLevel  - int(sec.LightLevel * rl_additive), 0, 255);
			int wlight = int(sec.LightLevel * rl_additive);
			foreach (lin: sec.Lines)
			{
				int fside = (lin.FrontSector != sec) ? Line.Back : Line.Front;
				Side wall = lin.Sidedef[fside];
				int i = 0;
				foreach (sid: stype)
				{
					string t = texture.GetName(wall.GetTexture(sid));
					i += t == "" ? 0 : 1;
				}
				if (i == 0) continue;
				wall.flags = wall.flags | Side.WALLF_SMOOTHLIGHTING | Side.WALLF_NOFAKECONTRAST;
				wall.Light -= wlight;
			}
			if (hd.area > 0) hd_sectors.Push(hd);
		}
	}

	hd_grid hd_map_grid;
	void build_hd_grid()
	{
		double minx = double.infinity, miny = double.infinity, maxx = -double.infinity, maxy = -double.infinity;
		foreach (sec: hd_sectors)
		{
			minx = min(minx, sec.minx); miny = min(miny, sec.miny); 
			maxx = max(maxx, sec.maxx); maxy = max(maxy, sec.maxy); 
		}
		hd_map_grid = new ("hd_grid").init(minx, miny, maxx, maxy);
	}

	Array <int> moving;
	void add_platform_lights()
	{
		Array<int> doors = { 11, 12, 13, 105, 202 };
		Array<int> platforms = { 60, 61, 62, 63, 64, 65, 172, 203, 206, 207 };
		Array<int> sec_nums;
		Array<int> types;
		foreach (lin : Level.Lines)
		{
			int type = doors.Find(lin.special) != doors.Size() ? 1 : platforms.Find(lin.special) != platforms.Size() ? 2 : 0;
			if (type != 0)
			{
				int sec_num;
				if (lin.Args[0] == 0)
				{
					Sector bsec = lin.BackSector;
					if (bsec)
					{
						sec_num = bsec.SectorNum;
						if (sec_nums.Find(sec_num) == sec_nums.Size())
						{
							types.Push(type);
							sec_nums.Push(sec_num);
							moving.Push(sec_num);
						}
					}
				}
				else
				{
					let it = LevelLocals.CreateSectorTagIterator(lin.Args[0]);
					while (sec_num = it.Next())
					{
						if (sec_num == -1) break;
						if (sec_nums.Find(sec_num) == sec_nums.Size())
						{
							types.Push(type);
							sec_nums.Push(sec_num);
							moving.Push(sec_num);
						}
					}
				}
			}
		}
		foreach (sec: hd_sectors)
		{
			int index = sec_nums.Find(sec.sec);
			if (index != sec_nums.Size())
			{
				Sector ssec = Level.Sectors[sec.sec];
				Actor p = Actor.Spawn("hd_platform", (sec.cspot.x, sec.cspot.y, ssec.FloorPlane.ZAtPoint(sec.cspot)));
				if (p) p.args[0] = types[index];
			}
		}
	}

/****************************************************************************************************************************/
// adding cameras
	PlayerInfo player;
	Actor cam;
	int playertid;
	bool endlevel;
	vector3 camHook;
	Array <Actor> cameras;
	Array<int> camtid;

	bool addCamera(vector3 v3, int tid, double offset = 0.0)
	{
		bool ec_enabled = CVar.FindCvar("ec_enabled").GetBool();
		if (ec_enabled)
		{
			cam = Actor.Spawn("EndCam", v3);
			if (!cam) return false;
			// check existing cameras
			for (int i = 0; i < cameras.Size(); i++)
			{
				if (cam.CheckSight(cameras[i]) || cam.Distance2D(cameras[i]) < 512)
				{
					cam.A_Remove(AAPTR_DEFAULT);
					return false;
				}
			}
			cam.args[0] = 15;
			cam.args[1] = 180;
			cam.args[2] = 150;
			cam.ChangeTid(tid);
			cam.angle += offset;
			cameras.Push(cam);
			return true;
		}
		else
		{
			return false;
		}
	}

	void placeCameras()
	{
		bool ec_enabled = CVar.FindCvar("ec_enabled").GetBool();
		int ec_chance = CVar.FindCvar("ec_chance").GetInt();
		if (!ec_enabled) return;
		// try to ignore end of episode levels
		string nextmap = Level.NextMap.MakeUpper();
		If (nextmap != "ENDGAME1" && nextmap != "ENDGAME2" && nextmap != "ENDBUNNY" && nextmap != "ENDGAME4"  && nextmap != "ENDGAMEC"
		&& nextmap != "SCREDIT" && nextmap.IndexOf("ENDSEQ") == -1 )
		{
			// every map has a player start
			vector3 v3;
			int i;
			[v3, i] = Level.PickPlayerStart(1);
			int tid = ACS_NamedExecuteWithResult("gettid");
			if (addCamera((v3.x, v3.y, v3.z + player.mo.height + 16), tid))
			{
				camtid.Push(tid);
				player.mo.ACS_NamedExecuteAlways("settid", 0, tid);
			}
			ThinkerIterator Camera_PointFinder;
			Camera_PointFinder = ThinkerIterator.Create("Actor");
			Actor campoint;
			while (campoint = Actor(Camera_PointFinder.Next()))
			{
				if (campoint.bSolid && campoint.ceilingZ - campoint.height > 16 && Random(1,10) <= ec_chance)
				{
					vector3 v3 = (campoint.pos.x, campoint.pos.y, campoint.floorZ + campoint.height + 16);
					int tid = ACS_NamedExecuteWithResult("gettid");
					if (addCamera(v3, tid))
					{
						camtid.Push(tid);
						player.mo.ACS_NamedExecuteAlways("settid", 0, tid);
					}
					if (camtid.Size() == 4) break;
				}
			}
			foreach (s : Level.Sectors)
			{
				foreach (l : s.Lines)
				{
					if (l.Special == 243)
					{
						l.Special = 237;
						l.args[0] = camtid[0];
						l.args[1] = 1;
						l.args[2] = 0;
					}
					if (l.Special == 244)
					{
						l.Special = 237;
						l.args[0] = camtid.Size() == 1 ? camtid[0] : camtid[1];
						l.args[1] = 1;
						l.args[2] = 0;
					}
				}
			}
		}
	}
	void setPlayer(PlayerEvent e)
	{
		player = players[e.PlayerNumber];
		endlevel = true;
		playertid = ACS_NamedExecuteWithResult("gettid");
		player.mo.ChangeTid(playertid);
	}
	void set_shader()
	{
		PPShader.SetEnabled("hd_shader", CVar.FindCvar("rl_shader").GetBool());
		PPShader.SetUniform1f("hd_shader", "rl_bleeding", CVar.FindCvar("rl_bleeding").GetFloat());
	}

	override void PlayerRespawned(PlayerEvent e)
	{
		setPlayer(e);
		set_shader();
	}
	override void PlayerSpawned(PlayerEvent e)
	{
		setPlayer(e);
		cwalk = new ("crosswalk").init();
		Texman texture;
		string sname = texture.GetName(players[consoleplayer].mo.CurState.GetSpriteTexture(0));
		if (CVar.FindCvar("rl_shadows").GetBool())
		{
			players[consoleplayer].mo.A_GiveInventory("hd_shade", 1);
			Actor ptr = players[consoleplayer].mo.FindInventory("hd_shade");
			if (ptr) ptr.PostBeginPlay();
		}
		set_shader();
	}
	override void WorldUnLoaded(WorldEvent e)
	{
		PPShader.SetEnabled("hd_shader", false);
	}

/****************************************************************************************************************************/
// adding patches
    Array<string> tnames;
    Array<string> pnames;
	void find_pnames(string fname, int fstart, int pstart)
	{
		int bptr = 0;
		int fhnd = Wads.FindLump(fname, fstart, Wads.ANYNAMESPACE);
		int phnd = Wads.FindLump("PNAMES", pstart, Wads.ANYNAMESPACE);
		if (fhnd == -1) return;
		string flump = Wads.ReadLump(fhnd);
		string plump = Wads.ReadLump(phnd);
		int num_textures = int(flump.ByteAt(bptr++) & 255)  + int((flump.ByteAt(bptr++) & 255) << 8) + int((flump.ByteAt(bptr++) & 255) << 16) + int((flump.ByteAt(bptr++) & 255) << 24);
		for (int i=0; i < num_textures; i++)
		{
			int offset = int(flump.ByteAt(bptr++) & 255)  + int((flump.ByteAt(bptr++) & 255) << 8) + int((flump.ByteAt(bptr++) & 255) << 16) + int((flump.ByteAt(bptr++) & 255) << 24);
			string text = String.Format("%c%c%c%c%c%c%c%c", int(flump.ByteAt(offset++)), int(flump.ByteAt(offset++)), int(flump.ByteAt(offset++)), int(flump.ByteAt(offset++)), int(flump.ByteAt(offset++)), int(flump.ByteAt(offset++)), int(flump.ByteAt(offset++)), int(flump.ByteAt(offset++)));
			tnames.Push(text);
			offset += 12;
			int num_patches = int(flump.ByteAt(offset++) & 255)  + int((flump.ByteAt(offset++) & 255) << 8);
			string patches = "";
			for (int ii=0; ii < num_patches; ii++)
			{
				offset += 4;
				int patch_num = int(flump.ByteAt(offset++) & 255)  + int((flump.ByteAt(offset++) & 255) << 8);
				offset += 4;
				int pptr = patch_num * 8 + 4;
				string patch = String.Format("%c%c%c%c%c%c%c%c", int(plump.ByteAt(pptr++)), int(plump.ByteAt(pptr++)), int(plump.ByteAt(pptr++)), int(plump.ByteAt(pptr++)), int(plump.ByteAt(pptr++)), int(plump.ByteAt(pptr++)), int(plump.ByteAt(pptr++)), int(plump.ByteAt(pptr++)));
				patches = patches == "" ? patch : String.Format("%s,%s", patches, patch);
			}
			pnames.Push(patches);
		}
		if (fname == "TEXTURE1")
		{
			find_pnames("TEXTURE2", fhnd + 1, phnd);
		}
		else
		{
			find_pnames("TEXTURE1", fhnd + 1, phnd + 1);
		}
	}

/****************************************************************************************************************************/
// adding color
	Array<color> palette;
	void find_palette()
	{
		double rl_palette_shade = CVar.FindCvar("rl_palette_shade").GetFloat();
		double rl_palette_sat = CVar.FindCvar("rl_palette_sat").GetFloat();
		string flump = Wads.ReadLump(Wads.CheckNumForName("PLAYPAL", Wads.NS_GLOBAL));
		for (int i = 0; i < 768; i += 3)
		{
			color c = Color(flump.ByteAt(i), flump.ByteAt(i + 1), flump.ByteAt(i + 2));
			palette.Push(saturate(shade(c, rl_palette_shade), rl_palette_sat));
		}
	}

/****************************************************************************************************************************/
// helper functions
int, int getwd(string s)
{
		Texman texture;
		textureid textid;
		textid = texture.CheckForTexture(s, Texman.TYPE_WALL);
		int width, height;
		[width, height] = texture.GetSize(textid);
		return width, height;
}

/****************************************************************************************************************************/
// adding textures
	Array<string> textures;
	Array<int> textures_light_size;
	Array<int> textures_x;
	Array<int> textures_y;
	void add_textures(string s)
	{
		if (s != "")
		{
			if (textures.Find(s) == textures.Size())
			{
				int width, height;
				[width, height] = getwd(s);
				textures_light_size.Push(-1);
				textures.Push(s);
				textures_x.Push(int(width * 0.5));
				textures_y.Push(int(height * 0.5));
			}
		}
	}
	static const int stype[] = {Side.Top, Side.Mid, Side.Bottom};
	void find_textures()
	{
		Texman texture;
		textures.Push(texture.GetName(Level.SkyTexture1)); // sky texture is always 0
		textures_light_size.Push(0);
		textures_x.Push(0);
		textures_y.Push(0);
		foreach (sec: hd_sectors)
		{
			foreach (t: sec.textures) add_textures(t);
		}
	}
	double, double, double, double, double get_patch_color(string flump, int pc, int hr, int hg, int hb, bool bsprite = false, int tc = 58, int tr = 70, int tg = 59, int tb = 50)
	{
		int bptr = 0;
		color c, temp;
		int width = int(flump.ByteAt(bptr++) & 255)  + int((flump.ByteAt(bptr++) & 255) << 8) ;
		int height = int(flump.ByteAt(bptr++) & 255)  + int((flump.ByteAt(bptr++) & 255) << 8) ;
		int leftoffset = int(flump.ByteAt(bptr++) & 255)  + int((flump.ByteAt(bptr++) & 255) << 8) ;
		int topoffset = int(flump.ByteAt(bptr++) & 255)  + int((flump.ByteAt(bptr++) & 255) << 8) ;
		Array<int> columnsofs;
		for (int i = 0; i < width; i++) // create column_array with width number of elements
		{
			columnsofs.Push(int(flump.ByteAt(bptr++) & 255)  + int((flump.ByteAt(bptr++) & 255) << 8) + int((flump.ByteAt(bptr++) & 255) << 16) + int((flump.ByteAt(bptr++) & 255) << 24));
		}
		int rowstart, pixel_count, dummy_value;
		double p = 0, n = 0, r = 0, g = 0, b = 0;
		foreach (offset: columnsofs) // seek doom image to column_array[i] from beginning of doom image
		{
			bptr = offset;
			rowstart = 0;
			while (true)
			{
				rowstart = flump.ByteAt(bptr++);
				if (rowstart == 255) break;
				pixel_count = flump.ByteAt(bptr++);
				// only read top 1/3 of decorative light sprite
				if (bsprite && rowstart < (height * 0.2))
				{
					pixel_count = int(pixel_count * 0.2);
				}
				else if (bsprite)
				{
					break;
				}
				dummy_value = flump.ByteAt(bptr++);
				for (int i = 0; i < pixel_count; i++)
				{
					temp = palette[flump.ByteAt(bptr++)];
					double hue, saturation, value;
					[hue, saturation, value] = get_hsv(temp);
					if (value > 30.0)
					{
						bool keep;
						int perceived, howred, howgreen, howblue;
						[keep, perceived, howred, howgreen, howblue] = keepthecolor(temp, pc, hr, hg, hb); //, true);
						if (keep)
						{
							n++; r += temp.r;  g += temp.g; b += temp.b;

//							if (perceived > (rl_perceived + tc) || (howred > tr && howgreen == 0 && howblue == 0) || (howred == 0 && howgreen > tg && howblue == 0) || (howred == 0 && howgreen == 0 && howblue > tb)) p++;

							if ((perceived > (rl_perceived + tc) || (howred > tr && howgreen == 0 && howblue == 0) || (howred == 0 && howgreen > tg && howblue == 0) || (howred == 0 && howgreen == 0 && howblue > tb ))
							&& ((hue < 15 || hue > 25))) p++; // no brown light
						}
					}
				}
				dummy_value = flump.ByteAt(bptr++);
			}
		}
		return p, n, r, g, b;
	}

	Array<color> sprite_colors;
	color get_sprite_color(string flump, int pc, int hr, int hg, int hb)
	{
		int bptr;
		color c, temp;
		double p = 0, n = 0, r = 0, g = 0, b = 0;
		[p, n, r, g, b] = get_patch_color(flump, pc, hr, hg, hb, true);
		if (n > 0) // resample entire patch if not pure or no color
		{
			c = Color(int(clamp(r/n,0,255)), int(clamp(g/n,0,255)), int(clamp(b/n,0,255)));
			int max = max(c.r, max(c.g, c.b));
			if ((max == 0) || (max == c.r && c.g + c.b > c.r) || (max == c.g && c.r + c.b > c.g) || (max == c.b && c.g + c.r > c.b)) [p, n, r, g, b] = get_patch_color(flump, pc, hr, hg, hb, false);
		}
		else
		{
			[p, n, r, g, b] = get_patch_color(flump, pc, hr, hg, hb, false);
		}
		if (n > 0) c = Color(int(clamp(r/n,0,255)), int(clamp(g/n,0,255)), int(clamp(b/n,0,255)));
		return saturate(c, rl_saturation);
	}

	bool isLight(Color c, int width)
	{
		bool blight = ((abs(c.r - c.g) < 8 && abs(c.r - c.b) < 8) && perceived(c) >= rl_perceived);
		double hue, saturation, value;
		[hue, saturation, value] = get_hsv(c);
		bool byellow = hue >= 40 && hue <= 80;
		bool bred = hue >= 350 || hue <= 10;
		bool bgreen = hue >= 100 && hue <= 140; 
		bool bblue = hue >= 220 && hue <= 260; 

if (rl_debug)
{
	if (blight) console.printf("***** is a light");
	if (bred)  console.printf("***** mostly red, val %f", value);
	if (bgreen)  console.printf("***** mostly green, val %f", value);
	if (bblue)  console.printf("***** mostly blue, val %f", value);
	if (byellow)  console.printf("***** mostly yellow, val %f", value);
}

		return (blight || bred || bgreen || bblue || byellow);
	}

	Array<color> texture_colors;
	Array<string> texture_ignore;
	color get_texture_color(string text, int pc, int hr, int hg, int hb)
	{
		double rl_texture = CVar.FindCvar("rl_texture").GetFloat();
		color c, temp;
		string flump;
		c = color(128,128,128);
		double p = 0, n = 0, r = 0, g = 0, b = 0;
		double pp = 0, pn = 0, pr = 0, pg = 0, pb = 0;
		string s;
		int index = tnames.Find(text);
		if (index == tnames.Size())
		{
			console.printf("%s not found", text);
			return color("#ffffff");
		}
		if (texture_ignore.Find(text) != texture_ignore.Size())
		{
			return color("#ffffff");
		}
		// add animated textures
		bool a = anim_texture(text);
		int width, height;
		[width, height] = getwd(text);
		s = pnames[index];
		Array<string> patches;
		s.Split(patches, ",");
		foreach (t: patches)
		{
			flump = Wads.ReadLump(Wads.FindLump(t, 0, Wads.ANYNAMESPACE));
			[pp, pn, pr, pg, pb] = get_patch_color(flump, a ? 64 : pc, hr, hg, hb, tr: (width < 65 ? 30 : 50), tb: (width < 65 ? 11 : 50));
			p += pp; n += pn; r += pr; g += pg; b += pb;
		}
		if (n > 0) c = Color(int(clamp(r/n,0,255)), int(clamp(g/n,0,255)), int(clamp(b/n,0,255)));

if (rl_debug) console.printf("? Texture %s n %f h * w %f p %f r %i g %i b %i", text, n, height * width, p, c.r, c.g, c.b);

		if (n == 0 || (n <= (height * width * .075) && (n != p))) // .05
//		if (n == 0) // .05
		{
if (rl_debug) console.printf("                    IGNORED");
			texture_ignore.Push(text);
		}
		else if (a || (p/n > 0.2 && perceived(c) > int(rl_perceived * 0.2)))
		{
if (rl_debug) console.printf("> Texture %s n %f p %f p/n %f r %i g %i b %i", text, n, p, p/n, c.r, c.g, c.b);

			index = textures.Find(text);
			if (index != textures.Size())
			{

if (rl_debug) console.printf("Texture %s n %f p %f p/n %f wid %i hgt %i size %i r %i g %i b %i pc %i", text, n, p, p/n, width, height, textures_light_size[index], c.r, c.g, c.b, perceived(Color(c.r, c.g, c.b)));

				bool b = (isLight(c, width) && textures_light_size[index] == -1 && height > 16) || index == 0;
				if (b)
				{
					textures_light_size[index] = clamp(int(p/n*rl_texture*(1.0 - rl_additive)), 1, rl_texture);
					if (a) textures_light_size[index] = clamp(int(textures_light_size[index] - textures_light_size[index] * (1.0 - rl_additive)), 1, rl_texture);

if (rl_debug) console.printf("-------------> %s n %f p %f p/n %f wid %i hgt %i size %i r %i g %i b %i pc %i", text, n, p, p/n, width, height, textures_light_size[index], c.r, c.g, c.b, perceived(Color(c.r, c.g, c.b)));
				}
				else
				{
if (rl_debug) console.printf("                    NOT A LIGHT");
				}
			}
		}
		return saturate(c, rl_saturation);
	}
	void find_texture_colors()
	{
		foreach (text: textures) texture_colors.Push(get_texture_color(text, rl_perceived, rl_howred, rl_howgreen, rl_howblue));
	}
	Array<int> texture_color_lux;
	void find_texture_color_lux()
	{
		foreach (c: texture_colors) texture_color_lux.Push(perceived(c));
	}

/****************************************************************************************************************************/
// adding flats
	Array<string> flats;
	Array<int> flats_light_size;
	void add_flats(string s)
	{
		if (s != "")
		{
			if (flats.Find(s) == flats.Size())
			{
				flats_light_size.Push(-1);
				flats.Push(s);
			}
		}
	}
	void find_flats()
	{
		Texman texture;
		int ftype[] = { Sector.ceiling, Sector.floor };
		foreach (sec: hd_sectors) foreach (f: ftype) add_flats(texture.GetName(Level.Sectors[sec.sec].GetTexture(f)));
	}

	bool anim_texture(string text)
	{
		string anim = " BLODGR BLODRIP FIREBLU FIRELAV FIREMAG FIREWALL GSTFONT ROCKRED SLADRIP BFALL SFALL DBRAIN WFALL WLLWTFL WLLLVFL";
		bool b = anim.indexOf(String.Format(" %s ", text)) != -1 || anim.indexOf(String.Format(" %s ", text.Left(text.Length() - 1))) != -1;
		return b;
	}
	bool anim_flat(string f)
	{
		string anim = " NUKAGE FWATER SWATER LAVA BLOOD SLIME0 FLTWAWA FLTSLUD FLTFLWW FLTTELE FLTLAVA FLATHUH ";
		bool b = anim.indexOf(String.Format(" %s ", f.Left(f.Length() - 1))) != -1 || anim.indexOf(String.Format(" %s ", f.Left(f.Length() - 2))) != -1;
		if (!b)
		{
			anim = " RROCK05 RROCK06 RROCK07 RROCK08 ";
			b = anim.indexOf(String.Format(" %s ", f)) != -1;
		}
		return b;
	}

	Array<color> flat_colors;
	color get_flat_color(string f, int pc, int hr, int hg, int hb, int tc = 58, int tr = 50, int tg = 59, int tb = 50)
	{
		double rl_flat = CVar.FindCvar("rl_flat").GetFloat();
		Texman texture;
		textureid textid;
		int len, width, height;
		color c, temp;
		c = color(128,128,128);
		string flump = Wads.ReadLump(Wads.CheckNumForName(f, Wads.NS_FLATS));
		len = flump.Length();
		double p = 0, n = 0, r = 0, g = 0, b = 0;
		for (int i = 0; i < len; i++)
		{
			double hue, saturation, value;
			[hue, saturation, value] = get_hsv(temp);
			temp = palette[flump.ByteAt(i)];
			if (value > 30.0)
			{
				bool keep;
				int perceived, howred, howgreen, howblue;
				[keep, perceived, howred, howgreen, howblue] = keepthecolor(temp, pc, hr, hg, hb);
				if (keep)
				{
					n++; r += temp.r; g += temp.g; b += temp.b;
					if (perceived > (rl_perceived + tc) || (howred > tr && howgreen == 0 && howblue == 0) || (howred == 0 && howgreen > tg && howblue == 0) || (howred == 0 && howgreen == 0 && howblue > tb )) p++;
				}
			}
		}
		if (n > 0) c = Color(int(clamp(r/n,0,255)), int(clamp(g/n,0,255)), int(clamp(b/n,0,255)));

if (rl_debug) console.printf("? Flat %s n %f p %f r %i g %i b %i pc %i", f, n, p, c.r, c.g, c.b, perceived(c));

		bool a = anim_flat(f);
		if (!a && (n < 102 || p == 0))
//		if (!a && p == 0)
		{
if (rl_debug) console.printf("                    IGNORED");
		}
		else if (n > 0 && p> 0)
//		if (n > 0 && p> 0)
		{
			int index = flats.Find(f);
			if (index != flats.Size())
			{
				if (a || isLight(c, 999) || p/n > 0.2)
//				if (a || isLight(c, 999))
				{
					flats_light_size[index] = clamp(int(p/n*rl_flat), min(rl_flat, 2), rl_flat);
if (rl_debug) console.printf("----------> Flat %s n %f p %f p/n %f size %i r %i g %i b %i, pc %i", f, n, p, p/n, int(p/n*rl_flat), c.r, c.g, c.b, perceived(Color(c.r, c.g, c.b)));
				}
				else
				{
if (rl_debug) console.printf("                    NOT A LIGHT / ANIMATED");
				}
			}
		}
		return saturate(c, rl_saturation);
	}
	void find_flat_colors()
	{
		Texman texture;
		foreach (f: flats)
		{
			if (f != texture.GetName(Level.SkyTexture1)) flat_colors.Push(get_flat_color(f, rl_perceived, rl_howred, rl_howgreen, rl_howblue));
		}
	}
	Array<int> flat_color_lux;
	void find_flat_color_lux() 
	{
		foreach (c: flat_colors) flat_color_lux.Push(perceived(c));
	}

/****************************************************************************************************************************/
// reading data

	Array<string> gl_defs;
	void readgldefs(int startlump=0)
	{
		int fhnd = Wads.FindLump("gldefs", startlump, Wads.ANYNAMESPACE);
		if (fhnd == -1) return;
		gl_defs.Push(Wads.ReadLump(fhnd).MakeUpper());
		readgldefs(++fhnd);
	}

/****************************************************************************************************************************/
// adding light

	void disperse(Actor ls, int lux, color c, double angle = -1, bool flat = false, bool prop = false)
	{
		bool rl_maxlight = CVar.FindCvar("rl_maxlight").GetBool();
		int spread = rl_maxlight ? 90 : 30;
		int astep = rl_maxlight ? 1 : 5;
		int pstep = rl_maxlight ? 5 : 20;
		int astart = angle == -1 ? 0 : angle - spread;
		int aend = angle == -1 ? 360 : angle + spread;
		int pstart = 4;
		int pend = 50;
		for (double a = astart; a < aend; a += astep)
		{
			double aa = a;
			if (aa < 0) aa = aa + 360;
			if (aa > 360) aa = aa - 360;
			bool u = true, d = true;
			for (double p = pstart; p < pend && (d || u); p += pstep)
			{
				if (!prop && d)
				{
					if (!seekwalls(ls, lux * ls.Scale.Y, aa, p, c)) d = false; // down
				}
				else if (!flat && u)
				{
					if (!seekwalls(ls, lux * ls.Scale.Y, aa, -p, c)) u = false; // up
				}
			}
		}
	}
	bool seekwalls(Actor ls, int lux, double a, double p, color c)
	{
		bool rl_maxlight = CVar.FindCvar("rl_maxlight").GetBool();
		bool rl_color_txt = CVar.FindCvar("rl_color_txt").GetBool();
		double rl_color_val = CVar.FindCvar("rl_color_val").GetFloat();
		FLineTraceData beam;
		if (ls.LineTrace(a, lux * (rl_maxlight ? 2048 : 1024) * .0039216, p, TRF_THRUBLOCK | TRF_THRUHITSCAN | TRF_THRUACTORS, data: beam)) // 255 lux is <1 at 1024
		{
			if (beam.HitType == FLineTraceData.TRACE_HitFloor || beam.HitType == FLineTraceData.TRACE_HitCeiling || beam.HitType == FLineTraceData.TRACE_HasHitSky) return false;
			if (beam.HitType == FLineTraceData.TRACE_HitWall)
			{
				Line lin = beam.HitLine;
				Side wall = lin.Sidedef[beam.LineSide];
				double distance = beam.Distance * .015625;
				// adjustment for off center beams
				vector2 hxy = (beam.HitLocation.x, beam.HitLocation.y);
				vector2 w1 = LevelLocals.Vec2Diff(hxy, (lin.v1.P.x, lin.v1.P.y));
				vector2 w2 = LevelLocals.Vec2Diff(hxy, (lin.v2.P.x, lin.v2.P.y));
				double wmin = min(w1.length(), w2.length());
				double wmax = max(w1.length(), w2.length());
				double wskew = wmax == 0 ? 1 : wmin / wmax;
				vector3 bh = beam.HitLocation;
				vector3 h1 = LevelLocals.Vec3Diff(bh, (bh.x, bh.y, beam.HitSector.FloorPlane.ZAtPoint(hxy)));
				vector3 h2 = LevelLocals.Vec3Diff(bh, (bh.x, bh.y, beam.HitSector.CeilingPlane.ZAtPoint(hxy)));
				double hmin = min(h1.length(), h2.length());
				double hmax = max(h1.length(), h2.length());
				double hskew = hmax == 0 ? 1 : hmin / hmax;
				double xskew = max(hskew, wskew) == 0 ? 1 : min(hskew, wskew) / max(hskew, wskew); // note that max can return 0 even when both numbers can't be 0
				// add total light hitting side
				double total_light = (lux *  hskew * wskew * xskew * (rl_maxlight ? 1 : (1.0 - rl_additive)));
				// if (total_light < 1.0) return false;
				if (rl_color_txt)
				{
					double hue, saturation, value;
					[hue, saturation, value] = get_hsv(c);
					if (value > rl_color_val && beam.HitSector.ColorMap.LightColor != color("white"))
					{
						c = blend(c, beam.HitSector.ColorMap.LightColor);
						[hue, saturation, value] = get_hsv(c);
					}
					double lum = total_light  / 255 * 100;
					if (value > rl_color_val && lum > 1.0)
					{
						bool b;
						if (wall_index.Find(wall.index()) == wall_index.Size())
						{
							b = true;
						}
						else
						{
							b = (wall_hue[wall_index.Find(wall.index())] != adj_hue(hue));
						}
						if (b)
						{
							double sat = (distance <= 1 ? saturation : saturation * 1 / (distance * distance)) * (rl_maxlight ? 1 : (1.0 - rl_additive));
							double slimit = 14.0;
							double dlimit = 0.3;
							if (hue > 329 || hue < 56) // red
							{
								slimit = 59.0;
								dlimit = 0.6;
							}
							if (hue > 179 && hue < 316) // blue-magenta
							{
								slimit = 24.0;
								dlimit = 2.1;
							}
							if (saturation > 10.0 && sat > dlimit)
							{
								Texman texture;
								string text = texture.GetName(wall.GetTexture(beam.LinePart));
								int index = textures.Find(text);
								if (index != textures.Size())
								{
									if (wall_index.Find(wall.index()) == wall_index.Size())
									{
										colorize(wall, adj_hue(hue));
									}
									else
									{
										double whue = wall_hue[wall_index.Find(wall.index())];
										if (adj_hue(hue) != whue) 
										{
											colorize(wall, avg_hue(hue, whue));
										}
									}
								}
							}
						}
					}
				}
				// increase to threshold
				int th_light = clamp(int(lux  * (rl_maxlight ? 1 : (1.0 - rl_additive))), 0, beam.HitSector.LightLevel);
				if (wall.Light >= th_light) return false;
				// dissipate via inverse square law
				double increase = (distance <= 1 ? total_light : total_light * 1 / (distance * distance)) * (rl_maxlight ? 1 : (1.0 - rl_additive));
				wall.Light = clamp(wall.Light + increase, wall.Light, th_light);
			}
		}
		return true;
	}

	// here "thinkers" generate shadows & both bake textures
	const HD_THINK = 1;
	const HD_DUMMY = 2;
	bool add_light(int type, vector3 v3, int lux, double scaley, double prox = 0.0, color c = color("white"), int size = 0, bool text = false, double angle = -1, double pitch = 0, bool flat = false, bool disperse = true, bool window = false, bool eave = false, bool plat = false)
	{
		Actor p = type == HD_THINK ? Actor.Spawn("hd_thinklight", v3) : type == HD_DUMMY ? Actor.Spawn("hd_dummylight", v3) : null;
		if (p)
		{
			if (prox > 0)
			{
				if (p.CheckProximity("hd_lightsource", prox, flags: CPXF_ANCESTOR)) size = 0;
			}
			p.Scale.Y = scaley;
			bool rl_maxlight = CVar.FindCvar("rl_maxlight").GetBool();
			if (rl_maxlight)
			{
				disperse(p, lux, c, angle, flat, size > 0 && !text ? true : false);
			}
			else
			{
				if (type == HD_THINK || true) disperse(p, int(lux * (1.0 - rl_additive)), c, angle, flat,  size > 0 && !text ? true : false);
			}
			double hue, saturation, value;
			[hue, saturation, value] = get_hsv(c);
			if (size > (rl_maxlight ? 0 : 2))
			{
				int flags = CVar.FindCvar("rl_shadows").GetBool() ? DYNAMICLIGHT.LF_ATTENUATE | DYNAMICLIGHT.LF_DONTLIGHTACTORS | DYNAMICLIGHT.LF_SPOT : DYNAMICLIGHT.LF_ATTENUATE | DYNAMICLIGHT.LF_SPOT;
				p.angle = angle;
				if (text)
				{
					p.A_AttachLight("hd_dlight", DynamicLight.SectorLight, c, size, 0, flags, spoti: 90, spoto: 100, spotp: pitch);
				}
				else
				{
					p.A_AttachLight("hd_dlight", DynamicLight.SectorLight, c, size, 0, flags, spoti: 80, spoto: 110, spotp: -90);
				}
				if (CVar.FindCvar("rl_performance").GetBool() && !window)
				{
					p.A_RemoveLight("hd_dlight");
					if (type == HD_DUMMY) p.Destroy();
				}
			}
			return true;
		}
		return false;
	}

	Array<string> sprites;
	Array<int> sprite_color_lux;
	void add_decorativelights() // watch for embedded class names
	{
		double rl_decorative = CVar.FindCvar("rl_decorative").GetFloat();
		foreach (sec: hd_sectors)
		{
			Actor thing = Level.Sectors[sec.sec].ThingList;
			while (thing)
			{
				if (!thing.bIsMonster && thing.bSolid && !thing.bShootable && thing.height > 0 && !(thing is "Inventory"))
				{
					string cname = thing.GetClassName();
					cname = cname.MakeUpper();
					foreach (g: gl_defs)
					{
						if (g.IndexOf(cname) != -1)
						{
							int index = sprites.Find(cname);
							if (index == sprites.Size())
							{
								Texman texture;
								string sname = texture.GetName(thing.CurState.GetSpriteTexture(0));
								int fhnd = Wads.FindLump(sname, 0, Wads.NS_SPRITES);
								string ns = Wads.GetLumpFullName(fhnd).MakeUpper();
								if (ns != sname) continue; // for now this routine only reads WAD or IWAD sprites
								string flump = Wads.ReadLump(fhnd);
								sprites.Push(cname);
								sprite_colors.Push(get_sprite_color(flump, rl_perceived, rl_howred, rl_howgreen, rl_howblue));
								sprite_color_lux.Push(perceived(sprite_colors[sprite_colors.Size() - 1]));
								index = sprite_colors.Size() - 1;
							}
							double scaley = clamp(thing.height * .015625, 0.5, 1.0);
							int lux = sprite_color_lux[index];
							if (sec.height > thing.height * 2) lux -= clamp(int(4 * sec.height / thing.height), int(lux * 0.25), lux);
							int size = clamp(int(lux * 0.0392 * scaley * rl_decorative), 1, rl_decorative);
							color c = sprite_colors[index];
							if (add_light(HD_THINK, (thing.pos.x, thing.pos.y, thing.pos.z + thing.height + int(thing.height * 0.2)), lux, scaley, 0.0, c, size)) break;
						}
					}
				}
				thing = thing.snext;
			}
		}
	}
	void add_morelights()
	{
		if (sprites.Size() == 0) return;
		Texman texture;
		double rl_decorative = CVar.FindCvar("rl_decorative").GetFloat();
		double rl_area = CVar.FindCvar("rl_area").GetFloat();
		double rl_length = CVar.FindCvar("rl_length").GetFloat();
		foreach (sec: hd_sectors)
		{
			Sector ssec = Level.Sectors[sec.sec];
			string floor = texture.GetName(ssec.GetTexture(Sector.floor));
			if (anim_flat(floor)) continue;
			if (ssec.LightLevel > 64 && ssec.LightLevel < 128 && sec.area > rl_area && sec.height > 96 && !sec.special)
			{
				foreach (lin: ssec.Lines)
				{
					if (!(lin.Flags & Line.ML_TWOSIDED) && lin.delta.length() >= rl_length && lin.delta.length() <= 1024)
					{
						Sector bsec = backSector(ssec, lin);
						int fside = (lin.FrontSector != ssec) ? Line.Back : Line.Front;
						Side wall = lin.Sidedef[fside];
						string text = texture.GetName(wall.GetTexture(Side.Mid));
						if (textures.Find(text) == textures.Size())
						{
							continue;
						}
						else
						{
							if (textures_light_size[textures.Find(text)] != -1) continue; // don't put in front of lights
						}
						vector2 xy = frontline(lin, 16.0);
						int index = random(0, sprites.Size() - 1);
						Actor p = Actor.Spawn(sprites[index], (xy.x, xy.y, sec.floorZ));
						if (p)
						{
							double minwall = -1, minactor = -1;
							for (int a = 0; a < 361; a++)
							{
								FlineTraceData beam;
								if (p.LineTrace(a, 256, 0, TRF_THRUBLOCK | TRF_THRUHITSCAN | TRF_ALLACTORS, data: beam))
								{
									if (beam.HitLine == lin || beam.HitType == FlineTraceData.TRACE_HitNone) continue;
									if ((beam.HitType == FlineTraceData.TRACE_HitWall && beam.distance < 96) || (beam.HitType == FlineTraceData.TRACE_HitActor && beam.distance < p.radius))
									{
										p.Destroy();
										p = null;
										break;
									}
								}
							}
							if (p)
							{
								double scaley = clamp(p.height * .015625, 0.5, 1.0);
								int lux = sprite_color_lux[index];
								if (sec.height > p.height * 2) lux -= clamp(int(4 * sec.height / p.height), int(lux * 0.25), lux);
								int size = clamp(int(lux * 0.0392 * scaley * rl_decorative), 1, rl_decorative);
								color c = sprite_colors[index];
								add_light(HD_THINK, (p.pos.x, p.pos.y, p.pos.z + p.height + int(p.height * 0.2)), lux, scaley, 0.0, c, size);
							}
						}
					}
				}
			}
		}
	}

	Array<int> lightboxes;
	void add_tierlight(hd_sector ssec, Line lin, int tier)
	{
		Texman texture;
		Sector sec = Level.Sectors[ssec.sec];
		Sector bsec = backSector(sec, lin);
		int fside = (lin.FrontSector != sec) ? Line.Back : Line.Front;
		Side wall = lin.Sidedef[fside];
		string text = texture.GetName(wall.GetTexture(tier));
		int index = textures.Find(text);
		if (index == textures.Size()) return;
		if (textures_light_size[index] == -1) return;
		vector2 point = frontLine(lin);
		double floorZ, ceilingZ;
		double rl_texture = CVar.FindCvar("rl_texture").GetFloat();
		int width, height;
		[width, height] = getwd(text);
		// find floor and ceiling
		if (tier == Side.Top)
		{
			if (bsec)
			{
				if (bsec.CeilingPlane.ZAtPoint(point) < sec.CeilingPlane.ZAtPoint(point))
				{
					floorZ = bsec.CeilingPlane.ZAtPoint(point);
				}
				else
				{
					return;
				}
				ceilingZ = sec.CeilingPlane.ZAtPoint(point);
			}
		}
		if (tier == Side.Mid)
		{
			if (bsec)
			{
				if (bsec.FloorPlane.ZAtPoint(point) > sec.FloorPlane.ZAtPoint(point))
				{
					floorZ = bsec.FloorPlane.ZAtPoint(point);
				}
				else
				{
					floorZ = sec.FloorPlane.ZAtPoint(point);
				}
				if (bsec.CeilingPlane.ZAtPoint(point) < sec.CeilingPlane.ZAtPoint(point))
				{
					ceilingZ = bsec.CeilingPlane.ZAtPoint(point);
				}
				else
				{
					ceilingZ = sec.CeilingPlane.ZAtPoint(point);
				}
			}
			else
			{
				floorZ = sec.FloorPlane.ZAtPoint(point);
				ceilingZ = sec.CeilingPlane.ZAtPoint(point);
			}
		}
		if (tier == Side.Bottom)
		{
			if (bsec)
			{
				if (bsec.FloorPlane.ZAtPoint(point) > sec.FloorPlane.ZAtPoint(point)) // does not allow for unpegged textures
				{
					ceilingZ = bsec.FloorPlane.ZAtPoint(point);
				}
				else
				{
					return;
				}
				floorZ = sec.FloorPlane.ZAtPoint(point);
			}
		}
		// dimensions
		int theight = ceilingZ - floorZ;
		int x_pos = textures_x[index];
		int y_pos = height - textures_y[index];
		if (abs(y_pos - height * 0.5) < 2)
		{
			y_pos = int(theight * 0.5); // close enough to halfway
		}
		else if (theight < height)
		{
			if (tier == Side.Bottom && height - theight > y_pos) return;
			if (theight < y_pos) y_pos -= height - theight;
		}
		// texture data
		int lux = texture_color_lux[index];
		color c = texture_colors[index];
		// add the light
		double prox = tier == Side.Mid ? 0.0 : 64.0; // 32
		double scaley = clamp(lin.delta.length() * .015625, 0.5, 4.0);
		int tsize = textures_light_size[index] ; // * lux / 255;
		int size = width == 0 ? tsize : clamp(int(tsize * lin.delta.length() / width), tsize < rl_texture ? tsize : rl_texture, rl_texture);
		if (ceilingZ - floorZ < height * 0.25) return;
		if (ceilingZ - floorZ > 128) size = int(clamp(size * 128 / (ceilingZ - floorZ), size * 0.3, size));
		vector2 p1 = getMiddle(lin);
		double spotangle = lightangle(point, p1);
		bool added = false;
		if (theight < 16 || size == 0) return;
		double hue, saturation, value;
		[hue, saturation, value] = get_hsv(c);
		if ((lin.delta.length() < 16 && value < CVar.FindCvar("rl_color_val").GetFloat()) || lin.delta.length() < 8 || (anim_texture(text) && lin.delta.length() < 16)) return; // 64
		if (tier == Side.Top)
		{
			int findex, bindex;
			if (lin.FrontSector) findex = moving.Find(lin.FrontSector.SectorNum);
			if (lin.BackSector) bindex = moving.Find(lin.BackSector.SectorNum);
			if (findex == moving.Size() && bindex == moving.Size())
			{
				added = add_light(HD_DUMMY, (point.x, point.y, floorZ + y_pos), lux, scaley, prox, c, size, true, spotangle, disperse : (height > 24 ? true : false));
			}
		}
		if (tier == Side.Mid)
		{
			bool b;
			double f_min, c_max;
			[b, f_min, c_max] = window(sec);
			if (b && !steps(sec))
			{
				double c_diff = abs(floorZ - c_max);
				double f_diff = abs(ceilingZ - f_min);
				if (abs(c_diff - f_diff) < 8)
				{
					added = add_light(HD_THINK, (point.x, point.y, floorZ + y_pos), lux, scaley, prox, c, size, true, spotangle, disperse : (height > 24 ? true : false));
				}
				else if (c_diff < f_diff)
				{
					added = add_light(HD_THINK, (point.x, point.y, floorZ), lux, scaley, prox, c, size, true, spotangle, -90, true, disperse : (height > 24 ? true : false));
				}
				else if (c_diff > f_diff)
				{
					added = add_light(HD_THINK, (point.x, point.y, ceilingZ), lux, scaley, prox, c, size, true, spotangle, 90, true, disperse : (height > 24 ? true : false));
				}
				lightboxes.Push(sec.SectorNum);
			}
			else
			{
				added = add_light(HD_THINK, (point.x, point.y, floorZ + y_pos), lux, scaley, prox, c, size, true, spotangle, disperse : (height > 24 ? true : false));
			}
			sec.LightLevel = clamp(int(sec.LightLevel + (lux * .025)), 0, 255); // 1-
			ssec.light = sec.LightLevel;
		}
		if (tier != Side.Mid) added = add_light(HD_DUMMY, (point.x, point.y, floorZ + y_pos), lux, scaley, prox, c, size, true, spotangle, disperse : (height > 24 ? true : false)); // was only bottom & HD_DUMMY
		if (added)
		{
			if (theight > 512)
			{
				int step = theight * 0.25 * (CVar.FindCvar("rl_maxlight").GetBool() ? 0.5 : 2.0);
				for (double z = floorZ + y_pos + step; z < ceilingZ; z += step) bool b = add_light(HD_DUMMY, (point.x, point.y, z), lux, scaley, 0.0, c, size, true, spotangle);
				for (double z = floorZ + y_pos - step; z > floorZ; z -= step) bool b = add_light(HD_DUMMY, (point.x, point.y, z), lux, scaley, 0.0, c, size, true, spotangle);
			}
			// increase to threshold
			int th_light = clamp(int(lux  * (1.0 - rl_additive)), 0, lux); // 2
			wall.Light = clamp(wall.Light + lux, wall.Light, th_light);
		}
	}

	void add_windowlights()
	{
		foreach (sec: hd_sectors)
		{
			Sector ssec = Level.Sectors[sec.sec];
			if (lightboxes.Find(sec.sec) == lightboxes.Size())
			{
				double rl_flat = CVar.FindCvar("rl_flat").GetFloat();
				double floorZ = sec.floorZ;
				double ceilingZ = sec.ceilingZ;
				bool b;
				double f_min, c_max;
				[b, f_min, c_max] = window(ssec, false);
				if (b && !steps(ssec))
				{
					double c_diff = abs(floorZ - c_max);
					double f_diff = abs(ceilingZ - f_min);
					if (abs(f_diff - c_diff) < 32) continue;
					// find brightest adjacent sector
					color c = ssec.ColorMap.LightColor;
					int min, max;
					color bc;
					[min, max, bc] = brightest(ssec);
					if (max - min < 20) // 20
					{
						continue;
					}
					int size = int(clamp((max - min) * rl_flat, rl_flat * 0.25, rl_flat * 5.0)); // 4.0
					if (size < 4) continue;
					if (c == color("white") && bc == color("white"))
					{
						int gs = int((max + min) * 0.25);
						c = color(gs, gs, gs);
					}
					else if (c != color("white") && bc != color("white"))
					{
						c = blend(c, bc);
					}
					c = shade(c, -0.4);
					foreach (lin: ssec.Lines)
					{
						if (lin.delta.length() < 8) continue;
						Sector bsec = BackSector(ssec, lin);
						if (!bsec)
						{
							vector2 point = frontline(lin);
							bool add = c_diff < f_diff ? add_light(HD_DUMMY, (point.x, point.y, floorZ), 0, 0, 0, c, size, true, 0, -90, true, true, true) : c_diff > f_diff ? add_light(HD_DUMMY, (point.x, point.y, ceilingZ), 0, 0, 0, c, size, true, -1, 90, true, true, true) : false;
						}
					}
				}
			}
		}
	}

	void add_texturelights()
	{
		foreach (sec: hd_sectors) foreach (lin: Level.Sectors[sec.sec].Lines) foreach (sid: stype) add_tierlight(sec, lin, sid);
	}

	Array <Sector> b_secs;
	Array <Sector> w_secs;
	void set_bleed_color(Sector sec, color c)
	{
		if (CVar.FindCvar("rl_color_sec").GetBool())
		{
			if (sec.ColorMap.LightColor != color("white") && sec.ColorMap.LightColor != c) c = blend(sec.ColorMap.LightColor, c);
			sec.SetColor(saturate(c, sec.LightLevel / 1280));
		}
		double hue, saturation, value;
		[hue, saturation, value] = get_hsv(c);
		if (!CVar.FindCvar("rl_color_spr").GetBool()) sec.SetSpecialColor(Sector.sprites, shade(c, sec.LightLevel / 320));
		c = shade(c, -0.1);
		bool b = false;
		double rl_texture = CVar.FindCvar("rl_texture").GetFloat();
		bool rl_eave = CVar.FindCvar("rl_eave").GetBool();
		// color bleeding
		foreach (lin: sec.Lines)
		{
			if (lin.delta.length() < 16) continue;  // 16
			Sector bsec = backSector(sec, lin);
			if (bsec)
			{
				vector2 v2 = Level.Vec2Offset(lin.V1.P, lin.delta.Unit() * lin.delta.length() * 0.5);
				double secZ = sec.CeilingPlane.ZAtPoint(v2);
				double bsecZ = bsec.CeilingPlane.ZAtPoint(v2);
				if (secZ >= bsecZ && (hue < 210 || hue > 270)) // no blue bleeding
				{
					if (b_secs.Find(bsec) == b_secs.Size())
					{
						b_secs.Push(bsec);

						if (sec.GetTexture(Sector.ceiling) == SkyFlatNum &&  bsec.GetTexture(Sector.ceiling) != SkyFlatNum)
						{
							set_bleed_color(bsec, c);
						}
						else
						{
							vector2 secv2, bsecv2;
							foreach (ssec : hd_sectors)
							{
								if (ssec.sec == sec.SectorNum)
								{
									secv2 = ssec.cspot;
								}
								if (ssec.sec == bsec.SectorNum)
								{
									bsecv2 = ssec.cspot;
								}
							}
							Actor p = Actor.Spawn("hd_phantom", (secv2.x, secv2.y, (sec.CeilingPlane.ZAtPoint(secv2) + sec.FloorPlane.ZAtPoint(secv2)) * 0.5));
							if (p)
							{
								Actor pb = Actor.Spawn("hd_phantom", (bsecv2.x, bsecv2.y, (bsec.CeilingPlane.ZAtPoint(bsecv2) + bsec.FloorPlane.ZAtPoint(bsecv2)) * 0.5));
								if (pb)
								{
									p.target = pb;
									p.A_Face(pb, flags: FAF_BOTTOM);
									if (p.CheckIfTargetInLOS()) set_bleed_color(bsec, c);
									pb.Destroy();
								}
								p.Destroy();
							}
						}
					}
					if (secZ > bsecZ && bsec.GetTexture(Sector.ceiling) != SkyFlatNum && abs(sec.FloorPlane.ZAtPoint(v2) - bsec.FloorPlane.ZAtPoint(v2)) < 32  && sec.LightLevel > bsec.LightLevel && rl_eave)
					{
						// attach fuzzy light
						Texman texture;
						int fside = (lin.FrontSector != sec) ? Line.Back : Line.Front;
						Side wall = lin.Sidedef[fside];
						string text = texture.GetName(wall.GetTexture(Side.Top));
						int index = textures.Find(text);
						// add eave lights
						double dlen = 0.5;
						for (double d = 0.1; d < 0.5; d += 0.05)
						{
							if (lin.delta.length() * d >= 128)
							{
								dlen = d;
								break;
							}
						}
						vector2 lindir = lin.delta.Unit();
						for (double d = dlen; d < 0.9; d += dlen)
						{
							vector2 point = Level.Vec2Offset(lin.V1.P, lindir * (lin.delta.length() * d) + (lindir.Y, -lindir.X) * 1.5);
							vector2 p1 = Level.Vec2Offset(lin.V1.P, lindir * (lin.delta.length() * d) + (lindir.Y, -lindir.X) * 1.0);
							double spotangle = lightangle(point, p1);
							int size = clamp(int((bsecZ - sec.FloorPlane.ZAtPoint(v2)) / 16), rl_texture * 0.25, rl_texture * 0.75); // * 0.50);
							if (size > 1) add_light(HD_DUMMY, (point.x, point.y, bsecZ), 0, 0, 0, shade(c, -0.5), size, true, spotangle, 45, true, eave: true);
							b = true;
						}
					}
					else if (sec.GetTexture(Sector.ceiling) == SkyFlatNum && w_secs.Find(bsec) == w_secs.Size()) // outside window lights
					{
						// add window sky lights
						if (window(bsec) && bsec.GetTexture(Sector.ceiling) != SkyFlatNum && bsec.Lines.Size() == 4) // only simple windows
						{
							bool rl_maxlight = CVar.FindCvar("rl_maxlight").GetBool();
							int lux = texture_color_lux[0];
							double scaley = clamp(lux * .0039216, 0.5, 2.0);
							foreach (bbsec : hd_sectors)
							{
								if (bbsec.sec == bsec.SectorNum)
								{
									double xspan = abs(bbsec.maxx - bbsec.minx);
									double yspan = abs(bbsec.maxy - bbsec.miny);
									double area = bbsec.height * max(xspan, yspan);
									lux *= int(area / (rl_maxlight ? 2048 : 4096));
									if (area > 0)	add_light(HD_THINK, (bbsec.cspot.x, bbsec.cspot.y, (bbsec.floorZ + bbsec.ceilingZ) * 0.5), lux, scaley, 0.0, texture_colors[0], window: true);
									w_secs.Push(bsec);
									break;
								}
							}
						}
					}
				}
			}
		}
	}

	void add_flatlights()
	{
		Texman texture;
		double rl_flat = CVar.FindCvar("rl_flat").GetFloat();
		double rl_ceiling_grid = CVar.FindCvar("rl_ceiling_grid").GetFloat();
		bool rl_fluid = CVar.FindCvar("rl_fluid").GetBool();
		bool rl_maxlight = CVar.FindCvar("rl_maxlight").GetBool();
		Array<Actor> lights;
		foreach (sec: hd_sectors)
		{
			if (sec.height == 0) continue;
//			if (sec.area < 4) continue;

			Sector ssec = Level.Sectors[sec.sec];
			string ceiling = texture.GetName(ssec.GetTexture(Sector.ceiling));
			string floor = texture.GetName(ssec.GetTexture(Sector.floor));
			int index = flats.find(floor);
			if (index != flats.Size())
			{
				color c = flat_colors[index];
				int lux = flat_color_lux[index];
				if (anim_flat(floor) && flats_light_size[index] != -1)
				{
					ssec.SetGlowHeight(Sector.Floor, sec.height * 0.25);             //////////////// note that Glow Height does not work
					ssec.SetGlowColor(Sector.Floor, saturate(c, 0.5));
					set_bleed_color(ssec, shade(flat_colors[index], 1.5));
					if (rl_fluid && !CVar.FindCvar("rl_performance").GetBool() && sec.area > 27)
					{
						Actor p, pp;
						p = Actor.Spawn("hd_phantom", (sec.cspot.x, sec.cspot.y, ssec.FloorPlane.ZAtPoint(sec.cspot)));
						if (p)
						{
							foreach (lin : ssec.Lines)
							{
								if (lin.delta.length() < 128) continue;
								vector2 point = frontline(lin);
								if (IsInsideSector(ssec, point.x, point.y))
								{
									pp = Actor.Spawn("hd_spotlight", (point.x, point.y, ssec.FloorPlane.ZAtPoint(point)));
									if (pp)
									{
										if (pp.CheckProximity("hd_spotlight", 64.0, 1,  flags: CPXF_CHECKSIGHT | CPXF_NOZ))
										{
											pp.Destroy();
										}
										else
										{
											pp.args[0] = sec.sec;
											color c = flat_colors[index];
											pp.Angle = pp.AngleTo(p);
											pp.A_AttachLight("hd_spot", DynamicLight.SectorLight, shade(c, -0.15), 0, 0, DYNAMICLIGHT.LF_ATTENUATE | DYNAMICLIGHT.LF_SPOT, spoti: Frandom(12.0, 24.0), spoto: Frandom(48.0, 96.0), spotp: 180.0);
										}
									}
								}
							}
						}
						p.Destroy();
					}
					// increase to threshold
					int th_light = clamp(int(lux  * (1.0 - rl_additive)), 0, lux);
					th_light *= rl_maxlight ? 1 : (1.0 - rl_additive);
					ssec.SetPlaneLight(Sector.Floor, ssec.GetFloorLight() + th_light);
				}
			}
			if (ssec.GetTexture(Sector.CEILING) == SkyFlatNum) continue;
			index = flats.find(ceiling);
			if (index != flats.Size() && flats_light_size[index] != -1)
			{
				set_bleed_color(ssec, flat_colors[index]);
				if (sec.area < 1) continue;
				int lux = flat_color_lux[index];
				double scaley = clamp(32.0 / sec.height, 0.1, 2.0);
				color c = shade(ssec.ColorMap.LightColor, 0.1);
				double cz = sec.ceilingZ;
				int size = clamp(int(flats_light_size[index] * lux/ 255), 0, rl_flat);
				if (int(sec.area) == 28 && lux > 200)
				{
					Actor p = Actor.Spawn("hd_phantom", (sec.cspot.x, sec.cspot.y, (sec.ceilingZ)));
					if (p) p.A_AttachLight("hd_spot", DynamicLight.SectorLight, c, 0, 0, DYNAMICLIGHT.LF_ATTENUATE | DYNAMICLIGHT.LF_SPOT | DYNAMICLIGHT.LF_DONTLIGHTACTORS, spoti: 24.0, spoto: 36.0, spotp: 90.0);
				}
				else if (steps(ssec) && sec.area < 2048)
				{
					bool b = add_light(HD_DUMMY, (sec.cspot.x, sec.cspot.y, cz), lux, scaley, 128.0, c, size, true, -1, 90, true);
				}
				else if (sec.area >= 28 &&  size > 0 && rl_ceiling_grid > 0)
				{
					bool b = add_light(HD_DUMMY, (sec.cspot.x, sec.cspot.y, cz), lux, scaley, 128.0, c, size, true, -1, 90, true); // HD_THINK
//					rl_ceiling_grid *= rl_maxlight ? 1 : 2;
					double x = rl_ceiling_grid, y = rl_ceiling_grid;
					double cx = sec.cspot.x, cy = sec.cspot.y;
					double prox = rl_ceiling_grid * 0.5;
					while (abs(x) < abs(sec.maxx - sec.minx))
					{
						while (abs(y) < abs(sec.maxy - sec.miny))
						{
							if (cx + x < sec.maxx && IsInsideSector(ssec, cx + x, cy)) add_light(HD_DUMMY, (cx + x, cy, cz), lux, scaley, prox, c, size, true, -1, 90, true);
							if (cx - x > sec.minx && IsInsideSector(ssec, cx - x, cy)) add_light(HD_DUMMY, (cx - x, cy, cz), lux, scaley, prox, c, size, true, -1, 90, true);

							if (cy + y < sec.maxy && IsInsideSector(ssec, cx, cy + y)) add_light(HD_DUMMY, (cx, cy + y, cz), lux, scaley, prox, c, size, true, -1, 90, true);
							if (cy - y > sec.miny && IsInsideSector(ssec, cx, cy - y)) add_light(HD_DUMMY, (cx, cy - y, cz), lux, scaley, prox, c, size, true, -1, 90, true);

							if (cx + x < sec.maxx && cy + y < sec.maxy && IsInsideSector(ssec, cx + x, cy + y)) add_light(HD_DUMMY, (cx + x, cy + y, cz), lux, scaley, prox, c, size, true, -1, 90, true);
							if (cx - x > sec.minx && cy + y < sec.maxy && IsInsideSector(ssec, cx - x, cy + y)) add_light(HD_DUMMY, (cx - x, cy + y, cz), lux, scaley, prox, c, size, true, -1, 90, true);

							if (cx + x < sec.maxx && cy - y > sec.miny && IsInsideSector(ssec, cx + x, cy - y)) add_light(HD_DUMMY, (cx + x, cy - y, cz), lux, scaley, prox, c, size, true, -1, 90, true);
							if (cx - x > sec.minx && cy - y > sec.miny && IsInsideSector(ssec, cx - x, cy - y)) add_light(HD_DUMMY, (cx - x, cy - y, cz), lux, scaley, prox, c, size, true, -1, 90, true);

							y += rl_ceiling_grid;
						}
						x += rl_ceiling_grid;
						y = rl_ceiling_grid;
					}
				}
				if (!sec.special) ssec.LightLevel = clamp(int(ssec.LightLevel + (lux * (1- rl_additive))), 0, 255); // 1-
				sec.light = ssec.LightLevel;
				lightboxes.Push(sec.sec); // check array
				int th_light = clamp(int(lux  * rl_additive), 0, lux); // 2
				if (!sec.special) ssec.SetPlaneLight(Sector.Ceiling, int(lux  * (1.0 - rl_additive)));
			}
		}
	}

	void add_outsidelights()
	{
		b_secs.clear();
		bool rl_maxlight = CVar.FindCvar("rl_maxlight").GetBool();
		int lux = texture_color_lux[0] * (1 + (rl_maxlight ? (1 - abs(rl_additive)) : 0));
		double scaley = clamp(lux * .0039216, 0.5, 2.0);
		foreach (sec: hd_sectors)
		{
			if (sec.light == 0) continue;
			if (sec.height < 32) continue;
			Sector ssec = Level.Sectors[sec.sec];
			if (ssec.GetTexture(Sector.ceiling) == SkyFlatNum)
			{
				if (steps(ssec) && sec.area < 2048)
				{
					add_light(HD_DUMMY, (sec.cspot.x, sec.cspot.y, (sec.floorZ + sec.ceilingZ) * 0.5), lux, scaley, 128.0, texture_colors[0]);
				}
				else if (sec.area > 256)
				{
					int step = sec.height * 0.25 * (rl_maxlight ? 0.5 : 2.0);
					add_light(HD_THINK, (sec.cspot.x, sec.cspot.y, (sec.floorZ + sec.ceilingZ) * 0.5), lux, scaley, 0.0, texture_colors[0]);
					if (sec.height > step * 2)
					{
						for (double z = (sec.floorZ + sec.ceilingZ) * 0.5 + step; z < sec.ceilingZ; z += step) add_light(HD_DUMMY, (sec.cspot.x, sec.cspot.y, z), lux, scaley, 0.0, texture_colors[0]);
						for (double z = (sec.floorZ + sec.ceilingZ) * 0.5 - step; z > sec.floorZ; z -= step) add_light(HD_DUMMY, (sec.cspot.x, sec.cspot.y, z), lux, scaley, 0.0, texture_colors[0]);
					}
				}
				set_bleed_color(ssec, texture_colors[0]);
				if (!sec.special)
				{
					ssec.LightLevel = int(max(ssec.LightLevel, lux * (1.0 - rl_additive)));
					sec.light = ssec.LightLevel;
					ssec.SetPlaneLight(Sector.Floor, int(ssec.LightLevel * (1.0 - rl_additive) * rl_maxlight ? 1 : (1.0 - rl_additive)));
				}
			}
		}
	}

/****************************************************************************************************************************/
// light smoothing

	const LEFT = 0;
	const RIGHT = 1;
	Line find_adjacent(Line lin, int dir)
	{
		double lin_angle = VectorAngle(lin.delta.x, lin.delta.y);
		Line rlin = null;
		Array<Line> adj_lines;
		foreach (slin: Level.Lines)
		{
			if (slin == lin) continue;
			if (dir == LEFT)
			{
				if (slin.V2 == lin.V1) adj_lines.Push(slin);
			}
			if (dir == RIGHT)
			{
				if (slin.V1 == lin.V2) adj_lines.Push(slin);
			}
		}
		double diff = double.infinity;
		foreach (slin: adj_lines)
		{
			if (Actor.AbsAngle(VectorAngle(slin.delta.x, slin.delta.y), lin_angle) < diff)
			{
				diff = Actor.AbsAngle(VectorAngle(slin.delta.x, slin.delta.y), lin_angle);
				if (diff < 45) // < 45
				{
					rlin = slin;
					break;
				}
			}
		}
		return rlin;
	}

	int, int find_adjacent_light(Line lin, Sector sec)
	{
		Sector ssec = lin.FrontSector;
		if (ssec == sec)
		{
			Side wall = lin.Sidedef[Line.Front];
			return wall.index(), wall.Light;
		}
		foreach (slin: ssec.Lines)
		{
			if (slin == lin) continue;
			if (slin.Flags & Line.ML_TWOSIDED)
			{
				Sector bsec = backSector(ssec, slin);
				if (!bsec) continue;
				if (bsec == sec)
				{
					Side wall = lin.Sidedef[Line.Front];
					return wall.index(), wall.Light;
				}
			}
		}
		Side wall = lin.Sidedef[Line.Back];
		if (wall)
		{
			return wall.index(), wall.Light;
		}
		else
		{
			return -1, 666;
		}
	}

	void smooth_lights()
	{
		Texman texture;
		int lightleft, lightright;
		foreach (sec: hd_sectors)
		{
			if (sec.light == 0) continue;
			Sector ssec = Level.Sectors[sec.sec];
			foreach (lin: ssec.Lines)
			{
				if (lin.delta.length() < 4) continue;
				int fside = (lin.FrontSector != ssec) ? Line.Back : Line.Front;
				Side wall = lin.Sidedef[fside];
				int i = 0;
				foreach (sid: stype)
				{
					string t = texture.GetName(wall.GetTexture(sid));
					i += t == "" ? 0 : 1;
				}
				if (i == 0) continue;
				Line rlin;
				Sector bsec = backSector(ssec, lin);
				vector2 v2 = Level.Vec2Offset(lin.V1.P, lin.delta.Unit() * lin.delta.length() * 0.5);
				double lin_angle = VectorAngle(lin.delta.x, lin.delta.y);
				double left_angle = double.infinity;
				int left_light = 666;
				int left_index = -1, right_index = -1;
				rlin = find_adjacent(lin, LEFT);
				if (rlin)
				{
					if (rlin.delta.length() > 4)
					{
						left_angle = VectorAngle(rlin.delta.x, rlin.delta.y);
						[left_index, left_light] = find_adjacent_light(rlin, ssec);
					}
				}
				double right_angle = double.infinity;
				int right_light = 666;
				rlin = find_adjacent(lin, RIGHT);
				if (rlin)
				{
					if (rlin.delta.length() < 4)
					{
						right_angle = VectorAngle(rlin.delta.x, rlin.delta.y);
						[right_index, right_light] = find_adjacent_light(rlin, ssec);
					}
				}
				// average wall light
				if (left_light != 666 && right_light != 666) wall.Light = int((wall.Light + left_light + right_light) * 0.333);
				if (left_light == 666 && right_light != 666) wall.Light = int((wall.Light + right_light) * 0.5);
				if (left_light != 666 && right_light == 666) wall.Light = int((wall.Light + left_light) * 0.5);
				// colorize
				double this_hue = wall_index.Find(wall.index()) != wall_index.size() ? wall_hue[wall_index.Find(wall.index())] : double.infinity;
				double left_hue = wall_index.Find(left_index) != wall_index.size() ? wall_hue[wall_index.Find(left_index)] : double.infinity;
				double right_hue = wall_index.Find(right_index) != wall_index.size() ? wall_hue[wall_index.Find(right_index)] : double.infinity;
				// apply or average
				if (this_hue == double.infinity && right_hue == double.infinity && left_hue != double.infinity) colorize(wall, left_hue);
				if (this_hue == double.infinity && right_hue != double.infinity && left_hue == double.infinity) colorize(wall, right_hue);
				if (this_hue == double.infinity && right_hue != double.infinity && left_hue != double.infinity) colorize(wall, avg_hue(left_hue, right_hue));
				if (this_hue != double.infinity && right_hue == double.infinity && left_hue != double.infinity) colorize(wall, avg_hue(this_hue, left_hue));
				if (this_hue != double.infinity && right_hue != double.infinity && left_hue == double.infinity) colorize(wall, avg_hue(this_hue, right_hue));
				if (this_hue != double.infinity && right_hue != double.infinity && left_hue != double.infinity) colorize(wall, avg_hue(this_hue, avg_hue(left_hue, right_hue)));
			}
		}
	}

/****************************************************************************************************************************/
//  applied color
	Array<int> wall_index;
	Array<double> wall_hue;
	void colorize(Side wall, double hue)
	{
		Texman texture;
		if (wall_index.Find(wall.index()) == wall_index.Size())
		{
			wall_index.Push(wall.index());
			wall_hue.Push(hue);
		}
		else
		{
			wall_hue[wall_index.Find(wall.index())] = hue;
		}
		foreach (sid: stype)
		{
			string t = texture.GetName(wall.GetTexture(sid));
			if (t != "")
			{
				int index = textures.Find(t);
				if (index == textures.Size())
				{
					wall.SetColorization(sid, String.Format("deg%i", int(hue))); // rare
				}
				else
				{
					if (!anim_texture(t) && textures_light_size[index] == -1) wall.SetColorization(sid, String.Format("deg%i", int(hue)));
				}
			}
		}
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (rotimer > 100 && rotimer < 300) Screen.DrawText(ConFont, Font.CR_YELLOW, 0, 0, "ReLite_0.7.3 b", DTA_ScaleX, 1.5, DTA_ScaleY, 1.5); 
		if (info) Screen.DrawText(ConFont, Font.CR_GOLD, 0, 25, info, DTA_ScaleX, 2.5, DTA_ScaleY, 2.5); 
	}
}

/****************************************************************************************************************************/
//  menu
class hd_menu : OptionMenu {}
