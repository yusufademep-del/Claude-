-- Lager-Imperium – LKW-Modell + Fahrten (anfahren, rückwärts an die Rampe, abfahren)

local TweenService = game:GetService("TweenService")

local Trucks = {}

local SPEED = 45 -- Studs pro Sekunde auf der Straße
local LANE_Z = -32 -- Fahrspur (relativ zum Grundstück)
local PARK_Z = -15 -- Mitte des LKWs, wenn er an der Rampe steht
local ROAD_END = 140

local CAB_COLORS = {
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(40, 110, 220),
	Color3.fromRGB(250, 170, 20),
	Color3.fromRGB(40, 170, 90),
	Color3.fromRGB(130, 70, 200),
	Color3.fromRGB(240, 240, 240),
}

local function add(model, name, size, pos, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = model
	return p
end

-- LKW zeigt mit der Front nach -Z, Heck (Ladetür) bei +Z
function Trucks.Build(stripeColor, title)
	local m = Instance.new("Model")
	m.Name = "Truck"
	local root = add(m, "Root", Vector3.new(1, 1, 1), Vector3.zero, Color3.new(), nil, { Transparency = 1 })
	m.PrimaryPart = root

	local cab = CAB_COLORS[math.random(1, #CAB_COLORS)]
	add(m, "Chassis", Vector3.new(6, 1, 28), Vector3.new(0, 1.6, 0), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	add(m, "Cab", Vector3.new(7, 7, 6), Vector3.new(0, 4.6, -11.5), cab, Enum.Material.SmoothPlastic)
	add(m, "CabTop", Vector3.new(7, 1.5, 4), Vector3.new(0, 8.8, -10.5), cab, Enum.Material.SmoothPlastic)
	add(m, "Windshield", Vector3.new(6.2, 2.8, 0.2), Vector3.new(0, 6.1, -14.55), Color3.fromRGB(30, 40, 60), Enum.Material.Glass, { Transparency = 0.2 })
	add(m, "Bumper", Vector3.new(7.2, 1, 0.6), Vector3.new(0, 1.5, -14.7), Color3.fromRGB(120, 120, 125), Enum.Material.Metal)
	for _, x in ipairs({ -2.6, 2.6 }) do
		add(m, "Headlight", Vector3.new(1.1, 0.6, 0.1), Vector3.new(x, 2.7, -14.6), Color3.fromRGB(255, 250, 210), Enum.Material.Neon)
	end

	local trailer = add(m, "Trailer", Vector3.new(8, 9, 22), Vector3.new(0, 6.6, 3.5), Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -4.05, 4.05 }) do
		add(m, "Stripe", Vector3.new(0.1, 1.4, 20), Vector3.new(x, 5, 3.5), stripeColor, Enum.Material.SmoothPlastic)
	end
	add(m, "Rear", Vector3.new(7.6, 8.4, 0.2), Vector3.new(0, 6.6, 14.55), Color3.fromRGB(190, 190, 195), Enum.Material.CorrodedMetal)
	for _, x in ipairs({ -3.2, 3.2 }) do
		add(m, "Taillight", Vector3.new(0.8, 0.5, 0.1), Vector3.new(x, 2.4, 14.6), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	end

	for _, z in ipairs({ -11, 6, 9.5, 12.5 }) do
		for _, x in ipairs({ -3.4, 3.4 }) do
			add(m, "Wheel", Vector3.new(1.2, 3, 3), Vector3.new(x, 1.5, z), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		end
	end

	-- Anzeige über dem LKW (Ladung / Zeit)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(14, 0, 4, 0)
	gui.StudsOffset = Vector3.new(0, 7.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = trailer
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = title or ""
	label.Parent = gui

	-- Hier hängt später der „Entladen/Beladen“-Prompt
	local att = Instance.new("Attachment")
	att.Name = "PromptPoint"
	att.Position = Vector3.new(0, -2.5, 1)
	att.Parent = m.Rear

	return m
end

local function moveTo(model, target, duration, style)
	if not model.Parent then
		return
	end
	local cv = Instance.new("CFrameValue")
	cv.Value = model:GetPivot()
	local conn = cv.Changed:Connect(function(v)
		if model.Parent then
			model:PivotTo(v)
		end
	end)
	local tween = TweenService:Create(cv, TweenInfo.new(duration, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = target })
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	cv:Destroy()
end

local FACE_WEST = CFrame.Angles(0, math.rad(90), 0) -- Front zeigt nach -X (Fahrtrichtung)

-- Fährt auf der Straße heran und setzt rückwärts an die Rampe (blockiert, bis er steht)
function Trucks.Arrive(model, origin, dockX)
	local start = origin * CFrame.new(ROAD_END, 0, LANE_Z) * FACE_WEST
	local pass = origin * CFrame.new(dockX - 18, 0, LANE_Z) * FACE_WEST
	local park = origin * CFrame.new(dockX, 0, PARK_Z)
	model:PivotTo(start)
	moveTo(model, pass, math.abs(ROAD_END - (dockX - 18)) / SPEED, Enum.EasingStyle.Quad)
	moveTo(model, park, 2.5)
end

-- Fährt von der Rampe weg und verschwindet
function Trucks.Leave(model, origin, dockX)
	local exit = origin * CFrame.new(dockX - 18, 0, LANE_Z) * FACE_WEST
	local gone = origin * CFrame.new(-ROAD_END, 0, LANE_Z) * FACE_WEST
	moveTo(model, exit, 2.2)
	moveTo(model, gone, math.abs((dockX - 18) + ROAD_END) / SPEED, Enum.EasingStyle.Quad)
	model:Destroy()
end

return Trucks
