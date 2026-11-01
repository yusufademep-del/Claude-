-- Lager-Imperium – Grundstücke: Zuweisung, Flächen, Objekte platzieren/abreißen, Regale

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))

local Plots = {}
Plots.List = {}

local T = Config.TileSize
local CHUNK = Config.ChunkTiles * T

function Plots.Init(worldPlots)
	for _, p in ipairs(worldPlots) do
		p.Owner = nil
		p.Models = {}
		p.Entries = {}
		p.Occ = { Object = {}, Floor = {} }
		p.DockBusy = {}
		table.insert(Plots.List, p)
	end
end

function Plots.Assign(player)
	for _, p in ipairs(Plots.List) do
		if not p.Owner then
			p.Owner = player
			p.Folder:SetAttribute("OwnerId", player.UserId)
			p.SignLabel.Text = "📦 Lager von " .. player.DisplayName
			return p
		end
	end
	return nil
end

function Plots.Clear(plot)
	plot.ItemsFolder:ClearAllChildren()
	plot.Trucks:ClearAllChildren()
	plot.Ground:ClearAllChildren()
	plot.Models = {}
	plot.Entries = {}
	plot.Occ = { Object = {}, Floor = {} }
	plot.DockBusy = {}
end

function Plots.Release(plot)
	Plots.Clear(plot)
	plot.Owner = nil
	plot.Folder:SetAttribute("OwnerId", 0)
	plot.SignLabel.Text = "Freies Grundstück"
end

function Plots.ChunkKey(cx, cz)
	return cx .. "," .. cz
end

function Plots.OwnsChunk(data, cx, cz)
	return data.Chunks[Plots.ChunkKey(cx, cz)] == true
end

function Plots.ChunkCount(data)
	local n = 0
	for _ in pairs(data.Chunks) do
		n += 1
	end
	return n
end

-- Darf dieses Flächen-Stück gekauft werden? (muss an ein eigenes angrenzen)
function Plots.CanBuyChunk(data, cx, cz)
	if cx < 0 or cx >= Config.ChunksX or cz < 0 or cz >= Config.ChunksZ then
		return false
	end
	if Plots.OwnsChunk(data, cx, cz) then
		return false
	end
	for _, n in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		if Plots.OwnsChunk(data, cx + n[1], cz + n[2]) then
			return true
		end
	end
	return false
end

-- Betonboden für alle gekauften Flächen
function Plots.RefreshGround(plot, data)
	plot.Ground:ClearAllChildren()
	local halfW = Config.ChunksX * CHUNK / 2
	for key in pairs(data.Chunks) do
		local cx, cz = string.match(key, "^(%-?%d+),(%-?%d+)$")
		cx, cz = tonumber(cx), tonumber(cz)
		if cx and cz then
			local p = Instance.new("Part")
			p.Name = "Chunk_" .. key
			p.Anchored = true
			p.Size = Vector3.new(CHUNK, 1, CHUNK)
			p.CFrame = plot.Origin * CFrame.new(-halfW + (cx + 0.5) * CHUNK, -0.5, (cz + 0.5) * CHUNK)
			p.Color = (cx + cz) % 2 == 0 and Color3.fromRGB(175, 175, 180) or Color3.fromRGB(165, 165, 170)
			p.Material = Enum.Material.Concrete
			p.TopSurface = Enum.SurfaceType.Smooth
			p.Parent = plot.Ground
		end
	end
end

local function tileKey(x, z)
	return x .. "," .. z
end

function Plots.IsFree(plot, layer, x, z)
	return plot.Occ[layer][tileKey(x, z)] == nil
end

function Plots.CanPlace(plot, data, def, tx, tz, rot)
	return Items.Validate(def, tx, tz, rot, function(cx, cz)
		return Plots.OwnsChunk(data, cx, cz)
	end, function(layer, x, z)
		return Plots.IsFree(plot, layer, x, z)
	end)
end

local function occupy(plot, entry, value)
	local def = Items.ById[entry.i]
	local w, d = Items.Footprint(def, entry.r)
	for x = entry.x, entry.x + w - 1 do
		for z = entry.z, entry.z + d - 1 do
			plot.Occ[def.Layer][tileKey(x, z)] = value
		end
	end
end

local function addPrompt(parent, name, action, key, text, distance, uid, plot)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = text
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", action)
	prompt:SetAttribute("Uid", uid)
	prompt:SetAttribute("Plot", plot.Index)
	prompt:SetAttribute("OwnerId", plot.Owner and plot.Owner.UserId or 0)
	prompt.Parent = parent
	return prompt
end

