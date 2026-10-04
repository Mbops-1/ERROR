-- ================= SERVICES =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- ================= REFS =================
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ================= CONFIG (LOGIKA ASLI) =================
local AIM_RADIUS = 400
local AIM_SPEED  = 1.25
local LOCK_PART  = "Head"

local AIM_MODE = 1 -- 1 = LOCK TETAP, 2 = AUTO SWITCH
local USE_CAM_HEIGHT = true
local CAM_HEIGHT = 2
local SCREEN_TILT = -12

local USE_FRIEND_FILTER = true
local USE_FACE_TARGET = false
local USE_STEALTH_MODE = false

local TOGGLE_KEY = Enum.KeyCode.V

-- ================= ESP CONFIG & STATE =================
local ESP_ENABLED      = false
local ESP_CHAMS        = true
local ESP_NAMES        = true
local ESP_HEALTH       = true
local ESP_BOX          = true
local ESP_SKELETON     = false
local ESP_TRACERS      = true
local ESP_DISTANCE     = true
local ESP_TEAM_CHECK   = false

local ESP_STORAGE = {}
local aiming = false
local targetPart = nil
local lastTarget = nil
local holdTime = 0
local LOCK_DELAY = 0.05

local function clearTarget()
	targetPart = nil
	lastTarget = nil
	holdTime = 0
end

-- ================= ADVANCED ESP SYSTEM =================
local SKELETON_PAIRS = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"},
	{"LeftUpperArm", "LeftLowerArm"},
	{"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"},
	{"RightUpperArm", "RightLowerArm"},
	{"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"},
	{"LeftUpperLeg", "LeftLowerLeg"},
	{"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"},
	{"RightUpperLeg", "RightLowerLeg"},
	{"RightLowerLeg", "RightFoot"}
}

local function removeESPForPlayer(player)
	if ESP_STORAGE[player] then
		local data = ESP_STORAGE[player]
		if data.highlight then pcall(function() data.highlight:Destroy() end) end
		if data.billboard then pcall(function() data.billboard:Destroy() end) end
		if data.boxOutline then pcall(function() data.boxOutline:Remove() end) end
		if data.box then pcall(function() data.box:Remove() end) end
		if data.tracer then pcall(function() data.tracer:Remove() end) end
		if data.healthBarBg then pcall(function() data.healthBarBg:Remove() end) end
		if data.healthBar then pcall(function() data.healthBar:Remove() end) end
		
		if data.bones then
			for _, line in pairs(data.bones) do
				pcall(function() line:Remove() end)
			end
		end
		if data.charConn then data.charConn:Disconnect() end
		ESP_STORAGE[player] = nil
	end
end

