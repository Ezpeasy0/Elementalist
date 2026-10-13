extends Node2D

var game_status = 0

var w = 10
var h = 20
var sz = 40
var bg_w = 400

@export var tex_background: Texture2D
@export var tex_water: Texture2D
@export var tex_fire: Texture2D
@export var tex_earth: Texture2D
@export var tex_wind: Texture2D
@export var tex_ice: Texture2D

@export var bg_music: AudioStream
@export var sfx_drop: AudioStream
@export var sfx_clear: AudioStream
@export var sfx_skill: AudioStream

var music_play: AudioStreamPlayer
var sound_play: AudioStreamPlayer

var map_data = []
var px = 0
var py = 0
var c1 = 0
var c2 = 0 

var t = 0.0
var my_score = 0
var my_mana = 0
var timer = 180.0
var is_die = false
var is_win = false 

var doing_anim = false
var del_list = []
var blink_t1 = 0.0
var blink_t2 = 0.0
var show_blink = true
var del_mode = 1 

var color_code = {
	0: Color.BLACK,
	1: Color("00bfff"), 
	2: Color("ff4500"), 
	3: Color("8b4513"), 
	4: Color("a9a9a9"), 
	5: Color("00ffff")  
}

var pics = {}

func _ready():
	pics[1] = tex_water
	pics[2] = tex_fire
	pics[3] = tex_earth
	pics[4] = tex_wind
	pics[5] = tex_ice
	
	music_play = AudioStreamPlayer.new()
	add_child(music_play)
	if bg_music != null:
		music_play.stream = bg_music
		music_play.play()
		
	sound_play = AudioStreamPlayer.new()
	add_child(sound_play)
	
	for i in range(h):
		var row = []
		for j in range(w):
			row.append(0)
		map_data.append(row)

func start_game():
	my_score = 0
	my_mana = 0
	timer = 180.0
	is_die = false
	is_win = false
	doing_anim = false
	del_list.clear()
	
	for i in range(h):
		for j in range(w):
			map_data[i][j] = 0
			
	game_status = 1
	create_block()

func create_block():
	px = (w / 2) - 1 
	py = 0

	c1 = randi() % 5 + 1
	c2 = randi() % 5 + 1
	
	if map_data[0][px] != 0 or map_data[0][px + 1] != 0:
		is_die = true
		game_status = 3

func _process(delta):
	if game_status != 1:
		queue_redraw()
		return
		
	timer -= delta
	if timer <= 0:
		is_die = true
		game_status = 3 
		
	if doing_anim == true:
		blink_t1 += delta
		blink_t2 += delta
		
		if blink_t2 >= 0.1:
			show_blink = not show_blink
			blink_t2 = 0.0
			
		if blink_t1 >= 0.5:
			doing_anim = false
			
			if del_mode == 1:
				var count = del_list.size()
				my_score += count * 100
				
				my_mana = my_mana + (count * 5)
				if my_mana > 100:
					my_mana = 100 
				
				if my_score >= 7000:
					is_win = true
					game_status = 3
			
			for p in del_list:
				map_data[p.y][p.x] = 0
				
			block_fall_down()
			
			var matches = check_match()
			if matches.size() > 0:
				del_list = matches
				doing_anim = true
				blink_t1 = 0.0
				blink_t2 = 0.0
				show_blink = true
				del_mode = 1
				
				if sound_play != null and sfx_clear != null:
					sound_play.stream = sfx_clear
					sound_play.play()
			else:
				if c1 == 0:
					create_block()
				
		queue_redraw()
		return 

	var speed = 0.5
	if Input.is_physical_key_pressed(KEY_DOWN):
		speed = 0.05
	
	t += delta
	
	if t >= speed:
		t = 0
		if hit_wall_or_block(px, py + 1) == false:
			py += 1
		else:
			place_block()
			
	queue_redraw()

