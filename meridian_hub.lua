--[[
 MERIDIAN — Full Menu
 Tab 1 Player: Anti Gummy/Ragdoll/Paintball/Boogie + Speed 3-mode (Meridian S2 loop)
 + Tool Aimbot + Drop Jump/Stand + Insta V1/V2 + TP Down keybinds
 Tab 2 ESP: Player ESP + Tracker + Anti Lag (Meridian logic)
 Tab 3 Settings: Mobile 3-mode buttons, Lock/Unlock, shape Box/Round/Square,
 one size +/- for all floating buttons, Reset Mobile / Reset All
 Close menu: − button | Open: draggable mini | NO keybind to open/close
]]

repeat task.wait() until game:IsLoaded()
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
if not LP then
	repeat task.wait() until Players.LocalPlayer
	LP = Players.LocalPlayer
end
local PlayerGui = LP:WaitForChild("PlayerGui", 30) or LP:FindFirstChild("PlayerGui") or game:GetService("CoreGui")

pcall(function()
	for _, n in ipairs({
 "MeridianHubFullMenu", "MeridianHubFullMini", "MeridianHubModeBar", "MeridianHubActionButtons", "MeridianIntro", "MeridianHubIntro",
 "MeridianBypassGui", "Per1shccLaggerV2",
 "ZenonetopHubFullMenu", "ZenonetopHubFullMini", "ZenonetopHubModeBar", "ZenonetopHubActionButtons", "ZenonetopIntro", "ZenonetopHubIntro",
	}) do
 local g = PlayerGui:FindFirstChild(n)
 if g then g:Destroy() end
	end
end)


-- Remove leftover GUIs from the old Zenonetop build (steal bar, TP panel, etc.).
pcall(function()
	local parents = { PlayerGui }
	pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
	pcall(function() if gethui then table.insert(parents, gethui()) end end)
	for _, parent in ipairs(parents) do
		for _, g in ipairs(parent:GetChildren()) do
			if g.Name:sub(1, 9) == "Zenonetop" then pcall(function() g:Destroy() end) end
		end
	end
end)

----------------------------------------------------------------
-- COLORS / STATE
----------------------------------------------------------------
local C = {
	-- Black & white palette
	bg = Color3.fromRGB(8, 8, 8), bg2 = Color3.fromRGB(16, 16, 16),
	card = Color3.fromRGB(24, 24, 24), stroke = Color3.fromRGB(75, 75, 75),
	accent = Color3.fromRGB(255, 255, 255), text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(165, 165, 165), on = Color3.fromRGB(255, 255, 255),
	off = Color3.fromRGB(45, 45, 45), box = Color3.fromRGB(34, 34, 34),
	danger = Color3.fromRGB(150, 150, 150),
	modeOnBg = Color3.fromRGB(255, 255, 255), modeOnTxt = Color3.fromRGB(20, 20, 20),
	modeOffBg = Color3.fromRGB(38, 38, 38), modeOffTxt = Color3.fromRGB(255, 255, 255),
	btnOff = Color3.fromRGB(16, 16, 16),
}

local St = {
	antiGummy = true, antiRagdoll = false, antiPaint = true, antiBoogie = true, antiBee = false,
	toolAim = true, infJump = true, bodyLock = false, bodyLockRange = 20,
	activeMode = "Normal",
	manualCarry = false, -- ON = auto carry OFF, speed switches only via the CARRY button
	modes = {
 Normal = { norm = 59, steal = 30, key = Enum.KeyCode.T },
 Lagger = { norm = 18, steal = 24, key = Enum.KeyCode.Q },
 Custom = { norm = 33, steal = 33, key = Enum.KeyCode.C },
	},
	dropMode = 2, -- 1 Stand/Fling, 2 Jump
	instaMode = "V1",
	mobileBtns = true, guiLock = false, -- default ON: Drop / Insta / TP buttons
	btnShape = "Box", -- Round | Box | Square
	btnScale = 1,
	menuScale = 1.0,
	btnSizes = { mode = 38, drop = 52.5, insta = 52.5, tp = 52.5, sentry = 52.5 },
	keys = {
 Drop = Enum.KeyCode.X,
 TPDown = Enum.KeyCode.F,
 InstaReset = Enum.KeyCode.Z,
 DestroySentry = Enum.KeyCode.H,
 AutoSteal = nil, -- nil = None (no key)
	},
	esp = false, tracer = false, antiLag = false,
	antiKick = true, wallOpacity = 0, speedMethod = "Velocity",
	destroySentry = false,
	spamLaser = false, spamPaint = false,
	counterLaser = false, counterBoogie = false, counterSwapBody = false,
	equipOnDrop = false,
}
local ToggleRefs = {} -- so Reset All can update the UI

local CFG = "MeridianAllGear.json"
function _serializeValue(v, depth)
	depth = depth or 0
	if depth > 6 then return nil end
	local t = typeof(v)
	if t == "number" or t == "string" or t == "boolean" then
 return v
	elseif t == "EnumItem" then
 return v.Name
	elseif t == "table" then
 local out = {}
 for k2, v2 in pairs(v) do
 local kt = type(k2)
 if kt == "string" or kt == "number" then
 local sv = _serializeValue(v2, depth + 1)
 if sv ~= nil then out[k2] = sv end
 end
 end
 return out
	end
	return nil
end
function saveCfg()
	local d = {}
	-- dump ALL of St (every key that can be JSON-encoded)
	for k, v in pairs(St) do
 if type(k) == "string" then
 -- do not save base/pet TP — only remember the panel position
 if k == "_saveBase" or k == "_savePet" or k == "saveBase" or k == "savePet"
 or k == "_delayBase" or k == "_delayPet" then
 -- skip
 elseif k == "modes" or k == "keys" then
 -- skip, handle below
 else
 local sv = _serializeValue(v)
 if sv ~= nil then d[k] = sv end
 end
 end
	end
	d.modes = {}
	for k, m in pairs(St.modes or {}) do
 if type(m) == "table" then
 d.modes[k] = {
 norm = tonumber(m.norm) or 16,
 steal = tonumber(m.steal) or 16,
 key = (typeof(m.key) == "EnumItem" and m.key.Name) or (type(m.key) == "string" and m.key) or "Unknown",
 }
 end
	end
	d.keys = {}
	for k, v in pairs(St.keys or {}) do
 d.keys[k] = (typeof(v) == "EnumItem" and v.Name) or tostring(v)
	end
	local ok, err = pcall(function()
 if not writefile then error("no writefile") end
 d._saveBase = nil
	d._savePet = nil
	d.saveBase = nil
	d.savePet = nil
	d._delayBase = nil
	d._delayPet = nil
	local json = HttpService:JSONEncode(d)
	if json ~= _zCfgLast then writefile(CFG, json); _zCfgLast = json end
	end)
	if not ok then
 warn("[MERIDIAN] saveCfg fail:", err)
	end
	return ok
end
function loadCfg()
	local ok, data = pcall(function()
 if isfile and readfile then
 if isfile(CFG) then
 return HttpService:JSONDecode(readfile(CFG))
 end
 for _, old in ipairs({"ZenonetopAllgear.json", "RaraOnflop.json", "ZenonetopHub_FullMenu_v1.json", "ZenonetopHub_Config.json", "ZENONETOP.json"}) do
 if isfile(old) then
 local d = HttpService:JSONDecode(readfile(old))
 pcall(function() writefile(CFG, HttpService:JSONEncode(d)) end)
 return d
 end
 end
 end
	end)
	if not (ok and type(data) == "table") then return false end
	for k, v in pairs(data) do
 if type(k) == "string" and k ~= "modes" and k ~= "keys" then
 St[k] = v
 end
	end
	if type(data.modes) == "table" then
 for k, m in pairs(data.modes) do
 if type(m) == "table" then
 St.modes[k] = St.modes[k] or { norm = 59, steal = 30, key = Enum.KeyCode.Unknown }
 St.modes[k].norm = tonumber(m.norm) or St.modes[k].norm
 St.modes[k].steal = tonumber(m.steal) or St.modes[k].steal
 if type(m.key) == "string" then
 pcall(function() St.modes[k].key = Enum.KeyCode[m.key] end)
 end
 end
 end
	end
	if type(data.keys) == "table" then
 St.keys = St.keys or {}
 for k, name in pairs(data.keys) do
 pcall(function() St.keys[k] = Enum.KeyCode[name] end)
 end
	end
	if type(data.btnSizes) == "table" then
 St.btnSizes = data.btnSizes
 for k,v in pairs(St.btnSizes) do
 St.btnSizes[k] = math.clamp(tonumber(v) or 50, 20, 200)
 end
	end
	-- one size editor now: every floating button shares the same base size (taken from Speed 3Mode)
	do
 local base = math.clamp(tonumber(St.btnSizes and St.btnSizes.mode) or 38, 20, 200)
 St.btnSizes = { mode = base, drop = base, insta = base, tp = base, sentry = base }
	end
	if type(data._btnPos) == "table" then St._btnPos = data._btnPos end
	St.stealRadius = tonumber(St.stealRadius) or 60
	St.stealBarScale = tonumber(St.stealBarScale) or 1
	return true
end
loadCfg()

----------------------------------------------------------------
----------------------------------------------------------------
-- SPEED — Velocity loop (impulse toward the move direction)
----------------------------------------------------------------
local speedConnection = nil
local currentSpeedValue = 16
St.speedMethod = "Velocity"

local _spd = {
	lastMethod = nil,
	lastMoveDir = Vector3.zero,
	anchoredBySpeed = nil,
}

local MOVE_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
}

----------------------------------------------------------------
-- SPEED LOOP + INF JUMP — FULL EMPIRE (fetched) — no old leftovers
-- 3 mode (Normal/Lagger/Custom) = St.modes + getActiveMoveSpeed
----------------------------------------------------------------

function isCarryingBrainrot(char)
	if not char then return false end
	if LP:GetAttribute("Stealing") == true or char:GetAttribute("Stealing") == true then return true end
	-- the child-name scan allocates and runs from the per-frame speed loop, so it is throttled
	local now = os.clock()
	if _spd.carryChar == char and now - (_spd.carryT or 0) < 0.15 then return _spd.carryV == true end
	local found = false
	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("Tool") or v:IsA("Model") or v:IsA("Folder") then
			local n = string.lower(tostring(v.Name))
			if n:find("brainrot", 1, true) or n:find("carriedbrain", 1, true) then found = true break end
		end
	end
	_spd.carryChar, _spd.carryT, _spd.carryV = char, now, found
	return found
end

function getActiveMoveSpeed()
	-- 3 mode speed: Normal / Lagger / Custom (UI + V2 bar)
	local mode = St.activeMode
	if not mode or not St.modes[mode] then
 mode = "Normal"
 St.activeMode = "Normal"
	end
	local m = St.modes[mode] or { norm = 59, steal = 30 }
	local norm = math.clamp(tonumber(m.norm) or 59, 1, 200)
	local steal = math.clamp(tonumber(m.steal) or 30, 1, 200)
	if St.manualCarry == true then
		-- manual carry: auto detect fully OFF, steal speed only while CARRY button is ON
		if _G.MeridianCarryActive == true then return steal end
		return norm
	end
	if isCarryingBrainrot(LP.Character) then
 return steal
	end
	return norm
end

function destroySpeedObjects()
	if _spd.anchoredBySpeed then
		pcall(function() _spd.anchoredBySpeed.Anchored = false end)
		_spd.anchoredBySpeed = nil
	end
end

-- Velocity method (the only one the menu ever selects): impulse toward dir*spd, Y untouched
function applySpeedMethod(hrp, hum, dir, spd)
	if _spd.lastMethod ~= "Velocity" then
		destroySpeedObjects()
		if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
		_spd.lastMethod = "Velocity"
	end
	local cur = hrp.AssemblyLinearVelocity
	local mass = hrp.AssemblyMass or 1
	pcall(hrp.ApplyImpulse, hrp, Vector3.new((dir.X * spd - cur.X) * mass, 0, (dir.Z * spd - cur.Z) * mass))
end

function startSpeedBoost()
	currentSpeedValue = getActiveMoveSpeed()
	if speedConnection then
 pcall(function() speedConnection:Disconnect() end)
 speedConnection = nil
	end
	-- EMPIRE full loop (RenderStepped)
	speedConnection = RS.RenderStepped:Connect(function(dt)
 local char = LP.Character
 if not char then return end
 local hum = char:FindFirstChildOfClass("Humanoid")
 local hrp = char:FindFirstChild("HumanoidRootPart")
 if not hum or not hrp then return end
 -- ragdoll → stop
 local stt = hum:GetState()
 if stt == Enum.HumanoidStateType.Physics
 or stt == Enum.HumanoidStateType.Ragdoll
 or stt == Enum.HumanoidStateType.FallingDown
 or hum.Health <= 0 then
 _spd.lastMoveDir = Vector3.zero
 destroySpeedObjects()
 return
 end
 local md = hum.MoveDirection
 local spd = getActiveMoveSpeed()
 currentSpeedValue = spd
 local dir = Vector3.zero
 if md.Magnitude > 0.01 then
 _spd.lastMoveDir = md
 dir = md
 else
 -- keep direction during anti ragdoll while the key is still held (Empire style)
 local anyHeld = false
 if type(MOVE_KEYS) == "table" then
 for key in pairs(MOVE_KEYS) do
 if UIS:IsKeyDown(key) then anyHeld = true break end
 end
 end
 if anyHeld and _spd.lastMoveDir and _spd.lastMoveDir.Magnitude > 0.01 then
 dir = _spd.lastMoveDir
 end
 end
 if dir.Magnitude > 0.01 then
 applySpeedMethod(hrp, hum, dir.Unit, spd, dt)
 else
 destroySpeedObjects()
 end
	end)
end

function setActiveMode(mode)
	if not St.modes[mode] then return end
	St.activeMode = mode
	currentSpeedValue = getActiveMoveSpeed()
	startSpeedBoost() -- restart Empire loop
	if _G.MeridianRefreshModeBar then pcall(_G.MeridianRefreshModeBar) end
	if _G.MeridianRefreshV2ModeBar then pcall(_G.MeridianRefreshV2ModeBar) end
	if _G.MeridianRefreshModeCards then pcall(_G.MeridianRefreshModeCards) end
	pcall(saveCfg)
end

function toggleMode(name)
	if name ~= "Normal" and St.activeMode == name then name = "Normal" end
	setActiveMode(name)
end

----------------------------------------------------------------
-- INFINITE JUMP — FULL EMPIRE (hold + manual 2 mode)
----------------------------------------------------------------
InfJumpState = { enabled = false, mode = "hold", jumpHeld = false }
local _holdInfJumpConn = nil

function stopHoldInfJump()
	if _holdInfJumpConn then
 pcall(function() _holdInfJumpConn:Disconnect() end)
 _holdInfJumpConn = nil
	end
end

function startHoldInfJump()
	stopHoldInfJump()
	-- FULL Empire hold infinite jump (Velocity)
	_holdInfJumpConn = RS.Heartbeat:Connect(function()
 if not InfJumpState.enabled then return end
 local char = LP.Character
 if not char then return end
 local root = char:FindFirstChild("HumanoidRootPart")
 local hum = char:FindFirstChildOfClass("Humanoid")
 if not root or not hum then return end
 local isJumpHeld = UIS:IsKeyDown(Enum.KeyCode.Space) or (hum.Jump == true) or (InfJumpState.jumpHeld == true)
 local vel = root.Velocity
 pcall(function()
 local av = root.AssemblyLinearVelocity
 if av then vel = av end
 end)
 if isJumpHeld and vel.Y < 35 then
 local nv = Vector3.new(vel.X, 55, vel.Z)
 pcall(function() root.Velocity = nv end)
 pcall(function() root.AssemblyLinearVelocity = nv end)
 end
 if vel.Y < -120 then
 local nv = Vector3.new(vel.X, -120, vel.Z)
 pcall(function() root.Velocity = nv end)
 pcall(function() root.AssemblyLinearVelocity = nv end)
 end
	end)
end

function startInfJump()
	InfJumpState.enabled = true
	InfJumpState.mode = "hold"
	startHoldInfJump()
end

function stopInfJump()
	InfJumpState.enabled = false
	InfJumpState.jumpHeld = false
	stopHoldInfJump()
end

function setInfJump(on)
	St.infJump = on and true or false
	if St.infJump then startInfJump() else stopInfJump() end
	saveCfg()
end

-- Mobile JumpButton + Space (Empire)
if not _G._MeridianEmpireJumpHook then
	_G._MeridianEmpireJumpHook = true
	task.spawn(function()
 local pg = LP:WaitForChild("PlayerGui", 15)
 if not pg then return end
 local function hookJumpButton(btn)
 if btn:IsA("GuiButton") and btn.Name == "JumpButton" and not btn:GetAttribute("MeridianInfJumpHooked") then
 btn:SetAttribute("MeridianInfJumpHooked", true)
 btn.MouseButton1Down:Connect(function()
 if InfJumpState.enabled then InfJumpState.jumpHeld = true end
 end)
 btn.MouseButton1Up:Connect(function()
 InfJumpState.jumpHeld = false
 end)
 end
 end
 for _, d in ipairs(pg:GetDescendants()) do hookJumpButton(d) end
 pg.DescendantAdded:Connect(hookJumpButton)
	end)
	UIS.JumpRequest:Connect(function()
 if not InfJumpState.enabled then return end
 if InfJumpState.mode == "manual" then
 InfJumpState.jumpHeld = true
 task.defer(function() InfJumpState.jumpHeld = false end)
 end
	end)
	UIS.InputEnded:Connect(function(inp)
 if inp.KeyCode == Enum.KeyCode.Space then
 InfJumpState.jumpHeld = false
 end
	end)
end

-- ANTI KICK (Empire full) — ALWAYS ON, never OFF
----------------------------------------------------------------
local AntiKickState = { enabled = true, brainrotDetected = false, conn = nil }
function enableAntiKick()
	AntiKickState.enabled = true
	St.antiKick = true
	-- namecall Kick shield (executor)
	pcall(function()
 if hookmetamethod and not _G._FAGAntiKickHooked then
 _G._FAGAntiKickHooked = true
 local old
 old = hookmetamethod(game, "__namecall", function(self, ...)
 local method = (getnamecallmethod and getnamecallmethod()) or ""
 if tostring(method) == "Kick" then
 if self == LP or (typeof(self) == "Instance" and self:IsA("Player") and self == LP) then
 return -- block LocalPlayer:Kick
 end
 end
 return old(self, ...)
 end)
 end
	end)
	-- block Players.LocalPlayer:Kick via hookfunction if available
	pcall(function()
 if hookfunction and not _G._FAGKickFnHooked then
 _G._FAGKickFnHooked = true
 local oldKick = LP.Kick
 if typeof(oldKick) == "function" then
 hookfunction(oldKick, function(self, ...)
 return -- never kick self
 end)
 end
 end
	end)
	if AntiKickState.conn then return end
	AntiKickState.conn = task.spawn(function()
 while true do -- forever
 AntiKickState.enabled = true
 St.antiKick = true
 task.wait(0.5)
 local char = LP.Character
 local found = false
 if char then
 for _, tool in ipairs(char:GetChildren()) do
 if tool:IsA("Tool") then
 local n = tool.Name:lower()
 if n:find("brainrot") or n:find("skibidi") or n:find("toilet") then
 found = true
 break
 end
 end
 end
 end
 AntiKickState.brainrotDetected = found
 end
	end)
end
task.defer(enableAntiKick)

-- Anti Ragdoll V1=Splatter / V2=No Splatter (full logic)
AntiRagdollV2 = AntiRagdollV2 or { Connection = nil, Enabled = false, ResetCooldown = 0 }
St.antiRagdollMode = St.antiRagdollMode or "V1" -- V1=Splatter, V2=No Splatter

function forceNoSplatterReset()
	local char = LP.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return end
	pcall(function()
 hum:ChangeState(Enum.HumanoidStateType.GettingUp)
 root.Velocity = Vector3.zero
 root.RotVelocity = Vector3.zero
 root.AssemblyLinearVelocity = Vector3.zero
 root.AssemblyAngularVelocity = Vector3.zero
 for _, obj in ipairs(char:GetDescendants()) do
 if obj:IsA("Motor6D") then obj.Enabled = true end
 if obj:IsA("Constraint") then obj.Enabled = true end
 end
 workspace.CurrentCamera.CameraSubject = hum
 local PM = LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("PlayerModule")
 if PM then
 local ok, CM = pcall(function() return require(PM:FindFirstChild("ControlModule")) end)
 if ok and CM and CM.Enable then pcall(function() CM:Enable() end) end
 end
 hum.AutoRotate = true
 hum.PlatformStand = false
 hum.Sit = false
	end)
end

function startAntiRagdoll()
	stopAntiRagdoll()
	AntiRagdollV2.Enabled = true
	AntiRagdollV2.Connection = RS.Heartbeat:Connect(function()
 if not AntiRagdollV2.Enabled or not St.antiRagdoll then return end
 local char = LP.Character
 if not char then return end
 local hum = char:FindFirstChildOfClass("Humanoid")
 local root = char:FindFirstChild("HumanoidRootPart")
 if not hum or hum.Health <= 0 then return end
 local state = hum:GetState()
 local ragdolled = (state == Enum.HumanoidStateType.Physics
 or state == Enum.HumanoidStateType.Ragdoll
 or state == Enum.HumanoidStateType.FallingDown)
 local mode = tostring(St.antiRagdollMode or "V1"):upper()
 -- V2 = No Splatter 
 if mode == "V2" or mode == "NO SPLATTER" then
 if ragdolled then
 local now = tick()
 if now - (AntiRagdollV2.ResetCooldown or 0) > 0.15 then
 AntiRagdollV2.ResetCooldown = now
 forceNoSplatterReset()
 end
 end
 return
 end
 -- V1 = Splatter : clear constraints + Running
 if not root then return end
 local endTime = LP:GetAttribute("RagdollEndTime")
 if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then
 ragdolled = true
 end
 if ragdolled then
 pcall(function()
 LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
 end)
 for _, d in ipairs(char:GetDescendants()) do
 if d:IsA("BallSocketConstraint") or
 (d:IsA("Attachment") and tostring(d.Name):find("RagdollAttachment")) then
 d:Destroy()
 end
 end
 for _, obj in ipairs(char:GetDescendants()) do
 if obj:IsA("Motor6D") and obj.Enabled == false then
 obj.Enabled = true
 end
 end
 if hum.Health > 0 then
 hum:ChangeState(Enum.HumanoidStateType.Running)
 end
 pcall(function() workspace.CurrentCamera.CameraSubject = hum end)
 root.Anchored = false
 root.AssemblyLinearVelocity = Vector3.zero
 root.AssemblyAngularVelocity = Vector3.zero
 end
	end)
end

function stopAntiRagdoll()
	AntiRagdollV2.Enabled = false
	if AntiRagdollV2.Connection then
 pcall(function() AntiRagdollV2.Connection:Disconnect() end)
 AntiRagdollV2.Connection = nil
	end
	AntiRagdollV2.ResetCooldown = 0
end

function setAntiRagdoll(on)
	St.antiRagdoll = on and true or false
	if St.antiRagdoll then
 startAntiRagdoll()
	else
 stopAntiRagdoll()
	end
	pcall(saveCfg)
end

function setAntiRagdollMode(mode)
	mode = tostring(mode or "V1"):upper()
	if mode == "V2" or mode == "NO SPLATTER" or mode == "NOSPLATTER" then
 St.antiRagdollMode = "V2"
	else
 St.antiRagdollMode = "V1"
	end
	if St.antiRagdoll then
 stopAntiRagdoll()
 startAntiRagdoll()
	end
	pcall(function() if _G.MeridianRefreshAntiRagMode then _G.MeridianRefreshAntiRagMode() end end)
	pcall(saveCfg)
end
_G.MeridianSetAntiRagdollMode = setAntiRagdollMode

----------------------------------------------------------------
-- ANTI BEE: removes Lighting post-effects and locks FOV while ON
----------------------------------------------------------------
AntiBeeFx = AntiBeeFx or { running = false, conns = {}, fov = 70 }
AntiBeeFx.classes = {
	"BlurEffect", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect",
	"Atmosphere", "Sky", "Smoke", "ParticleEmitter", "Beam", "Trail", "Highlight", "PostEffect",
	"SurfaceAppearance", "Fire", "Sparkles", "Explosion", "PointLight", "SpotLight", "SurfaceLight",
	"Shadows", "Blur", "Fog", "ColorGradingEffect", "ToneMappingEffect", "VignetteEffect", "GodRays",
	"Glare", "ChromaticAberrationEffect", "DistortionEffect", "LensFlare", "SunFlare", "LightInfluence",
	"AmbientOcclusionEffect", "RefractionEffect", "HeatDistortion", "GlitchEffect", "ScreenSpaceReflection",
	"MotionBlur", "VolumetricLight", "RainEffect", "SnowEffect", "LightningEffect", "NeonGlow",
	"ContrastCorrection", "ShadowMap", "Bloom", "Clouds", "FogVolume", "WaterEffect", "WindEffect",
	"PixelateEffect", "FilmGrainEffect", "CRTShader", "NightVisionEffect", "InfraredEffect", "HazeEffect",
	"ColorBalanceEffect", "DynamicLight", "AmbientEffect", "ScreenDistortion", "ScanlineEffect",
	"UnderwaterEffect", "ThermalVision", "ShockwaveEffect", "FlashEffect", "ExplosionLight", "VFXPart",
	"GlitchScreen", "ScreenFlash", "OverlayEffect", "ShadowEffect", "GhostEffect", "FogEmitter",
	"WindEmitter", "HeatWave", "SunGlow", "ColorOverlay", "VisionDistort", "EchoEffect", "ScreenOverlay",
	"RenderEffect", "VisualEffect", "LightingEffect", "CameraEffect", "WeatherEffect", "SmokeTrail",
	"FireTrail", "NeonEffect", "RefractionLayer", "PostProcessingEffect", "VisualNoise", "ScreenNoise",
}
function AntiBeeFx.isBlacklisted(obj)
	for _, name in ipairs(AntiBeeFx.classes) do
		if obj:IsA(name) then return true end
	end
	return false
end
function AntiBeeFx.clear()
	for _, v in ipairs(Lighting:GetDescendants()) do
		if AntiBeeFx.isBlacklisted(v) then pcall(function() v:Destroy() end) end
	end
end
function AntiBeeFx.start()
	if AntiBeeFx.running then return end
	AntiBeeFx.running = true
	AntiBeeFx.clear()
	table.insert(AntiBeeFx.conns, Lighting.DescendantAdded:Connect(function(obj)
		task.wait()
		if AntiBeeFx.running and AntiBeeFx.isBlacklisted(obj) then pcall(function() obj:Destroy() end) end
	end))
	table.insert(AntiBeeFx.conns, RS.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if cam and cam.FieldOfView ~= AntiBeeFx.fov then cam.FieldOfView = AntiBeeFx.fov end
	end))
end
function AntiBeeFx.stop()
	AntiBeeFx.running = false
	for _, c in ipairs(AntiBeeFx.conns) do pcall(function() c:Disconnect() end) end
	AntiBeeFx.conns = {}
end
function setAntiBee(on)
	St.antiBee = on and true or false
	if St.antiBee then AntiBeeFx.start() else AntiBeeFx.stop() end
	pcall(saveCfg)
end

