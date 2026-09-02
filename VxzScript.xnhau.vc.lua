local WindUI = loadstring(game:HttpGet(
 "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Alurt = loadstring(game:HttpGet(
 "https://raw.githubusercontent.com/azir-py/project/refs/heads/main/Zwolf/AlurtUI.lua"
))()

local function NotifyFeature(featureName, enabled)
 pcall(function()
 Alurt.CreateNode({
 Title = featureName .. (enabled and " ON" or " OFF"),
 Content = enabled and (featureName .. " đã được bật") or (featureName .. " đã được tắt"),
 Audio = "rbxassetid://17208361335",
 Length = 3,
 Image = "rbxassetid://6031068421",
 BarColor = enabled and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(255, 75, 75)
 })
 end)
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ===== CẤU HÌNH =====
local Config = {
 Godmode = false,
 BoostLevel = 1,
 MinBoost = 1,
 MaxBoost = 30,
 BaseWalkSpeed = 16,
 PromptDistance = 30,
 PromptHoldDuration = 0,
 DeleteTrap = false,
 EspTrap = false,
 AntiTrapBeta = false,
 EspParasite = false,
 DeleteTreadmill = false,
 AntiRagdoll = false,
 InstantEgg = false,
 AutoBat = false,
 EspPlayer = false,
 AutoAttackBloom = false,
 AutoFixLagOnEnable = true,
 AutoStealBest = false,
 FlightHeight = 70,
 NoclipEnabled = false,
 BASE_POS = Vector3.new(543.38, 68.58, -359.13)
}

local Connections = {
 Heartbeat = nil,
 RenderStepped = nil,
 CharacterAdded = nil,
 WorkspaceAdded = nil,
 WorkspaceRemoving = nil,
 HealthChanged = nil,
 TrapAdded = nil,
 TrapCleanup = nil,
 TrapESP = nil,
 ParasiteESP = nil,
 TreadmillAdded = nil,
 TreadmillCleanup = nil,
 AntiRagdoll = nil,
 InstantEgg = nil,
 AutoBat = nil,
 EspPlayer = nil,
 AutoAttackBloom = nil,
 AutoStealLoop = nil
}

local TrapCache = {}
local ParasiteCache = {}
local TreadmillCache = {}
local EggPromptCache = {}
local TrapESPObjects = {}
local ParasiteESPObjects = {}
local PlayerESPObjects = {}

local TargetPrompt = nil
local PromptLoopRunning = false
local LastRagdollReset = 0
local AntiRagdollResetCooldown = 0

local ATTACK_RANGE = 20

local BAT_NAMES = {
 "bat",
 "gậy"
}

local HUM_PROPERTIES = {
 "RigType", "HipHeight", "JumpPower", "JumpHeight", "UseJumpPower",
 "AutoRotate", "MaxSlopeAngle", "DisplayDistanceType", "NameDisplayDistance",
 "HealthDisplayDistance", "AutomaticScalingEnabled", "BreakJointsOnDeath",
 "RequiresNeck", "EvaluateStateMachine"
}
local TRAP_WORDS = { "trap", "cage", "snare" }
local PARASITE_WORDS = { "parasite", "parasites" }

local function ApplyFixLagAuto()
 if not Config.AutoFixLagOnEnable then return end
 pcall(function()
 local settingsObj = settings()
 settingsObj.Rendering.QualityLevel = Enum.QualityLevel.Level01
 settingsObj.Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
 local lighting = game:GetService("Lighting")
 lighting.GlobalShadows = false
 lighting.FogEnd = 9e9
 lighting.Technology = Enum.Technology.Compatibility
 if setfpscap then setfpscap(9999999) end
 end)
end

local function FormatSpeedNumber(val)
 local num = tonumber(val)
 if not num then return tostring(val or "N/A") end
 if num >= 1e12 then return string.format("%.2fT", num / 1e12)
 elseif num >= 1e9 then return string.format("%.2fB", num / 1e9)
 elseif num >= 1e6 then return string.format("%.2fM", num / 1e6)
 elseif num >= 1e3 then return string.format("%.2fK", num / 1e3)
 else return string.format("%d", math.floor(num)) end
