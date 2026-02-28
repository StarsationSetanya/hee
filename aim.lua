--// Cache

local select = select
local pcall, getgenv, next, Vector2new, mathclamp, type, CFramenew, TweenInfonew, Color3fromRGB, Drawingnew, stringupper, mousemoverel = pcall, getgenv, next, Vector2.new, math.clamp, type, CFrame.new, TweenInfo.new, Color3.fromRGB, Drawing.new, string.upper, mousemoverel or (Input and Input.MouseMove)

--// Compatibility
local hook_metamethod = hookmetamethod or hook_metamethod or (getrawmetatable and function(obj, method, func)
    local mt = getrawmetatable(obj)
    local old = mt[method]
    if setreadonly then setreadonly(mt, false) elseif make_writeable then make_writeable(mt) end
    mt[method] = func
    if setreadonly then setreadonly(mt, true) elseif make_readonly then make_readonly(mt) end
    return old
end)

local getnamecallmethod = getnamecallmethod or (get_namecall_method)
local checkcaller = checkcaller or (function() return false end)

--// Preventing Multiple Processes

pcall(function()
	getgenv().Aimbot.Functions:Exit()
end)

--// Environment

getgenv().Aimbot = {}
getgenv().AimbotStatus = "🟢 พร้อมใช้งาน"
local Environment = getgenv().Aimbot

--// Services

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end

local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
end)

--// Variables

local ServiceConnections = {}

--// Script Settings

Environment.Settings = {
	Enabled = false,
	TeamCheck = false,
	AliveCheck = true,
	WallCheck = false,
	Sensitivity = 0, -- Animation length (in seconds) before fully locking onto target
	ThirdPerson = false, -- Uses mousemoverel instead of CFrame to support locking in third person (could be choppy)
	ThirdPersonSensitivity = 3,
	TriggerKey = "MouseButton2",
	Toggle = false,
	RandomizePart = false,
	LockPart = "Head", -- Body part to lock on
	SilentAim = true, -- Enable Silent Aim
	HeadshotChance = 100 -- Percentage chance for headshot in Silent Aim
}

Environment.FOVSettings = {
	Enabled = true,
	Visible = true,
	Amount = 90,
	Color = Color3.fromRGB(255, 255, 255),
	LockedColor = Color3.fromRGB(255, 70, 70),
	Transparency = 0.5,
	Sides = 60,
	Thickness = 1,
	Filled = false
}

Environment.FOVCircle = Drawingnew("Circle")

local TweenService = game:GetService("TweenService")
local Animation, OriginalSensitivity = nil, UserInputService.MouseDeltaSensitivity
local Running, Typing = false, false

--// Functions

local function CancelLock()
	Environment.Locked = nil
	Environment.FOVCircle.Color = Environment.FOVSettings.Color
	UserInputService.MouseDeltaSensitivity = OriginalSensitivity

	if Animation then
		Animation:Cancel()
	end
end

local function GetClosestPlayer()
	local RequiredDistance = (Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000)
	local Closest = nil

	for _, v in next, Players:GetPlayers() do
		if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChildOfClass("Humanoid") then
			if Environment.Settings.TeamCheck and v.Team == LocalPlayer.Team then continue end
			if Environment.Settings.AliveCheck and v.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
			
			local TargetPartName = Environment.Settings.LockPart
			if not v.Character:FindFirstChild(TargetPartName) then continue end
			
			if Environment.Settings.WallCheck and #(Camera:GetPartsObscuringTarget({v.Character[TargetPartName].Position}, v.Character:GetDescendants())) > 0 then continue end

			local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[TargetPartName].Position)
			local MousePos = UserInputService:GetMouseLocation()
			local Distance = (Vector2new(MousePos.X, MousePos.Y) - Vector2new(Vector.X, Vector.Y)).Magnitude

			if Distance < RequiredDistance and (OnScreen or Environment.Settings.SilentAim) then
				RequiredDistance = Distance
				Closest = v
			end
		end
	end
	
	return Closest
end

--// Silent Aim Hook Logic

local function GetTarget()
    local Target = GetClosestPlayer()
    if Target and Target.Character then
        local Part = Target.Character:FindFirstChild(Environment.Settings.LockPart) or Target.Character:FindFirstChild("Head")
        if Part then
            -- Handle Headshot Chance
            if math.random(1, 100) > Environment.Settings.HeadshotChance then
                Part = Target.Character:FindFirstChild("HumanoidRootPart") or Part
            end
            return Part
        end
    end
    return nil
end