----------------------------------------------------------------
-- ANTI GUMMY / BOOGIE / PAINTBALL (MERIDIAN full) — ALWAYS ON
--------------------------------------------------------------
-- Anti Gummy / Boogie / Bee / Paintball (from Tp Heatseeker)
-- Always ON, no GUI
-- ============================================================
if not _G._FAG_MeridianAntiGummyFullLoaded then
	_G._FAG_MeridianAntiGummyFullLoaded = true
	task.spawn(function()
 local Players = game:GetService("Players")
 local RunService = game:GetService("RunService")
 local Lighting = game:GetService("Lighting")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local LocalPlayer = Players.LocalPlayer

  local AntiGummy, AntiBoogie = true, true
 local ANTI_PAINTBALL_ALWAYS_ON = true

 -- runs every Heartbeat: only write an attribute when it is not already the wanted value
 local function ResetTool(Char)
 if not Char then Char = LocalPlayer.Character end
 if not Char then return end
 if LocalPlayer:GetAttribute("BlockTools") ~= false then LocalPlayer:SetAttribute("BlockTools", false) end
 if LocalPlayer:GetAttribute("Web") ~= false then LocalPlayer:SetAttribute("Web", false) end
 if Char:GetAttribute("BackpackReady") ~= true then Char:SetAttribute("BackpackReady", true) end
 end

 local boomSound, boomNext = nil, 0
 -- runs every Heartbeat: no GetChildren() table, controller lookup is cached
 local function ClearEffect()
 if not AntiBoogie then return end
 for _ = 1, 4 do
 local d = Lighting:FindFirstChild("DiscoEffect")
 if not d then break end
 pcall(d.Destroy, d)
 end
 if not (boomSound and boomSound.Parent) then
 boomSound = nil
 local now = os.clock()
 if now >= boomNext then
 boomNext = now + 1
 local Ctrl = ReplicatedStorage:FindFirstChild("Controllers")
 local BC = Ctrl and Ctrl:FindFirstChild("BoogieBombController")
 boomSound = BC and BC:FindFirstChild("BOOM") or nil
 end
 end
 if boomSound then pcall(boomSound.Stop, boomSound) end
 end

 local function getMainHudGui()
 local pg = LocalPlayer:FindFirstChild("PlayerGui")
 return pg and pg:FindFirstChild("Main")
 end

 local function isPaintballSplatGui(gui)
 if not gui or gui.Parent ~= getMainHudGui() then return false end
 if not (gui:IsA("ImageLabel") or gui:IsA("ImageButton")) then return false end
 if gui:GetAttribute("__UGPaintballIgnore") or gui:GetAttribute("__UGPaintballShrunk") then return false end
 return math.abs(gui.Rotation) > 0.01
 end

 local function shrinkPaintballSplat(gui)
 if not gui or gui:GetAttribute("__UGPaintballShrunk") then return end
 gui:SetAttribute("__UGPaintballShrunk", true)
 gui.Size = UDim2.fromOffset(6, 6)
 end

 -- Paintball sweep: one pass every 0.25s (new splats are also shrunk instantly by the ChildAdded hook below)
 task.spawn(function()
 while task.wait(0.25) do
 if ANTI_PAINTBALL_ALWAYS_ON then
 pcall(function()
 local main = getMainHudGui()
 if not main then return end
 for _, c in ipairs(main:GetChildren()) do
 if isPaintballSplatGui(c) then pcall(shrinkPaintballSplat, c) end
 end
 end)
 end
 end
 end)

 -- Heartbeat: Anti Gummy + Boogie
 RunService.Heartbeat:Connect(function()
 if AntiGummy then pcall(ResetTool) end
 if AntiBoogie then pcall(ClearEffect) end
 end)

 -- Also clear on Lighting child added (instant)
 pcall(function()
 Lighting.ChildAdded:Connect(function(child)
 if child and AntiBoogie and child.Name == "DiscoEffect" then
 task.defer(function() pcall(child.Destroy, child) end)
 end
 end)
 end)

 -- Paintball: shrink when new splat appears on Main HUD
 pcall(function()
 local function hookMain(main)
 if not main or main:GetAttribute("_MeridianAntiPaintballHooked") then return end
 main:SetAttribute("_MeridianAntiPaintballHooked", true)
 main.ChildAdded:Connect(function(c)
 task.defer(function()
 if isPaintballSplatGui(c) then
 pcall(shrinkPaintballSplat, c)
 end
 end)
 end)
 end
 local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
 if pg then
 hookMain(pg:FindFirstChild("Main"))
 pg.ChildAdded:Connect(function(ch)
 if ch.Name == "Main" then
 task.defer(function() hookMain(ch) end)
 end
 end)
 end
 end)

 -- CharacterAdded: ensure tools unblocked
 LocalPlayer.CharacterAdded:Connect(function(char)
 task.defer(function()
 pcall(ResetTool, char)
 end)
 end)

 print("[Meridian AllGear] Anti Gummy / Boogie / Bee / Paintball ON (silent)")
	end)
end

-- Setters: always ON, cannot be turned OFF
AntiFX = AntiFX or { gummy = true, boogie = true, paint = true }
function setAntiGummy(on)
	St.antiGummy = true
	AntiFX.gummy = true
	saveCfg()
end
function setAntiBoogie(on)
	St.antiBoogie = true
	AntiFX.boogie = true
	saveCfg()
end
function setAntiPaint(on)
	St.antiPaint = true
	AntiFX.paint = true
	saveCfg()
end

----------------------------------------------------------------
-- TOOL AIMBOT (MERIDIAN full) — ALWAYS ON
----------------------------------------------------------------
local aimOn = true
local TOOLS = { ["Web Slinger"] = true, ["Paintball Gun"] = true, ["Laser Cape"] = true }
local hooked = {}
local mouseMod, lastAimUp = nil, 0
function getMouse()
	if mouseMod then return mouseMod end
	pcall(function()
 local pkg = ReplicatedStorage:FindFirstChild("Packages")
 if pkg then mouseMod = require(pkg:WaitForChild("PlayerMouse", 5)) end
	end)
	return mouseMod
end
function bestEnemy()
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam then return nil end
	local best, score = nil, math.huge
	local camPos, camDir = cam.CFrame.Position, cam.CFrame.LookVector
	for _, plr in ipairs(Players:GetPlayers()) do
 if plr ~= LP and plr.Character then
 local r = plr.Character:FindFirstChild("HumanoidRootPart")
 local h = plr.Character:FindFirstChildOfClass("Humanoid")
 if r and h and h.Health > 0 then
 local d = (r.Position - root.Position).Magnitude
 if d <= 100 then
 local to = r.Position - camPos
 if to.Magnitude > 0.01 then
 local ang = math.deg(math.acos(math.clamp(camDir:Dot(to.Unit), -1, 1)))
 local sc = d + (ang > 200 and 1000 or 0)
 if sc < score then score, best = sc, r end
 end
 end
 end
 end
	end
	return best
end
function overrideMouse()
	if not aimOn then return end
	local pm = getMouse()
	if not pm then return end
	local e = bestEnemy()
	if e and e.Parent then
 local vel = e.AssemblyLinearVelocity or Vector3.zero
 pcall(function()
 pm.Hit = CFrame.new(e.Position + vel * 0.1)
 pm.Target = e
 end)
	end
end
function hookTool(tool)
	if hooked[tool] or not tool then return end
	hooked[tool] = true
	tool.Activated:Connect(overrideMouse)
	tool.Equipped:Connect(function()
 task.wait(0.1)
 local pm = getMouse()
 if pm and aimOn then
 local old = pm.Button1Down
 pm.Button1Down = function(...)
 overrideMouse()
 if old then old(...) end
 end
 end
	end)
end
function watchTools(parent)
	if not parent then return end
	for _, c in ipairs(parent:GetChildren()) do
 if TOOLS[c.Name] then hookTool(c) end
	end
	parent.ChildAdded:Connect(function(c)
 task.wait(0.05)
 if TOOLS[c.Name] then hookTool(c) end
	end)
end
watchTools(LP.Backpack)
if LP.Character then watchTools(LP.Character) end
LP.CharacterAdded:Connect(function(c)
	task.wait(0.2)
	watchTools(c)
	watchTools(LP.Backpack)
end)
RS.RenderStepped:Connect(function()
	if not aimOn then return end
	if tick() - lastAimUp > 0.1 then lastAimUp = tick(); bestEnemy() end
	if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then overrideMouse() end
end)
function setToolAim(on)
	-- tool aimbot ALWAYS ON
	aimOn = true
	St.toolAim = true
	local char = LP.Character
	if char then pcall(watchTools, char) end
	local bp = LP:FindFirstChild("Backpack")
	if bp then pcall(watchTools, bp) end
	saveCfg()
end
-- boot tool aim
task.defer(function()
	aimOn = true
	St.toolAim = true
	pcall(function()
 if LP.Character then watchTools(LP.Character) end
 if LP.Backpack then watchTools(LP.Backpack) end
	end)
end)

----------------------------------------------------------------
-- DROP JUMP / STAND (Meridian Clean)
----------------------------------------------------------------
local dropActive = false
local DROP_SPD, DROP_DUR = 200, 0.28
function runDrop()
	if dropActive then return end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local mode = tonumber(St.dropMode) or 2
	if mode == 1 then
 -- Stand / Fling style burst
 dropActive = true
 local t0 = tick()
 local conn
 conn = RS.Heartbeat:Connect(function()
 if not dropActive or tick() - t0 > 0.25 then
 if conn then conn:Disconnect() end
 dropActive = false
 if root and root.Parent then
 root.AssemblyLinearVelocity = Vector3.zero
 end
 return
 end
 local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
 if not r then return end
 local v = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
 r.AssemblyLinearVelocity = v * 10000 + Vector3.new(0, 10000, 0)
 end)
 return
	end
	-- Jump ascend
	dropActive = true
	local t0 = tick()
	local conn
	conn = RS.Heartbeat:Connect(function()
 local c = LP.Character
 local r = c and c:FindFirstChild("HumanoidRootPart")
 if not r or not dropActive then
 if conn then conn:Disconnect() end
 dropActive = false
 return
 end
 if tick() - t0 >= DROP_DUR then
 if conn then conn:Disconnect() end
 local rp = RaycastParams.new()
 rp.FilterDescendantsInstances = { c }
 rp.FilterType = Enum.RaycastFilterType.Exclude
 local rr = workspace:Raycast(r.Position, Vector3.new(0, -3000, 0), rp)
 if rr then
 local h2 = c:FindFirstChildOfClass("Humanoid")
 local off = ((h2 and h2.HipHeight) or 2) + (r.Size.Y / 2)
 r.CFrame = CFrame.new(r.Position.X, rr.Position.Y + off, r.Position.Z)
 end
 r.AssemblyLinearVelocity = Vector3.zero
 r.AssemblyAngularVelocity = Vector3.zero
 dropActive = false
 return
 end
 r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_SPD, r.AssemblyLinearVelocity.Z)
	end)
end

----------------------------------------------------------------
-- INSTA RESET V1 / V2 (Meridian)
----------------------------------------------------------------
local _resetBusy = false
local _resetCD = false
local INST_V2_POS = CFrame.new(2000.5, 9911.9, 4000.2)
function InstaResetV2()
	if _resetBusy then return end
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	_resetBusy = true
	local cam = workspace.CurrentCamera
	local lockCF = cam and cam.CFrame
	pcall(function()
 if cam then cam.CameraType = Enum.CameraType.Scriptable; cam.CFrame = lockCF end
 RS:BindToRenderStep("MeridianInstaV2Cam", Enum.RenderPriority.Camera.Value + 1, function()
 pcall(function()
 if cam then cam.CameraType = Enum.CameraType.Scriptable; if lockCF then cam.CFrame = lockCF end end
 local ac = LP.Character
 local ah = ac and ac:FindFirstChild("HumanoidRootPart")
 if ah then
 ah.AssemblyLinearVelocity = Vector3.zero
 ah.CFrame = INST_V2_POS
 end
 end)
 end)
	end)
	local conn
	conn = LP.CharacterAdded:Connect(function(newChar)
 if conn then conn:Disconnect() end
 pcall(function() RS:UnbindFromRenderStep("MeridianInstaV2Cam") end)
 local nh = newChar:WaitForChild("Humanoid", 5)
 task.wait(0.05)
 pcall(function()
 if cam and nh then cam.CameraSubject = nh; cam.CameraType = Enum.CameraType.Custom end
 end)
 _resetBusy = false
	end)
	task.delay(8, function()
 if _resetBusy then
 pcall(function() RS:UnbindFromRenderStep("MeridianInstaV2Cam") end)
 _resetBusy = false
 end
	end)
end

function InstaResetV1()
	-- V1: HipHeight kill — does NOT lock the camera, it still rotates horizontally/vertically as normal
	if _resetCD then return end
	local character = LP.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not hrp then return end
	_resetCD = true
	_resetBusy = true
	local originalHip = humanoid.HipHeight
	local cam = workspace.CurrentCamera

	-- Keep the camera on Custom — the player rotates it themselves, no Scriptable / no BindToRenderStep
	pcall(function()
 if cam then
 cam.CameraType = Enum.CameraType.Custom
 if humanoid then cam.CameraSubject = humanoid end
 end
 pcall(function() RS:UnbindFromRenderStep("MeridianInstaV1Cam") end)
 pcall(function() RS:UnbindFromRenderStep("MeridianInstaV2Cam") end)
	end)

	local charConn
	charConn = LP.CharacterAdded:Connect(function(newChar)
 if charConn then charConn:Disconnect() end
 local nh = newChar:WaitForChild("Humanoid", 5)
 task.wait(0.05)
 pcall(function()
 local c = workspace.CurrentCamera
 if c and nh then
 c.CameraSubject = nh
 c.CameraType = Enum.CameraType.Custom
 end
 end)
 _resetCD = false
 _resetBusy = false
	end)

	task.spawn(function()
 local attempts = 0
 while character and character.Parent and humanoid and attempts < 40 do
 if LP.Character ~= character then break end
 pcall(function()
 humanoid.PlatformStand = false
 humanoid.Sit = false
 pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
 pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
 humanoid.HipHeight = 1e30
 humanoid.AutoRotate = true
 local rp = character:FindFirstChild("HumanoidRootPart")
 if rp then rp.CanCollide = false end
 for _, part in ipairs(character:GetChildren()) do
 if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
 part.CanCollide = false
 end
 end
 -- camera stays Custom every frame (in case another script changes it)
 if cam then
 cam.CameraType = Enum.CameraType.Custom
 cam.CameraSubject = humanoid
 end
 end)
 if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then break end
 attempts = attempts + 1
 task.wait(0.05)
 end
 if character and character.Parent and humanoid and humanoid.Health > 0 then
 pcall(function() humanoid.Health = 0 end)
 end
 if character and character.Parent and humanoid then
 pcall(function()
 humanoid.HipHeight = originalHip
 local rp = character:FindFirstChild("HumanoidRootPart")
 if rp then rp.CanCollide = true end
 end)
 end
 task.delay(5, function()
 if _resetBusy then
 _resetCD = false
 _resetBusy = false
 end
 end)
	end)
end

function doInstaReset()
	if St.instaMode == "V2" then InstaResetV2() else InstaResetV1() end
end

----------------------------------------------------------------
-- TP DOWN (Meridian)
----------------------------------------------------------------
function doTPDown(force)
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end
	if not force then
 if hum.FloorMaterial ~= Enum.Material.Air then return end
 if hrp.Position.Y < 20 then return end
	end
	hrp.CFrame = CFrame.new(hrp.Position.X, -7, hrp.Position.Z)
 * CFrame.Angles(0, select(2, hrp.CFrame:ToEulerAnglesYXZ()), 0)
	hrp.AssemblyLinearVelocity = Vector3.zero
end

----------------------------------------------------------------
-- ESP + TRACER + ANTI LAG
----------------------------------------------------------------
local ESP = { on = false, data = {}, conns = {} }
function espCleanup(plr)
	local d = ESP.data[plr]
	if not d then return end
	pcall(function() if d.hl then d.hl:Destroy() end end)
	pcall(function() if d.bb then d.bb:Destroy() end end)
	pcall(function() if d.tracer then d.tracer:Remove() end end)
	ESP.data[plr] = nil
end
function espSetup(plr, char)
	if not ESP.on or plr == LP or not char then return end
	espCleanup(plr)
	local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 3)
	local head = char:FindFirstChild("Head")
	if not hrp then return end
	local hl = Instance.new("Highlight")
	hl.Adornee = char
	hl.FillColor = Color3.fromRGB(35, 35, 35)
	hl.FillTransparency = 0.7
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = char
	local bb, tracer
	if head then
 bb = Instance.new("BillboardGui")
 bb.Adornee = head
 bb.Size = UDim2.new(0, 100, 0, 20)
 bb.StudsOffset = Vector3.new(0, 2.5, 0)
 bb.AlwaysOnTop = true
 bb.Parent = head
 local t = Instance.new("TextLabel", bb)
 t.Size = UDim2.new(1, 0, 1, 0)
 t.BackgroundTransparency = 1
 t.Text = plr.DisplayName or plr.Name
 t.TextColor3 = Color3.new(1, 1, 1)
 t.TextSize = 12
 t.Font = Enum.Font.GothamBold
 t.TextStrokeTransparency = 0.5
	end
	if St.tracer then
 tracer = Drawing and Drawing.new and Drawing.new("Line")
 if tracer then
 tracer.Thickness = 1
 tracer.Color = Color3.fromRGB(255, 255, 255)
 tracer.Visible = true
 end
	end
	ESP.data[plr] = { hl = hl, bb = bb, tracer = tracer, hrp = hrp }
end
function startESP()
	if ESP.on then return end
	ESP.on = true
	for _, plr in ipairs(Players:GetPlayers()) do
 if plr ~= LP and plr.Character then espSetup(plr, plr.Character) end
 table.insert(ESP.conns, plr.CharacterAdded:Connect(function(c)
 task.defer(espSetup, plr, c)
 end))
	end
	table.insert(ESP.conns, Players.PlayerAdded:Connect(function(plr)
 table.insert(ESP.conns, plr.CharacterAdded:Connect(function(c)
 task.defer(espSetup, plr, c)
 end))
	end))
	table.insert(ESP.conns, Players.PlayerRemoving:Connect(espCleanup))
	-- tracer loop only exists while Tracer is ON (setTracer restarts ESP when it changes)
	if St.tracer then
		table.insert(ESP.conns, RS.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if not cam or not my then return end
			local o = cam:WorldToViewportPoint(my.Position)
			local from = Vector2.new(o.X, o.Y)
			for _, d in pairs(ESP.data) do
				if d.tracer and d.hrp and d.hrp.Parent then
					local p, onScreen = cam:WorldToViewportPoint(d.hrp.Position)
					d.tracer.From = from
					d.tracer.To = Vector2.new(p.X, p.Y)
					d.tracer.Visible = onScreen and p.Z > 0
				elseif d.tracer then
					d.tracer.Visible = false
				end
			end
		end))
	end
end
function stopESP()
	ESP.on = false
	for _, c in ipairs(ESP.conns) do pcall(function() c:Disconnect() end) end
	ESP.conns = {}
	for plr in pairs(ESP.data) do espCleanup(plr) end
end
function setESP(on)
	St.esp = on
	if on then startESP() else stopESP() end
	saveCfg()
end
function setTracer(on)
	St.tracer = on
	if St.esp then stopESP(); startESP() end
	saveCfg()
end

-- Anti Lag (Meridian simplified)
local antiLagConn = nil
function applyDerender(obj)
	if obj:IsA("Accessory") or obj:IsA("Hat") then
		obj:Destroy()
	elseif obj:IsA("BasePart") then
		obj.Material = Enum.Material.Plastic
		obj.Reflectance = 0
		obj.CastShadow = false
	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		obj.Transparency = 1
	elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
		or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
		obj.Enabled = false
	end
end
function setAntiLag(on)
	St.antiLag = on
	if on then
 Lighting.GlobalShadows = false
 Lighting.FogEnd = 1e10
 Lighting.Brightness = 0
 for _, e in pairs(Lighting:GetChildren()) do
 if e:IsA("BlurEffect") or e:IsA("BloomEffect") or e:IsA("SunRaysEffect")
 or e:IsA("ColorCorrectionEffect") or e:IsA("DepthOfFieldEffect") then
 pcall(function() e.Enabled = false end)
 end
 end
 -- chunked so enabling Anti Lag on a big map does not freeze one frame
 local token = {}
 _zAntiLagToken = token
 task.spawn(function()
 local n = 0
 for _, obj in ipairs(workspace:GetDescendants()) do
 if _zAntiLagToken ~= token then return end
 pcall(applyDerender, obj)
 n = n + 1
 if n % 300 == 0 then task.wait() end
 end
 end)
 if antiLagConn then antiLagConn:Disconnect() end
 antiLagConn = workspace.DescendantAdded:Connect(function(o) pcall(applyDerender, o) end)
	else
 if antiLagConn then antiLagConn:Disconnect() antiLagConn = nil end
 _zAntiLagToken = nil
 Lighting.GlobalShadows = true
 Lighting.FogEnd = 100000
 Lighting.Brightness = 2
	end
	saveCfg()
end

----------------------------------------------------------------
-- INFINITE JUMP (Meridian hold)
----------------------------------------------------------------

-- AUTO DESTROY SENTRY (full from AutoDestroyTurret)
----------------------------------------------------------------
local GTurret = { AutoDestroyTurret = false }
local turretBusy = setmetatable({}, { __mode = "k" })
local turretQueued = setmetatable({}, { __mode = "k" })
local turretCD = setmetatable({}, { __mode = "k" })
local activeTurretAtk = 0
function isEnemyTurret(obj)
	if not obj or not obj:IsA("BasePart") then return false end
	local name, nameLower = obj.Name, obj.Name:lower()
	local ownerId = name:match("^Sentry_(%d+)$") or name:match("^sentry_(%d+)$")
	if not ownerId then
 ownerId = name:match("^CandySentry_(%d+)$") or name:match("^Candy_Sentry_(%d+)$")
 or name:match("^candy_sentry_(%d+)$") or nameLower:match("^candy[_%-]?sentry_(%d+)$")
	end
	if not ownerId and nameLower:find("candy") and nameLower:find("sentry") then
 ownerId = name:match("(%d+)$")
	end
	if not ownerId then ownerId = name:match("^[Tt]urret_(%d+)$") end
	if not ownerId and nameLower:find("sentry") then ownerId = name:match("(%d+)$") end
	return ownerId ~= nil and tostring(ownerId) ~= tostring(LP.UserId)
end
function setTurretNoClip(turret)
	if not isEnemyTurret(turret) then return end
	pcall(function()
 turret.CanCollide = false
 turret.Anchored = true
 turret.AssemblyLinearVelocity = Vector3.zero
 turret.AssemblyAngularVelocity = Vector3.zero
	end)
end
function getTurretTimeLabel(turret)
	if not turret or not turret.Parent then return nil end
	local sf = turret:FindFirstChild("SetupFrame")
	local mf = sf and sf:FindFirstChild("MainFrame")
	local tl = mf and mf:FindFirstChild("Time")
	if tl and tl:IsA("TextLabel") then return tl end
	for _, d in ipairs(turret:GetDescendants()) do
 if d:IsA("TextLabel") then
 local n = d.Name:lower()
 if n == "time" or n == "timer" or n == "countdown" then return d end
 end
	end
	return nil
end
function shouldAttackTurret(turret)
	if LP:GetAttribute("Stealing") ~= nil then return false end
	if not isEnemyTurret(turret) then return false end
	setTurretNoClip(turret)
	local timeLabel = getTurretTimeLabel(turret)
	if timeLabel then
 local ok, text = pcall(function() return timeLabel.Text end)
 if not ok then return false end
 text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
 if text == "" then return false end
 if string.find(text, "^%d+%s*[sS]!?$") or string.find(text, "^%d+$") then return true end
 return false
	end
	return true
end
function bringTurretInFront(turret, hrp)
	if not turret or not hrp then return end
	local forward = hrp.CFrame.LookVector
	local targetPos = hrp.Position + forward * 2.8 + Vector3.new(0, 1.15, 0)
	pcall(function()
 turret.AssemblyLinearVelocity = Vector3.zero
 turret.CFrame = CFrame.lookAt(targetPos, targetPos + forward)
	end)
end
function findBat()
	local char = LP.Character
	if not char then return nil end
	local bat = char:FindFirstChild("Bat") or LP.Backpack:FindFirstChild("Bat")
	if bat then return bat end
	for _, t in ipairs(char:GetChildren()) do
 if t:IsA("Tool") and t.Name:lower():find("bat") then return t end
	end
	for _, t in ipairs(LP.Backpack:GetChildren()) do
 if t:IsA("Tool") and t.Name:lower():find("bat") then return t end
	end
	return nil
end
function ensureBat(hum, char)
	local held = char:FindFirstChildOfClass("Tool")
	if held and (held.Name == "Bat" or held.Name:lower():find("bat")) then return held end
	local bat = findBat()
	if not bat then return nil end
	pcall(function() hum:EquipTool(bat) end)
	return char:FindFirstChild("Bat") or bat
end
function attackTurret(turret)
	local now = os.clock()
	if turretBusy[turret] or turretQueued[turret] then return end
	if activeTurretAtk >= 2 then return end
	if not shouldAttackTurret(turret) then return end
	if (turretCD[turret] or 0) > now then return end
	turretQueued[turret] = true
	turretCD[turret] = now + 0.15
	task.spawn(function()
 turretQueued[turret] = nil
 if activeTurretAtk >= 2 or turretBusy[turret] or not shouldAttackTurret(turret) then return end
 activeTurretAtk = activeTurretAtk + 1
 turretBusy[turret] = true
 pcall(function()
 local attempts, batReady = 0, false
 while attempts < 18 and GTurret.AutoDestroyTurret do
 if not turret or not turret.Parent or not shouldAttackTurret(turret) then break end
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 local hum = char and char:FindFirstChildOfClass("Humanoid")
 if not hrp or not hum or hum.Health <= 0 then break end
 local okD, dist = pcall(function() return (turret.Position - hrp.Position).Magnitude end)
 if okD and dist > 250 then break end
 setTurretNoClip(turret)
 bringTurretInFront(turret, hrp)
 local bat
 if not batReady then
 bat = ensureBat(hum, char)
 batReady = bat ~= nil
 else
 bat = char:FindFirstChild("Bat") or findBat()
 local held = char:FindFirstChildOfClass("Tool")
 if held and held.Name ~= "Bat" and not held.Name:lower():find("bat") then break end
 end
 if bat then pcall(function() bat:Activate() end) end
 attempts = attempts + 1
 task.wait(0.045)
 end
 end)
 turretBusy[turret] = nil
 activeTurretAtk = math.max(0, activeTurretAtk - 1)
	end)
