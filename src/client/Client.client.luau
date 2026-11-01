-- Lager-Imperium – Client: HUD, Auftrags-Tafel, Bau-Menü, Ausrüstung, Codes, Tutorial

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local UI = require(script.Parent:WaitForChild("UI"))
local BuildMode = require(script.Parent:WaitForChild("BuildMode"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local R = {}
for _, name in ipairs({ "Place", "Remove", "BuyChunk", "AcceptOrder", "CancelOrder", "BuyTool", "Drop", "Redeem", "RequestState", "State", "Notify" }) do
	R[name] = remotes:WaitForChild(name)
end

local player = Players.LocalPlayer
local fmt = Config.Format
local new, label, button = UI.new, UI.label, UI.button

local state
local stateAt = os.clock()

local gui = new("ScreenGui", {
	Name = "LagerUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
UI.initToasts(gui)

---------------------------------------------------------------- HUD oben
local top = UI.scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.fromOffset(520, 112),
	BackgroundTransparency = 1,
	Parent = gui,
}))
local coinsLabel = label({ Size = UDim2.new(1, 0, 0, 46), Text = "💰 0", TextColor3 = UI.YELLOW, TextStrokeTransparency = 0, Parent = top })
local levelBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.fromOffset(380, 24),
	BackgroundColor3 = UI.DARK,
	Parent = top,
}, { UI.corner(10), UI.stroke(2) })
local levelFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(160, 90, 255), Parent = levelBar }, { UI.corner(10) })
local levelText = label({ Size = UDim2.fromScale(1, 1), Text = "⭐ Level 1", ZIndex = 2, Parent = levelBar })
local infoLabel = label({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 24), Text = "", Parent = top })

local hintLabel = UI.scaled(label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 118),
	Size = UDim2.fromOffset(700, 30),
	Text = "",
	TextColor3 = UI.YELLOW,
	TextStrokeTransparency = 0,
	Parent = gui,
}))

---------------------------------------------------------------- Tragen (unten Mitte)
local carryFrame = UI.scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(420, 54),
	BackgroundColor3 = UI.DARK,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = gui,
}, { UI.corner(14), UI.stroke(3) }))
local carryLabel = label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = carryFrame })
local dropBtn = button("Abstellen", UI.RED, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(130, 40), Parent = carryFrame })

---------------------------------------------------------------- Menü links
local menu = UI.scaled(new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(160, 420),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) }))
local function menuButton(text, color, order)
	return button(text, color, { Size = UDim2.fromOffset(160, 58), LayoutOrder = order, Parent = menu })
end
local ordersBtn = menuButton("📋 Aufträge", Color3.fromRGB(255, 140, 30), 1)
local buildBtn = menuButton("🔨 Bauen", UI.BLUE, 2)
local expandBtn = menuButton("🧱 Erweitern", Color3.fromRGB(40, 180, 120), 3)
local deleteBtn = menuButton("🗑 Abreißen", UI.RED, 4)
local toolsBtn = menuButton("🛠 Ausrüstung", Color3.fromRGB(150, 90, 230), 5)
local codesBtn = menuButton("🎟 Codes", Color3.fromRGB(255, 90, 140), 6)

---------------------------------------------------------------- Laufende Aufträge (rechts)
local tracker = UI.scaled(new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 60),
	Size = UDim2.fromOffset(300, 420),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }))

---------------------------------------------------------------- Bau-Leiste (unten, im Bau-Modus)
local buildBar = UI.scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(600, 118),
	BackgroundColor3 = UI.DARK,
	BackgroundTransparency = 0.1,
	Visible = false,
	Parent = gui,
}, { UI.corner(16), UI.stroke(3) }))
local buildInfo = label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), Text = "", Parent = buildBar })
local buildReason = label({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 20), Text = "", TextColor3 = Color3.fromRGB(255, 120, 120), Parent = buildBar })
local rotateBtn = button("↻ Drehen (R)", UI.BLUE, { Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(180, 48), Parent = buildBar })
local confirmBtn = button("✔ Platzieren", UI.GREEN, { Position = UDim2.fromOffset(210, 60), Size = UDim2.fromOffset(180, 48), Parent = buildBar })
local doneBtn = button("✖ Fertig (Q)", UI.GRAY, { Position = UDim2.fromOffset(408, 60), Size = UDim2.fromOffset(180, 48), Parent = buildBar })

