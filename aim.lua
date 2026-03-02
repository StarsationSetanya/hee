local select, tonumber, tostring, pcall, getgenv, next, type, loadstring = select, tonumber, tostring, pcall, getgenv, next, type, loadstring
local Vector2new, Vector3new, CFramenew, Color3fromRGB, Drawingnew = Vector2.new, Vector3.new, CFrame.new, Color3.fromRGB, Drawing.new
local mathclamp, mathfloor = math.clamp, math.floor
local stringupper, stringmatch = string.upper, string.match
local mousemoverel = mousemoverel or (Input and Input.MouseMove)
local coroutinewrap = coroutine.wrap

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
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

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
local OriginalSensitivity = UserInputService.MouseDeltaSensitivity
local TweenService = game:GetService("TweenService")
local Animation = nil
local Running = false
local Typing = false

--// Script Settings

Environment.Settings = {
	Enabled = false,
	TeamCheck = false,
	AliveCheck = true,
	WallCheck = false,
	Sensitivity = 0,
	ThirdPerson = false,
	ThirdPersonSensitivity = 3,
	TriggerKey = "MouseButton2",
	Toggle = false,
	RandomizePart = false,
	LockPart = "Head",
	SendNotifications = true,
	SaveSettings = true,
	ReloadOnTeleport = true
}

Environment.FOVSettings = {
	Enabled = false,
	Visible = false,
	Amount = 90,
	Color = Color3.fromRGB(255, 255, 255),
	LockedColor = Color3.fromRGB(255, 70, 70),
	Transparency = 0.5,
	Sides = 60,
	Thickness = 1,
	Filled = false
}

Environment.FOVCircle = Drawingnew("Circle")

--// New Wall Hack ESP Settings
Environment.WrappedPlayers = {}

Environment.Visuals = {
    ESPSettings = {
        Enabled = false,
        TextColor = "20, 90, 255",
        TextSize = 14,
        Center = false,
        Outline = false,
        OutlineColor = "0, 0, 0",
        TextTransparency = 0.7,
        TextFont = (Drawing and Drawing.Fonts and Drawing.Fonts.Monospace) or 2, -- UI, System, Plex, Monospace
        DisplayDistance = false,
        DisplayHealth = false,
        DisplayName = false,
        Rainbow = false
    },

    TracersSettings = {
        Enabled = false,
        Type = 1, -- 1 - Bottom; 2 - Center; 3 - Mouse
        Transparency = 0.7,
        Thickness = 1,
        Color = "50, 120, 255",
        Rainbow = false
    },

    BoxSettings = {
        Enabled = false,
        Type = 1, -- 1 - 3D; 2 - 2D;
        Color = "50, 120, 255",
        Transparency = 0.7,
        Thickness = 1,
        Filled = false, -- For 2D
        Increase = 1,
        Rainbow = false
    },

    HeadDotSettings = {
        Enabled = false,
        Color = "50, 120, 255",
        Transparency = 0.5,
        Thickness = 1,
        Filled = false,
        Sides = 30,
        Size = 2,
        Rainbow = false
    }
}

Environment.Crosshair = {
    CrosshairSettings = {
        Enabled = false,
        Type = 1, -- 1 - Mouse; 2 - Center
        Size = 12,
        Thickness = 1,
        Color = "0, 255, 0",
        Transparency = 1,
        GapSize = 5,
        CenterDot = false,
        CenterDotColor = "0, 255, 0",
        CenterDotSize = 1,
        CenterDotTransparency = 1,
        CenterDotFilled = false,
        Rainbow = false
    },
    Parts = {
        LeftLine = Drawingnew("Line"),
        RightLine = Drawingnew("Line"),
        TopLine = Drawingnew("Line"),
        BottomLine = Drawingnew("Line"),
        CenterDot = Drawingnew("Circle")
    }
}

--// Core Functions

local function Encode(Table)
    if Table and type(Table) == "table" then
        local EncodedTable = HttpService:JSONEncode(Table)
        return EncodedTable
    end
end

local function Decode(String)
    if String and type(String) == "string" then
        local DecodedTable = HttpService:JSONDecode(String)
        return DecodedTable
    end
end

local function SendNotification(TitleArg, DescriptionArg, DurationArg)
    if Environment.Settings.SendNotifications then
        StarterGui:SetCore("SendNotification", {
            Title = TitleArg,
            Text = DescriptionArg,
            Duration = DurationArg
        })
    end
end

local function GetColor(Color)
    if type(Color) == "userdata" then return Color end
    local R = tonumber(stringmatch(Color, "([%d]+)[%s]*,[%s]*[%d]+[%s]*,[%s]*[%d]+"))
    local G = tonumber(stringmatch(Color, "[%d]+[%s]*,[%s]*([%d]+)[%s]*,[%s]*[%d]+"))
    local B = tonumber(stringmatch(Color, "[%d]+[%s]*,[%s]*[%d]+[%s]*,[%s]*([%d]+)"))
    return Color3fromRGB(R or 255, G or 255, B or 255)
end

local function GetRainbowColor()
    return Color3.fromHSV(tick() % 5 / 5, 1, 1)
end

local function GetPlayerTable(Player)
    for _, v in next, Environment.WrappedPlayers do
        if v.Name == Player.Name then
            return v
        end
    end
end

--// Visuals

