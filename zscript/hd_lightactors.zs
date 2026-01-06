class hd_grid
{
	double minx1, miny1, maxx, maxy;
	double minx2, miny2;
	double minx3, miny3;
	hd_grid init(double minx, double miny, double maxx, double maxy)
	{
		self.maxx = maxx;
		self.maxy = maxy;

		self.minx1 = minx;
		self.minx2 = minx + ((maxx - minx) * 0.3333);
		self.minx3 = minx + ((maxx - minx) * 0.1667);

		self.miny1 = miny;
		self.miny2 = miny + ((maxy - miny) * 0.3333);
		self.miny3 = miny + ((maxy - miny) * 0.1667);

		return self;
	}
	// returns region of a 3x3 grid (STAT_NUM)
	int get_region(vector2 v2, double xd = 0, double yd = 0)
	{
		v2 = (v2.x + xd, v2.y + yd);
		if (v2.x < minx2)
		{
			if (v2.y < miny2)
			{
				return 1;
			}
			else if (v2.y < miny3)
			{
				return 4;
			}
			else
			{
				return 7;
			}
		}
		else if (v2.x < minx3)
		{
			if (v2.y < miny2)
			{
				return 2;
			}
			else if (v2.y < miny3)
			{
				return 5;
			}
			else
			{
				return 8;
			}
		}
		else
		{
			if (v2.y < miny2)
			{
				return 3;
			}
			else if (v2.y < miny3)
			{
				return 6;
			}
			else
			{
				return 9;
			}
		}
		xd = xd < 0 ? xd + 64 : xd - 64;
		yd = yd < 0 ? yd + 64 : yd - 64;
		int r = get_region(v2, xd, yd);
		return r;
	}
}

class hd_phantom : Actor
{
	Default
	{
		+NOINTERACTION
		+NOTONAUTOMAP
		+NOBLOCKMAP
		+NOGRAVITY
	}
}

class hd_platform : hd_phantom
{
	mixin mColor;
	mixin mGeo;

	bool light;
	int size;
	color c;
	double height, pitch;
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		// find brightest adjacent sector
		Sector sec = self.CurSector;
		c = sec.ColorMap.LightColor;
		int min, max;
		color bc;
		[min, max, bc] = brightest(sec);
		if (max - min < 20) //  || max < 196) // TESTING THIS
		{
			self.Destroy();
		}
		size = int((max - min) * 0.2);
		if (c == color("white") && bc == color("white"))
		{
			int gs = int((max + min) * 0.5);
			c = color(gs, gs, gs);
		}
		else
		{
			c = blend(c, bc);
		}

		light = false;
		height = self.CurSector.CeilingPlane.ZAtPoint(self.Pos.xy) - self.CurSector.FloorPlane.ZAtPoint(self.Pos.xy);
		pitch = self.args[0] == 1 ? 90 : -90;
		if (self.args[0] == 2) self.A_AttachLight("hd_plight", DynamicLight.SectorLight, c, size, 0, DYNAMICLIGHT.LF_ATTENUATE | DYNAMICLIGHT.LF_DONTLIGHTACTORS | DYNAMICLIGHT.LF_SPOT, spoti: 90, spoto: 100, spotp: pitch);
	}
	override void Tick()
	{
		Super.Tick();
		double floorZ = self.CurSector.FloorPlane.ZAtPoint(self.Pos.xy);
		double ceilingZ = self.CurSector.CeilingPlane.ZAtPoint(self.Pos.xy);
		if (ceilingZ - floorZ != height)
		{
			vector3 newpos = (self.Pos.x, self.Pos.y, self.args[0] == 1 ? ceilingZ : floorZ);
			self.SetOrigin(newpos, true);
			if (!light && self.args[0] == 1)
			{
				self.A_AttachLight("hd_plight", DynamicLight.SectorLight, c, size, 0, DYNAMICLIGHT.LF_ATTENUATE | DYNAMICLIGHT.LF_DONTLIGHTACTORS | DYNAMICLIGHT.LF_SPOT, spoti: 90, spoto: 100, spotp: pitch);
				light = true;
			}
		}
		else
		{
			if (self.args[0] == 1) self.A_RemoveLight("hd_plight");
			light = false;
		}
	}
}

class hd_spotlight: hd_phantom
{
	Default
	{
		+INTERPOLATEANGLES
	}
	double dirA, bAngle, bPitch, dirP, bZ, dirZ;
	string floor;
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		Texman texture;
		floor = texture.GetName(Level.Sectors[self.args[0]].GetTexture(Sector.floor)).Left(4);

		dirA = Frandom(-1.0, 1.0);
		bAngle = self.Angle;
		dirP = Frandom(-1.0, 1.0);
		bPitch = self.Pitch;
		dirZ = Frandom(-1.0, 1.0);
		bZ = self.Pos.z;
	}
	override void Tick()
	{
		Super.Tick();

		self.Angle += Frandom(1, 10) * dirA;
		if (self.Angle > bAngle + 90) dirA = -1.0;
		if (self.Angle < bAngle - 90) dirA = 1.0;

		self.Pitch += Frandom(1, 5) * dirP;
		if (self.Pitch > bPitch + 90) dirP = -1.0;
		if (self.Pitch < bPitch - 15) dirP = 1.0;

		self.SetZ(bZ + Frandom(1, 5) * dirZ);
		if (self.Pos.z > bZ + 16) dirZ = -1.0;
		if (self.Pos.z < bZ - 16) dirZ = 1.0;

		Texman texture;
		string f =  texture.GetName(Level.Sectors[self.args[0]].GetTexture(Sector.floor)).Left(4);
		if (f != floor)
		{
			Level.Sectors[self.args[0]].SetGlowHeight(Sector.Floor, 0);
			Level.Sectors[self.args[0]].SetSpecialColor(Sector.sprites, color("white"));
			self.Destroy();
		}
	}
}

class hd_lightsource : Actor
{
	hd_relite_Events Event;
	int lux;
	mixin mColor;
	Default
	{
		+NOINTERACTION
		+NOTONAUTOMAP
		+NOBLOCKMAP
		+NOGRAVITY
	}
	override void BeginPlay()
	{
		Super.BeginPlay();
		Event = hd_relite_Events(EventHandler.Find("hd_relite_Events"));
	}
/*
	States
	{
	Spawn:
		PUFF A 35;
		Loop;
	}
*/
}

class hd_thinklight : hd_lightsource
{
	override void BeginPlay()
	{
		Super.BeginPlay();
		ChangeStatNum(Thinker.STAT_USER + Event.hd_map_grid.get_region(self.Pos.xy));
	}
}

class hd_dummylight : hd_lightsource
{
}

class hd_flashlight : CustomInventory
{
	Default
	{
		+Inventory.Autoactivate
		Inventory.MaxAmount 1;
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let mo = hd_flash_light(Spawn("hd_flash_light", Owner.POS, NO_REPLACE));
		mo.master = Owner;
		self.Destroy();
	}
	States
	{
	Use:
		TNT1 A 0;
	}
}

class hd_flash_light : hd_lightsource
{
	override void BeginPlay()
	{
		Super.BeginPlay();
		ChangeStatNum(STAT_HDFLASH);
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		args[0] = 255;
		Scale.Y = 6.0;
	}
	override void Tick()
	{
		Super.Tick();
		if (!master)
		{
			self.Destroy();
			return;
		}
		if (AAPTR_MASTER) A_Warp(AAPTR_MASTER, 0,0,-2, 0, WARPF_INTERPOLATE | WARPF_NOCHECKPOSITION);
	}
}

