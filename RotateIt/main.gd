
extends Node2D

# member variables

var img_background = preload("res://gfx/background.png")
var block_sz = Vector2(48, 48)

var playground_sz = Vector2(300, 300)

const board_sz = Vector2(5, 5)

var start_block = Vector2(0, 0)

var scn_worker = preload("res://worker.scn")

var scn_fbridge_1way = preload("res://footbridge_1way.scn")
var scn_fbridge_2ways_90 = preload("res://footbridge_2ways_90.scn")
var scn_fbridge_2ways_180 = preload("res://footbridge_2ways_180.scn")
var scn_fbridge_3ways = preload("res://footbridge_3ways.scn")
var scn_fbridge_4ways = preload("res://footbridge_4ways.scn")

const ACT_LEFT  = 1
const ACT_RIGHT = 2
const ACT_UP    = 4
const ACT_DOWN  = 8
const ACT_APPLY = 16

const STAGE_MOVE_CURSOR = 0
const STAGE_APPLY_CURSOR = 1
const STAGE_WORKER = 2
var stage = STAGE_MOVE_CURSOR

const SEL_2X2_ROT_CW_90  = 1
const SEL_2X2_ROT_CCW_90 = 2
const SEL_2X1_ROT_CW_90  = 3
const SEL_2X1_ROT_CCW_90 = 4
const SEL_1X2_ROT_CW_90  = 5
const SEL_1X2_ROT_CCW_90 = 6

var selectors = [
	{ "type": SEL_2X2_ROT_CW_90,  "width": 2, "height": 2, "scn": preload("res://sel_2x2_rot_cw_90.scn")},
	{ "type": SEL_2X2_ROT_CCW_90, "width": 2, "height": 2, "scn": preload("res://sel_2x2_rot_ccw_90.scn")},
	{ "type": SEL_2X1_ROT_CW_90,  "width": 2, "height": 1, "scn": preload("res://sel_2x1_rot_cw_90.scn")},
	{ "type": SEL_2X1_ROT_CCW_90, "width": 2, "height": 1, "scn": preload("res://sel_2x1_rot_ccw_90.scn")},
	{ "type": SEL_1X2_ROT_CW_90,  "width": 1, "height": 2, "scn": preload("res://sel_1x2_rot_cw_90.scn")},
	{ "type": SEL_1X2_ROT_CCW_90, "width": 1, "height": 2, "scn": preload("res://sel_1x2_rot_ccw_90.scn")},
]

var fbridge_types = {
	"E": { "dir":"E", "scn": scn_fbridge_1way, "frame": 0},
	"S": { "dir":"S", "scn": scn_fbridge_1way, "frame": 4},
	"W": { "dir":"W", "scn": scn_fbridge_1way, "frame": 8},
	"N": { "dir":"N", "scn": scn_fbridge_1way, "frame": 12},
	
	"ES": { "dir":"ES", "scn": scn_fbridge_2ways_90, "frame": 0 },
	"SW": { "dir":"SW", "scn": scn_fbridge_2ways_90, "frame": 4 },
	"WN": { "dir":"WN", "scn": scn_fbridge_2ways_90, "frame": 8 },
	"NE": { "dir":"NE", "scn": scn_fbridge_2ways_90, "frame": 12 },
	
	"EW": { "dir":"EW", "scn": scn_fbridge_2ways_180, "frame": 0 },
	"SN": { "dir":"SN", "scn": scn_fbridge_2ways_180, "frame": 4 },
	"WE": { "dir":"WE", "scn": scn_fbridge_2ways_180, "frame": 0 },
	"NS": { "dir":"NS", "scn": scn_fbridge_2ways_180, "frame": 4 },
	
	"ESW": { "dir":"ESW", "scn": scn_fbridge_3ways, "frame": 0 },
	"SWN": { "dir":"SWN", "scn": scn_fbridge_3ways, "frame": 4 },
	"WNE": { "dir":"WNE", "scn": scn_fbridge_3ways, "frame": 8 },
	"NES": { "dir":"NES", "scn": scn_fbridge_3ways, "frame": 12 },

	"NESW": { "dir":"NESW", "scn": scn_fbridge_4ways, "frame": 0 },
	"ESWN": { "dir":"ESWN", "scn": scn_fbridge_4ways, "frame": 0 },
	"SWNE": { "dir":"SWNE", "scn": scn_fbridge_4ways, "frame": 0 },
	"WNES": { "dir":"WNES", "scn": scn_fbridge_4ways, "frame": 0 },
}


