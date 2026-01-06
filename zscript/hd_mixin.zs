mixin class mGeo
{
    bool IsInsideSector(Sector sec, double x, double y)
    {
        let result = Level.PointInSector((x, y));
        if (result == sec) return Level.IsPointInLevel((x, y, sec.floorplane.ZatPoint((x, y))));
        return false;
    }
	vector2 getMiddle(Line lin)
	{
		return ((lin.V1.P.x + lin.V2.P.x) * 0.5, (lin.V1.P.y + lin.V2.P.y) * 0.5);
	}
	vector2 frontLine(Line lin, double d = 1.1)
	{
		vector2 lindir = lin.delta.Unit();
		vector2 point = Level.Vec2Offset(lin.V1.P, lindir * (lin.delta.length() * 0.5) + (lindir.Y, -lindir.X) * d); // 2
		return point;
	}
	double lightAngle(vector2 p1, vector2 p2)
	{
		vector3 delta = (p1.x - p2.x, p1.y - p2.y, 0);
		return atan2(delta.y, delta.x);
	}
	Sector backSector(Sector sec, Line lin)
	{
		if (lin.Flags & Line.ML_TWOSIDED)
		{
			if (lin.BackSector != sec) return lin.BackSector;
			if (lin.FrontSector != sec) return lin.FrontSector;
		}
		return null;
	}
	int, int, color brightest(Sector sec)
	{
		// find brightest adjacent sector
		int min = 256;
		int max = -1;
		int len = -1;
		color bc = color("white");
		foreach (lin: sec.Lines)
		{
			len = max(len, lin.delta.length());
			Sector bsec = backSector(sec, lin);
			if (bsec)
			{
				if (bsec.LightLevel > max && bsec.ColorMap.LightColor != color("white")) bc = bsec.ColorMap.LightColor;
				min = min(min, bsec.LightLevel);
				max = max(max, bsec.LightLevel);
			}
		}
		return min, max, bc;
	}
	bool, double, double window(Sector sec, bool lightbox = true)
	{
		int sill = 0;
		double f_min = double.infinity;
		double c_max = -double.infinity;

		if (sec.Lines.Size() < 4 && !lightbox) return false, 0, 0; // test.................... was != 4

		foreach (lin : sec.Lines)
		{
			Sector bsec = backSector(sec, lin);
			if (bsec)
			{
				vector2 v2 = Level.Vec2Offset(lin.V1.P, lin.delta.Unit() * lin.delta.length() * 0.5);
				double f_secZ = sec.FloorPlane.ZAtPoint(v2);
				double f_bsecZ = bsec.FloorPlane.ZAtPoint(v2);
				double c_secZ = sec.CeilingPlane.ZAtPoint(v2);
				double c_bsecZ = bsec.CeilingPlane.ZAtPoint(v2);
				double f_diff = f_secZ - f_bsecZ;
				double c_diff = c_secZ - c_bsecZ;

				if (((f_diff > 8.0 || c_diff < -8.0) && lightbox) || ((f_diff > 8.0 && c_diff < -8.0) && !lightbox))
				{
					f_min = min(f_min, f_bsecZ);
					c_max = max(c_max, c_bsecZ);
					sill++;
				}
			}
		}
		return sill > (lightbox ? 0 : 1), f_min, c_max;
	}
	bool steps(Sector sec)
	{
		bool bUp=false, bDown=false;
		foreach (lin : sec.Lines)
		{
			Sector bsec = backSector(sec, lin);
			if (bsec)
			{
				vector2 v2 = Level.Vec2Offset(lin.V1.P, lin.delta.Unit() * lin.delta.length() * 0.5);
				double secZ = sec.FloorPlane.ZAtPoint(v2);
				double bsecZ = bsec.FloorPlane.ZAtPoint(v2);
				if (bsecZ > secZ) bUp = true;
				if (bsecZ < secZ) bDown = true;
			}
			if (bUp && bDown) break;
		}
		return bUp && bDown;
	}
}

