class_name ArenaMaps
extends RefCounted

const WIDTH=3200.0
const HEIGHT=1800.0
const NAMES=["THE HOLLOW","ROOTBOUND RUINS","EMBER QUARRY"]
const SUBTITLES=["Buried catacombs. Broken arches. A fight on every level.","A forgotten temple, swallowed by the earth.","Old mine shafts cut through a volcanic canyon."]
const ACCENTS=[Color("e5b66b"),Color("9dcc89"),Color("ed9562")]
const PALETTES=[
	[Color("332c2a"),Color("665144"),Color("967458"),Color("b4926a"),Color("28282b")],
	[Color("252f2b"),Color("4c5941"),Color("7f8c58"),Color("bdba83"),Color("1c2827")],
	[Color("352727"),Color("705041"),Color("a87650"),Color("dbad75"),Color("2a2527")]
]
static var cache: Dictionary={}

static func polygon(points: Array, material: int=0) -> Dictionary:
	return {"points":PackedVector2Array(points),"material":material}

static func shelf(x: float,y: float,width: float,depth: float,seed_value: int=1,material: int=0) -> Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	var points: Array=[Vector2(x,y)]
	var pieces=maxi(3,int(width/70))
	for j in range(1,pieces):points.append(Vector2(x+width*j/pieces,y+rng.randf_range(-8,8)))
	points.append(Vector2(x+width,y+5))
	points.append(Vector2(x+width-16,y+depth*0.64))
	for j in range(pieces,-1,-1):points.append(Vector2(x+width*j/pieces,y+depth+rng.randf_range(-19,16)))
	points.append(Vector2(x+12,y+depth*0.38))
	return polygon(points,material)

static func block(x: float,y: float,w: float,h: float,material: int=1) -> Dictionary:
	return polygon([Vector2(x+12,y),Vector2(x+w-15,y+4),Vector2(x+w,y+14),Vector2(x+w-4,y+h-10),Vector2(x+w-17,y+h),Vector2(x+6,y+h-4),Vector2(x,y+16)],material)

static func shape(poly: PackedVector2Array) -> Dictionary:
	var bounds=Rect2(poly[0],Vector2.ZERO)
	for v in poly:bounds=bounds.expand(v)
	var axes: Array=[Vector2.RIGHT,Vector2.DOWN]
	for j in range(poly.size()):
		var edge=poly[(j+1)%poly.size()]-poly[j]
		if edge.length_squared()>0.01:axes.append(Vector2(-edge.y,edge.x).normalized())
	var slabs: Array=[]
	for axis in axes:
		var low=INF;var high=-INF
		for point in poly:
			var projection=point.dot(axis);low=minf(low,projection);high=maxf(high,projection)
		slabs.append(Vector3(axis.x,axis.y,low));slabs.append(Vector3(axis.x,axis.y,high))
	return {"bounds":bounds,"points":poly,"slabs":slabs}

static func _compile(terrain: Array) -> Array:
	var result: Array=[]
	for piece in terrain:
		var parts=Geometry2D.decompose_polygon_in_convex(piece.points)
		for part in parts:result.append(shape(part))
	return result