end

local function DisconnectConnection(name)
 local connection = Connections[name]
 if connection then
 pcall(function() connection:Disconnect() end)
 Connections[name] = nil
 end
end

local function GetCharacter()
 return LocalPlayer.Character
end

local function GetHumanoid(character)
 if not character then return nil end
 return character:FindFirstChildOfClass("Humanoid")
end

local function GetRoot(character)
 if not character then return nil end
 return character:FindFirstChild("HumanoidRootPart")
end

local function GetAdaptiveSpeed()
 local boost = math.clamp(tonumber(Config.BoostLevel) or Config.MinBoost, Config.MinBoost, Config.MaxBoost)
 return Config.BaseWalkSpeed + (boost * 40)
end

local TreadmillKeywords = {
 "treadmill", "máy chạy", "may chay", "running machine"
}

local function NormalizeName(value)
 value = tostring(value or "")
 value = string.lower(value)
 return value
end

local function ContainsKeyword(text, keywordsList)
 text = NormalizeName(text)
 for _, keyword in ipairs(keywordsList) do
 if string.find(text, keyword, 1, true) then return true end
 end
 return false
end

local function IsTrapObject(object)
 if not object or object == Workspace then return false end
 if ContainsKeyword(object.Name, TRAP_WORDS) then return true end
 local attributes = { "Trap", "Type", "ObjectType", "ItemType", "Name", "DisplayName" }
 for _, attributeName in ipairs(attributes) do
 local success, value = pcall(function() return object:GetAttribute(attributeName) end)
 if success and value ~= nil then
 if ContainsKeyword(value, TRAP_WORDS) then return true end
 end
 end
 return false
end

local function IsParasiteObject(object)
 if not object or object == Workspace then return false end
 if ContainsKeyword(object.Name, PARASITE_WORDS) then return true end
 local attributes = { "Parasite", "Type", "ObjectType", "ItemType", "Name", "DisplayName" }
 for _, attributeName in ipairs(attributes) do
 local success, value = pcall(function() return object:GetAttribute(attributeName) end)
 if success and value ~= nil then
 if ContainsKeyword(value, PARASITE_WORDS) then return true end
 end
 end
 return false
end

local function IsTreadmillObject(object)
 if not object or object == Workspace then return false end
 if ContainsKeyword(object.Name, TreadmillKeywords) then return true end
 return false
end

local function GetESPAdornee(object)
 if not object then return nil end
 if object:IsA("BasePart") then return object end
 if object:IsA("Model") then
 local primary = object.PrimaryPart
 if primary and primary:IsA("BasePart") then return primary end
 local root = object:FindFirstChildWhichIsA("BasePart", true)
 return root
 end
 return nil
end

local function RemoveTrapESP(object)
 local data = TrapESPObjects[object]
 if not data then return end
 if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
 if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
 TrapESPObjects[object] = nil
end

local function CreateTrapESP(object)
 if not Config.EspTrap or not object or not object.Parent or TrapESPObjects[object] then return end
 local adornee = GetESPAdornee(object)
 if not adornee then return end
 local highlight = Instance.new("Highlight")
 highlight.Name = "VxzTrapHighlight"
 highlight.Adornee = object:IsA("Model") and object or adornee
 highlight.FillColor = Color3.fromRGB(255, 0, 0)
 highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
 highlight.FillTransparency = 0.55
 highlight.OutlineTransparency = 0
 highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
 highlight.Parent = object
 local billboard = Instance.new("BillboardGui")
 billboard.Name = "VxzTrapLabel"
 billboard.Adornee = adornee
 billboard.AlwaysOnTop = true
 billboard.LightInfluence = 0
 billboard.MaxDistance = 1000
 billboard.Size = UDim2.fromOffset(120, 38)
 billboard.StudsOffset = Vector3.new(0, 3.5, 0)
 billboard.Parent = object
 local label = Instance.new("TextLabel")
 label.Name = "TrapText"
 label.BackgroundTransparency = 1
 label.Size = UDim2.fromScale(1, 1)
 label.Font = Enum.Font.GothamBold
 label.Text = "Trap !"
 label.TextSize = 18
 label.TextColor3 = Color3.fromRGB(255, 0, 0)
 label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
 label.TextStrokeTransparency = 0
 label.TextXAlignment = Enum.TextXAlignment.Center
 label.TextYAlignment = Enum.TextYAlignment.Center
 label.Parent = billboard
 TrapESPObjects[object] = { Highlight = highlight, Billboard = billboard }
