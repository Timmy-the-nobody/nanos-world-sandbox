-- Spawns/Overrides with default NanosWorld's Sun
Sky.Spawn(true)

-- Sets the same time for everyone
local gmt_time = os.date("!*t", os.time())
Sky.SetTimeOfDay(gmt_time.hour, gmt_time.min)

-- All notifications already sent
PERSISTENT_DATA_NOTIFICATIONS = PERSISTENT_DATA_NOTIFICATIONS or {}

-- Spawns Sandbox HUD
MainHUD = MainHUD or WebUI("Sandbox HUD", "file:///UI/index.html")

-- Requires the SpawnMenu
Package.Require("Notifications.lua")
Package.Require("ContextMenu.lua")
Package.Require("SpawnMenu.lua")
Package.Require("Scoreboard.lua")

-- Configures Keybindings Inputs
Input.Register("NoClip", "B")
Input.Register("Scoreboard", "Tab")
Input.Register("Ragdoll", "J")
Input.Register("SpawnMenu", "Q")
Input.Register("ContextMenu", "C")
Input.Register("Undo", "X")

-- Hit Taken Feedback Sound Cached
SoundHitTakenFeedback = Sound(Vector(), "nanos-world::A_HitTaken_Feedback", true, false, SoundType.SFX, 1, 1, 400, 3600, 0, false, 0, false)


-- When LocalPlayer spawns, sets an event on it to trigger when we possesses a new character, to store the local controlled character locally. This event is only called once, see Package.Subscribe("Load") to load it when reloading a package
Client.Subscribe("SpawnLocalPlayer", function(local_player)
	local_player:Subscribe("Possess", function(player, character)
		UpdateLocalCharacter(character)
	end)
end)

-- When package loads, verify if LocalPlayer already exists (eg. when reloading the package), then try to get and store it's controlled character
Package.Subscribe("Load", function()
	Input.SetMouseEnabled(false)
	Input.SetInputEnabled(true)

	local local_player = Client.GetLocalPlayer()

	if (local_player ~= nil) then
		UpdateLocalCharacter(local_player:GetControlledCharacter())

		local_player:Subscribe("Possess", function(player, character)
			UpdateLocalCharacter(character)
		end)
	end

	-- Gets all notifications already sent
	PERSISTENT_DATA_NOTIFICATIONS = Package.GetPersistentData().notifications or {}
end)

-- Function to set all needed events on local character (to update the UI when it takes damage or dies)
---@param character Character
function UpdateLocalCharacter(character)
	-- Verifies if character is not nil (eg. when GetControllerCharacter() doesn't return a character)
	if (character == nil) then return end

	-- Updates the UI with the current character's health
	UpdateHealth(character:GetHealth())

	-- Sets on character an event to update the health's UI after it takes damage
	character:Subscribe("HealthChange", function(charac, old_health, new_health)
		-- Plays a Hit Taken sound effect if took damage
		if (new_health < old_health) then
			SoundHitTakenFeedback:Play()
		end

		-- Immediatelly Updates the Health UI
		UpdateHealth(new_health)
	end)

	-- Try to get if the character is holding any weapon
	local current_picked_item = character:GetPicked()

	-- If so, update the UI
	if (current_picked_item and current_picked_item:IsA(Weapon) and not current_picked_item:IsA(ToolGun)) then
		UpdateAmmo(true, current_picked_item:GetAmmoClip(), current_picked_item:GetAmmoBag())
	end

	-- Sets on character an event to update his grabbing weapon (to show ammo on UI)
	character:Subscribe("PickUp", function(charac, object)
		if (object:IsA(Weapon) and not object:IsA(ToolGun)) then
			-- Immediatelly Updates the Ammo UI
			UpdateAmmo(true, object:GetAmmoClip(), object:GetAmmoBag())

			-- Trigger Weapon Hints
			AddNotification("AIM_DOWN_SIGHT", "you can use mouse wheel to aim down sight with your Weapon when you are in First Person Mode", 10000, 3000)
			AddNotification("HEADSHOTS", "headshots can cause more damage", 10000, 15000)

			-- Subscribes on the weapon when the Ammo changes
			object:Subscribe("AmmoClipChange", OnAmmoClipChanged)
			object:Subscribe("AmmoBagChange", OnAmmoBagChanged)
		end
	end)

	-- Sets on character an event to remove the ammo ui when he drops it's weapon
	character:Subscribe("Drop", function(charac, object)
		-- Unsubscribes from events
		if (object:IsA(Weapon) and not object:IsA(ToolGun)) then
			UpdateAmmo(false)
			object:Unsubscribe("AmmoClipChange", OnAmmoClipChanged)
			object:Unsubscribe("AmmoBagChange", OnAmmoBagChanged)
		end
	end)
end

-- Function to update the Ammo's UI
function UpdateAmmo(enable_ui, ammo, ammo_bag)
	MainHUD:CallEvent("UpdateWeaponAmmo", enable_ui, ammo, ammo_bag)
end

-- Function to update the Health's UI
function UpdateHealth(health)
	MainHUD:CallEvent("UpdateHealth", health)
end

-- Callback when Weapon Ammo Clip changes
function OnAmmoClipChanged(weapon, old_ammo_clip, new_ammo_clip)
	UpdateAmmo(true, new_ammo_clip, weapon:GetAmmoBag())
end

-- Callback when Weapon Ammo Bag changes
function OnAmmoBagChanged(weapon, old_ammo_bag, new_ammo_bag)
	UpdateAmmo(true, weapon:GetAmmoClip(), new_ammo_bag)
end

Input.Bind("NoClip", InputEvent.Pressed, function()
	Events.CallRemote("ToggleNoClip")
end)

Input.Bind("Ragdoll", InputEvent.Pressed, function()
	Events.CallRemote("EnterRagdoll")
end)

-- VOIP UI
Player.Subscribe("VOIP", function(player, is_talking)
	MainHUD:CallEvent("ToggleVoice", player:GetName(), is_talking)
end)

Player.Subscribe("Destroy", function(player)
	MainHUD:CallEvent("ToggleVoice", player:GetName(), false)
	MainHUD:CallEvent("UpdatePlayer", player:GetID(), false)
end)

Events.SubscribeRemote("SpawnSound", function(location, sound_asset, is_2D, volume, pitch)
	Sound(location, sound_asset, is_2D, true, SoundType.SFX, volume or 1, pitch or 1)
end)

Events.SubscribeRemote("SpawnSoundAttached", function(object, sound_asset, is_2D, auto_destroy, volume, pitch)
	local sound = Sound(object:GetLocation(), sound_asset, is_2D, auto_destroy ~= false, SoundType.SFX, volume or 1, pitch or 1)
	sound:AttachTo(object, AttachmentRule.SnapToTarget, "", 0)
end)

-- Exposes this to other packages
Package.Export("UpdateLocalCharacter", UpdateLocalCharacter)