end
local turretSet = setmetatable({}, { __mode = "k" })
local turretSeeded = false
workspace.DescendantAdded:Connect(function(obj)
	if isEnemyTurret(obj) then
		turretSet[obj] = true
		setTurretNoClip(obj)
	end
	if GTurret.AutoDestroyTurret and shouldAttackTurret(obj) then task.defer(attackTurret, obj) end
end)
workspace.DescendantRemoving:Connect(function(obj) turretSet[obj] = nil end)
task.spawn(function()
	while task.wait(0.25) do
 if GTurret.AutoDestroyTurret then
 -- one full scan the first time it is ON; after that only the tracked turrets are visited
 if not turretSeeded then
 turretSeeded = true
 local n = 0
 for _, obj in ipairs(workspace:GetDescendants()) do
 if isEnemyTurret(obj) then turretSet[obj] = true end
 n = n + 1
 if n % 2000 == 0 then task.wait() end
 end
 end
 local pending = {}
 for obj in pairs(turretSet) do
 if obj.Parent and isEnemyTurret(obj) then
 setTurretNoClip(obj)
 if shouldAttackTurret(obj) and not turretBusy[obj] then
 table.insert(pending, obj)
 end
 end
 end
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 if hrp and #pending > 0 then
 table.sort(pending, function(a, b)
 return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
 end)
 for i = 1, math.min(2, #pending) do attackTurret(pending[i]) end
 end
 end
	end
end)
function setDestroySentry(on)
	St.destroySentry = on and true or false
	GTurret.AutoDestroyTurret = St.destroySentry
	if _G.MeridianRefreshSentryBtn then _G.MeridianRefreshSentryBtn() end
	saveCfg()
end

----------------------------------------------------------------
-- SPAM LASER CAPE / PAINTBALL (activate only, no auto-equip)
----------------------------------------------------------------
local spamConn = nil
function startSpamLoop()
	if spamConn then return end
	spamConn = RS.Heartbeat:Connect(function()
 local char = LP.Character
 if not char then return end
 local tool = char:FindFirstChildOfClass("Tool")
 if not tool then return end
 local n = tool.Name
 if St.spamLaser and n == "Laser Cape" then
 if aimOn then overrideMouse() end
 pcall(function() tool:Activate() end)
 elseif St.spamPaint and n == "Paintball Gun" then
 if aimOn then overrideMouse() end
 pcall(function() tool:Activate() end)
 end
	end)
end
function stopSpamLoopIfIdle()
	if not St.spamLaser and not St.spamPaint then
 if spamConn then pcall(function() spamConn:Disconnect() end) spamConn = nil end
	end
end
function setSpamLaser(on)
	St.spamLaser = on and true or false
	if St.spamLaser then startSpamLoop() else stopSpamLoopIfIdle() end
	saveCfg()
end
function setSpamPaint(on)
	St.spamPaint = on and true or false
	if St.spamPaint then startSpamLoop() else stopSpamLoopIfIdle() end
	saveCfg()
end

----------------------------------------------------------------
-- COUNTER: Laser Cape / Boogie Bomb / Swap Body / Equip on Drop
----------------------------------------------------------------
local counterConn = nil
local COUNTER_TOOL_NAMES = {
	laser = { "Laser Cape", "LaserCape", "laser cape" },
	boogie = { "Boogie Bomb", "BoogieBomb", "boogie bomb", "Disco Ball" },
	swap = { "Body Swap Potion", "Swap Body", "Body Swap", "SwapBody", "Potion of Body Swap" },
}

local function findToolByNames(names)
	local char = LP.Character
	local bp = LP:FindFirstChild("Backpack")
	for _, nm in ipairs(names) do
 if char then
 local t = char:FindFirstChild(nm)
 if t and t:IsA("Tool") then return t end
 end
 if bp then
 local t = bp:FindFirstChild(nm)
 if t and t:IsA("Tool") then return t end
 end
	end
	-- fuzzy
	local function scan(parent)
 if not parent then return nil end
 for _, ch in ipairs(parent:GetChildren()) do
 if ch:IsA("Tool") then
 local ln = string.lower(ch.Name)
 for _, nm in ipairs(names) do
 if ln:find(string.lower(nm), 1, true) then return ch end
 end
 end
 end
 return nil
	end
	return scan(char) or scan(bp)
end

local function equipAndActivate(tool)
	if not tool then return end
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	pcall(function()
 if tool.Parent ~= char then
 hum:EquipTool(tool)
 end
	end)
	task.defer(function()
 pcall(function() tool:Activate() end)
	end)
end

function stopCounterLoopIfIdle()
	if not (St.counterLaser or St.counterBoogie or St.counterSwapBody or St.equipOnDrop) then
 if counterConn then pcall(function() counterConn:Disconnect() end) counterConn = nil end
	end
end

local function _counterExclusive(which)
	-- Only 1 counter ON: turn the others OFF
	St.counterLaser = (which == "laser")
	St.counterBoogie = (which == "boogie")
	St.counterSwapBody = (which == "swap")
	if ToggleRefs then
 for k, flag in pairs({counterLaser = (which=="laser"), counterBoogie = (which=="boogie"), counterSwapBody = (which=="swap")}) do
 local r = ToggleRefs[k]
 if r and r.setVisual then pcall(r.setVisual, flag) end
 end
	end
end

function setCounterLaser(on)
	if on then
 _counterExclusive("laser")
 -- only saves the selection; equip + activate x2 on Drop
 stopCounterLoopIfIdle()
	else
 St.counterLaser = false
 stopCounterLoopIfIdle()
	end
	saveCfg()
end
function setCounterBoogie(on)
	if on then
 _counterExclusive("boogie")
 -- only saves the selection; equip + activate x2 on Drop
 stopCounterLoopIfIdle()
	else
 St.counterBoogie = false
 stopCounterLoopIfIdle()
	end
	saveCfg()
end
function setCounterSwapBody(on)
	if on then
 _counterExclusive("swap")
 -- only saves the selection; equip + activate x2 on Drop
 stopCounterLoopIfIdle()
	else
 St.counterSwapBody = false
 stopCounterLoopIfIdle()
	end
	saveCfg()
end
function setEquipOnDrop(on)
	St.equipOnDrop = on and true or false
	saveCfg()
end

-- Equip + activate after Drop finishes
_G.MeridianCounterOnDrop = function()
	-- Selected counter: equip 1 + activate 2 on Drop (Fling & Jump)
	local anyCounter = St.counterLaser or St.counterBoogie or St.counterSwapBody
	if not anyCounter and not St.equipOnDrop then return end
	if _G._MeridianCounterDropBusy == true then return end
	_G._MeridianCounterDropBusy = true
	task.spawn(function()
 local char = LP.Character
 local hum = char and char:FindFirstChildOfClass("Humanoid")
 local prevTool = char and char:FindFirstChildOfClass("Tool")
 local prevName = prevTool and prevTool.Name or nil
 task.wait(0.2)
 local function runOnce(names)
 local tool = findToolByNames(names)
 if not tool then return end
 equipAndActivate(tool) -- equip + activate #1
 task.wait(0.15)
 pcall(function() tool:Activate() end) -- activate #2
 task.wait(0.1)
 end
 if St.counterLaser then runOnce(COUNTER_TOOL_NAMES.laser) end
 if St.counterBoogie then runOnce(COUNTER_TOOL_NAMES.boogie) end
 if St.counterSwapBody then runOnce(COUNTER_TOOL_NAMES.swap) end
 task.wait(0.1)
 pcall(function()
 local c = LP.Character
 local h = c and c:FindFirstChildOfClass("Humanoid")
 if not h or not prevName then return end
 local pl = string.lower(prevName)
 local isCounter = false
 for _, names in pairs(COUNTER_TOOL_NAMES) do
 for _, nm in ipairs(names) do
 if pl:find(string.lower(nm), 1, true) then isCounter = true break end
 end
 if isCounter then break end
 end
 if not isCounter then
 local bp = LP:FindFirstChild("Backpack")
 local t = (c and c:FindFirstChild(prevName)) or (bp and bp:FindFirstChild(prevName))
 if t and t:IsA("Tool") then h:EquipTool(t) end
 end
 end)
 _G._MeridianCounterDropBusy = false
	end)
end

-- Counter toggle ON: equip 1 + activate 2 (once)
_G.MeridianCounterOneShot = function(kind)
	if _G._MeridianCounterDropBusy then return end
	_G._MeridianCounterDropBusy = true
	task.spawn(function()
 local names = COUNTER_TOOL_NAMES[kind]
 if not names then _G._MeridianCounterDropBusy = false return end
 local tool = findToolByNames(names)
 if tool then
 equipAndActivate(tool)
 task.wait(0.15)
 pcall(function() tool:Activate() end)
 end
 _G._MeridianCounterDropBusy = false
	end)
end

function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
	return c
end
function stroke(p, col)
	local s = Instance.new("UIStroke")
	s.Color = col or C.stroke
	s.Thickness = 1
	s.Transparency = 0.35
	s.Parent = p
	return s
end

-- ============================================================
-- GLOW / GRADIENT STYLE (toggles + pickers)
-- ============================================================
-- Font used for feature names (toggles, pickers, buttons). Change here to swap everywhere.
NAME_FONT = Enum.Font.Oswald

function gradFill(p, rot, lo)
	local g = p:FindFirstChild("FillGrad")
	if not g then
		g = Instance.new("UIGradient")
		g.Name = "FillGrad"
		g.Parent = p
	end
	g.Rotation = rot or 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), lo or Color3.fromRGB(150, 150, 150))
	return g
end
function glowStroke(p, thick)
	local s = p:FindFirstChild("GlowStroke")
	if not s then
		s = Instance.new("UIStroke")
		s.Name = "GlowStroke"
		s.Color = Color3.new(1, 1, 1)
		s.Thickness = thick or 1.5
		s.Transparency = 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- TextButtons would outline the text otherwise
		s.Parent = p
	end
	return s
end
function haloFor(p, pad, cr)
	-- soft glow body sitting behind p (sibling), same center as p
	local pos, sz = p.Position, p.Size
	local h = Instance.new("Frame")
	h.Name = "Halo"
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.new(pos.X.Scale + sz.X.Scale / 2, pos.X.Offset + sz.X.Offset / 2,
		pos.Y.Scale + sz.Y.Scale / 2, pos.Y.Offset + sz.Y.Offset / 2)
	h.Size = UDim2.new(sz.X.Scale, sz.X.Offset + pad * 2, sz.Y.Scale, sz.Y.Offset + pad * 2)
	h.BackgroundColor3 = Color3.new(1, 1, 1)
	h.BackgroundTransparency = 1
	h.BorderSizePixel = 0
	h.ZIndex = math.max(p.ZIndex - 1, 0)
	h.Parent = p.Parent
	corner(h, cr or 12)
	return h
end
function paintChoice(b, on)
	-- picker button: selected = bright gradient + glow ring + halo
	b.BackgroundColor3 = on and C.accent or C.box
	b.TextColor3 = on and Color3.fromRGB(24, 24, 24) or C.text
	gradFill(b, 90, on and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(95, 95, 95))
	glowStroke(b, 1.5).Transparency = on and 0.1 or 1
	local par = b.Parent
	if not par then return end
	local hname = "Halo_" .. b.Text
	local h = par:FindFirstChild(hname)
	if not h then
		local uc = b:FindFirstChildOfClass("UICorner")
		h = haloFor(b, 5, (uc and uc.CornerRadius.Offset or 8) + 5)
		h.Name = hname
	end
	h.BackgroundTransparency = on and 0.86 or 1
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "MeridianHubFullMenu"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 200
Gui.Parent = PlayerGui

local MW, MH = 310, 320
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, MW, 0, MH)
Main.Position = UDim2.new(0.5, -MW / 2, 0.5, -MH / 2)
Main.BackgroundColor3 = C.bg
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Main.Parent = Gui

-- Menu scale (enlarge/shrink the main menu)
local menuScaleObj = Instance.new("UIScale")
menuScaleObj.Name = "MeridianMenuScale"
menuScaleObj.Scale = tonumber(St.menuScale) or 1
menuScaleObj.Parent = Main
function applyMenuScale()
	local sc = math.clamp(tonumber(St.menuScale) or 1, 0.5, 1.5)
	St.menuScale = sc
	if menuScaleObj and menuScaleObj.Parent then
 menuScaleObj.Scale = sc
	else
 -- fallback: resize Main
 local baseW, baseH = 270, 360
 Main.Size = UDim2.new(0, math.floor(baseW * sc), 0, math.floor(baseH * sc))
	end
end
pcall(applyMenuScale)
-- restore menu position
pcall(function()
	local p = St._mainPos
	if type(p) == "table" and p[1] ~= nil then
 Main.Position = UDim2.new(p[1], p[2], p[3], p[4])
	end
end)

corner(Main, 14)
local mainStroke = stroke(Main)
mainStroke.Thickness = 2.2
mainStroke.Transparency = 0
-- Wallpaper legibility: soft dark outline on light text that sits directly over the image
do
	local function polish(inst)
		if not inst:IsA("TextLabel") then return end
		task.defer(function()
			if not inst.Parent or inst.BackgroundTransparency < 0.95 or inst.TextStrokeTransparency < 1 then return end
			local p = inst.Parent
			if p:IsA("GuiObject") and p.BackgroundTransparency < 0.95 then return end -- sits on a solid box: leave it
			local c = inst.TextColor3
			if (c.R * 0.299 + c.G * 0.587 + c.B * 0.114) < 0.6 then return end
			inst.TextStrokeColor3 = Color3.new(0, 0, 0)
			inst.TextStrokeTransparency = 0.55
		end)
	end
	Main.DescendantAdded:Connect(polish)
	for _, d in ipairs(Main:GetDescendants()) do polish(d) end
end
-- Empire-style animated outline gradient
do
	local g = Instance.new("UIGradient")
	g.Name = "EmpireOutlineGrad"
	g.Color = ColorSequence.new({
 ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
 ColorSequenceKeypoint.new(0.15, Color3.fromRGB(200, 200, 200)),
 ColorSequenceKeypoint.new(0.35, Color3.fromRGB(150, 150, 150)),
 ColorSequenceKeypoint.new(0.55, Color3.fromRGB(110, 110, 110)),
 ColorSequenceKeypoint.new(0.75, Color3.fromRGB(150, 150, 150)),
 ColorSequenceKeypoint.new(0.90, Color3.fromRGB(205, 205, 205)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	g.Parent = mainStroke
	task.spawn(function()
 local t0 = tick()
 while mainStroke and mainStroke.Parent do
 local t = (tick() - t0) * 0.35
 g.Rotation = (t * 60) % 360
 task.wait(0.03)
 end
	end)
end

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 44)
Top.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Top.BorderSizePixel = 0
Top.ZIndex = 15
Top.Active = true
Top.ClipsDescendants = true -- nothing in the header can ever spill past its background
Top.Parent = Main
corner(Top, 14)
local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 12)
topFix.Position = UDim2.new(0, 0, 1, -12)
topFix.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
topFix.BorderSizePixel = 0
topFix.Parent = Top

-- Header: big "Meridian" + spaced "ALL GEAR" between two thin lines
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 24)
Title.Position = UDim2.new(0, 0, 0, 3)
Title.BackgroundTransparency = 1
Title.Text = "Meridian"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 19
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.ZIndex = 16
Title.Parent = Top
pcall(function() Title.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold) end)

do
	local SUB = "A L L   G E A R"
	local subW = 80
	pcall(function()
		subW = game:GetService("TextService"):GetTextSize(SUB, 10, Enum.Font.GothamBold, Vector2.new(400, 20)).X
	end)
	local GAP = 8
	-- the row has a 12px margin on both sides and clips, so the lines stay inside the background
	local Row = Instance.new("Frame")
	Row.Name = "HeaderDivider"
	Row.BackgroundTransparency = 1
	Row.Position = UDim2.new(0, 12, 0, 29)
	Row.Size = UDim2.new(1, -24, 0, 12)
	Row.ClipsDescendants = true
	Row.ZIndex = 16
	Row.Parent = Top
	local Sub = Instance.new("TextLabel")
	Sub.Name = "Subtitle"
	Sub.AnchorPoint = Vector2.new(0.5, 0.5)
	Sub.Position = UDim2.new(0.5, 0, 0.5, 0)
	Sub.Size = UDim2.new(0, subW + 2, 1, 0)
	Sub.BackgroundTransparency = 1
	Sub.Text = SUB
	Sub.TextColor3 = Color3.fromRGB(150, 150, 150)
	Sub.TextSize = 10
	Sub.Font = Enum.Font.GothamBold
	Sub.ZIndex = 17
	Sub.Parent = Row
	local function divLine(rightSide)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.fromRGB(72, 72, 72)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(rightSide and 1 or 0, 0.5)
		f.Position = UDim2.new(rightSide and 1 or 0, 0, 0.5, 0)
		f.Size = UDim2.new(0.5, -(subW / 2 + GAP), 0, 1)
		f.ZIndex = 16
		f.Parent = Row
	end
	divLine(false)
	divLine(true)
end

-- Small close button in the right corner (secondary)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
CloseBtn.Text = "−"
CloseBtn.TextColor3 = C.textDim
CloseBtn.TextSize = 11
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Top
corner(CloseBtn, 6)

-- Round helper on the LEFT of the menu (LKZ style) — press = close
local Helper = Instance.new("TextButton")
Helper.Name = "HelperClose"
Helper.Size = UDim2.new(0, 44, 0, 44)
Helper.Position = UDim2.new(0, -52, 0, 8)
Helper.BackgroundColor3 = Color3.fromRGB(19, 19, 19)
Helper.Text = "⚔"
Helper.TextColor3 = C.accent
Helper.TextSize = 18
Helper.Font = Enum.Font.GothamBold
Helper.AutoButtonColor = false
Helper.Parent = Main
corner(Helper, 22)
local hs = Instance.new("UIStroke", Helper)
hs.Color = C.accent
hs.Thickness = 2
hs.Transparency = 0.15

-- Vertical tabs (Clean style) — PC can scroll down
local TAB_W = 72
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(0, TAB_W, 1, -48)
TabBar.Position = UDim2.new(0, 4, 0, 44)
TabBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TabBar.BackgroundTransparency = 1 -- same as the content side, so the wallpaper shows evenly
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 4
TabBar.ScrollBarImageColor3 = C.accent
TabBar.ScrollingDirection = Enum.ScrollingDirection.Y
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabBar.ZIndex = 20
TabBar.Active = true
TabBar.Selectable = true
TabBar.Parent = Main
corner(TabBar, 8)
local tabList = Instance.new("UIListLayout", TabBar)
tabList.FillDirection = Enum.FillDirection.Vertical
tabList.Padding = UDim.new(0, 4)
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabList.SortOrder = Enum.SortOrder.LayoutOrder
local tabPad = Instance.new("UIPadding", TabBar)
tabPad.PaddingTop = UDim.new(0, 4)
tabPad.PaddingBottom = UDim.new(0, 6)
tabPad.PaddingLeft = UDim.new(0, 3)
tabPad.PaddingRight = UDim.new(0, 3)

local pages, tabBtns = {}, {}
function makePage(name)
	local sc = Instance.new("ScrollingFrame")
	sc.Name = name
	-- Content on the right of the vertical tabs
	sc.Size = UDim2.new(1, -(TAB_W + 10), 1, -52)
	sc.Position = UDim2.new(0, TAB_W + 8, 0, 48)
	sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0
	sc.ScrollBarThickness = 4
	sc.ScrollBarImageColor3 = C.accent
	sc.ScrollingDirection = Enum.ScrollingDirection.Y
	sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sc.CanvasSize = UDim2.new(0, 0, 0, 0)
	sc.Visible = false
	sc.ZIndex = 10
	sc.Active = true
	sc.Selectable = true
	sc.Parent = Main
	local pad = Instance.new("UIPadding", sc)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 8)
	local lay = Instance.new("UIListLayout", sc)
	lay.Padding = UDim.new(0, 7)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	sc.Active = true
	sc.Selectable = true
	pages[name] = sc
	return sc
end
local pagePlayer = makePage("Player")
local pageESP = makePage("ESP")
local pageSpam = makePage("Spam")
local pageCounter = makePage("Counter")
local pageSet = makePage("Settings")
local pageKeys = makePage("Keybinds")

function setTab(name)
	for n, p in pairs(pages) do
 p.Visible = (n == name)
 p.ZIndex = 3
	end
	for n, b in pairs(tabBtns) do
 local on = n == name
 b.BackgroundColor3 = on and C.accent or C.card
 b.BackgroundTransparency = on and 0 or 1
 b.TextColor3 = on and Color3.fromRGB(24, 24, 24) or C.text
 b.TextStrokeTransparency = on and 1 or 0.55
	end
end
function addTab(name, order)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -4, 0, 28)
	b.BackgroundColor3 = C.card
	b.BackgroundTransparency = 1
	b.Text = name
	b.TextColor3 = C.text
	b.TextStrokeColor3 = Color3.new(0, 0, 0)
	b.TextStrokeTransparency = 0.55
	b.TextSize = 11
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = false
	b.LayoutOrder = order
	b.Active = true
	b.Selectable = true
	b.ZIndex = 21
	b.Parent = TabBar
	corner(b, 8)
	local function go() setTab(name) end
	b.MouseButton1Click:Connect(go)
	b.Activated:Connect(go)
	tabBtns[name] = b
end
addTab("Player", 1)
addTab("ESP", 2)
addTab("Spam", 3)
addTab("Counter", 4)
addTab("Settings", 5)
addTab("Keybinds", 6)

function section(parent, text, order)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 20)
	f.BackgroundTransparency = 1
	f.LayoutOrder = order
	f.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextSize = 14
	t.Font = Enum.Font.GothamBlack
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = f
	local g = Instance.new("UIGradient")
	g.Name = "LabelGrad"
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))
	g.Parent = t
end
function row(parent, h, order)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, h or 38)
	f.BackgroundColor3 = C.card
	f.BackgroundTransparency = 1 -- see-through pill: the wallpaper shows behind it
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.Active = true
	f.Parent = parent
	corner(f, 9)
	local rowStroke = stroke(f)
	rowStroke.Color = Color3.fromRGB(235, 235, 235)
	rowStroke.Transparency = 0.6
	return f
end
function toggle(parent, label, default, cb, order)
	local r = row(parent, 38, order)
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, -60, 1, 0)
	txt.Position = UDim2.new(0, 12, 0, 0)
	txt.BackgroundTransparency = 1
	txt.Text = label
	txt.TextColor3 = C.text
	txt.TextSize = 13
	txt.Font = NAME_FONT
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.Parent = r
	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 40, 0, 22)
	track.Position = UDim2.new(1, -50, 0.5, -11)
	track.BackgroundColor3 = default and C.on or C.off
	track.BorderSizePixel = 0
	track.Parent = r
	corner(track, 11)
	gradFill(track, 45, Color3.fromRGB(140, 140, 140))
	local trackGlow = glowStroke(track, 1.5)
	trackGlow.Transparency = default and 0.15 or 1
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	knob.BackgroundColor3 = default and Color3.fromRGB(20, 20, 20) or Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 9)
	gradFill(knob, 90, Color3.fromRGB(190, 190, 190))
	local halo = haloFor(track, 6, 17)
	halo.ZIndex = 5
	halo.BackgroundTransparency = default and 0.86 or 1
	local function glow(on, t)
		local ti = TweenInfo.new(t)
		TS:Create(trackGlow, ti, { Transparency = on and 0.15 or 1 }):Play()
		TS:Create(halo, ti, { BackgroundTransparency = on and 0.86 or 1 }):Play()
	end
	local state = default
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = r
	local function apply(on)
 state = on and true or false
 TS:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = state and C.on or C.off }):Play()
 TS:Create(knob, TweenInfo.new(0.15), {
 BackgroundColor3 = state and Color3.fromRGB(20, 20, 20) or Color3.new(1, 1, 1),
 Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
 }):Play()
 glow(state, 0.15)
 if cb then pcall(cb, state) end
 pcall(saveCfg)
	end
	btn.Active = true
	btn.Selectable = true
	btn.ZIndex = 50
	track.ZIndex = 6
	knob.ZIndex = 7
	r.Active = true
	local _busy = false
	local function fireToggle()
 if _busy then return end
 _busy = true
 apply(not state)
 task.delay(0.15, function() _busy = false end)
	end
	btn.MouseButton1Click:Connect(fireToggle)
	btn.Activated:Connect(fireToggle)
	-- mobile fallback: InputEnded short tap
	do
 local down, startP
 btn.InputBegan:Connect(function(input)
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 down = true
 startP = input.Position
 end
 end)
 btn.InputEnded:Connect(function(input)
 if not down then return end
 if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
 down = false
 if startP and (input.Position - startP).Magnitude < 12 then
 fireToggle()
 end
 end)
	end
	local function setVisualOnly(on)
 state = on and true or false
 TS:Create(track, TweenInfo.new(0.12), { BackgroundColor3 = state and C.on or C.off }):Play()
 TS:Create(knob, TweenInfo.new(0.12), {
 BackgroundColor3 = state and Color3.fromRGB(20, 20, 20) or Color3.new(1, 1, 1),
 Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
 }):Play()
 glow(state, 0.12)
	end
	return {
 set = apply,
 setVisual = setVisualOnly,
 get = function() return state end,
	}
end
-- Small top-center toast used by Save / Reset / TP messages.
function showToast(msg)
	pcall(function()
		local old = PlayerGui:FindFirstChild("MeridianToast")
		if old then old:Destroy() end
		local g = Instance.new("ScreenGui")
		g.Name = "MeridianToast"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 300000
		g.Parent = PlayerGui
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, 24)
		l.Size = UDim2.fromOffset(0, 28)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.BackgroundColor3 = Color3.fromRGB(9, 9, 15)
		l.BackgroundTransparency = 0.1
		l.Text = "  " .. tostring(msg) .. "  "
		l.TextColor3 = Color3.fromRGB(240, 240, 246)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 12
		l.Parent = g
		Instance.new("UICorner", l).CornerRadius = UDim.new(1, 0)
		local st = Instance.new("UIStroke", l)
		st.Color = Color3.fromRGB(48, 50, 64)
		st.Thickness = 1
		task.delay(1.6, function()
			pcall(function()
				TS:Create(l, TweenInfo.new(0.25), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			end)
			task.wait(0.3)
			pcall(function() g:Destroy() end)
		end)
	end)
end
function toggleNamed(parent, label, default, cb, order, refName)
	local api = toggle(parent, label, default, cb, order)
	if refName then ToggleRefs[refName] = api end
	return api
end
function numBox(parent, pos, w, val, cb)
	local b = Instance.new("TextBox")
	b.Size = UDim2.new(0, w, 0, 24)
	b.Position = pos
	b.BackgroundColor3 = C.box
	b.Text = tostring(val)
	b.TextColor3 = C.text
	b.TextSize = 12
	b.Font = Enum.Font.GothamBold
	b.ClearTextOnFocus = false
	b.Active = true
	b.ZIndex = 25
	b.Parent = parent
	corner(b, 6)
	b.FocusLost:Connect(function()
 local n = tonumber(b.Text)
 if n then
 n = math.clamp(n, 1, 200)
 b.Text = tostring(n)
 if cb then cb(n) end
 else
 b.Text = tostring(val)
 end
	end)
	return b
end
function keyName(k)
	return k and tostring(k):gsub("Enum.KeyCode.", "") or "?"
end
local listening = nil
function keyBtn(parent, key, onSet, pos)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 36, 0, 24)
	b.Position = pos or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = C.box
	b.Text = keyName(key)
	b.TextColor3 = C.text
	b.TextSize = 11
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = false
	b.Active = true
	b.ZIndex = 25
	b.Parent = parent
	corner(b, 6)
	b.MouseButton1Click:Connect(function()
 if listening then return end
 listening = b
 b.Text = "..."
 local conn
 conn = UIS.InputBegan:Connect(function(input, gp)
 if gp or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
 if input.KeyCode == Enum.KeyCode.Escape then
 b.Text = keyName(key)
 listening = nil
 conn:Disconnect()
 return
 end
 key = input.KeyCode
 b.Text = keyName(key)
 listening = nil
 conn:Disconnect()
 if onSet then onSet(key) end
 end)
	end)
	return b