end

local function RemoveParasiteESP(object)
 local data = ParasiteESPObjects[object]
 if not data then return end
 if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
 if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
 ParasiteESPObjects[object] = nil
end

local function CreateParasiteESP(object)
 if not Config.EspParasite or not object or not object.Parent or ParasiteESPObjects[object] then return end
 local adornee = GetESPAdornee(object)
 if not adornee then return end
 local highlight = Instance.new("Highlight")
 highlight.Name = "VxzParasiteHighlight"
 highlight.Adornee = object:IsA("Model") and object or adornee
 highlight.FillColor = Color3.fromRGB(0, 255, 128)
 highlight.OutlineColor = Color3.fromRGB(0, 255, 128)
 highlight.FillTransparency = 0.55
 highlight.OutlineTransparency = 0
 highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
 highlight.Parent = object
 local billboard = Instance.new("BillboardGui")
 billboard.Name = "VxzParasiteLabel"
 billboard.Adornee = adornee
 billboard.AlwaysOnTop = true
 billboard.LightInfluence = 0
 billboard.MaxDistance = 1000
 billboard.Size = UDim2.fromOffset(140, 38)
 billboard.StudsOffset = Vector3.new(0, 3.5, 0)
 billboard.Parent = object
 local label = Instance.new("TextLabel")
 label.Name = "ParasiteText"
 label.BackgroundTransparency = 1
 label.Size = UDim2.fromScale(1, 1)
 label.Font = Enum.Font.GothamBold
 label.Text = "Parasite !"
 label.TextSize = 18
 label.TextColor3 = Color3.fromRGB(0, 255, 128)
 label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
 label.TextStrokeTransparency = 0
 label.TextXAlignment = Enum.TextXAlignment.Center
 label.TextYAlignment = Enum.TextYAlignment.Center
 label.Parent = billboard
 ParasiteESPObjects[object] = { Highlight = highlight, Billboard = billboard }
end

local function ScanAllObjects()
 for _, object in ipairs(Workspace:GetDescendants()) do
 if IsTrapObject(object) then
 TrapCache[object] = true
 if Config.EspTrap then CreateTrapESP(object) end
 if Config.DeleteTrap then pcall(function() object:Destroy() end) end
 end
 if IsParasiteObject(object) then
 ParasiteCache[object] = true
 if Config.EspParasite then CreateParasiteESP(object) end
 end
 if IsTreadmillObject(object) then
 TreadmillCache[object] = true
 if Config.DeleteTreadmill then pcall(function() object:Destroy() end) end
 end
 end
end

local function IsEggPrompt(prompt)
 if not prompt or not prompt:IsA("ProximityPrompt") then return false end
 local nameText = string.lower(tostring(prompt.Name) .. " " .. tostring(prompt.ObjectText))
 local actionText = string.lower(tostring(prompt.ActionText))
 local nameMatch = string.find(nameText, "trứng", 1, true) or string.find(nameText, "trung", 1, true) or string.find(nameText, "egg", 1, true)
 local actionMatch = string.find(actionText, "trộm", 1, true) or string.find(actionText, "trom", 1, true) or string.find(actionText, "cắp", 1, true) or string.find(actionText, "steal", 1, true)
 return nameMatch ~= nil or actionMatch ~= nil
