-- title:   game title
-- author:  game developer, email, etc.
-- desc:    short description
-- site:    website link
-- license: MIT License (change this to your license of choice)
-- version: 0.1
-- script:  moon

-- These functions are at top because forward declare doesnt work for some reason
t = 0

vecnew = (x, y) ->
	return {
		x: x,
		y: y,
	}

veccopy = (vec) ->
	return {
		x: vec.x,
		y: vec.y,
	}

tweenvec_create = (pos) ->
	return {
		prev_pos: veccopy(pos),
		pos: veccopy(pos),
		dest: veccopy(pos),
		tween_time: 0.7,
		t_start_tween: 0,
		sine: true,
		tween: (self, dest) ->
			self.prev_pos = veccopy(self.pos)
			self.dest = veccopy(dest)
			self.t_start_tween = t
		set_pos: (self, pos) ->
			self.prev_pos = veccopy(pos)
			self.dest = veccopy(pos)
			self.pos = veccopy(pos)
			self.t_start_tween = t - self.tween_time*60
		tweening: (self) ->
			return t <= self.t_start_tween + self.tween_time*60
	}

list_tween_vec = {}
tweenvec_list_add = (tweenvec) ->
	table.insert(list_tween_vec, tweenvec)


WINDOW_W = 240
WINDOW_H = 136
WINDOW_WH = vecnew(240, 136)

NORMAL_GRAVITY_ADD = 0.15
NORMAL_JUMP_GRAVITY = -2.2

KNIFE_COOLDOWN = 0.1

LIST_ROOM = {
	{
		pos: vecnew(0, 0),
		sz: vecnew(30, 17),
		restart: vecnew(5, 15),
	},
	{
		pos: vecnew(30, 0),
		sz: vecnew(30, 17),
	},
	{
		pos: vecnew(60, 0),
		sz: vecnew(60, 17),
	},
	{
		pos: vecnew(120, 0),
		sz: vecnew(30, 17),
	},
}

list_entity = {}
player = {}
time_stopped = false
n_vbank = 0
prev_room = {}


cam = {
	pos: tweenvec_create(vecnew(0, 0))
}
tweenvec_list_add(cam.pos)


-- vec
vecequals = (vec1, vec2) ->
	return vec1.x == vec2.x and vec1.y == vec2.y

vecassign = (vec1, vec2) ->
	vec1.x = vec2.x
	vec1.y = vec2.y

vecadd = (vec1, vec2) ->
	return {
		x: vec1.x + vec2.x,
		y: vec1.y + vec2.y,
	}

vecsub = (vec1, vec2) ->
	return {
		x: vec1.x - vec2.x,
		y: vec1.y - vec2.y,
	}

vecmul = (vec, n) ->
	return {
		x: vec.x * n,
		y: vec.y * n,
	}

vecdiv = (vec, n) ->
	return {
		x: vec.x / n,
		y: vec.y / n,
	}

vecdivdiv = (vec, n) ->
	return {
		x: vec.x // n,
		y: vec.y // n,
	}

vecfloor = (vec) ->
	return {
		x: math.floor(vec.x),
		y: math.floor(vec.y),
	}

veclength = (vec) ->
	return math.sqrt(vec.x*vec.x + vec.y*vec.y)

vecdist = (vec1, vec2) ->
	return veclength(vecsub(vec1, vec2))

vecnormalized = (vec) ->
	if vecequals(vec, vecnew(0, 0)) then
		return vecnew(0, 0)
	return vecdiv(vec, veclength(vec))
	
vecshrink = (vec, n) ->
	length = veclength(vec)
	if length < 0.1 then return vecnew(0, 0)
	return vecmul(vecnormalized(vec), length - n)

vecrot = (vec, rad) ->
	newx = 0
	newy = 0
	newx = vec.x * math.cos(rad) - vec.y * math.sin(rad)
	newy = vec.x * math.sin(rad) + vec.y * math.cos(rad)
	return vecnew(newx, newy)

