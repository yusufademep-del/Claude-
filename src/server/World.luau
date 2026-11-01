-- Lager-Imperium – baut die Map: Straße + 6 Grundstücke mit LKW-Hof
-- Stell in den Spieleinstellungen „Max. Spieler“ auf 6 (ein Grundstück pro Spieler).

local World = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

function World.Build(Config)
	local old = workspace:FindFirstChild("LagerWorld")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "LagerWorld"
	folder.Parent = workspace

	if not workspace:FindFirstChild("Baseplate") then
		part({
			Name = "Baseplate",
			Size = Vector3.new(1400, 2, 1400),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(95, 170, 85),
			Material = Enum.Material.Grass,
			Parent = workspace,
		})
	end

	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end

	local plotW = Config.ChunksX * Config.ChunkTiles * Config.TileSize -- 160
	local plotD = Config.ChunksZ * Config.ChunkTiles * Config.TileSize -- 128
	local yard = 24
	local roadW = 24
	local gap = 24
	local spacing = plotW + gap
	local roadLen = spacing * 3 + 200

	-- Straße
	part({
		Name = "Road",
		Size = Vector3.new(roadLen, 0.2, roadW),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(45, 45, 50),
		Material = Enum.Material.Asphalt,
		Parent = folder,
	})
	for x = -roadLen / 2 + 6, roadLen / 2 - 6, 16 do
		part({
			Name = "Dash",
			Size = Vector3.new(8, 0.05, 0.6),
			Position = Vector3.new(x, 0.22, 0),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = folder,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.Position = Vector3.new(0, 0.3, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	local plots = {}
	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plots"
	plotFolder.Parent = workspace

	local index = 0
	for _, side in ipairs({ 1, -1 }) do
		for col = -1, 1 do
			index += 1
			local front = roadW / 2 + yard
			local origin = CFrame.new(col * spacing, 0.2, side * front)
			if side == -1 then
				origin *= CFrame.Angles(0, math.pi, 0)
			end

			local f = Instance.new("Folder")
			f.Name = "Plot_" .. index
			f:SetAttribute("Index", index)
			f:SetAttribute("OwnerId", 0)
			f:SetAttribute("Origin", origin)
			f.Parent = plotFolder

			-- LKW-Hof (zwischen Straße und Grundstück)
			part({
				Name = "Yard",
				Size = Vector3.new(plotW, 0.2, yard),
				CFrame = origin * CFrame.new(0, -0.1, -yard / 2),
				Color = Color3.fromRGB(120, 120, 125),
				Material = Enum.Material.Concrete,
				Parent = f,
			})
			-- Umrandung des Grundstücks (zeigt, wie groß es maximal werden kann)
			for _, b in ipairs({
				{ Vector3.new(plotW, 0.3, 0.6), Vector3.new(0, 0, plotD) },
				{ Vector3.new(0.6, 0.3, plotD), Vector3.new(-plotW / 2, 0, plotD / 2) },
				{ Vector3.new(0.6, 0.3, plotD), Vector3.new(plotW / 2, 0, plotD / 2) },
			}) do
				part({
					Name = "Border",
					Size = b[1],
					CFrame = origin * CFrame.new(b[2]),
					Color = Color3.fromRGB(255, 255, 255),
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0.4,
					CanCollide = false,
					Parent = f,
				})
			end

			-- Schild am Hof
			local signPost = part({
				Name = "SignPost",
				Size = Vector3.new(0.6, 9, 0.6),
				CFrame = origin * CFrame.new(plotW / 2 - 6, 4.5, -yard + 2),
				Color = Color3.fromRGB(60, 60, 70),
				Material = Enum.Material.Metal,
				Parent = f,
			})
			local board = part({
				Name = "SignBoard",
				Size = Vector3.new(14, 4, 0.4),
				CFrame = signPost.CFrame * CFrame.new(-6, 3, 0),
				Color = Color3.fromRGB(30, 30, 45),
				Parent = f,
			})
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 30
			gui.LightInfluence = 0
			gui.Parent = board
			local signLabel = Instance.new("TextLabel")
			signLabel.Size = UDim2.fromScale(1, 1)
			signLabel.BackgroundTransparency = 1
			signLabel.Text = "Freies Grundstück"
			signLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
			signLabel.TextScaled = true
			signLabel.Font = Enum.Font.FredokaOne
			signLabel.Parent = gui

			local ground = Instance.new("Folder")
			ground.Name = "Ground"
			ground.Parent = f
			local items = Instance.new("Folder")
			items.Name = "Items"
			items.Parent = f
			local trucks = Instance.new("Folder")
			trucks.Name = "Trucks"
			trucks.Parent = f

			table.insert(plots, {
				Index = index,
				Folder = f,
				Origin = origin,
				Ground = ground,
				ItemsFolder = items,
				Trucks = trucks,
				SignLabel = signLabel,
			})
		end
	end

	return { Plots = plots }
end

return World