end

local function ScanAllEggPrompts()
 for _, object in ipairs(Workspace:GetDescendants()) do
 if object:IsA("ProximityPrompt") and IsEggPrompt(object) then
 EggPromptCache[object] = true
 end
 end
end

task.spawn(function()
 while task.wait(2) do
 if Config.AntiTrapBeta then
 for _, obj in ipairs(Workspace:GetDescendants()) do
 if obj:IsA("BasePart") then
 local objName = string.lower(obj.Name)
 for _, word in ipairs(TRAP_WORDS) do
 if string.find(objName, word) then
 pcall(function()
 obj.CanTouch = false
 obj.CanCollide = false
 obj.Anchored = true
 end)
 break
 end
 end
 end
 end
 end
 end
end)

local function StartTrapESP()
 DisconnectConnection("TrapESP")
 Connections.TrapESP = RunService.Heartbeat:Connect(function()
 if not Config.EspTrap then return end
 for object in pairs(TrapESPObjects) do
 if not object or not object.Parent or not IsTrapObject(object) then
 RemoveTrapESP(object)
 end
 end
 end)
end

local function StopTrapESP()
 DisconnectConnection("TrapESP")
 for object in pairs(TrapESPObjects) do RemoveTrapESP(object) end
end

local function StartParasiteESP()
 DisconnectConnection("ParasiteESP")
 Connections.ParasiteESP = RunService.Heartbeat:Connect(function()
 if not Config.EspParasite then return end
 for object in pairs(ParasiteESPObjects) do
 if not object or not object.Parent or not IsParasiteObject(object) then
 RemoveParasiteESP(object)
 end
 end
 end)
end

local function StopParasiteESP()
 DisconnectConnection("ParasiteESP")
 for object in pairs(ParasiteESPObjects) do RemoveParasiteESP(object) end
end

local function DeleteTrapObject(object)
 if not Config.DeleteTrap or not object or not object.Parent or not IsTrapObject(object) then return end
 TrapCache[object] = true
 pcall(function() object:Destroy() end)
end

local function StartTrapScanner()
 DisconnectConnection("TrapAdded")
 DisconnectConnection("TrapCleanup")
 Connections.TrapAdded = Workspace.DescendantAdded:Connect(function(object)
 if Config.DeleteTrap and IsTrapObject(object) then
 DeleteTrapObject(object)
 elseif Config.EspTrap and IsTrapObject(object) then
 CreateTrapESP(object)
 elseif Config.EspParasite and IsParasiteObject(object) then
 CreateParasiteESP(object)
 end
 end)
end

local function EnableDeleteTrap()
 Config.DeleteTrap = true
 ApplyFixLagAuto()
 StartTrapScanner()
end

local function DisableDeleteTrap()
 Config.DeleteTrap = false
end

local function EnableTrapESP()
 Config.EspTrap = true
 ApplyFixLagAuto()
 StartTrapESP()
end

local function DisableTrapESP()
 Config.EspTrap = false
 StopTrapESP()
end

local function EnableParasiteESP()
 Config.EspParasite = true
 ApplyFixLagAuto()
 ScanAllObjects()
 StartParasiteESP()
end

local function DisableParasiteESP()
 Config.EspParasite = false
 StopParasiteESP()
end

local function EnableDeleteTreadmill()
 Config.DeleteTreadmill = true
 ApplyFixLagAuto()
end

local function DisableDeleteTreadmill()
 Config.DeleteTreadmill = false
end

-- ================= BEST ESP XỊN NHẤT (PRO PLAYER ESP) =================
local function RemovePlayerESP(player)
 local data = PlayerESPObjects[player]
 if data then
 if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
 if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
 PlayerESPObjects[player] = nil
 end
end