local function AddESP(Player)
    local PlayerTable = GetPlayerTable(Player)
    if not PlayerTable then return end

    PlayerTable.ESP = Drawingnew("Text")

    PlayerTable.Connections.ESP = RunService.RenderStepped:Connect(function()
        if Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character:FindFirstChild("Head") and Player.Character:FindFirstChild("HumanoidRootPart") and Environment.Settings.Enabled then
            local Vector, OnScreen = Camera:WorldToViewportPoint(Player.Character.Head.Position)

            PlayerTable.ESP.Visible = Environment.Visuals.ESPSettings.Enabled

            local function UpdateESP_Internal()
                PlayerTable.ESP.Size = Environment.Visuals.ESPSettings.TextSize
                PlayerTable.ESP.Center = Environment.Visuals.ESPSettings.Center
                PlayerTable.ESP.Outline = Environment.Visuals.ESPSettings.Outline
                PlayerTable.ESP.OutlineColor = GetColor(Environment.Visuals.ESPSettings.OutlineColor)
                PlayerTable.ESP.Color = Environment.Visuals.ESPSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Visuals.ESPSettings.TextColor)
                PlayerTable.ESP.Transparency = Environment.Visuals.ESPSettings.TextTransparency
                PlayerTable.ESP.Font = Environment.Visuals.ESPSettings.TextFont

                PlayerTable.ESP.Position = Vector2new(Vector.X, Vector.Y - 25)

                local Parts = {
                    Health = "("..tostring(mathfloor(Player.Character.Humanoid.Health))..")",
                    Distance = "["..tostring(mathfloor((Player.Character.HumanoidRootPart.Position - (LocalPlayer.Character.HumanoidRootPart.Position or Vector3new(0, 0, 0))).Magnitude)).."]",
                    Name = Player.Name
                }

                local Content = ""

                if Environment.Visuals.ESPSettings.DisplayName then
                    Content = Parts.Name..Content
                end

                if Environment.Visuals.ESPSettings.DisplayHealth then
                    if Environment.Visuals.ESPSettings.DisplayName then
                        Content = Parts.Health.." "..Content
                    else
                        Content = Parts.Health..Content
                    end
                end

                if Environment.Visuals.ESPSettings.DisplayDistance then
                    Content = Content.." "..Parts.Distance
                end

                PlayerTable.ESP.Text = Content
            end

            if OnScreen then
                if Environment.Visuals.ESPSettings.Enabled then
                    local Checks = {Alive = true, Team = true}

                    if Environment.Settings.AliveCheck then
                        Checks.Alive = (Player.Character:FindFirstChild("Humanoid").Health > 0)
                    end

                    if Environment.Settings.TeamCheck then
                        Checks.Team = (Player.TeamColor ~= LocalPlayer.TeamColor)
                    end

                    if Checks.Alive and Checks.Team then
                        PlayerTable.ESP.Visible = true
                        UpdateESP_Internal()
                    else
                        PlayerTable.ESP.Visible = false
                    end
                end
            else
                PlayerTable.ESP.Visible = false
            end
        else
            PlayerTable.ESP.Visible = false
        end
    end)
end

local function AddTracer(Player)
    local PlayerTable = GetPlayerTable(Player)
    if not PlayerTable then return end

    PlayerTable.Tracer = Drawingnew("Line")

    PlayerTable.Connections.Tracer = RunService.RenderStepped:Connect(function()
        if Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character:FindFirstChild("HumanoidRootPart") and Environment.Settings.Enabled then
            local HRPCFrame, HRPSize = Player.Character.HumanoidRootPart.CFrame, Player.Character.HumanoidRootPart.Size
            local Vector, OnScreen = Camera:WorldToViewportPoint(HRPCFrame * CFramenew(0, -HRPSize.Y, 0).Position)

            PlayerTable.Tracer.Visible = Environment.Visuals.TracersSettings.Enabled

            local function UpdateTracer_Internal()
                PlayerTable.Tracer.Thickness = Environment.Visuals.TracersSettings.Thickness
                PlayerTable.Tracer.Color = Environment.Visuals.TracersSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Visuals.TracersSettings.Color)
                PlayerTable.Tracer.Transparency = Environment.Visuals.TracersSettings.Transparency

                PlayerTable.Tracer.To = Vector2new(Vector.X, Vector.Y)

                if Environment.Visuals.TracersSettings.Type == 1 then
                    PlayerTable.Tracer.From = Vector2new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                elseif Environment.Visuals.TracersSettings.Type == 2 then
                    PlayerTable.Tracer.From = Vector2new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                elseif Environment.Visuals.TracersSettings.Type == 3 then
                    PlayerTable.Tracer.From = Vector2new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
                else
                    PlayerTable.Tracer.From = Vector2new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                end
            end

            if OnScreen then
                if Environment.Visuals.TracersSettings.Enabled then
                    local Checks = {Alive = true, Team = true}

                    if Environment.Settings.AliveCheck then
                        Checks.Alive = (Player.Character:FindFirstChild("Humanoid").Health > 0)
                    end

                    if Environment.Settings.TeamCheck then
                        Checks.Team = (Player.TeamColor ~= LocalPlayer.TeamColor)
                    end

                    if Checks.Alive and Checks.Team then
                        PlayerTable.Tracer.Visible = true
                        UpdateTracer_Internal()
                    else
                        PlayerTable.Tracer.Visible = false
                    end
                end
            else
                PlayerTable.Tracer.Visible = false
            end
        else
            PlayerTable.Tracer.Visible = false
        end
    end)
end

