-- Function to setup the Prop to be able to Break (usually called by SpawnMenu)
function SetupBreakableProp(prop)
	-- Checks if this Prop can be breakable (a.k.a. was configured previously with SetBreakableProp)
	local breakable_data = BreakableProps[prop:GetAssetName()]

	if (not breakable_data) then
		return
	end

	if (breakable_data.explosive and breakable_data.explosive.inflamable) then
		-- Subscribes when it hits
		prop:Subscribe("Hit", function(breakable, intensity, normal_impulse, impact_location, velocity)
			BreakProp(breakable, intensity, velocity)
		end)

		-- Subscribes when it takes damage
		prop:Subscribe("TakeDamage", function(self, damage, bone_name, damage_type, hit_from_direction, instigator, causer)
			-- First ignites, then explodes
			InflameProp(self)
		end)
	else
		-- Subscribes when it hits
		prop:Subscribe("Hit", function(breakable, intensity, normal_impulse, impact_location, velocity)
			BreakProp(breakable, intensity, velocity)
		end)

		-- Subscribes when it takes damage
		prop:Subscribe("TakeDamage", function(breakable, damage, bone_name, damage_type, hit_from_direction, instigator, causer)
			BreakProp(breakable, damage * 50, Vector())
		end)
	end
end

-- This will trigger "Inflame" in a Inflamable Prop - I.e. make it fire for some seconds then explode
function InflameProp(prop)
	local breakable_data = BreakableProps[prop:GetAssetName()]

	if (not breakable_data) then
		Package.Warn("Failed to find Breakable data for Prop '" .. prop:GetAssetName() .."'. Maybe missed configuration?")
		return
	end

	if (prop:GetValue("IsLeaking")) then
		local location = prop:GetLocation()
		prop:Destroy()

		ExplodeProp(location, breakable_data.explosive)
		return
	end

	prop:SetValue("IsLeaking", true)
	prop:SetForce(Vector(0, 0, breakable_data.explosive.inflamable.force or -100000), true)

	Events.BroadcastRemote("SpawnSoundAttached", prop, "nanos-world::A_WhiteNoise", false, false, 0.05, 0.05)

	local particle = Particle(prop:GetLocation(), Rotator(), "nanos-world::P_LeadersRing", false, true)
	particle:AttachTo(prop, AttachmentRule.SnapToTarget, "", 0.05)
	particle:SetRelativeLocation(breakable_data.explosive.inflamable.relative_particle or Vector())
	particle:SetRelativeRotation(Rotator(90, 0, 0))
	particle:SetScale(Vector(0.25))

	Timer.Bind(Timer.SetTimeout(function(explosible)
		local location = explosible:GetLocation()
		explosible:Destroy()

		ExplodeProp(location, breakable_data.explosive)
	end, (breakable_data.explosive.inflamable.duration or 5000) * math.random(75, 125) / 100, prop), prop)
end

-- This will "Break" a breakable prop into several Debris
function BreakProp(prop, intensity, velocity)
	local breakable_data = BreakableProps[prop:GetAssetName()]

	if (not breakable_data) then
		Package.Warn("Failed to find Breakable data for Prop '" .. prop:GetAssetName() .."'. Maybe missed configuration?")
		return
	end

	-- Checks if intensity is enough to break
	if (intensity < (breakable_data.weakness or 500)) then
		return
	end

	-- Stores object data
	local parent_location = prop:GetLocation() + velocity / 30
	local parent_rotation = prop:GetRotation()
	local parent_scale = prop:GetScale()
	local override_lifespan = prop:GetValue("DebrisLifeSpan")

	-- Destroy main prop
	prop:Destroy()

	for debris_i in pairs(breakable_data.debris) do
		local debris_data = breakable_data.debris[debris_i]

		-- Check if has chance to spawn, 0 means no chance, 1 means 100% chance of spawning
		if (debris_data.randomness and debris_data.randomness < math.random()) then
			return
		end

		-- Spawns the Debris
		local debris = Prop(
			parent_location + ((debris_data.offset and parent_rotation:UnrotateVector(debris_data.offset)) or Vector()),
			parent_rotation + (debris_data.rotation or Rotator.Random()),
			debris_data.mesh,
			CollisionType.StaticOnly,
			true,
			false,
			true
		)

		-- Copy parent scale
		debris:SetScale(parent_scale)

		-- Copy parent velocity, adds a small randomness to make it better
		debris:AddImpulse(velocity * 0.5 + Vector(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)), true)

		-- Setup lifespan
		debris:SetLifeSpan(override_lifespan or debris_data.lifespan or 10)
	end

	if (breakable_data.explosive) then
		ExplodeProp(parent_location, breakable_data.explosive)
	end