function Plots.Spawn(plot, entry)
	local def = Items.ById[entry.i]
	if not def then
		return
	end
	local model = Items.Build(def, { OwnerName = plot.Owner and plot.Owner.DisplayName })
	model.Name = def.Id .. "_" .. entry.u
	model:SetAttribute("Uid", entry.u)
	model:SetAttribute("ItemId", def.Id)
	model:SetAttribute("Tx", entry.x)
	model:SetAttribute("Tz", entry.z)
	model:SetAttribute("Rot", entry.r)
	model:PivotTo(plot.Origin * Items.LocalCFrame(def, entry.x, entry.z, entry.r))

	if def.Shelf then
		entry.s = entry.s or {}
		local interact = model:FindFirstChild("Interact")
		local dist = math.max(def.W, def.D) * T / 2 + 6
		local store = addPrompt(interact, "StorePrompt", "Store", Enum.KeyCode.E, "Einlagern", dist, entry.u, plot)
		store.ObjectText = def.Name
		local take = addPrompt(interact, "TakePrompt", "Take", Enum.KeyCode.F, "Auslagern", dist, entry.u, plot)
		take.ObjectText = def.Name
		take.UIOffset = Vector2.new(0, 70)
		Items.UpdateShelf(model, entry.s, def.Capacity)
	end

	model.Parent = plot.ItemsFolder
	if def.Id == "Conveyor" then
		local belt = model:FindFirstChild("Belt")
		if belt then
			belt.AssemblyLinearVelocity = belt.CFrame.LookVector * 10
		end
	end
	plot.Models[entry.u] = model
	plot.Entries[entry.u] = entry
	occupy(plot, entry, entry.u)
	return model
end

function Plots.Despawn(plot, uid)
	local entry = plot.Entries[uid]
	if not entry then
		return
	end
	occupy(plot, entry, nil)
	if plot.Models[uid] then
		plot.Models[uid]:Destroy()
	end
	plot.Models[uid] = nil
	plot.Entries[uid] = nil
	plot.DockBusy[uid] = nil
end

function Plots.Load(plot, data)
	Plots.Clear(plot)
	Plots.RefreshGround(plot, data)
	local valid = {}
	for _, entry in ipairs(data.Items) do
		local def = Items.ById[entry.i]
		if def and Plots.CanPlace(plot, data, def, entry.x, entry.z, entry.r) then
			Plots.Spawn(plot, entry)
			table.insert(valid, entry)
		end
	end
	data.Items = valid
end

function Plots.Count(plot, itemId)
	local n = 0
	for _, e in pairs(plot.Entries) do
		if e.i == itemId then
			n += 1
		end
	end
	return n
end

function Plots.Shelves(plot)
	local list = {}
	for _, e in pairs(plot.Entries) do
		local def = Items.ById[e.i]
		if def.Shelf then
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		return a.u < b.u
	end)
	return list
end

function Plots.ShelfUsed(entry)
	local n = 0
	for _, c in pairs(entry.s or {}) do
		n += c
	end
	return n
end

function Plots.UpdateShelf(plot, entry)
	local model = plot.Models[entry.u]
	if model then
		Items.UpdateShelf(model, entry.s, Items.ById[entry.i].Capacity)
	end
end

-- Gesamtbestand + Kapazität
function Plots.StockSummary(plot)
	local stock, used, cap = {}, 0, 0
	for _, e in ipairs(Plots.Shelves(plot)) do
		cap += Items.ById[e.i].Capacity
		for g, c in pairs(e.s or {}) do
			stock[g] = (stock[g] or 0) + c
			used += c
		end
	end
	return stock, used, cap
end

-- Kisten in Regale einlagern (füllt der Reihe nach). Gibt die eingelagerte Menge zurück.
function Plots.StoreAnywhere(plot, goods, amount)
	local stored = 0
	for _, e in ipairs(Plots.Shelves(plot)) do
		if stored >= amount then
			break
		end
		local free = Items.ById[e.i].Capacity - Plots.ShelfUsed(e)
		if free > 0 then
			local n = math.min(free, amount - stored)
			e.s[goods] = (e.s[goods] or 0) + n
			stored += n
			Plots.UpdateShelf(plot, e)
		end
	end
	return stored
end

function Plots.TakeAnywhere(plot, goods, amount)
	local taken = 0
	for _, e in ipairs(Plots.Shelves(plot)) do
		if taken >= amount then
			break
		end
		local have = e.s[goods] or 0
		if have > 0 then
			local n = math.min(have, amount - taken)
			e.s[goods] = have - n > 0 and have - n or nil
			taken += n
			Plots.UpdateShelf(plot, e)
		end
	end
	return taken
end

function Plots.Docks(plot)
	local list = {}
	for _, e in pairs(plot.Entries) do
		if e.i == "Dock" then
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		return a.x < b.x
	end)
	return list
end

function Plots.DockX(entry)
	local def = Items.ById.Dock
	local w = Items.Footprint(def, entry.r)
	return (entry.x + w / 2) * T
end

function Plots.SetDockBusy(plot, uid, orderId)
	plot.DockBusy[uid] = orderId
	local model = plot.Models[uid]
	local light = model and model:FindFirstChild("Light")
	if light then
		light.Color = orderId and Color3.fromRGB(255, 70, 50) or Color3.fromRGB(60, 255, 90)
	end
end

return Plots