local function AddBox(Player)
    local PlayerTable = GetPlayerTable(Player)
    if not PlayerTable then return end

    PlayerTable.Box.Square = Drawingnew("Square")
    PlayerTable.Box.TopLeftLine = Drawingnew("Line")
    PlayerTable.Box.TopRightLine = Drawingnew("Line")
    PlayerTable.Box.BottomLeftLine = Drawingnew("Line")
    PlayerTable.Box.BottomRightLine = Drawingnew("Line")

    PlayerTable.Connections.Box = RunService.RenderStepped:Connect(function()
            local function Visibility(Bool)
                if Environment.Visuals.BoxSettings.Type == 1 then
                    PlayerTable.Box.Square.Visible = false
                    PlayerTable.Box.TopLeftLine.Visible = Bool
                    PlayerTable.Box.TopRightLine.Visible = Bool
                    PlayerTable.Box.BottomLeftLine.Visible = Bool
                    PlayerTable.Box.BottomRightLine.Visible = Bool
                elseif Environment.Visuals.BoxSettings.Type == 2 then
                    PlayerTable.Box.Square.Visible = Bool
                    PlayerTable.Box.TopLeftLine.Visible = false
                    PlayerTable.Box.TopRightLine.Visible = false
                    PlayerTable.Box.BottomLeftLine.Visible = false
                    PlayerTable.Box.BottomRightLine.Visible = false
                end
            end

            local function VisibilityAll(Bool)
                PlayerTable.Box.Square.Visible = Bool
                PlayerTable.Box.TopLeftLine.Visible = Bool
                PlayerTable.Box.TopRightLine.Visible = Bool
                PlayerTable.Box.BottomLeftLine.Visible = Bool
                PlayerTable.Box.BottomRightLine.Visible = Bool
            end

        if Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character:FindFirstChild("Head") and Player.Character:FindFirstChild("HumanoidRootPart") and Environment.Settings.Enabled then
            local Vector, OnScreen = Camera:WorldToViewportPoint(Player.Character.HumanoidRootPart.Position)

            local HRPCFrame, HRPSize = Player.Character.HumanoidRootPart.CFrame, Player.Character.HumanoidRootPart.Size * Environment.Visuals.BoxSettings.Increase

            local TopLeftPosition = Camera:WorldToViewportPoint(HRPCFrame * CFramenew(HRPSize.X,  HRPSize.Y, 0).Position)
            local TopRightPosition = Camera:WorldToViewportPoint(HRPCFrame * CFramenew(-HRPSize.X,  HRPSize.Y, 0).Position)
            local BottomLeftPosition = Camera:WorldToViewportPoint(HRPCFrame * CFramenew(HRPSize.X, -HRPSize.Y, 0).Position)
            local BottomRightPosition = Camera:WorldToViewportPoint(HRPCFrame * CFramenew(-HRPSize.X, -HRPSize.Y, 0).Position)

            local HeadOffset = Camera:WorldToViewportPoint(Player.Character.Head.Position + Vector3new(0, 0.5, 0))
			local LegsOffset = Camera:WorldToViewportPoint(Player.Character.HumanoidRootPart.Position - Vector3new(0, 3, 0))

            local function Update2DBox()
                PlayerTable.Box.Square.Thickness = Environment.Visuals.BoxSettings.Thickness
                PlayerTable.Box.Square.Color = GetColor(Environment.Visuals.BoxSettings.Color)
                PlayerTable.Box.Square.Transparency = Environment.Visuals.BoxSettings.Transparency
                PlayerTable.Box.Square.Filled = Environment.Visuals.BoxSettings.Filled

                PlayerTable.Box.Square.Size = Vector2new(2000 / Vector.Z, HeadOffset.Y - LegsOffset.Y)
				PlayerTable.Box.Square.Position = Vector2new(Vector.X - PlayerTable.Box.Square.Size.X / 2, Vector.Y - PlayerTable.Box.Square.Size.Y / 2)
            end

            local function Update3DBox()
                PlayerTable.Box.TopLeftLine.Thickness = Environment.Visuals.BoxSettings.Thickness
                PlayerTable.Box.TopLeftLine.Transparency = Environment.Visuals.BoxSettings.Transparency
                PlayerTable.Box.TopLeftLine.Color = Environment.Visuals.BoxSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Visuals.BoxSettings.Color)

                PlayerTable.Box.TopRightLine.Thickness = Environment.Visuals.BoxSettings.Thickness
                PlayerTable.Box.TopRightLine.Transparency = Environment.Visuals.BoxSettings.Transparency
                PlayerTable.Box.TopRightLine.Color = Environment.Visuals.BoxSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Visuals.BoxSettings.Color)

                PlayerTable.Box.BottomLeftLine.Thickness = Environment.Visuals.BoxSettings.Thickness
                PlayerTable.Box.BottomLeftLine.Transparency = Environment.Visuals.BoxSettings.Transparency
                PlayerTable.Box.BottomLeftLine.Color = Environment.Visuals.BoxSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Visuals.BoxSettings.Color)

                PlayerTable.Box.BottomRightLine.Thickness = Environment.Visuals.BoxSettings.Thickness
                PlayerTable.Box.BottomRightLine.Transparency = Environment.Visuals.BoxSettings.Transparency
                PlayerTable.Box.BottomRightLine.Color = Environment.Visuals.BoxSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Visuals.BoxSettings.Color)

                PlayerTable.Box.TopLeftLine.From = Vector2new(TopLeftPosition.X, TopLeftPosition.Y)
                PlayerTable.Box.TopLeftLine.To = Vector2new(TopRightPosition.X, TopRightPosition.Y)

                PlayerTable.Box.TopRightLine.From = Vector2new(TopRightPosition.X, TopRightPosition.Y)
                PlayerTable.Box.TopRightLine.To = Vector2new(BottomRightPosition.X, BottomRightPosition.Y)

                PlayerTable.Box.BottomLeftLine.From = Vector2new(BottomLeftPosition.X, BottomLeftPosition.Y)
                PlayerTable.Box.BottomLeftLine.To = Vector2new(TopLeftPosition.X, TopLeftPosition.Y)

                PlayerTable.Box.BottomRightLine.From = Vector2new(BottomRightPosition.X, BottomRightPosition.Y)
                PlayerTable.Box.BottomRightLine.To = Vector2new(BottomLeftPosition.X, BottomLeftPosition.Y)
            end

            if OnScreen then
                if Environment.Visuals.BoxSettings.Enabled then
                    local Checks = {Alive = true, Team = true}

                    if Environment.Settings.AliveCheck then
                        Checks.Alive = (Player.Character:FindFirstChild("Humanoid").Health > 0)
                    end

                    if Environment.Settings.TeamCheck then
                        Checks.Team = (Player.TeamColor ~= LocalPlayer.TeamColor)
                    end

                    if Checks.Alive and Checks.Team then
                        Visibility(true)
                        if Environment.Visuals.BoxSettings.Type == 1 then
                            Update3DBox()
                        else
                            Update2DBox()
                        end
                    else
                        VisibilityAll(false)
                    end
                end
            else
                VisibilityAll(false)
            end
        else
            VisibilityAll(false)
        end
    end)