local function GetPlayerSpeedFromLeaderboard(player)
 local leaderstats = player:FindFirstChild("leaderstats")
 if leaderstats then
 local speedStat = leaderstats:FindFirstChild("Speed") or leaderstats:FindFirstChild("speed") or leaderstats:FindFirstChild("WalkSpeed")
 if speedStat then return FormatSpeedNumber(speedStat.Value) end
 end
 local char = player.Character
 if char then
 local hum = GetHumanoid(char)
 if hum then return FormatSpeedNumber(hum.WalkSpeed) end
 end
 return "N/A"
end

local function CreatePlayerESP(player)
 if player == LocalPlayer or not Config.EspPlayer then return end
 local char = player.Character
 if not char then return end
 local head = char:FindFirstChild("Head")
 if not head then return end
 RemovePlayerESP(player)

 local highlight = Instance.new("Highlight")
 highlight.Name = "VxzProPlayerHighlight"
 highlight.Adornee = char
 highlight.FillColor = Color3.fromRGB(0, 162, 255)
 highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
 highlight.FillTransparency = 0.65
 highlight.OutlineTransparency = 0.1
 highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
 highlight.Parent = char

 local billboard = Instance.new("BillboardGui")
 billboard.Name = "VxzProPlayerLabel"
 billboard.Adornee = head
 billboard.AlwaysOnTop = true
 billboard.LightInfluence = 0
 billboard.MaxDistance = 2500
 billboard.Size = UDim2.fromOffset(220, 65)
 billboard.StudsOffset = Vector3.new(0, 3, 0)
 billboard.Parent = head

 local mainFrame = Instance.new("Frame")
 mainFrame.Name = "MainFrame"
 mainFrame.BackgroundTransparency = 0.35
 mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
 mainFrame.Size = UDim2.fromScale(1, 1)
 mainFrame.Parent = billboard

 local corner = Instance.new("UICorner")
 corner.CornerRadius = UDim.new(0, 6)
 corner.Parent = mainFrame

 local stroke = Instance.new("UIStroke")
 stroke.Color = Color3.fromRGB(0, 170, 255)
 stroke.Thickness = 1.2
 stroke.Parent = mainFrame

 local label = Instance.new("TextLabel")
 label.Name = "InfoText"
 label.BackgroundTransparency = 1
 label.Size = UDim2.fromScale(1, 0.75)
 label.Position = UDim2.fromScale(0, 0)
 label.Font = Enum.Font.GothamBold
 label.TextSize = 13
 label.TextColor3 = Color3.fromRGB(255, 255, 255)
 label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
 label.TextStrokeTransparency = 0
 label.TextXAlignment = Enum.TextXAlignment.Center
 label.TextYAlignment = Enum.TextYAlignment.Center
 label.Parent = mainFrame

 local healthBg = Instance.new("Frame")
 healthBg.Name = "HealthBg"
 healthBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
 healthBg.BorderSizePixel = 0
 healthBg.Size = UDim2.new(0.9, 0, 0, 6)
 healthBg.Position = UDim2.new(0.05, 0, 0.78, 0)
 healthBg.Parent = mainFrame

 local healthCorner = Instance.new("UICorner")
 healthCorner.CornerRadius = UDim.new(0, 3)
 healthCorner.Parent = healthBg

 local healthBar = Instance.new("Frame")
 healthBar.Name = "HealthBar"
 healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
 healthBar.BorderSizePixel = 0
 healthBar.Size = UDim2.fromScale(1, 1)
 healthBar.Parent = healthBg

 local barCorner = Instance.new("UICorner")
 barCorner.CornerRadius = UDim.new(0, 3)
 barCorner.Parent = healthBar

 PlayerESPObjects[player] = { Highlight = highlight, Billboard = billboard, Label = label, HealthBar = healthBar }
end