local function applyESPToCharacter(player, character)
	if not character then return end
	
	removeESPForPlayer(player)

	local data = {
		bones = {}
	}
	ESP_STORAGE[player] = data

	-- Chams Highlight
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Enabled = ESP_ENABLED and ESP_CHAMS
	highlight.Parent = CoreGui
	data.highlight = highlight

	-- Billboard Name Tag
	local head = character:WaitForChild("Head", 5) or character:WaitForChild("HumanoidRootPart", 5)
	if head then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ESP_Tag"
		billboard.Adornee = head
		billboard.Size = UDim2.new(0, 150, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Enabled = ESP_ENABLED and ESP_NAMES
		billboard.Parent = CoreGui
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = player.Name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = billboard

		data.billboard = billboard
		data.nameLabel = label
	end

	-- Drawing Objects (Box, Tracer, Health Bar, Skeleton)
	if Drawing then
		-- Box
		local boxOutline = Drawing.new("Square")
		boxOutline.Thickness = 3
		boxOutline.Color = Color3.new(0, 0, 0)
		boxOutline.Filled = false
		boxOutline.Visible = false
		data.boxOutline = boxOutline

		local box = Drawing.new("Square")
		box.Thickness = 1
		box.Color = Color3.fromRGB(255, 255, 255)
		box.Filled = false
		box.Visible = false
		data.box = box

		-- Tracer
		local tracer = Drawing.new("Line")
		tracer.Thickness = 1.5
		tracer.Color = Color3.fromRGB(255, 50, 50)
		tracer.Visible = false
		data.tracer = tracer

		-- Health Bar
		local healthBarBg = Drawing.new("Square")
		healthBarBg.Thickness = 1
		healthBarBg.Color = Color3.new(0, 0, 0)
		healthBarBg.Filled = true
		healthBarBg.Visible = false
		data.healthBarBg = healthBarBg

		local healthBar = Drawing.new("Square")
		healthBar.Thickness = 1
		healthBar.Color = Color3.fromRGB(0, 255, 0)
		healthBar.Filled = true
		healthBar.Visible = false
		data.healthBar = healthBar

		-- Skeleton Bones
		for i = 1, #SKELETON_PAIRS do
			local line = Drawing.new("Line")
			line.Thickness = 1.5
			line.Color = Color3.fromRGB(255, 255, 255)
			line.Visible = false
			table.insert(data.bones, line)
		end
	end
end

local function createESPForPlayer(player)
	if player == LocalPlayer then return end

	local data = {}
	ESP_STORAGE[player] = data

	data.charConn = player.CharacterAdded:Connect(function(char)
		if ESP_ENABLED then
			task.wait(0.2)
			applyESPToCharacter(player, char)
		end
	end)

	if player.Character and ESP_ENABLED then
		applyESPToCharacter(player, player.Character)
	end
end

local function toggleESP(state)
	ESP_ENABLED = state
	for plr, data in pairs(ESP_STORAGE) do
		if not state then
			removeESPForPlayer(plr)
		else
			if plr.Character then
				applyESPToCharacter(plr, plr.Character)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	if ESP_ENABLED then
		task.wait(0.5)
		createESPForPlayer(plr)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	removeESPForPlayer(plr)
end)

-- ================= GUI PROTECTION =================
local ProtectedFolder = Instance.new("Folder")
ProtectedFolder.Parent = CoreGui
ProtectedFolder.Name = "RobloxGui"

local function Protect(inst)
	if not inst then return end
	local HiddenUI = gethui or gethiddenui or get_hidden_ui or get_hui or get_h_ui
	inst.Parent = (HiddenUI and HiddenUI()) or cloneref(ProtectedFolder)
	inst.Name = HttpService:GenerateGUID(false)
end

