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
	if (title_screen) return

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
		if portal1 then
			self.mom = 0
			if self.y<56 then
				self.y = 56
				if self.iframes == 0 then
					self.iframes = 40
				elseif self.iframes == 11 then
					self.iframes = 12
				end
			end
		end
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
	if self.shot_timer <= 0 and not warp_zone and not intro then
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
				self.shot_timer = 20
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
	if self.iframes%4<2 and not title_screen then
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
			move_stars_anyway = false
			stage_over = true
			intro = true
			lives -=1
			next_zone = current_zone
			if lives < 0 then
				game_over = true
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------

star = actor:new({colour = 7, depth = -20, background})

function star:update()
	if not self.background then
		self.y += star_speed
	else
		self.y += star_speed/2
	end

	if self.y >= 128 then
		self.y -=128
		self.x = rnd(127)
	end
	if self.background then
		self.colour = star_col_2
	else
		self.colour = star_col_1
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
	self.interactable = current_zone == 7 or (not tutorial_over and current_zone == 1)
	self.y+=self.speed * game_speed
	if self.y >=128 then
		self.dead = true;
	elseif self:collides(player) then
		charge +=1
		self.dead = true
		if not self.no_points then
			add_actor(points_marker:new({x = self.x+5, y = self.y+3, value = 5}))
		end
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

basic_enemy = actor:new({y=-64, colour = 8, collision_width=9, collision_height=9, collision_offset_x=-4, collision_offset_y=-4, sine_timer = 0, enemy = true, points=10, actions = {{x=64,y=-8}, {x=64,y=64}, {x=64,y=56-8, shoot=true}}, final="target", action_counter=1, actions_over = false, target_timer = 0, eye_counter = 0, interactable = true})

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
		elseif self.final == "vanish" then
			self.dead = true
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
		self.x += 0.2 * game_speed * self.target_x
		self.y += 0.2 * game_speed * self.target_y
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
		if self.points!=0 then
			add_actor(points_marker:new({x = self.x, y = self.y, value = self.points}))
		end

		for i =0,0.9,0.1 do
			add_actor(death_effect:new({x=self.x, y=self.y, colour=self.colour, angle = i}))
		end

		local no_points = false
		if self.points == 0 then
			no_points = true
		end
		if(rnd(6)<3) add_actor(powerup:new({x=self.x-4, y = self.y-4, no_points = no_points}))
		sfx(4)
	end
end

--------------------------------------------------------------------------------------------------------------------------------

boss_enemy = basic_enemy:new({collision_width = 33, collision_height = 16, collision_offset_x = -16, collision_offset_y = -8, secondary_colour = 2, iframes=0, health=32, max_health=32, points=1000, pupil_offset_x = 0, pupil_offset_y = 0, pupil_offset_x_goal=0, pupil_size = 3, name="crimson general", boss=true})

function boss_enemy:update()
	if not self.prev_x then
		self.prev_x = self.x
		self.prev_y = self.y
		self.goal_x = self.x
		self.goal_y = self.y
	end
	self:update_unique()
	self.iframes = max(0, self.iframes-1)
	if not dying then
		self:move()
	end

	if dying then
		self.y += 1
	end
	if self.y>140 then
		self.dead = true
		if healthbar.tracking == self then
			healthbar.tracking = nil
		end
	end
end

function boss_enemy:update_unique()

	if self.pupil_offset_x < self.pupil_offset_x_goal then
		self.pupil_offset_x += 1
	elseif self.pupil_offset_x > self.pupil_offset_x_goal then
		self.pupil_offset_x -= 1
	end
	if self.attacking then
		self.pupil_size+=0.5
		if self.pupil_size >= 3 then
			add_actor(big_enemy_attack:new({x=self.x-3+self.pupil_offset_x, y=self.y-3+self.pupil_offset_y+4, colour = self.colour}))
			self.pupil_size = 3
			self.attacking=false
		end
	end

end

function boss_enemy:draw()
	if self.iframes%4<2 then
		pal(2, self.secondary_colour)
		circfill(self.x, self.y, 16, self.colour)
		sspr(0, 40, 32, 16, self.x-16, self.y-4)
		circ(self.x, self.y, 16, self.secondary_colour)
		self:draw_unique()
		circfill(self.x+self.pupil_offset_x, self.y+4+self.pupil_offset_y, self.pupil_size, 0)
		pal()
	end
end

function boss_enemy:draw_unique()
	sspr(32, 40, 32, 16, self.x-16, self.y-9)
	sspr(32, 40, 32, 16, self.x-16, self.y+4, 32, 16, false, true)
end

function boss_enemy:hit()
	if not self.dead and self.y>-4 and self.iframes <=0 then
		self.health-=1
		self.iframes = 16

		sfx(4)
		if self.health <=0 then
			self.dead = true
			add_actor(points_marker:new({x = self.x, y = self.y, value = self.points}))

			for i =0,0.9,0.1 do
				add_actor(death_effect:new({x=self.x, y=self.y, colour=self.colour, angle = i, size=6}))
			end
			next_level = 1
			for i in all(actors) do
				if i.enemy or i.projectile then
					i.dead = true
				end
			end
			if self.emperor then
				self.emperor.dead = true
				add_actor(points_marker:new({x = self.emperor.x, y = self.emperor.y, value = self.emperor.points}))

				for i =0,0.9,0.1 do
					add_actor(death_effect:new({x=self.emperor.x, y=self.emperor.y, colour=self.emperor.colour, angle = i, size=6}))
				end
			end
			self:on_kill()
		end
	end
