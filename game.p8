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

player = actor:new({x=63, y=100, depth = 5, mom = 0, acc = 0.3, dec = 0.2, max_mom = 1.5, shot_timer = 0, double_dist = 4, collision_width=9, collision_height=10, collision_offset_x=-4, collision_offset_y=4, iframes = 0})

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

	-- End of stage (either lose or win)
	if dying then
		self.y+=0.5
		self.mom = 0
	elseif stage_over then
		self.y-=1
	elseif self.y > 100 then
		self.y-=1
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
	if self.shot_timer <= 0 then
		if btn(4) or btn(5) then
			if weapon_level == 0 then
				self.shot_timer = 20
				local shot = shot:new({x=self.x, y=self.y-6})
				add_actor(shot)
				sfx(1)
			elseif weapon_level == 1 then
				self.shot_timer = 20
				local shot = shot:new({x=self.x-3, y=self.y-6, pal = 8})
				add_actor(shot)
				shot = shot:new({x=self.x+3, y=self.y-6, pal = 8})
				add_actor(shot)
				sfx(2)
			else
				self.shot_timer = 15
				local shot = shot:new({x=self.x-3, y=self.y-4, pal = 12, speed = 6, plasma = true})
				add_actor(shot)
				shot = shot:new({x=self.x+3, y=self.y-4, pal = 12, speed = 6, plasma = true})
				add_actor(shot)
				local shot = shot:new({x=self.x, y=self.y-6, pal = 10, speed = 6, plasma = true})
				add_actor(shot)
				sfx(3)
			end
		end
	else
		self.shot_timer -=1
	end
	self.iframes = max(0,self.iframes-1)
end

function player:draw()
	if self.iframes%4<2 then
		-- Double weapons
		local weapon_sprite = 4
		spr(weapon_sprite, self.x-self.double_dist, self.y)
		spr(weapon_sprite, self.x+self.double_dist-7, self.y, 1, 1, true)
		--Ship
		sspr(0,0,9,14,self.x-4, self.y)
	end
end

function player:hit()
	if self.iframes <=0 then
		sfx(7)
		self.iframes = 60
		if weapon_level > 0 then
			weapon_level -=1
		else
			dying = true
			stage_over = true
			intro = true
			lives -=1
		end
	end
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
	self.interactable = not tutorial_over
	self.y+=self.speed * game_speed
	if self.y >=128 then
		self.dead = true;
	elseif self:collides(player) then
		charge +=1
		self.dead = true
		add_actor(points_marker:new({x = self.x+4, y = self.y+3, value = 1}))
		if charge >= max_charge then
			sfx(6)
		else
			sfx(5)
		end
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

basic_enemy = actor:new({y=-64, colour = 8, collision_width=9, collision_height=9, collision_offset_x=-4, collision_offset_y=-4, sine_timer = 0, enemy = true, points=1, actions = {{x=64,y=-8}, {x=64,y=64}, {x=64,y=56-8, shoot=true}}, final="target", action_counter=1, actions_over = false, target_timer = 0, eye_counter = 0, interactable = true})

function basic_enemy:update()
	if not self.tail_pos then
		self.tail_pos = {}
		for i = 0,4 do
			self.tail_pos[i] = {x=self.x, y=self.y}
		end
		self:set_initial()
		self.x = self.actions[1].x
		self.y = self.actions[1].y
		self.prev_x = self.x
		self.prev_y = self.y
		self.goal_x = self.actions[2].x
		self.goal_y = self.actions[2].y
	end

	if not dying then
		if not self.actions_over then
			self:move()
		elseif self.final == "go_away" then
			self:go_away()
		elseif self.final == "target" then
			self:target()
		end
	end

	if self.preparing_shot and time_unit > 0.75 and not actions_over then
		self.eye_counter = time_unit * 16 - 12
	elseif self.eye_counter > 0.2 then
		self.eye_counter -= 0.2
	else
		self.eye_counter = 0
	end

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

	if self:collides(player) then
		player:hit()
	end

	if self.y > 128 then
		self.dead = true
	end

	if dying then
		self.y += 1
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
	if not self.actions_over then
		self.prev_x = self.actions[self.action_counter].x
		self.prev_y = self.actions[self.action_counter].y

		if self.actions[self.action_counter].shoot then
			add_actor(enemy_attack:new({x=self.x-2, y=self.y-2, colour = self.colour}))
		end

		self.action_counter +=1

		if self.action_counter > #self.actions then
			self.actions_over = true
		else
			self.goal_x = self.actions[self.action_counter].x
			self.goal_y = self.actions[self.action_counter].y
			self.preparing_shot = self.actions[self.action_counter].shoot
		end
	end
