-- Pump & Fly – Client: komplette UI per Code, Steuerung, Flug-Animation
-- PC: E gedrückt halten = pumpen, F = starten. Handy: Buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local R = {}
for _, name in ipairs({ "Pump", "Launch", "Buy", "Rebirth", "Redeem", "ClaimGift", "RequestState", "State", "Flight", "FlightEnd", "Notify" }) do
	R[name] = remotes:WaitForChild(name)
end

local player = Players.LocalPlayer
local fmt = Config.Format
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(30, 30, 45)

---------------------------------------------------------------- UI-Helfer
local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

local function stroke(thickness, color)
	return new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Color3.new(0, 0, 0),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.3
	return new("TextLabel", props)
end

local function button(text, color, props)
	props.Text = text
	props.BackgroundColor3 = color
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = WHITE
	props.TextStrokeTransparency = 0.3
	props.AutoButtonColor = true
	local b = new("TextButton", props, {
		corner(14),
		stroke(3),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	new("UIScale", { Name = "Bounce", Parent = b })
	return b
end

local function bounce(gui)
	local s = gui:FindFirstChild("Bounce")
	if s then
		s.Scale = 0.88
		TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local gui = new("ScreenGui", {
	Name = "PumpFlyUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Skaliert alle Bereiche passend zur Bildschirmgröße (Handy + PC)
local scalers = {}
local function scaled(frame)
	table.insert(scalers, new("UIScale", { Parent = frame }))
	return frame
end
local function updateScale()
	local cam = workspace.CurrentCamera
	local scale = cam and math.clamp(cam.ViewportSize.Y / 760, 0.5, 1.2) or 1
	for _, s in ipairs(scalers) do
		s.Scale = scale
	end
end

---------------------------------------------------------------- Oben: Münzen + Infos
local top = scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(460, 90),
	BackgroundTransparency = 1,
	Parent = gui,
}))
local coinsLabel = label({
	Size = UDim2.new(1, 0, 0, 56),
	Text = "💰 0",
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextStrokeTransparency = 0,
	Parent = top,
})
local infoLabel = label({
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 0, 26),
	Text = "",
	Parent = top,
})

---------------------------------------------------------------- Unten: Luft-Balken + Pumpen/Starten
local bottom = scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(400, 190),
	BackgroundTransparency = 1,
	Parent = gui,
}))

local warnLabel = label({
	Size = UDim2.new(1, 0, 0, 26),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 80, 80),
	TextStrokeTransparency = 0,
	Parent = bottom,
})

local airBar = new("Frame", {
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundColor3 = DARK,
	Parent = bottom,
}, { corner(12), stroke(3) })
local airFill = new("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(90, 220, 90),
	Parent = airBar,
}, { corner(12) })
local airText = label({
	Size = UDim2.fromScale(1, 1),
	Text = "🎈 Luft: 0 / 20",
	ZIndex = 2,
	Parent = airBar,
})

local pumpButton = button("🎈 PUMPEN", Color3.fromRGB(60, 190, 90), {
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.fromOffset(192, 84),
	Parent = bottom,
})
local launchButton = button("🚀 STARTEN", Color3.fromRGB(255, 140, 30), {
	Position = UDim2.fromOffset(208, 80),
	Size = UDim2.fromOffset(192, 84),
	Parent = bottom,
})
label({
	Position = UDim2.fromOffset(0, 168),
	Size = UDim2.new(1, 0, 0, 20),
	Text = UserInputService.TouchEnabled and "PUMPEN gedrückt halten!" or "E halten = Pumpen   •   F = Starten",
	TextTransparency = 0.2,
	Parent = bottom,
})

---------------------------------------------------------------- Links: Menü
local menu = scaled(new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(150, 330),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
}))
local function menuButton(text, color, order)
	return button(text, color, { Size = UDim2.fromOffset(150, 56), LayoutOrder = order, Parent = menu })