var elapsed_time = 0.0
var cur_stage_time = 0.0
var worker_upd = 0.0

var moving_workers = []

var board_map = []
var board_spr = [] # sprites
var fbridge_tab = [] # sprites
var cur_selector = null
var cur_selector_pos = Vector2(1, 1) # selector coord in block unit
var cur_selector_idx = 0

var old_act_key = 0

func resize():
	var root = get_tree().get_root()
	root.set_rect(Rect2(Vector2(0, 0), playground_sz))

func _ready():
	get_tree().connect("screen_resized", self, "resize")
	resize()

	# Initalization here
	old_act_key = 0
	set_process(true)
	
	# Create footbridges
	randomize()
	var fb_keys = fbridge_types.keys()
	fbridge_tab.resize(board_sz.y)
	for y in range(0, board_sz.y):
		var line = []
		line.resize(board_sz.x)
		fbridge_tab[y] = line
		for x in range(0, board_sz.x):
			var typ_name = fb_keys[randi() % fb_keys.size()]
			var fb = fbridge_types[typ_name].scn.instance()
			add_child(fb)
			fb.set_pos((start_block + Vector2(x, y)) * block_sz)
			fb.set_frame(fbridge_types[typ_name].frame)
#			fb.get_node("anim").play("rotate_endless")
			line[x] = [fb,typ_name]

	# Create workers
	board_spr.resize(board_sz.y)
	for y in range(0, board_sz.y):
		var line = []
		line.resize(board_sz.x)
		board_spr[y] = line
		for x in range(0, board_sz.x):
			var type = randi() % 10
			if type < 2:
				var wrkr
				if type == 0:
					wrkr = scn_worker.instance()
				else:
					wrkr = scn_worker.instance()
				add_child(wrkr)
				wrkr.set_pos((start_block + Vector2(x, y)) * block_sz + (block_sz/2))
				wrkr.get_node("sprite").get_node("anim").play("idle")
				line[x] = wrkr
#	print(board_spr)

	# Create initial selector
	cur_selector_pos = Vector2(0, 0)
	set_selector(randi() % selectors.size())
#	cur_selector_idx = 1
#	cur_selector = selectors[cur_selector_idx]["scn"].instance()
#	cur_selector = scn_sel_2x2_rot_ccw_90.instance()
#	cur_selector.set_pos((cur_selector_pos + start_block) * block_sz)
#	add_child(cur_selector)



func _draw():
	var iw = img_background.get_width()
	var ih = img_background.get_height()
	var xmax = (playground_sz.x + (iw - 1)) / iw
	var ymax = (playground_sz.y + (ih - 1)) / ih

	# Draw background
	for x in range(0, xmax):
		for y in range(0, ymax):
			draw_texture_rect(img_background, Rect2(Vector2(x*iw, y*ih), Vector2(iw, ih)), false)


var clockwise_map = { 'N': 'E', 'E': 'S', 'S': 'W', 'W': 'N' }
var counter_clockwise_map = { 'N': 'W', 'W': 'S', 'S': 'E', 'E': 'N' }

func rotate_fbridge_cw(x, y):
	var cur_name = fbridge_tab[y][x][1]
	var new_name = ""
	for idx in range(0, cur_name.length()):
		new_name += clockwise_map[cur_name[idx]]
	print("OLD:", cur_name, " NEW:", new_name)
	fbridge_tab[y][x][0].get_node("anim").play("rotate_"+cur_name[0]+"_to_"+new_name[0])
	fbridge_tab[y][x][1] = new_name

func rotate_fbridge_ccw(x, y):
	var cur_name = fbridge_tab[y][x][1]
	var new_name = ""
	for idx in range(0, cur_name.length()):
		new_name += counter_clockwise_map[cur_name[idx]]
	print("OLD:", cur_name, " NEW:", new_name)
	fbridge_tab[y][x][0].get_node("anim").play("rotate_"+cur_name[0]+"_to_"+new_name[0])
	fbridge_tab[y][x][1] = new_name

func move_selector_left():
	if cur_selector_pos.x  > 0:
		cur_selector_pos.x -= 1