end
function actionBtn(parent, text, color, cb, order)
	local r = row(parent, 36, order)
	r.BackgroundColor3 = color or C.accent
	r.BackgroundTransparency = 0 -- filled button stays solid
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 1, 0)
	b.BackgroundTransparency = 1
	b.Text = text
	b.TextColor3 = Color3.fromRGB(24, 24, 24)
	b.TextSize = 13
	b.Font = NAME_FONT
	b.Parent = r
	b.Active = true
	b.ZIndex = 20
	local _busy = false
	local function fire()
 if _busy then return end
 _busy = true
 if cb then pcall(cb) end
 task.delay(0.15, function() _busy = false end)
	end
	b.MouseButton1Click:Connect(fire)
	b.Activated:Connect(fire)
	return r
end

----------------------------------------------------------------
-- PLAYER TAB
----------------------------------------------------------------
section(pageCounter, "Anti", 20)
toggleNamed(pageCounter, "Anti Gummy Bear", St.antiGummy, setAntiGummy, 21, "antiGummy")
toggleNamed(pageCounter, "Anti Ragdoll", St.antiRagdoll, setAntiRagdoll, 22, "antiRagdoll")
do
	local r = row(pageCounter, 36, 22.5)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.4, 0, 1, 0)
	label.Font = NAME_FONT
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = C.textDim
	label.Text = " Mode"
	label.Parent = r
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0.55, 0, 0, 26)
	holder.Position = UDim2.new(0.42, 0, 0.5, -13)
	holder.BackgroundColor3 = C.box
	holder.BorderSizePixel = 0
	holder.Parent = r
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 8)
	hc.Parent = holder
	local slide = Instance.new("Frame")
	slide.Size = UDim2.new(0.5, -6, 1, -6)
	slide.Position = UDim2.new(0, 3, 0, 3)
	slide.BackgroundColor3 = C.accent
	slide.BorderSizePixel = 0
	slide.ZIndex = 2
	slide.Parent = holder
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 6)
	sc.Parent = slide
	gradFill(slide, 90, Color3.fromRGB(150, 150, 150))
	glowStroke(slide, 2).Transparency = 0.4
	local t1 = Instance.new("TextLabel")
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.new(0.5, 0, 1, 0)
	t1.Font = NAME_FONT
	t1.TextSize = 11
	t1.Text = "V1"
	t1.TextColor3 = C.text
	t1.ZIndex = 3
	t1.Parent = holder
	local t2 = Instance.new("TextLabel")
	t2.BackgroundTransparency = 1
	t2.Size = UDim2.new(0.5, 0, 1, 0)
	t2.Position = UDim2.new(0.5, 0, 0, 0)
	t2.Font = NAME_FONT
	t2.TextSize = 11
	t2.Text = "V2"
	t2.TextColor3 = C.text
	t2.ZIndex = 3
	t2.Parent = holder
	local function refresh()
 local isV2 = tostring(St.antiRagdollMode or "V1"):upper() == "V2"
 slide.Position = isV2 and UDim2.new(0.5, 2, 0, 3) or UDim2.new(0, 3, 0, 3)
 t1.TextColor3 = isV2 and C.text or Color3.fromRGB(20, 20, 20)
 t2.TextColor3 = isV2 and Color3.fromRGB(20, 20, 20) or C.text
 t1.TextTransparency = isV2 and 0.35 or 0
 t2.TextTransparency = isV2 and 0 or 0.35
	end
	_G.MeridianRefreshAntiRagMode = refresh
	local b1 = Instance.new("TextButton")
	b1.BackgroundTransparency = 1
	b1.Size = UDim2.new(0.5, 0, 1, 0)
	b1.Text = ""
	b1.ZIndex = 4
	b1.Parent = holder
	b1.MouseButton1Click:Connect(function() setAntiRagdollMode("V1"); refresh() end)
	local b2 = Instance.new("TextButton")
	b2.BackgroundTransparency = 1
	b2.Size = UDim2.new(0.5, 0, 1, 0)
	b2.Position = UDim2.new(0.5, 0, 0, 0)
	b2.Text = ""
	b2.ZIndex = 4
	b2.Parent = holder
	b2.MouseButton1Click:Connect(function() setAntiRagdollMode("V2"); refresh() end)
	refresh()
end
toggleNamed(pageCounter, "Anti Paintball Gun", St.antiPaint, setAntiPaint, 23, "antiPaint")
toggleNamed(pageCounter, "Anti Boogie Bomb", St.antiBoogie, setAntiBoogie, 24, "antiBoogie")
toggleNamed(pageCounter, "Anti Bee", St.antiBee, setAntiBee, 25, "antiBee")

section(pagePlayer, "Speed", -1)
toggleNamed(pagePlayer, "Manual Carry", St.manualCarry == true, function(on)
	if type(setManualCarry) == "function" then setManualCarry(on) else St.manualCarry = on and true or false end
end, -0.95, "manualCarry")

local modeCards = {}
function modeCard(name, desc, order)
	local m = St.modes[name]
	-- Compact speed editor: mode name centered at top, keybind on the left.
	local r = row(pagePlayer, 58, order)
	r.Size = UDim2.new(1, -18, 0, 58)
	modeCards[name] = r

	-- Speed mode name — centered at the top
	local nm = Instance.new("TextLabel")
	nm.Size = UDim2.new(1, -20, 0, 20)
	nm.Position = UDim2.new(0, 10, 0, 3)
	nm.BackgroundTransparency = 1
	nm.Text = name .. " Speed"
	nm.TextColor3 = C.text
	nm.TextSize = 13
	nm.Font = NAME_FONT
	nm.TextXAlignment = Enum.TextXAlignment.Center
	nm.Parent = r

	-- Keybind — clearly visible on the left
	local kb = Instance.new("TextLabel")
	kb.Size = UDim2.new(0, 47, 0, 12)
	kb.Position = UDim2.new(0, 10, 0, 31)
	kb.BackgroundTransparency = 1
	kb.Text = "keybind"
	kb.TextColor3 = C.textDim
	kb.TextSize = 8
	kb.Font = Enum.Font.Gotham
	kb.TextXAlignment = Enum.TextXAlignment.Left
	kb.Parent = r

	keyBtn(r, m.key, function(k)
		St.modes[name].key = k
		saveCfg()
	end, UDim2.new(0, 57, 0, 27))

	-- Norm / carry values on the right side
	local ln = Instance.new("TextLabel")
	ln.Size = UDim2.new(0, 40, 0, 10)
	ln.Position = UDim2.new(1, -96, 0, 30)
	ln.BackgroundTransparency = 1
	ln.Text = "norm"
	ln.TextColor3 = C.textDim
	ln.TextSize = 8
	ln.Font = Enum.Font.Gotham
	ln.TextXAlignment = Enum.TextXAlignment.Center
	ln.Parent = r

	local ls = Instance.new("TextLabel")
	ls.Size = UDim2.new(0, 40, 0, 10)
	ls.Position = UDim2.new(1, -48, 0, 30)
	ls.BackgroundTransparency = 1
	ls.Text = "carry"
	ls.TextColor3 = C.textDim
	ls.TextSize = 8
	ls.Font = Enum.Font.Gotham
	ls.TextXAlignment = Enum.TextXAlignment.Center
	ls.Parent = r

	numBox(r, UDim2.new(1, -96, 0, 27), 40, m.norm, function(v)
		St.modes[name].norm = math.clamp(tonumber(v) or 59, 1, 200)
		if St.activeMode == name then
			currentSpeedValue = getActiveMoveSpeed()
			if speedConnection then pcall(function() speedConnection:Disconnect() end); speedConnection = nil end
			pcall(startSpeedBoost)
		end
		saveCfg()
	end)

	numBox(r, UDim2.new(1, -48, 0, 27), 40, m.steal, function(v)
		St.modes[name].steal = math.clamp(tonumber(v) or 30, 1, 200)
		if St.activeMode == name then
			currentSpeedValue = getActiveMoveSpeed()
			if speedConnection then pcall(function() speedConnection:Disconnect() end); speedConnection = nil end
			pcall(startSpeedBoost)
		end
		saveCfg()
	end)

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.new(0.42, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Active = true
	hit.ZIndex = 15
	hit.Parent = r
	hit.MouseButton1Click:Connect(function() toggleMode(name) end)
	hit.Activated:Connect(function() toggleMode(name) end)
end
modeCard("Normal", "default mode", -0.9)
modeCard("Lagger", "use against lagger", -0.8)
modeCard("Custom", "custom spd", -0.7)
function _G.MeridianRefreshModeCards()
	for n, card in pairs(modeCards) do
		local on = St.activeMode == n
		local st = card:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = on and C.accent or C.stroke
			st.Transparency = on and 0.05 or 0.35
			st.Thickness = on and 2 or 1
		end
		gradFill(card, 90, Color3.fromRGB(110, 110, 110))
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.BackgroundTransparency = on and 0.88 or 1
	end
end
_G.MeridianRefreshModeCards()

-- ============================================================
-- Ragdoll TP Left/Right removed

section(pagePlayer, "Drop", 20)
toggleNamed(pagePlayer, "Tool Aimbot", St.toolAim, setToolAim, 21, "toolAim")
toggleNamed(pagePlayer, "Body Lock", St.bodyLock == true, function(on) if setBodyLock then setBodyLock(on) end end, 22, "bodyLock")
do
	local rr = row(pagePlayer, 36, 22)
	local rl = Instance.new("TextLabel")
	rl.Size = UDim2.new(0.55, 0, 1, 0)
	rl.BackgroundTransparency = 1
	rl.Text = "Body Lock Range"
	rl.TextColor3 = C.text
	rl.TextSize = 12
	rl.Font = NAME_FONT
	rl.TextXAlignment = Enum.TextXAlignment.Left
	rl.Parent = rr
	numBox(rr, UDim2.new(1, -70, 0.5, -12), 56, tonumber(St.bodyLockRange) or 20, function(v)
 setBodyLockRange(v)
	end)
end
-- Ragdoll TP Left/Right removed from menu

toggleNamed(pagePlayer, "Inf Jump", St.infJump, setInfJump, 215, "infJump")
toggleNamed(pagePlayer, "Auto Destroy Sentry", St.destroySentry, setDestroySentry, 216, "destroySentry")
-- drop mode
local dropRow = row(pagePlayer, 38, 22)
local dropLbl = Instance.new("TextLabel")
dropLbl.Size = UDim2.new(0.4, 0, 1, 0)
dropLbl.Position = UDim2.new(0, 12, 0, 0)
dropLbl.BackgroundTransparency = 1
dropLbl.Text = "Drop Mode"
dropLbl.TextColor3 = C.text
dropLbl.TextSize = 13
dropLbl.Font = NAME_FONT
dropLbl.TextXAlignment = Enum.TextXAlignment.Left
dropLbl.Parent = dropRow
for i, name in ipairs({ "Stand", "Jump" }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 60, 0, 26)
	b.Position = UDim2.new(1, -140 + (i - 1) * 66, 0.5, -13)
	b.BackgroundColor3 = ((St.dropMode == 1 and name == "Stand") or (St.dropMode == 2 and name == "Jump")) and C.accent or C.box
	b.Text = name
	b.TextColor3 = ((St.dropMode == 1 and name == "Stand") or (St.dropMode == 2 and name == "Jump")) and Color3.fromRGB(24, 24, 24) or C.text
	b.TextSize = 11
	b.Font = NAME_FONT
	b.AutoButtonColor = false
	b.Parent = dropRow
	corner(b, 7)
	b.Active = true
	b.ZIndex = 40
	paintChoice(b, (St.dropMode == 1 and name == "Stand") or (St.dropMode == 2 and name == "Jump"))
	function pickDrop()
 St.dropMode = (name == "Jump") and 2 or 1
 for _, ch in ipairs(dropRow:GetChildren()) do
 if ch:IsA("TextButton") then
 local on = (St.dropMode == 2 and ch.Text == "Jump") or (St.dropMode == 1 and ch.Text == "Stand")
 paintChoice(ch, on)
 end
 end
 pcall(saveCfg)
	end
	b.MouseButton1Click:Connect(pickDrop)
	b.Activated:Connect(pickDrop)
end
actionBtn(pagePlayer, "Drop Now", C.accent, runDrop, 23)

local instaRow = row(pagePlayer, 38, 24)
local instaLbl = Instance.new("TextLabel")
instaLbl.Size = UDim2.new(0.4, 0, 1, 0)
instaLbl.Position = UDim2.new(0, 12, 0, 0)
instaLbl.BackgroundTransparency = 1
instaLbl.Text = "Insta Reset"
instaLbl.TextColor3 = C.text
instaLbl.TextSize = 13
instaLbl.Font = NAME_FONT
instaLbl.TextXAlignment = Enum.TextXAlignment.Left
instaLbl.Parent = instaRow
for i, name in ipairs({ "V1", "V2" }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 48, 0, 26)
	b.Position = UDim2.new(1, -120 + (i - 1) * 54, 0.5, -13)
	b.BackgroundColor3 = (St.instaMode == name) and C.accent or C.box
	b.Text = name
	b.TextColor3 = (St.instaMode == name) and Color3.fromRGB(24, 24, 24) or C.text
	b.TextSize = 11
	b.Font = NAME_FONT
	b.AutoButtonColor = false
	b.Parent = instaRow
	corner(b, 7)
	b.Active = true
	b.ZIndex = 40
	paintChoice(b, St.instaMode == name)
	function pickInsta()
 St.instaMode = name
 for _, ch in ipairs(instaRow:GetChildren()) do
 if ch:IsA("TextButton") then
 local on = ch.Text == St.instaMode
 paintChoice(ch, on)
 end
 end
 pcall(saveCfg)
	end
	b.MouseButton1Click:Connect(pickInsta)
	b.Activated:Connect(pickInsta)
end
actionBtn(pagePlayer, "Insta Reset Now", C.danger, doInstaReset, 25)
actionBtn(pagePlayer, "TP Down", C.accent, function() doTPDown(true) end, 26)

section(pagePlayer, "Keybinds", 30)
function keyRow(label, keyId, order)
	local r = row(pagePlayer, 36, order)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -56, 1, 0)
	t.Position = UDim2.new(0, 12, 0, 0)
	t.BackgroundTransparency = 1
	t.Text = label
	t.TextColor3 = C.text
	t.TextSize = 13
	t.Font = NAME_FONT
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = r
	keyBtn(r, St.keys[keyId], function(k) St.keys[keyId] = k; saveCfg() end, UDim2.new(1, -48, 0.5, -12))
end
keyRow("Key Drop", "Drop", 31)
keyRow("Key TP Down", "TPDown", 32)
keyRow("Key Insta Reset", "InstaReset", 33)
keyRow("Key Destroy Sentry", "DestroySentry", 34)
keyRow("Key Auto Steal", "AutoSteal", 35)

-- Full KEYBINDS TAB
if pageKeys then
	section(pageKeys, "Keybinds", 1)
	local function keyRowTab(label, keyId, order)
 local r = row(pageKeys, 36, order)
 local t = Instance.new("TextLabel")
 t.Size = UDim2.new(1, -100, 1, 0)
 t.Position = UDim2.new(0, 12, 0, 0)
 t.BackgroundTransparency = 1
 t.Text = label
 t.TextColor3 = C.text
 t.TextSize = 13
 t.Font = NAME_FONT
 t.TextXAlignment = Enum.TextXAlignment.Left
 t.Parent = r
 local b = Instance.new("TextButton")
 b.Size = UDim2.new(0, 88, 0, 28)
 b.Position = UDim2.new(1, -96, 0.5, -14)
 b.BackgroundColor3 = C.box
 b.TextColor3 = C.text
 b.TextSize = 12
 b.Font = Enum.Font.GothamBold
 b.AutoButtonColor = false
 b.Parent = r
 corner(b, 7)
 local function refresh()
 local k = St.keys and St.keys[keyId]
 if not k or k == Enum.KeyCode.Unknown then
 b.Text = "None"
 else
 b.Text = tostring(k.Name or k)
 end
 end
 refresh()
 local listening = false
 local function startListen()
 if listening then return end
 listening = true
 b.Text = "..."
 b.BackgroundColor3 = C.accent
 b.TextColor3 = Color3.fromRGB(20, 20, 20)
 local conn
 conn = UIS.InputBegan:Connect(function(inp, gp)
 if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
 local code = inp.KeyCode
 if code == Enum.KeyCode.Escape then
 -- keep current
 listening = false
 b.BackgroundColor3 = C.box
 b.TextColor3 = C.text
 refresh()
 if conn then conn:Disconnect() end
 return
 end
 if code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete then
 St.keys[keyId] = nil
 else
 St.keys[keyId] = code
 end
 listening = false
 b.BackgroundColor3 = C.box
 b.TextColor3 = C.text
 refresh()
 pcall(saveCfg)
 if conn then conn:Disconnect() end
 end)
 end
 b.MouseButton1Click:Connect(startListen)
 b.Activated:Connect(startListen)
	end
	keyRowTab("Drop", "Drop", 2)
	keyRowTab("TP Down", "TPDown", 3)
	keyRowTab("Insta Reset", "InstaReset", 4)
	keyRowTab("Destroy Sentry", "DestroySentry", 5)
	keyRowTab("Auto Steal (toggle)", "AutoSteal", 6)
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -16, 0, 40)
	hint.BackgroundTransparency = 1
	hint.Text = "Press the button → press a key to bind\nBackspace/Delete = None | Esc = cancel"
	hint.TextColor3 = C.textDim
	hint.TextSize = 11
	hint.Font = Enum.Font.Gotham
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = pageKeys
	hint.LayoutOrder = 20
end

----------------------------------------------------------------
-- ESP TAB
----------------------------------------------------------------
section(pageESP, "ESP", 1)
toggleNamed(pageESP, "Player ESP", St.esp, setESP, 2, "esp")
toggleNamed(pageESP, "Tracker / Tracer", St.tracer, setTracer, 3, "tracer")
toggleNamed(pageCounter, "Anti Lag", St.antiLag, setAntiLag, 26, "antiLag")

----------------------------------------------------------------
-- SPAM TAB
----------------------------------------------------------------
section(pageSpam, "Auto Spam", 1)
toggleNamed(pageSpam, "Spam Laser Cape", St.spamLaser, setSpamLaser, 2, "spamLaser")
toggleNamed(pageSpam, "Spam Paintball Gun", St.spamPaint, setSpamPaint, 3, "spamPaint")

section(pageCounter, "Counter", 1)
toggleNamed(pageCounter, "Auto Laser Cape", St.counterLaser == true, setCounterLaser, 2, "counterLaser")
toggleNamed(pageCounter, "Auto Boogie Bomb", St.counterBoogie == true, setCounterBoogie, 3, "counterBoogie")
toggleNamed(pageCounter, "Auto Swap Body", St.counterSwapBody == true, setCounterSwapBody, 4, "counterSwapBody")
toggleNamed(pageCounter, "Equip & Activate on Drop", St.equipOnDrop == true, setEquipOnDrop, 5, "equipOnDrop")
do
	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(1, -20, 0, 48)
	info.BackgroundTransparency = 1
	info.Text = "Laser Cape / Boogie Bomb / Swap Body: held manually + Activate.\nOn Drop: after the DROP, the counter tool is equipped & activated."
	info.TextColor3 = C.textDim
	info.TextSize = 11
	info.Font = Enum.Font.Gotham
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Parent = pageCounter
	info.LayoutOrder = 7
end

local spamInfo = row(pageSpam, 62, 4)
local spamTxt = Instance.new("TextLabel")
spamTxt.Size = UDim2.new(1, -12, 1, 0)
spamTxt.Position = UDim2.new(0, 6, 0, 0)
spamTxt.BackgroundTransparency = 1
spamTxt.Text = "Only activates while HOLDING the tool.\nNo auto-equip. Use together with Tool Aimbot if needed."
spamTxt.TextColor3 = C.textDim
spamTxt.TextSize = 10
spamTxt.Font = Enum.Font.Gotham
spamTxt.TextXAlignment = Enum.TextXAlignment.Left
spamTxt.TextYAlignment = Enum.TextYAlignment.Center
spamTxt.TextWrapped = true
spamTxt.Parent = spamInfo

----------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------
section(pageSet, "Mobile", 1)
toggleNamed(pageSet, "Mobile Buttons", St.mobileBtns, function(on)
	St.mobileBtns = on
	if _G.MeridianApplyMobile then _G.MeridianApplyMobile() end
	saveCfg()
end, 2, "mobileBtns")
toggleNamed(pageSet, "Show Panel TP", St.showTPPanel ~= false, function(on)
	St.showTPPanel = on and true or false
	local g = PlayerGui:FindFirstChild("MeridianHubbTP")
	if g then g.Enabled = St.showTPPanel end
	saveCfg()
end, 25, "showTPPanel")
toggleNamed(pageSet, "Lock UI", St.guiLock, function(on)
	St.guiLock = on and true or false
	-- snapshot positions then save immediately on lock/unlock
	pcall(function()
 if Main and Main.Parent then
 St._mainPos = {Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset}
 St.menuOpen = Main.Visible == true
 end
 local miniGui = PlayerGui:FindFirstChild("MeridianHubFullMini")
 local mini = miniGui and miniGui:FindFirstChildWhichIsA("TextButton")
 if mini then
 St._miniPos = {mini.Position.X.Scale, mini.Position.X.Offset, mini.Position.Y.Scale, mini.Position.Y.Offset}
 end
 local mb = PlayerGui:FindFirstChild("MeridianHubModeBar")
 local mf = mb and mb:FindFirstChildWhichIsA("Frame")
 if mf then
 St._modeBarPos = {mf.Position.X.Scale, mf.Position.X.Offset, mf.Position.Y.Scale, mf.Position.Y.Offset}
 end
 St._btnPos = St._btnPos or {}
 local function snapHoldersLock(gui)
 if not gui then return end
 for _, holder in ipairs(gui:GetChildren()) do
 if holder:IsA("Frame") or holder:IsA("TextButton") then
 local key = holder.Name
 if key and (key:sub(1,2) == "A_" or key:sub(1,2) == "M_") then
 St._btnPos[key] = {
 holder.Position.X.Scale, holder.Position.X.Offset,
 holder.Position.Y.Scale, holder.Position.Y.Offset,
 holder.Size.X.Offset, holder.Size.Y.Offset,
 }
 end
 end
 end
 end
 snapHoldersLock(PlayerGui:FindFirstChild("MeridianHubActionButtons"))
 snapHoldersLock(PlayerGui:FindFirstChild("MeridianHubModeBar"))
	end)
	pcall(saveCfg)
end, 3, "guiLock")
section(pageSet, "Button Shape", 10)
local shapeRow = row(pageSet, 38, 11)
for i, name in ipairs({ "Round", "Box", "Square" }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 90, 0, 28)
	b.Position = UDim2.new(0, 12 + (i - 1) * 100, 0.5, -14)
	b.BackgroundColor3 = (St.btnShape == name) and C.accent or C.box
	b.Text = name
	b.TextColor3 = (St.btnShape == name) and Color3.fromRGB(24, 24, 24) or C.text
	b.TextSize = 12
	b.Font = NAME_FONT
	b.AutoButtonColor = false
	b.Parent = shapeRow
	corner(b, name == "Round" and 14 or (name == "Box" and 6 or 2))
	paintChoice(b, St.btnShape == name)
	local function pickShape()
 St.btnShape = name
 -- Apply the shape immediately to EVERY action button
 pcall(function()
 if actRefs then
 for key, e in pairs(actRefs) do
 if e and e.btn then
 applyCorner(e.btn, name)
 applyCornerToChildren(e.btn, name)
 end
 end
 end
 end)
 if _G.MeridianUpdateMobileVisuals then pcall(_G.MeridianUpdateMobileVisuals) end
 if _G.MeridianForceApplyShape then pcall(_G.MeridianForceApplyShape, name) end
 for _, ch in ipairs(shapeRow:GetChildren()) do
 if ch:IsA("TextButton") then
 local on = ch.Text == name
 paintChoice(ch, on)
 end
 end
 pcall(saveCfg)
	end
	b.MouseButton1Click:Connect(pickShape)
	b.Activated:Connect(pickShape)
	b.MouseButton1Down:Connect(pickShape)
end

section(pageSet, "Button Size", 20)
-- Shared +/- row: label (truncates, never overlaps) | fixed value box | [-] [+]
function stepperRow(parent, label, text, onStep, order)
	local r = row(parent, 36, order)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -118, 1, 0)
	t.Position = UDim2.new(0, 10, 0, 0)
	t.BackgroundTransparency = 1
	t.Text = label
	t.TextColor3 = C.text
	t.TextSize = 12
	t.Font = NAME_FONT
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Parent = r
	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(0, 38, 0, 24)
	val.Position = UDim2.new(1, -106, 0.5, -12)
	val.BackgroundTransparency = 1
	val.Text = text
	val.TextColor3 = C.accent
	val.TextSize = 12
	val.Font = Enum.Font.GothamBold
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.Parent = r
	local function mk(sign, x)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 26, 0, 26)
		btn.Position = UDim2.new(1, x, 0.5, -13)
		btn.BackgroundColor3 = C.box
		btn.Text = sign
		btn.TextColor3 = C.text
		btn.TextSize = 15
		btn.Font = Enum.Font.GothamBold
		btn.AutoButtonColor = false
		btn.Active = true
		btn.ZIndex = 30
		btn.Parent = r
		corner(btn, 7)
		local function fire()
			local shown = onStep(sign)
			if shown then val.Text = shown end
		end
		btn.MouseButton1Click:Connect(fire)
		btn.Activated:Connect(fire)
	end
	mk("-", -64)
	mk("+", -34)
	return val
end

stepperRow(pageSet, "All Buttons", tostring(math.floor(St.btnScale * 100)) .. "%", function(sign)
	St.btnScale = math.clamp((tonumber(St.btnScale) or 1) + (sign == "+" and 0.05 or -0.05), 0.3, 2.0)
	if _G.MeridianUpdateMobileVisuals then pcall(_G.MeridianUpdateMobileVisuals) end
	if _G.MeridianApplyMobile then pcall(_G.MeridianApplyMobile) end
	-- rebuild V2 bar to pick new scale defaults
	if _G.MeridianBuildV2ModeBar then pcall(_G.MeridianBuildV2ModeBar) end
	saveCfg()
	return tostring(math.floor(St.btnScale * 100)) .. "%"
end, 22)

section(pageSet, "Progress Bar Size", 26)
stepperRow(pageSet, "Progress Bar", tostring(math.floor((tonumber(St.stealBarScale) or 1) * 100)) .. "%", function(sign)
	St.stealBarScale = math.clamp((tonumber(St.stealBarScale) or 1) + (sign == "+" and 0.05 or -0.05), 0.5, 2.5)
	if _G.MeridianApplyStealBarScale then pcall(_G.MeridianApplyStealBarScale) end
	saveCfg()
	return tostring(math.floor(St.stealBarScale * 100)) .. "%"
end, 27)

section(pageSet, "Menu UI Scale", 28)
stepperRow(pageSet, "Menu Size", tostring(math.floor((St.menuScale or 1) * 100)) .. "%", function(sign)
	St.menuScale = math.clamp((St.menuScale or 1) + (sign == "+" and 0.05 or -0.05), 0.7, 1.3)
	applyMenuScale()
	saveCfg()
	return tostring(math.floor(St.menuScale * 100)) .. "%"
end, 29)

