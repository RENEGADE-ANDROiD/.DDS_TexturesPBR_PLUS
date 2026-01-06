class hd_sector
{
	int sec, light, volume, sources, total_light;
	double minx, maxx, miny, maxy;
	double centerZ, floorZ, ceilingZ, height, area;
	vector2 cspot;
	bool bspot;
	bool special;
	Array<string> textures;
	static const int stype[] = {Side.Top, Side.Mid, Side.Bottom};

	hd_sector init(Sector sec)
	{
		self.sec = sec.SectorNum;
		self.light = sec.LightLevel;
		self.cspot = polylabel(sec);
		self.floorZ = sec.FloorPlane.ZAtPoint(self.cspot);
		self.ceilingZ = sec.CeilingPlane.ZAtPoint(self.cspot);
		self.centerZ = self.floorZ + ((self.ceilingZ - self.floorZ) * 0.5);
		self.height = self.ceilingZ - self.floorZ;
		Array <int> LSpecials = { 21, 22, 23, 24, 1, 2, 3, 4, 65, 66, 67, 68, 76, 77, 197, 198, 199, 200 };
		self.special = LSpecials.Find(sec.Special) != LSpecials.Size();
		self.area = polygonarea(sec);
		self.volume = int(self.area * (sec.CeilingPlane.ZAtPoint(self.cspot) - sec.FloorPlane.ZAtPoint(self.cspot)) * .015625);
		self.minx = double.infinity; self.miny = double.infinity;
		self.maxx = -double.infinity; self.maxy = -double.infinity;
		Texman texture;
		foreach (lin: sec.Lines)
		{
			if (lin.delta.length() > 4)
			{
				int fside = (lin.FrontSector != sec) ? Line.Back : Line.Front;
				Side wall = lin.Sidedef[fside];
				foreach (sid: stype)
				{
					string t = texture.GetName(wall.GetTexture(sid));
					if (t == "") continue;
					if (self.textures.Find(t) == self.textures.Size()) self.textures.Push(t);
				}
			}
			self.minx = min(self.minx, lin.V1.P.x);
			self.miny = min(self.miny, lin.V1.P.y);
			self.maxx = max(self.maxx, lin.V1.P.x);
			self.maxy = max(self.maxy, lin.V1.P.y);
		}
		return self;
	}
	void getdim()
	{
		self.floorZ = Level.Sectors[self.sec].FloorPlane.ZAtPoint(self.cspot);
		self.ceilingZ = Level.Sectors[self.sec].CeilingPlane.ZAtPoint(self.cspot);
		self.centerZ = self.floorZ + ((self.ceilingZ - self.floorZ) * 0.5);
		self.height = self.ceilingZ - self.floorZ;
	}
	double shoelace(Array<double> x, Array<double> y)
	{
		double area;
		int j = x.Size() - 1;
		for (int i = 0; i < x.Size(); i++)
		{
			area += (x[j] + x[i]) * (y[j] - y[i]);
			j = i;
		}
		return abs(area * 0.5);
	}

	void nextperimeter(Sector sec, out Array<double> x, out Array<double> y, out Array<int> done)
	{
		// find lowest corner
		double xhead = double.infinity;
		double yhead = double.infinity;
		int min = -1;
		for (int i = 0; i < sec.Lines.Size(); i++)
		{
			if (done.Find(i) != done.Size()) continue;
			if (sec.Lines[i].V1.P.x < xhead && sec.Lines[i].V1.P.y < yhead)
			{
				xhead = sec.Lines[i].V1.P.x;
				yhead = sec.Lines[i].V1.P.y;
				min = i;
			}
		}
		done.Push(min);
		x.Push(xhead);
		y.Push(yhead);
		double xtail = sec.Lines[min].V2.P.x;
		double ytail = sec.Lines[min].V2.P.y;
		double vangle = VectorAngle(sec.Lines[min].delta.x, sec.Lines[min].delta.y);
		double xlast, ylast;
		// stitch the perimeter
		while (xtail != xhead || ytail != yhead)
		{
			xlast = xtail;
			ylast = ytail;
			for (int i = 0; i < sec.Lines.Size(); i++)
			{
				if (done.Find(i) != done.Size()) continue;
				Line lin = sec.Lines[i];
				// match the tail
				if (lin.V1.P.x ~== xtail && lin.V1.P.y ~== ytail)
				{
					done.Push(i);
					xtail = lin.V2.P.x;
					ytail = lin.V2.P.y;
					if (vangle ~== VectorAngle(lin.delta.x, lin.delta.y)) break;
					vangle = VectorAngle(lin.delta.x, lin.delta.y);
					x.Push(lin.V1.P.x);
					y.Push(lin.V1.P.y);
					break;
				}
				if (lin.V2.P.x ~== xtail && lin.V2.P.y ~== ytail) // line turned around
				{
					done.Push(i);
					xtail = lin.V1.P.x;
					ytail = lin.V1.P.y;
					if (vangle ~== VectorAngle(lin.delta.x, lin.delta.y)) break;
					vangle = VectorAngle(lin.delta.x, lin.delta.y);
					x.Push(lin.V2.P.x);
					y.Push(lin.V2.P.y);
					break;
				}
			}
			if (xlast == xtail && ylast == ytail) break;
		}
		return;
	}
	double polygonArea(Sector sec)
	{
		if (sec.Lines.Size() < 3) return 0.0; // map 21 of Doom 2
		Array<double> x;
		Array<double> y;
		Array<int> done;
		nextperimeter(sec, x, y, done);
		double area = shoelace(x, y);
		double inner = 0;
		while (sec.Lines.Size() > done.Size())
		{
			x.Clear();
			y.Clear();
			nextperimeter(sec, x, y, done);
			inner += shoelace(x, y);
		}
		return abs((area - inner) * .00694);
	}
	vector2 polylabel(Sector sec)
	{
		// find bounding box
		double minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
		Array<double> vx;
		Array<double> vy;
		for (int i = 0; i < sec.Lines.Size(); i++)
		{
			Line lin = sec.Lines[i];
			double x1 = lin.V1.P.x;
			double y1 = lin.V1.P.y;
			double x2 = lin.V2.P.x;
			double y2 = lin.V2.P.y;
			bool b = false;
			for (int j = 0; j < vx.Size(); j++)
			{
				if (vx[j] ~== x1 && vy[j] ~== y1)
				{
					vx.Push(x2);
					vy.Push(y2);
					b = true;
					break;
				}
			}
			if (!b)
			{
				vx.Push(x1);
				vy.Push(y1);
			}
		}
		// check for rectangle
		Array<double> x;
		Array<double> y;
		Array<int> done;
		nextperimeter(sec, x, y, done);
		if (x.Size() == 4)
		{
			return sec.CenterSpot;
		}
		if (vx.Size() == 3)
		{
			return ((vx[0] + vx[1] + vx[2]) * 0.3333, (vy[0] + vy[1] + vy[2]) * 0.3333);
		}
		for (int i = 0; i < vx.Size(); i++)
		{
			if (vx[i] < minx) minx = vx[i];
			if (vx[i] > maxx) maxx = vx[i];
			if (vy[i] < miny) miny = vy[i];
			if (vy[i] > maxy) maxy = vy[i];
		}
		double polywidth = abs(maxX - minX);
		double polyheight = abs(maxY - minY);
		double cellSize = polywidth > polyheight ? polywidth : polyheight; // online this is Math.min(width, height)
		double h = cellSize * 0.5;
		double minh = cellSize * .125 < 16 ? 16 : cellSize * .125;
		double precision = minh * 0.1;
		hd_polycell pcell;
		// start with center spot
		let bestCell = new("hd_polycell").init(sec.CenterSpot.x, sec.CenterSpot.y, h, vx, vy, sec);
		// get initial cells
		Array<hd_polycell> cells;
		for (double x = MinX; x < MaxX; x += cellSize)
		{
			for (double y = MinY; y < MaxY; y += cellSize)
			{
				cells.Push(new("hd_polycell").init(x + h, y + h, h, vx, vy, sec));
			}
		}
		int j = cells.Size();
		int numProbes = cells.Size();
		while (cells.Size())
		{
			// find best cell
			double qD = 0;
			int nD = 0;
			int j = 0;
			while (j < cells.Size())
			{
				if (cells[j].D != cells[j].D) // delete nan
				{
					cells.Delete(j);
				}
				else if (cells[j].D > qD)
				{
					qD = cells[j].D;
					nD = j;
				}
				j++;
			}
			if (cells.Size() == 0) break;
			let compareCell = cells[nD];
			cells.Delete(nD);
			double d = bestCell.D;
			if (compareCell.D > bestCell.D) bestCell = compareCell;
			if (compareCell.Max - d <= precision || h < minh) continue;
			// drill down and split the cell into 4
			h = compareCell.H * 0.5;
			int i = cells.Size();
			cells.Push(new("hd_polycell").init(compareCell.x - h, compareCell.y - h, h, vx, vy, sec));
			cells.Push(new("hd_polycell").init(compareCell.x - h, compareCell.y + h, h, vx, vy, sec));
			cells.Push(new("hd_polycell").init(compareCell.x + h, compareCell.y - h, h, vx, vy, sec));
			cells.Push(new("hd_polycell").init(compareCell.x + h, compareCell.y + h, h, vx, vy, sec));
			numProbes += cells.Size() - i;
		}
		return (bestCell.X, bestCell.Y);
	}
}