end

local function AddHeadDot(Player)
    local PlayerTable = GetPlayerTable(Player)
    if not PlayerTable then return end

    PlayerTable.HeadDot = Drawingnew("Circle")

    PlayerTable.Connections.HeadDot = RunService.RenderStepped:Connect(function()
        if Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character:FindFirstChild("Head") and Environment.Settings.Enabled then
            local Vector, OnScreen = Camera:WorldToViewportPoint(Player.Character.Head.Position)

            PlayerTable.HeadDot.Visible = Environment.Visuals.HeadDotSettings.Enabled

            local function UpdateHeadDot_Internal()
                PlayerTable.HeadDot.Thickness = Environment.Visuals.HeadDotSettings.Thickness
                PlayerTable.HeadDot.Color = Environment.Visuals.HeadDotSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Visuals.HeadDotSettings.Color)
                PlayerTable.HeadDot.Transparency = Environment.Visuals.HeadDotSettings.Transparency
                PlayerTable.HeadDot.NumSides = Environment.Visuals.HeadDotSettings.Sides
                PlayerTable.HeadDot.Filled = Environment.Visuals.HeadDotSettings.Filled
                PlayerTable.HeadDot.Radius = Environment.Visuals.HeadDotSettings.Size

                PlayerTable.HeadDot.Position = Vector2new(Vector.X, Vector.Y)
            end

            if OnScreen then
                if Environment.Visuals.HeadDotSettings.Enabled then
                    local Checks = {Alive = true, Team = true}

                    if Environment.Settings.AliveCheck then
                        Checks.Alive = (Player.Character:FindFirstChild("Humanoid").Health > 0)
                    end

                    if Environment.Settings.TeamCheck then
                        Checks.Team = (Player.TeamColor ~= LocalPlayer.TeamColor)
                    end

                    if Checks.Alive and Checks.Team then
                        PlayerTable.HeadDot.Visible = true
                        UpdateHeadDot_Internal()
                    else
                        PlayerTable.HeadDot.Visible = false
                    end
                end
            else
                PlayerTable.HeadDot.Visible = false
            end
        else
            PlayerTable.HeadDot.Visible = false
        end
    end)
end

local function AddCrosshair()
    local AxisX, AxisY = nil, nil

    pcall(function()
        ServiceConnections.AxisConnection = RunService.RenderStepped:Connect(function()
            if Environment.Crosshair.CrosshairSettings.Type == 1 then
                AxisX, AxisY = UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y
            elseif Environment.Crosshair.CrosshairSettings.Type == 2 then
                AxisX, AxisY = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
            else
                Environment.Crosshair.CrosshairSettings.Type = 1
            end
        end)
        
        ServiceConnections.CrosshairConnection = RunService.RenderStepped:Connect(function()
            if not AxisX or not AxisY then return end

            local CrosshairColor = Environment.Crosshair.CrosshairSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Crosshair.CrosshairSettings.Color)

            --// Left Line
            Environment.Crosshair.Parts.LeftLine.Visible = Environment.Settings.Enabled and Environment.Crosshair.CrosshairSettings.Enabled
            Environment.Crosshair.Parts.LeftLine.Color = CrosshairColor
            Environment.Crosshair.Parts.LeftLine.Thickness = Environment.Crosshair.CrosshairSettings.Thickness
            Environment.Crosshair.Parts.LeftLine.Transparency = Environment.Crosshair.CrosshairSettings.Transparency
            Environment.Crosshair.Parts.LeftLine.From = Vector2new(AxisX + Environment.Crosshair.CrosshairSettings.GapSize, AxisY)
            Environment.Crosshair.Parts.LeftLine.To = Vector2new(AxisX + Environment.Crosshair.CrosshairSettings.Size, AxisY)

            --// Right Line
            Environment.Crosshair.Parts.RightLine.Visible = Environment.Settings.Enabled and Environment.Crosshair.CrosshairSettings.Enabled
            Environment.Crosshair.Parts.RightLine.Color = CrosshairColor
            Environment.Crosshair.Parts.RightLine.Thickness = Environment.Crosshair.CrosshairSettings.Thickness
            Environment.Crosshair.Parts.RightLine.Transparency = Environment.Crosshair.CrosshairSettings.Transparency
            Environment.Crosshair.Parts.RightLine.From = Vector2new(AxisX - Environment.Crosshair.CrosshairSettings.GapSize, AxisY)
            Environment.Crosshair.Parts.RightLine.To = Vector2new(AxisX - Environment.Crosshair.CrosshairSettings.Size, AxisY)

            --// Top Line
            Environment.Crosshair.Parts.TopLine.Visible = Environment.Settings.Enabled and Environment.Crosshair.CrosshairSettings.Enabled
            Environment.Crosshair.Parts.TopLine.Color = CrosshairColor
            Environment.Crosshair.Parts.TopLine.Thickness = Environment.Crosshair.CrosshairSettings.Thickness
            Environment.Crosshair.Parts.TopLine.Transparency = Environment.Crosshair.CrosshairSettings.Transparency
            Environment.Crosshair.Parts.TopLine.From = Vector2new(AxisX, AxisY + Environment.Crosshair.CrosshairSettings.GapSize)
            Environment.Crosshair.Parts.TopLine.To = Vector2new(AxisX, AxisY + Environment.Crosshair.CrosshairSettings.Size)

            --// Bottom Line
            Environment.Crosshair.Parts.BottomLine.Visible = Environment.Settings.Enabled and Environment.Crosshair.CrosshairSettings.Enabled
            Environment.Crosshair.Parts.BottomLine.Color = CrosshairColor
            Environment.Crosshair.Parts.BottomLine.Thickness = Environment.Crosshair.CrosshairSettings.Thickness
            Environment.Crosshair.Parts.BottomLine.Transparency = Environment.Crosshair.CrosshairSettings.Transparency
            Environment.Crosshair.Parts.BottomLine.From = Vector2new(AxisX, AxisY - Environment.Crosshair.CrosshairSettings.GapSize)
            Environment.Crosshair.Parts.BottomLine.To = Vector2new(AxisX, AxisY - Environment.Crosshair.CrosshairSettings.Size)

            --// Center Dot
            Environment.Crosshair.Parts.CenterDot.Visible = Environment.Settings.Enabled and Environment.Crosshair.CrosshairSettings.Enabled and Environment.Crosshair.CrosshairSettings.CenterDot
            Environment.Crosshair.Parts.CenterDot.Color = Environment.Crosshair.CrosshairSettings.Rainbow and GetRainbowColor() or GetColor(Environment.Crosshair.CrosshairSettings.CenterDotColor)
            Environment.Crosshair.Parts.CenterDot.Radius = Environment.Crosshair.CrosshairSettings.CenterDotSize
            Environment.Crosshair.Parts.CenterDot.Transparency = Environment.Crosshair.CrosshairSettings.CenterDotTransparency
            Environment.Crosshair.Parts.CenterDot.Filled = Environment.Crosshair.CrosshairSettings.CenterDotFilled
            Environment.Crosshair.Parts.CenterDot.Position = Vector2new(AxisX, AxisY)
        end)
    end)
