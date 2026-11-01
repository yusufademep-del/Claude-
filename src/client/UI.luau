-- Lager-Imperium – UI-Baukasten (Buttons, Fenster, Benachrichtigungen)

local TweenService = game:GetService("TweenService")

local UI = {}

UI.FONT = Enum.Font.FredokaOne
UI.WHITE = Color3.new(1, 1, 1)
UI.DARK = Color3.fromRGB(28, 30, 42)
UI.CARD = Color3.fromRGB(48, 52, 72)
UI.GREEN = Color3.fromRGB(60, 190, 90)
UI.RED = Color3.fromRGB(230, 70, 70)
UI.GRAY = Color3.fromRGB(110, 110, 120)
UI.YELLOW = Color3.fromRGB(255, 200, 40)
UI.BLUE = Color3.fromRGB(60, 140, 255)

function UI.new(class, props, children)
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
local new = UI.new

function UI.corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

function UI.stroke(thickness, color)
	return new("UIStroke", { Thickness = thickness or 3, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UI.padding(px)
	local u = UDim.new(0, px)
	return new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.label(props)
	props.BackgroundTransparency = 1
	props.Font = UI.FONT
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	props.TextColor3 = props.TextColor3 or UI.WHITE
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.4
	return new("TextLabel", props)
end

function UI.button(text, color, props)
	props.Text = text
	props.BackgroundColor3 = color
	props.Font = UI.FONT
	props.TextScaled = true
	props.TextColor3 = UI.WHITE
	props.TextStrokeTransparency = 0.4
	props.AutoButtonColor = true
	local b = new("TextButton", props, { UI.corner(12), UI.stroke(3), UI.padding(6) })
	new("UIScale", { Name = "Bounce", Parent = b })
	return b
end

function UI.bounce(gui)
	local s = gui:FindFirstChild("Bounce")
	if s then
		s.Scale = 0.88
		TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

---------------------------------------------------------------- Skalierung (Handy + PC)
local scalers = {}

function UI.scaled(frame)
	table.insert(scalers, new("UIScale", { Parent = frame }))
	UI.updateScale()
	return frame
end

function UI.updateScale()
	local cam = workspace.CurrentCamera
	local scale = cam and math.clamp(cam.ViewportSize.Y / 800, 0.5, 1.15) or 1
	for _, s in ipairs(scalers) do
		s.Scale = scale
	end
end

---------------------------------------------------------------- Fenster
local panels = {}

function UI.panel(gui, title, size)
	local frame = UI.scaled(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = UI.DARK,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { UI.corner(18), UI.stroke(4) }))
	UI.label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 40), Text = title, ZIndex = 11, Parent = frame })
	local close = UI.button("X", UI.RED, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(42, 42),
		ZIndex = 11,
		Parent = frame,
	})
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local content = new("Frame", {
		Position = UDim2.fromOffset(14, 60),
		Size = UDim2.new(1, -28, 1, -74),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = frame,
	})
	table.insert(panels, frame)
	return frame, content
end

function UI.closePanels()
	for _, p in ipairs(panels) do
		p.Visible = false
	end
end

function UI.toggle(frame)
	local show = not frame.Visible
	UI.closePanels()
	frame.Visible = show
end

function UI.scroll(parent, props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 8
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.CanvasSize = UDim2.new()
	props.Parent = parent
	return new("ScrollingFrame", props)
end

---------------------------------------------------------------- Benachrichtigungen
local toastHolder
local toastCount = 0
local toastColors = {
	good = Color3.fromRGB(100, 235, 120),
	bad = Color3.fromRGB(255, 100, 100),
	record = Color3.fromRGB(255, 215, 60),
	info = UI.WHITE,
}

function UI.initToasts(gui)
	toastHolder = UI.scaled(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(620, 220),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	}))
end

function UI.toast(text, kind)
	if not toastHolder then
		return
	end
	toastCount += 1
	local t = UI.label({
		Size = UDim2.new(1, 0, 0, kind == "record" and 42 or 32),
		Text = text,
		TextColor3 = toastColors[kind] or UI.WHITE,
		TextStrokeTransparency = 0,
		LayoutOrder = toastCount,
		ZIndex = 20,
		Parent = toastHolder,
	})
	local labels = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #labels - 5 do
		labels[i]:Destroy()
	end
	task.delay(3, function()
		if t.Parent then
			local tween = TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			t:Destroy()
		end
	end)
end

return UI