static func data(index: int) -> Dictionary:
	index=clampi(index,0,2)
	if cache.has(index):return cache[index]
	var terrain: Array=[]
	# Continuous geological strata enclose the arena; ledges have irregular outlines.
	terrain.append(shelf(0,1730,3200,160,921+index))
	terrain.append(polygon([Vector2(0,0),Vector2(90,0),Vector2(125,310),Vector2(94,690),Vector2(115,1120),Vector2(90,1735),Vector2(0,1800)]))
	terrain.append(polygon([Vector2(3115,0),Vector2(3200,0),Vector2(3200,1800),Vector2(3095,1730),Vector2(3078,1280),Vector2(3105,870),Vector2(3083,440)]))
	var spawns: Array=[];var loot: Array=[];var lamps: Array=[];var props: Array=[]
	if index==0:
		# Three overlapping routes through a ruined underground ossuary.
		terrain.append(shelf(85,360,610,140,11))
		terrain.append(shelf(2480,365,650,145,12))
		terrain.append(shelf(1020,270,1140,120,13,1))
		terrain.append(shelf(340,725,590,145,14))
		terrain.append(shelf(1210,690,720,170,15,1))
		terrain.append(shelf(2240,720,600,160,16))
		terrain.append(shelf(75,1110,620,170,17))
		terrain.append(shelf(940,1080,490,150,18))
		terrain.append(shelf(1760,1080,490,150,19))
		terrain.append(shelf(2510,1110,610,170,20))
		terrain.append(shelf(370,1430,700,170,21))
		terrain.append(shelf(2100,1430,700,180,22))
		terrain.append(shelf(1295,1400,610,110,23,1))
		# Real inclined routes between ledges, with collision following the slope.
		terrain.append(polygon([Vector2(695,1110),Vector2(940,940),Vector2(1040,965),Vector2(800,1200)],1))
		terrain.append(polygon([Vector2(2210,955),Vector2(2505,1110),Vector2(2390,1190),Vector2(2130,1010)],1))
		# Curved masonry arches: walk / fly through the empty opening.
		for center in [Vector2(1590,650),Vector2(1600,1365)]:
			for j in range(9):
				var a=PI+j*PI/9;var b=PI+(j+1)*PI/9
				terrain.append(polygon([center+Vector2.from_angle(a)*190,center+Vector2.from_angle(b)*190,center+Vector2.from_angle(b)*145,center+Vector2.from_angle(a)*145],1))
		spawns=[Vector2(270,310),Vector2(2890,310),Vector2(570,675),Vector2(2600,675),Vector2(1120,1030),Vector2(2060,1030),Vector2(680,1380),Vector2(2520,1380)]
		lamps=[Vector2(480,610),Vector2(2720,610),Vector2(1300,970),Vector2(1910,970),Vector2(1580,1580),Vector2(530,1590),Vector2(2690,1590)]
		props=[Vector3(520,1717,0),Vector3(640,1718,1),Vector3(2630,1718,0),Vector3(1420,1378,2),Vector3(1820,1378,2),Vector3(430,704,3),Vector3(2680,700,3)]
	elif index==1:
		terrain.append(shelf(80,395,620,145,41))
		terrain.append(shelf(2500,395,630,160,42))
		terrain.append(shelf(1090,340,1020,190,43,1))
		terrain.append(shelf(300,800,650,175,44))
		terrain.append(shelf(2240,800,660,170,45))
		terrain.append(shelf(1200,850,800,120,46,1))
		terrain.append(shelf(75,1200,660,150,47))
		terrain.append(shelf(2480,1200,645,150,48))
		terrain.append(shelf(940,1240,530,145,49))
		terrain.append(shelf(1750,1240,530,145,50))
		terrain.append(shelf(500,1510,550,130,51))
		terrain.append(shelf(2110,1510,550,135,52))
		terrain.append(shelf(1320,1570,560,100,53,1))
		terrain.append(polygon([Vector2(820,1240),Vector2(1160,1000),Vector2(1250,1020),Vector2(960,1300)]))
		terrain.append(polygon([Vector2(1950,1015),Vector2(2310,1250),Vector2(2180,1320),Vector2(1890,1080)]))
		for x in [1420,1710]:terrain.append(block(x,640,65,210,1))
		spawns=[Vector2(260,340),Vector2(2910,340),Vector2(570,750),Vector2(2650,750),Vector2(1140,1190),Vector2(1830,1180),Vector2(700,1460),Vector2(2400,1460)]
		lamps=[Vector2(620,675),Vector2(2600,675),Vector2(1580,725),Vector2(1280,1120),Vector2(1940,1120),Vector2(1570,1440)]
		props=[Vector3(1420,1715,2),Vector3(1780,1715,2),Vector3(540,1488,3),Vector3(2420,1488,3),Vector3(450,1714,0),Vector3(2760,1714,0)]
	else:
		terrain.append(shelf(80,420,670,190,71))
		terrain.append(shelf(2440,420,685,190,72))
		terrain.append(shelf(1230,290,740,200,73))
		terrain.append(shelf(390,820,680,140,74))
		terrain.append(shelf(2130,820,690,140,75))
		terrain.append(shelf(1290,840,620,110,76,2))
		terrain.append(shelf(80,1200,720,170,77))
		terrain.append(shelf(2400,1200,720,170,78))
		terrain.append(shelf(1050,1230,1100,190,79))
		terrain.append(shelf(380,1500,580,140,80))
		terrain.append(shelf(2240,1500,580,140,81))
		terrain.append(polygon([Vector2(800,1200),Vector2(1080,1040),Vector2(1200,1080),Vector2(940,1280)],2))
		terrain.append(polygon([Vector2(2050,1050),Vector2(2400,1200),Vector2(2260,1280),Vector2(1940,1110)],2))
		spawns=[Vector2(270,365),Vector2(2890,365),Vector2(610,770),Vector2(2560,770),Vector2(1180,1180),Vector2(1780,1175),Vector2(610,1450),Vector2(2580,1450)]
		lamps=[Vector2(620,695),Vector2(2580,695),Vector2(1570,705),Vector2(1250,1100),Vector2(1950,1100),Vector2(1550,1580)]
		props=[Vector3(500,1714,4),Vector3(2670,1714,4),Vector3(1190,1205,4),Vector3(2000,1205,4),Vector3(680,797,0),Vector3(2450,797,0)]
	# Connected cave masses and low, fractured ceilings create rooms rather than
	# a stack of detached rectangular platforms. Open shafts remain between them.
	terrain.append(polygon([Vector2(0,0),Vector2(3200,0),Vector2(3200,150),Vector2(2960,155),Vector2(2760,110),Vector2(2510,140),Vector2(2330,80),Vector2(1990,100),Vector2(1720,65),Vector2(1430,100),Vector2(1160,70),Vector2(840,130),Vector2(600,100),Vector2(370,160),Vector2(120,145),Vector2(0,175)]))
	var base_y=[820,900,920][index]
	var column=PackedVector2Array([Vector2(350,base_y),Vector2(450,base_y-5),Vector2(500,base_y+70),Vector2(453,base_y+160),Vector2(490,base_y+300),Vector2(350,base_y+310),Vector2(365,base_y+180),Vector2(330,base_y+90)])
	terrain.append({"points":column,"material":0})
	var mirrored=PackedVector2Array()
	for j in range(column.size()-1,-1,-1):mirrored.append(Vector2(WIDTH-column[j].x,column[j].y))
	terrain.append({"points":mirrored,"material":0})
	if index==0:
		var mass=PackedVector2Array([Vector2(90,1180),Vector2(450,1240),Vector2(530,1340),Vector2(470,1440),Vector2(340,1550),Vector2(90,1620)])
		terrain.append({"points":mass,"material":0})
		var mirrored_mass=PackedVector2Array()
		for j in range(mass.size()-1,-1,-1):mirrored_mass.append(Vector2(WIDTH-mass[j].x,mass[j].y))
		terrain.append({"points":mirrored_mass,"material":0})
	# Distinct weapons are actually collected, rather than all being granted on spawn.
	var anchors=[spawns[0]+Vector2(170,14),spawns[1]+Vector2(-170,14),spawns[2]+Vector2(120,14),spawns[3]+Vector2(-120,14),spawns[4]+Vector2(90,14),spawns[5]+Vector2(-90,14),Vector2(1590,230),Vector2(1590,1675)]
	for j in range(anchors.size()):loot.append({"kind":"gun","item":1+j%5,"p":anchors[j]})
	for j in range(3):
		loot.append({"kind":"grenade","item":j,"p":spawns[2+j]+Vector2(-85,12)})
		loot.append({"kind":"grenade","item":j,"p":spawns[5+j]+Vector2(60,12)})
	for p in [Vector2(260,1670),Vector2(2940,1670),spawns[6]+Vector2(90,10),spawns[7]+Vector2(-90,10)]:loot.append({"kind":"health","item":0,"p":p})
	if index==1:
		loot[7].p=Vector2(1590,1528)
		loot[12].p=Vector2(1340,1198)
	var positions: Array=[]
	for item in loot:positions.append(item.p)
	var result={"terrain":terrain,"platforms":_compile(terrain),"spawns":spawns,"loot":loot,"pickups":positions,"lamps":lamps,"props":props,"width":WIDTH,"height":HEIGHT}
	result.nav=_navigation(result.platforms)
	cache[index]=result
	return result