end

--// Aimbot Functions

local function CancelLock()
	Environment.Locked = nil
	if Animation then Animation:Cancel() end
	UserInputService.MouseDeltaSensitivity = OriginalSensitivity
end

local function GetClosestPlayer()
	if not Environment.Locked then
		local RequiredDistance = (Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000)

		for _, v in next, Players:GetPlayers() do
			if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild(Environment.Settings.LockPart) and v.Character:FindFirstChildOfClass("Humanoid") then
				if Environment.Settings.TeamCheck and v.Team == LocalPlayer.Team then continue end
				if Environment.Settings.AliveCheck and v.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
				
				-- Wall Check: ใช้ Raycast เพื่อตรวจสอบว่ามีกำแพงบังหรือไม่
				if Environment.Settings.WallCheck then
					local TargetPart = v.Character[Environment.Settings.LockPart]
					local CameraPosition = Camera.CFrame.Position
					local Direction = (TargetPart.Position - CameraPosition)
					local RaycastParams = RaycastParams.new()
					RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
					local FilterList = {v.Character}
					if LocalPlayer.Character then
						table.insert(FilterList, LocalPlayer.Character)
					end
					RaycastParams.FilterDescendantsInstances = FilterList
					
					local RaycastResult = workspace:Raycast(CameraPosition, Direction, RaycastParams)
					if RaycastResult and RaycastResult.Instance then
						-- ถ้ามีอะไรบัง (ไม่ใช่ตัวเป้าหมายเอง) ให้ข้าม
						local HitPart = RaycastResult.Instance
						if not HitPart:IsDescendantOf(v.Character) then
							continue
						end
					end
				end

				local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[Environment.Settings.LockPart].Position)
				local MousePos = UserInputService:GetMouseLocation()
				local Distance = (Vector2new(MousePos.X, MousePos.Y) - Vector2new(Vector.X, Vector.Y)).Magnitude

				if Distance < RequiredDistance and OnScreen then
					RequiredDistance = Distance
					Environment.Locked = v
					
					if Environment.Settings.RandomizePart then
						local Parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
						Environment.Settings.LockPart = Parts[math.random(1, #Parts)]
					end
				end
			end
		end
	elseif (UserInputService:GetMouseLocation() - (function()
			local Vector, _ = Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position)
			return Vector2new(Vector.X, Vector.Y)
		end)()).Magnitude > (Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000) then
		CancelLock()
	end
end

--// Functions

local function SaveSettings()
    if Environment.Settings.SaveSettings then
        if not isfolder("Exunys Developer") then makefolder("Exunys Developer") end
        if not isfolder("Exunys Developer/Wall Hack") then makefolder("Exunys Developer/Wall Hack") end
        
        pcall(function()
            writefile("Exunys Developer/Wall Hack/Configuration.json", HttpService:JSONEncode(Environment.Settings))
            writefile("Exunys Developer/Wall Hack/Visuals.json", HttpService:JSONEncode(Environment.Visuals))
            writefile("Exunys Developer/Wall Hack/Crosshair.json", HttpService:JSONEncode(Environment.Crosshair.CrosshairSettings))
        end)
    end
end

local function Wrap(Player)
    local Value = {
        Name = Player.Name,
        Connections = {},
        ESP = nil,
        Tracer = nil,
        HeadDot = nil,
        Box = {Square = nil, TopLeftLine = nil, TopRightLine = nil, BottomLeftLine = nil, BottomRightLine = nil}
    }

    local Table = nil
    for _, v in next, Environment.WrappedPlayers do
        if v.Name == Player.Name then
            Table = v
            break
        end
    end

    if not Table then
        Environment.WrappedPlayers[#Environment.WrappedPlayers + 1] = Value
        AddESP(Player)
        AddTracer(Player)
        AddBox(Player)
        AddHeadDot(Player)
    end
end

local function UnWrap(Player)
    local Table, Index = nil, nil

    for i, v in next, Environment.WrappedPlayers do
        if v.Name == Player.Name then
            Table, Index = v, i
            break
        end
    end

    if Table then
        for _, v in next, Table.Connections do
            v:Disconnect()
        end

        if Table.ESP then Table.ESP:Remove() end
        if Table.Tracer then Table.Tracer:Remove() end
        if Table.HeadDot then Table.HeadDot:Remove() end

        for _, v in next, Table.Box do
            if v then v:Remove() end
        end

        table.remove(Environment.WrappedPlayers, Index)
    end
end

local function Load()
    OriginalSensitivity = UserInputService.MouseDeltaSensitivity

    -- Initialize ESP for current players
    for _, v in next, Players:GetPlayers() do
        if v ~= LocalPlayer then
            Wrap(v)
        end
    end

    ServiceConnections.PlayerAddedConnection = Players.PlayerAdded:Connect(function(v)
        if v ~= LocalPlayer then
            Wrap(v)
        end
    end)

    ServiceConnections.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(v)
        if v ~= LocalPlayer then
            UnWrap(v)
        else
            SaveSettings()
        end
    end)

    -- Aimbot & Visuals Loop
    ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
        -- FOV Circle
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

        -- Aimbot Targetting
        if Running and Environment.Settings.Enabled then
            GetClosestPlayer()

            if Environment.Locked then
                if Environment.Settings.ThirdPerson then
                    local Vector = Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position)
                    if mousemoverel then
                        mousemoverel((Vector.X - UserInputService:GetMouseLocation().X) * Environment.Settings.ThirdPersonSensitivity, (Vector.Y - UserInputService:GetMouseLocation().Y) * Environment.Settings.ThirdPersonSensitivity)
                    end
                else
                    if Environment.Settings.Sensitivity > 0 then
                        Animation = TweenService:Create(Camera, TweenInfo.new(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)})
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

    -- Aimbot Input Handling
    ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
        if not Typing then
            pcall(function()
                local Key = #Environment.Settings.TriggerKey == 1 and stringupper(Environment.Settings.TriggerKey) or Environment.Settings.TriggerKey
                if (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) or (Input.UserInputType.Name == Key) then
                    if Environment.Settings.Toggle then
                        Running = not Running
                        if not Running then CancelLock() end
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

    ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function() Typing = true end)
    ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)
    
    -- Load Crosshair
    AddCrosshair()