end

function basic_enemy:go_away()
	self.y+=1 * game_speed
	self.x = self.goal_x + 16 * sin(time_unit)
end

function basic_enemy:target()
	if self.target_timer < 50 then
		self.target_x = (player.x-self.x)/10
		self.target_y = (player.y+8-self.y)/10
		self.x -= 0.05 * game_speed * self.target_x
		self.y -= 0.05 * game_speed * self.target_y
		self.target_timer+=game_speed
	else
		self.x += 0.5 * game_speed * self.target_x
		self.y += 0.5 * game_speed * self.target_y
	end
end

function basic_enemy:draw()
	self.depth = 2 + self.y/128
	if self.tail_pos then
		for i = 0,4 do
			circfill(self.tail_pos[i].x, self.tail_pos[i].y, 4-i, self.colour)
		end
	end
	draw_eye(self.x,self.y,self.eye_counter)
	--print(self.action_counter.."",self.x, self.y, 9)
end

function basic_enemy:hit()
	if not self.dead and self.y>-4 then
		self.dead = true
		add_actor(points_marker:new({x = self.x, y = self.y, value = self.points}))

		for i =0,0.9,0.1 do
			add_actor(death_effect:new({x=self.x, y=self.y, colour=self.colour, angle = i}))
		end

		if(rnd(6)<3) add_actor(powerup:new({x=self.x-4, y = self.y-4}))
		sfx(4)
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
	--if self.life%2==0 then
	local print_string = self.value.."0"
	for i=-1,1 do
		for j=-1,1 do
			print(print_string, self.x-2*#print_string+i, self.y-3+j, 0)
		end
	end
	print(print_string, self.x-2*#print_string, self.y-3, 7)
	--end
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
	clip()
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

enemy_attack = actor:new({collision_width=5, collision_height=5, colour = 8, interactable = true})

function enemy_attack:update()
	self.y+=1 * game_speed
	if self.y > 128 then
		self.dead = true
	end
	if self:collides(player) then
		player:hit()
		self.dead = true
	end
end

function enemy_attack:draw()
	self.depth = 2 + self.y/128
	pal(8, self.colour)
	spr(35, self.x, self.y)
	pal()
end

--------------------------------------------------------------------------------------------------------------------------------

tutorial_message_1 = actor:new({y=32, depth = 30, life = 0, time = 6, interactable = true})

function tutorial_message_1:update()
	if self.life > self.time then
		self.dead = true
		tutorials_shown+=1
	end
end

function tutorial_message_1:time_unit_over()
	self.life+=1
end

function tutorial_message_1:draw()
	centre_pr("use the left and",64,self.y,7)
	centre_pr("right buttons",64,self.y+8,7)
	centre_pr("to move.",64,self.y+16,7)
	centre_pr("move to collect",64,self.y+32,7)
	centre_pr("the powerups!",64,self.y+40,7)
end

tutorial_message_2 = tutorial_message_1:new({time=3})

function tutorial_message_2:draw()
	centre_pr("press either button",64,self.y+32,7)
	centre_pr("to shoot!",64,self.y+40,7)
end

--------------------------------------------------------------------------------------------------------------------------------

zone_controller = actor:new({position = 1, wait = 0})

function zone_controller:set_zone(z)
	self.zone = z
	self.position = 1
	self.wait = 0
end

function zone_controller:time_unit_over()
	if self.zone then
		if self.wait > 0 then
			self.wait -=1
		elseif self.position > #self.zone then
			self.zone = nil
			stage_over = true
			intro = true
		else
			local current_instruction = self.zone[self.position]
			if current_instruction.wait then
				self.wait = current_instruction.wait
			elseif current_instruction.tutorial == 1 then
				add_actor(tutorial_message_1:new())
			elseif current_instruction.tutorial == 2 then
				add_actor(tutorial_message_2:new())
			else
				create_enemies(current_instruction)
			end

			self.position +=1
		end
	end
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
	num_time_units = 0

	lives = 7

	intro_black_bars = 60
	intro_timer = 120
	intro = true
	stage_over = false

	enemy_col_1 = 8
	enemy_col_2 = 3
	enemy_col_3 = 14
	enemy_col_4 = 12
	special_enemy_col = 9

	--enable mouse for testing
	--poke(0x5f2d, 1)
	setup_zones()

	add_actor(zone_controller)

	current_zone = 1

	zone_controller:set_zone(zones[current_zone])

	tutorials_shown = 0
end

function setup_zones()
	zones = {}
	zones[1] = {
		{tutorial = 1},
		{{powerup = 60}},
		{{powerup = 80}},
		{{powerup = 90}},
		{{powerup = 60}},
		{{powerup = 40}},
		{{powerup = 30}},
		{{powerup = 60}},
		{wait = 1},
		new_basic_formation(3, 64, 32, -32, 8, 4, false, 0),
		{tutorial = 2},
		{wait = 4},
		new_basic_formation(3, 64, 32, -32, 8, 3, false, 0),
		{wait = 3},
		new_basic_formation(2, 32, 32, 24, 8, 3, false, 0),
		new_basic_formation(2, 96, 32, -24, 8, 2, false, 0),
		{wait = 3},
		new_basic_formation(5, 64, 32, -20, 8, 3, false, 0),
		join({new_side_bouncer("left",16,64,32,64,3,false,1), new_side_bouncer("right",112,64,96,64,3,false,1)}),
		{wait = 5},
		new_basic_formation(3, 64, 64, -40, 8, 4, false, 0),
		new_basic_formation(3, 64, 32, 32, 8, 1, "lots", 0),
		{wait = 5},
		new_basic_formation(5, 64, 32, -20, 8, 3, false, 0),
		join({new_side_bouncer("left",16,64,32,64,2,false,2), new_side_bouncer("right",112,64,96,64,2,false,2)}),
		{wait = 16}
	}
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

	tutorial_over = tutorials_shown >= 2

	if not update_intro() then
		do_timing()
	end
	for a in all(actors) do
		a:update()
		if a.dead then
			del(actors, a)
		end
	end

	if not any_enemies() and time_unit < 0.1 then
		-- add_actor(basic_enemy:new())
		-- add_actor(basic_enemy:new({x=32,y=64}))
		-- add_actor(basic_enemy:new({x=96,y=64}))
		-- add_actor(basic_enemy:new({x=24,y=32}))
		-- add_actor(basic_enemy:new({x=108,y=32}))
		--create_enemies(join( { new_basic_formation(5,64,32,20,8,3,true,flr(rnd(4))), new_basic_formation(3,64,64,-20,8,3,false,flr(rnd(4))) } ))


	end
	--debug_weapon_level()
	update_weapon()
	--debug_many_powerups()

	animate_powerups()

	debug_speed()

	if dying then
		star_speed = max(0, star_speed-0.1)
	elseif stage_over then
		star_speed +=0.2
	else
		star_speed = 2*game_speed
	end

	score:update()
end

function create_enemies(enemies)
	for a in all(enemies) do
		if a.powerup then
			add_actor(powerup:new({x=a.powerup, y=-8}))
		else
			local enemy = basic_enemy:new()
			enemy.actions = a.actions
			enemy.points = a.level + 1

			if a.level == 0 then
				enemy.colour = enemy_col_1
				enemy.final = "go_away"
			elseif a.level == 1 then
				enemy.colour = enemy_col_2
				enemy.final = "go_away"
			elseif a.level == 2 then
				enemy.colour = enemy_col_3
				enemy.final = "target"
			elseif a.level == 3 then
				enemy.colour = enemy_col_4
				enemy.final = "target"
			elseif a.level == 4 then
				enemy.colour = special_enemy_col
				enemy.final = "go_away"
				enemy.points = 10
			end

			add_actor(enemy)
		end

	end
end

function new_basic_formation(num, centre_x, centre_y, x_dist, y_dist, iterations, shoot, add_level)
	local formation = {}
	for i = 0,num-1 do
		local enemy = {}
		enemy.level = add_level + i%2
		local x_pos = centre_x - x_dist * (i-(num-1)/2)

		local actions = {}

		add(actions, {x=x_pos, y=-16})

		local y_mult = -1
		if i%2==0 then
			y_mult = 1
		end

		for j = 0, iterations + i do
			i_shoot = false
			if shoot == "lots" or (shoot and j == iterations+i-1) then
				i_shoot = true
			end
			add(actions, {x=x_pos, y=centre_y + y_dist * y_mult, shoot=i_shoot})
			y_mult = -y_mult
		end


		enemy.actions = actions

		add(formation, enemy)
	end
	return formation
end

function new_side_bouncer(side, x1, y1, x2, y2, num_times, shoot, level)
	local formation = {}
	local enemy = {}
	enemy.level = level
	local actions = {}
	if side == "right" then
		add(actions, {x=144,y=y1})
	else
		add(actions, {x=-16,y=y1})
	end
	local first = true
	for i = 0, num_times do
		local i_shoot = i == num_times-1 and shoot
		if first then
			add(actions, {x=x1,y=y1,shoot=i_shoot})
		else
			add(actions, {x=x2,y=y2,shoot=i_shoot})
		end
		first = not first
	end
	enemy.actions = actions
	add(formation, enemy)
	return formation
end

function join(lists)
	new_list = {}
	for l in all(lists) do
		for a in all(l) do
			add(new_list, a)
		end
	end
	return new_list
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

function update_intro()
	if intro then
		if stage_over then
			intro_timer +=1
		else
			intro_timer -=1
			player.x = 64
			player.mom = 0
			player.y=128
		end
		intro_black_bars = min(intro_timer, 60)
		if not stage_over and intro_timer <= 0 then
			intro = false
			intro_timer = -120
			num_time_units = 0
			dying = false
		elseif intro_timer > 120 then
			stage_over = false
			zone_controller:set_zone(zones[current_zone])
			tutorials_shown = 0
		end
		return true
	end
	return false
end

function do_timing()
	if anything_interactable() then
		time_unit += 0.01 * game_speed
	else
		time_unit = flr(time_unit+1)
	end
	if time_unit >= 1 then
		time_unit -=1
		num_time_units += 1
		for a in all(actors) do
			a:time_unit_over()
		end
	end
	slerp_time_unit = 1-(cos(time_unit/2)+1)/2
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

function anything_interactable()
	for a in all(actors) do
		if a.interactable then
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
	draw_intro()
	pr(""..num_time_units,0,0,7)
end

function draw_intro()
	if intro then
		clip(0,0,127,120)
		rectfill(0,0,127,intro_black_bars,0)
		rectfill(0,120-intro_black_bars,127,119,0)
		if intro_timer > 60 then
			centre_pr("zone 1", 64, 50, 7)
			local lives_string = "`x "..lives
			sspr(0,0,9,14,45,68)
			pr(lives_string,59,72,7)
		else
			line(0,intro_black_bars, 127, intro_black_bars, 2)
			line(0,120-intro_black_bars, 127, 120-intro_black_bars, 2)
		end
	end
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

function centre_pr(str, x, y, col)
	local len = 0
	for i=0,#str do
		if sub(str,i,i) != "`" then
			len+=3
		end
	end
	pr(str, x-len, y-3, col)
end

-- Code by Zep

fdat = [[  0000.0000! 739c.e038" 5280.0000# 02be.afa8$ 23e8.e2f8% 0674.45cc& 6414.c934' 2100.0000( 3318.c618) 618c.6330* 012a.ea90+ 0109.f210, 0000.0230- 0000.e000. 0000.0030/ 3198.cc600 fef7.bdfc1 f18c.637c2 f8ff.8c7c3 f8de.31fc4 defe.318c5 fe3e.31fc6 fe3f.bdfc7 f8cc.c6308 feff.bdfc9 fefe.31fc: 0300.0600; 0300.0660< 0199.8618= 001c.0700> 030c.3330? f0c6.e030@ 746f.783ca 76f7.fdecb f6fd.bdf8c 76f1.8db8d f6f7.bdf8e 7e3d.8c3cf 7e3d.8c60g 7e31.bdbch deff.bdeci f318.c678j f98c.6370k def9.bdecl c631.8c7cm dfff.bdecn f6f7.bdeco 76f7.bdb8p f6f7.ec60q 76f7.bf3cr f6f7.cdecs 7e1c.31f8t fb18.c630u def7.bdb8v def7.b710w def7.ffecx dec9.bdecy defe.31f8z f8cc.cc7c[ 7318.c638\ 630c.618c] 718c.6338^ 2280.0000_ 0000.007c``4100.0000`a001f.bdf4`bc63d.bdfc`c001f.8c3c`d18df.bdbc`e001d.be3c`f3b19.f630`g7ef6.f1fa`hc63d.bdec`i6018.c618`j318c.6372`kc6f5.cd6c`l6318.c618`m0015.fdec`n003d.bdec`o001f.bdf8`pf6f7.ec62`q7ef6.f18e`r001d.bc60`s001f.c3f8`t633c.c618`u0037.bdbc`v0037.b510`w0037.bfa8`x0036.edec`ydef6.f1ba`z003e.667c{ 0188.c218| 0108.4210} 0184.3118~ 02a8.0000`*013e.e500]]
cmap={}
for i=0,#fdat/11 do
 local p=1+i*11
 cmap[sub(fdat,p,p+1)]=
  tonum("0x"..sub(fdat,p+2,p+10))
end

function pr(str,sx,sy,col)
 local sx0=sx
 local p=1
 while (p <= #str) do
  local c=sub(str,p,p)
  local v

  if (c=="\n") then
   -- linebreak
   sy+=9 sx=sx0
  else
      -- single (a)
      v = cmap[c.." "]
      if not v then
       -- double (`a)
       v= cmap[sub(str,p,p+1)]
       p+=1
      end

   --adjust height
   local sy1=sy
   if (band(v,0x0.0002)>0)sy1+=2

   -- draw pixels
   for y=sy1,sy1+5 do
       for x=sx,sx+4 do
        if (band(v,0x8000)<0) pset(x,y,col)
        v=rotl(v,1)
       end
      end
      sx+=6
  end
  p+=1
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
00000000000000000000000008880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000088888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000bbb088788000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000088888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000008880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0001000024350223501f3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000293502c3502e3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002e35032350353503630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000337701b7702e7701777026770137701377016770187701c7702177023770217700f600116001160011600000000000000000000000000000000000000000000000000000000000000000000000000000
000100001f0502305026050290502b0502d0502d0502c0002c0003100033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001f0501f0501f0502705027050270503305033050330500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002a35023350283501f360263601c36022360173601c36013360183600f370133700b370103700937000000000000000000000000000000000000000000000000000000000000000000000000000000000
