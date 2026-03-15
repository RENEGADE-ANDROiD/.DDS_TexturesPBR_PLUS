// Nash's  basic idea for adding sprite shadow (modified)
class hd_shade : CustomInventory
{

bool IsReLiteOn;  // Now this is an instance variable

	Default
	{
		+Inventory.Autoactivate
		Inventory.MaxAmount 1;
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (Owner)
		{
			let mo = hd_shadow(Spawn("hd_shadow", Owner.POS, NO_REPLACE));
			mo.caster = Owner;
		}
		self.Destroy();
	}
	States
	{
	Use:
		TNT1 A 0;
	}
}

class hd_Pshadow: Actor
{
	Actor caster;
	Default
	{
		RenderStyle "Stencil";
		StencilColor "Black";
		+SPRITEANGLE
		+NOINTERACTION
		+NOTONAUTOMAP
		+NOBLOCKMAP
		+MOVEWITHSECTOR
		+SYNCHRONIZED
		+DONTBLAST
		+SPRITEFLIP
		+INTERPOLATEANGLES
		FloatBobPhase 0;
	}
}

class hd_floorshadow : hd_Pshadow
{
	Default
	{
		+FLATSPRITE
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (self.args[0] == 0)
		{
			self.bXFlip = true;
			self.SpriteAngle -= 180;
		}
		if (self.args[1] == 1) self.bYFlip = true;
	}
	override void Tick()
	{
		Super.Tick();
		if (!self.args[2]--) self.Destroy();
	}
}

class hd_wallshadow : hd_Pshadow
{
	Default
	{
		+WALLSPRITE
	}
	override void Tick(void)
	{
		Super.Tick();
		if (!self.args[2]--) self.Destroy();
	}
}

class hd_beam
{
	double tscale, distance, new_angle, scaley, pitch;
	double tscaley;
	bool flashlight;
	Actor source;
	hd_beam init()
	{
		return self;
	}
}

class hd_shadow : hd_PShadow
{
	Default
	{
		RenderStyle "None";
	}
	int lifespan;
	int shadow_distance;
	crosswalk cwalk;
	Array<double> fscale;
	hd_relite_Events Event;
	// modified Agent_Ash function
	bool, double lightcheck(Actor light)
	{
		vector3 delta = caster.Vec3To(light);
		if (delta.length() > shadow_distance) return false, 0;
		vector2 aim = (VectorAngle(delta.x, delta.y), -VectorAngle(delta.xy.Length(), delta.z));
		return !caster.LineTrace(aim.x,delta.Length(),aim.y,TRF_THRUBLOCK|TRF_THRUHITSCAN|TRF_THRUACTORS, offsetz: caster.height * 0.25), delta.Length();
	}
	// Agent_Ash function to check visibility in viewport
	bool SimpleCheckSight(PlayerPawn who)
	{
        if (!who || !caster) return false;
        Vector3 delta = Vec3To(who) + (0,0,who.player.viewz - who.pos.z - height * 0.5);
        vector2 aim = (VectorAngle(delta.x, delta.y), -VectorAngle(delta.xy.Length(), delta.z) );
		if (delta.Length() > shadow_distance) return false;
        return !LineTrace(aim.x,delta.Length(),aim.y,TRF_THRUBLOCK|TRF_THRUHITSCAN|TRF_THRUACTORS, offsetz: caster.height * 0.5);
	}
	hd_beam seeklight(ThinkerIterator it)
	{
		hd_beam beam = new ("hd_beam").init();
		Actor light;
		while (light = hd_lightsource(it.Next()))
		{
			int x = int(abs(caster.Pos.x - light.Pos.x));
			int y = int(abs(caster.Pos.y - light.Pos.y));
			if (x < shadow_distance && y < shadow_distance)
			{
				if (light.Scale.Y * 100 > beam.tscale)
				{
					bool visible;
					double d;
					[visible, d] = lightcheck(light);
					if (visible)
					{
						beam.tscale = light.Scale.Y * 100;
						beam.distance = d;
						beam.source = light;
						beam.new_angle = caster.AngleTo(light) + 180;
						double scaley = clamp(1 + fscale[int(clamp(d * light.Scale.Y, 0, fscale.Size() - 1))], 0.5, 4.0);
						beam.tscaley = scaley;
						beam.scaley = scaley * 0.9;

						double vheight = light.master ? light.Pos.Z + (light.master.Height * 0.5) : light.Pos.z;

						beam.pitch = atan2(caster.Pos.z - vheight, caster.Vec2To(light).length());
						if (light.master && light.master == players[consoleplayer].mo)
						{
							beam.flashlight = true;
							beam.pitch += players[consoleplayer].mo.Pitch * 0.25;
						}
						else
						{
							beam.flashlight = false;
						}
					}
				}
			}
		}
		return beam;
	}
	Actor midlocator, endlocator;
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		cwalk = new ("crosswalk").init();
		lifespan = Random(5, 15);