func _input(event):
	if event.is_pressed() == false:
		return
		
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
			return
			
		if event.keycode == KEY_ENTER:
			if game_status == 0 or game_status == 3:
				start_game()
			elif game_status == 1:
				game_status = 2 
			elif game_status == 2:
				game_status = 1 
			queue_redraw()
			return
			
		if game_status == 1:
			if event.keycode == KEY_LEFT:
				if doing_anim == false:
					if hit_wall_or_block(px - 1, py) == false:
						px -= 1
			elif event.keycode == KEY_RIGHT:
				if doing_anim == false:
					if hit_wall_or_block(px + 1, py) == false:
						px += 1
			elif event.keycode == KEY_UP:
				if doing_anim == false and c1 != 0:

					var tmp = c1
					c1 = c2
					c2 = tmp
			elif event.keycode == KEY_1: 
				if doing_anim == false and my_mana >= 20 and c1 != 0:
					my_mana -= 20
					c1 = randi() % 5 + 1
					c2 = randi() % 5 + 1
					if sound_play != null:
						sound_play.stream = sfx_skill
						sound_play.play()
			elif event.keycode == KEY_2: 
				if doing_anim == false and my_mana >= 100:
					var target_list = []
					var row_y = h - 1
					
					while row_y >= 0:
						for col_x in range(w):
							if map_data[row_y][col_x] != 0:
								target_list.append(Vector2(col_x, row_y))
						if target_list.size() > 0:
							break
						row_y -= 1
						
					if target_list.size() > 0:
						my_mana -= 100
						del_list = target_list
						doing_anim = true
						blink_t1 = 0.0
						blink_t2 = 0.0
						show_blink = true
						del_mode = 2
						if sound_play != null:
							sound_play.stream = sfx_skill
							sound_play.play()

func hit_wall_or_block(nx, ny):
	if nx < 0 or nx + 1 >= w or ny >= h:
		return true
	if ny >= 0:
		if map_data[ny][nx] != 0 or map_data[ny][nx + 1] != 0:
			return true
	return false

func place_block():
	map_data[py][px] = c1
	map_data[py][px + 1] = c2
	
	c1 = 0
	c2 = 0 
	
	if sound_play != null and sfx_drop != null:
		sound_play.stream = sfx_drop
		sound_play.play()

	block_fall_down()
	
	var matches = check_match()
	if matches.size() > 0:
		del_list = matches
		doing_anim = true
		blink_t1 = 0.0
		blink_t2 = 0.0
		show_blink = true
		del_mode = 1
		
		if sound_play != null and sfx_clear != null:
			sound_play.stream = sfx_clear
			sound_play.play()
	else:
		create_block()

func check_match():
	var res = []
	var checked = {} 
	
	for i in range(h):
		for j in range(w):
			var color = map_data[i][j]
			
			if color != 0 and checked.has(Vector2(j, i)) == false:
				var g = []
				var q = [Vector2(j, i)]
				checked[Vector2(j, i)] = true
				
				while q.size() > 0:
					var cur = q.pop_front()
					g.append(cur)
					
					var nb = [
						Vector2(cur.x + 1, cur.y), 
						Vector2(cur.x - 1, cur.y), 
						Vector2(cur.x, cur.y + 1), 
						Vector2(cur.x, cur.y - 1)  
					]
					
					for n in nb:
						if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
							if map_data[n.y][n.x] == color:
								if checked.has(n) == false:
									checked[n] = true
									q.append(n)

				if g.size() >= 4:
					for p in g:
						res.append(p)
						
	return res

func block_fall_down():
	for c in range(w):
		for r in range(h - 1, -1, -1):
			if map_data[r][c] == 0:
				for k in range(r - 1, -1, -1):
					if map_data[k][c] != 0:
						map_data[r][c] = map_data[k][c]
						map_data[k][c] = 0
						break