---------------------------------------------------------------- Fenster: Aufträge
local ordersPanel, ordersContent = UI.panel(gui, "📋 AUFTRAGS-TAFEL", Vector2.new(600, 500))
label({ Size = UDim2.new(1, 0, 0, 24), Text = "Neue Angebote", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = ordersContent })
local offersList = UI.scroll(ordersContent, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 250), ZIndex = 11 })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = offersList })
label({ Position = UDim2.fromOffset(0, 286), Size = UDim2.new(1, 0, 0, 24), Text = "Laufende Aufträge", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = ordersContent })
local activeList = UI.scroll(ordersContent, { Position = UDim2.fromOffset(0, 314), Size = UDim2.new(1, 0, 1, -314), ZIndex = 11 })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = activeList })

---------------------------------------------------------------- Fenster: Bauen
local buildPanel, buildContent = UI.panel(gui, "🔨 BAUEN", Vector2.new(660, 520))
local tabs = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 11, Parent = buildContent }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local itemGrid = UI.scroll(buildContent, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), ZIndex = 11 })
new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 186), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = itemGrid })

---------------------------------------------------------------- Fenster: Ausrüstung & Codes
local toolsPanel, toolsContent = UI.panel(gui, "🛠 AUSRÜSTUNG", Vector2.new(480, 320))
local toolCurrent = label({ Size = UDim2.new(1, 0, 0, 34), Text = "", ZIndex = 11, Parent = toolsContent })
local toolNext = label({ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 28), Text = "", TextColor3 = Color3.fromRGB(190, 190, 220), ZIndex = 11, Parent = toolsContent })
local toolBuy = button("Kaufen", UI.GREEN, { Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 58), ZIndex = 11, Parent = toolsContent })
label({ Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 50), Text = "Mehr tragen = weniger laufen!\nSpäter übernehmen Gabelstapler die Arbeit.", TextColor3 = Color3.fromRGB(190, 190, 220), ZIndex = 11, Parent = toolsContent })

local codesPanel, codesContent = UI.panel(gui, "🎟 CODES", Vector2.new(460, 260))
local codeBox = new("TextBox", {
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundColor3 = UI.WHITE,
	TextColor3 = UI.DARK,
	PlaceholderText = "Code eingeben…",
	Text = "",
	Font = UI.FONT,
	TextScaled = true,
	ClearTextOnFocus = false,
	ZIndex = 11,
	Parent = codesContent,
}, { UI.corner(12), UI.stroke(3) })
local redeemBtn = button("Einlösen", Color3.fromRGB(255, 90, 140), { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 54), ZIndex = 11, Parent = codesContent })
label({ Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 24), Text = "Neue Codes gibt's auf unserem TikTok! 👀", TextColor3 = Color3.fromRGB(190, 190, 220), ZIndex = 11, Parent = codesContent })

---------------------------------------------------------------- Hilfsfunktionen
local function timeLeft(o)
	if not o.Arrived then
		return o.TimeLeft
	end
	return o.TimeLeft - (os.clock() - stateAt)
end

local function kindText(kind)
	if kind == "In" then
		return "⬇ WARENEINGANG", Color3.fromRGB(110, 220, 255)
	end
	return "⬆ WARENAUSGANG", Color3.fromRGB(255, 170, 70)
end

local function clearList(list)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function progressBar(parent, pos, size, frac, color)
	local bg = new("Frame", { Position = pos, Size = size, BackgroundColor3 = UI.DARK, ZIndex = 12, Parent = parent }, { UI.corner(8) })
	new("Frame", { Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1), BackgroundColor3 = color, ZIndex = 13, Parent = bg }, { UI.corner(8) })
	return bg
end

