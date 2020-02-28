pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

object = {}

function object:new(a)
	self.__index=self
	return setmetatable(a or {}, self)
end

actor = object:new({x=0, y=0, depth=0})

function actor:update()

end

function actor:draw()

end

--------------------------------------------------------------------------------------------------------------------------------

player = actor:new({x=63, y=100, mom = 0, acc = 0.3, dec = 0.2, max_mom = 1.5})

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
end

function player:draw()
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

function _init()
	actors = {}
	add_actor(player)

	game_speed = 1
	star_speed = 2

	create_stars()

	max_charge = 7
	charge = 3
	weapon_level = 0
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
	end
end

function add_actor(a)
	add(actors, a)
end

--------------------------------------------------------------------------------------------------------------------------------

function _draw()
	cls()
	sort_actors_by_depth()
	for a in all(actors) do
		a:draw()
	end
	draw_hud()
end

function draw_hud()
	rectfill(0,120,127,127,2)
	line(0,120,127,120,14)

	-- Charge
	local x = 64-max_charge*3
	for i = 1,max_charge do
		if i > charge then
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

__gfx__
00006000000000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000700000000000bbb000000cccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000000000b00000000cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077700000000000b000000000cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007c700000000000b00000000cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007ccc70000000000b0000000cccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777770000000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06776776000000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67776777600000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67576757600000000b00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67777777600000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d77d0d77d00000000b00000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08800088000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09900099000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
