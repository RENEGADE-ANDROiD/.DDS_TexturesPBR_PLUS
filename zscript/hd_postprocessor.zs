class hd_postprocessor : LevelPostProcessor
{

bool IsReLiteOn;  // Now this is an instance variable

	protected void Apply(Name checksum, String mapname)
	{
		// AddSectorTag does not add a tag if tag(s) are already assigned
		Texman texture;
		if (CVar.FindCVar("rl_ceilreflections").GetBool())
		{
			int tag = CVar.FindCvar("rl_ceil_tag").GetInt();
			// add tags
			string flatcheck = "|";
			string flat;
			Array<string> cvars = {"rl_ceil1","rl_ceil2","rl_ceil3","rl_ceil4","rl_ceil5","rl_ceil6","rl_ceil7","rl_ceil8","rl_ceil9","rl_ceil10"};
			foreach (s: cvars)
			{
				flat = CVar.FindCvar(s).GetString();
				CVar.FindCvar(s).SetString(flat.MakeUpper());
				flatcheck = String.Format("%s%s|",flatcheck,CVar.FindCvar(s).GetString());
			}
			foreach (sec: Level.Sectors) if (flatcheck.IndexOf(String.Format("|%s|",texture.GetName(sec.GetTexture(Sector.Ceiling)))) != -1) AddSectorTag(sec.SectorNum, tag);
		}
		if (CVar.FindCVar("rl_floorreflections").GetBool())
		{
			int tag = CVar.FindCvar("rl_floor_tag").GetInt();
			// add tags
			string flatcheck = "|";
			string flat;
			Array <string> cvars = {"rl_floor1","rl_floor2","rl_floor3","rl_floor4","rl_floor5","rl_floor6","rl_floor7","rl_floor8","rl_floor9","rl_floor10"};
			foreach (s: cvars)
			{
				flat = CVar.FindCvar(s).GetString();
				CVar.FindCvar(s).SetString(flat.MakeUpper());
				flatcheck = String.Format("%s%s|",flatcheck,CVar.FindCvar(s).GetString());
			}
			foreach (sec: Level.Sectors)	if (flatcheck.IndexOf(String.Format("|%s|",texture.GetName(sec.GetTexture(Sector.Floor)))) != -1) AddSectorTag(sec.SectorNum, tag);
		}
	}
}