section(pageSet, "Reset", 30)
actionBtn(pageSet, "Reset Mobile Positions", C.accent, function()
	if _G.MeridianResetMobilePos then _G.MeridianResetMobilePos() end
	saveCfg()
end, 31)
actionBtn(pageSet, "Reset All Settings", C.danger, function()
	-- full defaults
	pcall(function() setAntiGummy(true) end)
	pcall(function() setAntiRagdoll(false) end)
	pcall(function() setAntiPaint(true) end)
	pcall(function() setAntiBoogie(true) end)
	pcall(function() setToolAim(true) end)
	pcall(function() setInfJump(true) end)
	pcall(function() setDestroySentry(false) end)
	pcall(function() setActiveMode("Normal") end)
	St.dropMode = 2
	St.instaMode = "V1"
	St.mobileBtns = true
	St.guiLock = false
	St.btnShape = "Box"
	St.btnScale = 1
	St.menuScale = 1
	St.btnSizes = { mode = 38, drop = 52.5, insta = 52.5, tp = 52.5, sentry = 52.5 }
	St._btnPos = nil
	St._modeBarPos = nil
	St._miniPos = nil
	St._mainPos = nil
	St._stealBarPos = nil
	St._sbPos = nil
	St.stealBarScale = 1
	St._tpMainPos = nil
	St.stealRadius = 60
	St.autoSteal = false
	St.manualCarry = false
	_G.MeridianCarryActive = false
	St.antiBee = false
	pcall(function() setAntiBee(false) end)
	St.modes = {
 Normal = { norm = 59, steal = 30, key = Enum.KeyCode.T },
 Lagger = { norm = 18, steal = 24, key = Enum.KeyCode.Q },
 Custom = { norm = 33, steal = 33, key = Enum.KeyCode.C },
	}
	St.activeMode = "Normal"
	St.keys = {
 Drop = Enum.KeyCode.X,
 TPDown = Enum.KeyCode.F,
 InstaReset = Enum.KeyCode.Z,
 DestroySentry = Enum.KeyCode.H,
	}
	pcall(function() setESP(false) end)
	pcall(function() setTracer(false) end)
	pcall(function() setAntiLag(false) end)
	pcall(function() setSpamLaser(false) end)
	pcall(function() setSpamPaint(false) end)
	if type(setAutoSteal) == "function" then
 pcall(function() setAutoSteal(false) end)
	end
	-- sync toggle UI
	local defs = {
 antiGummy = true, antiRagdoll = false, antiPaint = true, antiBoogie = true, antiBee = false,
 toolAim = true, infJump = true, destroySentry = false,
 mobileBtns = true, guiLock = false,
 esp = false, tracer = false, antiLag = false,
 spamLaser = false, spamPaint = false,
 autoSteal = false, showTPPanel = true, manualCarry = false,
	}
	for k, v in pairs(defs) do
 if ToggleRefs[k] and ToggleRefs[k].set then
 pcall(function() ToggleRefs[k].set(v) end)
 end
	end
	if _G.MeridianResetMobilePos then pcall(_G.MeridianResetMobilePos) end
	if _G.MeridianApplyMobile then pcall(_G.MeridianApplyMobile) end
	if _G.MeridianRefreshModeCards then pcall(_G.MeridianRefreshModeCards) end
	pcall(applyMenuScale)
	if _G.MeridianSyncAutoSteal then pcall(_G.MeridianSyncAutoSteal) end
	pcall(saveCfg)
	showToast("RESET ALL ✓")
end, 32)
actionBtn(pageSet, "Save Now", C.accent, function()
	-- snapshot menu / mini / bar positions before writing
	pcall(function()
 if Main then
 St._mainPos = {Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset}
 end
 local mini = PlayerGui:FindFirstChild("MeridianHubFullMini")
 local mb = mini and mini:FindFirstChildWhichIsA("GuiObject")
 if mb then
 St._miniPos = {mb.Position.X.Scale, mb.Position.X.Offset, mb.Position.Y.Scale, mb.Position.Y.Offset}
 end
 St.menuOpen = Main and Main.Visible == true
	end)
	local ok = saveCfg()
	if ok then
 showToast("SAVED ✓")
	else
 showToast("SAVE FAIL (no writefile?)")
	end
end, 33)

----------------------------------------------------------------
-- MINI + CLOSE (no keybind)
----------------------------------------------------------------
-- Remove an older opener instance so duplicate/ghost MERIDIAN text cannot remain
local oldMiniGui = PlayerGui:FindFirstChild("MeridianHubFullMini")
if oldMiniGui then
	pcall(function() oldMiniGui:Destroy() end)
end

local MiniGui = Instance.new("ScreenGui")
MiniGui.Name = "MeridianHubFullMini"
MiniGui.ResetOnSpawn = false
MiniGui.IgnoreGuiInset = true
MiniGui.DisplayOrder = 121
MiniGui.Parent = PlayerGui
-- Round helper when the menu is hidden (LKZ style) — draggable, press to open the menu
-- Opener style 04 — ICON BAR: frosted capsule + dot indicator, transparent, modern
local Mini = Instance.new("TextButton")
Mini.Name = "Mini"
Mini.Size = UDim2.fromOffset(96, 38)
Mini.Position = UDim2.new(0, 14, 0, 90)
Mini.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
Mini.BackgroundTransparency = 0
Mini.BorderSizePixel = 0
Mini.Text = ""
Mini.AutoButtonColor = false
Mini.Visible = false
Mini.Active = true
Mini.ZIndex = 10
Mini.Parent = MiniGui

local miniCorner = Instance.new("UICorner")
miniCorner.CornerRadius = UDim.new(1, 0)
miniCorner.Parent = Mini

local miniStroke = Instance.new("UIStroke")
miniStroke.Color = Color3.fromRGB(255, 255, 255)
miniStroke.Thickness = 1.2
miniStroke.Transparency = 0.55
miniStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
miniStroke.Parent = Mini

local miniDot = Instance.new("Frame")
miniDot.Name = "Circle"
miniDot.Size = UDim2.fromOffset(8, 8)
miniDot.Position = UDim2.new(0, 14, 0.5, -4)
miniDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
miniDot.BorderSizePixel = 0
miniDot.ZIndex = 12
miniDot.Parent = Mini

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = miniDot

local miniLabel = Instance.new("TextLabel")
miniLabel.Name = "Name"
miniLabel.BackgroundTransparency = 1
miniLabel.Position = UDim2.new(0, 28, 0, 0)
miniLabel.Size = UDim2.new(1, -38, 1, 0)
miniLabel.Text = "MERIDIAN"
miniLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
miniLabel.TextSize = 11
miniLabel.Font = Enum.Font.GothamBold
miniLabel.TextXAlignment = Enum.TextXAlignment.Left
miniLabel.TextYAlignment = Enum.TextYAlignment.Center
miniLabel.ZIndex = 12
miniLabel.Parent = Mini

local miniNormalSize = Mini.Size
Mini.MouseEnter:Connect(function()
 TS:Create(Mini, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(18, 18, 18)}):Play()
 TS:Create(miniStroke, TweenInfo.new(0.12), {Transparency = 0.2}):Play()
end)
Mini.MouseLeave:Connect(function()
 TS:Create(Mini, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(5, 5, 5)}):Play()
 TS:Create(miniStroke, TweenInfo.new(0.12), {Transparency = 0.55}):Play()
end)
Mini.MouseButton1Down:Connect(function()
 TS:Create(Mini, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(102, 36)}):Play()
end)
Mini.MouseButton1Up:Connect(function()
 TS:Create(Mini, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = miniNormalSize}):Play()
end)


do
	local dragging, dragStart, startPos, moved
	Top.InputBegan:Connect(function(input)
 if St.guiLock then return end
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 dragging = true
 dragStart = input.Position
 startPos = Main.Position
 input.Changed:Connect(function()
 if input.UserInputState == Enum.UserInputState.End then
 dragging = false
 St._mainPos = {Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset}
 St.menuOpen = Main.Visible == true
 pcall(saveCfg)
 end
 end)
 end
	end)
	UIS.InputChanged:Connect(function(input)
 if dragging and not St.guiLock and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
 local d = input.Position - dragStart
 Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
 end
	end)
end
do
	local dragging, dragStart, startPos, moved
	-- Load the saved open/close button position
	pcall(function()
 local p = St._miniPos
 if type(p) == "table" and p[1] ~= nil then
 Mini.Position = UDim2.new(p[1], p[2], p[3], p[4])
 end
	end)
	Mini.InputBegan:Connect(function(input)
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 dragging = true
 moved = false
 dragStart = input.Position
 startPos = Mini.Position
 end
	end)
	UIS.InputChanged:Connect(function(input)
 if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
 local d = input.Position - dragStart
 if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then moved = true end
 if moved then
 Mini.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
 end
 end
	end)
	UIS.InputEnded:Connect(function(input)
 if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
 if not dragging then return end
 dragging = false
 if moved then
 St._miniPos = {Mini.Position.X.Scale, Mini.Position.X.Offset, Mini.Position.Y.Scale, Mini.Position.Y.Offset}
 pcall(saveCfg)
 end
	end)
	Mini.MouseButton1Click:Connect(function()
 if moved then return end -- just finished dragging, do not open the menu
 St.menuOpen = true
 saveCfg()
 if moved then return end
 openMenu()
	end)
end

function openMenu()
	Main.Visible = true
	Mini.Visible = false
	St.menuOpen = true
	pcall(saveCfg)
	Main.Size = UDim2.new(0, 0, 0, MH)
	TS:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
 Size = UDim2.new(0, MW, 0, MH),
	}):Play()
end
function closeMenu()
	local tw = TS:Create(Main, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
 Size = UDim2.new(0, 0, 0, MH),
	})
	tw:Play()
	tw.Completed:Connect(function()
 Main.Visible = false
 St.menuOpen = false
 pcall(function()
 if Main and Main.Parent then
 St._mainPos = {Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset}
 end
 end)
 Mini.Visible = true
 local miniLabel = Mini:FindFirstChild("Name")
 if miniLabel then
  miniLabel.Text = "MERIDIAN"
 end
 -- Keep the saved mini position; if there is none, place it near the menu
 pcall(function()
 local p = St._miniPos
 if type(p) == "table" and p[1] ~= nil then
 Mini.Position = UDim2.new(p[1], p[2], p[3], p[4])
 else
 Mini.Position = UDim2.new(Main.Position.X.Scale, Main.Position.X.Offset + 8, Main.Position.Y.Scale, Main.Position.Y.Offset)
 St._miniPos = {Mini.Position.X.Scale, Mini.Position.X.Offset, Mini.Position.Y.Scale, Mini.Position.Y.Offset}
 end
 end)
 pcall(saveCfg)
	end)
end
CloseBtn.Active = true
CloseBtn.ZIndex = 50
CloseBtn.MouseButton1Click:Connect(closeMenu)
CloseBtn.Activated:Connect(closeMenu)

do
	local GuiLockBtn = Instance.new("TextButton")
	GuiLockBtn.Name = "GuiLockBtn"
	GuiLockBtn.Size = UDim2.new(0, 22, 0, 22)
	GuiLockBtn.Position = UDim2.new(1, -54, 0, 4)
	GuiLockBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	GuiLockBtn.TextSize = 11
	GuiLockBtn.Font = Enum.Font.GothamBold
	GuiLockBtn.AutoButtonColor = false
	GuiLockBtn.Active = true
	GuiLockBtn.ZIndex = 50
	GuiLockBtn.Parent = Top
	corner(GuiLockBtn, 6)
	local shown
	local function refresh()
		local on = St.guiLock and true or false
		if shown == on then return end
		shown = on
		GuiLockBtn.Text = on and "🔒" or "🔓"
		GuiLockBtn.TextColor3 = on and Color3.fromRGB(255, 200, 80) or C.textDim
	end
	refresh()
	local function flip()
		local want = not St.guiLock
		local ref = ToggleRefs and ToggleRefs.guiLock
		if ref and ref.set then
			pcall(ref.set, want)
		else
			St.guiLock = want
			pcall(saveCfg)
		end
		refresh()
	end
	local last = 0
	GuiLockBtn.Activated:Connect(function()
		if os.clock() - last < 0.15 then return end
		last = os.clock()
		flip()
	end)
	game:GetService("RunService").Heartbeat:Connect(refresh)
end
if Helper then
	Helper.MouseButton1Click:Connect(closeMenu)
	pcall(function() Helper.Activated:Connect(closeMenu) end)
end

----------------------------------------------------------------
-- MOBILE: 3 mode + Drop + Insta + TP
----------------------------------------------------------------
local ModeGui = Instance.new("ScreenGui")
ModeGui.Name = "MeridianHubModeBar"
ModeGui.ResetOnSpawn = false
ModeGui.IgnoreGuiInset = true
ModeGui.DisplayOrder = 2501
ModeGui.Enabled = false
ModeGui.Parent = PlayerGui

local ActGui = Instance.new("ScreenGui")
ActGui.Name = "MeridianHubActionButtons"
ActGui.ResetOnSpawn = false
ActGui.IgnoreGuiInset = true
ActGui.DisplayOrder = 2500
ActGui.Enabled = false
ActGui.Parent = PlayerGui

local modeRefs = {}
actRefs = {}

-- Shape only applies to ACTION buttons (Drop/Insta/TP/Sentry/Steal).
-- 3-mode speed (Normal/Lagger/Custom) ALWAYS keeps the default style (Pill) as in the video.
function applyCorner(btn, forceShape)
	if not btn then return end
	local shape = forceShape or St.btnShape or "Box"
	-- Remove all old UICorners, then recreate them (avoids a stuck old radius)
	for _, ch in ipairs(btn:GetChildren()) do
 if ch:IsA("UICorner") then pcall(function() ch:Destroy() end) end
	end
	local rad
	if shape == "Round" then
 rad = UDim.new(1, 0) -- round
	elseif shape == "Box" then
 rad = UDim.new(0, 12) -- medium rounding
	elseif shape == "Pill" then
 rad = UDim.new(0, 16)
	else
 rad = UDim.new(0, 2) -- Square: nearly square
	end
	local c = Instance.new("UICorner")
	c.Name = "ShapeCorner"
	c.CornerRadius = rad
	c.Parent = btn
	-- sync background image / dim
	for _, ch in ipairs(btn:GetChildren()) do
 if ch:IsA("ImageLabel") or (ch:IsA("Frame") and ch.Name ~= "BtnTextOverlay") then
 for _, sub in ipairs(ch:GetChildren()) do
 if sub:IsA("UICorner") then pcall(function() sub:Destroy() end) end
 end
 local c2 = Instance.new("UICorner")
 c2.Name = "ShapeCorner"
 c2.CornerRadius = rad
 c2.Parent = ch
 end
	end
end

function applyCornerToChildren(btn, shape)
	if not btn then return end
	shape = shape or St.btnShape or "Box"
	local rad
	if shape == "Round" then rad = UDim.new(1, 0)
	elseif shape == "Box" then rad = UDim.new(0, 12)
	elseif shape == "Pill" then rad = UDim.new(0, 16)
	else rad = UDim.new(0, 2)
	end
	for _, ch in ipairs(btn:GetChildren()) do
 if ch:IsA("ImageLabel") or (ch:IsA("Frame") and ch.Name ~= "BtnTextOverlay") then
 for _, sub in ipairs(ch:GetChildren()) do
 if sub:IsA("UICorner") then pcall(function() sub:Destroy() end) end
 end
 local c = Instance.new("UICorner")
 c.Name = "ShapeCorner"
 c.CornerRadius = rad
 c.Parent = ch
 end
	end
end

-- Floating action buttons: black & white "Carbon ring" style.
-- OFF = carbon black with a silver ring, ON = white/silver with black text.
function carbonBtnStyle(btn, on)
	if not btn then return end
	on = on == true
	pcall(function()
		local img = btn:FindFirstChild("BtnBgImage")
		if img then img:Destroy() end
		local dim = btn:FindFirstChild("BtnDim")
		if dim then dim:Destroy() end
		btn.BackgroundTransparency = 0
		btn.BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(16, 16, 16)
		local g = btn:FindFirstChild("CarbonGrad")
		if g then g:Destroy() end
		local gx = btn:FindFirstChildOfClass("UIGradient")
		if gx then gx:Destroy() end
		local ink = on and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		btn.TextColor3 = ink
		local tl = btn:FindFirstChild("BtnTextOverlay")
		if tl then
			tl.TextColor3 = ink
			tl.TextStrokeTransparency = 1
		end
		local st = btn:FindFirstChildOfClass("UIStroke")
		if st then st:Destroy() end
	end)
end

function applyEmpireBtnBg(btn, index)
	if not btn then return end
	btn.TextTransparency = 0
	btn.TextStrokeTransparency = 1
	pcall(function() btn.ZIndex = math.max(btn.ZIndex or 1, 100) end)
	carbonBtnStyle(btn, false)
end

----------------------------------------------------------------
-- SPEED V2 MODE BAR (full GUI from MERIDIAN Clean) — 3 mode
----------------------------------------------------------------
local v2BarButtons = {}
function _G.MeridianBuildV2ModeBar()
	pcall(function()
 local old = PlayerGui:FindFirstChild("MeridianV2ModeBar")
 if old then old:Destroy() end
	end)
	if not St.mobileBtns then return end
 local sc = math.clamp(tonumber(St.btnScale) or 1, 0.3, 2)
	local modeBase = tonumber(St.btnSizes and St.btnSizes.mode) or 38
	-- Size: Speed 3Mode increases HEIGHT, width stays just enough for the text
	local V2_BTN_H = math.max(28, math.floor(modeBase * sc))
	local V2_BTN_W = math.max(72, math.floor(88 * sc)) -- stable width, does not bloat with size
	local V2_CORNER = 12	local MODE_COLORS = {
 Normal = {
 onBg = Color3.fromRGB(255, 255, 255), onTxt = Color3.fromRGB(20, 20, 20),
 offBg = Color3.fromRGB(38, 38, 38), offTxt = Color3.fromRGB(255, 255, 255),
 stroke = Color3.fromRGB(255, 255, 255),
 },
 Lagger = {
 onBg = Color3.fromRGB(255, 255, 255), onTxt = Color3.fromRGB(20, 20, 20),
 offBg = Color3.fromRGB(38, 38, 38), offTxt = Color3.fromRGB(255, 255, 255),
 stroke = Color3.fromRGB(255, 255, 255),
 },
 Custom = {
 onBg = Color3.fromRGB(255, 255, 255), onTxt = Color3.fromRGB(20, 20, 20),
 offBg = Color3.fromRGB(38, 38, 38), offTxt = Color3.fromRGB(255, 255, 255),
 stroke = Color3.fromRGB(255, 255, 255),
 },
	}
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeridianV2ModeBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 95
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = PlayerGui
	v2BarButtons = {}
	local function styleV2Btn(btn, modeName, active)
 local col = MODE_COLORS[modeName] or MODE_COLORS.Normal
 btn.BackgroundColor3 = active and col.onBg or col.offBg
 btn.TextColor3 = active and col.onTxt or col.offTxt
 local st = btn:FindFirstChildOfClass("UIStroke")
 if st then
 st.Color = active and col.stroke or Color3.fromRGB(211, 211, 211)
 st.Transparency = active and 0.15 or 0.35
 st.Thickness = active and 1.5 or 1
 end
	end
	local function posFromSaved(modeName, order)
 local key = "V2_" .. modeName
 local t = St._btnPos and St._btnPos[key]
 if type(t) == "table" and t[1] ~= nil then
 return UDim2.new(t[1], t[2], t[3], t[4])
 end
 local gap = 10
 local total = (V2_BTN_W + gap) * 3 - gap
 return UDim2.new(0.5, -total / 2 + (order - 1) * (V2_BTN_W + gap), 1, -118)
	end
	local function saveV2Pos(modeName, holder)
 St._btnPos = St._btnPos or {}
 St._btnPos["V2_" .. modeName] = {
 holder.Position.X.Scale, holder.Position.X.Offset,
 holder.Position.Y.Scale, holder.Position.Y.Offset,
 }
 pcall(saveCfg)
	end
	local function makeV2ModeBtn(modeName, label, order)
 local holder = Instance.new("Frame")
 holder.Name = "V2MH_" .. modeName
 holder.Size = UDim2.new(0, V2_BTN_W, 0, V2_BTN_H)
 holder.Position = posFromSaved(modeName, order)
 holder.BackgroundTransparency = 1
 holder.BorderSizePixel = 0
 holder.ZIndex = 10
 holder.Active = true
 holder.Parent = gui
 local btn = Instance.new("TextButton")
 btn.Name = "V2Bar_" .. modeName
 btn.Size = UDim2.new(1, 0, 1, 0)
 btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
 btn.Text = label
 btn.TextColor3 = Color3.fromRGB(26, 26, 26)
 btn.Font = NAME_FONT
 btn.TextSize = 13
 btn.AutoButtonColor = false
 btn.ZIndex = 12
 btn.Parent = holder
 Instance.new("UICorner", btn).CornerRadius = UDim.new(0, V2_CORNER)
 local st = Instance.new("UIStroke", btn)
 st.Thickness = 1
 st.Transparency = 0.35
 st.Color = Color3.fromRGB(211, 211, 211)
 st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 styleV2Btn(btn, modeName, St.activeMode == modeName)
 local activeInput, pressPos, holderStart = nil, nil, nil
 local moved, lastClick = false, 0
 local function runClick()
 local now = tick()
 if now - lastClick < 0.08 then return end
 lastClick = now
 if type(setActiveMode) == "function" then
 toggleMode(modeName)
 else
 St.activeMode = modeName
 end
 for n, e in pairs(v2BarButtons) do
 if e and e.btn then styleV2Btn(e.btn, n, St.activeMode == n) end
 end
 -- sync old modeRefs if any
 for n, e in pairs(modeRefs or {}) do
 if e and e.style then pcall(e.style, St.activeMode == n)
 elseif e and e.btn then
 e.btn.BackgroundColor3 = (St.activeMode == n) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 38, 38)
 e.btn.TextColor3 = (St.activeMode == n) and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(255, 255, 255)
 end
 end
 end
 btn.InputBegan:Connect(function(input)
 if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
 activeInput = input
 pressPos = input.Position
 holderStart = holder.Position
 moved = false
 input.Changed:Connect(function()
 if input.UserInputState ~= Enum.UserInputState.End or activeInput ~= input then return end
 activeInput = nil
 if not moved then
 runClick()
 elseif not St.guiLock then
 saveV2Pos(modeName, holder)
 end
 end)
 end)
 btn.Activated:Connect(function()
 if moved then return end
 runClick()
 end)
 UIS.InputChanged:Connect(function(input)
 if not activeInput or not pressPos or not holderStart then return end
 if activeInput.UserInputType == Enum.UserInputType.Touch then
 if input ~= activeInput then return end
 elseif activeInput.UserInputType == Enum.UserInputType.MouseButton1 then
 if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
 else return end
 local dx = input.Position.X - pressPos.X
 local dy = input.Position.Y - pressPos.Y
 if math.abs(dx) > 4 or math.abs(dy) > 4 then moved = true end
 if moved and not St.guiLock then
 holder.Position = UDim2.new(holderStart.X.Scale, holderStart.X.Offset + dx, holderStart.Y.Scale, holderStart.Y.Offset + dy)
 end
 end)
 v2BarButtons[modeName] = { holder = holder, btn = btn }
 return btn
	end
	makeV2ModeBtn("Normal", "NORMAL", 1)
	makeV2ModeBtn("Lagger", "LAGGER", 2)
	makeV2ModeBtn("Custom", "CUSTOM", 3)
	_G.MeridianRefreshV2ModeBar = function()
 for n, e in pairs(v2BarButtons) do
 if e and e.btn then styleV2Btn(e.btn, n, St.activeMode == n) end
 end
	end
end

function makeModeBtn(name, order)
	-- Speed 3Mode size: increases height; width stays stable
	local sc = tonumber(St.btnScale) or 1
	local modeBase = tonumber(St.btnSizes and St.btnSizes.mode) or 38
	local V2_CORNER = 12
	local h = math.max(28, math.floor(modeBase * sc))
	local w = math.max(72, math.floor(88 * sc))
	local holder = Instance.new("Frame")
	holder.Name = "M_" .. name
	holder.Size = UDim2.new(0, w, 0, h)
	local gap = 10
	local total = (w + gap) * 3 - gap
	holder.Position = UDim2.new(0.5, -total / 2 + (order - 1) * (w + gap), 1, -118)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ZIndex = 10
	holder.Active = true
	holder.Parent = ModeGui
	-- restore saved pos
	pcall(function()
 local p = St._btnPos and St._btnPos["M_" .. name]
 if type(p) == "table" and p[1] ~= nil then
 holder.Position = UDim2.new(p[1], p[2], p[3], p[4])
 end
	end)
	local btn = Instance.new("TextButton")
	btn.Name = "ModeBtn"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = name:upper()
	if name == "Normal" then btn.Text = "NORMAL" end
	btn.TextColor3 = Color3.fromRGB(26, 26, 26)
	btn.Font = NAME_FONT
	btn.TextSize = math.clamp(math.floor(h * 0.36), 11, 14)
	btn.AutoButtonColor = false
	btn.ZIndex = 12
	btn.Active = true
	btn.Parent = holder
	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, V2_CORNER)
	local st = Instance.new("UIStroke", btn)
	st.Thickness = 1
	st.Transparency = 0.35
	st.Color = Color3.fromRGB(211, 211, 211)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local function styleMode(on)
 if on then
 btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
 btn.TextColor3 = Color3.fromRGB(20, 20, 20)
 st.Color = Color3.fromRGB(255, 255, 255)
 st.Transparency = 0.1
 else
 btn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
 btn.TextColor3 = Color3.fromRGB(255, 255, 255)
 st.Color = Color3.fromRGB(211, 211, 211)
 st.Transparency = 0.35
 end
	end
	styleMode(St.activeMode == name)
	local dragging, dragStart, startPos, moved = false, nil, nil, false
	local movedDistance = 0
	local TAP_MAX = 22
	btn.InputBegan:Connect(function(input)
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 dragging = true
 moved = false
 movedDistance = 0
 dragStart = input.Position
 startPos = holder.Position
 end
	end)
	btn.InputChanged:Connect(function(input)
 if not dragging or not dragStart then return end
 if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
 local d = input.Position - dragStart
 movedDistance = d.Magnitude
 if movedDistance > 8 then moved = true end
 if not St.guiLock and moved then
 holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
 end
 end
	end)
	local function pick()
 toggleMode(name)
 -- refresh all mode styles
 for n, e in pairs(modeRefs) do
 if e and e.btn and e.style then
 e.style(St.activeMode == n)
 elseif e and e.btn then
 local on = St.activeMode == n
 e.btn.BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(38, 38, 38)
 e.btn.TextColor3 = on and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(255, 255, 255)
 end
 end
 styleMode(St.activeMode == name)
	end
	btn.InputEnded:Connect(function(input)
 if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
 if not dragging then return end
 dragging = false
 if not moved and movedDistance < TAP_MAX then
 pick()
 elseif moved and not St.guiLock then
 savePos(holder, "M_" .. name)
 end
 movedDistance = 0
 dragStart = nil
	end)
	btn.MouseButton1Click:Connect(function()
 if moved then return end
 pick()
	end)
	btn.Activated:Connect(function()
 if moved then return end
 pick()
	end)
	modeRefs[name] = { holder = holder, btn = btn, style = styleMode }
end