local OldNamecall
OldNamecall = hook_metamethod(game, "__namecall", function(self, ...)
    local Method = getnamecallmethod()
    local Args = {...}

    if not checkcaller() and Environment.Settings.Enabled and Environment.Settings.SilentAim then
        if Method == "FireServer" and tostring(self) == "NetworkModule2" then
            local Target = GetTarget()
            if Target then
                -- This is a generic redirection, specific remote arguments may vary per game
                -- Based on the game structure, we might need to modify Args[2] (Position) or similar
                if Args[1] == "Shoot" or Args[1] == "Fire" then
                    -- Potential argument redirection based on Gun.luau and ProjectileMod.luau
                    -- Args[2] often contains the hit position or direction
                    Args[2] = Target.Position
                end
            end
        end
    end

    return OldNamecall(self, unpack(Args))
end)

--// Load Logic

local function Load()
	OriginalSensitivity = UserInputService.MouseDeltaSensitivity

	ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
		if Environment.FOVSettings.Enabled and Environment.Settings.Enabled then
			Environment.FOVCircle.Radius = Environment.FOVSettings.Amount
			Environment.FOVCircle.Thickness = Environment.FOVSettings.Thickness
			Environment.FOVCircle.Filled = Environment.FOVSettings.Filled
			Environment.FOVCircle.NumSides = Environment.FOVSettings.Sides
			Environment.FOVCircle.Color = Environment.FOVSettings.Color
			Environment.FOVCircle.Transparency = Environment.FOVSettings.Transparency
			Environment.FOVCircle.Visible = Environment.FOVSettings.Visible
			Environment.FOVCircle.Position = Vector2new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
		else
			Environment.FOVCircle.Visible = false
		end

		if Running and Environment.Settings.Enabled then
			Environment.Locked = GetClosestPlayer()

			if Environment.Locked and not Environment.Settings.SilentAim then
				if Environment.Settings.ThirdPerson then
					local Vector = Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position)

					mousemoverel((Vector.X - UserInputService:GetMouseLocation().X) * Environment.Settings.ThirdPersonSensitivity, (Vector.Y - UserInputService:GetMouseLocation().Y) * Environment.Settings.ThirdPersonSensitivity)
				else
					if Environment.Settings.Sensitivity > 0 then
						Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)})
						Animation:Play()
					else
						Camera.CFrame = CFramenew(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)
					end

					UserInputService.MouseDeltaSensitivity = 0
				end

				Environment.FOVCircle.Color = Environment.FOVSettings.LockedColor
			end
		end
	end)
		
	ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
		if not Typing then
			pcall(function()
				local Key = #Environment.Settings.TriggerKey == 1 and stringupper(Environment.Settings.TriggerKey) or Environment.Settings.TriggerKey
				if (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) or (Input.UserInputType.Name == Key) then
					if Environment.Settings.Toggle then
						Running = not Running

						if not Running then
							CancelLock()
						end
					else
						Running = true
					end
				end
			end)
		end
	end)

	ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
		if not Typing then
			if not Environment.Settings.Toggle then
				pcall(function()
					local Key = #Environment.Settings.TriggerKey == 1 and stringupper(Environment.Settings.TriggerKey) or Environment.Settings.TriggerKey
					if (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) or (Input.UserInputType.Name == Key) then
						Running = false; CancelLock()
					end
				end)
			end
		end
	end)

	ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function()
		Typing = true
	end)

	ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function()
		Typing = false
	end)
end

--// Functions

Environment.Functions = {}

function Environment.Functions:Exit()
	for _, v in next, ServiceConnections do
		v:Disconnect()
	end

	if Environment.FOVCircle then
		Environment.FOVCircle:Remove()
	end
	getgenv().Aimbot = nil
end

function Environment.Functions:Restart()
	Environment.Functions:Exit()
	task.wait(0.1)
	Load()
end

function Environment.Functions:ResetSettings()
	Environment.Settings = {
		Enabled = false,
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		HighlightCheck = false,
		Sensitivity = 0,
		ThirdPerson = false,
		ThirdPersonSensitivity = 3,
		TriggerKey = "MouseButton2",
		Toggle = false,
		RandomizePart = false,
		LockPart = "Head"
	}

	Environment.FOVSettings = {
		Enabled = true,
		Visible = true,
		Amount = 90,
		Color = Color3.fromRGB(255, 255, 255),
		LockedColor = Color3.fromRGB(255, 70, 70),
		Transparency = 0.5,
		Sides = 60,
		Thickness = 1,
		Filled = false
	}

	Environment.ESPSettings = ExunysESP.Settings
	ExunysESP:InitCrosshair()