end
local shopBtn = menuButton("🛒 Shop", Color3.fromRGB(60, 140, 255), 1)
local rebirthBtn = menuButton("🌟 Rebirth", Color3.fromRGB(200, 80, 255), 2)
local codesBtn = menuButton("🎟 Codes", Color3.fromRGB(255, 90, 140), 3)
local giftBtn = menuButton("🎁 Geschenk", Color3.fromRGB(40, 200, 180), 4)
local passBtn = menuButton("💎 2x Münzen", Color3.fromRGB(255, 190, 0), 5)
passBtn.Visible = Config.GamePasses.DoubleCoins ~= 0

---------------------------------------------------------------- Fenster (Shop, Rebirth, Codes)
local panels = {}
local function panel(title, height)
	local frame = scaled(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, height),
		BackgroundColor3 = DARK,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}, { corner(18), stroke(4) }))
	label({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 44), Text = title, ZIndex = 6, Parent = frame })
	local close = button("X", Color3.fromRGB(230, 60, 60), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 6,
		Parent = frame,
	})
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local content = new("Frame", {
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = frame,
	})
	table.insert(panels, frame)
	return frame, content
end

local function toggle(frame)
	local show = not frame.Visible
	for _, p in ipairs(panels) do
		p.Visible = false
	end
	frame.Visible = show
end

-- Shop
local shopPanel, shopContent = panel("🛒 SHOP", 360)
local function shopRow(y, buyText)
	local row = new("Frame", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = Color3.fromRGB(50, 50, 75),
		ZIndex = 6,
		Parent = shopContent,
	}, { corner(14) })
	local current = label({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = row })
	local nextL = label({ Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 190, 220), ZIndex = 7, Parent = row })
	local buy = button(buyText, Color3.fromRGB(60, 190, 90), { Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 0, 46), ZIndex = 7, Parent = row })
	return current, nextL, buy
end
local balloonCurrent, balloonNext, buyBalloon = shopRow(0, "Kaufen")
local pumpCurrent, pumpNext, buyPump = shopRow(144, "Kaufen")

-- Rebirth
local rebirthPanel, rebirthContent = panel("🌟 REBIRTH", 300)
local rebirthInfo = label({
	Size = UDim2.new(1, 0, 0, 140),
	TextScaled = true,
	TextWrapped = true,
	ZIndex = 7,
	Parent = rebirthContent,
})
local doRebirth = button("REBIRTH!", Color3.fromRGB(200, 80, 255), { Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 60), ZIndex = 7, Parent = rebirthContent })

-- Codes
local codesPanel, codesContent = panel("🎟 CODES", 250)
local codeBox = new("TextBox", {
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundColor3 = WHITE,
	TextColor3 = DARK,
	PlaceholderText = "Code eingeben…",
	Text = "",
	Font = FONT,
	TextScaled = true,
	ClearTextOnFocus = false,
	ZIndex = 7,
	Parent = codesContent,
}, { corner(12), stroke(3) })
local redeemBtn = button("Einlösen", Color3.fromRGB(255, 90, 140), { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 56), ZIndex = 7, Parent = codesContent })
label({ Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 0, 24), Text = "Neue Codes gibt's auf unserem TikTok! 👀", TextColor3 = Color3.fromRGB(190, 190, 220), ZIndex = 7, Parent = codesContent })

---------------------------------------------------------------- Benachrichtigungen + Flug-Anzeige
local toastHolder = scaled(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 105),
	Size = UDim2.fromOffset(560, 220),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
}))

local toastColors = {
	good = Color3.fromRGB(90, 230, 110),
	bad = Color3.fromRGB(255, 90, 90),
	record = Color3.fromRGB(255, 215, 60),
	info = WHITE,
}
local toastCount = 0
local function toast(text, kind)
	toastCount += 1
	local t = label({
		Size = UDim2.new(1, 0, 0, kind == "record" and 46 or 34),
		Text = text,
		TextColor3 = toastColors[kind] or WHITE,
		TextStrokeTransparency = 0,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	})
	local items = toastHolder:GetChildren()
	if #items > 6 then
		for _, c in ipairs(items) do
			if c:IsA("TextLabel") then
				c:Destroy()
				break
			end
		end
	end
	task.delay(2.5, function()
		if t.Parent then
			local tween = TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			t:Destroy()
		end
	end)
end

local flightLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromScale(0.6, 0.12),
	Text = "",
	TextStrokeTransparency = 0,
	Visible = false,
	Parent = gui,
})

---------------------------------------------------------------- Zustand vom Server anzeigen
local state
local giftReadyAt = 0

local function applyState(s)
	state = s
	coinsLabel.Text = "💰 " .. fmt(s.Coins)

	local info = string.format("⚡ x%s Boost   🏆 Rekord: %s Studs", Config.FormatMult(s.Multiplier), fmt(s.BestHeight))
	if s.FriendBoost > 0 then
		info ..= string.format("   👥 +%d%%", math.floor(s.FriendBoost * 100 + 0.5))
	end
	infoLabel.Text = info

	local fill = math.clamp(s.Air / s.Capacity, 0, 1)
	TweenService:Create(airFill, TweenInfo.new(0.12), {
		Size = UDim2.new(fill, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(90, 220, 90):Lerp(Color3.fromRGB(255, 50, 50), fill),
	}):Play()
	airText.Text = string.format("🎈 Luft: %s / %s   →  %s Studs", fmt(s.Air), fmt(s.Capacity), fmt(s.Air * Config.LiftPerAir))
	if fill >= 0.85 then
		warnLabel.Text = "⚠ GLEICH PLATZT ES! ⚠"
	elseif fill >= 0.65 then
		warnLabel.Text = "Riskant… 😬"
	else
		warnLabel.Text = ""
	end

	local canLaunch = s.Air >= Config.LaunchMinAir and not s.Flying
	launchButton.BackgroundColor3 = canLaunch and Color3.fromRGB(255, 140, 30) or Color3.fromRGB(120, 120, 120)

	-- Shop
	local b, nb = Config.Balloons[s.Balloon], Config.Balloons[s.Balloon + 1]
	balloonCurrent.Text = string.format("🎈 %s (%s Luft)", b.Name, fmt(b.Capacity))
	balloonNext.Text = nb and string.format("Nächster: %s (%s Luft)", nb.Name, fmt(nb.Capacity)) or "MAX erreicht!"
	buyBalloon.Text = nb and ("Kaufen – " .. fmt(nb.Price) .. " 💰") or "MAX"
	buyBalloon.BackgroundColor3 = (nb and s.Coins >= nb.Price) and Color3.fromRGB(60, 190, 90) or Color3.fromRGB(110, 110, 110)

	local p, np = Config.Pumps[s.Pump], Config.Pumps[s.Pump + 1]
	pumpCurrent.Text = string.format("💨 %s (%s pro Pump)", p.Name, fmt(p.Power))
	pumpNext.Text = np and string.format("Nächste: %s (%s pro Pump)", np.Name, fmt(np.Power)) or "MAX erreicht!"
	buyPump.Text = np and ("Kaufen – " .. fmt(np.Price) .. " 💰") or "MAX"
	buyPump.BackgroundColor3 = (np and s.Coins >= np.Price) and Color3.fromRGB(60, 190, 90) or Color3.fromRGB(110, 110, 110)

	-- Rebirth
	local cost = Config.RebirthCost(s.Rebirths)
	local nextMult = 1 + (s.Rebirths + 1) * Config.RebirthBonus
	rebirthInfo.Text = string.format(
		"Rebirths: %d\nSetzt Münzen, Ballon & Pumpe zurück.\nDafür DAUERHAFT x%s Münzen!\nKosten: %s 💰",
		s.Rebirths,
		Config.FormatMult(nextMult),
		fmt(cost)
	)
	doRebirth.BackgroundColor3 = s.Coins >= cost and Color3.fromRGB(200, 80, 255) or Color3.fromRGB(110, 110, 110)

	giftReadyAt = os.clock() + s.GiftIn
	passBtn.Text = s.HasDouble and "💎 2x AKTIV" or "💎 2x Münzen"
end

R.State.OnClientEvent:Connect(applyState)
R.Notify.OnClientEvent:Connect(toast)

-- Geschenk-Countdown
task.spawn(function()
	while true do
		local left = math.max(0, math.ceil(giftReadyAt - os.clock()))
		if left == 0 then
			giftBtn.Text = "🎁 ABHOLEN!"
		else
			giftBtn.Text = string.format("🎁 %d:%02d", left // 60, left % 60)
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Pumpen (gedrückt halten)
local holding = false
local function startPumping()
	if holding then
		return
	end
	holding = true
	task.spawn(function()
		while holding do
			if state and not state.Flying then
				R.Pump:FireServer()
				bounce(pumpButton)
			end
			task.wait(0.1)
		end
	end)
end
local function stopPumping()
	holding = false
end

local function launch()
	if state and not state.Flying then
		stopPumping()
		bounce(launchButton)
		R.Launch:FireServer()
	end
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

pumpButton.InputBegan:Connect(function(input)
	if isPress(input) then
		startPumping()
	end
end)
launchButton.Activated:Connect(launch)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		startPumping()
	elseif input.KeyCode == Enum.KeyCode.F then
		launch()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if isPress(input) or input.KeyCode == Enum.KeyCode.E then
		stopPumping()
	end
end)

---------------------------------------------------------------- Menü-Buttons
shopBtn.Activated:Connect(function()
	bounce(shopBtn)
	toggle(shopPanel)
end)
rebirthBtn.Activated:Connect(function()
	bounce(rebirthBtn)
	toggle(rebirthPanel)
end)
codesBtn.Activated:Connect(function()
	bounce(codesBtn)
	toggle(codesPanel)
end)
giftBtn.Activated:Connect(function()
	bounce(giftBtn)
	R.ClaimGift:FireServer()
end)
passBtn.Activated:Connect(function()
	bounce(passBtn)
	if Config.GamePasses.DoubleCoins ~= 0 and not (state and state.HasDouble) then
		MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.DoubleCoins)
	end
end)

buyBalloon.Activated:Connect(function()
	bounce(buyBalloon)
	R.Buy:FireServer("Balloon")
end)
buyPump.Activated:Connect(function()
	bounce(buyPump)
	R.Buy:FireServer("Pump")
end)
doRebirth.Activated:Connect(function()
	bounce(doRebirth)
	R.Rebirth:FireServer()
end)
redeemBtn.Activated:Connect(function()
	bounce(redeemBtn)
	R.Redeem:FireServer(codeBox.Text)
	codeBox.Text = ""
end)

---------------------------------------------------------------- Flug (rein optisch – Belohnung berechnet der Server)
local flight

local function endFlight()
	if flight then
		flight.conn:Disconnect()
		flight.align:Destroy()
		flight.attachment:Destroy()
		flight = nil
	end
	flightLabel.Visible = false
end

R.Flight.OnClientEvent:Connect(function(height, duration)
	endFlight()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	stopPumping()

	local attachment = new("Attachment", { Parent = root })
	local align = new("AlignPosition", {
		Mode = Enum.PositionAlignmentMode.OneAttachment,
		Attachment0 = attachment,
		MaxForce = 1e9,
		MaxVelocity = 1e6,
		Responsiveness = 120,
		Position = root.Position,
		Parent = root,
	})

	local start = root.Position
	local t0 = os.clock()
	local lastZone
	flightLabel.Visible = true
	local conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		local y = height * (1 - (1 - a) ^ 3)
		align.Position = start + Vector3.new(0, y, 0)
		local zone = Config.GetZone(y)
		flightLabel.Text = string.format("⬆ %s Studs\n%s %s", fmt(y), zone.Icon, zone.Name)
		flightLabel.TextColor3 = zone.Color
		if zone ~= lastZone then
			if lastZone then
				toast(string.format("%s %s erreicht! x%s", zone.Icon, zone.Name, Config.FormatMult(zone.Multiplier)), "record")
			end
			lastZone = zone
		end
	end)
	flight = { conn = conn, align = align, attachment = attachment }
end)

R.FlightEnd.OnClientEvent:Connect(function(spawnCFrame)
	endFlight()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		char:PivotTo(spawnCFrame)
	end
end)

player.CharacterAdded:Connect(function()
	endFlight()
	stopPumping()
end)

---------------------------------------------------------------- Start
local function hookCamera()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
hookCamera()

R.RequestState:FireServer()