-- ================= ScreenGui INITIALIZATION =================
local gui = Instance.new("ScreenGui")
gui.Name = "AimlockUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
pcall(function() gui.Parent = gethui and gethui() or game.CoreGui end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
Protect(gui)

local SafeFrame = Instance.new("Frame", gui)
SafeFrame.Size = UDim2.fromScale(1,1)
SafeFrame.BackgroundTransparency = 1

-- ================= EFFECT LUXURY RAIN (💎 & 💵) =================
local function createLuxuryRain(parentFrame)
	local rainContainer = Instance.new("Frame")
	rainContainer.Name = "LuxuryRainContainer"
	rainContainer.Size = UDim2.new(1, 0, 1, 0)
	rainContainer.BackgroundTransparency = 1
	rainContainer.ClipsDescendants = true
	rainContainer.ZIndex = 1
	rainContainer.Parent = parentFrame

	local items = {"💎", "💵"}

	task.spawn(function()
		while parentFrame and parentFrame.Parent do
			if parentFrame.Visible and parentFrame.BackgroundTransparency < 1 then
				local dropItem = Instance.new("TextLabel")
				dropItem.Text = items[math.random(1, #items)]
				dropItem.BackgroundTransparency = 1
				dropItem.Font = Enum.Font.Gotham
				dropItem.TextColor3 = Color3.new(1, 1, 1)
				
				local randomSize = math.random(12, 20)
				dropItem.TextSize = randomSize
				dropItem.Size = UDim2.new(0, randomSize, 0, randomSize)
				
				dropItem.Position = UDim2.new(math.random(), 0, -0.1, 0)
				dropItem.ZIndex = 1
				dropItem.Parent = rainContainer

				local fallDuration = math.random(150, 350) / 100
				
				local tween = TweenService:Create(dropItem, TweenInfo.new(fallDuration, Enum.EasingStyle.Linear), {
					Position = UDim2.new(dropItem.Position.X.Scale, 0, 1.1, 0),
					TextTransparency = 0.6
				})
				tween:Play()

				task.delay(fallDuration, function()
					if dropItem and dropItem.Parent then
						dropItem:Destroy()
					end
				end)
			end
			task.wait(0.25)
		end
	end)
end

-- ================= MAIN PANEL =================
local main = Instance.new("Frame", SafeFrame)
main.Size = UDim2.new(0, 240, 0, 85)
main.Position = UDim2.new(0.3, 0, 0.4, 0)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke", main)
MainStroke.Color = Color3.fromRGB(100, 100, 100)
MainStroke.Thickness = 4

createLuxuryRain(main)

local aimBtn = Instance.new("TextButton", main)
aimBtn.Size = UDim2.new(1, 0, 1, 0)
aimBtn.Font = Enum.Font.GothamBold
aimBtn.TextSize = 24
aimBtn.Text = "AIMBOT: OFF"
aimBtn.BackgroundTransparency = 1
aimBtn.TextColor3 = Color3.new(1, 1, 1)
aimBtn.ZIndex = 5

local setBtn = Instance.new("TextButton", main)
setBtn.Size = UDim2.new(0, 24, 0, 24)
setBtn.Position = UDim2.new(1, -10, 0, 10)
setBtn.AnchorPoint = Vector2.new(1, 0)
setBtn.Text = "⚙️️"
setBtn.Font = Enum.Font.GothamBold
setBtn.TextSize = 16
setBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
setBtn.BackgroundTransparency = 1
setBtn.ZIndex = 6

local dot = Instance.new("Frame", main)
dot.Size = UDim2.new(0, 12, 0, 12)
dot.Position = UDim2.new(1, -12, 1, -12)
dot.AnchorPoint = Vector2.new(1, 1)
dot.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
dot.ZIndex = 6

-- DRAG LOGIC FOR MAIN PANEL
local dragMain, dragInputMain, dragStartMain, startPosMain
local function startDragMain(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragMain = true
		dragStartMain = input.Position
		startPosMain = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragMain = false end
		end)
	end
end
main.InputBegan:Connect(startDragMain)
aimBtn.InputBegan:Connect(startDragMain)
main.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInputMain = input end end)
aimBtn.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInputMain = input end end)

-- ================= MINI AIM BUTTONS (MOBILE) =================
local miniLock = Instance.new("TextButton", SafeFrame)
miniLock.Size = UDim2.new(0, 55, 0, 55)
miniLock.Position = UDim2.new(0.85, 0, 0.50, 0)
miniLock.Text = "LOCK"
miniLock.Font = Enum.Font.GothamBold
miniLock.TextSize = 13
miniLock.TextColor3 = Color3.new(1,1,1)
miniLock.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
miniLock.Active = true
miniLock.ZIndex = 999
Instance.new("UICorner", miniLock).CornerRadius = UDim.new(1,0)
local strokeML = Instance.new("UIStroke", miniLock) strokeML.Color = Color3.fromRGB(100, 100, 100) strokeML.Thickness = 2

local miniSwitch = Instance.new("TextButton", SafeFrame)
miniSwitch.Size = UDim2.new(0, 55, 0, 55)
miniSwitch.Position = UDim2.new(0.85, 0, 0.60, 0)
miniSwitch.Text = "GESER"
miniSwitch.Font = Enum.Font.GothamBold
miniSwitch.TextSize = 11
miniSwitch.TextColor3 = Color3.new(1,1,1)
miniSwitch.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
miniSwitch.Active = true
miniSwitch.ZIndex = 999
Instance.new("UICorner", miniSwitch).CornerRadius = UDim.new(1,0)
local strokeMS = Instance.new("UIStroke", miniSwitch) strokeMS.Color = Color3.fromRGB(100, 100, 100) strokeMS.Thickness = 2

local function makeMobileDraggable(button)
	local drag, dragInput, dragStart, startPos
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			drag = true dragStart = input.Position startPos = button.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then drag = false end end)
		end
	end)
	button.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and drag then
			local delta = input.Position - dragStart
			button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end
makeMobileDraggable(miniLock)
makeMobileDraggable(miniSwitch)