end

--// Script Functions

Environment.Functions = {}

function Environment.Functions:Exit()
    SaveSettings()

    for _, v in next, ServiceConnections do
        v:Disconnect()
    end

    for _, v in next, Players:GetPlayers() do
        if v ~= LocalPlayer then
            UnWrap(v)
        end
    end

    if Environment.FOVCircle then Environment.FOVCircle:Remove() end

    for _, v in next, Environment.Crosshair.Parts do
        v:Remove()
    end

    getgenv().Aimbot = nil
end

function Environment.Functions:Restart()
    Environment.Functions:Exit()
    task.wait(0.1)
    Load()
end

function Environment.Functions:ResetSettings()
    -- Reset to default values
    Environment.Settings.Enabled = false
    Environment.Settings.TeamCheck = false
    Environment.Settings.AliveCheck = true
    Environment.Settings.WallCheck = false
    
    Environment.Visuals.ESPSettings.Enabled = true
    Environment.Visuals.TracersSettings.Enabled = true
    Environment.Visuals.BoxSettings.Enabled = true
    Environment.Visuals.HeadDotSettings.Enabled = true
    
    SaveSettings()
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
	Name = "Aimbot ใช้ได้ทุกเกมยกเว้น Hypershot 😭😭😭",
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
			local currentStatus = (Running and Environment.Locked) and "🔴 Locked : " .. Environment.Locked.Name or (Running and "🟡 Looking for a target...") or "🟢 Ready"
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

--// Tab: ESP

local ESPTab = Window:CreateTab("ESP & Visuals", 4483362458)

-- local ESPStatusSection = ESPTab:CreateSection("สถานะ ESP")
-- local ESPStatusLabel = ESPTab:CreateLabel("สถานะ ESP: " .. (Environment.Visuals.ESPSettings.Enabled and "🟢 Enabled" or "🔴 Disabled"))

-- task.spawn(function()
--     while task.wait(0.5) do
--         if ESPStatusLabel and ESPStatusLabel.Set then
--             local currentStatus = Environment.Visuals.ESPSettings.Enabled and "🟢 Enabled" or "🔴 Disabled"
--             ESPStatusLabel:Set("สถานะ ESP: " .. currentStatus)
--         end
--     end
-- end)

local ESPMainSection = ESPTab:CreateSection("ESP (ตัวอักษร)")

ESPTab:CreateToggle({
    Name = "เปิดใช้งาน ESP",
    CurrentValue = Environment.Visuals.ESPSettings.Enabled,
    Flag = "ESPEnabled",
    Callback = function(Value)
        Environment.Visuals.ESPSettings.Enabled = Value
    end,
})

ESPTab:CreateToggle({
    Name = "แสดงชื่อ (Show Name)",
    CurrentValue = Environment.Visuals.ESPSettings.DisplayName,
    Flag = "ESPShowName",
    Callback = function(Value)
        Environment.Visuals.ESPSettings.DisplayName = Value
    end,
})

ESPTab:CreateToggle({
    Name = "แสดงระยะทาง (Show Distance)",
    CurrentValue = Environment.Visuals.ESPSettings.DisplayDistance,
    Flag = "ESPShowDistance",
    Callback = function(Value)
        Environment.Visuals.ESPSettings.DisplayDistance = Value
    end,
})

ESPTab:CreateToggle({
    Name = "แสดง HP (Show Health)",
    CurrentValue = Environment.Visuals.ESPSettings.DisplayHealth,
    Flag = "ESPShowHealth",
    Callback = function(Value)
        Environment.Visuals.ESPSettings.DisplayHealth = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Rainbow Text (สีรุ้ง)",
    CurrentValue = Environment.Visuals.ESPSettings.Rainbow,
    Flag = "ESPTextRainbow",
    Callback = function(Value)
        Environment.Visuals.ESPSettings.Rainbow = Value
    end,
})