end

function boss_enemy:on_kill()
	bosses_killed[1] = true
end

function boss_enemy:time_unit_over()
	self.goal_x = flr(rnd(3)) * 32 + 32
	if self.y < 0 then
		self.goal_x=64
	end
	self.goal_y = 32
	self.prev_x = self.x
	self.prev_y = self.y
	if self.goal_x < self.x-4 then
		self.pupil_offset_x_goal = -4
	elseif self.goal_x > self.x+4 then
		self.pupil_offset_x_goal = 4
	elseif self.y > 0 then
		self.pupil_offset_x_goal = 0
		self.attacking = true
		self.pupil_size = 0
	end

	for i = 32,96,32 do
		if abs(i-self.x) > 16 and self.y > 0 then
			add_actor(basic_enemy:new({x=i,actions_over=true,points=0,final="go_away", actions = {{x=i,y=-8}, {x=i,y=64}} }))
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------

boss_enemy_2 = boss_enemy:new({colour=12,secondary_colour=1,name="azure general", shoot_turn = false, preparing_shot = false, shots_fired = 0, shot_delay=0})

function boss_enemy_2:update_unique()
	if self.preparing_shot then
		if self.pupil_size>1 then
			self.pupil_size -= 0.5
		elseif self.shots_fired < 6 then
			if self.shot_delay<=0 then
				self.shots_fired+=1
				self.shot_delay=1
				add_actor(big_enemy_attack:new({x=self.x-3+self.pupil_offset_x, y=self.y-3+self.pupil_offset_y+4, colour = self.colour, add_x = self.add_x}))
			else
				self.shot_delay-=0.1
			end
		else
			self.preparing_shot = false
			self.shots_fired = 0
		end
	else
		self.pupil_size = 3
	end
	local dist = player.x - self.x
	self.pupil_offset_x = dist / 32 - 0.5
	self.pupil_offset_y = 2 - abs(self.pupil_offset_x /2)
	self.add_x = (player.x - self.x) / (player.y - self.y)
end

function boss_enemy_2:on_kill()
	bosses_killed[2] = true
end

function boss_enemy_2:draw_unique()
	sspr(64, 40, 32, 16, self.x-16, self.y-9)
end

function boss_enemy_2:time_unit_over()
	if self.y < 0 then
		self.goal_x=64
	elseif not self.shoot_turn then
		if self.goal_x < 64 then
			self.goal_x = 96
		else
			self.goal_x = 32
		end
		self.shoot_turn = true
	elseif self.shoot_turn then
		self.shoot_turn = false
		self.preparing_shot = true
		-- add_actor(basic_enemy:new({x=(128-self.x),actions_over=true,points=0,final="go_away", actions = {{x=(128-self.x),y=-8}, {x=(128-self.x),y=64, colour=12}} }))
	end
	self.goal_y = 32
	self.prev_x = self.x
	self.prev_y = self.y
end

--------------------------------------------------------------------------------------------------------------------------------

boss_enemy_3 = boss_enemy:new({colour=11,secondary_colour=3,name="verdant general", shoot_turn = false, preparing_shot = false, shots_fired = 0, shot_delay=0})

function boss_enemy_3:update_unique()
	if self.preparing_shot then
		if self.pupil_size>1 then
			self.pupil_size -= 0.5
		elseif self.shots_fired < 6 then
			if self.shot_delay<=0 then
				self.shots_fired+=1
				self.shot_delay=1
				add_actor(big_enemy_attack:new({x=self.x-3+self.pupil_offset_x, y=self.y-3+self.pupil_offset_y+4, colour = self.colour, add_x = self.add_x}))
			else
				self.shot_delay-=0.1
			end
		else
			self.preparing_shot = false
			self.shots_fired = 0
		end
	else
		self.pupil_size = 3
	end
	local dist = player.x - self.x
	self.pupil_offset_x = dist / 32 - 0.5
	self.pupil_offset_y = 2 - abs(self.pupil_offset_x /2)
	self.add_x = (player.x - self.x) / (player.y - self.y)
end

function boss_enemy_3:draw_unique()
	sspr(96, 40, 32, 16, self.x-16, self.y-12)
end

function boss_enemy_3:on_kill()
	bosses_killed[3] = true
end

function boss_enemy_3:time_unit_over()
	if self.y < 0 then
		self.goal_x=64
	else
		--local x = rnd(64) + 32
		local x = player.x
		local y = 64
		if self.goal_x < 64 then
			self.goal_x = 127
			y +=16
			add_actor(basic_enemy:new({x=i,actions_over=false,points=0,final="vanish", actions = {{x=-8,y=y}, {x=x,y=y, shoot=true}, {x=136,y=y}}, colour=3}))
		else
			self.goal_x = 0
			add_actor(basic_enemy:new({x=i,actions_over=false,points=0,final="vanish", actions = {{x=136,y=y}, {x=x,y=y, shoot=true}, {x=-8,y=y}}, colour=3}))
		end
	end
	self.goal_y = 32
	self.prev_x = self.x
	self.prev_y = self.y
end

--------------------------------------------------------------------------------------------------------------------------------

empress = boss_enemy:new({colour=10,secondary_colour=9,name="empress and emperor", shoot_turn = false, preparing_shot = false, shots_fired = 0, shot_delay=0})