local function UpdatePlayerESP()
 local myChar = GetCharacter()
 local myRoot = GetRoot(myChar)
 for player, data in pairs(PlayerESPObjects) do
 if player and player.Parent and player.Character and player.Character:FindFirstChild("Head") then
 local targetChar = player.Character
 local targetRoot = GetRoot(targetChar)
 local targetHum = GetHumanoid(targetChar)
 local distStr = "N/A"
 if myRoot and targetRoot then
 local dist = math.floor((myRoot.Position - targetRoot.Position).Magnitude)
 distStr = tostring(dist) .. "m"
 end
 local speedStr = GetPlayerSpeedFromLeaderboard(player)
 
 if data.Label then
 data.Label.Text = string.format("%s | [%s]\nSpeed: %s", player.DisplayName or player.Name, distStr, speedStr)
 end

 if data.HealthBar and targetHum then
 local hpPercent = math.clamp(targetHum.Health / math.max(targetHum.MaxHealth, 1), 0, 1)
 data.HealthBar.Size = UDim2.fromScale(hpPercent, 1)
 data.HealthBar.BackgroundColor3 = Color3.fromRGB(255 * (1 - hpPercent), 255 * hpPercent, 50)
 end
 else
 RemovePlayerESP(player)
 end
 end
end

local function StartPlayerESP()
 DisconnectConnection("EspPlayer")
 ApplyFixLagAuto()
 for _, player in ipairs(Players:GetPlayers()) do
 if player ~= LocalPlayer then CreatePlayerESP(player) end
 end
 Connections.EspPlayer = RunService.Heartbeat:Connect(function()
 if not Config.EspPlayer then return end
 for _, player in ipairs(Players:GetPlayers()) do
 if player ~= LocalPlayer and not PlayerESPObjects[player] and player.Character then
 CreatePlayerESP(player)
 end
 end
 UpdatePlayerESP()
 end)
end

local function StopPlayerESP()
 DisconnectConnection("EspPlayer")
 for player in pairs(PlayerESPObjects) do RemovePlayerESP(player) end
end

local function ApplyInstantEggPrompt(prompt)
 if prompt and prompt:IsA("ProximityPrompt") and IsEggPrompt(prompt) then
 pcall(function() prompt.HoldDuration = 0 end)
 end
end

local function StartInstantEgg()
 DisconnectConnection("InstantEgg")
 ApplyFixLagAuto()
 for _, object in ipairs(Workspace:GetDescendants()) do
 if object:IsA("ProximityPrompt") then ApplyInstantEggPrompt(object) end
 end
 Connections.InstantEgg = Workspace.DescendantAdded:Connect(function(object)
 if Config.InstantEgg and object:IsA("ProximityPrompt") then
 ApplyInstantEggPrompt(object)
 end
 end)
end

local function StopInstantEgg()
 DisconnectConnection("InstantEgg")
end

local function ReplaceHumanoid(character)
 if not Config.Godmode then return end
 local oldHumanoid = character:WaitForChild("Humanoid", 5)
 if not oldHumanoid then return end
 local data = {}
 for _, prop in ipairs(HUM_PROPERTIES) do
 local ok, val = pcall(function() return oldHumanoid[prop] end)
 if ok then data[prop] = val end
 end
 local walkSpeed = GetAdaptiveSpeed()
 pcall(function() oldHumanoid:Destroy() end)
 RunService.Heartbeat:Wait()
 local newHumanoid = Instance.new("Humanoid")
 for prop, val in pairs(data) do
 pcall(function() newHumanoid[prop] = val end)
 end
 newHumanoid.Parent = character
 RunService.Heartbeat:Wait()
 newHumanoid.WalkSpeed = walkSpeed
 pcall(function() newHumanoid:ChangeState(Enum.HumanoidStateType.Landed) end)
 local animateScript = character:FindFirstChild("Animate")
 if animateScript then
 animateScript.Enabled = false
 task.spawn(function()
 task.wait(0.05)
 if animateScript and animateScript.Parent then
 animateScript.Enabled = true
 end
 end)
 end
 local camera = Workspace.CurrentCamera
 if camera then
 pcall(function() camera.CameraSubject = newHumanoid end)
 end
end

