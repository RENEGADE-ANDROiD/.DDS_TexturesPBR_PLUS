class DDSFogHandler : EventHandler
{
	void ApplyFog()
	{
		CVar toggle = CVar.FindCVar("udv_togglefog");
		if (!toggle || !toggle.GetBool())
			return;

		int density = CVar.FindCVar("udv_fogdensity").GetInt();
		bool fograndom = CVar.FindCVar("udv_fograndom").GetBool();
		bool fogcolor = CVar.FindCVar("udv_fogcolor").GetBool();
		int r, g, b;
		if (fogcolor)
		{
			r = random(0, 60);
			g = random(0, 60);
			b = random(0, 60);
			CVar.FindCVar("udv_getred").SetInt(r);
			CVar.FindCVar("udv_getgreen").SetInt(g);
			CVar.FindCVar("udv_getblue").SetInt(b);
		}
		else
		{
			r = CVar.FindCVar("udv_getred").GetInt();
			g = CVar.FindCVar("udv_getgreen").GetInt();
			b = CVar.FindCVar("udv_getblue").GetInt();
		}

		int d0 = density;
		int d1 = density;
		int d2 = density;
		if (fograndom && density > 0)
		{
			d0 = random(0, density);
			d1 = random(0, density);
			d2 = random(0, density);
		}

		Color fade = density > 0 ? Color(255, r, g, b) : Color(255, 0, 0, 0);
		int count = level.Sectors.Size();
		for (int i = 0; i < count; i++)
			level.Sectors[i].SetFade(fade);

		if (density > 0)
		{
			level.ExecuteSpecial(157, null, null, false, FOGP_DENSITY, 64 * d0);
			level.ExecuteSpecial(157, null, null, false, FOGP_OUTSIDEDENSITY, 32 * d1);
			level.ExecuteSpecial(157, null, null, false, FOGP_SKYFOG, 32 * d2);
		}
		else
		{
			level.ExecuteSpecial(157, null, null, false, FOGP_DENSITY, 0);
			level.ExecuteSpecial(157, null, null, false, FOGP_OUTSIDEDENSITY, 0);
			level.ExecuteSpecial(157, null, null, false, FOGP_SKYFOG, 0);
		}
	}

	override void WorldLoaded(WorldEvent e)
	{
		ApplyFog();
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "dds_applyfog")
			ApplyFog();
	}
}
