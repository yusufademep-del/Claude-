-- Lager-Imperium – alle platzierbaren Objekte (Definition + 3D-Modell aus Parts)
-- Wird vom Server (echte Objekte) und vom Client (durchsichtige Vorschau beim Bauen) benutzt.
--
-- Neues Objekt hinzufügen: Eintrag in Items.List mit Id, Name, Cat, Price, Level, W, D (Größe in Feldern)
-- und einer Build-Funktion. Fertig – es taucht automatisch im Bau-Menü auf.

local Config = require(script.Parent:WaitForChild("Config"))

local Items = {}

Items.Categories = { "Lager", "Technik", "Bau", "Deko" }

local M = Enum.Material
local C = Color3.fromRGB

local function add(model, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = props and props.Parent or model
	return p
end

-- Zylinder stehen in Roblox quer – das hier stellt sie aufrecht
local function cylinder(model, name, height, diameter, pos, color, material)
	return add(model, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, { Shape = Enum.PartType.Cylinder })
end

local function signText(part, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.Parent = gui
	gui.Parent = part
	return l
end

---------------------------------------------------------------- Bau-Funktionen
local function buildShelf(m, def)
	local W, D = def.W * 4, def.D * 4
	local levels, spacing = def.Shelf.Levels, def.Shelf.Spacing
	local levelH = spacing * 0.8 + 1.2
	local H = levels * levelH + 0.6
	local upright, beam = C(40, 90, 200), C(255, 120, 30)

	local nx = math.max(1, math.floor(W / 4))
	for i = 0, nx do
		local x = -W / 2 + 0.2 + i * (W - 0.4) / nx
		for _, z in ipairs({ -D / 2 + 0.2, D / 2 - 0.2 }) do
			add(m, "Post", Vector3.new(0.4, H, 0.4), CFrame.new(x, H / 2, z), upright, M.Metal)
		end
	end

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = m
	local perX = math.max(1, math.floor((W - 0.6) / spacing))
	local perZ = math.max(1, math.floor((D - 0.6) / spacing))
	local box = spacing * 0.8
	local n = 0
	for l = 1, levels do
		local y = (l - 1) * levelH + 0.4
		add(m, "Board", Vector3.new(W - 0.2, 0.2, D - 0.4), CFrame.new(0, y, 0), C(160, 160, 165), M.Metal)
		add(m, "Beam", Vector3.new(W, 0.3, 0.3), CFrame.new(0, y + 0.05, -D / 2 + 0.2), beam, M.Metal)
		add(m, "Beam", Vector3.new(W, 0.3, 0.3), CFrame.new(0, y + 0.05, D / 2 - 0.2), beam, M.Metal)
		for ix = 1, perX do
			for iz = 1, perZ do
				n += 1
				local x = -W / 2 + 0.3 + (ix - 0.5) * (W - 0.6) / perX
				local z = -D / 2 + 0.3 + (iz - 0.5) * (D - 0.6) / perZ
				add(slots, tostring(n), Vector3.new(box, box, box), CFrame.new(x, y + 0.1 + box / 2, z), C(200, 160, 110), M.SmoothPlastic, {
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
					Parent = slots,
				})
			end
		end
	end
	add(m, "Beam", Vector3.new(W, 0.3, 0.3), CFrame.new(0, H, -D / 2 + 0.2), beam, M.Metal)
	add(m, "Beam", Vector3.new(W, 0.3, 0.3), CFrame.new(0, H, D / 2 - 0.2), beam, M.Metal)

	add(m, "Interact", Vector3.new(W, 3, D), CFrame.new(0, 2, 0), C(0, 0, 0), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
end

local function buildDock(m, def)
	local W, D = def.W * 4, def.D * 4
	add(m, "Floor", Vector3.new(W, 0.3, D), CFrame.new(0, 0.15, 0), C(150, 150, 150), M.Concrete)
	for i = 0, 5 do
		add(m, "Stripe", Vector3.new(W / 6, 0.32, 0.6), CFrame.new(-W / 2 + W / 12 + i * W / 6, 0.16, -D / 2 + 0.3), i % 2 == 0 and C(255, 200, 0) or C(30, 30, 30))
	end
	for _, x in ipairs({ -W / 2 + 0.5, W / 2 - 0.5 }) do
		add(m, "Post", Vector3.new(1, 11, 1), CFrame.new(x, 5.5, -D / 2 + 0.5), C(70, 70, 80), M.Metal)
	end
	add(m, "TopBeam", Vector3.new(W, 1.5, 1), CFrame.new(0, 11.75, -D / 2 + 0.5), C(70, 70, 80), M.Metal)
	add(m, "Shutter", Vector3.new(W - 2, 2, 0.6), CFrame.new(0, 10, -D / 2 + 0.5), C(200, 200, 210), M.CorrodedMetal)
	for _, x in ipairs({ -3, 3 }) do
		add(m, "Bumper", Vector3.new(1, 1.2, 0.6), CFrame.new(x, 1.5, -D / 2 - 0.2), C(20, 20, 20), M.SmoothPlastic)
	end
	add(m, "Light", Vector3.new(1.2, 0.6, 0.6), CFrame.new(0, 12.8, -D / 2 + 0.5), C(60, 255, 90), M.Neon)
	signText(add(m, "SignBoard", Vector3.new(6, 1.4, 0.2), CFrame.new(0, 11.75, -D / 2 - 0.05), C(30, 30, 30)), Enum.NormalId.Front, "RAMPE", C(255, 220, 60))
end

local function buildForklift(m, def)
	local W, D = def.W * 4, def.D * 4
	for _, s in ipairs({
		{ Vector3.new(W, 0.12, 0.4), Vector3.new(0, 0.06, -D / 2 + 0.2) },
		{ Vector3.new(W, 0.12, 0.4), Vector3.new(0, 0.06, D / 2 - 0.2) },
		{ Vector3.new(0.4, 0.12, D), Vector3.new(-W / 2 + 0.2, 0.06, 0) },
		{ Vector3.new(0.4, 0.12, D), Vector3.new(W / 2 - 0.2, 0.06, 0) },
	}) do
		add(m, "Marking", s[1], CFrame.new(s[2]), C(255, 200, 0))
	end
	add(m, "Charger", Vector3.new(1, 4, 1), CFrame.new(W / 2 - 1, 2, D / 2 - 1), C(60, 60, 70), M.Metal)
	add(m, "ChargerLight", Vector3.new(0.4, 0.4, 0.2), CFrame.new(W / 2 - 1, 3.4, D / 2 - 1.55), C(60, 255, 90), M.Neon)

	add(m, "Body", Vector3.new(3, 2, 4.5), CFrame.new(0, 1.6, 0.5), C(255, 190, 0), M.SmoothPlastic)
	add(m, "Seat", Vector3.new(1.4, 0.8, 1.2), CFrame.new(0, 3, 1), C(30, 30, 30))
	for _, p in ipairs({ { -1.3, -0.6 }, { 1.3, -0.6 }, { -1.3, 2.4 }, { 1.3, 2.4 } }) do
		add(m, "Cage", Vector3.new(0.2, 3, 0.2), CFrame.new(p[1], 4.1, p[2]), C(30, 30, 30), M.Metal)
	end
	add(m, "Roof", Vector3.new(3, 0.2, 3.4), CFrame.new(0, 5.6, 0.9), C(30, 30, 30), M.Metal)
	for _, x in ipairs({ -0.8, 0.8 }) do
		add(m, "Mast", Vector3.new(0.3, 6, 0.3), CFrame.new(x, 3, -2), C(60, 60, 60), M.Metal)
		add(m, "Fork", Vector3.new(0.4, 0.2, 3), CFrame.new(x, 0.5, -3.5), C(60, 60, 60), M.Metal)
	end
	for _, p in ipairs({ { -1.6, -1 }, { 1.6, -1 }, { -1.6, 2 }, { 1.6, 2 } }) do
		add(m, "Wheel", Vector3.new(0.6, 1.4, 1.4), CFrame.new(p[1], 0.7, p[2]), C(20, 20, 20), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	end
end

local function buildConveyor(m, def)
	local W, D = def.W * 4, def.D * 4
	for _, z in ipairs({ -D / 2 + 1, 0, D / 2 - 1 }) do
		for _, x in ipairs({ -W / 2 + 0.6, W / 2 - 0.6 }) do
			add(m, "Leg", Vector3.new(0.3, 2.3, 0.3), CFrame.new(x, 1.15, z), C(80, 80, 90), M.Metal)
		end
	end
	for _, x in ipairs({ -W / 2 + 0.35, W / 2 - 0.35 }) do
		add(m, "Side", Vector3.new(0.3, 0.7, D), CFrame.new(x, 2.6, 0), C(255, 200, 0), M.Metal)
	end
	add(m, "Belt", Vector3.new(W - 1, 0.3, D), CFrame.new(0, 2.45, 0), C(35, 35, 35), M.SmoothPlastic)
	add(m, "Arrow", Vector3.new(1, 0.05, 2), CFrame.new(0, 2.62, 0), C(255, 255, 255), M.Neon)
end

local function buildPack(m, def)
	add(m, "Table", Vector3.new(7, 0.4, 3.5), CFrame.new(0, 3, 0), C(190, 150, 100), M.Wood)
	for _, p in ipairs({ { -3.2, -1.5 }, { 3.2, -1.5 }, { -3.2, 1.5 }, { 3.2, 1.5 } }) do
		add(m, "Leg", Vector3.new(0.3, 2.8, 0.3), CFrame.new(p[1], 1.4, p[2]), C(80, 80, 90), M.Metal)
	end
	add(m, "Box", Vector3.new(2, 1.5, 1.5), CFrame.new(-1.5, 3.95, 0), C(200, 160, 110))
	add(m, "Box", Vector3.new(1.2, 1, 1.2), CFrame.new(0.5, 3.7, 0.5), C(200, 160, 110))
	add(m, "Monitor", Vector3.new(1.8, 1.2, 0.2), CFrame.new(2.3, 4.2, 1.2), C(20, 20, 30))
	add(m, "Screen", Vector3.new(1.6, 1, 0.05), CFrame.new(2.3, 4.2, 1.08), C(80, 200, 255), M.Neon)
	add(m, "Tape", Vector3.new(0.6, 0.6, 0.6), CFrame.new(1.2, 3.5, -1), C(240, 200, 60))
end

local function buildOffice(m, def)
	local W, D = def.W * 4, def.D * 4
	add(m, "Container", Vector3.new(W - 0.4, 8, D - 0.4), CFrame.new(0, 4, 0), C(40, 110, 200), M.CorrodedMetal)
	add(m, "Roof", Vector3.new(W, 0.4, D), CFrame.new(0, 8.2, 0), C(230, 230, 235), M.Metal)
	for _, x in ipairs({ -3.5, 3.5 }) do
		add(m, "Window", Vector3.new(3, 2.5, 0.2), CFrame.new(x, 5, -D / 2 + 0.15), C(150, 220, 255), M.Glass, { Transparency = 0.3 })
	end
	add(m, "Door", Vector3.new(2.2, 5.5, 0.2), CFrame.new(0, 2.75, -D / 2 + 0.15), C(230, 230, 235), M.Metal)
	signText(add(m, "Sign", Vector3.new(5, 1.2, 0.2), CFrame.new(0, 7.2, -D / 2 + 0.1), C(30, 30, 30)), Enum.NormalId.Front, "BÜRO", C(255, 255, 255))
end

local function buildCoffee(m)
	add(m, "Machine", Vector3.new(2.6, 5.5, 2), CFrame.new(0, 2.75, 0.5), C(130, 30, 40), M.Metal)
	add(m, "Panel", Vector3.new(1.6, 1.6, 0.1), CFrame.new(0, 4, -0.55), C(255, 180, 90), M.Neon)
	add(m, "Slot", Vector3.new(1, 1, 0.3), CFrame.new(0, 1.8, -0.45), C(20, 20, 20))
	cylinder(m, "Cup", 0.5, 0.4, Vector3.new(0, 1.55, -0.4), C(255, 255, 255))
	signText(add(m, "Label", Vector3.new(2.2, 0.6, 0.1), CFrame.new(0, 5, -0.55), C(130, 30, 40)), Enum.NormalId.Front, "☕ KAFFEE", C(255, 255, 255))
end

local function buildWall(m, def)
	local W = def.W * 4
	add(m, "Wall", Vector3.new(W, 12, 1), CFrame.new(0, 6, 0), C(225, 225, 230), M.Metal)
	add(m, "Kick", Vector3.new(W, 1, 1.1), CFrame.new(0, 0.5, 0), C(60, 60, 70), M.Metal)
end

local function buildWindowWall(m, def)
	local W = def.W * 4
	add(m, "Lower", Vector3.new(W, 4, 1), CFrame.new(0, 2, 0), C(225, 225, 230), M.Metal)
	add(m, "Glass", Vector3.new(W, 5, 0.3), CFrame.new(0, 6.5, 0), C(170, 220, 255), M.Glass, { Transparency = 0.5 })
	add(m, "Upper", Vector3.new(W, 3, 1), CFrame.new(0, 10.5, 0), C(225, 225, 230), M.Metal)
end

local function buildGate(m, def)
	local W = def.W * 4
	for _, x in ipairs({ -W / 2 + 0.5, W / 2 - 0.5 }) do
		add(m, "Post", Vector3.new(1, 12, 1), CFrame.new(x, 6, 0), C(60, 60, 70), M.Metal)
		for i = 0, 3 do
			add(m, "Stripe", Vector3.new(1.05, 0.6, 1.05), CFrame.new(x, 0.8 + i * 1.2, 0), C(255, 200, 0))
		end
	end
	add(m, "Housing", Vector3.new(W, 2, 1.6), CFrame.new(0, 11, 0), C(200, 200, 210), M.CorrodedMetal)
	add(m, "Threshold", Vector3.new(W - 2, 0.1, 1), CFrame.new(0, 0.05, 0), C(255, 200, 0), M.SmoothPlastic, { CanCollide = false })
end

local function buildPillar(m)
	add(m, "Steel", Vector3.new(1.5, 14, 1.5), CFrame.new(0, 7, 0), C(90, 90, 100), M.Metal)
	add(m, "Base", Vector3.new(2.4, 1, 2.4), CFrame.new(0, 0.5, 0), C(255, 200, 0))
end

local function floorBuilder(color, material, lines)
	return function(m, def)
		local W, D = def.W * 4, def.D * 4
		add(m, "Floor", Vector3.new(W, 0.2, D), CFrame.new(0, 0.1, 0), color, material)
		if lines then
			for _, x in ipairs({ -W / 2 + 0.4, W / 2 - 0.4 }) do
				add(m, "Line", Vector3.new(0.4, 0.22, D), CFrame.new(x, 0.11, 0), C(255, 200, 0))
			end
		end
	end
end

local function buildPlant(m)
	cylinder(m, "Pot", 2, 2.2, Vector3.new(0, 1, 0), C(180, 90, 50), M.Slate)
	add(m, "Leaves", Vector3.new(3, 3, 3), CFrame.new(0, 3.3, 0), C(60, 160, 60), M.Grass, { Shape = Enum.PartType.Ball })
	add(m, "Leaves", Vector3.new(2, 2, 2), CFrame.new(0.6, 4.6, 0.3), C(80, 180, 70), M.Grass, { Shape = Enum.PartType.Ball })
end

local function buildLamp(m)
	add(m, "Base", Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 0.2, 0), C(40, 40, 45), M.Metal)
	add(m, "Pole", Vector3.new(0.4, 10, 0.4), CFrame.new(0, 5, 0), C(40, 40, 45), M.Metal)
	local head = add(m, "Head", Vector3.new(2.2, 0.6, 2.2), CFrame.new(0, 10.2, 0), C(255, 245, 200), M.Neon)
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.5
	light.Color = C(255, 240, 210)
	light.Parent = head
end

local function buildPallets(m)
	for i = 0, 2 do
		add(m, "Pallet", Vector3.new(3.6, 0.5, 3.6), CFrame.new(0, 0.25 + i * 0.55, 0), C(170, 130, 80), M.WoodPlanks)
	end
	add(m, "Box", Vector3.new(1.6, 1.6, 1.6), CFrame.new(-0.8, 2.5, -0.6), C(200, 160, 110))
	add(m, "Box", Vector3.new(1.4, 1.2, 1.4), CFrame.new(0.9, 2.3, 0.7), C(190, 150, 100))
end

local function buildBarrier(m, def)
	local W = def.W * 4
	for _, x in ipairs({ -W / 2 + 0.5, W / 2 - 0.5 }) do
		add(m, "Post", Vector3.new(0.4, 3.5, 0.4), CFrame.new(x, 1.75, 0), C(255, 200, 0), M.Metal)
	end
	add(m, "Bar", Vector3.new(W - 1, 0.4, 0.3), CFrame.new(0, 3, 0), C(255, 200, 0), M.Metal)
	add(m, "Bar", Vector3.new(W - 1, 0.4, 0.3), CFrame.new(0, 1.8, 0), C(30, 30, 30), M.Metal)
end

local function buildBarrels(m)
	cylinder(m, "Barrel", 3, 1.6, Vector3.new(-0.8, 1.5, -0.7), C(40, 90, 200), M.Metal)
	cylinder(m, "Barrel", 3, 1.6, Vector3.new(0.9, 1.5, -0.5), C(200, 50, 50), M.Metal)
	cylinder(m, "Barrel", 3, 1.6, Vector3.new(0, 1.5, 0.9), C(40, 90, 200), M.Metal)
end

local function buildSign(m, def, ctx)
	local W = def.W * 4
	for _, x in ipairs({ -W / 2 + 0.6, W / 2 - 0.6 }) do
		add(m, "Post", Vector3.new(0.4, 7.5, 0.4), CFrame.new(x, 3.75, 0), C(60, 60, 70), M.Metal)
	end
	local board = add(m, "Board", Vector3.new(W, 3, 0.4), CFrame.new(0, 6.5, 0), C(30, 30, 45))
	local text = "📦 " .. string.upper((ctx and ctx.OwnerName) or "MEIN LAGER")
	signText(board, Enum.NormalId.Front, text, C(255, 210, 60))
	signText(board, Enum.NormalId.Back, text, C(255, 210, 60))
end

---------------------------------------------------------------- Objekt-Liste
-- W/D = Breite/Tiefe in Feldern (1 Feld = 4 Studs). Layer "Floor" darf unter anderen Objekten liegen.
Items.List = {
	-- Lager
	{ Id = "ShelfS", Name = "Kleines Regal", Cat = "Lager", Price = 150, Level = 1, W = 2, D = 1, Capacity = 10, Shelf = { Levels = 3, Spacing = 2 }, Build = buildShelf, Desc = "Platz für 10 Kisten" },
	{ Id = "ShelfM", Name = "Großes Regal", Cat = "Lager", Price = 600, Level = 2, W = 4, D = 1, Capacity = 30, Shelf = { Levels = 3, Spacing = 2 }, Build = buildShelf, Desc = "Platz für 30 Kisten" },
	{ Id = "ShelfL", Name = "Hochregal", Cat = "Lager", Price = 2500, Level = 4, W = 4, D = 2, Capacity = 80, Shelf = { Levels = 4, Spacing = 3 }, Build = buildShelf, Desc = "Platz für 80 Kisten" },
	{ Id = "ShelfXL", Name = "Mega-Hochregal", Cat = "Lager", Price = 9000, Level = 7, W = 6, D = 2, Capacity = 200, Shelf = { Levels = 5, Spacing = 3.5 }, Build = buildShelf, Desc = "Platz für 200 Kisten" },

	-- Technik
	{ Id = "Dock", Name = "Laderampe", Cat = "Technik", Price = 1200, Level = 1, W = 3, D = 2, Dock = true, Build = buildDock, Desc = "Hier docken LKWs an. Nur vorne an der Straße!" },
	{ Id = "Pack", Name = "Packstation", Cat = "Technik", Price = 1500, Level = 2, W = 2, D = 2, Build = buildPack, Desc = "+10 % Belohnung bei Warenausgang" },
	{ Id = "Coffee", Name = "Kaffeeautomat", Cat = "Technik", Price = 800, Level = 2, W = 1, D = 1, Build = buildCoffee, Desc = "Du läufst schneller (+2)" },
	{ Id = "Forklift", Name = "Gabelstapler", Cat = "Technik", Price = 3000, Level = 3, W = 2, D = 2, Build = buildForklift, Desc = "Be- und entlädt LKWs automatisch" },
	{ Id = "Conveyor", Name = "Förderband", Cat = "Technik", Price = 400, Level = 3, W = 1, D = 3, Build = buildConveyor, Desc = "Gabelstapler +10 % schneller. Trägt dich mit!" },
	{ Id = "Office", Name = "Büro-Container", Cat = "Technik", Price = 5000, Level = 5, W = 3, D = 2, Build = buildOffice, Desc = "+1 Auftrag im Angebot, +5 % Belohnung" },

	-- Bau
	{ Id = "Wall", Name = "Wand", Cat = "Bau", Price = 20, Level = 1, W = 2, D = 1, Build = buildWall, Desc = "Baue deine Lagerhalle" },
	{ Id = "WindowWall", Name = "Fensterwand", Cat = "Bau", Price = 40, Level = 1, W = 2, D = 1, Build = buildWindowWall, Desc = "Wand mit Fenster" },
	{ Id = "Gate", Name = "Rolltor", Cat = "Bau", Price = 150, Level = 1, W = 3, D = 1, Build = buildGate, Desc = "Durchgang in der Wand" },
	{ Id = "Pillar", Name = "Stahlsäule", Cat = "Bau", Price = 30, Level = 1, W = 1, D = 1, Build = buildPillar, Desc = "Stütze für die Halle" },
	{ Id = "FloorGray", Name = "Betonboden", Cat = "Bau", Price = 10, Level = 1, W = 2, D = 2, Layer = "Floor", Build = floorBuilder(C(140, 140, 145), M.Concrete), Desc = "Boden (darunter platzierbar)" },
	{ Id = "FloorGreen", Name = "Epoxid-Boden", Cat = "Bau", Price = 25, Level = 2, W = 2, D = 2, Layer = "Floor", Build = floorBuilder(C(70, 140, 100), M.SmoothPlastic), Desc = "Glänzender Hallenboden" },
	{ Id = "FloorLane", Name = "Fahrspur", Cat = "Bau", Price = 15, Level = 1, W = 2, D = 2, Layer = "Floor", Build = floorBuilder(C(90, 90, 95), M.Concrete, true), Desc = "Boden mit gelben Linien" },

	-- Deko
	{ Id = "Plant", Name = "Pflanze", Cat = "Deko", Price = 50, Level = 1, W = 1, D = 1, Build = buildPlant, Desc = "Etwas Grün" },
	{ Id = "Lamp", Name = "Hallenlampe", Cat = "Deko", Price = 80, Level = 1, W = 1, D = 1, Build = buildLamp, Desc = "Leuchtet nachts" },
	{ Id = "Pallets", Name = "Palettenstapel", Cat = "Deko", Price = 60, Level = 1, W = 1, D = 1, Build = buildPallets, Desc = "Sieht nach Arbeit aus" },
	{ Id = "Barrier", Name = "Absperrung", Cat = "Deko", Price = 40, Level = 1, W = 2, D = 1, Build = buildBarrier, Desc = "Sicherheit zuerst" },
	{ Id = "Barrels", Name = "Fässer", Cat = "Deko", Price = 70, Level = 2, W = 1, D = 1, Build = buildBarrels, Desc = "Industrie-Look" },
	{ Id = "Sign", Name = "Firmenschild", Cat = "Deko", Price = 300, Level = 1, W = 2, D = 1, Build = buildSign, Desc = "Zeigt deinen Namen" },
}

Items.ById = {}
for i, def in ipairs(Items.List) do
	def.Order = i
	def.Layer = def.Layer or "Object"
	Items.ById[def.Id] = def
end

---------------------------------------------------------------- Raster-Helfer
function Items.Footprint(def, rot)
	if rot % 2 == 1 then
		return def.D, def.W
	end
	return def.W, def.D
end

-- Position relativ zum Grundstück (Ursprung = vordere Mitte, +Z = weg von der Straße)
function Items.LocalCFrame(def, tx, tz, rot)
	local w, d = Items.Footprint(def, rot)
	local T = Config.TileSize
	return CFrame.new((tx + w / 2) * T, 0, (tz + d / 2) * T) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

function Items.ChunkOf(tx, tz)
	local half = Config.TilesX() // 2
	return (tx + half) // Config.ChunkTiles, tz // Config.ChunkTiles
end

-- Prüft, ob ein Objekt hier stehen darf. ownsChunk(cx, cz) und isFree(layer, x, z) kommen vom Aufrufer.
function Items.Validate(def, tx, tz, rot, ownsChunk, isFree)
	local w, d = Items.Footprint(def, rot)
	if def.Dock then
		if rot ~= 0 then
			return false, "Rampe muss zur Straße zeigen"
		end
		if tz ~= 0 then
			return false, "Rampen nur ganz vorne an der Straße"
		end
	end
	local half = Config.TilesX() // 2
	for x = tx, tx + w - 1 do
		for z = tz, tz + d - 1 do
			if x < -half or x >= half or z < 0 or z >= Config.TilesZ() then
				return false, "Außerhalb deines Grundstücks"
			end
			if not ownsChunk(Items.ChunkOf(x, z)) then
				return false, "Fläche noch nicht gekauft (🧱 Erweitern)"
			end
			if not isFree(def.Layer, x, z) then
				return false, "Platz ist belegt"
			end
		end
	end
	return true
end

function Items.Build(def, ctx)
	local model = Instance.new("Model")
	model.Name = def.Id
	def.Build(model, def, ctx)
	model.WorldPivot = CFrame.new()
	return model
end

-- Füllt die Kisten im Regal passend zum Lagerbestand
function Items.UpdateShelf(model, stock, capacity)
	local slots = model:FindFirstChild("Slots")
	if not slots then
		return
	end
	local count = #slots:GetChildren()
	local total = 0
	for _, n in pairs(stock) do
		total += n
	end
	local shown = total > 0 and math.max(1, math.ceil(total / capacity * count)) or 0
	local idx, acc = 0, 0
	for _, g in ipairs(Config.Goods) do
		local n = stock[g.Id] or 0
		if n > 0 then
			acc += n
			local upto = math.floor(acc / total * shown + 0.5)
			while idx < upto do
				idx += 1
				local slot = slots:FindFirstChild(tostring(idx))
				if slot then
					slot.Transparency = 0
					slot.Color = g.Color
				end
			end
		end
	end
	for i = idx + 1, count do
		local slot = slots:FindFirstChild(tostring(i))
		if slot then
			slot.Transparency = 1
		end
	end
end

return Items