		if (!caster) self.Destroy();

		midlocator = Actor.Spawn("hd_phantom", caster.Pos);
		endlocator = Actor.Spawn("hd_phantom", caster.Pos);

		shadow_distance = CVar.FindCvar("rl_performance").GetBool() ? 512 : 1024;
		for (int i=0; i < 2049; i++) fscale.Push(i * 0.0078125);
		Event = hd_relite_Events(EventHandler.Find("hd_relite_Events"));
	}
	int delay;
	override void Tick()
	{
		Super.Tick();
		if (!caster) 
		{
			self.Destroy();
			return;
		}
		if (!delay) delay = CVar.FindCvar("rl_performance").GetBool() ? 15 : 5;
		delay--;
		// simple exclusions
		if (caster.GetRenderStyle() != STYLE_Normal) return;
		if (caster.FloorZ - players[consoleplayer].mo.Pos.z > players[consoleplayer].mo.height) return;
		int px = int(abs(caster.Pos.x - players[consoleplayer].mo.Pos.x));
		int py = int(abs(caster.Pos.y - players[consoleplayer].mo.Pos.y));
		if (px > shadow_distance || py > shadow_distance) return;
		// sight exclusion
		if (AbsAngle(players[consoleplayer].mo.Angle, players[consoleplayer].mo.AngleTo(self)) > players[consoleplayer].fov && (px > 128 && py > 128)) return;
		if (!SimpleCheckSight(players[consoleplayer].mo)) return;
		ThinkerIterator it = ThinkerIterator.Create("hd_lightsource", STAT_HDFLASH);
		hd_beam light = seeklight(it);
		double tscaley = light.scaley;
		double new_alpha;
		if (!light.source)
		{
			if (caster.CurSector.LightLevel < 64) return;
			// checking bounderies of searchable regions
			int r;
			Array<int> regions;
			// center & 8 dof
			r = Event.hd_map_grid.get_region(caster.Pos.xy);  if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, -shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, +shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, 0, -shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, 0, +shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, -shadow_distance, -shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, +shadow_distance, +shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, +shadow_distance, -shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			r = Event.hd_map_grid.get_region(caster.Pos.xy, -shadow_distance, +shadow_distance); if (regions.Find(r) == regions.Size()) regions.Push(r);
			hd_beam nearest;
			float d = double.infinity;
			float t = -double.infinity;
			foreach (num : regions)
			{
				ThinkerIterator it = ThinkerIterator.Create("hd_lightsource", Thinker.STAT_USER + num);
				nearest = seeklight(it);
				if (nearest.source && (nearest.distance < d || nearest.scaley > t))
				{
					d = nearest.distance;
					t = nearest.scaley;
					light = nearest;
					tscaley += light.scaley; // probably not used here
				}
				else
				{
					tscaley += light.scaley; // probably not used here
				}
			}
			new_alpha = clamp(clamp((light.scaley - light.distance *  .000025), 0.2, 0.4) * (1 - caster.CurSector.LightLevel / 255) * 0.75, 0.1, 0.4); // 0.1 is minimum
		}
		else if (caster == players[consoleplayer].mo)
		{
			return;
		}
		else {
			new_alpha = clamp(clamp((light.scaley - light.distance *  .000025), 0.2, 0.4) * (1 - caster.CurSector.LightLevel / 64) * 0.75, 0.1, 0.8); // 0.1 is minimum
		}
		vector3 v3 = (caster.Pos.x + cos(light.new_angle) * (light.scaley * 5), caster.Pos.y + sin(light.new_angle) * (light.scaley * 5), (caster.bSpawnCeiling && caster.CurSector.GetTexture(Sector.ceiling) != SkyFlatNum) ? caster.CeilingZ - 2 : caster.FloorZ + 2);
		Texman texture;
		let csprite = texture.GetName(caster.CurState.GetSpriteTexture(0));
		string swapsprite = cwalk.getswap(csprite.Left(4));
		let psprite = cwalk.getswap(csprite.Left(4)) == "NOTFOUND" ? caster.Sprite : GetSpriteIndex(swapsprite);
		Actor p = self.Spawn("hd_floorshadow", v3);
		if (p)
		{
			p.Sprite = psprite;
			p.Frame = caster.Frame;
			if (!light.source)
			{
				p.Scale.X = caster.Scale.X + 0.1;
				p.Scale.Y = 1.0;
				p.Angle = caster.Angle - 180;
			}
			else
			{
				p.Scale.X = caster.Scale.X + (light.scaley * 0.1);
				p.Scale.Y = light.scaley;
				p.Angle = light.new_angle;
			}
			p.Alpha = new_alpha;
			p.args[2] = 2;
			if (caster.bSpawnCeiling) p.args[1] = 1;
			// shadow between caster and player
			if (new_alpha > 0.1)
			{
				double inshadow = AbsAngle(players[consoleplayer].mo.Angle, p.Angle);
				if (inshadow > 135)
				{
					p.args[0] = 0;
					caster.LightLevel = caster.CurSector.LightLevel - int(inshadow * 0.3);
				}
				else
				{
					p.args[0] = light.flashlight ? 0 : 1;
					caster.LightLevel = caster.CurSector.LightLevel + int((135 - inshadow) * 0.3);
				}
			}
		}
		if (!light.source) return;
		// test overhang
		if (light.scaley > 0.5)
		{
			midlocator.SetOrigin(caster.Vec3Angle(caster.height * 0.5 * light.scaley, p.Angle), false);
			endlocator.SetOrigin(caster.Vec3Angle(caster.height * light.scaley, p.Angle), false);
			if (caster.floorZ - midlocator.floorZ > 16 || caster.floorZ - endlocator.floorZ > 16) p.Destroy();
		}
		// get wall shadow
		FlineTraceData beam;
		if (caster.Linetrace(light.new_angle, caster.height * light.scaley * 2.0, light.pitch, flags: TRF_THRUBLOCK | TRF_THRUHITSCAN | TRF_THRUACTORS, offsetz: caster.Height * 0.5, offsetforward: 4, data: beam))
		{
			if (beam.HitType == FlineTraceData.TRACE_HITWALL && beam.HitTexture)
			{
				if (!caster.bIsMonster && caster.bSolid && !caster.bShootable && caster.height > 0 && !(caster is "Inventory")) // decorative lights won't cast shadows behind themselves
				{
					if (beam.Distance < 64) return;
				}
				// placement tests
				bool b = false;
				vector2 hitxy = (beam.HitLocation.x, beam.HitLocation.y);
				Sector sec = beam.HitSector;
				Sector bsec = beam.LineSide == Line.front ? beam.HitLine.BackSector : beam.HitLine.FrontSector;
				// door
				if (bsec && beam.LinePart == Side.Top)
				{
					b = bsec.FloorPlane.zAtPoint(hitxy) == bsec.CeilingPlane.zAtPoint(hitxy);
					if (!b) b = (bsec.CeilingPlane.zAtPoint(hitxy) - sec.FloorPlane.zAtPoint(hitxy)) > caster.Height * light.scaley;
				}
				// bottom texture
				if (bsec && beam.LinePart == Side.Bottom) b = (bsec.FloorPlane.zAtPoint(hitxy) - caster.floorZ) > caster.Height * light.scaley - beam.Distance;
				// sky texture
				if (beam.LinePart == Side.Mid)
				{
					if (sec.GetTexture(Sector.Ceiling) == SkyFlatNum)
					{
						b = (sec.CeilingPlane.zAtPoint(hitxy) - sec.FloorPlane.zAtPoint(hitxy)) > caster.Height * light.scaley - beam.Distance;
					}
					else
					{
						b = true;
					}
				}
				if (!b) return;
				double belowZ = beam.HitLocation.Z - caster.Height * light.scaley * 0.2;
				if (caster.CurSector != sec && belowZ > sec.FloorPlane.zAtPoint(hitxy)) return;
				Actor p = self.Spawn("hd_wallshadow", (hitxy.x, hitxy.y, clamp(caster.floorZ - belowZ, caster.floorZ - caster.Height * light.scaley * 0.15, caster.floorZ)));
				if (p)
				{
					p.Sprite = psprite;
					p.Frame = caster.Frame;
					p.SpriteAngle = DeltaAngle(caster.AngleTo(light.source), caster.Angle) + 180;
					double line_angle = VectorAngle(beam.HitLine.delta.x, beam.HitLine.delta.y);
					double wall_angle = line_angle + DeltaAngle(line_angle, line_angle + 90);
					p.Angle = wall_angle;
					p.Scale.X = clamp(Scale.X + abs(beam.HitLine.delta dot (beam.HitDir.x,beam.HitDir.y) * .0025), Scale.X, 4.0);
					p.Scale.X += light.distance * .001;
					p.Scale.Y = clamp((light.scaley * 0.8) + (light.pitch * 0.08), 0.0, 4.0);
					p.Alpha = new_alpha;
					p.Thrust(-0.1, p.Angle);
					p.args[2] = 2;
				}
			}
		}
	}
}