function makeActBtn(key, label, pos, cb)
	-- Mobile button: easy to tap — steal/sentry/drop/insta/tp all have the same sensitivity
	local baseSz = tonumber(St.btnSizes and St.btnSizes.mode) or 38
	local sz = math.max(28, math.floor(baseSz * (St.btnScale or 1)))
	local holder = Instance.new("Frame")
	holder.Name = "A_" .. key
	holder.Size = UDim2.new(0, sz, 0, sz)
	holder.Position = pos
	holder.BackgroundTransparency = 1
	holder.Active = true -- receive touch
	holder.ZIndex = 50
	holder.Parent = ActGui
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	btn.Text = label
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = math.clamp(math.floor(sz * 0.22), 10, 16)
	btn.Font = NAME_FONT
	btn.TextWrapped = true
	btn.AutoButtonColor = false
	btn.Active = true
	btn.Selectable = true
	btn.Modal = false
	btn.ZIndex = 100
	btn.Parent = holder
	-- Action buttons: shape from Settings (Round/Box/Square)
	applyCorner(btn, St.btnShape)
	applyEmpireBtnBg(btn, ({drop=1,insta=2,tp=3,sentry=4,steal=5})[key] or 5)
	applyCornerToChildren(btn, St.btnShape)
	-- Text always visible: label drawn on top of the button
	btn.TextTransparency = 0
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	local oldL = btn:FindFirstChild("BtnTextOverlay")
	if oldL then oldL:Destroy() end
	local tl = Instance.new("TextLabel")
	tl.Name = "BtnTextOverlay"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, -4, 1, -4)
	tl.Position = UDim2.new(0, 2, 0, 2)
	tl.Text = label
	tl.TextColor3 = Color3.fromRGB(255, 255, 255)
	tl.TextStrokeTransparency = 0.35
	tl.TextStrokeColor3 = Color3.new(0, 0, 0)
	tl.Font = NAME_FONT
	tl.TextScaled = true
	tl.TextWrapped = true
	tl.ZIndex = (btn.ZIndex or 100) + 5
	tl.Active = false
	tl.Parent = btn
	-- hide the original text to avoid doubling (keep the overlay)
	btn.TextTransparency = 1
	local dragging, dragStart, startPos = false, nil, nil
	local movedDistance = 0
	local TAP_MAX = 22 -- easier to tap / easier to drag
	local dragThresh = 8 -- sensitive drag, not heavy
	btn.InputBegan:Connect(function(input)
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 dragging = true
 movedDistance = 0
 dragStart = input.Position
 startPos = holder.Position
 end
	end)
	-- global UIS = smoother than InputChanged on the button
	UIS.InputChanged:Connect(function(input)
 if not dragging or not dragStart then return end
 if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
 local d = input.Position - dragStart
 movedDistance = d.Magnitude
 if St.guiLock then return end
 if movedDistance > dragThresh then
 holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
 end
	end)
	btn.InputEnded:Connect(function(input)
 if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
 if not dragging then return end
 dragging = false
 local tapLimit = TAP_MAX
 -- steal/sentry/drop/insta/tp: easier to tap
 if key == "sentry" or key == "drop" or key == "insta" or key == "tp" or key == "carry" then
 tapLimit = 48
 end
 if movedDistance < tapLimit then
 if cb then
 btn:SetAttribute("_lastTap", tick())
 pcall(cb)
 if key == "sentry" and _G.MeridianRefreshSentryBtn then
 pcall(_G.MeridianRefreshSentryBtn)
 end
 end
 else
 if key == "carry" then btn:SetAttribute("_carryT", tick()) end
 if not St.guiLock then
 savePos(holder, "A_" .. key)
 end
 end
 movedDistance = 0
 dragStart = nil
	end)
	local function backupClick()
 local last = btn:GetAttribute("_lastTap") or 0
 if tick() - last < 0.15 then return end
 btn:SetAttribute("_lastTap", tick())
 if cb then pcall(cb) end
 if key == "sentry" and _G.MeridianRefreshSentryBtn then pcall(_G.MeridianRefreshSentryBtn) end
	end
	btn.MouseButton1Click:Connect(backupClick)
	btn.Activated:Connect(backupClick)
	-- overlay does not block clicks
	local ov = btn:FindFirstChild("BtnTextOverlay")
	if ov then ov.Active = false; ov.Selectable = false end

	-- SENTRY: instant feedback + white ON color
	if key == "sentry" then
 local function instantToggle()
 local last = btn:GetAttribute("_lastTap") or 0
 if tick() - last < 0.12 then return end
 btn:SetAttribute("_lastTap", tick())
 local on = not (St.destroySentry == true)
 if type(setDestroySentry) == "function" then pcall(setDestroySentry, on)
 else St.destroySentry = on end
 applyActBtnState(btn, St.destroySentry == true, "SENTRY", "SENTRY")
 if _G.MeridianRefreshSentryBtn then pcall(_G.MeridianRefreshSentryBtn) end
 end
 btn.MouseButton1Down:Connect(instantToggle)
 btn.TouchTap:Connect(function() end) -- ensure touch focus
 -- replace cb so InputEnded also uses this logic
 cb = instantToggle
	end

	-- CARRY: tap path and click path can both fire for one press; toggle only once
	if key == "carry" then
		cb = function()
			if movedDistance >= 48 then return end
			local now = tick()
			if now - (btn:GetAttribute("_carryT") or 0) < 0.25 then return end
			btn:SetAttribute("_carryT", now)
			if type(toggleCarry) == "function" then pcall(toggleCarry) end
		end
	end

	actRefs[key] = { holder = holder, btn = btn }
end

function restorePos(holder, key, defaultPos)
	local t = St._btnPos and St._btnPos[key]
	if type(t) == "table" and t[1] ~= nil then
 holder.Position = UDim2.new(tonumber(t[1]) or 0, tonumber(t[2]) or 0, tonumber(t[3]) or 0, tonumber(t[4]) or 0)
 if t[5] and t[6] then
 local s = tonumber(t[5])
 local h = tonumber(t[6])
 if s and h and s > 10 and h > 10 then
 holder.Size = UDim2.new(0, s, 0, h)
 end
 end
	elseif defaultPos then
 holder.Position = defaultPos
	end
end

function savePos(holder, key)
	St._btnPos = St._btnPos or {}
	St._btnPos[key] = {
 holder.Position.X.Scale, holder.Position.X.Offset,
 holder.Position.Y.Scale, holder.Position.Y.Offset,
 holder.Size.X.Offset, holder.Size.Y.Offset
	}
	saveCfg()
end

function rebuildMobile()
	for _, e in pairs(modeRefs) do if e.holder then e.holder:Destroy() end end
	for _, e in pairs(actRefs) do if e.holder then e.holder:Destroy() end end
	modeRefs, actRefs = {}, {}
	makeModeBtn("Normal", 1)
	makeModeBtn("Lagger", 2)
	makeModeBtn("Custom", 3)
	-- Full Speed V2 GUI bar
	pcall(function()
 if ModeGui then
 for _, ch in ipairs(ModeGui:GetChildren()) do
 if ch:IsA("Frame") and tostring(ch.Name):match("^M_") then
 ch.Visible = false
 end
 end
 end
 if _G.MeridianBuildV2ModeBar then _G.MeridianBuildV2ModeBar() end
 currentSpeedValue = getActiveMoveSpeed()
 pcall(startSpeedBoost)
	end)
	makeActBtn("drop", "DROP", UDim2.new(1, -150, 0.5, -40), function() runDrop() if _G.MeridianCounterOnDrop then pcall(_G.MeridianCounterOnDrop) end end)
	makeActBtn("insta", "INSTA\nRESET", UDim2.new(1, -80, 0.5, -40), doInstaReset)
	makeActBtn("tp", "TP\nDOWN", UDim2.new(1, -80, 0.5, 30), function() doTPDown(true) end)
	makeActBtn("sentry", "SENTRY", UDim2.new(1, -150, 0.5, 30), function()
 local on = not (St.destroySentry == true)
 if type(setDestroySentry) == "function" then
 setDestroySentry(on)
 else
 St.destroySentry = on
 end
 if _G.MeridianRefreshSentryBtn then pcall(_G.MeridianRefreshSentryBtn) end
	end)
	if St.manualCarry == true then
		makeActBtn("carry", "CARRY", UDim2.new(1, -220, 0.5, -5), function() if type(toggleCarry) == "function" then toggleCarry() end end)
	end
	-- restore saved positions
	for key, e in pairs(actRefs) do
 if e.holder then restorePos(e.holder, "A_" .. key) end
	end
	for key, e in pairs(modeRefs) do
 if e.holder then restorePos(e.holder, "M_" .. key) end
	end
	_G.MeridianRefreshModeBar()
	_G.MeridianRefreshSentryBtn()
	if _G.MeridianRefreshCarryBtn then pcall(_G.MeridianRefreshCarryBtn) end
end

-- ON = white/silver with black text, OFF = carbon black with white text
function applyActBtnState(btn, on, onText, offText)
	if not btn then return end
	on = on and true or false
	local txt = on and onText or offText
	if txt then
		btn.Text = txt
		local tl = btn:FindFirstChild("BtnTextOverlay")
		if tl then tl.Text = txt end
	end
	carbonBtnStyle(btn, on)
end

function _G.MeridianRefreshSentryBtn()
	local e = actRefs and actRefs.sentry
	if e and e.btn then
 applyActBtnState(e.btn, St.destroySentry == true, "SENTRY", "SENTRY")
	end
end

function _G.MeridianRefreshCarryBtn()
	local e = actRefs and actRefs.carry
	if e and e.btn then
		applyActBtnState(e.btn, _G.MeridianCarryActive == true, "CARRY", "CARRY")
	end
end

function toggleCarry()
	if St.manualCarry ~= true then return end
	_G.MeridianCarryActive = not (_G.MeridianCarryActive == true)
	currentSpeedValue = getActiveMoveSpeed()
	pcall(_G.MeridianRefreshCarryBtn)
end

function setManualCarry(on)
	St.manualCarry = on and true or false
	_G.MeridianCarryActive = false
	local e = actRefs.carry
	if St.manualCarry then
		if not e then
			makeActBtn("carry", "CARRY", UDim2.new(1, -220, 0.5, -5), toggleCarry)
			local n = actRefs.carry
			if n and n.holder then restorePos(n.holder, "A_carry") end
		end
	elseif e then
		if e.holder then e.holder:Destroy() end
		actRefs.carry = nil
	end
	currentSpeedValue = getActiveMoveSpeed()
	pcall(_G.MeridianRefreshCarryBtn)
	if ToggleRefs.manualCarry and ToggleRefs.manualCarry.setVisual then
		pcall(ToggleRefs.manualCarry.setVisual, St.manualCarry)
	end
	pcall(saveCfg)
end

-- carry press does not survive death (brainrot is dropped on respawn)
LP.CharacterAdded:Connect(function()
	if _G.MeridianCarryActive == true then
		_G.MeridianCarryActive = false
		pcall(_G.MeridianRefreshCarryBtn)
	end
end)

function _G.MeridianRefreshModeBar()
	for n, e in pairs(modeRefs) do
 if e and e.btn then
 local on = St.activeMode == n
 applyCorner(e.btn, "Pill")
 if on then
 e.btn.BackgroundColor3 = C.modeOnBg or Color3.fromRGB(255, 255, 255)
 e.btn.BackgroundTransparency = 0
 e.btn.TextColor3 = C.modeOnTxt or Color3.fromRGB(20, 20, 20)
 local tl = e.btn:FindFirstChild("BtnTextOverlay")
 if tl then
 tl.TextColor3 = Color3.fromRGB(20, 20, 20)
 tl.Text = n
 end
 local st = e.btn:FindFirstChildOfClass("UIStroke")
 if st then st.Color = Color3.fromRGB(255, 255, 255); st.Transparency = 0.05 end
 else
 e.btn.BackgroundColor3 = C.modeOffBg or Color3.fromRGB(38, 38, 38)
 e.btn.BackgroundTransparency = 0
 e.btn.TextColor3 = C.modeOffTxt or Color3.fromRGB(255, 255, 255)
 local tl = e.btn:FindFirstChild("BtnTextOverlay")
 if tl then
 tl.TextColor3 = Color3.fromRGB(255, 255, 255)
 tl.Text = n
 end
 local st = e.btn:FindFirstChildOfClass("UIStroke")
 if st then st.Color = Color3.fromRGB(201, 201, 201); st.Transparency = 0.2 end
 end
 end
	end
end

-- Update size + shape DIRECTLY (no destroy → keeps the dragged position)
_G.MeridianForceApplyShape = function(shape)
	shape = shape or (St and St.btnShape) or "Box"
	if St then St.btnShape = shape end
	local refs = actRefs
	if type(refs) ~= "table" then return end
	for key, e in pairs(refs) do
 if e and e.btn then
 pcall(function()
 applyCorner(e.btn, shape)
 if applyCornerToChildren then applyCornerToChildren(e.btn, shape) end
 end)
 end
	end
end

function _G.MeridianUpdateMobileVisuals()
	for n, e in pairs(modeRefs) do
 if e and e.holder and e.btn then
 local sc = tonumber(St.btnScale) or 1
 local w = math.max(80, math.floor(98 * sc))
 local h = math.max(32, math.floor(36 * sc))
 e.holder.Size = UDim2.new(0, w, 0, h)
 e.btn.TextSize = math.clamp(math.floor(h * 0.36), 11, 14)
 local c = e.btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", e.btn)
 c.CornerRadius = UDim.new(0, 12) -- V2 rounded-rectangle corners
 if e.style then e.style(St.activeMode == n) end
 end
	end
	for key, e in pairs(actRefs) do
 if e and e.holder and e.btn then
 local base = tonumber(St.btnSizes and St.btnSizes.mode) or 38
 local sz = math.max(28, math.floor(base * (St.btnScale or 1)))
 e.holder.Size = UDim2.new(0, sz, 0, sz)
 e.btn.TextSize = math.clamp(math.floor(sz * 0.22), 10, 16)
 applyCorner(e.btn, St.btnShape or "Round")
 applyCornerToChildren(e.btn, St.btnShape or "Round")
 end
	end
	if _G.MeridianRefreshModeBar then pcall(_G.MeridianRefreshModeBar) end
	if _G.MeridianRefreshSentryBtn then pcall(_G.MeridianRefreshSentryBtn) end
	-- Scale Speed V2 mode bar
	pcall(function()
 local gui = PlayerGui:FindFirstChild("MeridianV2ModeBar")
 if not gui then return end
 local sc = tonumber(St.btnScale) or 1
 local modeSz = tonumber(St.btnSizes and St.btnSizes.mode) or 38
 -- Speed 3Mode size: increases height; width stays stable
 local h = math.max(28, math.floor(modeSz * sc))
 local w = math.max(72, math.floor(88 * sc))
 for _, holder in ipairs(gui:GetChildren()) do
 if holder:IsA("Frame") and holder.Name:match("^V2MH_") then
 holder.Size = UDim2.new(0, w, 0, h)
 local btn = holder:FindFirstChildWhichIsA("TextButton")
 if btn then
 btn.TextSize = math.clamp(math.floor(h * 0.36), 9, 16)
 end
 end
 end
	end)
end

function _G.MeridianApplyMobile()
	ModeGui.Enabled = St.mobileBtns == true
	ActGui.Enabled = St.mobileBtns == true
	local hasMode = next(modeRefs) ~= nil
	local hasAct = next(actRefs) ~= nil
	if not hasMode or not hasAct then
 rebuildMobile()
	end
	-- always apply shape/size (Box/Round/Square) even when the button already exists
	if _G.MeridianUpdateMobileVisuals then pcall(_G.MeridianUpdateMobileVisuals) end
end
function _G.MeridianResetMobilePos()
	St._btnPos = {}
	rebuildMobile()
	pcall(saveCfg)
end
_G.MeridianApplyMobile()

----------------------------------------------------------------
-- KEYBINDS (Drop / TP / Insta / Mode) — no menu toggle key
----------------------------------------------------------------
UIS.InputBegan:Connect(function(input, gp)
	if gp or listening then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local k = input.KeyCode
	if k == St.keys.Drop then runDrop() if _G.MeridianCounterOnDrop then pcall(_G.MeridianCounterOnDrop) end
	elseif k == St.keys.TPDown then doTPDown(true)
	elseif k == St.keys.InstaReset then doInstaReset()
	elseif k == St.keys.DestroySentry then setDestroySentry(not St.destroySentry)
	elseif St.keys.AutoSteal and k == St.keys.AutoSteal then
 if type(setAutoSteal) == "function" then
 setAutoSteal(not (St.autoSteal == true))
 -- sync toggle UI
 if ToggleRefs and ToggleRefs.autoSteal and ToggleRefs.autoSteal.setVisual then
 pcall(ToggleRefs.autoSteal.setVisual, St.autoSteal == true)
 end
 end
	else
 for name, m in pairs(St.modes) do
 if m.key == k then toggleMode(name) break end
 end
	end
end)

----------------------------------------------------------------
-- BOOT
----------------------------------------------------------------

-- ============================================================
-- REAPPLY ALL LOGIC (fix/rejoin/respawn) — no fake buttons
-- ============================================================
function reapplyAllLogic(reason)
	reason = tostring(reason or "boot")
	-- Speed
	pcall(function()
 -- force restart loop (speed is always on)
 if speedConnection then
 pcall(function() speedConnection:Disconnect() end)
 speedConnection = nil
 end
 startSpeedBoost()
 if St.activeMode and setActiveMode then setActiveMode(St.activeMode) end
	end)
	-- Inf Jump
	pcall(function()
 if St.infJump then
 InfJumpState.enabled = true
 InfJumpState.mode = "hold"
 if startInfJump then startInfJump() elseif setInfJump then setInfJump(true) end
 else
 if stopInfJump then stopInfJump() end
 end
	end)
	-- Anti Bee
	pcall(function() if St.antiBee then AntiBeeFx.start() else AntiBeeFx.stop() end end)
	-- Anti ragdoll
	pcall(function()
 if St.antiRagdoll then
 if AntiRagdollV2 then AntiRagdollV2.Enabled = true end
 if startAntiRagdoll then startAntiRagdoll() end
 else
 if stopAntiRagdoll then stopAntiRagdoll() end
 end
	end)
	-- Anti FX flags
	pcall(function()
 if AntiFX then
 AntiFX.gummy = true
 AntiFX.boogie = true
 AntiFX.paint = true
 St.antiGummy = true
 St.antiBoogie = true
 St.antiPaint = true
 end
	end)
	-- Tool aim + rehook
	pcall(function()
 if St.toolAim then
 aimOn = true
 local char = LP.Character
 if char and watchTools then watchTools(char) end
 local bp = LP:FindFirstChild("Backpack")
 if bp and watchTools then watchTools(bp) end
 else
 aimOn = false
 end
	end)
	-- Destroy sentry
	pcall(function()
 if St.destroySentry and setDestroySentry then setDestroySentry(true) end
	end)
	-- ESP / tracer / antilag
	pcall(function() if St.esp and setESP then setESP(true) end end)
	pcall(function() if St.tracer and setTracer then setTracer(true) end end)
	pcall(function() if St.antiLag and setAntiLag then setAntiLag(true) end end)
	-- Spam
	pcall(function() if St.spamLaser and setSpamLaser then setSpamLaser(true) end end)
	pcall(function() if St.spamPaint and setSpamPaint then setSpamPaint(true) end end)
	-- Auto steal
	pcall(function()
 if St.autoSteal then
 if type(setAutoSteal) == "function" then setAutoSteal(true) end
 if _G.MeridianSyncAutoSteal then pcall(_G.MeridianSyncAutoSteal) end
 end
	end)
	-- Ragdoll TP
	pcall(function()
	end)
	-- Mobile buttons
	pcall(function()
 if ModeGui then ModeGui.Enabled = St.mobileBtns == true end
 if ActGui then ActGui.Enabled = St.mobileBtns == true end
 if _G.MeridianApplyMobile then pcall(_G.MeridianApplyMobile) end
	end)
	-- Sync toggle UI + force the logic to run if ON
	pcall(function()
 for name, ref in pairs(ToggleRefs or {}) do
 if ref and St[name] ~= nil then
 local on = St[name] == true
 if ref.setVisual then
 pcall(ref.setVisual, on)
 end
 end
 end
	end)
end
_G.MeridianReapplyAllLogic = reapplyAllLogic

-- Re-apply ALL saved states so toggles that show ON actually work
pcall(function() setAntiGummy(St.antiGummy ~= false) end)
pcall(function() setAntiBoogie(St.antiBoogie ~= false) end)
pcall(function() setAntiPaint(St.antiPaint ~= false) end)
pcall(function() setAntiRagdoll(St.antiRagdoll == true) end)
pcall(function() setAntiBee(St.antiBee == true) end)
pcall(function() setToolAim(St.toolAim ~= false) end)
pcall(function() setInfJump(St.infJump ~= false) end)
pcall(function() setDestroySentry(St.destroySentry == true) end)
pcall(startSpeedBoost)
pcall(function() setActiveMode(St.activeMode or "Normal") end)
pcall(function() setESP(St.esp == true) end)
pcall(function() setTracer(St.tracer == true) end)
pcall(function() setAntiLag(St.antiLag == true) end)
pcall(function() setSpamLaser(St.spamLaser == true) end)
pcall(function() setSpamPaint(St.spamPaint == true) end)
-- Auto Steal after setups exist
task.defer(function()
	pcall(function()
 if type(setAutoSteal) == "function" then
 setAutoSteal(St.autoSteal == true)
 end
 if St.autoSteal and _G.MeridianSyncAutoSteal then
 pcall(_G.MeridianSyncAutoSteal)
 end
	end)
end)
pcall(applyMenuScale)
pcall(function() setTab("Player") end)
task.defer(function()
	task.wait(0.6)
	pcall(function() if reapplyAllLogic then reapplyAllLogic("boot") end end)
end)
task.defer(function()
	-- rejoin server: re-apply after 2s (wait for the character/plot to load)
	task.wait(2)
	pcall(function() if reapplyAllLogic then reapplyAllLogic("boot-delayed") end end)
end)
-- Sync toggle UI to match actual state
task.defer(function()
	-- sync toggle UI
	for name, ref in pairs(ToggleRefs or {}) do
 if ref and ref.set and St[name] ~= nil then
 pcall(function() ref.set(St[name] == true) end)
 end
	end
	-- force-apply runtime features (after load / rejoin) — real logic, not just UI
	pcall(function() if startSpeedBoost then startSpeedBoost() end end)
	pcall(function() if St.antiRagdoll and startAntiRagdoll then startAntiRagdoll() end end)
	pcall(function()
 if St.infJump then
 InfJumpState.enabled = true
 InfJumpState.mode = "hold"
 end
	end)
	pcall(function() if St.toolAim and setToolAim then setToolAim(true) end end)
	pcall(function()
 if ModeGui then ModeGui.Enabled = St.mobileBtns == true end
 if ActGui then ActGui.Enabled = St.mobileBtns == true end
 if next(modeRefs) == nil or next(actRefs) == nil then
 if _G.MeridianApplyMobile then _G.MeridianApplyMobile() end
 end
	end)
	pcall(function() if St.activeMode and setActiveMode then setActiveMode(St.activeMode) end end)
	pcall(function() if St.autoSteal and type(setAutoSteal) == "function" then setAutoSteal(true) end end)
	pcall(function() if St.destroySentry and setDestroySentry then setDestroySentry(true) end end)
end)

-- Re-apply features on respawn / rejoin (full logic, no fake buttons)
if _G._MeridianHubCharReapplyConn then
	pcall(function() _G._MeridianHubCharReapplyConn:Disconnect() end)
	_G._MeridianHubCharReapplyConn = nil
end
_G._MeridianHubCharReapplyConn = LP.CharacterAdded:Connect(function(char)
	task.wait(0.4)
	pcall(function()
 if reapplyAllLogic then
 reapplyAllLogic("CharacterAdded")
 else
 if startSpeedBoost then
 if speedConnection then pcall(function() speedConnection:Disconnect() end); speedConnection = nil end
 startSpeedBoost()
 end
 if St.infJump and setInfJump then setInfJump(true) end
 if St.antiRagdoll and startAntiRagdoll then startAntiRagdoll() end
 if St.toolAim and setToolAim then setToolAim(true) end
 if St.autoSteal and _G.MeridianSyncAutoSteal then pcall(_G.MeridianSyncAutoSteal) end
 end
	end)
end)

print("[MERIDIAN Full] Player(Anti+Speed S2+Aim+Drop+Insta) | ESP | Settings mobile/lock/shape/size")

-- ============================================================
-- EXTENSION: InfJump 2-mode | Auto Steal V1/V2 | Steal Bar | Panel TP
-- ============================================================

-- InfJump mode: hold | manual
St.infJumpMode = "hold"

----------------------------------------------------------------
-- PANEL TP (from MERIDIAN, no music / no image / no sentry)
----------------------------------------------------------------
local TP = {
	base = nil, pet = nil,
	delayBase = 0.07, delayPet = 0.07,
	key = Enum.KeyCode.X,
	busy = false, markers = {},
}

_G.setDestroySentry = setDestroySentry

function smoothTP(hrp, pos)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	local tw = TS:Create(hrp, TweenInfo.new(0.065, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
 CFrame = CFrame.new(pos),
	})
	tw:Play()
	tw.Completed:Wait()
end

function chilliTP(hrp, targetPos, char)
	if not hrp or not targetPos then return end
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	-- equip carpet if any
	pcall(function()
 for _, n in ipairs({"Flying Carpet", "Carpet", "Cloud", "Witch's Broom"}) do
 local g = char:FindFirstChild(n) or LP.Backpack:FindFirstChild(n)
 if g and hum then hum:EquipTool(g) break end
 end
	end)
	task.wait(0.04)
	for _, p in ipairs(char:GetDescendants()) do
 if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
	end
	if hum then pcall(function() hum.PlatformStand = true end) end
	local airHeight = 95
	local airPos = Vector3.new(targetPos.X, targetPos.Y + airHeight, targetPos.Z)
	hrp.CFrame = CFrame.new(airPos)
	hrp.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
	task.wait(0.05)
	hrp.AssemblyLinearVelocity = Vector3.new(0, -220, 0)
	local landY = targetPos.Y + 3
	pcall(function()
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = { char }
 local result = workspace:Raycast(airPos, Vector3.new(0, -(airHeight + 80), 0), params)
 if result then landY = result.Position.Y + 3.2 end
	end)
	local landPos = Vector3.new(targetPos.X, landY, targetPos.Z)
	local t0 = os.clock()
	while os.clock() - t0 < 0.55 do
 if not hrp.Parent then break end
 if hrp.Position.Y <= landY + 8 then break end
 hrp.AssemblyLinearVelocity = Vector3.new(0, -220, 0)
 task.wait()
	end
	for _ = 1, 6 do
 if not hrp.Parent then break end
 hrp.CFrame = CFrame.new(landPos)
 hrp.AssemblyLinearVelocity = Vector3.zero
 task.wait(0.03)
	end
	if hum then pcall(function() hum.PlatformStand = false end) end
	for _, p in ipairs(char:GetDescendants()) do
 if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
	end
end

function runPanelTP()
	if TP.busy then return end
	if not TP.base and not TP.pet then
 showToast("No saved point")
 return
	end
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	TP.busy = true
	task.spawn(function()
 pcall(function()
 if (TP.base and not TP.pet) or (TP.pet and not TP.base) then
 chilliTP(hrp, TP.base or TP.pet, char)
 else
 smoothTP(hrp, TP.base)
 task.wait(TP.delayBase)
 char = LP.Character or char
 hrp = char and char:FindFirstChild("HumanoidRootPart") or hrp
 if hrp and TP.pet then smoothTP(hrp, TP.pet) end
 end
 end)
 TP.busy = false
 if _G.MeridianRefreshTPBtn then _G.MeridianRefreshTPBtn() end
	end)
