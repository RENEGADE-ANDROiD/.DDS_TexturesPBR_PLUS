class DropletsEventHandler : EventHandler
{
	bool blood_gibs, blood_pools, blood_alwaysgib;

	void RefreshCVars()
	{
		CVar g = CVar.FindCVar("blood_gibs");
		CVar p = CVar.FindCVar("blood_pools");
		CVar a = CVar.FindCVar("blood_alwaysgib");
		blood_gibs = g && g.GetBool();
		blood_pools = p && p.GetBool();
		blood_alwaysgib = a && a.GetBool();
	}
	
	override void OnRegister()
	{
		RefreshCVars();
		Super.OnRegister();
	}

	override void WorldLoaded(WorldEvent e)
	{
		RefreshCVars();
	}

	override void WorldTick()
	{
		if (gametic % 35 == 0)
			RefreshCVars();
	}
	
	override void WorldThingDamaged(WorldEvent e)
	{
		let mo = e.Thing;
		if (!mo.bISMONSTER || mo.bNOBLOOD)
			return;
		
		if (mo.health <= 0)
		{
			if (blood_gibs &&
				(!(e.Inflictor && e.Inflictor.bNoExtremeDeath) &&
				(mo.health < mo.GetGibHealth() ||
				(e.Inflictor && e.Inflictor.bExtremeDeath)) &&
				(mo.FindState("XDeath") || mo.FindState("Death.Extreme"))) ||
				blood_alwaysgib)
			{
				let giblets = Actor.Spawn('GibSpray',mo.pos + (0,0,32));
				giblets.master = mo;
				giblets.translation = mo.bloodtranslation;
				giblets.vel = mo.vel;
			}
				
			if (!blood_pools)
				return;
			
			let pool = Actor.Spawn('BloodPool2',mo.pos);
			pool.translation = mo.bloodtranslation;
			pool.master = mo;
		}
	}
}