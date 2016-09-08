--functions

--from lib_mount by blert2112 (WTFPL)

local function force_detach(player)
	local attached_to = player:get_attach()
	if attached_to and attached_to:get_luaentity() then
		local entity = attached_to:get_luaentity()
		if entity.driver then
			if entity ~= nil then entity.driver = nil end
		end
		player:set_detach()
	end
	default.player_attached[player:get_player_name()] = false
	player:set_eye_offset({x=0, y=0, z=0}, {x=0, y=0, z=0})
end

function object_attach(entity, player, attach_at, eye_offset)
	eye_offset = eye_offset or {x=0, y=0, z=0}
	force_detach(player)
	entity.driver = player
	entity.loaded = true
	entity.nitro = true
	player:set_attach(entity.object, "", attach_at, {x=0, y=0, z=0})
	
	player:set_properties({visual_size = {x=1, y=1}})
	
	player:set_eye_offset(eye_offset, {x=0, y=2, z=-40})
	default.player_attached[player:get_player_name()] = true
	minetest.after(0.2, function()
		default.player_set_animation(player, "sit" , 30)
	end)
	entity.object:setyaw(player:get_look_yaw() - math.pi / 2)
end

function object_detach(entity, player, offset)
	entity.driver = nil
	entity.object:setvelocity({x=0, y=0, z=0})
	player:set_detach()
	default.player_attached[player:get_player_name()] = false
	default.player_set_animation(player, "stand" , 30)
	player:set_eye_offset({x=0, y=0, z=0}, {x=0, y=0, z=0})
	local pos = player:getpos()
	pos = {x = pos.x + offset.x, y = pos.y + 0.2 + offset.y, z = pos.z + offset.z}
	minetest.after(0.1, function()
		player:setpos(pos)
	end)
end
-------------------------------------------------------------------------------


minetest.register_on_leaveplayer(function(player)
	force_detach(player)
end)

minetest.register_on_shutdown(function()
    local players = minetest.get_connected_players()
	for i = 1,#players do
		force_detach(players[i])
	end
end)

minetest.register_on_dieplayer(function(player)
	force_detach(player)
	return true
end)

--New code

function register_simplenode(name, desc, texture, light)
minetest.register_node("mt_speed:"..name, {
	description = desc,
	tiles = {texture},
	groups = {cracky=1},
	paramtype2 = "facedir",
	light_source = light,
})
end

function object_drive_simple(entity, dtime, speed, decell, nitro_duration)
	local ctrl = entity.driver:get_player_control()
	local velo = entity.object:getvelocity()
	local nitro_remaining = entity.nitro
	local dir = entity.driver:get_look_dir();
	local vec_forward = {x=dir.x*speed,y=velo.y-0.5,z=dir.z*speed}
	local vec_nitro = {x=dir.x*(speed*1.5),y=velo.y-0.5,z=dir.z*(speed*1.5)}
	local vec_backward = {x=-dir.x*speed,y=velo.y-0.5,z=-dir.z*speed}
	local vec_stop = {x=velo.x*decell,y=velo.y-1,z=velo.z*decell}
	local yaw = entity.driver:get_look_yaw();
	entity.object:setyaw(yaw+math.pi+math.pi/2)
	if not entity.nitro then
		minetest.after(4, function()
		entity.nitro = true
		end)
	end
	if ctrl.up and ctrl.sneak and entity.nitro then
		entity.object:setvelocity(vec_nitro)
		local pos = entity.object:getpos()
			minetest.add_particlespawner(
			15, --amount
			1, --time
			{x=pos.x-0.5, y=pos.y, z=pos.z-0.5}, --minpos
			{x=pos.x+0.5, y=pos.y, z=pos.z+0.5}, --maxpos
			{x=0, y=0, z=0}, --minvel
			{x=-velo.x, y=-velo.y, z=-velo.z}, --maxvel
			{x=-0,y=-0,z=-0}, --minacc
			{x=0,y=0,z=0}, --maxacc
			0.1, --minexptime
			0.2, --maxexptime
			10, --minsize
			15, --maxsize
			false, --collisiondetection
			"mt_speed_nitro.png" --texture
			)
			minetest.after(nitro_duration, function()
			entity.nitro = false
			end)
	elseif ctrl.up then
		entity.object:setvelocity(vec_forward)
	elseif ctrl.down then
		entity.object:setvelocity(vec_backward)
	elseif not ctrl.down or ctrl.up then
		entity.object:setvelocity(vec_stop)