-- ================= SETTINGS PANEL =================
local TARGET_PANEL_SIZE = UDim2.new(0, 280, 0, 260)
local settings = Instance.new("Frame", SafeFrame)
settings.Name = "SettingPanel"
settings.Size = UDim2.new(0, TARGET_PANEL_SIZE.X.Offset, 0, 0)
settings.Position = UDim2.new(0.6, 0, 0.4, 0)
settings.AnchorPoint = Vector2.new(0.5, 0.5)
settings.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
settings.Visible = false
settings.Active = true
settings.ClipsDescendants = true

local SettingStroke = Instance.new("UIStroke", settings)
SettingStroke.Color = Color3.fromRGB(100, 100, 100)
SettingStroke.Thickness = 2
Instance.new("UICorner", settings).CornerRadius = UDim.new(0, 12)

createLuxuryRain(settings)

-- HEADER TABS SYSTEM
local _HeaderTabs = Instance.new("Frame", settings)
_HeaderTabs.Size = UDim2.new(1, 0, 0, 40)
_HeaderTabs.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
_HeaderTabs.ZIndex = 20

local _BtnCombat = Instance.new("TextButton", _HeaderTabs)
_BtnCombat.Size = UDim2.new(0.45, 0, 0.8, 0)
_BtnCombat.Position = UDim2.new(0.03, 0, 0.1, 0)
_BtnCombat.Text = "🔫 Combat"
_BtnCombat.Font = Enum.Font.GothamBold
_BtnCombat.TextSize = 13
_BtnCombat.BackgroundColor3 = Color3.fromRGB(25, 33, 44)
_BtnCombat.TextColor3 = Color3.new(1, 1, 1)
_BtnCombat.ZIndex = 21
Instance.new("UICorner", _BtnCombat).CornerRadius = UDim.new(0, 6)

local _BtnEsp = Instance.new("TextButton", _HeaderTabs)
_BtnEsp.Size = UDim2.new(0.45, 0, 0.8, 0)
_BtnEsp.Position = UDim2.new(0.52, 0, 0.1, 0)
_BtnEsp.Text = "👁 Esp"
_BtnEsp.Font = Enum.Font.GothamBold
_BtnEsp.TextSize = 13
_BtnEsp.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
_BtnEsp.TextColor3 = Color3.fromRGB(140, 140, 140)
_BtnEsp.ZIndex = 21
Instance.new("UICorner", _BtnEsp).CornerRadius = UDim.new(0, 6)

local _HeaderLine = Instance.new("Frame", _HeaderTabs)
_HeaderLine.Size = UDim2.new(1, 0, 0, 2)
_HeaderLine.Position = UDim2.new(0, 0, 1, -2)
_HeaderLine.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
_HeaderLine.ZIndex = 21

-- AREA KONTEN
local _ContentFrame = Instance.new("Frame", settings)
_ContentFrame.Size = UDim2.new(1, 0, 1, -40)
_ContentFrame.Position = UDim2.new(0, 0, 0, 40)
_ContentFrame.BackgroundTransparency = 1
_ContentFrame.ZIndex = 10

local _CombatScroll = Instance.new("ScrollingFrame", _ContentFrame)
_CombatScroll.Size = UDim2.new(1, 0, 1, 0)
_CombatScroll.BackgroundTransparency = 1
_CombatScroll.ScrollBarThickness = 4
_CombatScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
_CombatScroll.ZIndex = 11
_CombatScroll.Visible = true

local _CombatLayout = Instance.new("UIListLayout", _CombatScroll)
_CombatLayout.Padding = UDim.new(0, 8)
_CombatLayout.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", _CombatScroll).PaddingLeft = UDim.new(0,10)

local _EspScroll = Instance.new("ScrollingFrame", _ContentFrame)
_EspScroll.Size = UDim2.new(1, 0, 1, 0)
_EspScroll.BackgroundTransparency = 1
_EspScroll.ScrollBarThickness = 4
_EspScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
_EspScroll.ZIndex = 11
_EspScroll.Visible = false

local _EspLayout = Instance.new("UIListLayout", _EspScroll)
_EspLayout.Padding = UDim.new(0, 8)
_EspLayout.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", _EspScroll).PaddingLeft = UDim.new(0,10)

_CombatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
	_CombatScroll.CanvasSize = UDim2.new(0, 0, 0, _CombatLayout.AbsoluteContentSize.Y + 25) 
end)
_EspLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
	_EspScroll.CanvasSize = UDim2.new(0, 0, 0, _EspLayout.AbsoluteContentSize.Y + 25) 
end)

-- DRAG FOR SETTINGS PANEL
local dragSet, dragInputSet, dragStartSet, startPosSet
_HeaderTabs.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragSet = true dragStartSet = input.Position startPosSet = settings.Position
		input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragSet = false end end)
	end
end)
_HeaderTabs.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInputSet = input end end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInputMain and dragMain then
		local delta = input.Position - dragStartMain
		main.Position = UDim2.new(startPosMain.X.Scale, startPosMain.X.Offset + delta.X, startPosMain.Y.Scale, startPosMain.Y.Offset + delta.Y)
	elseif input == dragInputSet and dragSet then
		local delta = input.Position - dragStartSet
		settings.Position = UDim2.new(startPosSet.X.Scale, startPosSet.X.Offset + delta.X, startPosSet.Y.Scale, startPosSet.Y.Offset + delta.Y)
	end
end)

-- LOGIKA TAB KONTEN
_BtnCombat.MouseButton1Click:Connect(function()
	_EspScroll.Visible = false
	_CombatScroll.Visible = true 
	_BtnCombat.BackgroundColor3 = Color3.fromRGB(25, 33, 44) 
	_BtnCombat.TextColor3 = Color3.new(1, 1, 1)
	_BtnEsp.BackgroundColor3 = Color3.fromRGB(15, 18, 22) 
	_BtnEsp.TextColor3 = Color3.fromRGB(140, 140, 140)
end)
_BtnEsp.MouseButton1Click:Connect(function()
	_CombatScroll.Visible = false 
	_EspScroll.Visible = true
	_BtnEsp.BackgroundColor3 = Color3.fromRGB(25, 33, 44) 
	_BtnEsp.TextColor3 = Color3.new(1, 1, 1)
	_BtnCombat.BackgroundColor3 = Color3.fromRGB(15, 18, 22) 
	_BtnCombat.TextColor3 = Color3.fromRGB(140, 140, 140)
end)

-- ================= CONTROLS BUILDERS =================
local function makeToggleNew(targetParent, text, state, callback)
	local btn = Instance.new("TextButton", targetParent)
	btn.Size = UDim2.new(0.94, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(30, 38, 46)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.ZIndex = 15
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", btn) stroke.Color = Color3.fromRGB(50, 65, 80) stroke.Thickness = 1

	local value = state
	btn.Text = text .. ": " .. (value and "NYALA" or "MATI")

	btn.MouseButton1Click:Connect(function()
		value = not value
		btn.Text = text .. ": " .. (value and "NYALA" or "MATI")
		callback(value)
	end)
end

local function makeStepperNew(targetParent, text, min, max, step, value, callback)
	local f = Instance.new("Frame", targetParent)
	f.Size = UDim2.new(0.94, 0, 0, 32)
	f.BackgroundTransparency = 1
	f.ZIndex = 15

	local lbl = Instance.new("TextLabel", f)
	lbl.Size = UDim2.new(0.6, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 15

	local minus = Instance.new("TextButton", f)
	minus.Size = UDim2.new(0, 26, 1, 0)
	minus.Position = UDim2.new(0.65, 0, 0, 0)
	minus.Text = "-" minus.Font = Enum.Font.GothamBold minus.TextSize = 14
	minus.BackgroundColor3 = Color3.fromRGB(220, 0, 0) minus.TextColor3 = Color3.new(1,1,1)
	minus.ZIndex = 16
	Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)
	local sM = Instance.new("UIStroke", minus) sM.Color = Color3.fromRGB(150, 0, 0) sM.Thickness = 1

	local plus = Instance.new("TextButton", f)
	plus.Size = UDim2.new(0, 26, 1, 0)
	plus.Position = UDim2.new(0.85, 0, 0, 0)
	plus.Text = "+" plus.Font = Enum.Font.GothamBold plus.TextSize = 14
	plus.BackgroundColor3 = Color3.fromRGB(0, 185, 0) plus.TextColor3 = Color3.new(1,1,1)
	plus.ZIndex = 16
	Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)
	local sP = Instance.new("UIStroke", plus) sP.Color = Color3.fromRGB(0, 120, 0) sP.Thickness = 1

	local v = value
	local function update()
		v = math.clamp(v, min, max)
		lbl.Text = text .. ": " .. string.format("%.2f", v)
		callback(v)
	end
	update()

	minus.MouseButton1Click:Connect(function() v -= step; update() end)
	plus.MouseButton1Click:Connect(function() v += step; update() end)