---------------------------------------------------------------- Rendern
local function renderOrders()
	if not state then
		return
	end
	clearList(offersList)
	for i, o in ipairs(state.Offers) do
		local g = Config.GoodsById[o.Goods]
		local head, headColor = kindText(o.Kind)
		local card = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 92), BackgroundColor3 = UI.CARD, ZIndex = 11, Parent = offersList }, { UI.corner(12) })
		label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.62, 0, 0, 24), Text = head, TextColor3 = headColor, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = card })
		label({ Position = UDim2.fromOffset(12, 32), Size = UDim2.new(0.62, 0, 0, 24), Text = string.format("%s %d× %s  •  %s", g.Icon, o.Amount, g.Name, o.Client), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = card })
		local detail = string.format("⏱ %s Zeit  •  läuft ab in %s", Config.FormatTime(o.Time), Config.FormatTime(o.ExpiresIn - (os.clock() - stateAt)))
		local detailColor = Color3.fromRGB(190, 190, 220)
		if o.Kind == "Out" then
			local have = state.Stock[o.Goods] or 0
			detail = string.format("Auf Lager: %d / %d  •  ⏱ %s", have, o.Amount, Config.FormatTime(o.Time))
			if have < o.Amount then
				detailColor = Color3.fromRGB(255, 120, 120)
			end
		elseif state.Capacity - state.Used < o.Amount then
			detail ..= "  •  ⚠ wenig Platz!"
			detailColor = Color3.fromRGB(255, 200, 120)
		end
		label({ Position = UDim2.fromOffset(12, 60), Size = UDim2.new(0.62, 0, 0, 20), Text = detail, TextColor3 = detailColor, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = card })
		label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(170, 32), Text = "💰 +" .. fmt(o.Reward), TextColor3 = UI.YELLOW, ZIndex = 12, Parent = card })
		local accept = button(state.FreeDocks > 0 and "Annehmen" or "Rampe belegt", state.FreeDocks > 0 and UI.GREEN or UI.GRAY, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 44),
			Size = UDim2.fromOffset(170, 40),
			ZIndex = 12,
			Parent = card,
		})
		accept.Activated:Connect(function()
			UI.bounce(accept)
			R.AcceptOrder:FireServer(o.Id)
		end)
	end

	clearList(activeList)
	if #state.Active == 0 then
		label({ Size = UDim2.new(1, -12, 0, 30), Text = "Keine laufenden Aufträge", TextColor3 = Color3.fromRGB(160, 160, 180), ZIndex = 12, Parent = activeList })
	end
	for i, o in ipairs(state.Active) do
		local g = Config.GoodsById[o.Goods]
		local head, headColor = kindText(o.Kind)
		local card = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 64), BackgroundColor3 = UI.CARD, ZIndex = 11, Parent = activeList }, { UI.corner(12) })
		local status = o.Arrived and ("⏱ " .. Config.FormatTime(timeLeft(o))) or "🚚 unterwegs"
		label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -140, 0, 24), Text = string.format("%s  %s %d/%d  %s", head, g.Icon, o.Done, o.Amount, status), TextColor3 = headColor, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = card })
		progressBar(card, UDim2.fromOffset(12, 38), UDim2.new(1, -140, 0, 16), o.Done / o.Amount, headColor)
		local cancel = button("Abbrechen", UI.RED, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 40), ZIndex = 12, Parent = card })
		cancel.Activated:Connect(function()
			R.CancelOrder:FireServer(o.Id)
		end)
	end
end

local function renderTracker()
	clearList(tracker)
	if not state then
		return
	end
	for i, o in ipairs(state.Active) do
		local g = Config.GoodsById[o.Goods]
		local _, color = kindText(o.Kind)
		local card = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.15, Parent = tracker }, { UI.corner(12), UI.stroke(2) })
		local left = timeLeft(o)
		local status = o.Arrived and ("⏱ " .. Config.FormatTime(left)) or "🚚 unterwegs"
		label({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 26),
			Text = string.format("%s %s %d/%d   %s", o.Kind == "In" and "⬇" or "⬆", g.Icon, o.Done, o.Amount, status),
			TextColor3 = (o.Arrived and left < 20) and Color3.fromRGB(255, 90, 90) or UI.WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		progressBar(card, UDim2.fromOffset(10, 34), UDim2.new(1, -20, 0, 14), o.Done / o.Amount, color)
	end
end

-- Bau-Menü: Karten mit 3D-Vorschau (werden einmal erstellt)
local itemCards = {}
local currentTab = Items.Categories[1]
local tabButtons = {}

local function makePreview(parent, def)
	local vp = new("ViewportFrame", {
		Position = UDim2.fromOffset(6, 30),
		Size = UDim2.new(1, -12, 0, 86),
		BackgroundColor3 = Color3.fromRGB(70, 75, 100),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightDirection = Vector3.new(-1, -2, -1),
		ZIndex = 12,
		Parent = parent,
	}, { UI.corner(10) })
	local model = Items.Build(def, { OwnerName = player.DisplayName })
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = new("Camera", { FieldOfView = 40, Parent = vp })
	local dist = size.Magnitude * 1.25 + 2
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.6, dist * 0.55, -dist * 0.7), cf.Position)
	vp.CurrentCamera = cam
end

