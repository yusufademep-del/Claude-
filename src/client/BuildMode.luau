-- Lager-Imperium – Bau-Modus auf dem Client
-- Platzieren (mit grüner/roter Vorschau), Drehen, Abreißen und Flächen kaufen.
-- PC: Maus zeigt die Position, Linksklick = platzieren, R = drehen, Q = fertig.
-- Handy: Tippen = Position wählen, dann ✔ drücken.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))

local player = Players.LocalPlayer
local T = Config.TileSize
local CHUNK = Config.ChunkTiles * T
local HALF_W = Config.ChunksX * CHUNK / 2
local OK_COLOR = Color3.fromRGB(70, 255, 110)
local BAD_COLOR = Color3.fromRGB(255, 60, 60)

local BuildMode = {}

local ctx
local mode
local current = { rot = 0, tx = 0, tz = 0, valid = false, reason = "" }
local ghost, ghostHighlight
local gridFolder, expandFolder
local hoverHighlight
local pointer
local touchStart
local occ, occDirty = { Object = {}, Floor = {} }, true
local watchedPlot
local plotConns = {}
local renderConn
local lastChunkSig = ""

---------------------------------------------------------------- Grundstück & Belegung
local function myPlot()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, f in ipairs(plots:GetChildren()) do
		if f:GetAttribute("OwnerId") == player.UserId then
			return f
		end
	end
end
BuildMode.MyPlot = myPlot

local function watchPlot(plot)
	for _, c in ipairs(plotConns) do
		c:Disconnect()
	end
	plotConns = {}
	watchedPlot = plot
	occDirty = true
	local items = plot:WaitForChild("Items")
	table.insert(plotConns, items.ChildAdded:Connect(function()
		occDirty = true
	end))
	table.insert(plotConns, items.ChildRemoved:Connect(function()
		occDirty = true
	end))
end

local function rebuildOcc(plot)
	occ = { Object = {}, Floor = {} }
	for _, m in ipairs(plot.Items:GetChildren()) do
		local def = Items.ById[m:GetAttribute("ItemId")]
		local tx, tz, rot = m:GetAttribute("Tx"), m:GetAttribute("Tz"), m:GetAttribute("Rot")
		if def and tx and tz and rot then
			local w, d = Items.Footprint(def, rot)
			for x = tx, tx + w - 1 do
				for z = tz, tz + d - 1 do
					occ[def.Layer][x .. "," .. z] = true
				end
			end
		end
	end
	occDirty = false
end

local function ownsChunk(state, cx, cz)
	return state.Chunks[cx .. "," .. cz] == true
end

local function canBuyChunk(state, cx, cz)
	if ownsChunk(state, cx, cz) then
		return false
	end
	for _, n in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		if ownsChunk(state, cx + n[1], cz + n[2]) then
			return true
		end
	end
	return false
end

local function chunkSig(state)
	local keys = {}
	for k in pairs(state.Chunks) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return table.concat(keys, ";")
end

---------------------------------------------------------------- Zeiger → Boden
local function pointerRay()
	local cam = workspace.CurrentCamera
	if pointer then
		return cam:ScreenPointToRay(pointer.X, pointer.Y)
	end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local v = cam.ViewportSize
		return cam:ViewportPointToRay(v.X / 2, v.Y / 2)
	end
	local m = UserInputService:GetMouseLocation()
	return cam:ViewportPointToRay(m.X, m.Y)
end

local function planePoint(origin)
	local ray = pointerRay()
	local dy = ray.Direction.Y
	if math.abs(dy) < 1e-4 then
		return nil
	end
	local t = (origin.Y - ray.Origin.Y) / dy
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function raycastIn(instances)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = instances
	local ray = pointerRay()
	return workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
end

local function hoveredModel(plot)
	local hit = raycastIn({ plot.Items })
	local inst = hit and hit.Instance
	while inst and inst.Parent ~= plot.Items do
		inst = inst.Parent
	end
	return inst
end

local function hoveredChunk()
	if not expandFolder then
		return nil
	end
	local hit = raycastIn({ expandFolder })
	return hit and hit.Instance
end

---------------------------------------------------------------- Visuelles: Vorschau, Raster, Flächen
local function clearVisuals()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if gridFolder then
		gridFolder:Destroy()
		gridFolder = nil
	end
	if expandFolder then
		expandFolder:Destroy()
		expandFolder = nil
	end
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
end

local function line(parent, size, cf)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.new(1, 1, 1)
	p.Transparency = 0.65
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
end