end

-- ================= INJECT ITEMS KE COMBAT =================
makeStepperNew(_CombatScroll, "Kecepatan Aim", 0.02, 1.5, 0.05, AIM_SPEED, function(v) AIM_SPEED = v end)
makeStepperNew(_CombatScroll, "Tinggi Kamera", 0, 5, 0.5, CAM_HEIGHT, function(v) CAM_HEIGHT = v end)
makeStepperNew(_CombatScroll, "Tilt Layar", -15, 15, 1, SCREEN_TILT, function(v) SCREEN_TILT = v end)
makeToggleNew(_CombatScroll, "Gunakan Tinggi Cam", USE_CAM_HEIGHT, function(v) USE_CAM_HEIGHT = v end)
makeToggleNew(_CombatScroll, "Saring Teman", USE_FRIEND_FILTER, function(v) USE_FRIEND_FILTER = v end)
makeToggleNew(_CombatScroll, "Hadap Target", USE_FACE_TARGET, function(v) USE_FACE_TARGET = v end)
makeToggleNew(_CombatScroll, "Mode Senyap (Stealth)", USE_STEALTH_MODE, function(v) USE_STEALTH_MODE = v end)

makeToggleNew(_CombatScroll, "Mode Ganti Target Otomatis", (AIM_MODE == 2), function(v)
	AIM_MODE = v and 2 or 1
end)

-- ================= INJECT FITUR ESP BARU KE ESP TAB =================
makeToggleNew(_EspScroll, "Master ESP", ESP_ENABLED, function(v)
	toggleESP(v)
end)
makeToggleNew(_EspScroll, "ESP Chams (Highlight)", ESP_CHAMS, function(v)
	ESP_CHAMS = v
	for _, d in pairs(ESP_STORAGE) do
		if d.highlight then d.highlight.Enabled = ESP_ENABLED and ESP_CHAMS end
	end
end)
makeToggleNew(_EspScroll, "ESP Nama", ESP_NAMES, function(v)
	ESP_NAMES = v
	for _, d in pairs(ESP_STORAGE) do
		if d.billboard then d.billboard.Enabled = ESP_ENABLED and ESP_NAMES end
	end
end)
makeToggleNew(_EspScroll, "ESP Box 2D", ESP_BOX, function(v) ESP_BOX = v end)
makeToggleNew(_EspScroll, "ESP Health Bar", ESP_HEALTH, function(v) ESP_HEALTH = v end)
makeToggleNew(_EspScroll, "ESP Skeleton (Tulang)", ESP_SKELETON, function(v) ESP_SKELETON = v end)
makeToggleNew(_EspScroll, "ESP Tracer Line", ESP_TRACERS, function(v) ESP_TRACERS = v end)
makeToggleNew(_EspScroll, "ESP Jarak (Distance)", ESP_DISTANCE, function(v) ESP_DISTANCE = v end)
makeToggleNew(_EspScroll, "ESP Saring Tim (Team)", ESP_TEAM_CHECK, function(v) ESP_TEAM_CHECK = v end)

-- ================= UI RESPONSIVE & EVENTS =================
local function updateUI()
	aimBtn.Text = aiming and "AIMBOT: ON" or "AIMBOT: OFF"
	dot.BackgroundColor3 = aiming and Color3.fromRGB(0, 220, 0) or Color3.fromRGB(220, 0, 0)

	if AIM_MODE == 1 and aiming then
		miniLock.BackgroundColor3 = Color3.fromRGB(0, 185, 0)
		miniSwitch.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	elseif AIM_MODE == 2 and aiming then
		miniSwitch.BackgroundColor3 = Color3.fromRGB(0, 185, 0)
		miniLock.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	else
		miniLock.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		miniSwitch.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	end
