-- Pump & Fly – baut die Map per Code (Spawn, Zonen-Ringe, Wolken, Bestenliste)
-- Du musst nichts bauen: einfach eine leere Baseplate nehmen und starten.

local World = {}

local function make(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function part(props)
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.CanCollide == nil then
		props.CanCollide = false
	end
	return make("Part", props)
end

local function billboard(adornee, text, color, size)
	local gui = make("BillboardGui", {
		Size = UDim2.new(size.X, 0, size.Y, 0),
		LightInfluence = 0,
		MaxDistance = 2000,
		Parent = adornee,
	})
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		Parent = gui,
	})
	return gui
end

local function buildZones(folder, Config, rng)
	for index, zone in ipairs(Config.Zones) do
		if zone.Height > 0 then
			local h = zone.Height
			local nextZone = Config.Zones[index + 1]
			local top = nextZone and nextZone.Height or (h + 8000)

			-- Leuchtender Rahmen, durch den man fliegt
			local size, t = 140, 3
			for _, def in ipairs({
				{ Vector3.new(0, h, size / 2), Vector3.new(size, t, t) },
				{ Vector3.new(0, h, -size / 2), Vector3.new(size, t, t) },
				{ Vector3.new(size / 2, h, 0), Vector3.new(t, t, size) },
				{ Vector3.new(-size / 2, h, 0), Vector3.new(t, t, size) },
			}) do
				part({
					Name = zone.Name .. "Ring",
					Position = def[1],
					Size = def[2],
					Color = zone.Color,
					Material = Enum.Material.Neon,
					Transparency = 0.15,
					CastShadow = false,
					CanQuery = false,
					Parent = folder,
				})
			end

			local labelAnchor = part({
				Name = zone.Name .. "Label",
				Position = Vector3.new(0, h + 15, size / 2),
				Size = Vector3.new(1, 1, 1),
				Transparency = 1,
				CanQuery = false,
				Parent = folder,
			})
			billboard(
				labelAnchor,
				string.format("%s %s  •  x%s Münzen", zone.Icon, string.upper(zone.Name), Config.FormatMult(zone.Multiplier)),
				zone.Color,
				Vector2.new(80, 14)
			)

			-- Deko pro Zone
			local count = (zone.Decor == "clouds" or zone.Decor == "storm") and 18 or 30
			for _ = 1, count do
				local pos = Vector3.new(rng:NextNumber(-500, 500), rng:NextNumber(h, top), rng:NextNumber(-500, 500))
				if zone.Decor == "clouds" or zone.Decor == "storm" then
					local w = rng:NextNumber(25, 60)
					part({
						Name = "Cloud",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(w, w, w),
						Position = pos,
						Color = zone.Decor == "storm" and Color3.fromRGB(90, 90, 105) or Color3.new(1, 1, 1),
						Material = Enum.Material.SmoothPlastic,
						Transparency = 0.25,
						CastShadow = false,
						CanQuery = false,
						Parent = folder,
					})
				else
					local s = rng:NextNumber(1, 4)
					part({
						Name = "Star",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(s, s, s),
						Position = pos,
						Color = zone.Decor == "void" and Color3.fromRGB(200, 120, 255) or Color3.new(1, 1, 0.85),
						Material = Enum.Material.Neon,
						CastShadow = false,
						CanQuery = false,
						Parent = folder,
					})
				end
			end

			if zone.Decor == "moon" then
				part({
					Name = "Moon",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(400, 400, 400),
					Position = Vector3.new(700, h + 600, -700),
					Color = Color3.fromRGB(200, 200, 190),
					Material = Enum.Material.Slate,
					CastShadow = false,
					CanQuery = false,
					Parent = folder,
				})
			end
		end
	end
end

local function buildLeaderboard(folder)
	local board = part({
		Name = "Bestenliste",
		Size = Vector3.new(18, 14, 1),
		CFrame = CFrame.new(0, 9, -30) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(35, 35, 55),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		Parent = folder,
	})
	local gui = make("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Parent = board,
	})
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0.16, 0),
		BackgroundTransparency = 1,
		Text = "🏆 HÖCHSTE FLÜGE (WELTWEIT)",
		TextColor3 = Color3.fromRGB(255, 215, 60),
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		Parent = gui,
	})
	local list = make("Frame", {
		Position = UDim2.new(0.05, 0, 0.18, 0),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local rows = {}
	for i = 1, 10 do
		rows[i] = make("TextLabel", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0.1, 0),
			BackgroundTransparency = 1,
			Text = i == 1 and "Lade…" or "",
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			Parent = list,
		})
	end

	return function(entries, format)
		if not entries then
			rows[1].Text = "Bestenliste nur im veröffentlichten Spiel"
			return
		end
		local medals = { "🥇", "🥈", "🥉" }
		for i = 1, 10 do
			local e = entries[i]
			rows[i].Text = e and string.format("%s %d. %s – %s Studs", medals[i] or "  ", i, e.Name, format(e.Value)) or ""
		end
	end
end

function World.Build(Config)
	local old = workspace:FindFirstChild("PumpFlyWorld")
	if old then
		old:Destroy()
	end
	local folder = make("Folder", { Name = "PumpFlyWorld", Parent = workspace })
	local rng = Random.new(1337)

	-- Boden, falls keine Baseplate existiert
	if not workspace:FindFirstChild("Baseplate") then
		part({
			Name = "Baseplate",
			Size = Vector3.new(1024, 2, 1024),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(100, 190, 90),
			Material = Enum.Material.Grass,
			CanCollide = true,
			Parent = folder,
		})
	end

	-- Fremde Spawns entfernen, damit alle auf unserer Plattform starten
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end

	part({
		Name = "SpawnPlatform",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 70, 70),
		CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 80),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		Parent = folder,
	})
	local spawn = make("SpawnLocation", {
		Name = "Spawn",
		Anchored = true,
		Size = Vector3.new(12, 1, 12),
		Position = Vector3.new(0, 1.5, 0),
		Color = Color3.fromRGB(255, 120, 180),
		Material = Enum.Material.Neon,
		Duration = 0,
		Neutral = true,
		Parent = folder,
	})

	local tip = part({
		Name = "Tipp",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 14, 25),
		Transparency = 1,
		Parent = folder,
	})
	billboard(tip, "🎈 Pumpe so viel du dich traust… 💥 aber nicht zu viel!", Color3.new(1, 1, 1), Vector2.new(40, 5))

	buildZones(folder, Config, rng)
	local setBoard = buildLeaderboard(folder)

	return {
		SpawnCFrame = spawn.CFrame + Vector3.new(0, 4, 0),
		SetBoard = function(entries)
			setBoard(entries, Config.Format)
		end,
	}
end

return World