ESPTab:CreateColorPicker({
    Name = "สีตัวอักษร",
    Color = GetColor(Environment.Visuals.ESPSettings.TextColor),
    Flag = "ESPTextColor",
    Callback = function(Value)
        Environment.Visuals.ESPSettings.TextColor = tostring(mathfloor(Value.R * 255))..", "..tostring(mathfloor(Value.G * 255))..", "..tostring(mathfloor(Value.B * 255))
    end,
})

ESPTab:CreateSlider({
    Name = "ขนาดตัวอักษร",
    Range = {10, 30},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Environment.Visuals.ESPSettings.TextSize,
    Flag = "ESPTextSize",
    Callback = function(Value)
        Environment.Visuals.ESPSettings.TextSize = Value
    end,
})

local TracerSection = ESPTab:CreateSection("Tracers (เส้นลาก)")

ESPTab:CreateToggle({
    Name = "เปิดใช้งาน Tracers",
    CurrentValue = Environment.Visuals.TracersSettings.Enabled,
    Flag = "TracersEnabled",
    Callback = function(Value)
        Environment.Visuals.TracersSettings.Enabled = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Rainbow Tracers (สีรุ้ง)",
    CurrentValue = Environment.Visuals.TracersSettings.Rainbow,
    Flag = "TracersRainbow",
    Callback = function(Value)
        Environment.Visuals.TracersSettings.Rainbow = Value
    end,
})

ESPTab:CreateColorPicker({
    Name = "สีเส้นลาก",
    Color = GetColor(Environment.Visuals.TracersSettings.Color),
    Flag = "TracersColor",
    Callback = function(Value)
        Environment.Visuals.TracersSettings.Color = tostring(mathfloor(Value.R * 255))..", "..tostring(mathfloor(Value.G * 255))..", "..tostring(mathfloor(Value.B * 255))
    end,
})

ESPTab:CreateDropdown({
    Name = "ประเภทเส้นลาก",
    Options = {"Bottom", "Center", "Mouse"},
    CurrentOption = {Environment.Visuals.TracersSettings.Type == 1 and "Bottom" or Environment.Visuals.TracersSettings.Type == 2 and "Center" or "Mouse"},
    MultipleOptions = false,
    Flag = "TracersType",
    Callback = function(Options)
        Environment.Visuals.TracersSettings.Type = (Options[1] == "Bottom" and 1 or Options[1] == "Center" and 2 or 3)
    end,
})

local BoxSection = ESPTab:CreateSection("Box (กล่อง)")

ESPTab:CreateToggle({
    Name = "เปิดใช้งาน Box",
    CurrentValue = Environment.Visuals.BoxSettings.Enabled,
    Flag = "BoxEnabled",
    Callback = function(Value)
        Environment.Visuals.BoxSettings.Enabled = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Rainbow Box (สีรุ้ง)",
    CurrentValue = Environment.Visuals.BoxSettings.Rainbow,
    Flag = "BoxRainbow",
    Callback = function(Value)
        Environment.Visuals.BoxSettings.Rainbow = Value
    end,
})

ESPTab:CreateColorPicker({
    Name = "สีกล่อง",
    Color = GetColor(Environment.Visuals.BoxSettings.Color),
    Flag = "BoxColor",
    Callback = function(Value)
        Environment.Visuals.BoxSettings.Color = tostring(mathfloor(Value.R * 255))..", "..tostring(mathfloor(Value.G * 255))..", "..tostring(mathfloor(Value.B * 255))
    end,
})

ESPTab:CreateDropdown({
    Name = "ประเภทกล่อง",
    Options = {"3D", "2D"},
    CurrentOption = {Environment.Visuals.BoxSettings.Type == 1 and "3D" or "2D"},
    MultipleOptions = false,
    Flag = "BoxType",
    Callback = function(Options)
        Environment.Visuals.BoxSettings.Type = (Options[1] == "3D" and 1 or 2)
    end,
})

local HeadDotSection = ESPTab:CreateSection("Head Dot (จุดหัว)")

ESPTab:CreateToggle({
    Name = "เปิดใช้งาน Head Dot",
    CurrentValue = Environment.Visuals.HeadDotSettings.Enabled,
    Flag = "HeadDotEnabled",
    Callback = function(Value)
        Environment.Visuals.HeadDotSettings.Enabled = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Rainbow Head Dot (สีรุ้ง)",
    CurrentValue = Environment.Visuals.HeadDotSettings.Rainbow,
    Flag = "HeadDotRainbow",
    Callback = function(Value)
        Environment.Visuals.HeadDotSettings.Rainbow = Value
    end,
})

ESPTab:CreateColorPicker({
    Name = "สีจุดหัว",
    Color = GetColor(Environment.Visuals.HeadDotSettings.Color),
    Flag = "HeadDotColor",
    Callback = function(Value)
        Environment.Visuals.HeadDotSettings.Color = tostring(mathfloor(Value.R * 255))..", "..tostring(mathfloor(Value.G * 255))..", "..tostring(mathfloor(Value.B * 255))
    end,
})

local CrosshairTab = Window:CreateTab("Crosshair", 4483362458)

local CrosshairSection = CrosshairTab:CreateSection("ตั้งค่าเป้าเล็ง")

CrosshairTab:CreateToggle({
    Name = "เปิดใช้งาน Crosshair",
    CurrentValue = Environment.Crosshair.CrosshairSettings.Enabled,
    Flag = "CrosshairEnabled",
    Callback = function(Value)
        Environment.Crosshair.CrosshairSettings.Enabled = Value
    end,
})

CrosshairTab:CreateToggle({
    Name = "Rainbow Crosshair (สีรุ้ง)",
    CurrentValue = Environment.Crosshair.CrosshairSettings.Rainbow,
    Flag = "CrosshairRainbow",
    Callback = function(Value)
        Environment.Crosshair.CrosshairSettings.Rainbow = Value
    end,
})