end

aimBtn.MouseButton1Click:Connect(function()
	aiming = not aiming
	clearTarget()
	updateUI()
end)

miniLock.MouseButton1Click:Connect(function()
	AIM_MODE = 1
	aiming = true
	clearTarget()
	updateUI()
end)

miniSwitch.MouseButton1Click:Connect(function()
	AIM_MODE = 2
	aiming = true
	clearTarget()
	updateUI()
end)

setBtn.MouseButton1Click:Connect(function()
	if settings.Visible then
		TweenService:Create(settings, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, TARGET_PANEL_SIZE.X.Offset, 0, 0)}):Play()
		task.delay(0.15, function() settings.Visible = false end)
	else
		settings.Visible = true
		TweenService:Create(settings, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = TARGET_PANEL_SIZE}):Play()
	end
end)

UserInputService.InputBegan:Connect(function(i, p)
	if not p and i.KeyCode == TOGGLE_KEY then
		aiming = not aiming
		clearTarget()
		updateUI()
	end
end)

-- ================= AIMBOT LOGICS =================
local function getSeatPriority(char) return 0 end

local function findTarget()
	local best = nil
	local bestScore = -1
	local camPos = Camera.CFrame.Position

	for _,plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and (not USE_FRIEND_FILTER or not LocalPlayer:IsFriendsWith(plr.UserId)) then
			local char = plr.Character
			if not char then continue end

			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then continue end

			local part = char:FindFirstChild(LOCK_PART) 
				or char:FindFirstChild("Head") 
				or char:FindFirstChild("HumanoidRootPart")

			if not part then continue end

			local dist = (part.Position - camPos).Magnitude
			if dist <= AIM_RADIUS then
				local dir = (part.Position - camPos).Unit
				local score = Camera.CFrame.LookVector:Dot(dir)

				score += getSeatPriority(char)

				if score > bestScore then
					bestScore = score
					best = part
				end
			end
		end
	end
	return best
end

