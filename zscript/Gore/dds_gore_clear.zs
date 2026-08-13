class DDSGoreClearHandler : EventHandler
{
	bool enabled;
	bool alertme;
	int intervalTics;

	void RefreshCVars()
	{
		CVar en = CVar.FindCVar("dds_goreclear");
		CVar al = CVar.FindCVar("dds_goreclear_alert");
		CVar iv = CVar.FindCVar("dds_goreclear_interval");
		enabled = en && en.GetBool();
		alertme = al && al.GetBool();
		int seconds = iv ? iv.GetInt() : 120;
		if (seconds < 10) seconds = 10;
		intervalTics = seconds * TICRATE;
	}

	override void WorldLoaded(WorldEvent e)
	{
		RefreshCVars();
	}

	override void WorldTick()
	{
		if (gametic % 35 == 0)
			RefreshCVars();
		if (!enabled || intervalTics <= 0)
			return;
		if (gametic % intervalTics != 0)
			return;

		int cleared = 0;
		ThinkerIterator it = ThinkerIterator.Create("Droplets");
		Actor mo;
		while ((mo = Actor(it.Next())))
		{
			mo.Destroy();
			cleared++;
		}
		it = ThinkerIterator.Create("BloodsMist");
		while ((mo = Actor(it.Next())))
		{
			mo.Destroy();
			cleared++;
		}
		if (alertme)
			console.printf("Cleared %d gore actors", cleared);
	}
}
