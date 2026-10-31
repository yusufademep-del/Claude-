-- Pump & Fly – Server: Spiellogik, Speichern, Bestenliste
-- Der Server entscheidet alles (Luft, Höhe, Münzen) → Exploiter können nicht schummeln.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local World = require(script.Parent:WaitForChild("World"))

local world = World.Build(Config)
local fmt = Config.Format

---------------------------------------------------------------- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local R = {}
for _, name in ipairs({ "Pump", "Launch", "Buy", "Rebirth", "Redeem", "ClaimGift", "RequestState", "State", "Flight", "FlightEnd", "Notify" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	R[name] = r
end
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- Daten
local dataStore, boardStore
pcall(function()
	dataStore = DataStoreService:GetDataStore(Config.DataStoreName)
	boardStore = DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_BestHeight")
end)

local sessions = {} -- [player] = Session

local function defaultData()
	return { Coins = 0, Balloon = 1, Pump = 1, Rebirths = 0, BestHeight = 0, Launches = 0, Codes = {}, LastGift = 0 }
end

local function loadData(player)
	if not dataStore then
		return defaultData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return dataStore:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			local data = type(result) == "table" and result or defaultData()
			for k, v in pairs(defaultData()) do
				if data[k] == nil then
					data[k] = v
				end
			end
			data.Balloon = math.clamp(data.Balloon, 1, #Config.Balloons)
			data.Pump = math.clamp(data.Pump, 1, #Config.Pumps)
			return data, true
		end
		task.wait(attempt)
	end
	return defaultData(), false
end

local function saveData(player, s)
	if not s or not s.canSave or not dataStore then
		return
	end
	local snapshot = table.clone(s.data)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:SetAsync("u_" .. player.UserId, snapshot)
		end)
		if ok then
			return
		end
		warn("[PumpFly] Speichern fehlgeschlagen für", player.Name, err)
		task.wait(attempt)
	end
end

---------------------------------------------------------------- Helfer
local function notify(player, text, kind)
	R.Notify:FireClient(player, text, kind or "info")
end

local function friendBoost(s)
	return math.min(s.friends * Config.FriendBoostPerFriend, Config.FriendBoostMax)
end

local function multiplier(s)
	local m = (1 + s.data.Rebirths * Config.RebirthBonus) * (1 + friendBoost(s))
	if s.hasDouble then
		m *= 2
	end
	return m
end

local function sendState(player)
	local s = sessions[player]
	if not s then
		return
	end
	local d = s.data
	if s.stats then
		s.stats.Coins.Value = d.Coins
		s.stats.Record.Value = d.BestHeight
		s.stats.Rebirths.Value = d.Rebirths
	end
	R.State:FireClient(player, {
		Coins = d.Coins,
		Air = s.air,
		Capacity = Config.Balloons[d.Balloon].Capacity,
		Balloon = d.Balloon,
		Pump = d.Pump,
		Rebirths = d.Rebirths,
		BestHeight = d.BestHeight,
		Multiplier = multiplier(s),
		FriendBoost = friendBoost(s),
		GiftIn = math.max(0, d.LastGift + Config.GiftCooldown - os.time()),
		HasDouble = s.hasDouble,
		Flying = s.flying,
	})
end

local function burst(position, color, amount)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.5
	e.Speed = NumberRange.new(25, 50)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Size = NumberSequence.new(1, 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(amount)
	Debris:AddItem(p, 2)
end

-- Der Ballon über dem Kopf wächst mit der Luft – alle anderen sehen ihn!
local function updateBalloon(player)
	local s = sessions[player]
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not s or not head then
		return
	end
	local cfg = Config.Balloons[s.data.Balloon]
	local balloon = char:FindFirstChild("PumpBalloon")
	if not balloon then
		balloon = Instance.new("Part")
		balloon.Name = "PumpBalloon"
		balloon.Shape = Enum.PartType.Ball
		balloon.Material = Enum.Material.SmoothPlastic
		balloon.Reflectance = 0.15
		balloon.CanCollide = false
		balloon.CanQuery = false
		balloon.CanTouch = false
		balloon.CastShadow = false
		balloon.Massless = true

		local weld = Instance.new("Weld")
		weld.Name = "BalloonWeld"
		weld.Part0 = head
		weld.Part1 = balloon
		weld.Parent = balloon

		local top = Instance.new("Attachment")
		top.Name = "StringTop"
		top.Parent = balloon
		local bottom = Instance.new("Attachment")
		bottom.Name = "BalloonString"
		bottom.Position = Vector3.new(0, head.Size.Y / 2, 0)
		bottom.Parent = head

		local rope = Instance.new("RopeConstraint")
		rope.Name = "String"
		rope.Visible = true
		rope.Thickness = 0.05
		rope.Color = BrickColor.White()
		rope.Attachment0 = bottom
		rope.Attachment1 = top
		rope.Parent = balloon

		balloon.Parent = char
	end

	local size = 1.2 + math.clamp(s.air / cfg.Capacity, 0, 1) * 5
	local offset = 2 + size / 2
	balloon.Size = Vector3.new(size, size * 1.1, size)
	balloon.Color = cfg.Color
	balloon.BalloonWeld.C0 = CFrame.new(0, offset, 0)
	balloon.StringTop.Position = Vector3.new(0, -size * 0.55, 0)
	balloon.String.Length = offset - size * 0.55 - head.Size.Y / 2 + 0.2
end

---------------------------------------------------------------- Pumpen
R.Pump.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.flying then
		return
	end
	local now = os.clock()
	if now - s.lastPump < Config.PumpCooldown then
		return
	end
	s.lastPump = now

	local cap = Config.Balloons[s.data.Balloon].Capacity
	local power = Config.Pumps[s.data.Pump].Power
	local roll = Config.PumpRandomMin + math.random() * (Config.PumpRandomMax - Config.PumpRandomMin)
	local gain = math.max(1, math.floor(power * roll + 0.5))
	gain = math.min(gain, math.max(1, math.floor(cap * Config.MaxGainPerPump)))
	s.air += gain

	if s.air > cap then
		local balloon = player.Character and player.Character:FindFirstChild("PumpBalloon")
		if balloon then
			burst(balloon.Position, balloon.Color, 70)
		end
		s.air = 0
		notify(player, "💥 PLOPP! Dein Ballon ist geplatzt!", "bad")
	end
	updateBalloon(player)
	sendState(player)
end)

---------------------------------------------------------------- Fliegen
R.Launch.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.flying then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	if s.air < Config.LaunchMinAir then
		notify(player, "Zu wenig Luft! Erst pumpen 🎈", "bad")
		return
	end

	s.flying = true
	local height = math.min(s.air * Config.LiftPerAir, Config.MaxHeight)
	local zone = Config.GetZone(height)
	local duration = math.clamp(height / Config.FlightSpeed, 1.5, 9)
	R.Flight:FireClient(player, height, duration)
	sendState(player)

	task.delay(duration, function()
		if sessions[player] ~= s then
			return
		end
		local reward = math.floor(height * Config.CoinsPerStud * zone.Multiplier * multiplier(s))
		s.data.Coins += reward
		s.data.Launches += 1

		local balloon = char:FindFirstChild("PumpBalloon")
		if balloon then
			burst(balloon.Position, balloon.Color, 50)
		end
		s.air = 0
		updateBalloon(player)

		if height > s.data.BestHeight then
			if s.data.BestHeight > 0 then
				notify(player, "🏆 NEUER REKORD: " .. fmt(height) .. " Studs!", "record")
			end
			s.data.BestHeight = math.floor(height)
		end
		notify(player, string.format("+%s 💰   %s %s (x%s)", fmt(reward), zone.Icon, zone.Name, Config.FormatMult(zone.Multiplier)), "good")
		sendState(player)

		task.wait(1)
		if sessions[player] ~= s then
			return
		end
		R.FlightEnd:FireClient(player, world.SpawnCFrame * CFrame.new(math.random(-10, 10), 0, math.random(-10, 10)))
		s.flying = false
		sendState(player)
	end)
end)

---------------------------------------------------------------- Shop / Rebirth / Codes / Geschenk
R.Buy.OnServerEvent:Connect(function(player, kind)
	local s = sessions[player]
	if not s or (kind ~= "Balloon" and kind ~= "Pump") then
		return
	end
	local list = kind == "Balloon" and Config.Balloons or Config.Pumps
	local nextItem = list[s.data[kind] + 1]
	if not nextItem then
		notify(player, "Schon das Beste vom Besten! 😎", "info")
		return
	end
	if s.data.Coins < nextItem.Price then
		notify(player, "Nicht genug Münzen 💸", "bad")
		return
	end
	s.data.Coins -= nextItem.Price
	s.data[kind] += 1
	notify(player, "Gekauft: " .. nextItem.Name .. " ✅", "good")
	updateBalloon(player)
	sendState(player)
end)

R.Rebirth.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.flying then
		return
	end
	local cost = Config.RebirthCost(s.data.Rebirths)
	if s.data.Coins < cost then
		notify(player, "Du brauchst " .. fmt(cost) .. " 💰 für einen Rebirth", "bad")
		return
	end
	s.data.Rebirths += 1
	s.data.Coins = 0
	s.data.Balloon = 1
	s.data.Pump = 1
	s.air = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		burst(root.Position, Color3.fromRGB(255, 220, 60), 120)
	end
	notify(player, string.format("🌟 REBIRTH %d! Jetzt dauerhaft x%s Münzen", s.data.Rebirths, Config.FormatMult(multiplier(s))), "record")
	updateBalloon(player)
	sendState(player)
end)

R.Redeem.OnServerEvent:Connect(function(player, code)
	local s = sessions[player]
	if not s or typeof(code) ~= "string" or #code > 30 then
		return
	end
	if os.clock() - s.lastAction < 1 then
		return
	end
	s.lastAction = os.clock()
	code = string.upper((code:gsub("%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		notify(player, "Ungültiger Code ❌", "bad")
	elseif s.data.Codes[code] then
		notify(player, "Code schon eingelöst!", "bad")
	else
		s.data.Codes[code] = true
		s.data.Coins += reward
		notify(player, "🎁 Code eingelöst: +" .. fmt(reward) .. " 💰", "good")
		sendState(player)
	end
end)

R.ClaimGift.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s then
		return
	end
	if os.time() - s.data.LastGift < Config.GiftCooldown then
		notify(player, "Geschenk noch nicht bereit ⏳", "bad")
		return
	end
	local reward = Config.GiftCoins(s.data.Rebirths)
	s.data.LastGift = os.time()
	s.data.Coins += reward
	notify(player, "🎁 Gratis-Geschenk: +" .. fmt(reward) .. " 💰", "good")
	sendState(player)
end)

R.RequestState.OnServerEvent:Connect(sendState)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local s = sessions[player]
	if s and purchased and passId == Config.GamePasses.DoubleCoins then
		s.hasDouble = true
		notify(player, "💎 2x Münzen aktiviert! Danke!", "record")
		sendState(player)
	end
end)

---------------------------------------------------------------- Freunde-Boost (lädt Spieler ein, Freunde mitzubringen)
local friendPairs = {}

local function refreshFriends()
	for player, s in pairs(sessions) do
		local n = 0
		for other, isFriend in pairs(friendPairs[player] or {}) do
			if isFriend and other.Parent then
				n += 1
			end
		end
		if n > s.friends then
			notify(player, string.format("👥 Freund ist da! +%d%% Münzen", math.floor(math.min(n * Config.FriendBoostPerFriend, Config.FriendBoostMax) * 100)), "good")
		end
		s.friends = n
		sendState(player)
	end
end

---------------------------------------------------------------- Spieler betreten / verlassen
local function onPlayerAdded(player)
	local data, ok = loadData(player)
	if not player.Parent then
		return
	end

	local s = {
		data = data,
		canSave = ok,
		air = 0,
		flying = false,
		lastPump = 0,
		lastAction = 0,
		friends = 0,
		hasDouble = false,
		postedHeight = 0,
	}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Münzen"
	coins.Parent = leaderstats
	local record = Instance.new("NumberValue")
	record.Name = "Rekord"
	record.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
	s.stats = { Coins = coins, Record = record, Rebirths = rebirths }

	sessions[player] = s

	if Config.GamePasses.DoubleCoins ~= 0 then
		local okPass, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Config.GamePasses.DoubleCoins)
		s.hasDouble = okPass and owns or false
	end

	friendPairs[player] = friendPairs[player] or {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local okF, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			local f = okF and isFriend or false
			friendPairs[player][other] = f
			friendPairs[other] = friendPairs[other] or {}
			friendPairs[other][player] = f
		end
	end

	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 5)
		updateBalloon(player)
	end)
	if player.Character then
		task.spawn(updateBalloon, player)
	end

	if not ok then
		notify(player, "⚠ Daten konnten nicht geladen werden – Fortschritt wird diese Runde NICHT gespeichert.", "bad")
	end
	notify(player, "Willkommen bei " .. Config.GameName .. "! 🎈 Halte PUMPEN gedrückt.", "info")
	refreshFriends()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local s = sessions[player]
	sessions[player] = nil
	friendPairs[player] = nil
	for _, t in pairs(friendPairs) do
		t[player] = nil
	end
	if s then
		saveData(player, s)
	end
	refreshFriends()