mixin class mColor
{
	int perceived(Color c)
	{
		double r = c.r * 1.0, g = c.g * 1.0, b = c.b * 1.0;
		return clamp(int(sqrt(0.299 * (r * r) + 0.587 * (g * g) + 0.114 * (b * b))), 0, 255);
	}
	bool, int, int, int, int keepthecolor(Color c , int p = -1, int hr = -1, int hg = -1, int hb = -1)
	{
		if (p == -1) p = CVar.FindCvar("rl_perceived").GetInt();
		if (hr == -1) hr = CVar.FindCvar("rl_howred").GetInt();
		if (hg == -1) hg = CVar.FindCvar("rl_howgreen").GetInt();
		if (hb == -1) hb = CVar.FindCvar("rl_howblue").GetInt();

		double r = c.r * 1.0, g = c.g * 1.0, b = c.b * 1.0;
		int perceived = perceived(c);
		int howred = (r > g && r > b && r > hr) ? int(r / 255.0 * 100) : 0;
		int howgreen = (g > r && g > b && g > hg) ? int(g / 255.0 * 100) : 0;
		int howblue = (b > r && b > g && b > hb) ? int(b / 255.0 * 100) : 0;

		return (perceived > p || howred || howgreen || howblue), perceived, howred, howgreen, howblue;
	}
	color blend(color c1, color c2)
	{
		double c1r = c1.r * 1.0, c1g = c1.g * 1.0, c1b = c1.b * 1.0, c2r = c2.r * 1.0, c2g = c2.g * 1.0, c2b = c2.b * 1.0;
		int r = int(sqrt((c1r * c1r + c2r * c2r) / 2));
		int g = int(sqrt((c1g * c1g + c2g * c2g) / 2));
		int b = int(sqrt((c1b * c1b + c2b * c2b) / 2));
		return Color(r, g, b);
	}
	color shade(color c, double luma)
	{
		double hue, saturation, value;
		[hue, saturation, value] = get_hsv(c);
		int r, g, b;
		double shade = clamp(value * (1 + luma), 0, 100);
		[r, g, b] = get_rgb(hue, saturation, shade);
		return Color(r, g, b);
	}
	color saturate(color c, double luma)
	{
		double hue, saturation, value;
		[hue, saturation, value] = get_hsv(c);
		int r, g, b;
		double sat = clamp(saturation * (1 + luma), 0, 100);
		[r, g, b] = get_rgb(hue, sat, value);
		return Color(r, g, b);
	}
	int, int, int get_rgb(double h, double s, double v)
	{
		h /= 360;
		s /= 100;
		v /= 100;
		double r, g, b, i, f, p, q, t;
		i = int(h * 6);
		f = h * 6 - i;
		p = v * (1 - s);
		q = v * (1 - f * s);
		t = v * (1 - (1 - f) * s);
		switch (i % 6)
		{
			case 0: r = v; g = t; b = p; break;
			case 1: r = q; g = v; b = p; break;
			case 2: r = p; g = v; b = t; break;
			case 3: r = p; g = q; b = v; break;
			case 4: r = t; g = p; b = v; break;
			case 5: r = v; g = p; b = q; break;
		}
		return int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5);
	}
	double, double, double get_hsv(color c)
	{
		double r = c.r / 255.0;
		double g = c.g / 255.0;
		double b = c.b / 255.0;
		double min = min(min(r, g), b);
		double max = max(max(r, g), b);
		double delta = max - min;
		double h, s, v;
		v = max;
		double hue = min == max ? 0 : max == r ? (g - b) / (max - min) : max == g ? 2.0 + (b - r) / (max - min) : 4.0 + (r - g) / (max - min);
		hue *= 60;
		if (hue < 0) hue += 360;
		double saturation = max == 0 ? 0 : (1.0 - (min / max)) * 100;
		return hue, saturation, max * 100;
	}
	double adj_hue(double h)
	{
		return int(h / 5 + 0.5) * 5;
	}
	double avg_hue(double h1, double h2) // simple clockwise average
	{
		double avg = adj_hue((h1 + h2) / 2.0);
console.printf("h1 %f h2 %f avg %f", h1, h2, avg);
		return avg;
	}
}