static func _navigation(shapes: Array) -> AStarGrid2D:
	var grid=AStarGrid2D.new()
	grid.region=Rect2i(0,0,40,23);grid.cell_size=Vector2(80,80);grid.offset=Vector2(40,40)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in range(23):
		for x in range(40):
			var p=Vector2(x*80+40,y*80+40);var blocked=p.y>HEIGHT-35
			for shape in shapes:
				if not shape.bounds.grow(32).has_point(p):continue
				var overlap=true
				for j in range(0,shape.slabs.size(),2):
					var slab: Vector3=shape.slabs[j];var axis=Vector2(slab.x,slab.y)
					var value=p.dot(axis);var extent=20*absf(axis.x)+30*absf(axis.y)
					if value+extent<=slab.z or value-extent>=shape.slabs[j+1].z:overlap=false;break
				if overlap:blocked=true;break
			grid.set_point_solid(Vector2i(x,y),blocked)
	return grid

static func navigation_cell(map: Dictionary,p: Vector2) -> Vector2i:
	var grid: AStarGrid2D=map.nav
	var origin=Vector2i(clampi(int(p.x/80),0,39),clampi(int(p.y/80),0,22))
	if not grid.is_point_solid(origin):return origin
	var best=origin;var distance=INF
	for radius in range(1,5):
		for y in range(maxi(0,origin.y-radius),mini(22,origin.y+radius)+1):
			for x in range(maxi(0,origin.x-radius),mini(39,origin.x+radius)+1):
				var id=Vector2i(x,y)
				if grid.is_point_solid(id):continue
				var d=p.distance_squared_to(Vector2(x*80+40,y*80+40))
				if d<distance:distance=d;best=id
		if distance<INF:return best
	return best