end

-- This will "explode" a Explodable Prop
function ExplodeProp(location, explosive_data)
	-- Spawns a Grenade to explode it immediately
	local grenade = Grenade(location, Rotator(), "nanos-world::SM_None", "nanos-world::P_Grenade_Special", "nanos-world::A_Explosion_Large", CollisionType.StaticOnly, false)

	-- Configures the Damge
	grenade:SetDamage(
		explosive_data.base_damage or 50,
		explosive_data.minimum_damage or 0,
		explosive_data.damage_inner_radius or 200,
		explosive_data.damage_outer_radius or 1000,
		explosive_data.damage_falloff or 1
	)

	-- Explodes it!
	grenade:Explode()
end

-- General function to configure Breakable Props
function SetBreakableProp(prop, weakness, debris, explosive)
	BreakableProps[prop] = { weakness = weakness or 500, debris = debris, explosive = explosive }
end

Package.Export("SetBreakableProp", SetBreakableProp)

-- Global table of Breakable Props, format:
BreakableProps = {}
-- {
--		["ASSET_NAME"] = {
--			weakness,
--			debris = {
--				{ mesh, rotation, offset, lifespan, randomness }
--				...
--			},
--			explosive = {
--				base_damage,
-- 				minimum_damage,
-- 				damage_inner_radius,
-- 				damage_outer_radius,
-- 				damage_falloff,
--				inflamable = { duration, force, relative_particle }
--			}
--		}
-- }

-- SM_Fruit_Watermelon_01
SetBreakableProp("nanos-world::SM_Fruit_Watermelon_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Watermelon_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Watermelon_01_Half_01", rotation = Rotator(180, 0, 0) },
	{ mesh = "nanos-world::SM_Fruit_Watermelon_01_Crust_01" },
	{ mesh = "nanos-world::SM_Fruit_Watermelon_01_Slice_01" },
	{ mesh = "nanos-world::SM_Fruit_Watermelon_01_Slice_01" },
})

-- SM_Fruit_Cantaloupe_01
SetBreakableProp("nanos-world::SM_Fruit_Cantaloupe_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Cantaloupe_01_Half_01" },
	{ mesh = "nanos-world::SM_Fruit_Cantaloupe_01_Slice_01" },
	{ mesh = "nanos-world::SM_Fruit_Cantaloupe_01_Slice_01" },
	{ mesh = "nanos-world::SM_Fruit_Cantaloupe_01_Slice_01" },
	{ mesh = "nanos-world::SM_Fruit_Cantaloupe_01_Slice_01" },
	{ mesh = "nanos-world::SM_Fruit_Cantaloupe_01_Slice_01" },
})

-- SM_Fruit_Plum_01
SetBreakableProp("nanos-world::SM_Fruit_Plum_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Plum_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Plum_01_Half_02", rotation = Rotator() }
})

-- SM_Fruit_Mango_01
SetBreakableProp("nanos-world::SM_Fruit_Mango_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Mango_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Mango_01_Half_01", rotation = Rotator(180, 0, 0) },
})

-- SM_Fruit_Lemon_01
SetBreakableProp("nanos-world::SM_Fruit_Lemon_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Lemon_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Lemon_01_Half_01", rotation = Rotator(180, 0, 0) }
})

-- SM_Fruit_Squash_01
SetBreakableProp("nanos-world::SM_Fruit_Squash_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Squash_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Squash_01_Half_01", rotation = Rotator(0, 180, 0) }
})

-- SM_Veg_Onion_Red_01
SetBreakableProp("nanos-world::SM_Veg_Onion_Red_01", 700, {
	{ mesh = "nanos-world::SM_Veg_Onion_Red_01_Cut", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Veg_Onion_Red_01_Cut", rotation = Rotator(180, 0, 0) }
})

-- SM_Veg_Artichoke_01
SetBreakableProp("nanos-world::SM_Veg_Artichoke_01", 700, {
	{ mesh = "nanos-world::SM_Veg_Artichoke_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Veg_Artichoke_01_Half_01", rotation = Rotator(0, 180, 0) }
})

-- SM_Fruit_Lime_01
SetBreakableProp("nanos-world::SM_Fruit_Lime_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Lime_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Lime_01_Half_01", rotation = Rotator(180, 0, 0) }
})

-- SM_Fruit_Orange_01
SetBreakableProp("nanos-world::SM_Fruit_Orange_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Orange_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Orange_01_Wedge_01", rotation = Rotator() }
})

-- SM_Fruit_Apple_01
SetBreakableProp("nanos-world::SM_Fruit_Apple_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Apple_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Apple_01_Quarter_01", rotation = Rotator() }
})