local function SetupAntiDie()
 if not Config.Godmode then return end
 DisconnectConnection("HealthChanged")
 local character = GetCharacter()
 if not character then return end
 local humanoid = GetHumanoid(character)
 if not humanoid then return end
 pcall(function()
 humanoid.BreakJointsOnDeath = false
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
 humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
 end)
 Connections.HealthChanged = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
 if not Config.Godmode then return end
 if humanoid.Health <= 0 then
 pcall(function() humanoid.Health = humanoid.MaxHealth end)
 end
 end)
end

local function ForceAntiRagdollReset()
 local char = GetCharacter()
 if not char then return end
 local hum = GetHumanoid(char)
 local root = GetRoot(char)
 if not hum or not root or hum.Health <= 0 then return end
 pcall(function()
 hum:ChangeState(Enum.HumanoidStateType.GettingUp)
 root.Velocity = Vector3.zero
 root.RotVelocity = Vector3.zero
 root.AssemblyLinearVelocity = Vector3.zero
 root.AssemblyAngularVelocity = Vector3.zero
 for _, obj in ipairs(char:GetDescendants()) do
 if obj:IsA("Motor6D") or obj:IsA("Constraint") then
 obj.Enabled = true
 end
 end
 if Workspace.CurrentCamera then
 Workspace.CurrentCamera.CameraSubject = hum
 end
 hum.AutoRotate = true
 hum.PlatformStand = false
 hum.Sit = false
 end)
end

local function StartAntiRagdoll()
 DisconnectConnection("AntiRagdoll")
 ApplyFixLagAuto()
 Connections.AntiRagdoll = RunService.Heartbeat:Connect(function()
 if not Config.AntiRagdoll then return end
 local char = GetCharacter()
 if not char then return end
 local hum = GetHumanoid(char)
 if not hum or hum.Health <= 0 then return end
 local state = hum:GetState()
 local isRagdolled = (state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown)
 if isRagdolled then
 local now = tick()
 if now - AntiRagdollResetCooldown > 0.15 then
 AntiRagdollResetCooldown = now
 ForceAntiRagdollReset()
 end
 end
 end)
end

local function StopAntiRagdoll()
 DisconnectConnection("AntiRagdoll")
end

local function isBat(tool)
 if not tool or not tool:IsA("Tool") then return false end
 local name = tool.Name:lower()
 for _, keyword in ipairs(BAT_NAMES) do
 if name:find(keyword, 1, true) then return true end
 end
 return false
end

local function getBat()
 local character = GetCharacter()
 local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
 if character then
 for _, object in ipairs(character:GetChildren()) do
 if isBat(object) then return object end
 end
 end
 if backpack then
 for _, object in ipairs(backpack:GetChildren()) do
 if isBat(object) then return object end
 end
 end
 return nil
end

local function equipBat()
 local character = GetCharacter()
 if not character then return nil end
 local humanoid = GetHumanoid(character)
 if not humanoid then return nil end
 local bat = getBat()
 if not bat then return nil end
 if bat.Parent ~= character then
 pcall(function() humanoid:EquipTool(bat) end)
 task.wait()
 end
 return bat
end

local function getNearestEnemy(maxRange)
 local character = GetCharacter()
 if not character then return nil end
 local root = GetRoot(character)
 if not root then return nil end
 local nearestCharacter = nil
 local nearestDistance = maxRange or ATTACK_RANGE
 for _, player in ipairs(Players:GetPlayers()) do
 if player ~= LocalPlayer then
 local targetCharacter = player.Character
 if targetCharacter then
 local targetRoot = GetRoot(targetCharacter)
 local targetHumanoid = GetHumanoid(targetCharacter)
 if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
 local distance = (targetRoot.Position - root.Position).Magnitude
 if distance <= nearestDistance then
 nearestDistance = distance
 nearestCharacter = targetCharacter
 end
 end
 end
 end
 end
 return nearestCharacter
end