func move_selector_right():
	if cur_selector_pos.x < board_sz.x - selectors[cur_selector_idx]["width"]:
		cur_selector_pos.x += 1

func move_selector_up():
	if cur_selector_pos.y  > 0:
		cur_selector_pos.y -= 1

func move_selector_down():
	if cur_selector_pos.y < board_sz.y - selectors[cur_selector_idx]["height"]:
		cur_selector_pos.y += 1

func apply_selector():
	var typ = selectors[cur_selector_idx]["type"]
	var p = cur_selector_pos # ease code readibility
	print("apply selector ", p)

	if typ == SEL_2X2_ROT_CW_90:
		rotate_fbridge_cw(p.x,   p.y)
		rotate_fbridge_cw(p.x,   p.y+1)
		rotate_fbridge_cw(p.x+1, p.y)
		rotate_fbridge_cw(p.x+1, p.y+1)
	elif typ == SEL_2X2_ROT_CCW_90:
		rotate_fbridge_ccw(p.x,   p.y)
		rotate_fbridge_ccw(p.x,   p.y+1)
		rotate_fbridge_ccw(p.x+1, p.y)
		rotate_fbridge_ccw(p.x+1, p.y+1)
	elif typ == SEL_2X1_ROT_CW_90:
		rotate_fbridge_cw(p.x,   p.y)
		rotate_fbridge_cw(p.x+1, p.y)
	elif typ == SEL_2X1_ROT_CCW_90:
		rotate_fbridge_ccw(p.x,   p.y)
		rotate_fbridge_ccw(p.x+1, p.y)
	elif typ == SEL_1X2_ROT_CW_90:
		rotate_fbridge_cw(p.x, p.y)
		rotate_fbridge_cw(p.x, p.y+1)
	elif typ == SEL_1X2_ROT_CCW_90:
		rotate_fbridge_ccw(p.x, p.y)
		rotate_fbridge_ccw(p.x, p.y+1)
	
	return

	if typ == SEL_2X2_ROT_CW_90:
		# 1-2      2-3
		# | |  =>  | |
		# 4-3      1-4
		var sp1 = board_spr[p.y][p.x]
		board_spr[p.y  ][p.x  ] = board_spr[p.y  ][p.x+1]
		board_spr[p.y  ][p.x+1] = board_spr[p.y+1][p.x+1]
		board_spr[p.y+1][p.x+1] = board_spr[p.y+1][p.x  ]
		board_spr[p.y+1][p.x  ] = sp1
	elif typ == SEL_2X2_ROT_CCW_90:
		# 1-2      4-1
		# | |  =>  | |
		# 4-3      3-2
		var sp1 = board_spr[p.y][p.x]
		board_spr[p.y  ][p.x  ] = board_spr[p.y+1][p.x  ]
		board_spr[p.y+1][p.x  ] = board_spr[p.y+1][p.x+1]
		board_spr[p.y+1][p.x+1] = board_spr[p.y  ][p.x+1]
		board_spr[p.y  ][p.x+1] = sp1
	
	for y in range(p.y, p.y + selectors[cur_selector_idx]["height"]):
		for x in range(p.x, p.x + selectors[cur_selector_idx]["width"]):
			if board_spr[y][x] != null:
				board_spr[y][x].set_pos((Vector2(x, y) + start_block) * block_sz + (block_sz/2))

func set_selector(idx):
	if cur_selector:
		remove_and_delete_child(cur_selector)
	cur_selector_idx = idx
#	cur_selector_pos = Vector2(0, 0)
	if cur_selector_pos.x > board_sz.x - selectors[cur_selector_idx]["width"]:
		cur_selector_pos.x = board_sz.x - selectors[cur_selector_idx]["width"]
	if cur_selector_pos.y > board_sz.y - selectors[cur_selector_idx]["height"]:
		cur_selector_pos.y = board_sz.y - selectors[cur_selector_idx]["height"]
	cur_selector = selectors[cur_selector_idx]["scn"].instance()
#	cur_selector = scn_sel_2x2_rot_ccw_90.instance()
	cur_selector.set_pos((cur_selector_pos + start_block) * block_sz)
	add_child(cur_selector)

func hide_selector():
	remove_and_delete_child(cur_selector)
	cur_selector = null