end

-- Panel TP GUI (popup)

-- Center TP button when 2 points saved
do
	local tpg = Instance.new("ScreenGui")
	tpg.Name = "MeridianCenterTP"
	tpg.ResetOnSpawn = false
	tpg.IgnoreGuiInset = true
	tpg.DisplayOrder = 1002
	tpg.Parent = PlayerGui
	local btn = Instance.new("TextButton")
	btn.Name = "CenterTP"
	btn.Size = UDim2.new(0, 160, 0, 40)
	btn.Position = UDim2.new(0.5, -80, 1, -120)
	btn.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
	btn.Text = "TP"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = NAME_FONT
	btn.TextSize = 14
	btn.Visible = false
	btn.Parent = tpg
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
	local bst = Instance.new("UIStroke", btn)
	bst.Color = Color3.fromRGB(220, 220, 220)
	btn.MouseButton1Click:Connect(runPanelTP)
	function _G.MeridianRefreshTPBtn()
 local has = TP.base ~= nil or TP.pet ~= nil
 btn.Visible = has
 local kn = tostring(TP.key):gsub("Enum.KeyCode.", "")
 if TP.base and TP.pet then
 btn.Text = "TP [" .. kn .. "]"
 elseif TP.base or TP.pet then
 btn.Text = "TP 1pt [" .. kn .. "]"
 else
 btn.Visible = false
 end
	end
end

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == TP.key then
 runPanelTP()
	end
end)

----------------------------------------------------------------
-- BODY LOCK (full MERIDIAN Clean)
----------------------------------------------------------------
local bodyLockEnabled = false
local bodyLockRange = 20
local _bodyLockConn = nil
local _blSuppressCount = 0

function getClosestTargetBody()
	local char = LP.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local closest, minDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
 if plr ~= LP and plr.Character then
 local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
 local hum = plr.Character:FindFirstChildOfClass("Humanoid")
 if tRoot and hum and hum.Health > 0 then
 local dist = (tRoot.Position - root.Position).Magnitude
 if dist < minDist then
 minDist = dist
 closest = tRoot
 end
 end
 end
	end
	return closest
end

-- Clean body lock tick (predict + angular velocity)
function _bodyLockTick()
	local char = LP.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local target = getClosestTargetBody()
	if not target then
 if not hum.AutoRotate then hum.AutoRotate = true end
 return
	end
	local range = tonumber(bodyLockRange) or (type(St)=="table" and tonumber(St.bodyLockRange)) or 20
	local dist = (target.Position - root.Position).Magnitude
	if dist > range then
 if not hum.AutoRotate then hum.AutoRotate = true end
 return
	end
	if hum.AutoRotate then hum.AutoRotate = false end
	local targetVel = target.AssemblyLinearVelocity
	local speed3 = targetVel.Magnitude
	local predictTime = math.clamp(speed3 / 80, 0.08, 0.35)
	local predictedPos = target.Position + targetVel * predictTime
	local targetHead = target.Parent and target.Parent:FindFirstChild("Head")
	local targetHeight = targetHead and targetHead.Position.Y or target.Position.Y
	local myHeight = root.Position.Y + (hum.HipHeight or 0)
	local heightDiff = targetHeight - myHeight
	local verticalCorrection = math.clamp(heightDiff * 0.15, -1.5, 1.5)
	local flatTarget = Vector3.new(predictedPos.X, root.Position.Y + verticalCorrection, predictedPos.Z)
	local toPredict = flatTarget - root.Position
	if toPredict.Magnitude > 0.1 then
 local goalCF = CFrame.lookAt(root.Position, flatTarget)
 local diffCF = root.CFrame:Inverse() * goalCF
 local _, ry, _ = diffCF:ToEulerAnglesXYZ()
 ry = math.clamp(ry, -2.5, 2.5)
 root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(0, ry * 42, 0))
	end
end

function startBodyLock()
	if _bodyLockConn then
 pcall(function() _bodyLockConn:Disconnect() end)
 _bodyLockConn = nil
	end
	bodyLockEnabled = true
	if type(St) == "table" then St.bodyLock = true end
	local RS_ = RS or RunService or game:GetService("RunService")
	_bodyLockConn = RS_.RenderStepped:Connect(function()
 if not bodyLockEnabled then return end
 if (_blSuppressCount or 0) > 0 then return end
 _bodyLockTick()
	end)
end

function stopBodyLock()
	if _bodyLockConn then
 pcall(function() _bodyLockConn:Disconnect() end)
 _bodyLockConn = nil
	end
	bodyLockEnabled = false
	if type(St) == "table" then St.bodyLock = false end
	local c = LP.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root then
 root.AssemblyAngularVelocity = Vector3.zero
 root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -0.1, root.AssemblyLinearVelocity.Z)
	end
	local hum2 = c and c:FindFirstChildOfClass("Humanoid")
	if hum2 then hum2.AutoRotate = true end
end

-- Clean suppress (auto left/right / bat can pause lock)

function setBodyLock(on)
	if on then startBodyLock() else stopBodyLock() end
	pcall(function() if saveCfg then saveCfg() end end)
end

-- sync range from config when set
function setBodyLockRange(v)
	v = math.clamp(tonumber(v) or 20, 5, 100)
	bodyLockRange = v
	St.bodyLockRange = v
	saveCfg()
end

----------------------------------------------------------------
-- UI: Panel tab + Auto Steal + InfJump mode on existing pages
----------------------------------------------------------------
task.defer(function()
	-- Auto steal on Player page
	if not pagePlayer then warn("[MERIDIAN] pagePlayer nil") return end
	section(pagePlayer, "Auto Steal", 0.1)
	local function safeSetAS(on)
 if type(setAutoSteal) == "function" then
 setAutoSteal(on)
 else
 St.autoSteal = on and true or false
 end
	end
	toggleNamed(pagePlayer, "Auto Steal", St.autoSteal == true, safeSetAS, 0.2, "autoSteal")
	-- force scroll size so AUTO STEAL is visible
	pcall(function()
 local lay = pagePlayer:FindFirstChildOfClass("UIListLayout")
 if lay then
 pagePlayer.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 40)
 end
	end)

	setTab("Panel")
end)

print("[MERIDIAN Ext] Panel TP | AutoSteal V1/V2 + bar | InfJump hold/manual | ToolAim ON")

-- ============================================================
-- TP TO BEST — equip carpet + TP best brainrot
-- ============================================================

function tpToBestChilli()
	-- removed per request
end
_G.MeridianTpToBest = tpToBestChilli

-- UI: button on Panel + mobile + keybind
St.keys.TpBest = St.keys.TpBest or Enum.KeyCode.B

task.defer(function()
	local pagePanel = pages and pages["Panel"]
	if pagePanel then
 section(pagePanel, "Panel TP", 10)
 -- TP BEST removed
	-- actionBtn panel removed
 local info = row(pagePanel, 44, 12)
 local t = Instance.new("TextLabel")
 t.Size = UDim2.new(1, -10, 1, 0)
 t.Position = UDim2.new(0, 6, 0, 0)
 t.BackgroundTransparency = 1
 t.Text = "Infinite Jump Hold/Manual"
 t.TextColor3 = C.textDim
 t.TextSize = 10
 t.Font = Enum.Font.Gotham
 t.TextXAlignment = Enum.TextXAlignment.Left
 t.Parent = info
	end
	-- also on Player for easy test
	if pagePlayer then
 section(pagePlayer, "Inf Jump", 40)
 -- TP BEST removed
	end
end)

-- Mobile external button
task.defer(function()
	local g = Instance.new("ScreenGui")
	g.Name = "MeridianTpBestBtn"
	g.Enabled = false -- removed TP BEST
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 1003
	g.Parent = PlayerGui
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 110, 0, 36)
	b.Position = UDim2.new(0.5, -55, 0, 12)
	b.BackgroundColor3 = Color3.fromRGB(33, 33, 33)
	b.Text = "INF JUMP"
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = NAME_FONT
	b.TextSize = 13
	b.Parent = g
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(200, 200, 200)
	s.Thickness = 1.5
	b.MouseButton1Click:Connect(tpToBestChilli)
	-- drag
	do
 local dragging, dragStart, startPos, moved
 b.InputBegan:Connect(function(input)
 if St.guiLock then return end
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 dragging = true
 moved = false
 dragStart = input.Position
 startPos = b.Position
 input.Changed:Connect(function()
 if input.UserInputState == Enum.UserInputState.End then dragging = false end
 end)
 end
 end)
 UIS.InputChanged:Connect(function(input)
 if not dragging or St.guiLock then return end
 if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
 local d = input.Position - dragStart
 if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
 if moved then
 b.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
 end
 end
 end)
	end
end)

-- TP Best keybind removed

----------------------------------------------------------------
-- OVERHEAD: real speed + discord (from MERIDIAN)
----------------------------------------------------------------
local overheadGui, overheadSpeedLabel
function setupOverheadInfo(char)
	char = char or LP.Character
	if not char then return end
	local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
	if not head then
 -- fallback HRP
 head = char:FindFirstChild("HumanoidRootPart")
 if not head then return end
	end
	pcall(function()
 local old = head:FindFirstChild("MeridianOverheadInfo")
 if old then old:Destroy() end
	end)
	if overheadGui then pcall(function() overheadGui:Destroy() end) end
	overheadGui = Instance.new("BillboardGui")
	overheadGui.Name = "MeridianOverheadInfo"
	overheadGui.Size = UDim2.new(0, 300, 0, 96)
	overheadGui.StudsOffset = Vector3.new(0, 2.8, 0)
	overheadGui.AlwaysOnTop = true
	overheadGui.MaxDistance = 200
	overheadGui.LightInfluence = 0
	overheadGui.Adornee = head
	overheadGui.Parent = head
	local discordLbl = Instance.new("TextLabel")
	discordLbl.Size = UDim2.new(1, 0, 0, 20)
	discordLbl.Position = UDim2.new(0, 0, 0, 22)
	discordLbl.BackgroundTransparency = 1
	discordLbl.Text = ""
	discordLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	discordLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	discordLbl.TextStrokeTransparency = 0
	discordLbl.Font = Enum.Font.Bangers
	discordLbl.TextSize = 16
	discordLbl.Parent = overheadGui
	overheadSpeedLabel = Instance.new("TextLabel")
	overheadSpeedLabel.Size = UDim2.new(1, 0, 0, 22)
	overheadSpeedLabel.Position = UDim2.new(0, 0, 0, 44)
	overheadSpeedLabel.BackgroundTransparency = 1
	overheadSpeedLabel.Text = "Speed: 0.0"
	overheadSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	overheadSpeedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	overheadSpeedLabel.TextStrokeTransparency = 0
	overheadSpeedLabel.Font = Enum.Font.Bangers
	overheadSpeedLabel.TextSize = 18
	overheadSpeedLabel.Parent = overheadGui
end
if not _G._MeridianOverheadLoop then
	_G._MeridianOverheadLoop = true
	LP.CharacterAdded:Connect(function(ch)
 task.wait(0.5)
 setupOverheadInfo(ch)
	end)
	if LP.Character then task.defer(function() setupOverheadInfo(LP.Character) end) end
	local visSpeed = 0
	RS.RenderStepped:Connect(function(dt)
 if not overheadSpeedLabel then return end
 local char = LP.Character
 local root = char and char:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local hum = char:FindFirstChildOfClass("Humanoid")
 local v = root.AssemblyLinearVelocity
 local actual = Vector3.new(v.X, 0, v.Z).Magnitude
 local okT, target = pcall(getActiveMoveSpeed)
 if not okT or type(target) ~= "number" then target = 0 end
 local moving = (hum and hum.MoveDirection.Magnitude > 0.1) or actual > 1
 local top = target > 0 and target or actual
 local want = moving and top or 0
 -- visual only: reaches the set speed in 0.15s when moving, drops back when you stop
 local step = (math.max(top, 1) / 0.15) * dt
 if visSpeed < want then visSpeed = math.min(want, visSpeed + step)
 elseif visSpeed > want then visSpeed = math.max(want, visSpeed - step) end
 local shown = math.floor(visSpeed + 0.5)
 if shown ~= _spd.shownSpeed then
 _spd.shownSpeed = shown
 overheadSpeedLabel.Text = "Speed: " .. shown
 end
	end)
end

print("[MERIDIAN] TP TO BEST ready | key B | TP BEST button")

-- ============================================================
-- AUTO STEAL — half-hold engine
-- hold HalfHoldMin (1.3s) -> fire when within HalfFireRange, give up at HalfHoldMax (2.6s)
-- Bar fill: 0 -> 100% over HalfHoldMin, 100% for 0.3s once done, then eased drain
-- ============================================================
ZenStealState = { isStealing = false, startTime = nil, endTime = nil, completed = false }
do
	local Steal = {
		AutoStealEnabled = false,
		StealRadius = 55,
		StealDuration = 0.1,
		Mode = "half",
		HalfFireRange = 10,
		HalfHoldMin = 1.3,
		HalfHoldMax = 2.6,
		HalfEntryDelay = 0.3,
		Data = {},
	}
	local S = ZenStealState
	local autoConn = nil

	-- Never run two engines: shut the previous instance down first.
	do
		local prev = _G.AutoSteal
		if type(prev) == "table" then
			prev.AutoStealEnabled = false
			if type(prev.Stop) == "function" then pcall(prev.Stop) end
		end
	end

	local function rootPart()
		local char = LP.Character
		if not char then return nil end
		return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	end

	local function isMyPlotByName(plotName)
		local plots = workspace:FindFirstChild("Plots")
		if not plots then return false end
		local plot = plots:FindFirstChild(plotName)
		if not plot then return false end
		local sign = plot:FindFirstChild("PlotSign")
		if sign then
			local yb = sign:FindFirstChild("YourBase")
			if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
		end
		return false
	end

	local function findNearestPrompt()
		local root = rootPart()
		if not root then return nil end
		local plots = workspace:FindFirstChild("Plots")
		if not plots then return nil end
		local nearest, dist = nil, math.huge
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:IsA("Model") and not isMyPlotByName(plot.Name) then
				local pods = plot:FindFirstChild("AnimalPodiums")
				if pods then
					for _, pod in ipairs(pods:GetChildren()) do
						local base = pod:FindFirstChild("Base")
						local sp = base and base:FindFirstChild("Spawn")
						if sp then
							local d = (sp.Position - root.Position).Magnitude
							if d <= Steal.StealRadius and d < dist then
								local found = nil
								local att = sp:FindFirstChild("PromptAttachment")
								if att then
									for _, pr in ipairs(att:GetChildren()) do
										if pr:IsA("ProximityPrompt") and pr.ActionText and pr.ActionText:find("Steal") then found = pr end
									end
								end
								if not found then
									for _, pr in ipairs(sp:GetDescendants()) do
										if pr:IsA("ProximityPrompt") and pr.ActionText and pr.ActionText:find("Steal") then found = pr end
									end
								end
								if found then nearest, dist = found, d end
							end
						end
					end
				end
			end
		end
		return nearest
	end

	local function promptDist(prompt)
		local root = rootPart()
		if not root then return math.huge end
		local part = prompt.Parent
		if part and part:IsA("Attachment") then part = part.Parent end
		if part and part:IsA("BasePart") then return (part.Position - root.Position).Magnitude end
		local ok, cf = pcall(function() return prompt.Parent and prompt.Parent.WorldPosition end)
		if ok and cf then return (cf - root.Position).Magnitude end
		return math.huge
	end

	local function executeSteal(prompt)
		if S.isStealing then return end
		if not Steal.Data[prompt] then
			Steal.Data[prompt] = { hold = {}, trigger = {}, ready = true }
			if getconnections then
				for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
					if c.Function then table.insert(Steal.Data[prompt].hold, c.Function) end
				end
				for _, c in ipairs(getconnections(prompt.Triggered)) do
					if c.Function then table.insert(Steal.Data[prompt].trigger, c.Function) end
				end
			end
		end
		local data = Steal.Data[prompt]
		if not data.ready then return end
		data.ready = false
		S.isStealing = true
		S.completed = false
		S.startTime = tick()
		S.endTime = nil

		task.spawn(function()
			for _, fn in ipairs(data.hold) do task.spawn(fn) end
			task.wait(Steal.HalfHoldMin)
			local inRange = promptDist(prompt) <= Steal.HalfFireRange
			while true do
				local el = tick() - S.startTime
				if el > Steal.HalfHoldMax or not prompt.Parent then break end
				if promptDist(prompt) <= Steal.HalfFireRange then
					if not inRange then task.wait(Steal.HalfEntryDelay) end
					for _, fn in ipairs(data.trigger) do task.spawn(fn) end
					break
				end
				task.wait()
			end
			S.completed = true
			S.endTime = tick()
			task.wait(0.5)
			data.ready = true
			S.isStealing = false
			S.completed = false
		end)
	end

	local function startAutoSteal()
		if autoConn then return end
		local nextScan = 0
		autoConn = RS.Heartbeat:Connect(function()
			if not Steal.AutoStealEnabled or S.isStealing then return end
			local now = os.clock()
			if now < nextScan then return end
			nextScan = now + 0.05
			Steal.StealRadius = tonumber(St.stealRadius) or Steal.StealRadius
			local p = findNearestPrompt()
			if p then executeSteal(p) end
		end)
	end

	local function stopAutoSteal()
		if autoConn then pcall(function() autoConn:Disconnect() end) autoConn = nil end
	end

	local function syncSteal()
		Steal.AutoStealEnabled = St.autoSteal == true
		Steal.StealRadius = tonumber(St.stealRadius) or Steal.StealRadius
		if Steal.AutoStealEnabled then startAutoSteal() else stopAutoSteal() end
	end

	Steal.Stop = stopAutoSteal
	_G.AutoSteal = Steal
	_G.MeridianSyncAutoSteal = syncSteal

	function setAutoSteal(on)
		St.autoSteal = on and true or false
		syncSteal()
		if ToggleRefs and ToggleRefs.autoSteal and ToggleRefs.autoSteal.setVisual then
			pcall(ToggleRefs.autoSteal.setVisual, St.autoSteal == true)
		end
		saveCfg()
	end
	_G.setAutoSteal = setAutoSteal
	pcall(syncSteal)
end