function empress:update_unique()

end

function empress:draw_unique()
	sspr(96, 24, 17, 16, self.x-8, self.y-20)
end

function empress:time_unit_over()
	if self.y < 0 then
		self.goal_x=32
	else
		self.goal_x = flr(rnd(4))*8 + 16
	end
	self.goal_y = 32
	self.prev_x = self.x
	self.prev_y = self.y

	local x = player.x
	local y = 64+8
	local off = rnd(2) < 1
	if off then
		y+=8
	end
	add_actor(basic_enemy:new({x=i,actions_over=false,points=0,final="vanish", actions = {{x=136,y=y}, {x=x-4,y=y, shoot=true}, {x=-8,y=y}}, colour=9}))
	if off then
		y-=8
	else
		y+=8
	end
	add_actor(basic_enemy:new({x=i,actions_over=false,points=0,final="vanish", actions = {{x=-8,y=y}, {x=x+4,y=y, shoot=true}, {x=136,y=y}}, colour=9}))
end

function empress:on_kill()
	bosses_killed[4] = true
	game_over = true
	game_over_message = "congratulations!"
end

--------------------------------------------------------------------------------------------------------------------------------

emperor = boss_enemy:new({colour=9,secondary_colour=4,name="not me plz", shoot_turn = false, preparing_shot = false, shots_fired = 0, shot_delay=0})

function emperor:update_unique()
	self.iframes = self.empress.iframes
end

function emperor:draw_unique()
	sspr(96, 8, 17, 16, self.x-8, self.y-20)
end

function emperor:time_unit_over()
	if self.y < 0 then
		self.goal_x=96
	else
		self.goal_x = flr(rnd(4))*8 + 16 + 64
	end
	self.goal_y = 32
	self.prev_x = self.x
	self.prev_y = self.y
end

function emperor:hit()
	self.empress:hit()
end

--------------------------------------------------------------------------------------------------------------------------------

mouth = boss_enemy:new()

function mouth:update()
	self.x = (self.empress.x + self.emperor.x) / 2
	self.y = self.empress.y+32
	if self.empress.dead then
		self.dead = true
	end
end

function mouth:time_unit_over()
end

function mouth:draw()
	sspr(64, 24, 32, 16, self.x-16, self.y-9)
end

function mouth:hit()
end

--------------------------------------------------------------------------------------------------------------------------------

healthbar = actor:new({tracking=nil, depth=20, y=-12})

function healthbar:update()
	if self.y > -12 and self.tracking == nil or (self.tracking != nil and self.tracking.health<=0) then
		self.y-=0.2
		if self.y<=-12 then
			self.tracking = nil
		end
	elseif self.y < 0 and self.tracking!=nil then
		self.y+=0.2
	end
end

function healthbar:draw()
	if self.tracking!=nil then
		rectfill(0,self.y,127,self.y+4,5)
		rectfill(1,self.y+1,126,self.y+3,2)
		if self.tracking.health>0 then
			rectfill(1,self.y+1,126*(self.tracking.health/self.tracking.max_health),self.y+3,8)
		end
		centre_pr(self.tracking.name,64,self.y+9,7)
	end
end

--------------------------------------------------------------------------------------------------------------------------------

points_marker = actor:new({value = 1, life = 0, depth = 50})

function points_marker:update()
	if self.life == 0 and not dying then
		score:add(self.value)
	end
	self.life+=1
	self.y-=0.1
	if self.life > 40 then
		self.dead = true
	end
end

function points_marker:draw()
	if not dying then
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
	local new_score = self.score+amount

	if amount > 0 and new_score % 2000 <= self.score % 2000 then
		lives+=1
		sfx(9)
	end

	self.score = mid(0,32000, new_score)
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

death_effect = actor:new({colour = 8, size = 4, angle = 0, dist = 0, dist_speed = 0.1, size_change=0.2})

function death_effect:update()
	if not self.inital_x then
		self.initial_x = self.x
		self.initial_y = self.y
	end
	self.size -= self.size_change
	self.dist += self.dist_speed
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

portal_particle = death_effect:new({dist_speed = -0.1})

--------------------------------------------------------------------------------------------------------------------------------

portal = actor:new({angle = 0, depth=-1})

function portal:update()
	if (self.next_zone == 7 and (not bosses_killed[1] or not bosses_killed[2] or not bosses_killed[3]))
	or (self.next_zone == 4 and bosses_killed[1])
	or (self.next_zone == 5 and bosses_killed[2])
	or (self.next_zone == 6 and bosses_killed[3])
	or (self.next_zone == 2 and bosses_killed[1] and bosses_killed[2])
	or (self.next_zone == 3 and bosses_killed[2] and bosses_killed[3])
	or (self.next_zone == 1 and (bosses_killed[1] and bosses_killed[2] and bosses_killed[3]))
	then
		self.disabled = true
	end
	self.angle+=0.26
	self.angle = self.angle%1
	for i =0,0 do
		local col = 1
		if (self.disabled) col=5
		add_actor(portal_particle:new({x=self.x + 16*cos(self.angle+i), y=self.y + 16*sin(self.angle+i),angle = self.angle+i, colour = col, size_change = 0.15}))
	end
	self.active = not self.disabled and abs(player.x - self.x) < 16
	if self.active and not self.used and (btnp(4) or btnp(5)) then
		self.used = true
		stage_over = true
		intro = true
		--warp_zone = false
		next_zone = self.next_zone
		if self.next_zone == 1 then
			game_speed += 0.5
		end
		sfx(10)
	end