-- math
floor = (n, f) ->
	return (n // f) * f

sqr = (n) ->
	return n*n

rndf = (a, b) ->
	return math.random() * (b - a) + a

rndi = (a, b) ->
	return math.random(a, b)

sign = (n) ->
	if n == 0 then return 0
	if n < 0 then return -1
	return 1

rectcollide = (pos1, sz1, pos2, sz2) ->
	if pos1.x + sz1.x <= pos2.x then return false
	if pos1.x >= pos2.x + sz2.x then return false
	if pos1.y + sz1.y <= pos2.y then return false
	if pos1.y >= pos2.y + sz2.y then return false
	return true

is_in_rect = (pos, rect_pos, rect_sz) ->
	if pos.x < rect_pos.x then return false
	if pos.x >= rect_pos.x + rect_sz.x then return false
	if pos.y < rect_pos.y then return false
	if pos.y >= rect_pos.y + rect_sz.y then return false
	return true

-- From https://easings.net/#easeInOutSine
ease = (n) ->
	return -(math.cos(math.pi * n) - 1) / 2

-- utils
find_in_list = (list, val) ->
	for i, val_comp in ipairs(list)
		if val_comp == val then return i
	return -1

-- tween
tweenvec_list_update = () ->
	for i, tweenvec in ipairs(list_tween_vec)
		t_percent = (t - tweenvec.t_start_tween) / (tweenvec.tween_time * 60)
		if t_percent >= 1 then 
			tweenvec.pos = veccopy(tweenvec.dest)
			continue
		if tweenvec.sine then
			t_percent = ease(t_percent)
		dir = vecsub(tweenvec.dest, tweenvec.prev_pos)
		dir = vecmul(dir, t_percent)
		tweenvec.pos = vecadd(tweenvec.prev_pos, dir)

-- map
map_solid = (pos) ->
	return mget(pos.x // 8, pos.y // 8) != 0

-- room
local explode
local restart_room_create
local entity_create
local entity_list_add

get_room = (pos) ->
	map_pos = vecdivdiv(pos, 8)
	for i, room in ipairs(LIST_ROOM)
		if is_in_rect(map_pos, room.pos, room.sz) then return room
	return -1

restart_room = ->
	entity_list_add(restart_room_create())
	player.visible = true
	player.pos = vecadd(vecmul(prev_room.restart, 8), vecnew(0, -16))

room_update = ->
	room = get_room(vecadd(player.pos, vecnew(4, 12)))
	if room != -1 then
		prev_room = room
		return

	if room == -1 and player.visible then 
		player.visible = false
		explode(vecadd(player.pos, vecnew(4, 8)))
		restart_room()
	
-- restart_room = ->
restart_room_draw = (e) ->
	t_diff = t - e.t_creation
	rect(0, WINDOW_H - t_diff * 6, WINDOW_W, WINDOW_H + 100, 0)

restart_room_chkremove = (i, e) ->
	t_diff = t - e.t_creation
	if WINDOW_H - t_diff * 2 < -(WINDOW_H + 100) then
		table.remove(list_entity, i)
	
restart_room_create = ->
	rr = entity_create(vecnew(0, 0), vecnew(0, 0))
	rr.t_creation = t

	rr.draw = restart_room_draw
	rr.chkremove = restart_room_chkremove
	
	return rr

-- camera
get_draw_pos = (pos) ->
	return vecsub(pos, vecfloor(cam.pos.pos))

cam_update = () ->
	room = get_room(vecadd(player.pos, vecnew(4, 12)))
	if room == -1 then
		return

	cam_follow_pos = vecsub(player.pos, vecdiv(WINDOW_WH, 2))
	cam_follow_pos = vecadd(cam_follow_pos, vecdiv(player.sz, 2))

	if cam_follow_pos.x//8 < room.pos.x then cam_follow_pos.x = room.pos.x*8
	if (cam_follow_pos.x + WINDOW_W)//8 >= room.pos.x + room.sz.x then
		cam_follow_pos.x = (room.pos.x + room.sz.x)*8 - WINDOW_W
	if cam_follow_pos.y//8 < room.pos.y then cam_follow_pos.y = room.pos.y*8
	if (cam_follow_pos.y + WINDOW_H)//8 >= room.pos.y + room.sz.y then
		cam_follow_pos.y = (room.pos.y + room.sz.y)*8 - WINDOW_H

	follow_dist = vecdist(cam_follow_pos, cam.pos.pos)
	if not cam.pos.tweening(cam.pos) and follow_dist > 50 then
		cam.pos.tween(cam.pos, cam_follow_pos)
		return

	if cam.pos.tweening(cam.pos) then
		return

	cam_follow_spd = vecdist(cam.pos.pos, cam_follow_pos) * 0.06
	cam_follow_dir = vecnormalized(vecsub(cam_follow_pos, cam.pos.pos))
	cam.pos.set_pos(cam.pos, vecadd(cam.pos.pos, vecmul(cam_follow_dir, cam_follow_spd)))

-- entity
COLLISION_COLLISION = 0
COLLISION_ONLY_DOWN = 1
COLLISION_NONE = 2

entity_list_add = (e) ->
	table.insert(list_entity, e)

entity_list_update = ->
	for i, e in ipairs(list_entity)
		if e.update != nil then e.update(e)

entity_list_chkremove = ->
	for i = #list_entity, 1, -1
		e = list_entity[i]
		if e.chkremove != nil then e.chkremove(i, e)

entity_list_draw = ->
	for i, e in ipairs(list_entity)
		if e.draw != nil then e.draw(e)

entity_create = (pos, sz) ->
	return {
		pos: veccopy(pos),
		sz: veccopy(sz),
		fvec: vecnew(0, 0),
		gravity: 0,
		gravity_add: 0,
		jump_gravity: 0,
		collision_weight: 999999,
		collision_type: COLLISION_COLLISION,
		ignore_collision: {},
	}

entity_physic_point_list = (pos, e) ->
	list = {}

	for ix = 0, (e.sz.x - 1)//8
		for iy = 0, (e.sz.y - 1)//8
			table.insert(list, vecnew(pos.x + 8*ix, pos.y + 8*iy))

	for ix = 0, (e.sz.x - 1)//8
		table.insert(list, vecnew(pos.x + 8*ix, pos.y + e.sz.y-1))

	for iy = 0, (e.sz.y - 1)//8
		table.insert(list, vecnew(pos.x + e.sz.x-1, pos.y + 8*iy))

	table.insert(list, vecnew(pos.x + e.sz.x-1, pos.y + e.sz.y-1))

	return list

entity_movex = (e) ->
	mx = e.fvec.x
	if mx == 0 then return
		
	newpos = vecnew(e.pos.x + mx, e.pos.y)
	
	list_physic_point = entity_physic_point_list(newpos, e)

	for i, physic_point in ipairs(list_physic_point)
		if map_solid(physic_point) then
			if mx < 0 then e.pos.x = floor(e.pos.x, 8)
			else e.pos.x = floor(newpos.x + e.sz.x, 8) - e.sz.x
			return

	for i, e_comp in ipairs(list_entity)
		if e_comp == e then continue
		if find_in_list(e.ignore_collision, e_comp) != -1 then continue
		if e_comp.collision_type == COLLISION_NONE then continue
		if e_comp.collision_type == COLLISION_ONLY_DOWN then continue
		if rectcollide(newpos, e.sz, e_comp.pos, e_comp.sz) then
			if mx < 0 then e.pos.x = e_comp.pos.x + e_comp.sz.x
			else e.pos.x = e_comp.pos.x - e.sz.x
			return

	e.pos.x = newpos.x

entity_movey = (e) ->
	my = e.fvec.y
	if my == 0 then return
			
	newpos = vecnew(e.pos.x, e.pos.y + my)
	
	list_physic_point = entity_physic_point_list(newpos, e)

	for i, physic_point in ipairs(list_physic_point)
		if map_solid(physic_point) then
			if my < 0 then e.pos.y = floor(e.pos.y, 8)
			else e.pos.y = floor(newpos.y + e.sz.y, 8) - e.sz.y
			return

	for i, e_comp in ipairs(list_entity)
		if e_comp == e then continue
		if find_in_list(e.ignore_collision, e_comp) != -1 then continue
		if e_comp.collision_type == COLLISION_NONE then continue
		if e_comp.collision_type == COLLISION_ONLY_DOWN and my < 0 then continue
		if rectcollide(newpos, e.sz, e_comp.pos, e_comp.sz) then
			if my < 0 then 
				e.pos.y = e_comp.pos.y + e_comp.sz.y
				return
			else
				dest = e_comp.pos.y - e.sz.y
				if e.pos.y <= dest then 
					e.pos.y = dest
					return

	e.pos.y = newpos.y

entity_move = (e) ->
	entity_movex(e)
	entity_movey(e)

_entity_collision_pt_chk = (list) ->
	for i, pos in ipairs(list)
		if map_solid(pos) then
			return true

	return false

entity_collision_up = (e, count_fvec) ->
	list = {
		vecnew(e.pos.x , e.pos.y - 1),
		vecnew(e.pos.x + e.sz.x-1 , e.pos.y - 1),
	}
	if _entity_collision_pt_chk(list) then
		return true

	newpos = vecnew(e.pos.x, e.pos.y - 1)
	for i, e_comp in ipairs(list_entity)
		if e == e_comp then continue
		if e_comp.collision_type == COLLISION_NONE then continue
		if e_comp.collision_type == COLLISION_ONLY_DOWN then continue
		if rectcollide(newpos, e.sz, e_comp.pos, e_comp.sz) then return true
			
	return false

entity_collision_down = (e) ->
	list = {
		vecnew(e.pos.x , e.pos.y + e.sz.y),
		vecnew(e.pos.x + e.sz.x-1 , e.pos.y + e.sz.y),
	}
	if _entity_collision_pt_chk(list) then
		return true

	newpos = vecnew(e.pos.x, e.pos.y + 1)
	for i, e_comp in ipairs(list_entity)
		if e == e_comp then continue
		if e_comp.collision_type == COLLISION_NONE then continue
		if e_comp.collision_type == COLLISION_ONLY_DOWN then
			if rectcollide(vecnew(newpos.x, newpos.y + e.sz.y-1), vecnew(e.sz.x, 1), e_comp.pos, e_comp.sz) then return true
			continue
		if rectcollide(newpos, e.sz, e_comp.pos, e_comp.sz) then return true

	return false

entity_collision_left = (e, count_fvec) ->
	list = {
		vecnew(e.pos.x - 1, e.pos.y),
		vecnew(e.pos.x - 1, e.pos.y + e.sz.y - 1),
	}
	if _entity_collision_pt_chk(list) then
		return true

	newpos = vecnew(e.pos.x - 1, e.pos.y)
	for i, e_comp in ipairs(list_entity)
		if e == e_comp then continue
		if e_comp.collision_type == COLLISION_NONE then continue
		if e_comp.collision_type == COLLISION_ONLY_DOWN then continue
		if rectcollide(newpos, e.sz, e_comp.pos, e_comp.sz) then return true

	return false

entity_collision_right = (e, count_fvec) ->
	list = {
		vecnew(e.pos.x + e.sz.x, e.pos.y),
		vecnew(e.pos.x + e.sz.x, e.pos.y + e.sz.y - 1),
	}
	if _entity_collision_pt_chk(list) then
		return true

	newpos = vecnew(e.pos.x + 1, e.pos.y)
	for i, e_comp in ipairs(list_entity)
		if e == e_comp then continue
		if e_comp.collision_type == COLLISION_NONE then continue
		if e_comp.collision_type == COLLISION_ONLY_DOWN then continue
		if rectcollide(newpos, e.sz, e_comp.pos, e_comp.sz) then return true

	return false

entity_gravity = (e, gravity_add, jump, jump_gravity) ->
	e.gravity += gravity_add

	if e.fvec.y > 0 and entity_collision_down(e) then
		e.gravity = 1
		if jump then e.gravity = jump_gravity

	if entity_collision_up(e, true) then
		e.gravity = 1

-- player
local knife_create
_player_looking_right = false
_knife_cooldown = 0

player_update = (e) ->
	if not player.visible then return

	e.fvec.x = 0
	if btn(2) then e.fvec.x = -1
	if btn(3) then e.fvec.x = 1

	entity_gravity(e, e.gravity_add, btnp(4), e.jump_gravity)
	e.fvec.y = math.floor(e.gravity)

	entity_move(e)


	if btnp(5) and _knife_cooldown <= 0 then
		_knife_cooldown = KNIFE_COOLDOWN * 60
		knife_pos = vecnew(e.pos.x + e.sz.x, e.pos.y + 6)
		if not _player_looking_right then knife_pos.x = e.pos.x - 8
		entity_list_add(knife_create(knife_pos, _player_looking_right))
	_knife_cooldown -= 1

	
	if btnp(6) then
		time_stopped = not time_stopped
		if time_stopped then n_vbank = 1 else n_vbank = 0

_PLAYER_SPR = {
	run: {
		257,
		259,
		263,
		261,
	},
	idle: {
		256,
		288,
	},
	air: {
		257,
	},
}

_t_player_stop_move = 0

player_draw = (e) ->
	if not player.visible then return
		
	draw_pos = get_draw_pos(e.pos)

	if btn(2) then _player_looking_right = false
	if btn(3) then _player_looking_right = true

	if e.fvec.y < 0 or not entity_collision_down(e) then
		if not _player_looking_right then
			spr(_PLAYER_SPR.air[1], draw_pos.x-5, draw_pos.y, 0, 1, 0, 0, 2, 2)
		else
			spr(_PLAYER_SPR.air[1], draw_pos.x-5, draw_pos.y, 0, 1, 1, 0, 2, 2)
		return

	if btn(2) then
		spr(_PLAYER_SPR.run[(t//6)%4+1], draw_pos.x-5, draw_pos.y, 0, 1, 0, 0, 2, 2)
		_t_player_stop_move = t
		return

	if btn(3) then
		spr(_PLAYER_SPR.run[(t//6)%4+1], draw_pos.x-5, draw_pos.y, 0, 1, 1, 0, 2, 2)
		_t_player_stop_move = t
		return

	if not _player_looking_right then
		spr(_PLAYER_SPR.idle[(t-_t_player_stop_move)//40%2 + 1], draw_pos.x, draw_pos.y, 0, 1, 0, 0, 1, 2)
		return
	
	spr(_PLAYER_SPR.idle[(t-_t_player_stop_move)//40%2 + 1], draw_pos.x, draw_pos.y, 0, 1, 1, 0, 1, 2)

player_create = (pos) ->
	player = entity_create(pos, vecnew(8, 16))
	player.collision_weight = 10

	player.gravity_add = NORMAL_GRAVITY_ADD
	player.jump_gravity = NORMAL_JUMP_GRAVITY

	player.visible = true

	player.draw = player_draw
	player.update = player_update

	return player

-- Knife
knife_update = (e) ->
	if time_stopped then return
	entity_move(e)

knife_draw = (e) ->
	draw_pos = vecnew(0, 0)
	if e.fvec.x < 0 then draw_pos.x = e.pos.x - 1
	else draw_pos.x = e.pos.x - 7
	draw_pos.y = e.pos.y

	draw_pos = get_draw_pos(draw_pos)

	flip = 0
	if e.fvec.x > 0 then flip = 1

	spr(320, draw_pos.x, draw_pos.y, 0, 1, flip, 0, 2, 1)

knife_create = (pos, right_dir) ->
	knife = entity_create(pos, vecnew(8, 2))
	if not right_dir then
		knife.fvec.x = -3
	else
		knife.fvec.x = 3

	knife.update = knife_update
	knife.draw = knife_draw

	knife.collision_type = COLLISION_ONLY_DOWN
	knife.ignore_collision = { player }

	return knife

-- explode
explode_particle_update = (par) ->
	par.pos = vecadd(par.pos, par.fvec)

explode_particle_chkremove = (i, par) ->
	dist = vecdist(par.pos, par.origin)
	if dist > par.max_dist + par.line_dist then table.remove(list_entity, i)

explode_particle_draw = (par) ->
	p1 = veccopy(par.pos)
	dist = vecdist(p1, par.origin)

	dir = vecnormalized(par.fvec)
	p0 = veccopy(par.origin)
	if dist > par.line_dist then p0 = vecsub(p1, vecmul(dir, par.line_dist))

	if dist > par.max_dist then p1 = vecadd(par.origin, vecmul(dir, par.max_dist))
	
	drawp0 = get_draw_pos(p0)
	drawp1 = get_draw_pos(p1)
	line(drawp0.x, drawp0.y, drawp1.x, drawp1.y, par.color)

explode_particle_create = (pos, fvec, max_dist, line_dist, color) ->
	par = entity_create(pos, vecnew(0, 0))
	par.collision_type = COLLISION_NONE
	par.fvec = veccopy(fvec)
	par.max_dist = max_dist
	par.color = color
	par.origin = veccopy(pos)
	par.line_dist = line_dist
	
	par.update = explode_particle_update
	par.chkremove = explode_particle_chkremove
	par.draw = explode_particle_draw
	return par

explode = (pos) ->
	step = math.pi/2/3
	for i = 0, (math.pi*2) // step
		fvec = vecrot(vecnew(0, 1.7), i*step)
		entity_list_add(explode_particle_create(pos, fvec, 40, 5, 11))

export BOOT = ->
	player = player_create(vecnew(50, 50))
	entity_list_add(player)

export TIC = ->
	cls(0)
	vbank(n_vbank)

	cam_update()
	cam_pos = vecfloor(cam.pos.pos)
	map(cam_pos.x//8-1, cam_pos.y//8-1, 32, 19, 8 - cam_pos.x%8 - 16, 8 - cam_pos.y%8 - 16)

	tweenvec_list_update()
	entity_list_update()
	entity_list_chkremove()
	room_update()

	entity_list_draw()

	t += 1

-- <TILES>
-- 001:eeeeeeeee000000ee000000ee000000ee000000ee000000ee000000eeeeeeeee
-- 002:ffefeeee0ffffffe0ffffffe000ffffeeeee0feefffe0ffffffe0fffffff00f0
-- 003:ffeeeeee0ffffffe0ffffffe000ffffeeeee0feefffe0ffffffe0fffffff0000
-- 004:ffefeeee0ffffffe0ffffffe000ffffeefee0feefffe0ffffffe0fffffff00ff
-- 006:dddddddd000ddd000ff0dffe000ffffeeeee0feefffe0ffffffe0fffffff00f0
-- 007:dddddddd0dddd00000dddffe000ffffeeeee0feefffe0ffffffe0fffffff0000
-- 008:ddddddddddddd0000dddfffe000ffffeeeee0feefffe0ffffffe0fffffff00f0
-- 009:dddddddd0000dddd0ffff0de000ffffeeeee0feefffe0ffffffe0fffffff0000
-- </TILES>

-- <SPRITES>
-- 000:00bbbb000bbbbbb00bcbbbb00bcccbb00bccccb00bdccdb0008dd80008fddf80
-- 001:000000bb00000bbb00000bcb00000bcc00000bcc00000bdc0000008d000008fd
-- 002:bb000000bbb00000bbb00000cbb00000ccb00000cdb00000d8000000df800000
-- 003:00000000000000bb00000bbb00000bcb00000bcc00000bcc00000bdc0000008d
-- 004:00000000bb000000bbb00000bbb00000cbb00000ccb00000cdb00000d8000000
-- 005:000000bb00000bbb00000bcb00000bcc00000bcc00000bdc0000008d000008fd
-- 006:bb000000bbb00000bbb00000cbb00000ccb00000cdb00000d8000000df800000
-- 007:00000000000000bb00000bbb00000bcb00000bcc00000bcc00000bdc0000008d
-- 008:00000000bb000000bbb00000bbb00000cbb00000ccb00000cdb00000d8000000
-- 016:08fddf800ffddff0fff88ffffff88ffffff88fff08f88f8000c00c0000f00f00
-- 017:00008ffd000ffffd00fffff8000f8ff800000ff800000ff8000000c0000000f0
-- 018:dff80000dffff0008fffff008ff8f0008ff000008ff000000c0000000f000000
-- 019:000008fd00008ffd000ffffd00fffff8000f8ff800000ff80000000c0000000f
-- 020:df800000dff80000dffff0008fffff008ff8f0008ff00000c00000000f000000
-- 021:00008ffd000ffffd00fffff8000f8ff800000ff800000ff800000c0000000f00
-- 022:dff80000dffff0008fffff008ff8f0008ff000008ff0000000c0000000f00000
-- 023:000008fd00008ffd000ffffd00fffff8000f8ff800000ff8000000c0000000f0
-- 024:df800000dff80000dffff0008fffff008ff8f0008ff000000c0000000f000000
-- 032:0000000000bbbb000bbbbbb00bcbbbb00bcccbb00bccccb00bdccdb0008dd800
-- 048:08fddf8008fddf800ffddff0fff88ffffff88fff08f88f8000c00c0000f00f00
-- 064:eedeeeee0eedee00000000000000000000000000000000000000000000000000
-- 065:ee00000000000000000000000000000000000000000000000000000000000000
-- </SPRITES>

-- <MAP>
-- 000:202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000000000000002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000000000000200020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000000000020000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000000002000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000000200000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000020000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000002000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000200000000000000020000000000000000000000000000000000000000020202020202000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000020000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000020000000000000000020000000000000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000020000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000002000000000000000000020000000000000000000002020000000000000000000000000000000000000000000000000000000000020202020200000000000000000000000000020000000000000000000000000000000000000000000000000000020000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000200000000000000000000020000000000000000000000000000000000000000000000000000000000000002020202000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000020000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:200000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000020000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:202020202020202020202020000000000020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <TRACKS>
-- 000:100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </TRACKS>

-- <PALETTE>
-- 000:1a1c2cedededfffbedf3dea4f5c16da7f07038b764ad8a53262c3fffea66d98effbaf5fffffff694b0c2566c86333c57
-- 001:1a1c2cedededfffbedf3dea4f5c16da7f07038b764ad8a532c2c2cffea66d98effe4e4e4fffff6aaaaaa6868683c3c3c
-- </PALETTE>