end

--// Load

Load()

--// UI (Starsation Interface)

local success, StarsationLibrary = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/StarsationSetanya/hee/refs/heads/main/ui.lua"))()
end)

if not success or not StarsationLibrary then
	return
end

local Window = StarsationLibrary:CreateWindow({
	Name = "Aimbot (Modified)",
	LoadingTitle = "Aimbot",
	LoadingSubtitle = "by Starsation",
	Theme = "Default",
	Icon = 0,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "StarsationAimbot",
		FileName = "StarsationAimbot_v1"
	},
	Discord = {
		Enabled = false,
		Invite = "",
		RememberJoins = true
	},
	KeySystem = false,
})

--// Tab: Aimbot

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

local StatusSection = AimbotTab:CreateSection("สถานะสคริปต์")

local StatusLabel = AimbotTab:CreateLabel("สถานะ Aimbot: " .. tostring(getgenv().AimbotStatus))

task.spawn(function()
	while task.wait(0.5) do
		if StatusLabel and StatusLabel.Set then
			local currentStatus = (Running and Environment.Locked) and "🔴 ล็อคเป้าหมาย: " .. Environment.Locked.Name or (Running and "🟡 กำลังหาเป้าหมาย...") or "🟢 พร้อมใช้งาน"
			StatusLabel:Set("สถานะ Aimbot: " .. currentStatus)
		end
	end
end)

local MainSection = AimbotTab:CreateSection("ตั้งค่า Aimbot")

AimbotTab:CreateToggle({
	Name = "เปิดใช้งาน Aimbot",
	CurrentValue = Environment.Settings.Enabled,
	Flag = "AimbotEnabled",
	Callback = function(Value)
		Environment.Settings.Enabled = Value
	end,
})

AimbotTab:CreateDropdown({
	Name = "Trigger Key (ปุ่มใช้งาน)",
	Options = {"MouseButton1", "MouseButton2", "E", "Q", "F", "X", "Z", "LeftControl", "LeftShift"},
	CurrentOption = {Environment.Settings.TriggerKey},
	MultipleOptions = false,
	Flag = "TriggerKey",
	Callback = function(Options)
		Environment.Settings.TriggerKey = Options[1]
	end,
})

AimbotTab:CreateToggle({
	Name = "Toggle (เปิด/ปิด)",
	CurrentValue = Environment.Settings.Toggle,
	Flag = "AimbotToggle",
	Callback = function(Value)
		Environment.Settings.Toggle = Value
	end,
})

AimbotTab:CreateSlider({
	Name = "Sensitivity (ความเร็วล็อค)",
	Range = {0, 1},
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Environment.Settings.Sensitivity,
	Flag = "AimbotSensitivity",
	Callback = function(Value)
		Environment.Settings.Sensitivity = Value
	end,
})

local SilentAimSection = AimbotTab:CreateSection("ตั้งค่า Silent Aim")

AimbotTab:CreateToggle({
	Name = "เปิดใช้งาน Silent Aim",
	CurrentValue = Environment.Settings.SilentAim,
	Flag = "SilentAimEnabled",
	Callback = function(Value)
		Environment.Settings.SilentAim = Value
	end,
})

AimbotTab:CreateSlider({
	Name = "โอกาส Hit Headshot",
	Range = {0, 100},
	Increment = 1,
	Suffix = "%",
	CurrentValue = Environment.Settings.HeadshotChance,
	Flag = "HeadshotChance",
	Callback = function(Value)
		Environment.Settings.HeadshotChance = Value
	end,
})

local ThirdPersonSection = AimbotTab:CreateSection("Third Person Support")

AimbotTab:CreateToggle({
	Name = "เปิดโหมด Third Person",
	CurrentValue = Environment.Settings.ThirdPerson,
	Flag = "ThirdPersonEnabled",
	Callback = function(Value)
		Environment.Settings.ThirdPerson = Value
	end,
})

AimbotTab:CreateSlider({
	Name = "Third Person Sensitivity",
	Range = {1, 10},
	Increment = 1,
	Suffix = "x",
	CurrentValue = Environment.Settings.ThirdPersonSensitivity,
	Flag = "ThirdPersonSensitivity",
	Callback = function(Value)
		Environment.Settings.ThirdPersonSensitivity = Value
	end,
})

local FOVSection = AimbotTab:CreateSection("ตั้งค่าวง FOV")