end

function portal:draw()
	circfill(self.x,self.y,9,0)
	if (self.disabled) sspr(0,16,16,16,self.x-8, self.y-8)
end

--------------------------------------------------------------------------------------------------------------------------------

enemy_attack = actor:new({collision_width=5, collision_height=5, colour = 8, interactable = true, projectile = true})

function enemy_attack:update()
	if not self.played_sound then
		sfx(8)
		self.played_sound = true
	end
	self.y+=1 * game_speed
	if self.add_x then
		self.x+=self.add_x * game_speed
	end
	if self.y > 128 then
		self.dead = true
	end
	if self:collides(player) then
		player:hit()
		self.dead = true
	end
end

function enemy_attack:hit()

end

function enemy_attack:draw()
	self.depth = 2 + self.y/128
	pal(8, self.colour)
	spr(35, self.x, self.y)
	pal()
end

big_enemy_attack = enemy_attack:new({collision_width=7, collision_height=7, colour = 8, interactable = true})

function big_enemy_attack:draw()
	self.depth = 2 + self.y/128
	pal(8, self.colour)
	spr(36, self.x, self.y)
	pal()
end

--------------------------------------------------------------------------------------------------------------------------------

tutorial_message_1 = actor:new({y=32, depth = 30, life = 0, time = 6, interactable = true})

function tutorial_message_1:update()
	if self.life > self.time or game_speed > 1 then
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
		for a in all(actors) do
			if a.boss then
				return
			end
		end
		if self.wait > 0 then
			self.wait -=1
		elseif self.position > #self.zone then
			self.zone = nil
			stage_over = true
			intro = true
			warp_zone = true
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

	cartdata("mush_vitreous_1")

	actors = {}
	add_actor(player)
	star_speed = 2

	create_stars()

	time_unit = 0
	slerp_time_unit = 0
	num_time_units = 0

	enemy_col_1 = 8
	enemy_col_2 = 3
	enemy_col_3 = 14
	enemy_col_4 = 12
	special_enemy_col = 9

	--enable mouse for testing
	--poke(0x5f2d, 1)
	setup_zones()

	add_actor(zone_controller)

	add_actor(healthbar)

	-- load high scores
	high_scores = {}
	for i = 1, 5 do
		high_scores[i] = {name = {dget(4*i), dget(4*i+1), dget(4*i+2)}, score = dget(4*i+3)}
	end

	reset()
end

function reset()

	game_speed = 1
	star_col_1 = 10
	star_col_2 = 9

	bosses_killed = {}

	game_over_message = "game over"
	game_over = false
	player_name = {1,1,1}
	name_entry_pos = 1

	-- max_charge = 7
	-- charge = 0
	-- weapon_level = 0
	-- weapon_flash_time = 0
	-- title_screen = true
	--
	-- lives = 3
	-- powerup_timer = 0
	--
	-- warp_zone = false

	max_charge, charge, weapon_level, weapon_flash_time, title_screen, lives, powerup_timer, warp_zone, tutorials_shown, current_zone, dying = 7,0,0,0,true,3,0,false, 0, 1, false

	-- tutorials_shown = 0

	-- current_zone = 1
	zone_controller:set_zone(zones[current_zone])
	-- dying = false

	score.score = 0
	add_actor(delete_code)
	add_actor(konami_code)
	add_actor(lda_code)
end

function int_to_char(i)
	return sub(" abcdefghijklmnopqrstuvwxyz", i+1, i+1)
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
	-- zones[1] = {
	-- 	{wait=1}
	-- }
	zones[2] = {
		new_basic_formation(5, 64, 32, -24, 8, 2, true, 0),
		{wait=7},
		new_side_bouncer("left",32,32,96,32,4,"lots",2),
		new_side_bouncer("right",96,64,32,64,2,"lots",3),
		{wait=7},
		new_basic_formation(5, 64, 64, -24, 8, 6, false, 0),
		new_side_bouncer("left",32,32,64,32,4,"lots",2),
		new_side_bouncer("right",96,32,64,32,3,"lots",3),
		{wait=7},
		join({new_side_bouncer("left",32,32,96,32,4,"lots",2),new_side_bouncer("right",96,48,32,64,2,"lots",3)}),
		new_basic_formation(3, 64, 64, -24, 8, 2, true, 0),
		{wait=7},
		new_side_bouncer("left",256,16,-128,16,0,false,4),
		{wait=7},
		new_basic_formation(5, 64, 64, -24, 8, 4, "lots", 0),
		{wait=16}
	}

	zones[3] = {
		new_basic_formation(5, 64, 32, -24, 8, 2, true, 0),
		{wait=7},
		join({new_side_bouncer("left",32,64,32,32,4,"lots",2),new_side_bouncer("right",96,32,96,64,4,"lots",3)}),
		{wait=7},
		join({new_side_bouncer("left",32,32,32,64,4,"lots",3), new_side_bouncer("right",96,64,96,32,4,"lots",3)}),
		join({new_side_bouncer("left",32,32,96,32,3,false,2),new_side_bouncer("right",96,64,32,64,3,false,2)}),
		{wait=7},
		new_side_bouncer("left",256,16,-128,16,0,false,4),
		{wait=7},
		new_basic_formation(3, 64, 64, -24, 8, 2, true, 0),
		join({new_side_bouncer("left",32,32,96,32,4,"lots",2),new_side_bouncer("right",96,48,32,64,2,"lots",3)}),
		{wait=3},
		new_basic_formation(3, 64, 64, -24, 8, 2, true, 0),
		{wait=16}
	}

	zones[4] = {
		new_side_bouncer("left",72,64,56,64,4,false,0),
		new_side_bouncer("right",40,48,88,48,4,false,0),
		new_side_bouncer("left",104,32,24,32,4,false,0),
		{wait=16},
		{{boss=1}},
		{wait=16}
	}

	zones[5] = {
		new_side_bouncer("left",104,32,24,32,4,false,3),
		new_side_bouncer("right",40,48,88,48,4,false,3),
		new_side_bouncer("left",72,64,56,64,4,false,3),
		{wait=16},
		{{boss=2}},
		{wait=16}
	}

	zones[6] = {
		new_side_bouncer("left",72,64,56,64,4,false,1),
		new_side_bouncer("right",40,48,88,48,4,false,1),
		new_side_bouncer("left",104,32,24,32,4,false,1),
		{wait=16},
		{{boss=3}},
		{wait=16}
	}

	zones[7] = {
		{{powerup = 60}},
		{{powerup = 80}},
		{{powerup = 90}},
		{{powerup = 60}},
		{{powerup = 40}},
		{{powerup = 30}},
		{{powerup = 60}},
		{wait = 1},
		{{boss=4}},
		{wait=16}
	}