CrosshairTab:CreateSlider({
    Name = "ขนาดเป้า",
    Range = {5, 50},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Environment.Crosshair.CrosshairSettings.Size,
    Flag = "CrosshairSize",
    Callback = function(Value)
        Environment.Crosshair.CrosshairSettings.Size = Value
    end,
})

CrosshairTab:CreateSlider({
    Name = "ช่องว่างกลาง",
    Range = {0, 20},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Environment.Crosshair.CrosshairSettings.GapSize,
    Flag = "CrosshairGap",
    Callback = function(Value)
        Environment.Crosshair.CrosshairSettings.GapSize = Value
    end,
})

CrosshairTab:CreateToggle({
    Name = "จุดกลางเลือกได้ (Center Dot)",
    CurrentValue = Environment.Crosshair.CrosshairSettings.CenterDot,
    Flag = "CrosshairCenterDot",
    Callback = function(Value)
        Environment.Crosshair.CrosshairSettings.CenterDot = Value
    end,
})

CrosshairTab:CreateColorPicker({
    Name = "สีเป้าเล็ง",
    Color = GetColor(Environment.Crosshair.CrosshairSettings.Color),
    Flag = "CrosshairColor",
    Callback = function(Value)
        Environment.Crosshair.CrosshairSettings.Color = tostring(mathfloor(Value.R * 255))..", "..tostring(mathfloor(Value.G * 255))..", "..tostring(mathfloor(Value.B * 255))
    end,
})

--// Tab: อื่นๆ

local MiscTab = Window:CreateTab("Other", 4483362458)

-- local UIHideKey = "RightControl"
-- local UIHidden = false

local MiscUISection = MiscTab:CreateSection("ยังไม่เสร็จ")

-- MiscTab:CreateKeybind({
-- 	Name = "ปุ่มซ่อน / แสดง UI",
-- 	CurrentKeybind = UIHideKey,
-- 	HoldToInteract = false,
-- 	Flag = "UIHideKey",
-- 	Callback = function()
-- 		UIHidden = not UIHidden
-- 		local screenGui = game:GetService("CoreGui"):FindFirstChild("Starsation") or (gethui and gethui():FindFirstChild("Starsation"))
-- 		if screenGui then
-- 			screenGui.Enabled = not UIHidden
-- 		end
-- 	end,
-- })

-- MiscTab:CreateLabel("กด " .. UIHideKey .. " เพื่อซ่อน / แสดง UI")

-- local MiscSection = MiscTab:CreateSection("การจัดการ")

-- MiscTab:CreateButton({
-- 	Name = "รีเซ็ตการตั้งค่า",
-- 	Callback = function()
-- 		Environment.Functions:ResetSettings()
-- 		StarsationLibrary:Notify({Title = "Aimbot", Content = "รีเซ็ตการตั้งค่าเรียบร้อยแล้ว!", Duration = 3})
-- 	end,
-- })

-- MiscTab:CreateButton({
-- 	Name = "รีสตาร์ทสคริปต์",
-- 	Callback = function()
-- 		Environment.Functions:Restart()
-- 		StarsationLibrary:Notify({Title = "Aimbot", Content = "รีสตาร์ทสคริปต์เรียบร้อยแล้ว!", Duration = 3})
-- 	end,
-- })

-- MiscTab:CreateButton({
-- 	Name = "ปิดสคริปต์",
-- 	Callback = function()
-- 		StarsationLibrary:Notify({Title = "Aimbot", Content = "กำลังปิดสคริปต์...", Duration = 2})
-- 		task.wait(1)
-- 		if Environment and Environment.Functions and Environment.Functions.Exit then
-- 			Environment.Functions:Exit()
-- 		end
-- 	end,
-- })

local InfoSection = MiscTab:CreateSection("ข้อมูล")

MiscTab:CreateParagraph({
	Title = "Aimbot Script",
	Content = "พ่อมึงอะ น่าหี สูตรลาบ วัตถุดิบลาบหมู หมูสับ 300 กรัม น้ำเปล่า ½ ถ้วย ต้นหอมซอย 2 ต้น ใบสะระแหน่ 2 ต้น ผักชีฝรั่งซอย 2 ต้น หอมแดงซอย 3 กลีบ พริกป่น 2 ช้อนโต๊ะ น้ำปลา 2 ช้อนโต๊ะ น้ำมะนาว 2 ช้อนโต๊ะ ข้าวคั่ว 2 ช้อนโต๊ะ น้ำตาล ½ ช้อนชา พริกแห้งทอดสำหรับตกแต่ง วิธีทําลาบหมู STEP 1 : รวนหมูสับ ใส่น้ำเปล่าลงในหม้อ แล้วใส่หมูสับลงไปรวนให้สุก TIP : การเติมน้ำลงในเนื้อหมูจะช่วยให้เนื้อหมูฉ่ำไม่แข็งกระด้าง และควรใช้ทัพพีขยี้หมูให้แตกออกจากกัน STEP 2 : ปรุงรสลาบหมู ตักหมูที่รวนแล้วใส่ในชามผสม ใส่เครื่องปรุง พริกป่น น้ำปลา ข้าวคั่ว และน้ำตาล คลุกเค้าให้เข้ากัน จากนั้นเติมมะนาว ผักชีฝรั่ง หอมแดงซอย ต้มหอม ผักชีฝรั่ง และใบสะระแหน่ จากนั้นคลุกเคล้าให้เข้ากัน STEP 3 : จัดเสิร์ฟ ตัก “ลาบหมู” ลงใส่จานที่ต้องการจัดเสิร์ฟ ตกแต่งด้วยพริกแห้งทอด และใบสะระแหน่ กินคู่กับผักเคียง แค่นี้ก็เสร็จแล้ว"
})
