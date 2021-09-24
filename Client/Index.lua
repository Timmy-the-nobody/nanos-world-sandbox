-- Spawns/Overrides with default NanosWorld's Sun
World.SpawnDefaultSun()

-- Sets the same time for everyone
local gmt_time = os.date("!*t", os.time())
World.SetTime((gmt_time.hour * 60 + gmt_time.min) % 24, gmt_time.sec)

-- All notifications already sent
PERSISTENT_DATA_NOTIFICATIONS = {}

-- Spawns Sandbox HUD
main_hud = WebUI("Sandbox HUD", "file:///UI/index.html")

-- Requires the SpawnMenu
Package.Require("Notifications.lua")
Package.Require("SpawnMenu.lua")
Package.Require("Scoreboard.lua")

-- When LocalPlayer spawns, sets an event on it to trigger when we possesses a new character, to store the local controlled character locally. This event is only called once, see Package.Subscribe("Load") to load it when reloading a package
Client.Subscribe("SpawnLocalPlayer", function(local_player)
	local_player:Subscribe("Possess", function(player, character)
		UpdateLocalCharacter(character)
	end)
end)

-- When package loads, verify if LocalPlayer already exists (eg. when reloading the package), then try to get and store it's controlled character
Package.Subscribe("Load", function()
	local local_player = Client.GetLocalPlayer()

	if (local_player ~= nil) then
		UpdateLocalCharacter(local_player:GetControlledCharacter())

		local_player:Subscribe("Possess", function(player, character)
			UpdateLocalCharacter(character)
		end)
	end

	-- Gets all notifications already sent
	PERSISTENT_DATA_NOTIFICATIONS = Package.GetPersistentData().notifications or {}

	-- Updates all existing Players
	for k, player in pairs(Player.GetAll()) do
		UpdatePlayerScoreboard(player)
	end
end)

-- Function to set all needed events on local character (to update the UI when it takes damage or dies)
function UpdateLocalCharacter(character)
	-- Verifies if character is not nil (eg. when GetControllerCharacter() doesn't return a character)
	if (character == nil) then return end

	-- Updates the UI with the current character's health
	UpdateHealth(character:GetHealth())

	-- Sets on character an event to update the health's UI after it takes damage
	character:Subscribe("TakeDamage", function(charac, damage, type, bone, from_direction, instigator, causer)
		-- Plays a Hit Taken sound effect
		Sound(Vector(), "nanos-world::A_HitTaken_Feedback", true)

		-- Updates the Health UI
		UpdateHealth(math.max(charac:GetHealth() - damage, 0))
	end)

	-- Sets on character an event to update the health's UI after it dies
	character:Subscribe("Death", function(charac)
		UpdateHealth(0)
	end)

	-- Sets on character an event to update the health's UI after it respawns
	character:Subscribe("Respawn", function(charac)
		UpdateHealth(100)
	end)

	-- Try to get if the character is holding any weapon
	local current_picked_item = character:GetPicked()

	-- If so, update the UI
	if (current_picked_item and current_picked_item:GetType() == "Weapon" and not current_picked_item:GetValue("ToolGun")) then
		UpdateAmmo(true, current_picked_item:GetAmmoClip(), current_picked_item:GetAmmoBag())
	end

	-- Sets on character an event to update his grabbing weapon (to show ammo on UI)
	character:Subscribe("PickUp", function(charac, object)
		if (object:GetType() == "Weapon" and not object:GetValue("ToolGun")) then
			UpdateAmmo(true, object:GetAmmoClip(), object:GetAmmoBag())

			-- Trigger Weapon Hints
			SetNotification("AIM_DOWN_SIGHT", 3000, "you can use mouse wheel to aim down sight with your Weapon when you are in First Person Mode", 5000)
			SetNotification("HEADSHOTS", 15000, "headshots can cause more damage", 5000)

			-- Sets on character an event to update the UI when he fires
			character:Subscribe("Fire", function(charac, weapon)
				UpdateAmmo(true, weapon:GetAmmoClip(), weapon:GetAmmoBag())
			end)

			-- Sets on character an event to update the UI when he reloads the weapon
			character:Subscribe("Reload", function(charac, weapon, ammo_to_reload)
				UpdateAmmo(true, weapon:GetAmmoClip(), weapon:GetAmmoBag())
			end)
		end
	end)

	-- Sets on character an event to remove the ammo ui when he drops it's weapon
	character:Subscribe("Drop", function(charac, object)
		UpdateAmmo(false)
		character:Unsubscribe("Fire")
		character:Unsubscribe("Reload")
	end)
end

-- Function to update the Ammo's UI
function UpdateAmmo(enable_ui, ammo, ammo_bag)
	main_hud:CallEvent("UpdateWeaponAmmo", enable_ui, ammo, ammo_bag)
end

-- Function to update the Health's UI
function UpdateHealth(health)
	main_hud:CallEvent("UpdateHealth", health)
end

Client.Subscribe("KeyPress", function(key_name)
	if (key_name == "B") then
		Events.CallRemote("ToggleNoClip")
		return
	end
end)

-- VOIP UI
Player.Subscribe("VOIP", function(player, is_talking)
	main_hud:CallEvent("ToggleVoice", player:GetName(), is_talking)
end)

Player.Subscribe("Destroy", function(player)
	main_hud:CallEvent("ToggleVoice", player:GetName(), false)
	main_hud:CallEvent("UpdatePlayer", player:GetID(), false)
end)

Events.Subscribe("SpawnSound", function(location, sound_asset, is_2D, volume, pitch)
	Sound(location, sound_asset, is_2D, true, SoundType.SFX, volume or 1, pitch or 1)
end)

Events.Subscribe("SpawnSoundAttached", function(object, sound_asset, is_2D, auto_destroy, volume, pitch)
	local sound = Sound(object:GetLocation(), sound_asset, is_2D, auto_destroy ~= false, SoundType.SFX, volume or 1, pitch or 1)
	sound:AttachTo(object, AttachmentRule.SnapToTarget, "", 0)
end)

-- Exposes this to other packages
Package.Export("UpdateLocalCharacter", UpdateLocalCharacter)