end

function create_stars()
	for i = 0,127,8 do
		add_actor(star:new({x=rnd(127), y=i}))
	end

	for i = 0,127,8 do
		add_actor(star:new({x=rnd(127), y=i, background = true, depth=-21}))
	end
end

---------------------------------------------------------------------------------------------------------------------------------

delete_code = actor:new({code = {2,2,2,2,3,3,3,3}, pointer = 0})

function delete_code:update()
	for i = 0,3 do
		if btnp(i) then
			if self.code[self.pointer] == i then
				self.pointer +=1
				if self.pointer > #self.code then
					self:do_event()
					sfx(9)
					self.pointer = 1
				end
			else
				self.pointer = 1
			end
		end
	end
end

function delete_code:delete()
	self.pointer = 1
	del(actors, self)
end

function delete_code:do_event()
	delete_mode = true
	delete_counter = 6
end

konami_code = delete_code:new({code = {2,2,3,3,0,1,0,1}})

function konami_code:do_event()
	lives = 30
end

lda_code = delete_code:new({code = {3,3,0,3,1}})

function lda_code:do_event()
	game_speed = 2
end

---------------------------------------------------------------------------------------------------------------------------------

function _update60()

	tutorial_over = tutorials_shown >= 2

	if title_screen then
		if delete_mode then
			if btnp(3) then
				delete_counter = min(delete_counter+1, 6)
			elseif btnp(2) then
				delete_counter = max(delete_counter-1, 1)
			end
			if btnp(4) or btnp(5) then
				if delete_counter == 6 then
					delete_mode = false
				else
					high_scores[delete_counter] = {name={0,0,0}, score=0}
					sort_highscores()
					save_highscores()
					sfx(7)
				end
			end
		elseif btnp(4) or btnp(5) then
			intro_black_bars = 60
			intro_timer = 120
			intro = true
			stage_over = false
			title_screen = false
			delete_code:delete()
			konami_code:delete()
			lda_code:delete()
		end
	else
		set_zone_properties()
		if not update_intro() then
			do_timing()
		end
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

	--debug_speed()

	if dying and not move_stars_anyway and not title_screen then
		star_speed = max(0, star_speed-0.1)
	elseif stage_over and not next_zone and not title_screen then
		star_speed +=0.2
	elseif warp_zone then
		star_speed = 0.5
	else
		star_speed = 2*game_speed
	end

	score:update()

	high_score_get = score.score > high_scores[5].score
end

function create_enemies(enemies)
	for a in all(enemies) do
		if a.powerup then
			add_actor(powerup:new({x=a.powerup, y=-8}))
		elseif a.boss == 1 then
			local boss = boss_enemy:new({x=64,y=-32})
			add_actor(boss)
			healthbar.tracking = boss
		elseif a.boss == 2 then
			local boss = boss_enemy_2:new({x=64,y=-32})
			add_actor(boss)
			healthbar.tracking = boss
		elseif a.boss == 3 then
			local boss = boss_enemy_3:new({x=64,y=-32})
			add_actor(boss)
			healthbar.tracking = boss
		elseif a.boss == 4 then
			local one = empress:new({x=32,y=-32})
			add_actor(one)
			local two = emperor:new({x=96,y=-32})
			add_actor(two)
			local three = mouth:new({x=64,y=-32})
			add_actor(three)
			two.empress = one
			one.emperor = two
			three.empress = one
			three.emperor = two
			healthbar.tracking = one
		else
			local enemy = basic_enemy:new()
			enemy.actions = a.actions
			enemy.points = (a.level + 1)*10

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
				enemy.final = "vanish"
				enemy.points = 500
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
		local i_shoot = shoot=="lots" or (i == num_times-1 and shoot)
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
			if (not warp_zone) sfx(13)
			intro = false
			intro_timer = -120
			num_time_units = 0
			dying = false
			move_stars_anyway = true
			if warp_zone and not next_zone then
				portal1 = portal:new({x=32,y=60, next_zone = next_zone_1})
				portal2 = portal:new({x=96,y=60, angle=0.125, next_zone = next_zone_2})
				add_actor(portal1)
				add_actor(portal2)
			end
		elseif intro_timer > 120 then
			if not game_over then
				stage_over = false
				if (portal1) portal1.dead = true
				if (portal2) portal2.dead = true
				portal1 = nil
				portal2 = nil
				if next_zone then
					zone_controller:set_zone(zones[next_zone])
					current_zone = next_zone
					next_zone = nil
					warp_zone = false
				end
				tutorials_shown = 0
			else
				if high_score_get then
					if btnp(1) and name_entry_pos < 3 then
						name_entry_pos+=1
					elseif btnp(0) and name_entry_pos > 1 then
						name_entry_pos -=1
					elseif btnp(2) then
						player_name[name_entry_pos] = (player_name[name_entry_pos] + 1) % 27
					elseif btnp(3) then
						player_name[name_entry_pos] = (player_name[name_entry_pos] - 1) % 27
					end
				end
				if btnp(4) or btnp(5) then
					if high_score_get then
						high_scores[5] = {name = player_name, score = score.score}
						sort_highscores()
						save_highscores()
					end
					reset()
				end
			end
		end
		return true
	end
	return false