AimbotTab:CreateToggle({
	Name = "เปิดใช้งาน FOV",
	CurrentValue = Environment.FOVSettings.Enabled,
	Flag = "FOVEnabled",
	Callback = function(Value)
		Environment.FOVSettings.Enabled = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "แสดงวง FOV",
	CurrentValue = Environment.FOVSettings.Visible,
	Flag = "FOVVisible",
	Callback = function(Value)
		Environment.FOVSettings.Visible = Value
	end,
})

AimbotTab:CreateSlider({
	Name = "ระยะ FOV",
	Range = {10, 800},
	Increment = 10,
	Suffix = "px",
	CurrentValue = Environment.FOVSettings.Amount,
	Flag = "FOVAmount",
	Callback = function(Value)
		Environment.FOVSettings.Amount = Value
	end,
})

AimbotTab:CreateColorPicker({
	Name = "สีปกติ",
	Color = Environment.FOVSettings.Color,
	Flag = "FOVColor",
	Callback = function(Value)
		Environment.FOVSettings.Color = Value
	end,
})

AimbotTab:CreateColorPicker({
	Name = "สีเมื่อล็อค",
	Color = Environment.FOVSettings.LockedColor,
	Flag = "FOVLockedColor",
	Callback = function(Value)
		Environment.FOVSettings.LockedColor = Value
	end,
})

local FilterSection = AimbotTab:CreateSection("ตัวกรองเป้าหมาย")

AimbotTab:CreateToggle({
	Name = "ตรวจสอบทีม (Team Check)",
	CurrentValue = Environment.Settings.TeamCheck,
	Flag = "TeamCheck",
	Callback = function(Value)
		Environment.Settings.TeamCheck = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "ตรวจสอบสถานะมีชีวิต (Alive Check)",
	CurrentValue = Environment.Settings.AliveCheck,
	Flag = "AliveCheck",
	Callback = function(Value)
		Environment.Settings.AliveCheck = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "ตรวจสอบกำแพง (Wall Check)",
	CurrentValue = Environment.Settings.WallCheck,
	Flag = "WallCheck",
	Callback = function(Value)
		Environment.Settings.WallCheck = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "สุ่มเลือกส่วนที่ล็อค (Randomize Part)",
	CurrentValue = Environment.Settings.RandomizePart,
	Flag = "RandomizePart",
	Callback = function(Value)
		Environment.Settings.RandomizePart = Value
	end,
})

--// Tab: อื่นๆ

local MiscTab = Window:CreateTab("อื่นๆ", 4483362458)

local UIHideKey = "RightControl"
local UIHidden = false

local MiscUISection = MiscTab:CreateSection("ซ่อน/แสดง UI")

MiscTab:CreateKeybind({
	Name = "ปุ่มซ่อน/แสดง UI",
	CurrentKeybind = UIHideKey,
	HoldToInteract = false,
	Flag = "UIHideKey",
	Callback = function()
		UIHidden = not UIHidden
		local screenGui = game:GetService("CoreGui"):FindFirstChild("Starsation") or (gethui and gethui():FindFirstChild("Starsation"))
		if screenGui then
			screenGui.Enabled = not UIHidden
		end
	end,
})

MiscTab:CreateLabel("กด " .. UIHideKey .. " เพื่อซ่อน/แสดง UI")

local MiscSection = MiscTab:CreateSection("การจัดการ")

MiscTab:CreateButton({
	Name = "รีเซ็ตการตั้งค่า",
	Callback = function()
		Environment.Functions:ResetSettings()
		StarsationLibrary:Notify({Title = "Aimbot", Content = "รีเซ็ตการตั้งค่าเรียบร้อยแล้ว!", Duration = 3})
	end,
})

MiscTab:CreateButton({
	Name = "รีสตาร์ทสคริปต์",
	Callback = function()
		Environment.Functions:Restart()
		StarsationLibrary:Notify({Title = "Aimbot", Content = "รีสตาร์ทสคริปต์เรียบร้อยแล้ว!", Duration = 3})
	end,
})

MiscTab:CreateButton({
	Name = "ปิดสคริปต์",
	Callback = function()
		StarsationLibrary:Notify({Title = "Aimbot", Content = "กำลังปิดสคริปต์...", Duration = 2})
		task.wait(1)
		if Environment and Environment.Functions and Environment.Functions.Exit then
			Environment.Functions:Exit()
		end
	end,
})

local InfoSection = MiscTab:CreateSection("ข้อมูล")

MiscTab:CreateParagraph({
	Title = "Aimbot Script",
	Content = "สคริปต์ Silent Aim พร้อม FOV Circle\nUI โดย Starsation Interface\nHook: __namecall + NetworkModule2"
})