end
end


function register_vehicle_spawner(vehicle, desc, texture)
minetest.register_tool(vehicle.."_spawner", {
	description = desc,
	inventory_image = texture,
	wield_scale = {x = 1.5, y = 1.5, z = 1},
	tool_capabilities = {
		full_punch_interval = 0.7,
		max_drop_level=1,
		groupcaps={
			snappy={times={[1]=2.0, [2]=1.00, [3]=0.35}, uses=30, maxlevel=3},
		},
		damage_groups = {fleshy=1},
	},
	on_use = function(item, placer, pointed_thing)
			local dir = placer:get_look_dir();
			local playerpos = placer:getpos();
			if pointed_thing.type == "node" then
			local obj = minetest.env:add_entity(pointed_thing.above, vehicle)
			item:take_item()
			return item
			end
	end,
})
end

--cars

minetest.register_entity("mt_speed:musting", {
	visual = "mesh",
	mesh = "musting.b3d",
	textures = {"mt_speed_musting.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 15, 0.95, 4)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:musting", "Musting (purple)", "mt_speed_musting_inv2.png")

minetest.register_entity("mt_speed:musting2", {
	visual = "mesh",
	mesh = "musting.b3d",
	textures = {"mt_speed_musting2.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 15, 0.85, 4)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:musting2", "Musting (white)", "mt_speed_musting_inv.png")

minetest.register_entity("mt_speed:lambogoni", {
	visual = "mesh",
	mesh = "lambogoni.b3d",
	textures = {"mt_speed_lambogoni.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 15, 0.8, 4)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:lambogoni", "Lambogoni (grey)", "mt_speed_lambogoni_inv.png")

minetest.register_entity("mt_speed:nizzan", {
	visual = "mesh",
	mesh = "nizzan.b3d",
	textures = {"mt_speed_nizzan.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 14, 0.8, 5)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:nizzan", "Nizzan (brown)", "mt_speed_nizzan_inv.png")

minetest.register_entity("mt_speed:nizzan2", {
	visual = "mesh",
	mesh = "nizzan.b3d",
	textures = {"mt_speed_nizzan2.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 14, 0.8, 5)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:nizzan2", "Nizzan (green)", "mt_speed_nizzan_inv2.png")


minetest.register_entity("mt_speed:masda", {
	visual = "mesh",
	mesh = "masda.b3d",
	textures = {"mt_speed_masda.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 15, 0.95, 4)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:masda", "Masda (pink)", "mt_speed_masda_inv.png")

minetest.register_entity("mt_speed:pooshe", {
	visual = "mesh",
	mesh = "pooshe.b3d",
	textures = {"mt_speed_pooshe.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 15, 0.95, 4)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:pooshe", "Pooshe (red)", "mt_speed_pooshe_inv.png")

minetest.register_entity("mt_speed:pooshe2", {
	visual = "mesh",
	mesh = "pooshe.b3d",
	textures = {"mt_speed_pooshe2.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 15, 0.95, 4)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:pooshe2", "Pooshe (yellow)", "mt_speed_pooshe_inv.png")

minetest.register_entity("mt_speed:masda2", {
	visual = "mesh",
	mesh = "masda.b3d",
	textures = {"mt_speed_masda2.png"},
	velocity = 15,
	acceleration = -5,
	stepheight = 1,
	hp_max = 200,
	physical = true,
	collisionbox = {-1, 0, -1, 1.3, 1, 1},
	on_rightclick = function(self, clicker)
		if self.driver and clicker == self.driver then
		object_detach(self, clicker, {x=1, y=0, z=1})
		elseif not self.driver then
		object_attach(self, clicker, {x=0, y=5, z=4}, {x=0, y=2, z=4}, {x=0, y=3, z=-72})
		end
	end,
	on_step = function(self, dtime)
	if self.driver then
		object_drive_simple(self, dtime, 15, 0.95, 4)
		return false
		end
		return true
	end,
})

register_vehicle_spawner("mt_speed:masda2", "Masda (orange)", "mt_speed_masda_inv2.png")



register_simplenode("road", "Road surface", "mt_speed_road.png", 0)
register_simplenode("concrete", "Concrete", "mt_speed_concrete.png", 0)
register_simplenode("arrows", "Turning Arrows(left)", "mt_speed_arrows.png", 10)
register_simplenode("arrows_flp", "Turning Arrows(right)", "mt_speed_arrows_flp.png", 10)
register_simplenode("checker", "Checkered surface", "mt_speed_checker.png", 0)
register_simplenode("stripe", "Road surface (stripe)", "mt_speed_road_stripe.png", 0)
register_simplenode("stripe2", "Road surface (double stripe)", "mt_speed_road_stripe2.png", 0)
register_simplenode("stripe3", "Road surface (white stripes)", "mt_speed_road_stripes3.png", 0)
register_simplenode("stripe4", "Road surface (yellow stripes)", "mt_speed_road_stripe4.png", 0)
register_simplenode("window", "Building glass", "mt_speed_window.png", 0)
register_simplenode("stripes", "Hazard stipes", "mt_speed_stripes.png", 10)
register_simplenode("lights", "Tunnel lights", "mt_speed_lights.png", 20)

minetest.register_node("mt_speed:neon_arrow", {
	description = "neon arrows (left)",
	drawtype = "signlike",
	visual_scale = 2.0,
	tiles = {"mt_speed_neon_arrow.png"},
	inventory_image = "mt_speed_neon_arrow.png",
	use_texture_alpha = true,
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,	
	light_source = 50,
	walkable = false,
	is_ground_content = true,
	selection_box = {
		type = "wallmounted",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.4, 0.5}
	},
	groups = {cracky=3,dig_immediate=3},
})

minetest.register_node("mt_speed:neon_arrow_flp", {
	description = "neon arrows (right)",
	drawtype = "signlike",
	visual_scale = 2.0,
	tiles = {"mt_speed_neon_arrow_flp.png"},
	inventory_image = "mt_speed_neon_arrow_flp.png",
	use_texture_alpha = true,
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,	
	light_source = 50,
	walkable = false,
	is_ground_content = true,
	selection_box = {
		type = "wallmounted",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.4, 0.5}
	},
	groups = {cracky=3,dig_immediate=3},
})

minetest.register_node("mt_speed:add_arrow", {
	description = "arrows(left)",
	drawtype = "signlike",
	visual_scale = 2.0,
	tiles = {"mt_speed_arrows.png"},
	inventory_image = "mt_speed_arrows.png",
	use_texture_alpha = true,
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,	
	light_source = 50,
	walkable = false,
	is_ground_content = true,
	selection_box = {
		type = "wallmounted",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.4, 0.5}
	},
	groups = {cracky=3,dig_immediate=3},
})

minetest.register_node("mt_speed:add_arrow_flp", {
	description = "arrows(right)",
	drawtype = "signlike",
	visual_scale = 2.0,
	tiles = {"mt_speed_arrows_flp.png"},
	inventory_image = "mt_speed_arrows_flp.png",
	use_texture_alpha = true,
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,	
	light_source = 50,
	walkable = false,
	is_ground_content = true,
	selection_box = {
		type = "wallmounted",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.4, 0.5}
	},
	groups = {cracky=3,dig_immediate=3},
})

--mapgen stuff