-- ================= RENDER & ESP LOOP =================
RunService.RenderStepped:Connect(function(dt)
	updateUI()

	-- ESP DRAWING UPDATES
	if ESP_ENABLED then
		for plr, data in pairs(ESP_STORAGE) do
			local char = plr.Character
			local isTeam = ESP_TEAM_CHECK and LocalPlayer.Team and plr.Team == LocalPlayer.Team
			
			if char and not isTeam then
				local root = char:FindFirstChild("HumanoidRootPart")
				local head = char:FindFirstChild("Head")
				local hum = char:FindFirstChildOfClass("Humanoid")

				if root and head and hum and hum.Health > 0 then
					local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
					local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)

					-- Distance & Name Label update
					if data.nameLabel then
						if ESP_DISTANCE then
							data.nameLabel.Text = string.format("%s [%dm]", plr.Name, dist)
						else
							data.nameLabel.Text = plr.Name
						end
					end

					if onScreen and Drawing then
						local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
						local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

						local height = math.abs(headPos.Y - legPos.Y)
						local width = height / 2.1

						-- 1. BOX 2D
						if ESP_BOX and data.box and data.boxOutline then
							data.box.Size = Vector2.new(width, height)
							data.box.Position = Vector2.new(rootPos.X - width / 2, rootPos.Y - height / 2)
							data.box.Visible = true

							data.boxOutline.Size = Vector2.new(width + 2, height + 2)
							data.boxOutline.Position = Vector2.new(rootPos.X - width / 2 - 1, rootPos.Y - height / 2 - 1)
							data.boxOutline.Visible = true
						else
							if data.box then data.box.Visible = false end
							if data.boxOutline then data.boxOutline.Visible = false end
						end

						-- 2. TRACER LINES
						if ESP_TRACERS and data.tracer then
							data.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
							data.tracer.To = Vector2.new(rootPos.X, rootPos.Y)
							data.tracer.Visible = true
						else
							if data.tracer then data.tracer.Visible = false end
						end

						-- 3. HEALTH BAR
						if ESP_HEALTH and data.healthBar and data.healthBarBg then
							local healthPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
							local barHeight = height * healthPct

							data.healthBarBg.Size = Vector2.new(4, height)
							data.healthBarBg.Position = Vector2.new(rootPos.X - width / 2 - 7, rootPos.Y - height / 2)
							data.healthBarBg.Visible = true

							data.healthBar.Size = Vector2.new(2, barHeight)
							data.healthBar.Position = Vector2.new(rootPos.X - width / 2 - 6, (rootPos.Y + height / 2) - barHeight)
							data.healthBar.Color = Color3.fromRGB(255 - (255 * healthPct), 255 * healthPct, 0)
							data.healthBar.Visible = true
						else
							if data.healthBar then data.healthBar.Visible = false end
							if data.healthBarBg then data.healthBarBg.Visible = false end
						end

						-- 4. SKELETON (TULANG)
						if ESP_SKELETON and data.bones then
							for i, pair in ipairs(SKELETON_PAIRS) do
								local p1 = char:FindFirstChild(pair[1])
								local p2 = char:FindFirstChild(pair[2])
								local line = data.bones[i]

								if p1 and p2 and line then
									local v1, vis1 = Camera:WorldToViewportPoint(p1.Position)
									local v2, vis2 = Camera:WorldToViewportPoint(p2.Position)

									if vis1 and vis2 then
										line.From = Vector2.new(v1.X, v1.Y)
										line.To = Vector2.new(v2.X, v2.Y)
										line.Visible = true
									else
										line.Visible = false
									end
								elseif line then
									line.Visible = false
								end
							end
						else
							if data.bones then
								for _, line in ipairs(data.bones) do line.Visible = false end
							end
						end
					else
						-- Hide Drawing Items if Offscreen
						if data.box then data.box.Visible = false end
						if data.boxOutline then data.boxOutline.Visible = false end
						if data.tracer then data.tracer.Visible = false end
						if data.healthBar then data.healthBar.Visible = false end
						if data.healthBarBg then data.healthBarBg.Visible = false end
						if data.bones then
							for _, line in ipairs(data.bones) do line.Visible = false end
						end
					end
				end
			else
				-- Hide ESP if Dead or Same Team
				if data.box then data.box.Visible = false end
				if data.boxOutline then data.boxOutline.Visible = false end
				if data.tracer then data.tracer.Visible = false end
				if data.healthBar then data.healthBar.Visible = false end
				if data.healthBarBg then data.healthBarBg.Visible = false end
				if data.bones then
					for _, line in ipairs(data.bones) do line.Visible = false end
				end
			end
		end
	end

	-- AIMBOT EXECUTION
	if not aiming then return end

	if not targetPart then
		targetPart = findTarget()
		lastTarget = targetPart
		return
	end

	if AIM_MODE == 1 then
		if not targetPart.Parent
		or not targetPart.Parent:FindFirstChildWhichIsA("Humanoid")
		or targetPart.Parent:FindFirstChildWhichIsA("Humanoid").Health <= 0
		or (targetPart.Position - Camera.CFrame.Position).Magnitude > AIM_RADIUS 
		then
			clearTarget()
			return
		end
	end

	if AIM_MODE == 2 then
		local newTarget = findTarget()
		if newTarget == lastTarget then
			holdTime += dt
		else
			holdTime = 0
		end
		if holdTime > LOCK_DELAY then
			targetPart = newTarget
		end
		lastTarget = newTarget
	end

	if targetPart then
		local origin = Camera.CFrame.Position
		if USE_CAM_HEIGHT then origin += Vector3.new(0,CAM_HEIGHT,0) end

		if USE_FACE_TARGET and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
			LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(LocalPlayer.Character.PrimaryPart.Position,targetPart.Position))
		end

		local goal = targetPart.Position
		if USE_STEALTH_MODE then
			goal += Vector3.new((math.random()-0.5)*0.05, (math.random()-0.5)*0.05, (math.random()-0.5)*0.05)
		end

		Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(origin,goal) * CFrame.Angles(math.rad(SCREEN_TILT),0,0), AIM_SPEED)
	end
end)

print("[DeltaAim] Advanced ESP & Combat Loaded Successfully!")