local function buildGrid(plot, state)
	if gridFolder then
		gridFolder:Destroy()
	end
	gridFolder = Instance.new("Folder")
	gridFolder.Name = "BuildGrid"
	local o = plot:GetAttribute("Origin")
	for key in pairs(state.Chunks) do
		local cx, cz = string.match(key, "^(%-?%d+),(%-?%d+)$")
		cx, cz = tonumber(cx), tonumber(cz)
		if cx and cz then
			local x0, z0 = -HALF_W + cx * CHUNK, cz * CHUNK
			for i = 0, Config.ChunkTiles do
				line(gridFolder, Vector3.new(0.12, 0.05, CHUNK), o * CFrame.new(x0 + i * T, 0.04, z0 + CHUNK / 2))
				line(gridFolder, Vector3.new(CHUNK, 0.05, 0.12), o * CFrame.new(x0 + CHUNK / 2, 0.04, z0 + i * T))
			end
		end
	end
	gridFolder.Parent = workspace
end

local function buildExpand(plot, state)
	if expandFolder then
		expandFolder:Destroy()
	end
	expandFolder = Instance.new("Folder")
	expandFolder.Name = "ExpandPreview"
	local o = plot:GetAttribute("Origin")
	for cx = 0, Config.ChunksX - 1 do
		for cz = 0, Config.ChunksZ - 1 do
			if canBuyChunk(state, cx, cz) then
				local p = Instance.new("Part")
				p.Name = "Chunk"
				p.Anchored = true
				p.CanCollide = false
				p.CastShadow = false
				p.Material = Enum.Material.Neon
				p.Color = OK_COLOR
				p.Transparency = 0.75
				p.Size = Vector3.new(CHUNK - 1, 3, CHUNK - 1)
				p.CFrame = o * CFrame.new(-HALF_W + (cx + 0.5) * CHUNK, 1.5, (cz + 0.5) * CHUNK)
				p:SetAttribute("Cx", cx)
				p:SetAttribute("Cz", cz)
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.new(18, 0, 6, 0)
				gui.StudsOffset = Vector3.new(0, 5, 0)
				gui.LightInfluence = 0
				gui.Parent = p
				local l = Instance.new("TextLabel")
				l.Size = UDim2.fromScale(1, 1)
				l.BackgroundTransparency = 1
				l.TextScaled = true
				l.Font = Enum.Font.FredokaOne
				l.TextColor3 = Color3.new(1, 1, 1)
				l.TextStrokeTransparency = 0
				l.Text = "🧱 Fläche kaufen\n💰 " .. Config.Format(state.ChunkPrice)
				l.Parent = gui
				p.Parent = expandFolder
			end
		end
	end
	expandFolder.Parent = workspace
end

local function makeGhost(def)
	if ghost then
		ghost:Destroy()
	end
	ghost = Items.Build(def, { OwnerName = player.DisplayName })
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency >= 1 then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.3)
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("Light") then
			d:Destroy()
		end
	end
	ghostHighlight = Instance.new("Highlight")
	ghostHighlight.FillTransparency = 0.55
	ghostHighlight.OutlineTransparency = 0
	ghostHighlight.Parent = ghost
	ghost.Parent = workspace
end

local function setHover(target, color)
	if not target then
		if hoverHighlight then
			hoverHighlight.Enabled = false
		end
		return
	end
	if not hoverHighlight or not hoverHighlight.Parent then
		hoverHighlight = Instance.new("Highlight")
		hoverHighlight.FillTransparency = 0.5
	end
	hoverHighlight.FillColor = color
	hoverHighlight.OutlineColor = color
	hoverHighlight.Adornee = target
	hoverHighlight.Parent = target
	hoverHighlight.Enabled = true
end