local function buildItemCards()
	for _, def in ipairs(Items.List) do
		local card = new("TextButton", { Text = "", LayoutOrder = def.Order, BackgroundColor3 = UI.CARD, AutoButtonColor = true, ZIndex = 11, Parent = itemGrid }, { UI.corner(12), UI.stroke(2) })
		label({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 24), Text = def.Name, ZIndex = 12, Parent = card })
		makePreview(card, def)
		label({ Position = UDim2.fromOffset(6, 120), Size = UDim2.new(1, -12, 0, 32), Text = def.Desc or "", TextWrapped = true, TextColor3 = Color3.fromRGB(190, 190, 220), ZIndex = 12, Parent = card })
		local price = label({ Position = UDim2.fromOffset(6, 154), Size = UDim2.new(1, -12, 0, 26), Text = "", ZIndex = 12, Parent = card })
		card.Activated:Connect(function()
			if state and state.Level < def.Level then
				UI.toast("🔒 Ab Level " .. def.Level, "bad")
				return
			end
			UI.closePanels()
			BuildMode.StartPlace(def.Id)
		end)
		itemCards[def.Id] = { Card = card, Price = price, Def = def }
	end
end

local function renderBuild()
	for _, b in pairs(tabButtons) do
		b.BackgroundColor3 = b.Name == currentTab and UI.BLUE or UI.GRAY
	end
	for _, c in pairs(itemCards) do
		local def = c.Def
		c.Card.Visible = def.Cat == currentTab
		if state then
			if state.Level < def.Level then
				c.Price.Text = "🔒 Level " .. def.Level
				c.Price.TextColor3 = Color3.fromRGB(200, 200, 200)
			else
				c.Price.Text = "💰 " .. fmt(def.Price)
				c.Price.TextColor3 = state.Coins >= def.Price and UI.YELLOW or Color3.fromRGB(255, 110, 110)
			end
		end
	end
end

for i, cat in ipairs(Items.Categories) do
	local b = button(cat, UI.GRAY, { Name = cat, LayoutOrder = i, Size = UDim2.fromOffset(148, 42), ZIndex = 12, Parent = tabs })
	b.Activated:Connect(function()
		currentTab = cat
		renderBuild()
	end)
	tabButtons[cat] = b
end
buildItemCards()

local function renderTools()
	if not state then
		return
	end
	local t, nt = Config.Tools[state.Tool], Config.Tools[state.Tool + 1]
	toolCurrent.Text = string.format("🛠 %s – trägt %d Kiste%s", t.Name, t.Carry, t.Carry == 1 and "" or "n")
	if nt then
		toolNext.Text = string.format("Nächste: %s – trägt %d Kisten", nt.Name, nt.Carry)
		if state.Level < nt.Level then
			toolBuy.Text = "🔒 Ab Level " .. nt.Level
			toolBuy.BackgroundColor3 = UI.GRAY
		else
			toolBuy.Text = "Kaufen – " .. fmt(nt.Price) .. " 💰"
			toolBuy.BackgroundColor3 = state.Coins >= nt.Price and UI.GREEN or UI.GRAY
		end
	else
		toolNext.Text = "Du hast die beste Ausrüstung! 😎"
		toolBuy.Text = "MAX"
		toolBuy.BackgroundColor3 = UI.GRAY
	end
end

local function hintText()
	if not state then
		return ""
	end
	if state.PlotIndex == 0 then
		return "Server voll – kein Grundstück frei."
	end
	if state.OrdersDone < 3 then
		local a = state.Active[1]
		local carrying = state.Carry.Count > 0
		if not a then
			return "👉 Öffne 📋 Aufträge und nimm einen Auftrag an!"
		elseif not a.Arrived then
			return "🚚 Der LKW fährt gerade zu deiner Laderampe…"
		elseif a.Kind == "In" then
			return carrying and "👉 Bring die Kisten zu einem Regal und drücke E (Einlagern)" or "👉 Geh hinten an den LKW und drücke E (Entladen)"
		else
			return carrying and "👉 Bring die Kisten zum LKW und drücke E (Beladen)" or "👉 Hol die Ware aus einem Regal: F (Auslagern)"
		end
	end
	if state.Capacity > 0 and state.Used >= state.Capacity then
		return "📦 Lager voll! Bau mehr Regale (🔨 Bauen → Lager)"
	end
	return ""
end

local function renderHUD()
	coinsLabel.Text = "💰 " .. fmt(state.Coins)
	levelFill.Size = UDim2.fromScale(math.clamp(state.XP / state.XPNeed, 0, 1), 1)
	levelText.Text = string.format("⭐ Level %d  •  %s / %s XP", state.Level, fmt(state.XP), fmt(state.XPNeed))
	infoLabel.Text = string.format("📦 Lager %s/%s   🚚 Rampen frei: %d/%d", fmt(state.Used), fmt(state.Capacity), state.FreeDocks, state.Docks)
	hintLabel.Text = hintText()

	local c = state.Carry
	if c.Count > 0 and not BuildMode.Mode() then
		local g = Config.GoodsById[c.Goods]
		carryLabel.Text = string.format("🤲 %d/%d  %s %s", c.Count, state.CarryMax, g and g.Icon or "📦", g and g.Name or "")
		carryFrame.Visible = true
	else
		carryFrame.Visible = false
	end
