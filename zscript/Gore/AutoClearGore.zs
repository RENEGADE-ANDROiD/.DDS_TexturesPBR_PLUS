
class PB_AutoClearGore_Handler : EventHandler
{
	int secondsValue;
	bool alertme, enabled;
	
	override void WorldTick() {
		secondsValue = CVar.GetCVar("pb_sv_goreclearinterval").GetInt() * TICRATE; //TICRATE by default is 35, if this is not 35 something is seriously wrong
		alertme = CVar.GetCvar("pb_sv_alertclear").GetBool();
		enabled = CVar.GetCvar("pb_sv_autocleargore").GetBool();
		
		if(enabled && (gametic % secondsValue == 0)) {
			NashGoreStatics.ClearGore(); //wish i could make it only clear old gore and not whatever exists
			if(alertme) console.printf("Cleared all gore"); 
		}
	}
	
	override void WorldLoaded(WorldEvent e)
	{
		secondsValue = CVar.GetCVar("pb_sv_goreclearinterval").GetInt() * 35;
		alertme = CVar.GetCvar("pb_sv_alertclear").GetBool();
		enabled = CVar.GetCvar("pb_sv_autocleargore").GetBool();
	}
}