func _draw():
	var w_size = get_viewport_rect().size
	var win_w = w_size.x
	var win_h = w_size.y
	var ui_w = win_w - bg_w

	if tex_background != null:
		draw_texture_rect(tex_background, Rect2(0, 0, win_w, win_h), false)
	else:
		draw_rect(Rect2(0, 0, win_w, win_h), Color.BLACK)
	
	draw_rect(Rect2(0, 0, bg_w, h * sz), Color(0, 0, 0, 0.5))
	
	for i in range(h):
		for j in range(w):
			var v = map_data[i][j]
			if v != 0:
				var is_blink = false
				if doing_anim and (Vector2(j, i) in del_list):
					is_blink = true
					
				if not is_blink or show_blink:
					var r_rect = Rect2(j * sz, i * sz, sz, sz)
					if pics.has(v) and pics[v] != null:
						draw_texture_rect(pics[v], r_rect, false)
					else:
						draw_rect(r_rect, color_code[v])
			
	if (game_status == 1 or game_status == 2) and c1 != 0:
		var rect1 = Rect2(px * sz, py * sz, sz, sz)
		if pics.has(c1) and pics[c1] != null:
			draw_texture_rect(pics[c1], rect1, false)
		else:
			draw_rect(rect1, color_code[c1])
			
		var rect2 = Rect2((px + 1) * sz, py * sz, sz, sz)
		if pics.has(c2) and pics[c2] != null:
			draw_texture_rect(pics[c2], rect2, false)
		else:
			draw_rect(rect2, color_code[c2])
		
	draw_rect(Rect2(bg_w, 0, ui_w, win_h), Color(0.12, 0.12, 0.16, 0.8))
	draw_line(Vector2(bg_w, 0), Vector2(bg_w, win_h), Color.WHITE, 2)
	
	var f = ThemeDB.fallback_font
	var margin_x = bg_w + 20
	
	var tc = Color.WHITE
	if timer <= 30:
		tc = Color.RED
		
	draw_string(f, Vector2(margin_x, 40), "TIME: " + str(int(timer)) + " s", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tc)
	draw_string(f, Vector2(margin_x, 100), "SCORE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.LIGHT_GRAY)
	draw_string(f, Vector2(margin_x, 130), str(my_score), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.GOLD)
	
	var mc = Color.DARK_CYAN
	if my_mana >= 100:
		mc = Color.CYAN
		
	draw_string(f, Vector2(margin_x, 200), "MANA: " + str(my_mana), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, mc)
	
	draw_rect(Rect2(margin_x, 215, 150, 20), Color.DARK_GRAY)
	draw_rect(Rect2(margin_x, 215, (float(my_mana) / 100.0) * 150, 20), mc)
	
	draw_string(f, Vector2(margin_x, 290), "SKILLS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	
	var skill1_color = Color.GRAY
	if my_mana >= 20: skill1_color = Color.YELLOW
	var skill2_color = Color.GRAY
	if my_mana >= 100: skill2_color = Color.RED
	
	draw_string(f, Vector2(margin_x, 330), "[UP] Swap L/R", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.LIGHT_GREEN)
	draw_string(f, Vector2(margin_x, 370), "[1] Reroll (-20)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, skill1_color)
	draw_string(f, Vector2(margin_x, 410), "[2] Bomb (-100)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, skill2_color)
	
	if game_status == 0:
		draw_rect(Rect2(0, 0, win_w, win_h), Color(0, 0, 0, 0.7))
		draw_string(f, Vector2(win_w / 2 - 120, win_h / 2 - 30), "PUZZLE GAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
		draw_string(f, Vector2(win_w / 2 - 100, win_h / 2 + 20), "Press ENTER to Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.YELLOW)
		
	elif game_status == 2:
		draw_rect(Rect2(0, 0, win_w, win_h), Color(0, 0, 0, 0.5))
		draw_string(f, Vector2(win_w / 2 - 70, win_h / 2 - 20), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
		draw_string(f, Vector2(win_w / 2 - 110, win_h / 2 + 20), "Press ENTER to Resume", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.YELLOW)
		
	elif game_status == 3:
		draw_rect(Rect2(0, 0, win_w, win_h), Color(0, 0, 0, 0.7))
		if is_win == true:
			draw_string(f, Vector2(win_w / 2 - 80, win_h / 2 - 30), "YOU WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.GREEN)
		else:
			draw_string(f, Vector2(win_w / 2 - 100, win_h / 2 - 30), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.RED)
		draw_string(f, Vector2(win_w / 2 - 110, win_h / 2 + 30), "Press ENTER to Restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.YELLOW)
