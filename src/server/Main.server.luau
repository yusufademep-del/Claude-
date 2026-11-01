-- Lager-Imperium – Server: Spieler, Speichern, Bauen, Aufträge, LKWs, Tragen, Automatisierung
-- Alles Wichtige entscheidet der Server → Exploiter können sich keine Münzen ercheaten.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local World = require(script.Parent:WaitForChild("World"))
local Plots = require(script.Parent:WaitForChild("Plots"))
local Trucks = require(script.Parent:WaitForChild("Trucks"))

local fmt = Config.Format
local world = World.Build(Config)
Plots.Init(world.Plots)

---------------------------------------------------------------- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local R = {}
for _, name in ipairs({ "Place", "Remove", "BuyChunk", "AcceptOrder", "CancelOrder", "BuyTool", "Drop", "Redeem", "RequestState", "State", "Notify" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	R[name] = r
end
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- Daten
local dataStore
pcall(function()
	dataStore = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local function defaultData()
	local sx, sz = Config.StartChunk[1], Config.StartChunk[2]
	return {
		Coins = Config.StartCoins,
		XP = 0,
		Level = 1,
		Tool = 1,
		Orders = 0,
		Chunks = { [Plots.ChunkKey(sx, sz)] = true },
		Items = {
			{ u = 1, i = "Dock", x = -2, z = 0, r = 0 },
			{ u = 2, i = "ShelfS", x = -4, z = 5, r = 0 },
			{ u = 3, i = "ShelfS", x = 1, z = 5, r = 0 },
			{ u = 4, i = "Sign", x = 2, z = 0, r = 0 },
		},
		NextUid = 5,
		Codes = {},
	}
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
			data.Tool = math.clamp(data.Tool, 1, #Config.Tools)
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
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:SetAsync("u_" .. player.UserId, s.data)
		end)
		if ok then
			return
		end
		warn("[Lager] Speichern fehlgeschlagen für", player.Name, err)
		task.wait(attempt)
	end
end

---------------------------------------------------------------- Sitzungen & Helfer
local sessions = {}

local function notify(player, text, kind)
	R.Notify:FireClient(player, text, kind or "info")
end

local function count(s, itemId, max)
	local n = s.plot and Plots.Count(s.plot, itemId) or 0
	return max and math.min(n, max) or n
end

local function carryMax(s)
	return Config.Tools[s.data.Tool].Carry
end

local function rewardMult(s, kind)
	local m = 1 + count(s, "Office", Config.OfficeMax) * Config.OfficeBonus
	if kind == "Out" then
		m += count(s, "Pack", Config.PackMax) * Config.PackBonus
	end
	return m
end

local function freeDocks(s)
	local free, total = {}, 0
	if s.plot then
		for _, e in ipairs(Plots.Docks(s.plot)) do
			total += 1
			if not s.plot.DockBusy[e.u] then
				table.insert(free, e)
			end
		end
	end
	return free, total
end

local function sendState(player)
	local s = sessions[player]
	if not s then
		return
	end
	local d = s.data
	if s.stats then
		s.stats.Coins.Value = d.Coins
		s.stats.Level.Value = d.Level
	end
	local stock, used, cap = {}, 0, 0
	if s.plot then
		stock, used, cap = Plots.StockSummary(s.plot)
	end
	local now = os.clock()
	local offers = {}
	for _, o in ipairs(s.offers) do
		table.insert(offers, {
			Id = o.Id,
			Kind = o.Kind,
			Goods = o.Goods,
			Amount = o.Amount,
			Reward = math.floor(o.Reward * rewardMult(s, o.Kind)),
			Client = o.Client,
			Time = o.Time,
			ExpiresIn = math.max(0, o.Expires - now),
		})
	end
	local active = {}
	for _, o in ipairs(s.active) do
		table.insert(active, {
			Id = o.Id,
			Kind = o.Kind,
			Goods = o.Goods,
			Amount = o.Amount,
			Done = o.Done,
			Reward = math.floor(o.Reward * rewardMult(s, o.Kind)),
			Client = o.Client,
			Arrived = o.Arrived,
			TimeLeft = o.Arrived and math.max(0, o.Deadline - now) or o.Time,
		})
	end
	local free, totalDocks = freeDocks(s)
	R.State:FireClient(player, {
		Coins = d.Coins,
		Level = d.Level,
		XP = d.XP,
		XPNeed = Config.XPForLevel(d.Level),
		Tool = d.Tool,
		Carry = { Goods = s.carry.g, Count = s.carry.n },
		CarryMax = carryMax(s),
		Chunks = d.Chunks,
		ChunkPrice = Config.ChunkPrice(Plots.ChunkCount(d)),
		Stock = stock,
		Used = used,
		Capacity = cap,
		Offers = offers,
		Active = active,
		Docks = totalDocks,
		FreeDocks = #free,
		OrdersDone = d.Orders,
		ItemCount = #d.Items,
		PlotIndex = s.plot and s.plot.Index or 0,
	})
end

local function addXP(s, amount)
	local d = s.data
	d.XP += amount
	while d.XP >= Config.XPForLevel(d.Level) do
		d.XP -= Config.XPForLevel(d.Level)
		d.Level += 1
		local unlocked = {}
		for _, def in ipairs(Items.List) do
			if def.Level == d.Level then
				table.insert(unlocked, def.Name)
			end
		end
		for _, g in ipairs(Config.Goods) do
			if g.Level == d.Level then
				table.insert(unlocked, g.Icon .. " " .. g.Name)
			end
		end
		for _, t in ipairs(Config.Tools) do
			if t.Level == d.Level then
				table.insert(unlocked, t.Name)
			end
		end
		notify(s.player, "⭐ LEVEL " .. d.Level .. "!", "record")
		if #unlocked > 0 then
			notify(s.player, "🔓 Neu: " .. table.concat(unlocked, ", "), "good")
		end
	end
end

-- Kisten, die der Spieler trägt, sieht man vor seinem Bauch
local function updateCarryVisual(s)
	local char = s.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = char:FindFirstChild("CarryBoxes")
	if old then
		old:Destroy()
	end
	if s.carry.n <= 0 then
		return
	end
	local g = Config.GoodsById[s.carry.g]
	local folder = Instance.new("Folder")
	folder.Name = "CarryBoxes"
	for i = 1, math.min(s.carry.n, 6) do
		local box = Instance.new("Part")
		box.Name = "Box"
		box.Size = Vector3.new(1.8, 1.2, 1.4)
		box.Color = g and g.Color or Color3.fromRGB(200, 160, 110)
		box.Material = Enum.Material.SmoothPlastic
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Massless = true
		box.CFrame = root.CFrame * CFrame.new(0, -0.6 + (i - 1) * 1.25, -1.5)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = box
		weld.Parent = box
		box.Parent = folder
	end
	folder.Parent = char
end

local function applyBonuses(s)
	local char = s.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Config.BaseWalkSpeed + count(s, "Coffee", Config.CoffeeMax) * Config.CoffeeSpeed
	end
end

---------------------------------------------------------------- Aufträge
local function unlockedGoods(level)
	local list = {}
	for _, g in ipairs(Config.Goods) do
		if g.Level <= level then
			table.insert(list, g)
		end
	end
	return list
end

local function makeOrder(s)
	local d = s.data
	local stock, used, cap = Plots.StockSummary(s.plot)
	local goodsList = unlockedGoods(d.Level)
	local minA, maxA = Config.OrderAmountRange(d.Level)

	local inStock = {}
	for _, g in ipairs(goodsList) do
		if (stock[g.Id] or 0) >= minA then
			table.insert(inStock, g)
		end
	end

	local kind, g, amount
	if #inStock > 0 and math.random() < 0.55 then
		kind = "Out"
		g = inStock[math.random(1, #inStock)]
		amount = math.random(minA, math.max(minA, math.min(maxA, stock[g.Id])))
	else
		kind = "In"
		g = goodsList[math.random(1, #goodsList)]
		local free = cap - used
		amount = math.random(minA, free >= minA and math.min(maxA, free) or maxA)
	end

	local levelMult = 1 + (d.Level - 1) * 0.08
	local base = kind == "In" and Config.InRewardPerBox or Config.OutRewardPerBox
	local order = {
		Id = s.nextOrderId,
		Kind = kind,
		Goods = g.Id,
		Amount = amount,
		Reward = math.floor(amount * base * g.Value * levelMult),
		Time = Config.OrderTime(amount),
		Client = Config.Clients[math.random(1, #Config.Clients)],
		Expires = os.clock() + Config.OfferLifetime + math.random(0, 40),
	}
	s.nextOrderId += 1
	return order
end

local function refillOffers(s)
	if not s.plot then
		return false
	end
	local now, changed = os.clock(), false
	for i = #s.offers, 1, -1 do
		if s.offers[i].Expires <= now then
			table.remove(s.offers, i)
			changed = true
		end
	end
	local want = Config.OfferCount + count(s, "Office", Config.OfficeMax)
	while #s.offers < want do
		table.insert(s.offers, makeOrder(s))
		changed = true
	end
	return changed
end

local function findActive(s, id)
	for i, o in ipairs(s.active) do
		if o.Id == id then
			return o, i
		end
	end
end

local function updateTruckLabel(o)
	local truck = o.Truck
	local label = truck and truck:FindFirstChild("Trailer") and truck.Trailer:FindFirstChild("Info")
	if not label then
		return
	end
	local g = Config.GoodsById[o.Goods]
	local head = o.Kind == "In" and "⬇ ENTLADEN" or "⬆ BELADEN"
	local timeText = o.Arrived and ("⏱ " .. Config.FormatTime(o.Deadline - os.clock())) or "🚚 kommt an…"
	label.Text.Text = string.format("%s  %s %d/%d\n%s", head, g.Icon, o.Done, o.Amount, timeText)
end

local function finishOrder(s, o, success, reason)
	if o.Finished then
		return
	end
	o.Finished = true
	local _, index = findActive(s, o.Id)
	if index then
		table.remove(s.active, index)
	end

	if success then
		local reward = math.floor(o.Reward * rewardMult(s, o.Kind))
		s.data.Coins += reward
		s.data.Orders += 1
		addXP(s, o.Amount * Config.XPPerOrderBox)
		notify(s.player, string.format("✅ Auftrag für %s erledigt: +%s 💰", o.Client, fmt(reward)), "good")
	else
		notify(s.player, reason or "⌛ Auftrag abgelaufen – der LKW fährt weg.", "bad")
	end

	local plot = s.plot
	local truck = o.Truck
	local dockEntry = plot and plot.Entries[o.DockUid]
	if truck and truck.Parent then
		local prompt = truck:FindFirstChild("TruckPrompt", true)
		if prompt then
			prompt:Destroy()
		end
		if o.Arrived and dockEntry then
			truck.Trailer.Info.Text.Text = success and "✅ Danke! Tschüss!" or "❌ Zu spät…"
			task.spawn(function()
				Trucks.Leave(truck, plot.Origin, Plots.DockX(dockEntry))
			end)
		else
			truck:Destroy()
		end
	end
	if plot then
		task.delay(o.Arrived and 2.5 or 0, function()
			if plot.Owner == s.player and plot.DockBusy[o.DockUid] == o.Id then
				Plots.SetDockBusy(plot, o.DockUid, nil)
				sendState(s.player)
			end
		end)
	end
	refillOffers(s)
	sendState(s.player)
end

local function checkComplete(s, o)
	updateTruckLabel(o)
	if o.Done >= o.Amount then
		finishOrder(s, o, true)
	end
end

R.AcceptOrder.OnServerEvent:Connect(function(player, id)
	local s = sessions[player]
	if not s or not s.plot then
		return
	end
	local offer, index
	for i, o in ipairs(s.offers) do
		if o.Id == id then
			offer, index = o, i
		end
	end
	if not offer then
		return
	end
	local free = freeDocks(s)
	local dock = free[1]
	if not dock then
		notify(player, "🚫 Keine freie Laderampe! Bau eine weitere (🔨 Bauen → Technik).", "bad")
		return
	end

	table.remove(s.offers, index)
	offer.Done = 0
	offer.DockUid = dock.u
	offer.Arrived = false
	table.insert(s.active, offer)
	Plots.SetDockBusy(s.plot, dock.u, offer.Id)

	local plot = s.plot
	local g = Config.GoodsById[offer.Goods]
	local truck = Trucks.Build(g.Color, "🚚 kommt an…")
	truck.Parent = plot.Trucks
	offer.Truck = truck
	updateTruckLabel(offer)

	task.spawn(function()
		Trucks.Arrive(truck, plot.Origin, Plots.DockX(dock))
		if offer.Finished or not truck.Parent then
			return
		end
		offer.Arrived = true
		offer.Deadline = os.clock() + offer.Time
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TruckPrompt"
		prompt.ActionText = offer.Kind == "In" and "Entladen" or "Beladen"
		prompt.ObjectText = "LKW – " .. g.Icon .. " " .. g.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Action", "Truck")
		prompt:SetAttribute("OrderId", offer.Id)
		prompt:SetAttribute("OwnerId", player.UserId)
		prompt.Parent = truck.Rear.PromptPoint
		updateTruckLabel(offer)
		notify(player, offer.Kind == "In" and "🚚 LKW ist da – ab ans Entladen!" or "🚚 LKW ist da – belade ihn mit " .. g.Name .. "!", "info")
		sendState(player)
	end)

	refillOffers(s)
	sendState(player)
end)

R.CancelOrder.OnServerEvent:Connect(function(player, id)
	local s = sessions[player]
	local o = s and findActive(s, id)
	if o then
		finishOrder(s, o, false, "Auftrag abgebrochen.")
	end
end)

---------------------------------------------------------------- Tragen: Regale & LKWs
local function neededForOut(s, goods)
	local need = 0
	for _, o in ipairs(s.active) do
		if o.Kind == "Out" and o.Goods == goods then
			need += o.Amount - o.Done
		end
	end
	return need
end

local function shelfAction(s, entry, action)
	local def = Items.ById[entry.i]
	local carry = s.carry
	if action == "Store" then
		if carry.n <= 0 then
			notify(s.player, "Du trägst nichts. Hol Kisten vom LKW!", "bad")
			return
		end
		local free = def.Capacity - Plots.ShelfUsed(entry)
		if free <= 0 then
			notify(s.player, "Regal ist voll! Bau mehr Regale.", "bad")
			return
		end
		local n = math.min(free, carry.n)
		entry.s[carry.g] = (entry.s[carry.g] or 0) + n
		carry.n -= n
		addXP(s, n * Config.XPPerBox)
	else
		local space = carryMax(s) - carry.n
		if space <= 0 then
			notify(s.player, "Hände voll! Bessere Ausrüstung = mehr tragen (🛠).", "bad")
			return
		end
		local pick
		if carry.n > 0 then
			pick = carry.g
		else
			for _, g in ipairs(Config.Goods) do
				if (entry.s[g.Id] or 0) > 0 and neededForOut(s, g.Id) > 0 then
					pick = g.Id
					break
				end
			end
			if not pick then
				local best = 0
				for gid, c in pairs(entry.s) do
					if c > best then
						pick, best = gid, c
					end
				end
			end
		end
		local have = pick and entry.s[pick] or 0
		if have <= 0 then
			notify(s.player, carry.n > 0 and "Hier liegt keine passende Ware." or "Regal ist leer.", "bad")
			return
		end
		local n = math.min(space, have)
		local need = neededForOut(s, pick)
		if need > 0 then
			n = math.min(n, math.max(1, need - (carry.g == pick and carry.n or 0)))
		end
		entry.s[pick] = have - n > 0 and have - n or nil
		carry.g = pick
		carry.n += n
	end
	if carry.n <= 0 then
		carry.g, carry.n = nil, 0
	end
	Plots.UpdateShelf(s.plot, entry)
	updateCarryVisual(s)
	sendState(s.player)
end

local function truckAction(s, o)
	local carry = s.carry
	local g = Config.GoodsById[o.Goods]
	if not o.Arrived or o.Done >= o.Amount then
		return
	end
	if o.Kind == "In" then
		if carry.n > 0 and carry.g ~= o.Goods then
			notify(s.player, "Du trägst andere Ware! Erst einlagern oder fallen lassen.", "bad")
			return
		end
		local space = carryMax(s) - carry.n
		if space <= 0 then
			notify(s.player, "Hände voll – bring die Kisten erst ins Regal!", "bad")
			return
		end
		local n = math.min(space, o.Amount - o.Done)
		carry.g = o.Goods
		carry.n += n
		o.Done += n
		addXP(s, n * Config.XPPerBox)
	else
		if carry.n <= 0 or carry.g ~= o.Goods then
			notify(s.player, "Hol erst " .. g.Icon .. " " .. g.Name .. " aus einem Regal (F)!", "bad")
			return
		end
		local n = math.min(carry.n, o.Amount - o.Done)
		carry.n -= n
		o.Done += n
		addXP(s, n * Config.XPPerBox)
		if carry.n <= 0 then
			carry.g, carry.n = nil, 0
		end
	end
	updateCarryVisual(s)
	checkComplete(s, o)
	sendState(s.player)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local s = sessions[player]
	local action = prompt:GetAttribute("Action")
	if not s or not s.plot or not action then
		return
	end
	if prompt:GetAttribute("OwnerId") ~= player.UserId then
		notify(player, "Das ist nicht dein Lager 😉", "bad")
		return
	end
	if action == "Store" or action == "Take" then
		local entry = s.plot.Entries[prompt:GetAttribute("Uid")]
		if entry then
			shelfAction(s, entry, action)
		end
	elseif action == "Truck" then
		local o = findActive(s, prompt:GetAttribute("OrderId"))
		if o then
			truckAction(s, o)
		end
	end
end)

R.Drop.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if s and s.carry.n > 0 then
		notify(player, "Kisten abgestellt und entsorgt.", "info")
		s.carry.g, s.carry.n = nil, 0
		updateCarryVisual(s)
		sendState(player)
	end
end)

---------------------------------------------------------------- Bauen
local function isInt(v, lo, hi)
	return typeof(v) == "number" and v == v and math.floor(v) == v and v >= lo and v <= hi
end

R.Place.OnServerEvent:Connect(function(player, itemId, tx, tz, rot)
	local s = sessions[player]
	if not s or not s.plot or typeof(itemId) ~= "string" then
		return
	end
	if not (isInt(tx, -999, 999) and isInt(tz, -999, 999) and isInt(rot, 0, 3)) then
		return
	end
	local def = Items.ById[itemId]
	if not def then
		return
	end
	local d = s.data
	if d.Level < def.Level then
		notify(player, "🔒 Ab Level " .. def.Level, "bad")
		return
	end
	if d.Coins < def.Price then
		notify(player, "Nicht genug Münzen 💸", "bad")
		return
	end
	if #d.Items >= Config.MaxItems then
		notify(player, "Maximale Anzahl Objekte erreicht.", "bad")
		return
	end
	local ok, reason = Plots.CanPlace(s.plot, d, def, tx, tz, rot)
	if not ok then
		notify(player, reason, "bad")
		return
	end
	d.Coins -= def.Price
	local entry = { u = d.NextUid, i = itemId, x = tx, z = tz, r = rot }
	d.NextUid += 1
	table.insert(d.Items, entry)
	Plots.Spawn(s.plot, entry)
	applyBonuses(s)
	refillOffers(s)
	sendState(player)
end)

R.Remove.OnServerEvent:Connect(function(player, uid)
	local s = sessions[player]
	if not s or not s.plot or typeof(uid) ~= "number" then
		return
	end
	local plot = s.plot
	local entry = plot.Entries[uid]
	if not entry then
		return
	end
	local def = Items.ById[entry.i]
	if def.Dock then
		if plot.DockBusy[uid] then
			notify(player, "Da steht gerade ein LKW!", "bad")
			return
		end
		if #Plots.Docks(plot) <= 1 then
			notify(player, "Du brauchst mindestens eine Laderampe.", "bad")
			return
		end
	end
	local moved
	if def.Shelf then
		local used = Plots.ShelfUsed(entry)
		if used > 0 then
			local _, totalUsed, totalCap = Plots.StockSummary(plot)
			local otherFree = (totalCap - def.Capacity) - (totalUsed - used)
			if otherFree < used then
				notify(player, "Kein Platz in anderen Regalen für den Inhalt!", "bad")
				return
			end
			moved = entry.s
		end
	end

	Plots.Despawn(plot, uid)
	for i, e in ipairs(s.data.Items) do
		if e.u == uid then
			table.remove(s.data.Items, i)
			break
		end
	end
	if moved then
		for g, c in pairs(moved) do
			Plots.StoreAnywhere(plot, g, c)
		end
	end
	local refund = math.floor(def.Price * Config.RemoveRefund)
	s.data.Coins += refund
	notify(player, "Abgerissen: +" .. fmt(refund) .. " 💰", "info")
	applyBonuses(s)
	sendState(player)
end)

R.BuyChunk.OnServerEvent:Connect(function(player, cx, cz)
	local s = sessions[player]
	if not s or not s.plot or not (isInt(cx, 0, 99) and isInt(cz, 0, 99)) then
		return
	end
	local d = s.data
	if not Plots.CanBuyChunk(d, cx, cz) then
		notify(player, "Diese Fläche kannst du (noch) nicht kaufen.", "bad")
		return
	end
	local price = Config.ChunkPrice(Plots.ChunkCount(d))
	if d.Coins < price then
		notify(player, "Du brauchst " .. fmt(price) .. " 💰 für diese Fläche.", "bad")
		return
	end
	d.Coins -= price
	d.Chunks[Plots.ChunkKey(cx, cz)] = true
	Plots.RefreshGround(s.plot, d)
	notify(player, "🧱 Neue Fläche gekauft! Dein Lager wächst.", "good")
	sendState(player)
end)

R.BuyTool.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s then
		return
	end
	local d = s.data
	local nextTool = Config.Tools[d.Tool + 1]
	if not nextTool then
		return
	end
	if d.Level < nextTool.Level then
		notify(player, "🔒 Ab Level " .. nextTool.Level, "bad")
		return
	end
	if d.Coins < nextTool.Price then
		notify(player, "Nicht genug Münzen 💸", "bad")
		return
	end
	d.Coins -= nextTool.Price
	d.Tool += 1
	notify(player, "🛠 " .. nextTool.Name .. " gekauft! Du trägst jetzt " .. nextTool.Carry .. " Kisten.", "good")
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

R.RequestState.OnServerEvent:Connect(sendState)

---------------------------------------------------------------- Spieler betreten / verlassen
local function teleportHome(s)
	local char = s.player.Character
	if char and s.plot then
		char:PivotTo(s.plot.Origin * CFrame.new(0, 4, 13))
	end
end

local function onPlayerAdded(player)
	local data, ok = loadData(player)
	if not player.Parent then
		return
	end

	local s = {
		player = player,
		data = data,
		canSave = ok,
		carry = { g = nil, n = 0 },
		offers = {},
		active = {},
		nextOrderId = 1,
		lastAction = 0,
		autoAcc = 0,
	}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Münzen"
	coins.Parent = leaderstats
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	leaderstats.Parent = player
	s.stats = { Coins = coins, Level = level }

	sessions[player] = s

	s.plot = Plots.Assign(player)
	if s.plot then
		Plots.Load(s.plot, data)
		refillOffers(s)
	else
		notify(player, "Server ist voll – kein Grundstück frei. Bitte anderen Server wählen.", "bad")
	end

	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		teleportHome(s)
		applyBonuses(s)
		s.carry.g, s.carry.n = nil, 0
		sendState(player)
	end)
	if player.Character then
		task.spawn(function()
			teleportHome(s)
			applyBonuses(s)
		end)
	end

	if not ok then
		notify(player, "⚠ Daten konnten nicht geladen werden – Fortschritt wird diese Runde NICHT gespeichert.", "bad")
	end
	notify(player, "Willkommen in deinem Lager! 📦 Öffne 📋 Aufträge, um loszulegen.", "info")
	sendState(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local s = sessions[player]
	sessions[player] = nil
	if not s then
		return
	end
	for _, o in ipairs(s.active) do
		o.Finished = true
	end
	saveData(player, s)
	if s.plot then
		Plots.Release(s.plot)
	end
end)

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

---------------------------------------------------------------- Takt: Zeitlimits, Angebote, LKW-Anzeigen
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for player, s in pairs(sessions) do
			local changed = refillOffers(s)
			for i = #s.active, 1, -1 do
				local o = s.active[i]
				if o and o.Arrived and now > o.Deadline then
					finishOrder(s, o, false)
				elseif o then
					updateTruckLabel(o)
				end
			end
			if changed then
				sendState(player)
			end
		end
	end
end)

---------------------------------------------------------------- Automatisierung: Gabelstapler
local function animateForklift(s)
	local list = {}
	for uid, e in pairs(s.plot.Entries) do
		if e.i == "Forklift" then
			table.insert(list, s.plot.Models[uid])
		end
	end
	local model = list[math.random(1, math.max(1, #list))]
	if not model then
		return
	end
	for _, part in ipairs(model:GetChildren()) do
		if part.Name == "Fork" and part:IsA("BasePart") then
			local base = part:GetAttribute("BaseCFrame") or part.CFrame
			part:SetAttribute("BaseCFrame", base)
			part.CFrame = base
			local up = TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), { CFrame = base + Vector3.new(0, 2.5, 0) })
			up:Play()
		end
	end
end

local function autoMove(s)
	for _, o in ipairs(s.active) do
		if o.Arrived and not o.Finished and o.Done < o.Amount then
			local moved = 0
			if o.Kind == "In" then
				moved = Plots.StoreAnywhere(s.plot, o.Goods, 1)
			else
				moved = Plots.TakeAnywhere(s.plot, o.Goods, 1)
			end
			if moved > 0 then
				o.Done += 1
				addXP(s, Config.XPPerBox)
				animateForklift(s)
				checkComplete(s, o)
				return true
			end
		end
	end
	return false
end

local TICK = 0.5
task.spawn(function()
	while true do
		task.wait(TICK)
		for player, s in pairs(sessions) do
			if s.plot and #s.active > 0 then
				local forklifts = count(s, "Forklift")
				if forklifts > 0 then
					local speed = 1 + count(s, "Conveyor", Config.ConveyorMax) * Config.ConveyorBonus
					s.autoAcc += forklifts * speed / Config.ForkliftInterval * TICK
					local moved = false
					while s.autoAcc >= 1 do
						s.autoAcc -= 1
						if autoMove(s) then
							moved = true
						else
							s.autoAcc = 0
							break
						end
					end
					if moved then
						sendState(player)
					end
				end
			else
				s.autoAcc = 0
			end
		end
	end
end)