local function attackBat(maxRange)
 local target = getNearestEnemy(maxRange)
 if not target then return end
 local bat = equipBat()
 if not bat then return end
 pcall(function() bat:Activate() end)
end

local function StartAutoBat()
 DisconnectConnection("AutoBat")
 ApplyFixLagAuto()
 Connections.AutoBat = RunService.Heartbeat:Connect(function()
 if not Config.AutoBat then return end
 attackBat(ATTACK_RANGE)
 end)
end

local function StopAutoBat()
 DisconnectConnection("AutoBat")
end

local function StartAutoAttackBloom()
 DisconnectConnection("AutoAttackBloom")
 ApplyFixLagAuto()
 task.spawn(function()
 while Config.AutoAttackBloom do
 attackBat(99999)
 task.wait(0.05)
 end
 end)
end

local function StopAutoAttackBloom()
 DisconnectConnection("AutoAttackBloom")
end

local function EnableGodmode()
 Config.Godmode = true
 ApplyFixLagAuto()
 ScanAllObjects()
 local character = GetCharacter()
 if character then
 ReplaceHumanoid(character)
 end
 DisconnectConnection("CharacterAdded")
 Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(function(newChar)
 if Config.Godmode then
 task.spawn(function()
 task.wait(0.5)
 ReplaceHumanoid(newChar)
 SetupAntiDie()
 end)
 end
 end)
 task.wait(0.1)
 SetupAntiDie()
 DisconnectConnection("Heartbeat")
 Connections.Heartbeat = RunService.Heartbeat:Connect(function()
 if not Config.Godmode then return end
 local character = GetCharacter()
 local humanoid = GetHumanoid(character)
 if humanoid then
 local targetSpeed = GetAdaptiveSpeed()
 if math.abs(humanoid.WalkSpeed - targetSpeed) > 0.1 then
 humanoid.WalkSpeed = targetSpeed
 end
 end
 end)
end


SecurityTab:Toggle({
 Title = "Anti Ragdoll",
 Desc = "Chống Ragdoll/té ngã",
 Value = false,
 Callback = function(value)
 Config.AntiRagdoll = value
 if value then StartAntiRagdoll() else StopAntiRagdoll() end
 NotifyFeature("Anti Ragdoll", value)
 end
})

local MiscTab = Window:Tab({
 Title = "Misc",
 Icon = "wrench"
})

MiscTab:Toggle({
 Title = "Auto Fix Lag On Feature Enable",
 Desc = "Tự động tối ưu giảm lag khi bật các chức năng",
 Value = true,
 Callback = function(value)
 Config.AutoFixLagOnEnable = value
 end
})

MiscTab:Button({
 Title = "Fix Lag & Max FPS",
 Desc = "Fix lag | Booster Device",
 Callback = function()
 pcall(function()
 local settingsObj = settings()
 settingsObj.Rendering.QualityLevel = Enum.QualityLevel.Level01
 settingsObj.Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
 for _, v in pairs(game:GetDescendants()) do
 if v:IsA("BasePart") then
 v.Material = Enum.Material.SmoothPlastic
 elseif v:IsA("Decal") or v:IsA("Texture") then
 v:Destroy()
 elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
 v.Enabled = false
 end
 end
 local lighting = game:GetService("Lighting")
 lighting.GlobalShadows = false
 lighting.FogEnd = 9e9
 lighting.Technology = Enum.Technology.Compatibility
 if setfpscap then setfpscap(9999999) end
 end)
 end
})

-- Quét ban đầu
ScanAllObjects()
ScanAllEggPrompts()

Workspace.DescendantAdded:Connect(function(object)
 if IsTrapObject(object) then
 if Config.DeleteTrap then DeleteTrapObject(object) end
 if Config.EspTrap then CreateTrapESP(object) end
 elseif IsParasiteObject(object) then
 if Config.EspParasite then CreateParasiteESP(object) end
 end
 if Config.AutoStealBest and object:IsA("ProximityPrompt") and IsEggPrompt(object) then
 EggPromptCache[object] = true
 end
end)