---------------------------------------------------------------- Jeder Frame im Bau-Modus
local function update()
	local plot = myPlot()
	local state = ctx.getState()
	if not plot or not state then
		return
	end
	if plot ~= watchedPlot then
		watchPlot(plot)
	end
	local o = plot:GetAttribute("Origin")

	if mode == "place" then
		local sig = chunkSig(state)
		if sig ~= lastChunkSig then
			lastChunkSig = sig
			buildGrid(plot, state)
		end
		if occDirty then
			rebuildOcc(plot)
		end
		local def = current.def
		local rot = def.Dock and 0 or current.rot
		local point = planePoint(o)
		if point then
			local lp = o:PointToObjectSpace(point)
			local w, d = Items.Footprint(def, rot)
			current.tx = math.floor(lp.X / T - w / 2 + 0.5)
			current.tz = def.Dock and 0 or math.floor(lp.Z / T - d / 2 + 0.5)
		end
		local ok, reason = Items.Validate(def, current.tx, current.tz, rot, function(cx, cz)
			return ownsChunk(state, cx, cz)
		end, function(layer, x, z)
			return not occ[layer][x .. "," .. z]
		end)
		if ok and state.Level < def.Level then
			ok, reason = false, "🔒 Ab Level " .. def.Level
		end
		if ok and state.Coins < def.Price then
			ok, reason = false, "Nicht genug Münzen 💸"
		end
		current.valid, current.reason, current.usedRot = ok, reason, rot
		ghost:PivotTo(o * Items.LocalCFrame(def, current.tx, current.tz, rot))
		ghostHighlight.FillColor = ok and OK_COLOR or BAD_COLOR
		ghostHighlight.OutlineColor = ok and OK_COLOR or BAD_COLOR
		ctx.onInfo(string.format("%s  •  %s 💰", def.Name, Config.Format(def.Price)), ok and "" or reason)
	elseif mode == "delete" then
		local model = hoveredModel(plot)
		setHover(model, BAD_COLOR)
		local def = model and Items.ById[model:GetAttribute("ItemId")]
		if def then
			ctx.onInfo("🗑 " .. def.Name .. "  •  +" .. Config.Format(math.floor(def.Price * Config.RemoveRefund)) .. " 💰 zurück", "")
		else
			ctx.onInfo("🗑 Klicke/tippe auf ein Objekt zum Abreißen", "")
		end
	elseif mode == "expand" then
		local sig = chunkSig(state) .. state.ChunkPrice
		if sig ~= lastChunkSig then
			lastChunkSig = sig
			buildExpand(plot, state)
		end
		local chunk = hoveredChunk()
		setHover(chunk, OK_COLOR)
		local canAfford = state.Coins >= state.ChunkPrice
		ctx.onInfo("🧱 Neue Fläche: " .. Config.Format(state.ChunkPrice) .. " 💰", canAfford and "" or "Noch nicht genug Münzen")
	end
end

local function act()
	local plot = myPlot()
	if not plot then
		return
	end
	if mode == "place" then
		if current.valid then
			ctx.R.Place:FireServer(current.def.Id, current.tx, current.tz, current.usedRot)
			occDirty = true
		elseif current.reason and current.reason ~= "" then
			ctx.toast(current.reason, "bad")
		end
	elseif mode == "delete" then
		local model = hoveredModel(plot)
		if model then
			ctx.R.Remove:FireServer(model:GetAttribute("Uid"))
		end
	elseif mode == "expand" then
		local chunk = hoveredChunk()
		if chunk then
			ctx.R.BuyChunk:FireServer(chunk:GetAttribute("Cx"), chunk:GetAttribute("Cz"))
		end
	end
end

---------------------------------------------------------------- Öffentliche Funktionen
local function start(newMode)
	BuildMode.Stop()
	mode = newMode
	lastChunkSig = ""
	pointer = nil
	renderConn = RunService.RenderStepped:Connect(update)
	ctx.onChanged(mode)
end

function BuildMode.StartPlace(itemId)
	local def = Items.ById[itemId]
	if not def then
		return
	end
	start("place")
	current.def = def
	makeGhost(def)
end

function BuildMode.StartDelete()
	start("delete")
end

function BuildMode.StartExpand()
	start("expand")
end

function BuildMode.Stop()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	clearVisuals()
	local was = mode
	mode = nil
	if was and ctx then
		ctx.onChanged(nil)
	end
end

function BuildMode.Mode()
	return mode
end

function BuildMode.Rotate()
	current.rot = (current.rot + 1) % 4
end

function BuildMode.Confirm()
	act()
end

function BuildMode.Init(context)
	ctx = context

	UserInputService.InputBegan:Connect(function(input, processed)
		if not mode or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			BuildMode.Rotate()
		elseif input.KeyCode == Enum.KeyCode.Q then
			BuildMode.Stop()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointer = nil
			act()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not mode or input.UserInputType ~= Enum.UserInputType.Touch or not touchStart then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local moved = (pos - touchStart).Magnitude
		touchStart = nil
		if moved < 20 then
			pointer = pos
			if mode ~= "place" then
				act()
			end
		end
	end)
end

return BuildMode