end)

-- Autosave
task.spawn(function()
	while true do
		task.wait(90)
		for player, s in pairs(sessions) do
			task.spawn(saveData, player, s)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player, s in pairs(sessions) do
		pending += 1
		task.spawn(function()
			saveData(player, s)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end)

---------------------------------------------------------------- Weltweite Bestenliste
local nameCache = {}

local function updateGlobalBoard()
	if not boardStore then
		world.SetBoard(nil)
		return
	end
	for player, s in pairs(sessions) do
		if s.canSave and s.data.BestHeight > s.postedHeight then
			local ok = pcall(function()
				boardStore:SetAsync(tostring(player.UserId), math.floor(s.data.BestHeight))
			end)
			if ok then
				s.postedHeight = s.data.BestHeight
			end
		end
	end
	local ok, pages = pcall(function()
		return boardStore:GetSortedAsync(false, 10)
	end)
	if not ok then
		world.SetBoard(nil)
		return
	end
	local entries = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		local name = nameCache[userId]
		if not name then
			local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			name = okName and result or "???"
			nameCache[userId] = name
		end
		table.insert(entries, { Name = name, Value = entry.value })
	end
	world.SetBoard(entries)
end

task.spawn(function()
	task.wait(5)
	while true do
		updateGlobalBoard()
		task.wait(60)
	end
end)
