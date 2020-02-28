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

--------------------------------------------------------------------------------------------------------------------------------

player = actor:new({x=63, y=100, depth = 5, mom = 0, acc = 0.3, dec = 0.2, max_mom = 1.5, shot_timer = 0, double_dist = 4, collision_width=9, collision_height=14, collision_offset_x=-4, collision_offset_y=0})

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
		self.y = 0
		self.x = rnd(127)
	end
end

function star:draw()
	pset(self.x, self.y, self.colour)
end

--------------------------------------------------------------------------------------------------------------------------------

shot = actor:new({speed = 4, depth = 4})

function shot:update()
	self.y-=self.speed
	if self.y < -15 then
		self.dead = true
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
	debug_weapon_level()
	update_weapon()
	debug_many_powerups()

	animate_powerups()
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

--------------------------------------------------------------------------------------------------------------------------------

function _draw()
	cls()
	sort_actors_by_depth()
	for a in all(actors) do
		a:draw()
	end
	draw_hud()
	debug_draw_collision_boxes()
	print(#actors, 0,0,7)
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
__sfx__
000100003105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
