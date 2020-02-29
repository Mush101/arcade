pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

object = {}

function object:new(a)
	self.__index=self
	return setmetatable(a or {}, self)
end

actor = object:new({x=0, y=0, depth=0, collision_width=0, collision_height=0, collision_offset_x=0, collision_offset_y=0})

function actor:update()

end

function actor:draw()

end

function actor:draw_collision_box()
	if self.collision_width > 0 and self.collision_height > 0 then
		local x, y = self.x+self.collision_offset_x, self.y+self.collision_offset_y
		rect(x, y, x + self.collision_width-1, y + self.collision_height-1, 8)
	end
end

function actor:collides(other)
	ax1 = self.x+self.collision_offset_x
	ay1 = self.y+self.collision_offset_y
	ax2 = ax1 + self.collision_width
	ay2 = ay1 + self.collision_height
	bx1 = other.x+other.collision_offset_x
	by1 = other.y+other.collision_offset_y
	bx2 = bx1 + other.collision_width
	by2 = by1 + other.collision_height
	return boxes_overlap(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
end

function actor:time_unit_over()

end

--------------------------------------------------------------------------------------------------------------------------------

player = actor:new({x=63, y=100, depth = 5, mom = 0, acc = 0.3, dec = 0.2, max_mom = 1.5, shot_timer = 0, double_dist = 4, collision_width=9, collision_height=10, collision_offset_x=-4, collision_offset_y=4})

function player:update()

	-- Movement code
	if btn(0) and not btn(1) then
		self.mom = max(-self.max_mom, self.mom - self.acc)
	elseif btn(1) and not btn(0) then
		self.mom = min(self.max_mom, self.mom + self.acc)
	elseif self.mom > self.dec then
		self.mom -= self.dec
	elseif self.mom < -self.dec then
		self.mom += self.dec
	else
		self.mom = 0
	end

	self.x += self.mom

	-- Screen clamping
	self.x = mid(4, 123, self.x)

	-- Double weapons
	if weapon_level > 0 and self.double_dist < 7 then
		self.double_dist+=1
	elseif weapon_level < 1 and self.double_dist > 4 then
		self.double_dist-=1
	end

	-- Shooting
	if self.shot_timer <=0 then
		if btn(4) or btn(5) then
			if weapon_level == 0 then
				self.shot_timer = 20
				local shot = shot:new({x=self.x, y=self.y-6})
				add_actor(shot)
			elseif weapon_level == 1 then
				self.shot_timer = 20
				local shot = shot:new({x=self.x-3, y=self.y-6, pal = 8})
				add_actor(shot)
				shot = shot:new({x=self.x+3, y=self.y-6, pal = 8})
				add_actor(shot)
			else
				self.shot_timer = 15
				local shot = shot:new({x=self.x-3, y=self.y-4, pal = 12, speed = 6, plasma = true})
				add_actor(shot)
				shot = shot:new({x=self.x+3, y=self.y-4, pal = 12, speed = 6, plasma = true})
				add_actor(shot)
				local shot = shot:new({x=self.x, y=self.y-6, pal = 10, speed = 6, plasma = true})
				add_actor(shot)
			end
		end
	else
		self.shot_timer -=1
	end
end

function player:draw()
	-- Double weapons
	local weapon_sprite = 4
	spr(weapon_sprite, self.x-self.double_dist, self.y)
	spr(weapon_sprite, self.x+self.double_dist-7, self.y, 1, 1, true)
	--Ship
	sspr(0,0,9,14,self.x-4, self.y)
end

--------------------------------------------------------------------------------------------------------------------------------

star = actor:new({colour = 7, depth = -20})

function star:update()
	if self.colour == 7 then
		self.y += star_speed
	else
		self.y += star_speed/2
	end

	if self.y >= 128 then
		self.y -=128
		self.x = rnd(127)
	end
end

function star:draw()
	pset(self.x, self.y, self.colour)
end

--------------------------------------------------------------------------------------------------------------------------------

shot = actor:new({speed = 4, depth = 4, collision_width=1, collision_height=15, collision_offset_x=0, collision_offset_y=0})

function shot:update()
	self.y-=self.speed
	if self.y < -15 then
		self.dead = true
	end

	for a in all(actors) do
		if not self.dead and a.enemy and self:collides(a) then
			a:hit()
			if not self.plasma then
				self.dead = true
			end
		end
	end
end

function shot:draw()
	if self.pal then
		pal(11, self.pal)
	end

	local sprite_add = 0
	-- if self.plasma then
	-- 	sprite_add = 4
	-- end

	sspr(16+sprite_add,0,3,15+sprite_add,self.x-1, self.y)
	pal()
end

--------------------------------------------------------------------------------------------------------------------------------

powerup = actor:new({speed = 0.5, collision_width=9, collision_height=8, collision_offset_x=0, collision_offset_y=0})

function powerup:update()
	self.y+=self.speed
	if self.y >=128 then
		self.dead = true;
	elseif self:collides(player) then
		charge +=1
		self.dead = true
	end
end

function powerup:draw()
	if powerup_timer > 1.5 then
		pal(12,7)
	end
	spr(20, self.x, self.y)
	spr(21, self.x+8, self.y)
	pal()
end

--------------------------------------------------------------------------------------------------------------------------------

basic_enemy = actor:new({colour = 8, collision_width=9, collision_height=9, collision_offset_x=-4, collision_offset_y=-4, sine_timer = 0, enemy = true, points=1})

function basic_enemy:update()
	if not self.tail_pos then
		self.tail_pos = {}
		for i = 0,4 do
			self.tail_pos[i] = {x=self.x, y=self.y}
		end
		self:set_initial()
		self.prev_x = self.x
		self.prev_y = self.y
		self.goal_x = 128-self.x
		self.goal_y = self.y+16
	end

	self:move()

	for i=4,1,-1 do
		self.tail_pos[i].x = self.tail_pos[i-1].x
		self.tail_pos[i].y = self.tail_pos[i-1].y-3
	end

	self.tail_pos[0].x = self.x
	self.tail_pos[0].y = self.y

	self.sine_timer += 0.01 * game_speed
	if self.sine_timer >= 1 then
		self.sine_timer -=1
	end
end

function basic_enemy:set_initial()
	self.init_x = self.x
	self.init_y = self.y
end

function basic_enemy:move()
	self.x = lerp(self.prev_x, self.goal_x, slerp_time_unit)
	self.y = lerp(self.prev_y, self.goal_y, slerp_time_unit)
end

function basic_enemy:time_unit_over()
	local x, y = self.prev_x, self.prev_y
	self.prev_x = self.goal_x
	self.prev_y = self.goal_y
	self.goal_x = x
	self.goal_y = y
end

function basic_enemy:go_away()
	self.y+=1 * game_speed
	self.x = self.init_x + 16 * sin(self.sine_timer)
	if self.y > 128 then
		self.y = -16
	end
end

function basic_enemy:draw()
	if self.tail_pos then
		for i = 0,4 do
			circfill(self.tail_pos[i].x, self.tail_pos[i].y, 4-i, self.colour)
		end
	end
	draw_eye(self.x,self.y,0)
end

function basic_enemy:hit()
	if not self.dead then
		self.dead = true
		add_actor(points_marker:new({x = self.x, y = self.y, value = self.points}))

		for i =0,0.9,0.1 do
			add_actor(death_effect:new({x=self.x, y=self.y, colour=self.colour, angle = i}))
		end

		if(rnd(6)<3) add_actor(powerup:new({x=self.x-4, y = self.y-4}))
	end
end

--------------------------------------------------------------------------------------------------------------------------------

points_marker = actor:new({value = 1, life = 0, depth = 50})

function points_marker:update()
	if self.life == 0 then
		score:add(self.value)
	end
	self.life+=1
	self.y-=0.1
	if self.life > 40 then
		self.dead = true
	end
end

function points_marker:draw()
	if self.life%2==0 then
		local print_string = self.value.."0"
		for i=-1,1 do
			for j=-1,1 do
				print(print_string, self.x-2*#print_string+i, self.y-3+j, 0)
			end
		end
		print(print_string, self.x-2*#print_string, self.y-3, 7)
	end
end

--------------------------------------------------------------------------------------------------------------------------------

score = actor:new({x=1, y=122, score = 0, reel_speed = 0.25, digits = {0,0,0,0,0,0}, desired_digits = {0,0,0,0,0,0}})

function score:update()

	local remaining = self.score
	for i = 5,1,-1 do
		local mod = remaining % 10
		self.desired_digits[i] = mod
		remaining -= mod
		remaining /= 10
	end

	for i = 1, 6 do
		if abs(self.digits[i] - self.desired_digits[i]) > 0.0001 then
			self.digits[i] += self.reel_speed
		end
		if self.digits[i] >= 10 then
			self.digits[i] = 0
		end
	end
end

function score:add(amount)
	self.score+=amount
	self.score = mid(0,32000, self.score)
end

function score:draw()
	clip(self.x, self.y-1, 24, 7)
	print(""..self.score, self.x+60, self.y, 7)
	for i = 0,5 do
		print("0\n9\n8\n7\n6\n5\n4\n3\n2\n1\n0",self.x + 4*i, self.y-60 + self.digits[i+1] * 6, 7)
	end
end

--------------------------------------------------------------------------------------------------------------------------------

death_effect = actor:new({colour = 8, size = 4, angle = 0, dist = 0})

function death_effect:update()
	if not self.inital_x then
		self.initial_x = self.x
		self.initial_y = self.y
	end
	self.size -= 0.2
	self.dist += 0.1
	self.angle += 0.01
	if self.size <=0 then
		self.dead = true
	end

	self.x = self.initial_x + self.dist * cos(self.angle)
	self.y = self.initial_y + self.dist * sin(self.angle)
end

function death_effect:draw()
	circfill(self.x,self.y,self.size, self.colour)
end

--------------------------------------------------------------------------------------------------------------------------------

function _init()
	actors = {}
	add_actor(player)

	game_speed = 1
	star_speed = 2

	create_stars()

	max_charge = 7
	charge = 0
	weapon_level = 0
	weapon_flash_time = 0

	powerup_timer = 0

	time_unit = 0
	slerp_time_unit = 0

	--enable mouse for testing
	--poke(0x5f2d, 1)
end

function create_stars()
	for i = 0,128,8 do
		add_actor(star:new({x=rnd(127), y=i}))
	end

	for i = 0,128,8 do
		add_actor(star:new({x=rnd(127), y=i, colour=12, depth=-21}))
	end
end

---------------------------------------------------------------------------------------------------------------------------------

function _update60()
	for a in all(actors) do
		a:update()
		if a.dead then
			del(actors, a)
		end
	end

	if not any_enemies() and time_unit < 0.1then
		add_actor(basic_enemy:new({x=32,y=64}))
		add_actor(basic_enemy:new({x=96,y=64}))
		add_actor(basic_enemy:new({x=24,y=32}))
		add_actor(basic_enemy:new({x=108,y=32}))
	end
	--debug_weapon_level()
	update_weapon()
	--debug_many_powerups()

	animate_powerups()

	debug_speed()

	do_timing()

	star_speed = 2*game_speed

	score:update()
end

function add_actor(a)
	add(actors, a)
end

function update_weapon()
	if weapon_flash_time > 0 then
		weapon_flash_time -= 1
	end
	if weapon_level == 2 then
		charge = min(0, charge)
	end
	charge = max(-1, charge)
	if weapon_level < 2 and charge > 6 then
		weapon_level +=1
		weapon_flash_time = 95
		charge -=7
	elseif weapon_level > 0 and charge < 0 then
		weapon_level -=1
		weapon_flash_time = 0
		charge +=7
	end
end

function do_timing()
	time_unit += 0.01 * game_speed
	if time_unit >= 1 then
		time_unit -=1
		for a in all(actors) do
			a:time_unit_over()
		end
	end
	slerp_time_unit = (sin(time_unit/2)+1)/2
end

function animate_powerups()
	powerup_timer+=0.1
	if powerup_timer >= 2 then
		powerup_timer -=2
	end
end

function debug_weapon_level()
	if btnp(2) then
		charge +=1
	elseif btnp(3) then
		charge -=1
	end
end

function debug_speed()
	if btnp(2) then
		game_speed +=0.1
	elseif btnp(3) then
		game_speed -=0.1
	end
end

function debug_many_powerups()
	if(rnd(128) < 2) add_actor(powerup:new({x=rnd(119) + 4, y = -8}))
end

function boxes_overlap(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
	if (bx1 > ax2) return false
	if (bx2 < ax1) return false
	if (by1 > ay2) return false
	if (by2 < ay1) return false
	return true
end

function lerp(a, b, t)
	return (1-t) * a + t * b
end

function any_enemies()
	for a in all(actors) do
		if a.enemy then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------------------------------------------------------

function _draw()
	cls()
	sort_actors_by_depth()
	for a in all(actors) do
		a:draw()
	end
	draw_hud()
	--debug_draw_collision_boxes()
	--print(#actors, 0,0,7)
	score:draw()
end

function draw_hud()
	rectfill(0,120,127,127,2)
	line(0,120,127,120,14)

	-- Charge
	local x = 64-max_charge*3-1
	for i = 1,max_charge do
		local lit = i > charge
		if weapon_flash_time > 0 then
			lit = weapon_flash_time%20 < 10
		end
		if lit then
			spr(19,x,121)
		else
			spr(3,x,121)
		end
		x+=6
	end

	-- Weapon
	local weapon = "single"
	if weapon_level == 1 then
		weapon = "double"
	elseif weapon_level == 2 then
		weapon = "plasma"
	end
	print(weapon, 104, 122, 12)
end

-- Very inefficient. Maybe come back to later.
function sort_actors_by_depth()
	local new_actors = {}
	while #actors > 0 do
		smallest_depth = 9999
		for a in all(actors) do
			if a.depth < smallest_depth then
				smallest_actor = a
				smallest_depth = a.depth
			end
		end
		add(new_actors, smallest_actor)
		del(actors, smallest_actor)
	end
	actors = new_actors
end

function debug_draw_collision_boxes()
	for a in all(actors) do
		a:draw_collision_box()
	end
end

function draw_eye(x, y, blink)
	pal(14,0)
	spr(64+blink,x-4,y-4)
	pal()
end

__gfx__
00006000000000000b00bbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000000000b00bbb00cccc00000006000000ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000000000b00bbb000cccc00000060000006660000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077700000000000b00bbb0000cccc0000770000007770000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007c700000000000b00bbb000cccc00000767000007670000000000000000000000000000000000000000000000000000000000000000000000000000000000
007ccc70000000000000bbb00cccc000000760000007600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777770000000000b00bbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06776776000000000000bbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67776777600000000000bbb000000000066666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67576757600000000b00000001111000655555556000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67777777600000000000bbb000111100555ccc555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d77d0d77d0000000000000000001111055ccc7c55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0880008800000000000000000011110055ccccc55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09900099000000000000bbb001111000555ccc555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000b00000000000000655555556000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000066666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000aa7a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000bbb0aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077eee77007eee700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077eee77077eee770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077eee77077eee77077eee7707000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777770007777700077777000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