end

function set_zone_properties()
	if current_zone == 1 then
		star_col_1 = 7
		star_col_2 = 12
		next_zone_1 = 2
		next_zone_2 = 3
	elseif current_zone == 2 then
		star_col_1 = 7
		star_col_2 = 14
		next_zone_1 = 4
		next_zone_2 = 5
	elseif current_zone == 3 then
		star_col_1 = 7
		star_col_2 = 11
		next_zone_1 = 5
		next_zone_2 = 6
	elseif current_zone == 4 then
		star_col_1 = 8
		star_col_2 = 2
		next_zone_1 = 1
		next_zone_2 = 7
	elseif current_zone == 5 then
		star_col_1 = 12
		star_col_2 = 1
		next_zone_1 = 1
		next_zone_2 = 7
	elseif current_zone == 6 then
		star_col_1 = 11
		star_col_2 = 3
		next_zone_1 = 1
		next_zone_2 = 7
	elseif current_zone == 7 then
		star_col_1 = 10
		star_col_2 = 6
		next_zone_1 = 0
		next_zone_2 = 0
	end
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

-- function debug_weapon_level()
-- 	if btnp(2) then
-- 		charge +=1
-- 	elseif btnp(3) then
-- 		charge -=1
-- 	end
-- end

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
	if warp_zone and not stage_over then
		draw_warp_zone()
	end
	--debug_draw_collision_boxes()
	--print(#actors, 0,0,7)

	if title_screen then
		draw_title_screen()
	else
		draw_hud()
		score:draw()
		draw_intro()
	end
	--pr(""..num_time_units,0,0,7)
end

function draw_title_screen()
	--cls()
	pr("20,000`p`t`s = 1up", 22, 2, 6)
	sspr(0,64,128,64,0,12)
	local str = "high scores"
	if delete_mode then
		str = "delete which score?"
		pr("cancel", 20, 121, 7)
			spr(50, 8, delete_counter * 8 + 73)
	end
	centre_pr(str, 64, 72, 7)
	for i=1,5 do
		if high_scores[i].score > 0 then
			centre_pr(i..": ".. num_to_name(high_scores[i].name).." - ".. score_to_string(high_scores[i].score), 64, 76+8*i, 7-i%2)
		end
	end
	if high_scores[1].score <=0 then
		centre_pr("none", 64, 82, 6)
	end
end

function score_to_string(score)
	local nums = {10, 100, 1000, 10000}
	local str = ""
	for i in all(nums) do
		if score < i then
			str = str.."0"
		end
	end
	return str .. score .. "0"
end

function draw_intro()
	if intro then
		clip(0,0,128,120)
		if intro_black_bars>0 then
			rectfill(0,0,127,intro_black_bars,0)
			rectfill(0,120-intro_black_bars,127,119,0)
		end
		if intro_timer > 60 then

			if game_over then
				camera(0,16)
				if high_score_get then
					centre_pr("new high score!", 64,68,11)
					centre_pr("enter name", 64,96,7)
					centre_pr("["..num_to_name(player_name).."]", 64,112,7)
					sspr(48,0,8,24,48+6*name_entry_pos,104)
				else
					if score.score > 0 then
						centre_pr("your score", 64,68,10)
					else
						centre_pr("did you even try?", 64,68,10)
					end
					centre_pr("push button", 64,112,7)
				end
				if score.score > 0 then
					centre_pr(score.score.."0", 64,80,6)
				else
					centre_pr("0", 64,80,6)
				end
			else
				local lives_string = "`x "..lives
				sspr(0,0,9,14,47,68)
				pr(lives_string,61,72,7)
			end

			local text = "final zone"
			if game_over then
				text = game_over_message
			elseif next_zone then
				if (next_zone != 7) text= "zone "..next_zone
			elseif warp_zone then
				text = "warp zone"
			else
				if (current_zone != 7) text= "zone "..current_zone
			end
			centre_pr(text, 64, 50, 7)

			camera()
		else
			line(0,intro_black_bars, 127, intro_black_bars, 2)
			line(0,120-intro_black_bars, 127, 120-intro_black_bars, 2)
		end
	end
end

function num_to_name(nums)
	return int_to_char(nums[1])..int_to_char(nums[2])..int_to_char(nums[3])
end

function draw_warp_zone()
	centre_pr("which way now?", 64, 16, 7)
	if portal1 and portal2 then
		colour1, colour2 = 6, 6
		if (portal1.active) colour1 = 12
		if (portal2.active) colour2 = 12
		centre_pr("zone "..next_zone_1, 32, 32, colour1)
		local text = "zone "..next_zone_2
		if next_zone_2 == 7 then
			text = "???"
		end
		centre_pr(text, 96, 32, colour2)
		if (portal1.active or portal2.active) centre_pr("push button", 64, 88, 7)
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

function sort_highscores()
	local new_high_scores = {}
	while #high_scores > 0 do
		largest_score = -1
		for a in all(high_scores) do
			if a.score > largest_score then
				largest_score_obj = a
				largest_score = a.score
			end
		end
		add(new_high_scores, largest_score_obj)
		del(high_scores, largest_score_obj)
	end
	high_scores = new_high_scores
end

function save_highscores()
	for i = 1, 5 do
		dset(4*i, high_scores[i].name[1])
		dset(4*i+1, high_scores[i].name[2])
		dset(4*i+2, high_scores[i].name[3])
		dset(4*i+3, high_scores[i].score)
	end
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
	-- local len = 0
	-- for i=0,#str do
	-- 	if sub(str,i,i) != "`" then
	-- 		len+=3
	-- 	end
	-- end
	pr(str, x-#str*3, y-3, col)
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
00006000000000000b00bbb000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000000000b00bbb00cccc00000006000000ccc0000999000000000000000000000000000000000000000000000000000000000000000000000000000
00007000000000000b00bbb000cccc00000060000006660009999900000000000000000000000000000000000000000000000000000000000000000000000000
00077700000000000b00bbb0000cccc0000770000007770000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007c700000000000b00bbb000cccc00000767000007670000000000000000000000000000000000000000000000000000000000000000000000000000000000
007ccc70000000000000bbb00cccc000000760000007600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777770000000000b00bbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06776776000000000000bbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67776777600000000000bbb000000000066666660000000000000000000000000000000000000000000000000000000040000000400000004000000000000000
67576757600000000b00000001111000655555556000000000000000000000000000000000000000000000000000000044000004940000044000000000000000
67777777600000000000bbb000111100555ccc555000000000000000000000000000000000000000000000000000000049400049994000494000000000000000
d77d0d77d0000000000000000001111055ccc7c55000000000000000000000000000000000000000000000000000000049940499999404994000000000000000
0880008800000000000000000011110055ccccc55000000000000000000000000000000000000000000000000000000049994999899949994000000000000000
09900099000000000000bbb001111000555ccc555000000009999900000000000000000000000000000000000000000049999998889999994000000000000000
00000000000000000b00000000000000655555556000000000999000000000000000000000000000000000000000000049999999899999994000000000000000
00000000000000000000000000000000066666660000000000090000000000000000000000000000000000000000000049988999999988994000000000000000
00050000000500000000000008880000008880000000000000000000000000000000000000000000000000000000000049988999999988994000000000000000
00585000005850000000000088888000088888000000000000000000000000000000000000000000000000000000000004999944444999940000000000000000
05888500058885000000bbb088788000888888800000000000000000000000000000000000000000000000000000000000444400000444400000000000000000
58888850588888500000000088888000888788800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05888885888885000000000008880000888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00588888888850000000000000000000088888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00058888888500000000000000000000008880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005888885000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00058888888500000070000000000000000000000000000000000000000000000000888000000000000000000088800000000099999000000000000000000000
00588888888850000077000000000000000000000000000000000000000000000000888800000000000000000888800000009988a88990000000000000000000
05888885888885000077700000000000000000000000000000000000000000000000882880000000000000008828800000098a88888a89000000000000000000
588888505888885000777700000000000000000000000000000000000000000000008872888800000000088882788000009888a888a888900000000000000000
058885000588850000777000000000000000000000000000000000000000000000002877222888888888882227782000009888a888a888900000000000000000
00585000005850000077000000000000000000000000000000000000000000000000088770722222222222707788000000988899899888900000000000000000
000500000005000000700000000000000000000000000000000000000000000000000288707707770777077078820000099989a989a989990000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000880007077707770700088000009aaa9aaa9aaa9aaa9000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000288700000000000007882000009aaaaa9aaa9aaaaa9000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000028807707707707708820000009aa9aa99999aa9aa9000000000000000
00777770000000000000000000000000000000000000000000000000000000000000000028877077077077882000000009999900000999990000000000000000
077eee77007eee700000000000000000000000000000000000000000000000000000000002888888888888820000000000000000000000000000000000000000
077eee77077eee770000000000000000000000000000000000000000000000000000000000228888888882200000000000000000000000000000000000000000
077eee77077eee77077eee7707000007000000000000000000000000000000000000000000002222222220000000000000000000000000000000000000000000
00777770007777700077777000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000020000000000000000000000000000111111100000000000000000000000000000000000330000000
00000000000002222222000000000000000000000000000020000000000000000000000000111000000011100000000000000000000000000000003bb3000000
0000000000022777777722000000000000000000000000022200000000000000000000001100011111110001100000000000000000000000000003bbb3000000
000000000227777777777722000000000000000002000002220000020000000000000001001110000000111001000000000000000000000000003bbbb3000000
00000000277777777777777720000000000000000220002222200022000000000000001011000000000000011010000000000000000000000003bbbbb3300000
00000002777777777777777772000000000000000222002222200222000000000000010100000000000000000101000000000000000000000003bbbb3bb30000
000000277777777777777777772000000000200002222000000022220000200000000010000000000000000000100000000000000000000000003333bbb33330
000002777777777777777777777200000000220002200000000000220002200000000100000000000000000000010000000000000000000000000003bb3bbbb3
00000277777777777777777777720000000022200000000000000000002220000000000000000000000000000000000000000000000000000000000033bbbbb3
00000027777777777777777777200000000022220000000000000000022220000000000000000000000000000000000000000000000000000000000003bbbb30
00000002777777777777777772000000000022200000000000000000002220000000000000000000000000000000000000000000000000000000000003bbb300
00000000277777777777777720000000000002000000000000000000000200000000000000000000000000000000000000000000000000000000000003bb3000
00000000022777777777772200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000330000
00000000000227777777220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000002222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000009970000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000977000000000000000000000000000000000000000000000000000000000000000
00000000066666666600000066666666600000000000000000000000000000077770066000000000000000000000000000000000000000000000000000000000
00000000061111111600000061111111600000000000000000000009000000777777566600000000000000000000000000000000000000000000000000000000
00000000061111111600000061111111600000000000000000000009990000777777755660000000000000000000000000000000000000000000000000000000
00000000006111111160000611111116000000000000000000000000997700777777c77566000000000000000000000000000000000000000000000000000000
00000000006111111160000611111116000000000000000000000000077755777777ccc755600000000000000000000000000000000000000000000000000000
00000000006111111160000611111116000000000000000000000000066666555777777777560000000000000000000000000000000000000000000000000000
00000000006111111160000611111116000000000000000000000006666656666555557777756000000000000000000000000000000000000000000000000000
00000000000611111160000611111160000000000000000000000000555666666666665555575600000000000000000000000000000000000000000000000000
00000000000611111160000611111160000000000000000000000000055555555566666666655500000000000000000000000000000000000000000000000000
00000000000611111116006111111160000000006666600000000000005555555555555555666600000000000000000000000000000000000000000000000000
00000000000611111116006111111160000000006111600000000000000000000000555555555500000000000000000000000000000000000000000000000000
00000000000611111116006111111160066600006111600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000061111116006111111600611160006111600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000061111116006111111600611160006111600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000061111116006111111600611160006111600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000061111111661111111600066600006111600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000006111111661111116000000000006111600000000000000000000000000000000000000000000000000000000000000000066666600000000000
00000000000006111111661111116066666660066111666000666066666600000066666000000000666666600000666660000666660006611111166000000000
00000000000006111111111111116061111160061111116000611611111160006611111660000066111111166000611160000611160061111111111600000000
00000000000006111111111111116066611160061111116000611111111160061111111116000611111111111600611160000611160061111111111600000000
00000000000000611111111111160000611160061111116000611111111160061111111116000611111111111600611160000611160611116666611600000000
00000000000000611111111111160000611160066111666000611111666660611116661111606111166666111160611160000611160611160000066000000000
00000000000000611111111111160000611160006111600000611116000000611116661111606111677777611160611160000611160611116666600000000000
0000000000000061111111111116000061116000611160000061116000000061111111111160611677ccc7761160611160000611160061111111160000000000
0000000000000061111111111116000061116000611160000061116000000061111111111160611677ccc7761160611160000611160006111111116000000000
0000000000000006111111111160000061116000611160000061116000000061116666666600611677ccc7761160611160000611160000666661111600000000
00000000000000061111111111600000611160006111606660611160000000611160000000006111677777611160611160000611160066000006111600000000
00000000000000061111111111600000611160006111161160611160000000611116666660006111166666111160611116666111160611666661111600000000
00000000000000061111111111600066611166606111111160611160000000061111111116000611111111111600061111111111160611111111116000000000
00000000000000006111111116000061111111600611111160611160000000061111111116000611111111111600061111111111160611111111116000000000
00000000000000006111111116000061111111600061111600611160000000006611111166000066111111166000006611111161160066111111660000000000
00000000000000006666666666000066666666600006666000666660000000000066666600000000666666600000000066666606660000666666000000000000
__sfx__
000100003105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000024350223501f3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000293502c3502e3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002e35032350353503630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000337701b7702e7701777026770137701377016770187701c7702177023770217700f600116001160011600000000000000000000000000000000000000000000000000000000000000000000000000000
000100001f0502305026050290502b0502d0502d0502c0002c0003100033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001f0501f0501f0502705027050270503305033050330500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002a35023350283501f360263601c36022360173601c36013360183600f370133700b370103700937000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002655020550265501a5502555019550235501e200172000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000200500000028050000002e050320503405000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000085000850008500085000b5000b5000b5000b5000f5000f5000f5000f5000a5000a5000a5000a500095500a550125501455017550145500e5500b550085500e55010550165501955017550125500e550
011000001a0501c0501d0502105021040210302102221012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001a1501c1501d1501f15021150221502415024150241502415024140241302412024110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
0108000018050180401d0501d04021050210502405024050240502405021040210302405024050240502405024040240302402024010000000000000000000000000000000000000000000000000000000000000