-- Wallpaper list (MERIDIAN style)
local VIS_WALLS = {
	-- Empire BG only
	"rbxassetid://125573386004845", "rbxassetid://104540837462600", "rbxassetid://129892685439735", "rbxassetid://109576317344038",
}
St.wallIndex = math.clamp(tonumber(St.wallIndex) or 1, 1, math.max(1, #VIS_WALLS))
task.defer(function()
	if not pageSet then return end
	section(pageSet, "Wallpaper", 25)
	local wr = row(pageSet, 40, 28)
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(0, 56, 0, 32)
	img.Position = UDim2.new(0, 8, 0.5, -16)
	img.BackgroundColor3 = C.box
	img.ScaleType = Enum.ScaleType.Crop
	img.Image = VIS_WALLS[St.wallIndex] or VIS_WALLS[1]
	img.ZIndex = 2
	img.Parent = wr
	Instance.new("UICorner", img).CornerRadius = UDim.new(0, 6)
	local idxLbl = Instance.new("TextLabel")
	idxLbl.Size = UDim2.new(0, 48, 0, 20)
	idxLbl.Position = UDim2.new(0, 70, 0.5, -10)
	idxLbl.BackgroundTransparency = 1
	idxLbl.Text = "#" .. tostring(St.wallIndex) .. "/" .. tostring(#VIS_WALLS)
	idxLbl.TextColor3 = C.textDim
	idxLbl.Font = Enum.Font.GothamBold
	idxLbl.TextSize = 11
	idxLbl.ZIndex = 2
	idxLbl.Parent = wr
	local function applyWall()
 local n = #VIS_WALLS
 if n < 1 then return end
 St.wallIndex = ((tonumber(St.wallIndex) or 1) - 1) % n + 1
 local asset = VIS_WALLS[St.wallIndex]
 img.Image = asset
 idxLbl.Text = "#" .. tostring(St.wallIndex) .. "/" .. tostring(n)
 local bg = Main:FindFirstChild("WallBG")
 if not bg then
 bg = Instance.new("ImageLabel")
 bg.Name = "WallBG"
 bg.Size = UDim2.new(1, 0, 1, 0)
 bg.Position = UDim2.new(0, 0, 0, 0)
 bg.BackgroundTransparency = 1
 bg.ScaleType = Enum.ScaleType.Crop
 bg.ZIndex = 0
 bg.Active = false
 bg.Selectable = false
 bg.ZIndex = 0
 bg.Parent = Main
 -- dim overlay for deeper look while keeping UI clickable
 local dim = Instance.new("Frame")
 dim.Name = "WallDim"
 dim.Size = UDim2.new(1, 0, 1, 0)
 dim.BackgroundColor3 = Color3.new(0, 0, 0)
 dim.BackgroundTransparency = 1 -- dim layer removed: wallpaper at full brightness
 dim.BorderSizePixel = 0
 dim.ZIndex = 0
 dim.Active = false
 dim.Selectable = false
 dim.Parent = Main
 Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)
 for _, ch in ipairs(Main:GetChildren()) do
 if ch ~= bg and ch.Name ~= "WallDim" and ch:IsA("GuiObject") then
 if ch.ZIndex < 2 then ch.ZIndex = 2 end
 end
 end
 end
 bg.Image = asset
 bg.ImageTransparency = 0 -- full clarity, no wash-out
 bg.Active = false
 bg.Selectable = false
 bg.ScaleType = Enum.ScaleType.Crop
 bg.Visible = true
 Main.BackgroundTransparency = 0.55
 saveCfg()
	end
	applyWall()
	for i, sign in ipairs({"-", "+"}) do
 local b = Instance.new("TextButton")
 b.Size = UDim2.new(0, 30, 0, 28)
 b.Position = UDim2.new(1, -72 + (i-1)*34, 0.5, -14)
 b.BackgroundColor3 = C.box
 b.Text = sign
 b.TextColor3 = C.text
 b.Font = Enum.Font.GothamBold
 b.TextSize = 16
 b.AutoButtonColor = true
 b.Active = true
 b.ZIndex = 3
 b.Parent = wr
 Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
 local function step()
 local n = #VIS_WALLS
 if n < 1 then return end
 St.wallIndex = (tonumber(St.wallIndex) or 1) + (sign == "+" and 1 or -1)
 if St.wallIndex < 1 then St.wallIndex = n end
 if St.wallIndex > n then St.wallIndex = 1 end
 applyWall()
 end
 b.Activated:Connect(step)
	end
end)

-- Mini = circle combat when closed
-- Watchdog: if the toggle is ON but the logic died → turn it back ON
if not _G._MeridianLogicWatchdog then
	_G._MeridianLogicWatchdog = true
	task.spawn(function()
 while true do
 task.wait(8)
 pcall(function()
 
 local alive = false
 if speedConnection then pcall(function() alive = speedConnection.Connected == true end) end
 if not alive and startSpeedBoost then
 speedConnection = nil
 startSpeedBoost()
 end
 
 if St.infJump and InfJumpState and not InfJumpState.enabled then
 if startInfJump then startInfJump() end
 end
 if St.antiRagdoll and AntiRagdollV2 and not AntiRagdollV2.Enabled then
 if startAntiRagdoll then startAntiRagdoll() end
 end
 if St.autoSteal and _G.MeridianSyncAutoSteal then
 pcall(_G.MeridianSyncAutoSteal)
 end
 end)
 end
	end)
end

print("[Meridian AllGear] Speed | InfJump Empire | RagdollTP | AutoSteal | Wallpaper | Control")

-- Auto-save ALL settings every 3s — every position + open/closed state + sizes (nothing missed)
task.spawn(function()
	while task.wait(3) do
 pcall(function()
 -- Main menu
 if Main and Main.Parent then
 St._mainPos = {Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset}
 St.menuOpen = Main.Visible == true
 end
 -- Mini open button
 local miniGui = PlayerGui:FindFirstChild("MeridianHubFullMini")
 local mini = miniGui and miniGui:FindFirstChildWhichIsA("TextButton")
 if mini then
 St._miniPos = {mini.Position.X.Scale, mini.Position.X.Offset, mini.Position.Y.Scale, mini.Position.Y.Offset}
 end
 -- Mode bar
 local mb = PlayerGui:FindFirstChild("MeridianHubModeBar")
 if mb then
 local f = mb:FindFirstChildWhichIsA("Frame")
 if f then
 St._modeBarPos = {f.Position.X.Scale, f.Position.X.Offset, f.Position.Y.Scale, f.Position.Y.Offset}
 end
 end
 -- Action + Mode buttons: saves the POSITION of the holder Frame (A_* / M_*), not the TextButton
 St._btnPos = St._btnPos or {}
 local function snapHolders(gui)
 if not gui then return end
 for _, holder in ipairs(gui:GetChildren()) do
 if holder:IsA("Frame") or holder:IsA("TextButton") then
 local key = holder.Name
 if key and (key:sub(1,2) == "A_" or key:sub(1,2) == "M_") then
 St._btnPos[key] = {
 holder.Position.X.Scale, holder.Position.X.Offset,
 holder.Position.Y.Scale, holder.Position.Y.Offset,
 holder.Size.X.Offset, holder.Size.Y.Offset
 }
 end
 end
 end
 end
 snapHolders(PlayerGui:FindFirstChild("MeridianHubActionButtons"))
 snapHolders(PlayerGui:FindFirstChild("MeridianHubModeBar"))
 -- Panel TP
 local tp = PlayerGui:FindFirstChild("MeridianHubbTP")
 if tp then
 local m = tp:FindFirstChild("TPMain")
 if m then
 St._tpMainPos = {m.Position.X.Scale, m.Position.X.Offset, m.Position.Y.Scale, m.Position.Y.Offset}
 St._tpMinimized = (m.Size.Y.Offset or 0) < 120
 end
 end
 -- Auto Steal floating GUI pos if any
 local asg = PlayerGui:FindFirstChild("MeridianAutoStealGui")
 if asg then
 local mf = asg:FindFirstChildWhichIsA("Frame")
 if mf then
 St._stealGuiPos = {mf.Position.X.Scale, mf.Position.X.Offset, mf.Position.Y.Scale, mf.Position.Y.Offset}
 end
 end
 saveCfg() -- dump all of St
 end)
	end
end)

-- restore positions on load
task.defer(function()
	pcall(function()
 if St._mainPos and Main then
 Main.Position = UDim2.new(St._mainPos[1], St._mainPos[2], St._mainPos[3], St._mainPos[4])
 end
 local miniGui = PlayerGui:FindFirstChild("MeridianHubFullMini")
 local mini = miniGui and miniGui:FindFirstChildWhichIsA("TextButton")
 if mini and St._miniPos then
 mini.Position = UDim2.new(St._miniPos[1], St._miniPos[2], St._miniPos[3], St._miniPos[4])
 end
	end)
end)

task.defer(function()
	if St.menuOpen == false then
 pcall(function()
 Main.Visible = false
 Mini.Visible = true
 end)
	end
end)

-- ============================================================
-- PANEL TP STANDALONE (compact + rainbow border + markers)
-- ============================================================
task.spawn(function()
	local SAVE_BASE, SAVE_PET = nil, nil
	local function toVec(t)
 if typeof(t) == "Vector3" then return t end
 if type(t) == "table" then
 local x,y,z = tonumber(t[1]) or tonumber(t.X), tonumber(t[2]) or tonumber(t.Y), tonumber(t[3]) or tonumber(t.Z)
 if x and y and z then return Vector3.new(x,y,z) end
 end
 return nil
	end
	-- Does not remember base/pet between sessions — only panel position
	SAVE_BASE = nil
	SAVE_PET = nil
	St._saveBase = nil
	St._savePet = nil
	print("[TP] base/pet memory disabled (panel pos only)")
	local DELAY_BASE = tonumber(St._delayBase) or 0.15
	local DELAY_PET = tonumber(St._delayPet) or 0.15
	local KEYBIND_TP = Enum.KeyCode.X
	St._keyTP = "X"
	local IS_TPING, panelLocked, MINIMIZE = false, false, St._tpMinimized == true
	local MARK_BASE, MARK_PET = nil, nil

	local function Marker(pos, col)
 local p = Instance.new("Part")
 p.Name = "MeridianTP_Marker"
 p.Shape = Enum.PartType.Cylinder
 p.Size = Vector3.new(0.35, 4, 4)
 p.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
 p.Anchored = true
 p.CanCollide = false
 p.Material = Enum.Material.Neon
 p.Color = col
 p.Transparency = 0.15
 p.Parent = workspace
 -- ring spin light
 local light = Instance.new("PointLight", p)
 light.Color = col
 light.Brightness = 2
 light.Range = 10
 return p
	end
	local function clearMark(m)
 if m then pcall(function() m:Destroy() end) end
	end

	local function SmoothTP(hrp, pos)
 if not hrp or not pos then return end
 pcall(function()
 hrp.AssemblyLinearVelocity = Vector3.zero
 hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
 end)
	end
	local _chilliAntiDieToken = 0
	local function enableChilliAntiDie(hum, char, duration)
	    if not hum or not char then return function() end end
	    _chilliAntiDieToken = _chilliAntiDieToken + 1
	    local myToken = _chilliAntiDieToken
	    local conns = {}

	    pcall(function()
	        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	    end)

	    table.insert(conns, hum:GetPropertyChangedSignal("Health"):Connect(function()
	        if myToken ~= _chilliAntiDieToken then return end
	        if hum and hum.Parent and hum.Health < hum.MaxHealth then
	            pcall(function() hum.Health = hum.MaxHealth end)
	        end
	    end))

	    local function onDied()
	        if myToken ~= _chilliAntiDieToken then return end
	        task.defer(function()
	            if myToken ~= _chilliAntiDieToken then return end
	            if hum and hum.Parent then
	                pcall(function()
	                    hum.Health = hum.MaxHealth
	                    hum:ChangeState(Enum.HumanoidStateType.Running)
	                end)
	            end
	        end)
	    end
	    table.insert(conns, hum.Died:Connect(onDied))

	    pcall(function()
	        if char:GetAttribute("BreakJoints") ~= nil then
	            char:SetAttribute("BreakJoints", false)
	        end
	    end)

	    local function disable()
	        if myToken ~= _chilliAntiDieToken then return end
	        _chilliAntiDieToken = _chilliAntiDieToken + 1
	        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	        pcall(function()
	            if hum and hum.Parent then
	                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
	            end
	        end)
	    end

	    if duration and duration > 0 then
	        task.delay(duration, disable)
	    end
	    return disable
	end

	local EquipFly
	local function ChilliDrop(hrp, targetPos, char)
    if not hrp or not targetPos then return end
    char = char or LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    enableChilliAntiDie(hum, char, 1.2)
    pcall(function() hum.Health = hum.MaxHealth end)

    EquipFly(char)
    task.wait(0.02)

    local function stopVel()
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    -- 1) FAST LIFT (shortened Ace drop ascend)
    local ASCEND_DUR = 0.08
    local ASCEND_SPD = 180
    local t0 = tick()
    while tick() - t0 < ASCEND_DUR do
        if not hrp or not hrp.Parent then return end
        pcall(function()
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, ASCEND_SPD, v.Z)
        end)
        RS.Heartbeat:Wait()
    end

    -- 2) FLY STRAIGHT PAST the save point (CFrame once, moderately high for a fast drop)
    local airY = targetPos.Y + 16
    stopVel()
    pcall(function()
        hrp.CFrame = CFrame.new(targetPos.X, airY, targetPos.Z)
        hrp.AssemblyLinearVelocity = Vector3.new(0, -200, 0) -- start slamming down immediately
    end)

    -- 3) DROP SLAMS THE GROUND IMMEDIATELY like Ace (raycast + snap, waits a very short time at most)
    local landY = targetPos.Y
    pcall(function()
        local ignore = {char}
        for _, p in ipairs(workspace:GetChildren()) do
            if p.Name == "SavePoint" then table.insert(ignore, p) end
        end
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = ignore
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local origin = Vector3.new(targetPos.X, airY + 5, targetPos.Z)
        local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), rayParams)
        if hit then
            local offset = (hum.HipHeight or 2) + (hrp.Size.Y / 2)
            landY = hit.Position.Y + offset
        end
    end)
    local landPos = Vector3.new(targetPos.X, landY, targetPos.Z)

    -- Only wait 1–2 falling frames then snap (as fast as Ace drop)
    local fallT = tick()
    while tick() - fallT < 0.10 do
        if not hrp or not hrp.Parent then break end
        if hrp.Position.Y <= landY + 6 then break end
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(0, -220, 0)
        end)
        RS.Heartbeat:Wait()
    end

    pcall(function()
        hrp.CFrame = CFrame.new(landPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    stopVel()

    pcall(function()
        hum.Sit = false
        hum.PlatformStand = false
        hum.AutoRotate = true
        hum.Health = hum.MaxHealth
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end)
    pcall(function()
        local cam = workspace.CurrentCamera
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if cam and h then cam.CameraSubject = h end
    end)
	end
	function EquipFly(char)
 char = char or LP.Character
 local hum = char and char:FindFirstChildOfClass("Humanoid")
 if not hum then return end
 for _, n in ipairs({"Flying Carpet", "Carpet", "Witch's Broom", "Cloud"}) do
 local t = char:FindFirstChild(n) or LP.Backpack:FindFirstChild(n)
 if t and t:IsA("Tool") then pcall(function() hum:EquipTool(t) end) return end
 end
	end

	-- restore markers
	if SAVE_BASE then MARK_BASE = Marker(SAVE_BASE, Color3.fromRGB(255, 105, 180)) end
	if SAVE_PET then MARK_PET = Marker(SAVE_PET, Color3.fromRGB(255, 140, 0)) end

	pcall(function()
 local old = PlayerGui:FindFirstChild("MeridianHubbTP")
 if old then old:Destroy() end
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeridianHubbTP"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 80
	gui.Enabled = (St.showTPPanel ~= false)
	gui.Parent = PlayerGui

	local Main = Instance.new("Frame")
	Main.Name = "TPMain"
	Main.Size = UDim2.new(0, 210, 0, 268)
	Main.Position = UDim2.new(0.02, 0, 0.28, 0)
	if type(St._tpMainPos) == "table" then
 Main.Position = UDim2.new(St._tpMainPos[1], St._tpMainPos[2], St._tpMainPos[3], St._tpMainPos[4])
	end
	Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	Main.BorderSizePixel = 0
	Main.Active = true
	Main.ClipsDescendants = true
	Main.Parent = gui
	Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

	-- rainbow 7-color stroke
	local stroke = Instance.new("UIStroke", Main)
	stroke.Thickness = 2.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local rainbow = {
 Color3.fromRGB(255, 255, 255),
 Color3.fromRGB(210, 210, 210),
 Color3.fromRGB(165, 165, 165),
 Color3.fromRGB(120, 120, 120),
 Color3.fromRGB(165, 165, 165),
 Color3.fromRGB(210, 210, 210),
 Color3.fromRGB(255, 255, 255),
	}
	task.spawn(function()
 local i = 1
 while Main and Main.Parent do
 stroke.Color = rainbow[i]
 i = i % #rainbow + 1
 task.wait(0.12)
 end
	end)

	-- header row
	local ROW = 30
	local PAD = 8
	local function y(i) return 6 + (i - 1) * (ROW + 4) end

	local LockBtn = Instance.new("TextButton", Main)
	LockBtn.Size = UDim2.new(0, 54, 0, 24)
	LockBtn.Position = UDim2.new(0, PAD, 0, y(1))
	LockBtn.BackgroundColor3 = Color3.fromRGB(33, 33, 33)
	LockBtn.Text = "UNLOCK"
	LockBtn.TextColor3 = Color3.new(1,1,1)
	LockBtn.Font = Enum.Font.GothamBold
	LockBtn.TextSize = 10
	Instance.new("UICorner", LockBtn).CornerRadius = UDim.new(0, 6)

	local title = Instance.new("TextLabel", Main)
	title.Size = UDim2.new(1, -100, 0, 24)
	title.Position = UDim2.new(0, 64, 0, y(1))
	title.BackgroundTransparency = 1
	title.Text = "Meridian Tp"
	title.TextColor3 = Color3.fromRGB(221, 221, 221)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left

	local CloseBtn = Instance.new("TextButton", Main)
	CloseBtn.Size = UDim2.new(0, 26, 0, 24)
	CloseBtn.Position = UDim2.new(1, -34, 0, y(1))
	CloseBtn.BackgroundColor3 = Color3.fromRGB(33, 33, 33)
	CloseBtn.Text = MINIMIZE and "+" or "−"
	CloseBtn.TextColor3 = Color3.new(1,1,1)
	CloseBtn.Font = Enum.Font.GothamBold
	CloseBtn.TextSize = 16
	Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

	local body = Instance.new("Frame", Main)
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 0, 190)
	body.Position = UDim2.new(0, PAD, 0, y(2))
	body.BackgroundTransparency = 1
	body.Visible = not MINIMIZE

	local function mkBtn(text, row, col)
 local b = Instance.new("TextButton", body)
 b.Size = UDim2.new(1, 0, 0, ROW)
 b.Position = UDim2.new(0, 0, 0, (row - 1) * (ROW + 4))
 b.BackgroundColor3 = col
 b.Text = text
 b.TextColor3 = Color3.new(1,1,1)
 b.Font = NAME_FONT
 b.TextSize = 12
 Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
 return b
	end
	local function mkLabel(text, row)
 local l = Instance.new("TextLabel", body)
 l.Size = UDim2.new(1, -64, 0, ROW)
 l.Position = UDim2.new(0, 0, 0, (row - 1) * (ROW + 4))
 l.BackgroundTransparency = 1
 l.Text = text
 l.TextColor3 = Color3.fromRGB(182, 182, 182)
 l.Font = Enum.Font.Gotham
 l.TextSize = 11
 l.TextXAlignment = Enum.TextXAlignment.Left
 return l
	end
	local function mkAdj(row, onMinus, onPlus)
 for i, s in ipairs({"-", "+"}) do
 local b = Instance.new("TextButton", body)
 b.Size = UDim2.new(0, 28, 0, 26)
 b.Position = UDim2.new(1, -60 + (i - 1) * 30, 0, (row - 1) * (ROW + 4) + 2)
 b.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
 b.Text = s
 b.TextColor3 = Color3.new(1,1,1)
 b.Font = Enum.Font.GothamBold
 b.TextSize = 14
 Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
 b.MouseButton1Click:Connect(s == "-" and onMinus or onPlus)
 end
	end

	local BtnSaveBase = mkBtn("Save Base", 1, Color3.fromRGB(96, 96, 96))
	local BtnSavePet = mkBtn("Save Pet", 2, Color3.fromRGB(132, 132, 132))
	local LblBase = mkLabel("Base: " .. string.format("%.2f", DELAY_BASE) .. "s", 3)
	local LblPet = mkLabel("Pet: " .. string.format("%.2f", DELAY_PET) .. "s", 4)
	mkAdj(3, function()
 DELAY_BASE = math.clamp(DELAY_BASE - 0.01, 0.01, 2)
 St._delayBase = DELAY_BASE
 LblBase.Text = "Base: " .. string.format("%.2f", DELAY_BASE) .. "s"
 saveCfg()
	end, function()
 DELAY_BASE = math.clamp(DELAY_BASE + 0.01, 0.01, 2)
 St._delayBase = DELAY_BASE
 LblBase.Text = "Base: " .. string.format("%.2f", DELAY_BASE) .. "s"
 saveCfg()
	end)
	mkAdj(4, function()
 DELAY_PET = math.clamp(DELAY_PET - 0.01, 0.01, 2)
 St._delayPet = DELAY_PET
 LblPet.Text = "Pet: " .. string.format("%.2f", DELAY_PET) .. "s"
 saveCfg()
	end, function()
 DELAY_PET = math.clamp(DELAY_PET + 0.01, 0.01, 2)
 St._delayPet = DELAY_PET
 LblPet.Text = "Pet: " .. string.format("%.2f", DELAY_PET) .. "s"
 saveCfg()
	end)

	local BtnKey = mkBtn("PHIM: [X]", 5, Color3.fromRGB(47, 47, 47))
	local settingKey = false
	BtnKey.MouseButton1Click:Connect(function()
 settingKey = true
 BtnKey.Text = "Press a key..."
	end)

	local BtnTP = Instance.new("TextButton", Main)
	BtnTP.Size = UDim2.new(1, -16, 0, 36)
	BtnTP.Position = UDim2.new(0, PAD, 1, -44)
	BtnTP.BackgroundColor3 = Color3.fromRGB(124, 124, 124)
	BtnTP.Text = "TP [X]"
	BtnTP.TextColor3 = Color3.new(1,1,1)
	BtnTP.Font = Enum.Font.GothamBlack
	BtnTP.TextSize = 14
	Instance.new("UICorner", BtnTP).CornerRadius = UDim.new(0, 10)

	if MINIMIZE then
 Main.Size = UDim2.new(0, 180, 0, 82)
 BtnTP.Position = UDim2.new(0, PAD, 0, 38)
 body.Visible = false
	end

	BtnSaveBase.MouseButton1Click:Connect(function()
 local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
 if not h then return end
 SAVE_BASE = h.Position
 St._saveBase = {SAVE_BASE.X, SAVE_BASE.Y, SAVE_BASE.Z}
 clearMark(MARK_BASE)
 MARK_BASE = Marker(SAVE_BASE, Color3.fromRGB(255, 105, 180))
 saveCfg()
 BtnSaveBase.Text = "Base saved"
 task.delay(0.7, function() BtnSaveBase.Text = "Save Base" end)
	end)
	BtnSavePet.MouseButton1Click:Connect(function()
 local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
 if not h then return end
 SAVE_PET = h.Position
 St._savePet = {SAVE_PET.X, SAVE_PET.Y, SAVE_PET.Z}
 clearMark(MARK_PET)
 MARK_PET = Marker(SAVE_PET, Color3.fromRGB(255, 140, 0))
 saveCfg()
 BtnSavePet.Text = "Pet saved"
 task.delay(0.7, function() BtnSavePet.Text = "Save Pet" end)
	end)

	local function StartTP()
 if IS_TPING or settingKey then return end
 -- re-read from St in case table updated
 SAVE_BASE = toVec(St._saveBase) or SAVE_BASE
 SAVE_PET = toVec(St._savePet) or SAVE_PET
 task.spawn(function()
 local C0 = LP.Character
 local HRP = C0 and C0:FindFirstChild("HumanoidRootPart")
 if not HRP then
 BtnTP.Text = "No character"
 task.wait(0.8)
 BtnTP.Text = "TP [" .. KEYBIND_TP.Name .. "]"
 return
 end
 if not SAVE_BASE and not SAVE_PET then
 BtnTP.Text = "No saved point"
 task.wait(0.9)
 BtnTP.Text = "TP [" .. KEYBIND_TP.Name .. "]"
 return
 end
 IS_TPING = true
 BtnTP.Text = "Teleporting..."
 local ok, err = pcall(function()
 if (SAVE_BASE and not SAVE_PET) or (SAVE_PET and not SAVE_BASE) then
 ChilliDrop(HRP, SAVE_BASE or SAVE_PET, C0)
 else
 EquipFly(C0)
 SmoothTP(HRP, SAVE_BASE)
 task.wait(tonumber(DELAY_BASE) or 0.15)
 C0 = LP.Character or C0
 HRP = C0 and C0:FindFirstChild("HumanoidRootPart") or HRP
 if HRP and SAVE_PET then SmoothTP(HRP, SAVE_PET) end
 end
 end)
 if not ok then
 warn("[TP] error:", err)
 BtnTP.Text = "TP error"
 task.wait(0.8)
 end
 IS_TPING = false
 BtnTP.Text = "TP [" .. KEYBIND_TP.Name .. "]"
 end)
	end
	BtnTP.MouseButton1Click:Connect(StartTP)

	LockBtn.MouseButton1Click:Connect(function()
 panelLocked = not panelLocked
 LockBtn.Text = panelLocked and "LOCK" or "UNLOCK"
 LockBtn.BackgroundColor3 = panelLocked and Color3.fromRGB(85, 85, 85) or Color3.fromRGB(33, 33, 33)
 saveCfg()
	end)
	CloseBtn.MouseButton1Click:Connect(function()
 MINIMIZE = not MINIMIZE
 St._tpMinimized = MINIMIZE
 body.Visible = not MINIMIZE
 if MINIMIZE then
 Main.Size = UDim2.new(0, 180, 0, 82)
 BtnTP.Position = UDim2.new(0, PAD, 0, 38)
 CloseBtn.Text = "+"
 else
 Main.Size = UDim2.new(0, 210, 0, 268)
 BtnTP.Position = UDim2.new(0, PAD, 1, -44)
 CloseBtn.Text = "−"
 end
 saveCfg()
	end)

	do
 local dragging, dragStart, startPos
 Main.InputBegan:Connect(function(input)
 if panelLocked then return end
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 dragging = true
 dragStart = input.Position
 startPos = Main.Position
 input.Changed:Connect(function()
 if input.UserInputState == Enum.UserInputState.End then
 dragging = false
 St._tpMainPos = {Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset}
 saveCfg()
 end
 end)
 end
 end)
 UIS.InputChanged:Connect(function(input)
 if not dragging or panelLocked then return end
 if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
 local d = input.Position - dragStart
 Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
 end
 end)
	end

	UIS.InputBegan:Connect(function(input, gp)
 if gp then return end
 if settingKey and input.UserInputType == Enum.UserInputType.Keyboard then
 KEYBIND_TP = input.KeyCode
 St._keyTP = KEYBIND_TP.Name
 settingKey = false
 BtnKey.Text = "PHIM: [" .. KEYBIND_TP.Name .. "]"
 BtnTP.Text = "TP [" .. KEYBIND_TP.Name .. "]"
 saveCfg()
 return
 end
 if input.KeyCode == KEYBIND_TP then StartTP() end
	end)

	print("[MERIDIAN] Compact TP panel ready | rainbow | markers | key X")
end)

-- ============================================================
-- STEAL BAR only (RARA style) — NO external Auto Steal GUI
-- Shown when Auto Steal is ON | draggable | resizable
-- ============================================================
task.spawn(function()
	-- kill external auto-steal panels from embedded script
	-- Only removes VIS's own auto-steal panel (duplicate), does NOT destroy other scripts' steal bars (lkz…)
	local function killStealGuis()
 pcall(function()
 local parents = {PlayerGui}
 pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
 pcall(function() if gethui then table.insert(parents, gethui()) end end)
 local own = {
 visautostealgui = true,
 visautosteal = true,
 aceautosteal = true,
 vis_auto_steal = true,
 }
 for _, parent in ipairs(parents) do
 for _, g in ipairs(parent:GetChildren()) do
 local n = (g.Name or ""):lower():gsub("%s+", "")
 -- keep MeridianStealBarOnly + other scripts' bars
 if n == "visstealbaronly" then
 -- keep
 elseif own[n] or n:find("visautosteal", 1, true) then
 pcall(function() g:Destroy() end)
 end
 end
 end
 end)
	end
	killStealGuis()
	-- no 0.5s destroy loop (avoids touching lkz's bar) — clean only once at load

	pcall(function()
 local o = PlayerGui:FindFirstChild("MeridianStealBarOnly")
 if o then o:Destroy() end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MeridianStealBarOnly"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = PlayerGui

	-- Dice-style steal bar (220x46 card, dot, state, FPS/ping, thin track)
	local ACC, ACC_DARK = Color3.fromRGB(240, 240, 246), Color3.fromRGB(110, 112, 126)
	local BASE_SCALE = 0.82
	local frame = Instance.new("Frame")
	frame.Name = "StealBar"
	frame.Size = UDim2.new(0, 220, 0, 46)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	if type(St._sbPos) == "table" then
 frame.Position = UDim2.new(St._sbPos[1], St._sbPos[2], St._sbPos[3], St._sbPos[4])
	else
 frame.Position = UDim2.new(0.5, 0, 0.86, 0)
	end
	frame.BackgroundColor3 = Color3.fromRGB(9, 9, 15)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.ZIndex = 20
	frame.ClipsDescendants = true
	frame.Active = true
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	local uiScale = Instance.new("UIScale", frame)
	uiScale.Scale = BASE_SCALE * math.clamp(tonumber(St.stealBarScale) or 1, 0.5, 2.5)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(48, 50, 64)
	stroke.Thickness = 1.2
	local bgGrad = Instance.new("UIGradient", frame)
	bgGrad.Color = ColorSequence.new({
 ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 17, 25)),
 ColorSequenceKeypoint.new(0.55, Color3.fromRGB(9, 9, 15)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 10)),
	})
	bgGrad.Rotation = 18

	local function mkLbl(name, size, pos, text, color, font, ts, align)
 local l = Instance.new("TextLabel")
 l.Name = name; l.Size = size; l.Position = pos
 l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = color
 l.Font = font; l.TextSize = ts; l.TextXAlignment = align; l.ZIndex = 22
 l.Parent = frame
 return l
	end

	local side = Instance.new("Frame", frame)
	side.Size = UDim2.new(0, 2, 0, 24); side.Position = UDim2.new(0, 0, 0.5, -12)
	side.BackgroundColor3 = ACC; side.BorderSizePixel = 0; side.ZIndex = 22
	Instance.new("UICorner", side).CornerRadius = UDim.new(0, 2)

	local dot = Instance.new("Frame", frame)
	dot.Size = UDim2.new(0, 6, 0, 6); dot.Position = UDim2.new(0, 12, 0, 11)
	dot.BackgroundColor3 = Color3.fromRGB(55, 58, 75); dot.BorderSizePixel = 0; dot.ZIndex = 22
	Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 4)

	mkLbl("Title", UDim2.new(0, 105, 0, 16), UDim2.new(0, 24, 0, 5), "AUTO STEAL",
 Color3.fromRGB(226, 230, 242), Enum.Font.GothamBold, 10, Enum.TextXAlignment.Left)
	local stateLbl = mkLbl("State", UDim2.new(0, 70, 0, 12), UDim2.new(0, 12, 0, 22), "OFF",
 Color3.fromRGB(104, 108, 126), Enum.Font.GothamBold, 8, Enum.TextXAlignment.Left)
	local perfLbl = mkLbl("Perf", UDim2.new(0, 92, 0, 12), UDim2.new(0, 66, 0, 22), "FPS --  /  --ms",
 Color3.fromRGB(128, 132, 150), Enum.Font.GothamBold, 8, Enum.TextXAlignment.Center)
	local pctLbl = mkLbl("Pct", UDim2.new(0, 42, 0, 14), UDim2.new(1, -50, 0, 21), "0%",
 ACC, Enum.Font.GothamBlack, 10, Enum.TextXAlignment.Right)

	local track = Instance.new("Frame", frame)
	track.Name = "Track"
	track.Size = UDim2.new(1, -24, 0, 4); track.Position = UDim2.new(0, 12, 1, -8)
	track.BackgroundColor3 = Color3.fromRGB(22, 22, 34); track.BorderSizePixel = 0; track.ZIndex = 21
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)
	local fill = Instance.new("Frame", track)
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = ACC; fill.BorderSizePixel = 0; fill.ZIndex = 22
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
	local fillGrad = Instance.new("UIGradient", fill)
	fillGrad.Color = ColorSequence.new({
 ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 152, 165)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 245, 250)),
	})

	-- size editor hook (Settings > Progress Bar Size)
	_G.MeridianApplyStealBarScale = function()
 St.stealBarScale = math.clamp(tonumber(St.stealBarScale) or 1, 0.5, 2.5)
 uiScale.Scale = BASE_SCALE * St.stealBarScale
	end

	-- FPS / ping
	task.spawn(function()
 local frames, t0, fps, ping = 0, tick(), 60, 0
 while gui and gui.Parent do
 frames = frames + 1
 local dt = tick() - t0
 if dt >= 0.5 then
 fps = math.floor(frames / dt + 0.5)
 frames, t0 = 0, tick()
 local gotPing = false
 pcall(function()
 local dp = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
 if typeof(dp) == "number" and dp > 0 then ping = math.floor(dp + 0.5); gotPing = true end
 end)
 if not gotPing then
 pcall(function()
 local pv = LP:GetNetworkPing()
 if typeof(pv) == "number" then ping = math.floor(pv * 1000 + 0.5) end
 end)
 end
 perfLbl.Text = "FPS " .. tostring(fps) .. "  /  " .. tostring(ping) .. "ms"
 end
 task.wait()
 end
	end)

	-- drag
	do
 local dragging, dragStart, startPos
 frame.InputBegan:Connect(function(input)
 if St.guiLock then return end
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
 dragging = true
 dragStart = input.Position
 startPos = frame.Position
 input.Changed:Connect(function()
 if input.UserInputState == Enum.UserInputState.End then
 dragging = false
 St._sbPos = {frame.Position.X.Scale, frame.Position.X.Offset, frame.Position.Y.Scale, frame.Position.Y.Offset}
 saveCfg()
 end
 end)
 end
 end)
 UIS.InputChanged:Connect(function(input)
 if not dragging or St.guiLock then return end
 if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
 local d = input.Position - dragStart
 frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
 end
 end)
	end

	-- fill behavior: 0 -> 100% over HalfHoldMin, 100% for 0.3s once done, then eased drain
	local lastPct, VISUAL_SPEED, DECAY_SPEED = 0, 0.35, 1.5
	if _G._MeridianStealBarConn then pcall(function() _G._MeridianStealBarConn:Disconnect() end) end
	_G._MeridianStealBarConn = RS.RenderStepped:Connect(function(dt)
 local S = ZenStealState
 local cfg = _G.AutoSteal
 local on = St.autoSteal == true
 local stealing = S and S.isStealing == true
 local target = 0
 if stealing and S.startTime then
 if S.completed then
 local since = tick() - (S.endTime or tick())
 if since < 0.3 then
 target = 1
 else
 target = math.max(0, 1 - (since - 0.3) * DECAY_SPEED)
 end
 else
 target = math.clamp((tick() - S.startTime) / math.max((cfg and cfg.HalfHoldMin) or 1.3, 0.01), 0, 1)
 end
 end
 lastPct = lastPct + (target - lastPct) * math.min(dt * VISUAL_SPEED * 60, 1)
 local f = math.clamp(lastPct, 0, 1)
 fill.Size = UDim2.new(f, 0, 1, 0)
 pctLbl.Text = tostring(math.floor(f * 100)) .. "%"
 if stealing then stateLbl.Text = "STEALING"
 elseif on then stateLbl.Text = "SEARCHING"
 else stateLbl.Text = "OFF" end
 stateLbl.TextColor3 = stealing and ACC or Color3.fromRGB(104, 108, 126)
 dot.BackgroundColor3 = stealing and ACC or Color3.fromRGB(55, 58, 75)
 stroke.Color = stealing and ACC_DARK or Color3.fromRGB(38, 40, 52)
	end)

end)