end

local function applyState(s)
	state = s
	stateAt = os.clock()
	renderHUD()
	renderTracker()
	if ordersPanel.Visible then
		renderOrders()
	end
	if buildPanel.Visible then
		renderBuild()
	end
	if toolsPanel.Visible then
		renderTools()
	end
end

R.State.OnClientEvent:Connect(applyState)
R.Notify.OnClientEvent:Connect(UI.toast)

-- Countdown-Anzeigen jede Sekunde auffrischen
task.spawn(function()
	while true do
		task.wait(1)
		if state then
			renderTracker()
			if ordersPanel.Visible then
				renderOrders()
			end
		end
	end
end)

---------------------------------------------------------------- Bau-Modus anbinden
BuildMode.Init({
	R = R,
	getState = function()
		return state
	end,
	toast = UI.toast,
	onInfo = function(text, reason)
		buildInfo.Text = text
		buildReason.Text = reason or ""
	end,
	onChanged = function(mode)
		buildBar.Visible = mode ~= nil
		rotateBtn.Visible = mode == "place"
		confirmBtn.Visible = mode == "place"
		deleteBtn.Text = mode == "delete" and "✖ Stopp" or "🗑 Abreißen"
		expandBtn.Text = mode == "expand" and "✖ Stopp" or "🧱 Erweitern"
		pcall(function()
			ProximityPromptService.Enabled = mode == nil
		end)
		if mode then
			UI.closePanels()
		end
		if state then
			renderHUD()
		end
	end,
})

rotateBtn.Activated:Connect(function()
	UI.bounce(rotateBtn)
	BuildMode.Rotate()
end)
confirmBtn.Activated:Connect(function()
	UI.bounce(confirmBtn)
	BuildMode.Confirm()
end)
doneBtn.Activated:Connect(function()
	BuildMode.Stop()
end)

---------------------------------------------------------------- Menü-Buttons
ordersBtn.Activated:Connect(function()
	UI.bounce(ordersBtn)
	BuildMode.Stop()
	UI.toggle(ordersPanel)
	renderOrders()
end)
buildBtn.Activated:Connect(function()
	UI.bounce(buildBtn)
	BuildMode.Stop()
	UI.toggle(buildPanel)
	renderBuild()
end)
expandBtn.Activated:Connect(function()
	UI.bounce(expandBtn)
	if BuildMode.Mode() == "expand" then
		BuildMode.Stop()
	else
		BuildMode.StartExpand()
	end
end)
deleteBtn.Activated:Connect(function()
	UI.bounce(deleteBtn)
	if BuildMode.Mode() == "delete" then
		BuildMode.Stop()
	else
		BuildMode.StartDelete()
	end
end)
toolsBtn.Activated:Connect(function()
	UI.bounce(toolsBtn)
	BuildMode.Stop()
	UI.toggle(toolsPanel)
	renderTools()
end)
codesBtn.Activated:Connect(function()
	UI.bounce(codesBtn)
	BuildMode.Stop()
	UI.toggle(codesPanel)
end)
toolBuy.Activated:Connect(function()
	UI.bounce(toolBuy)
	R.BuyTool:FireServer()
end)
redeemBtn.Activated:Connect(function()
	UI.bounce(redeemBtn)
	R.Redeem:FireServer(codeBox.Text)
	codeBox.Text = ""
end)
dropBtn.Activated:Connect(function()
	R.Drop:FireServer()
end)

---------------------------------------------------------------- Prompts fremder Lager ausblenden
local function checkPrompt(p)
	if p:IsA("ProximityPrompt") then
		local owner = p:GetAttribute("OwnerId")
		if owner and owner ~= player.UserId then
			p.Enabled = false
		end
	end
end
local plotsFolder = workspace:WaitForChild("Plots")
for _, d in ipairs(plotsFolder:GetDescendants()) do
	checkPrompt(d)
end
plotsFolder.DescendantAdded:Connect(checkPrompt)

---------------------------------------------------------------- Start
local function hookCamera()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(UI.updateScale)
	end
	UI.updateScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
hookCamera()

R.RequestState:FireServer()