-- SM_Fruit_Tomato_01
SetBreakableProp("nanos-world::SM_Fruit_Tomato_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Tomato_01_SliceBottom", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Tomato_01_SliceTop", rotation = Rotator() }
})

-- SM_Fruit_Mandarin_01
SetBreakableProp("nanos-world::SM_Fruit_Mandarin_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Mandarin_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Mandarin_01_Wedge_01", rotation = Rotator() }
})

-- SM_Fruit_Apple_Red_01
SetBreakableProp("nanos-world::SM_Fruit_Apple_Red_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Apple_Red_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Apple_Red_01_Quarter_01", rotation = Rotator() }
})

-- SM_Fruit_Apple_Green_01
SetBreakableProp("nanos-world::SM_Fruit_Apple_Green_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Apple_Green_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Apple_Green_01_Quarter_01", rotation = Rotator() }
})

-- SM_Fruit_Avocado_01
SetBreakableProp("nanos-world::SM_Fruit_Avocado_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Avocado_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Avocado_01_Half_02", rotation = Rotator() }
})

-- SM_Fruit_Peach_01
SetBreakableProp("nanos-world::SM_Fruit_Peach_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Peach_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Peach_01_Half_02", rotation = Rotator() }
})

-- SM_Bread_Pizza_01
SetBreakableProp("nanos-world::SM_Bread_Pizza_01", 700, {
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Slice_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Slice_02", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Slice_03", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Slice_04", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Slice_05", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Slice_06", rotation = Rotator() },
})

-- SM_Fruit_Pear_01
SetBreakableProp("nanos-world::SM_Fruit_Pear_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Pear_01_Half_01", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Pear_01_Half_01", rotation = Rotator(180, 0, 0) },
})

-- SM_Fruit_Tomato_01
SetBreakableProp("nanos-world::SM_Fruit_Tomato_01", 700, {
	{ mesh = "nanos-world::SM_Fruit_Tomato_01_SliceBottom", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Fruit_Tomato_01_SliceTop", rotation = Rotator() },
})

-- SM_Bread_Loaf_Multi_01
SetBreakableProp("nanos-world::SM_Bread_Loaf_Multi_01", 700, {
	{ mesh = "nanos-world::SM_Bread_Loaf_Multi_01_Slice_01", rotation = Rotator(), offset = Vector(9, 0, 0) },
	{ mesh = "nanos-world::SM_Bread_Loaf_Multi_01_SliceEnd", rotation = Rotator(), offset = Vector(12, 0, 0) },
	{ mesh = "nanos-world::SM_Bread_Loaf_Multi_01_SliceLoaf", rotation = Rotator(), offset = Vector(-3, 0, 0) },
})

-- SM_Onion_Red_01
SetBreakableProp("nanos-world::SM_Onion_Red_01", 700, {
	{ mesh = "nanos-world::SM_Onion_Red_01_Cut", rotation = Rotator() },
	{ mesh = "nanos-world::SM_Onion_Red_01_Cut", rotation = Rotator(180, 0, 0) },
})

-- SM_ConcreteBag_Stack_01
SetBreakableProp("nanos-world::SM_ConcreteBag_Stack_01", 700, {
	{ mesh = "nanos-world::SM_ConcreteBag", rotation = Rotator() },
	{ mesh = "nanos-world::SM_ConcreteBag", rotation = Rotator() },
	{ mesh = "nanos-world::SM_ConcreteBag", rotation = Rotator() },
	{ mesh = "nanos-world::SM_ConcreteBag", rotation = Rotator() },
})

-- SM_Trash_01
SetBreakableProp("nanos-world::SM_Trash_01", 600, {
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Crust_01" },
	{ mesh = "nanos-world::SM_Bread_Pizza_01_Slice_01" },
	{ mesh = "nanos-world::SM_Bread_Muffin_01" },
})

-- Explosives (last parameter as table enables it explosive)
SetBreakableProp("nanos-world::SM_PropaneTank_01", 700, {}, {
	inflamable = {
		duration = 5000,
		force = -15000,
		relative_particle = Vector(0, 0, 40)
	}
})

SetBreakableProp("nanos-world::SM_PropaneTank_02", 700, {}, {
	inflamable = {
		duration = 5000,
		force = -15000,
		relative_particle = Vector(0, 0, 40)
	}
})

SetBreakableProp("nanos-world::SM_TallGasCanister_01", 700, {}, {
	damage_outer_radius = 1500,
	inflamable = {
		duration = 5000,
		force = -115000,
		relative_particle = Vector(0, 0, 160)
	}
})