func build_worker_action():
	for y in range(0, board_sz.y):
		for x in range(0, board_sz.x):
			var spr = board_spr[y][x]
			if spr != null:
				# Check all directions in random order
				var rand_dir = randi()
				for check in range(0, 4):
					var cur_dir = (check + rand_dir) % 4
					if  cur_dir == 0 and x < (board_sz.x-1) and fbridge_tab[y][x][1].find('E')!=-1 and fbridge_tab[y][x+1][1].find('W')!=-1:
						# Go east
						moving_workers.append([spr, block_sz.x, 0, x, y, x+1, y])
						spr.get_node("sprite").get_node("anim").play("walk_E")
						break
					elif cur_dir == 1 and x > 0 and fbridge_tab[y][x][1].find('W')!=-1 and fbridge_tab[y][x-1][1].find('E')!=-1:
						# Go west
						moving_workers.append([spr, -block_sz.x, 0, x, y, x-1, y])
						spr.get_node("sprite").get_node("anim").play("walk_W")
						break
					elif cur_dir == 2 and y > 0 and fbridge_tab[y][x][1].find('N')!=-1 and fbridge_tab[y-1][x][1].find('S')!=-1:
						# Go north
						moving_workers.append([spr, 0, -block_sz.y, x, y, x, y-1])
						spr.get_node("sprite").get_node("anim").play("walk_N")
						break
					elif  cur_dir == 3 and y < (board_sz.y-1) and fbridge_tab[y][x][1].find('S')!=-1 and fbridge_tab[y+1][x][1].find('N')!=-1:
						# Go south
						moving_workers.append([spr, 0, block_sz.y, x, y, x, y+1])
						spr.get_node("sprite").get_node("anim").play("walk_S")
						break
	for wrk in moving_workers:
		board_spr[wrk[6]][wrk[5]] = wrk[0]
		board_spr[wrk[4]][wrk[3]] = null

func _process(delta):

	elapsed_time += delta
	cur_stage_time += delta

	if stage == STAGE_MOVE_CURSOR:
		var action_key = 0
		if Input.is_action_pressed("ui_down"):
			action_key = ACT_DOWN
			if not old_act_key & ACT_DOWN:
				move_selector_down()
		elif Input.is_action_pressed("ui_up"):
			action_key = ACT_UP
			if not old_act_key & ACT_UP:
				move_selector_up()
		
		if Input.is_action_pressed("ui_left"):
			action_key |= ACT_LEFT
			if not old_act_key & ACT_LEFT:
				move_selector_left()
		elif Input.is_action_pressed("ui_right"):
			action_key |= ACT_RIGHT
			if not old_act_key & ACT_RIGHT:
				move_selector_right()

		cur_selector.set_pos((cur_selector_pos + start_block) * block_sz)
		
		if Input.is_action_pressed("ui_accept"):
			action_key |= ACT_APPLY
			if not old_act_key & ACT_APPLY:
				apply_selector()
				stage = STAGE_APPLY_CURSOR
				hide_selector()
				cur_stage_time = 0.0
		
		old_act_key = action_key
	
	elif stage == STAGE_APPLY_CURSOR:
		if cur_stage_time > 0.5:
			build_worker_action()
			cur_stage_time -= 0.5
			stage = STAGE_WORKER
			worker_upd = 0.0

	elif stage == STAGE_WORKER:
		var remaining_worker = 0
		worker_upd += delta
		if worker_upd > 0.025:
			for w in moving_workers:
				if w[1] == 0 and w[2] == 0:
					continue
				var incx = 0
				if w[1] > 0:
					incx = 1
					w[1] -= 1
				elif w[1] < 0:
					incx = -1
					w[1] += 1
				var incy = 0
				if w[2] > 0:
					incy = 1
					w[2] -= 1
				elif w[2] < 0:
					incy = -1
					w[2] += 1
				# FIXME: do same for Y
				w[0].set_pos(w[0].get_pos() + Vector2(incx, incy))
				if w[1] == 0 and w[2] == 0:
					w[0].get_node("sprite").get_node("anim").play("idle")
				else:
					remaining_worker += 1
			worker_upd -= 0.025
			if remaining_worker == 0:
				set_selector(randi() % selectors.size())
				stage = STAGE_MOVE_CURSOR

	
	# Exit game?
	if(Input.is_action_pressed("exit")):
		OS.get_main_loop().quit()