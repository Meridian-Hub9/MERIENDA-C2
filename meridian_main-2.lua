if _G.MeridianHubRunning then return end
_G.MeridianHubRunning = true

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HS = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================
-- CACHÉ LOCAL DE SERVICIOS Y FUNCIONES (hot paths)
-- ============================================================
local _tick          = tick
local _clamp         = math.clamp
local _floor         = math.floor
local _huge          = math.huge
local _sqrt          = math.sqrt
local _V3new         = Vector3.new
local _V3zero        = Vector3.zero
local _CFnew         = CFrame.new
local _CFlookAt      = CFrame.lookAt

local _GetPlayersCached
do
    local cache, cacheTime = nil, 0
    _GetPlayersCached = function()
        local now = _tick()
        if cache and now - cacheTime < 0.03 then return cache end
        cache = Players:GetPlayers()
        cacheTime = now
        return cache
    end
end

local function waitForCharReady(char, timeout)
    timeout = timeout or 5
    local deadline = _tick() + timeout
    while (not char) or (not char.Parent)
          or (not char:FindFirstChild("HumanoidRootPart"))
          or (not char:FindFirstChildOfClass("Humanoid")) do
        if _tick() > deadline then return false end
        task.wait(0.05)
    end
    return true
end

NS = 60
CS = 29
LAGGER_SPEED = 15
LAGGER_CARRY_SPEED = 24.5
MEDUSA_COOLDOWN = 25
BAT_AIMBOT_SPEED    = 58
LAGGER_AIMBOT_SPEED = 58

-- Auto speed: Lagger Aimbot Spd while Lagger / Lagger Carry is on, else Bat Aimbot Speed
function getAimbotSpeed()
    if laggerToggled or laggerCarryToggled then return LAGGER_AIMBOT_SPEED end
    local wasLagger = _G._AdaptAutoCarryWasLagger
    if wasLagger and wasLagger() then return LAGGER_AIMBOT_SPEED end
    return BAT_AIMBOT_SPEED
end
CONFIG_FILE = "MeridianHub.json"
_isDraggingButton = false

backgroundIndex = 0
backgroundImages = {"99555977825356", "89784309464164", "138550322570942", "87012219126399", "123172079672908", "136020876423499", "115963355153377", "123836362734324", "97540240979096", "139659785448167", "73211468627724", "99803890852075", "122260603259941", "127365118869203", "130033760149642"}

backgroundImageTransparency = 0
floatingButtonScale = 1
_floatingUIScales = {}

local COLOR_THEMES = {
    ["Gray"]     = Color3.fromRGB(180, 180, 190),
    ["Purple"]   = Color3.fromRGB(160, 100, 220),
    ["Blue"]     = Color3.fromRGB(80, 150, 255),
    ["Pink"]   = Color3.fromRGB(255, 120, 180),
    ["Green"]    = Color3.fromRGB(80, 220, 120),
    ["Vanilla"] = Color3.fromRGB(212, 180, 135),
    ["Black"]    = Color3.fromRGB(70, 75, 90),
    ["Violet"]  = Color3.fromRGB(140, 0, 255),
    ["Red"]     = Color3.fromRGB(225, 45, 45),
    ["Cyan"]     = Color3.fromRGB(0, 210, 255),
    ["Orange"]  = Color3.fromRGB(255, 115, 25),
    ["Gold"]   = Color3.fromRGB(255, 200, 0),
}

currentColorTheme = "Gray"
selectedColor = COLOR_THEMES["Gray"]

function getThemeColor() return selectedColor end

local _lastThemeUpdate = 0
local _lastThemeColor = nil

function applyColorTheme(themeName)
    local color = COLOR_THEMES[themeName]
    if not color then return end
    currentColorTheme = themeName
    selectedColor = color
    updateAllUIThemeColors(color)
    saveAllSettings()
end

function updateAllUIThemeColors(color)
    local now = _tick()
    if color == _lastThemeColor and now - _lastThemeUpdate < 0.1 then return end
    _lastThemeUpdate = now
    _lastThemeColor = color

    if progressFill then
        progressFill.BackgroundColor3 = color
        local grad = progressFill:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, color),
                ColorSequenceKeypoint.new(0.50, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1.00, color),
            })
        end
    end
    if pbFrame then
        local border = pbFrame:FindFirstChildOfClass("UIStroke")
        if border then border.Color = color end
        local fpsNeon = pbFrame:FindFirstChild("FPSNeon")
        if fpsNeon then fpsNeon.TextColor3 = color end
    end
    local function searchAndUpdateText(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("TextLabel") then
                if child.Text:find("Spd:") or child.Text:find("Speed:") or child.Name == "MeridianHubSpeedIndicator" or child.Text:find("FPS") then
                    child.TextColor3 = color
                end
            end
            if child:IsA("UIStroke") then
                if child.Color == Color3.fromRGB(180, 180, 190) then child.Color = color end
            end
        end
    end
    if gui then searchAndUpdateText(gui) end
    -- Speed label lives in char.Head BillboardGui, outside gui — update directly
    if speedLabel and speedLabel.Parent then
        speedLabel.TextColor3 = color
        local grad = speedLabel:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, color),
                ColorSequenceKeypoint.new(0.3, Color3.fromRGB(200,200,200)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(0.7, Color3.fromRGB(200,200,200)),
                ColorSequenceKeypoint.new(1, color),
            })
        end
    end
    -- Re-color active toggle pills live (on-state pills hold old theme color until restart)
    if gui then
        for _, child in ipairs(gui:GetDescendants()) do
            if child:IsA("Frame") and child.Name == "Track" and child.BackgroundTransparency < 0.05 then
                child.BackgroundColor3 = Color3.new(1, 1, 1)
                local grad = child:FindFirstChildOfClass("UIGradient")
                if not grad then
                    grad = Instance.new("UIGradient", child)
                    grad.Rotation = 90
                end
                grad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1,1,1), 0.40)),
                    ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0,0,0), 0.25)),
                })
                grad.Enabled = true
                local stroke = child:FindFirstChildOfClass("UIStroke")
                if stroke and stroke.Transparency < 0.3 then
                    stroke.Color = color
                end
            end
        end
    end
    if tpBatFloatingButton then
        paintFloatingBtn(tpBatFloatingButton:FindFirstChild("Frame"), batDesyncTpEnabled)
    end
    if batV2FloatingButton then
        paintFloatingBtn(batV2FloatingButton:FindFirstChild("Frame"), isAimbotEnabled())
    end
    if avatarStrokeRef and avatarStrokeRef.Parent then
        avatarStrokeRef.Color = color
    end
    for _, tab in ipairs(tabButtons or {}) do
        if tab.TextColor3 == Color3.fromRGB(180, 180, 190) then tab.TextColor3 = color end
    end
    for _, hl in pairs(espHighlightCache) do
        if hl then hl.FillColor = color; hl.OutlineColor = color end
    end
    for _, lines in pairs(espTracerCache) do
        if lines then
            for _, ln in ipairs(lines) do
                if ln then ln.Color = color end
            end
        end
    end
    for _, bb in pairs(espBillboardCache) do
        if bb then
            local img = bb:FindFirstChildOfClass("ImageLabel")
            if img then
                local stroke = img:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = color end
            end
        end
    end
    if main then
        local titleFrame = main:FindFirstChild("Frame")
        if titleFrame then
            for _, child in ipairs(titleFrame:GetDescendants()) do
                if child:IsA("UIStroke") and child.Color == Color3.fromRGB(180, 180, 190) then
                    child.Color = color
                end
            end
        end
    end
    if colorSelectorLabel then
        colorSelectorLabel.Text = currentColorTheme
        colorSelectorLabel.TextColor3 = color
    end
    -- Update all mkLabel gradient text effects
    if gui then
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj.Name == "LabelThemeGrad" and obj:IsA("UIGradient") then
                obj.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0,    color),
                    ColorSequenceKeypoint.new(0.35, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(0.65, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1,    color),
                })
            end
        end
    end
    if miniBtn then
        miniBtn.TextColor3 = color
        local grad = miniBtn:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, color),
                ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, color),
            })
        end
    end

    local pGui = LP:FindFirstChild("PlayerGui")
    if pGui then
        local bb = pGui:FindFirstChild("RagCountdownBillboard")
        if bb then
            local lbl = bb:FindFirstChildOfClass("TextLabel")
            if lbl then
                lbl.TextColor3 = color
                local grad = lbl:FindFirstChildOfClass("UIGradient")
                if grad then
                    grad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, color),
                        ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(1, color),
                    })
                end
            end
        end
    end

    if MobilePanel then
        for _, btn in ipairs(MobilePanel:GetChildren()) do
            if btn:IsA("TextButton") and btn:FindFirstChild("BtnGrad") then
                paintFloatingBtn(btn, btn:GetAttribute("MobActive") == true)
            end
        end
    end
end

local HOMERO_CFG = {
    body = { 10725826963, 86500008, 86500054, 86500036, 86500064, 86500078 },
    aplicarCuerpo = true,
    items = {
        { id = 103227869700418, offset = _CFnew(0,0,0) },
        { id = 84952305140948,   offset = _CFnew(0,0,0) },
        { id = 122465238537030,  offset = _CFnew(0,0,0) },
    },
    shirt = nil,
    pants = "rbxassetid://78591690208112",
    skinColor = Color3.fromRGB(234,184,146),
    headColor = Color3.fromRGB(0,0,0),
}

local TAG = "LocalOutfit_"

local function loadObjects(id)
    local ok, res = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if ok and typeof(res) == "table" and #res > 0 then return res end
    ok, res = pcall(function()
        return game:GetService("InsertService"):LoadAsset(id)
    end)
    if ok and res then return { res } end
    return nil
end

local function collectParts(objs)
    local out = {}
    for _, o in ipairs(objs) do
        if o:IsA("BasePart") then out[#out + 1] = o end
        for _, d in ipairs(o:GetDescendants()) do
            if d:IsA("BasePart") then out[#out + 1] = d end
        end
    end
    return out
end

local function findAtt(char, name)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("Attachment") and p.Name == name and p.Parent:IsA("BasePart") then
            return p
        end
    end
end

local function applyBody(char)
    local total = 0
    for _, id in ipairs(HOMERO_CFG.body) do
        local objs = loadObjects(id)
        if objs then
            for _, mp in ipairs(collectParts(objs)) do
                local orig = char:FindFirstChild(mp.Name)
                if orig and orig:IsA("BasePart") then
                    local c = mp:Clone()
                    c.Name = TAG .. "body_" .. mp.Name
                    c.CanCollide = false
                    c.Anchored = false
                    c.Massless = true
                    c.Size = orig.Size
                    c.CFrame = orig.CFrame
                    c.Parent = char
                    local w = Instance.new("WeldConstraint")
                    w.Part0 = orig
                    w.Part1 = c
                    w.Parent = c
                    orig.Transparency = 1
                    total = total + 1
                end
            end
            for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        end
    end
    return total
end

local function attachItem(char, entry)
    local objs = loadObjects(entry.id)
    if not objs then return false end

    local handle
    for _, p in ipairs(collectParts(objs)) do
        if p.Name == "Handle" then handle = p; break end
        if not handle then handle = p end
    end
    if not handle then
        for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        return false
    end

    local H = handle:Clone()
    for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end

    H.Name = TAG .. "item_" .. tostring(entry.id)
    H.CanCollide = false
    H.Anchored = false
    H.Massless = true

    local wrap = H:FindFirstChildWhichIsA("WrapLayer")
    local target, c0, c1

    if wrap then
        target = char:FindFirstChild("UpperTorso")
              or char:FindFirstChild("Torso")
              or char:FindFirstChild("HumanoidRootPart")
        c0 = entry.offset or _CFnew()
        c1 = _CFnew()
    else
        local hAtt = H:FindFirstChildOfClass("Attachment")
        local bAtt = hAtt and findAtt(char, hAtt.Name)
        if bAtt then
            target = bAtt.Parent
            c0 = bAtt.CFrame * (entry.offset or _CFnew())
            c1 = hAtt.CFrame
        else
            target = char:FindFirstChild("Head")
            c0 = entry.offset or _CFnew(0, 1.4, 0)
            c1 = _CFnew()
        end
    end

    if not target then H:Destroy(); return false end

    H.CFrame = target.CFrame * c0 * c1:Inverse()
    H.Parent = char

    local w = Instance.new("Weld")
    w.Part0 = target
    w.Part1 = H
    w.C0 = c0
    w.C1 = c1
    w.Parent = H
    return true
end

function applyHomeroOutfit(char)
    if not char then char = LP.Character end
    if not char then return end
    char:WaitForChild("Humanoid", 10)
    char:WaitForChild("Head", 10)
    task.wait(0.4)

    for _, d in ipairs(char:GetChildren()) do
        if d.Name:sub(1, #TAG) == TAG then pcall(function() d:Destroy() end) end
    end

    if HOMERO_CFG.skinColor then
        local bc = char:FindFirstChildWhichIsA("BodyColors") or Instance.new("BodyColors")
        bc.HeadColor3 = HOMERO_CFG.headColor or HOMERO_CFG.skinColor
        bc.TorsoColor3 = HOMERO_CFG.skinColor
        bc.LeftArmColor3, bc.RightArmColor3 = HOMERO_CFG.skinColor, HOMERO_CFG.skinColor
        bc.LeftLegColor3, bc.RightLegColor3 = HOMERO_CFG.skinColor, HOMERO_CFG.skinColor
        bc.Parent = char
    end

    for _, a in ipairs(char:GetChildren()) do
        if a:IsA("Accessory") then
            local h = a:FindFirstChild("Handle")
            if h then h.Transparency = 1 end
        end
    end

    if HOMERO_CFG.shirt then
        local s = char:FindFirstChildWhichIsA("Shirt") or Instance.new("Shirt")
        s.Name = "Shirt"
        s.ShirtTemplate = HOMERO_CFG.shirt
        s.Parent = char
    end
    if HOMERO_CFG.pants then
        local p = char:FindFirstChildWhichIsA("Pants") or Instance.new("Pants")
        p.Name = "Pants"
        p.PantsTemplate = HOMERO_CFG.pants
        p.Parent = char
    end
    if HOMERO_CFG.aplicarCuerpo then applyBody(char) end
    for _, e in ipairs(HOMERO_CFG.items) do attachItem(char, e) end
end

local function applyNoOutfit(char)
    if not char then char = LP.Character end
    if not char then return end
    for _, d in ipairs(char:GetChildren()) do
        if d.Name:sub(1, #TAG) == TAG then pcall(function() d:Destroy() end) end
    end
    local oldAcc = char:FindFirstChild("AuFfitAccessory")
    if oldAcc then pcall(function() oldAcc:Destroy() end) end
    local oldKorblox = char:FindFirstChild("Korblox_RightLeg")
    if oldKorblox then pcall(function() oldKorblox:Destroy() end) end
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("CharacterMesh") and d.BodyPart == Enum.BodyPart.Head then
            pcall(function() d:Destroy() end)
        end
    end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 0
        head.CanCollide = true
        head.LocalTransparencyModifier = 0
        local face = head:FindFirstChild("face")
        if face then face.Transparency = 0 end
        local sm = head:FindFirstChildWhichIsA("SpecialMesh")
        if sm then pcall(function() sm:Destroy() end) end
    end
    pcall(function()
        local neck = char:FindFirstChild("Neck")
        if neck then neck.Enabled = true end
    end)
    for _, partName in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
        local limb = char:FindFirstChild(partName)
        if limb then limb.Transparency = 0 end
    end
    local shirt = char:FindFirstChildWhichIsA("Shirt")
    if shirt then pcall(function() shirt:Destroy() end) end
    local pants = char:FindFirstChildWhichIsA("Pants")
    if pants then pcall(function() pants:Destroy() end) end
    for _, a in ipairs(char:GetChildren()) do
        if a:IsA("Accessory") then
            local h = a:FindFirstChild("Handle")
            if h then h.Transparency = 0 end
        end
    end
end

local OUTFITS = {
    {
        accessory = 10159600649,
        offset = _V3new(0, 1, -0.2),
        shirt = "http://www.roblox.com/asset/?id=9683332638",
        pants = "http://www.roblox.com/asset/?id=93182020184041",
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918 ",
        korblox = "none",
        label = "Outfit 1",
        headlessKorblox = true,
    },
    {
        accessory = 1744060292,
        offset = _V3new(0, 1.3, -0.2),
        shirt = "http://www.roblox.com/asset/?id=9683332638",
        pants = "http://www.roblox.com/asset/?id=93182020184041",
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918 ",
        korblox = "none",
        label = "Outfit 2",
        headlessKorblox = true,
    },
    {
        accessory = 8349240186,
        offset = _V3new(0, 0.9, 0),
        shirt = "http://www.roblox.com/asset/?id=11926549070",
        pants = "http://www.roblox.com/asset/?id=13189494471",
        headMesh = "https://assetdelivery.roblox.com/v1/asset/?id=16673245747",
        headTexture = nil,
        korblox = "none",
        label = "Outfit 3",
        headlessKorblox = true,
    },
    {
        accessory = 121097973925756,
        offset = _V3new(0, 0.9, 0),
        shirt = "http://www.roblox.com/asset/?id=123181702116947",
        pants = "http://www.roblox.com/asset/?id=93330291631062",
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918 ",
        korblox = "none",
        label = "Outfit 4",
        headlessKorblox = true,
    },
    {
        label = "Homero Chino",
        customApply = applyHomeroOutfit,
    },
    {
        label = "NO",
        customApply = applyNoOutfit,
    },
}
local currentOutfitIndex = 1
local outfitSelectorLabel = nil

local function applyHeadlessKorblox(char)
    if not char then return end
    pcall(function() LP.CharacterAvatarType = Enum.AvatarType.R6 end)
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        head.CanCollide = false
        head.LocalTransparencyModifier = 1
        local face = head:FindFirstChild("face")
        if face then face.Transparency = 1 end
    end
    pcall(function()
        local neck = char:FindFirstChild("Neck")
        if neck then neck.Enabled = false end
    end)
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local w = v:FindFirstChildWhichIsA("Weld") or v:FindFirstChildWhichIsA("WeldConstraint") or v:FindFirstChildWhichIsA("Motor6D")
            if w then
                local p0, p1 = w.Part0, w.Part1
                if (p0 and p0.Name == "Head") or (p1 and p1.Name == "Head") then
                    v.Parent = nil
                end
            end
        end
    end
    local rightLegConfig = {
        id = "rbxassetid://139607718",
        targetBodyPart = "RightUpperLeg",
        partsToHide = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
        scale = _V3new(1, 1, 1),
        offset = _CFnew(0, 0, 0)
    }
    local targetPart = char:FindFirstChild(rightLegConfig.targetBodyPart)
    if targetPart then
        local oldAsset = char:FindFirstChild("Korblox_RightLeg")
        if oldAsset then oldAsset:Destroy() end
        for _, partName in ipairs(rightLegConfig.partsToHide) do
            local limb = char:FindFirstChild(partName)
            if limb and limb:IsA("BasePart") then limb.Transparency = 1 end
        end
        local success, objects = pcall(function() return game:GetObjects(rightLegConfig.id) end)
        if success and objects and #objects > 0 then
            local assetModel = objects[1]
            assetModel.Name = "Korblox_RightLeg"
            local mainMesh = assetModel:IsA("BasePart") and assetModel or assetModel:FindFirstChildWhichIsA("BasePart", true)
            if mainMesh then
                mainMesh.Size = mainMesh.Size * rightLegConfig.scale
                mainMesh.CanCollide = false
                mainMesh.CFrame = targetPart.CFrame * rightLegConfig.offset
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = targetPart
                weld.Part1 = mainMesh
                weld.Parent = mainMesh
                assetModel.Parent = char
            end
        end
    end
end

function applyOutfitByIndex(index)
    local cfg = OUTFITS[index]
    if not cfg then return end
    local char = LP.Character
    if not char then return end

    if cfg.customApply then
        cfg.customApply(char)
        if outfitSelectorLabel then outfitSelectorLabel.Text = cfg.label end
        return
    end

    char:WaitForChild("Head", 5)
    local head = char:FindFirstChild("Head")
    if not head then return end
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("CharacterMesh") and d.BodyPart == Enum.BodyPart.Head then
            pcall(function() d:Destroy() end)
        end
    end
    local done = false
    if head:IsA("MeshPart") then
        done = pcall(function()
            head.MeshId = cfg.headMesh
            if cfg.headTexture then head.TextureID = cfg.headTexture end
        end)
    end
    if not done then
        local sm = head:FindFirstChildWhichIsA("SpecialMesh") or Instance.new("SpecialMesh")
        sm.Parent = head
        sm.MeshType = Enum.MeshType.FileMesh
        sm.MeshId = cfg.headMesh
        sm.TextureId = cfg.headTexture or ""
    end
    if cfg.shirt then
        local s = char:FindFirstChildWhichIsA("Shirt") or Instance.new("Shirt")
        s.Name = "Shirt"
        s.ShirtTemplate = cfg.shirt
        s.Parent = char
    end
    if cfg.pants then
        local p = char:FindFirstChildWhichIsA("Pants") or Instance.new("Pants")
        p.Name = "Pants"
        p.PantsTemplate = cfg.pants
        p.Parent = char
    end
    local old = char:FindFirstChild("AuFfitAccessory")
    if old then old:Destroy() end
    if cfg.accessory and head then
        local objs = loadObjects(cfg.accessory)
        if objs then
            local handle
            for _, o in ipairs(objs) do
                if o:IsA("BasePart") then handle = o; break end
                local f = o:FindFirstChildWhichIsA("BasePart", true)
                if f then handle = f; break end
            end
            if handle then
                local h = handle:Clone()
                h.Name = "AuFfitAccessory"
                h.CanCollide = false
                h.Anchored = false
                h.Massless = true
                h.Parent = char
                local weld = Instance.new("Weld")
                weld.Part0 = head
                weld.Part1 = h
                weld.C0 = _CFnew(cfg.offset)
                weld.Parent = h
            end
            for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        end
    end
    if cfg.headlessKorblox then
        applyHeadlessKorblox(char)
    else
        if char then
            local head2 = char:FindFirstChild("Head")
            if head2 then
                head2.Transparency = 0
                head2.CanCollide = true
                head2.LocalTransparencyModifier = 0
                local face2 = head2:FindFirstChild("face")
                if face2 then face2.Transparency = 0 end
            end
            pcall(function()
                local neck = char:FindFirstChild("Neck")
                if neck then neck.Enabled = true end
            end)
            for _, partName in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
                local limb = char:FindFirstChild(partName)
                if limb then limb.Transparency = 0 end
            end
            local oldKorblox = char:FindFirstChild("Korblox_RightLeg")
            if oldKorblox then oldKorblox:Destroy() end
        end
    end
    if outfitSelectorLabel then outfitSelectorLabel.Text = cfg.label end
end

speedMode = false
adaptAutoCarryEnabled = false
antiRagdollMode = "off"
antiDieEnabled = false
antiFlingEnabled = false
laggerToggled = false
laggerCarryToggled = false
medusaCounterEnabled = false
batCounterEnabled = false
unwalkEnabled = false
autoLeftEnabled = false
autoRightEnabled = false
autoBatEnabled = false
dropMode = 1
antiLagEnabled = false
stretchEnabled = false
stretchFOV = 120
uiLocked = true
editModeEnabled = false
uiScaleValue = 80
espEnabled = false

bodyLockEnabled = false
bodyLockRange = 20
bodyLockRangeBox = nil
_bodyLockConn = nil
_blSuppressCount = 0
_blWasEnabled = false
_blRestoreTimer = nil
_blSmoothRestore = false

savedProgressBarPos = nil
pbBarWidth = 400
pbBarHeight = 76
savedButtonPositions = {}
tpBatFloatingPos = nil
batV2FloatingPos = nil
instaResetFloatingPos = nil

neonWeatherEnabled = false
skyTheme = "Off"
skySelectorLabel = nil
batSkin = "Off"
medusaSkin = "Off"
batSkinLabel = nil
medusaSkinLabel = nil
_originalLighting = nil
setNeonWeatherVisual = nil

currentAnimPack = "Off"
originalTryardAnims = nil
tryardHeartbeatConn = nil

autoBatV2Enabled = false
_batV2Conn = nil

autoBatV3Enabled = false

-- State tables for the shared aimbot kernel (_akLoop) and V3's own loop.
-- Must be declared before CharacterAdded connects below so they're non-nil on first respawn.
_akV2 = { equipped=false, bypassPart=nil, bypassWeld=nil, target=nil, lastScan=0, hittingCD=false, hitCD2=false }
_akV3 = { equipped=false, bypassPart=nil, bypassWeld=nil, target=nil, lastScan=0, hittingCD=false, conn=nil }

-- Shift lock guard: undoes any camera/shift-lock rotation write while V1/V2/bypass is on,
-- so aimbot facing behaves the same with or without shift lock.
_aimSL = { rot = nil, gs = nil }
local function _aimSLActive()
    return autoBatEnabled or autoBatV2Enabled or autoBatV3Enabled
end
local function _aimSLLocked()
    if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then return true end
    if not _aimSL.gs then
        pcall(function() _aimSL.gs = UserSettings():GetService("UserGameSettings") end)
    end
    local gs = _aimSL.gs
    return gs ~= nil and gs.RotationType == Enum.RotationType.CameraRelative
end
pcall(function() RunService:UnbindFromRenderStep("MeridianAimSLPre") end)
pcall(function() RunService:UnbindFromRenderStep("MeridianAimSLPost") end)
RunService:BindToRenderStep("MeridianAimSLPre", Enum.RenderPriority.Character.Value - 1, function()
    if not _aimSLActive() then _aimSL.rot = nil; return end
    local c = LP.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    _aimSL.rot = r and r.CFrame.Rotation or nil
end)
RunService:BindToRenderStep("MeridianAimSLPost", Enum.RenderPriority.Character.Value + 2, function()
    if not _aimSL.rot or not _aimSLActive() or not _aimSLLocked() then return end
    local c = LP.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not r then return end
    if r.CFrame.LookVector:Dot(_aimSL.rot.LookVector) < 0.99999 then
        r.CFrame = CFrame.new(r.Position) * _aimSL.rot
    end
end)

lastMoveDir = _V3zero

local InfiniteJump = {
    enabled = false,
    jumpPower = 55,
    minVelocity = 30,
    jumpConn = nil,
    heartbeatConn = nil,
}

local function applyJump(root)
    if not root then return end
    pcall(function()
        root.Velocity = _V3new(root.Velocity.X, InfiniteJump.jumpPower, root.Velocity.Z)
    end)
end

local function onJumpRequest()
    if not InfiniteJump.enabled then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then applyJump(root) end
end

local function onHeartbeat()
    if not InfiniteJump.enabled then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local jumpHeld = UIS:IsKeyDown(Enum.KeyCode.Space) or (hum.Jump == true)
    if jumpHeld and root.Velocity.Y < InfiniteJump.minVelocity then
        applyJump(root)
    end
end

local function connectEvents()
    if InfiniteJump.jumpConn then InfiniteJump.jumpConn:Disconnect() end
    if InfiniteJump.heartbeatConn then InfiniteJump.heartbeatConn:Disconnect() end
    InfiniteJump.jumpConn = UIS.JumpRequest:Connect(onJumpRequest)
    InfiniteJump.heartbeatConn = RunService.Heartbeat:Connect(onHeartbeat)
end

function InfiniteJump.start()
    if InfiniteJump.enabled then return end
    InfiniteJump.enabled = true
    connectEvents()
end

function InfiniteJump.stop()
    InfiniteJump.enabled = false
    if InfiniteJump.jumpConn then InfiniteJump.jumpConn:Disconnect(); InfiniteJump.jumpConn = nil end
    if InfiniteJump.heartbeatConn then InfiniteJump.heartbeatConn:Disconnect(); InfiniteJump.heartbeatConn = nil end
end

function InfiniteJump.setJumpPower(power)
    power = tonumber(power) or 55
    InfiniteJump.jumpPower = _clamp(power, 10, 200)
end

function InfiniteJump.isRunning() return InfiniteJump.enabled == true end

InfiniteJump.start()

local _velChecked = {}
local _hookedVelParts = {}

local function _setupVelChecked(char)
    _velChecked = {}
    if not char then return end
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then _velChecked[hrp] = true end
    return hrp
end

local _hookVelSupported = nil
local function _hookVelHRP(hrp)
    if not hrp or _hookedVelParts[hrp] then return end
    if _hookVelSupported == false then return end
    if _hookVelSupported == nil then
        _hookVelSupported = (type(getrawmetatable) == "function")
            and (type(setreadonly) == "function")
            and (type(newcclosure) == "function")
            and (type(checkcaller) == "function")
    end
    if not _hookVelSupported then return end
    _hookedVelParts[hrp] = true
    local ok = pcall(function()
        local mt = getrawmetatable(hrp)
        if not mt then return end
        setreadonly(mt, false)
        local originalVelIndex = rawget(mt, "__index")
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and _velChecked[self]
               and (key == "AssemblyLinearVelocity" or key == "Velocity") then
                local real
                if type(originalVelIndex) == "function" then
                    real = originalVelIndex(self, key)
                elseif type(originalVelIndex) == "table" then
                    real = originalVelIndex[key]
                end
                if real and real.Magnitude > 20 then return real.Unit * 20 end
                return real
            end
            if type(originalVelIndex) == "function" then
                return originalVelIndex(self, key)
            elseif type(originalVelIndex) == "table" then
                return originalVelIndex[key]
            end
        end)
        setreadonly(mt, true)
    end)
    if not ok then _hookVelSupported = false end
end

if LP.Character then
    local _hrp0 = _setupVelChecked(LP.Character)
    _hookVelHRP(_hrp0)
end

local function _isRagdollState(hum)
    if not hum then return true end
    local st = hum:GetState()
    return hum.PlatformStand
        or st == Enum.HumanoidStateType.Physics
        or st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
end

local function _applyVelocitySpeed(dir, speed, hrp)
    if not hrp or not hrp.Parent then return end
    if autoBatV2Enabled or autoBatV3Enabled or batDesyncTpEnabled or autoBatEnabled then return end
    local lv = hrp:FindFirstChild("_MeridianSpeedLV")
    if not lv then
        local att = hrp:FindFirstChild("_MeridianSpeedAtt") or Instance.new("Attachment")
        att.Name = "_MeridianSpeedAtt"
        att.Parent = hrp
        lv = Instance.new("LinearVelocity")
        lv.Name = "_MeridianSpeedLV"
        lv.Attachment0 = att
        lv.RelativeTo = Enum.ActuatorRelativeTo.World
        lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
        lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
        lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
        lv.MaxForce = math.huge
        lv.Parent = hrp
    end
    lv.Enabled = true
    if dir and dir.Magnitude > 0.05 then
        local flat = Vector3.new(dir.X, 0, dir.Z).Unit
        lv.PlaneVelocity = Vector2.new(flat.X * speed, flat.Z * speed)
    else
        lv.PlaneVelocity = Vector2.zero
    end
end

function getAutoPathSpeed()
    if laggerCarryToggled or laggerToggled then return LAGGER_SPEED end
    return NS
end

function getActiveMoveSpeed()
    if laggerCarryToggled then return LAGGER_CARRY_SPEED
    elseif laggerToggled then return LAGGER_SPEED
    elseif speedMode then return CS
    else return NS end
end

ANIM_PACKS = {
    ["Zombie"] = { idle1="rbxassetid://616158929", idle2="rbxassetid://616160636", walk="rbxassetid://616168032", run="rbxassetid://616163682", jump="rbxassetid://616161997", fall="rbxassetid://616157476", climb="rbxassetid://616156119", swim="rbxassetid://616165109", swimidle="rbxassetid://616166655" },
    ["Ninja"] = { idle1="rbxassetid://656117400", idle2="rbxassetid://656117400", walk="rbxassetid://656121766", run="rbxassetid://656118852", jump="rbxassetid://656117878", fall="rbxassetid://656115606", climb="rbxassetid://656114359", swim="rbxassetid://656117400", swimidle="rbxassetid://656117400" },
    ["Knight"] = { idle1="rbxassetid://657595757", idle2="rbxassetid://657595757", walk="rbxassetid://657552124", run="rbxassetid://657564596", jump="rbxassetid://658409194", fall="rbxassetid://657600338", climb="rbxassetid://658360781", swim="rbxassetid://657595757", swimidle="rbxassetid://657595757" },
    ["Elder"] = { idle1="rbxassetid://845397899", idle2="rbxassetid://845397899", walk="rbxassetid://845403856", run="rbxassetid://845386501", jump="rbxassetid://845398858", fall="rbxassetid://845397673", climb="rbxassetid://845392038", swim="rbxassetid://845397899", swimidle="rbxassetid://845397899" },
    ["Levitate"] = { idle1="rbxassetid://616006778", idle2="rbxassetid://616006778", walk="rbxassetid://616013216", run="rbxassetid://616013216", jump="rbxassetid://616008936", fall="rbxassetid://616005863", climb="rbxassetid://616003713", swim="rbxassetid://616006778", swimidle="rbxassetid://616006778" },
    ["Astronaut"] = { idle1="rbxassetid://891621366", idle2="rbxassetid://891621366", walk="rbxassetid://891636393", run="rbxassetid://891636393", jump="rbxassetid://891627522", fall="rbxassetid://891617961", climb="rbxassetid://891609353", swim="rbxassetid://891621366", swimidle="rbxassetid://891621366" },
    ["Pirate"] = { idle1="rbxassetid://750781874", idle2="rbxassetid://750781874", walk="rbxassetid://750785693", run="rbxassetid://750783738", jump="rbxassetid://750782230", fall="rbxassetid://750780242", climb="rbxassetid://750779899", swim="rbxassetid://750781874", swimidle="rbxassetid://750781874" },
    ["Toy"] = { idle1="rbxassetid://782841498", idle2="rbxassetid://782841498", walk="rbxassetid://782843345", run="rbxassetid://782842708", jump="rbxassetid://782847020", fall="rbxassetid://782846423", climb="rbxassetid://782843869", swim="rbxassetid://782841498", swimidle="rbxassetid://782841498" },
    ["Vampire"] = { idle1="rbxassetid://1083445855", idle2="rbxassetid://1083445855", walk="rbxassetid://1083473930", run="rbxassetid://1083462077", jump="rbxassetid://1083455352", fall="rbxassetid://1083443587", climb="rbxassetid://1083439238", swim="rbxassetid://1083445855", swimidle="rbxassetid://1083445855" },
    ["Werewolf"] = { idle1="rbxassetid://1083195517", idle2="rbxassetid://1083195517", walk="rbxassetid://1083178339", run="rbxassetid://1083216690", jump="rbxassetid://1083218792", fall="rbxassetid://1083189019", climb="rbxassetid://1083182000", swim="rbxassetid://1083195517", swimidle="rbxassetid://1083195517" },
    ["Rthro"] = { idle1="rbxassetid://2510196951", idle2="rbxassetid://2510196951", walk="rbxassetid://2510202577", run="rbxassetid://2510198475", jump="rbxassetid://2510197830", fall="rbxassetid://2510195892", climb="rbxassetid://2510192778", swim="rbxassetid://2510196951", swimidle="rbxassetid://2510196951" },
    ["Stylish"] = { idle1="rbxassetid://616136790", idle2="rbxassetid://616136790", walk="rbxassetid://616146177", run="rbxassetid://616140816", jump="rbxassetid://616139451", fall="rbxassetid://616134815", climb="rbxassetid://616133594", swim="rbxassetid://616136790", swimidle="rbxassetid://616136790" },
}

ANIM_PACK_ORDER = {{"Off", "Off"}, {"Zombie", "Zombie"}, {"Ninja", "Ninja"}, {"Knight", "Knight"}, {"Elder", "Elder"}, {"Levitate", "Levitate"}, {"Astronaut", "Astronaut"}, {"Pirate", "Pirate"}, {"Toy", "Toy"}, {"Vampire", "Vampire"}, {"Werewolf", "Werewolf"}, {"Rthro", "Rthro"}, {"Stylish", "Stylish"}}

local function isPackAnim(id)
    for _, pack in pairs(ANIM_PACKS) do
        for _, v in pairs(pack) do
            if v == id then return true end
        end
    end
    return false
end

local function saveOriginalAnims(char)
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    local function g(obj) return obj and obj.AnimationId or nil end
    local ids = {
        idle1 = g(animate.idle and animate.idle.Animation1),
        idle2 = g(animate.idle and animate.idle.Animation2),
        walk  = g(animate.walk and animate.walk.WalkAnim),
        run   = g(animate.run  and animate.run.RunAnim),
        jump  = g(animate.jump and animate.jump.JumpAnim),
        fall  = g(animate.fall and animate.fall.FallAnim),
        climb = g(animate.climb and animate.climb.ClimbAnim),
        swim  = g(animate.swim and animate.swim.Swim),
        swimidle = g(animate.swimidle and animate.swimidle.SwimIdle),
    }
    if not isPackAnim(ids.walk) then originalTryardAnims = ids end
end

local function applyAnimPack(packName)
    currentAnimPack = packName
    if animSelectorLabel then animSelectorLabel.Text = packName end
    if packName == "Off" then
        if originalTryardAnims and LP.Character then
            local animate = LP.Character:FindFirstChild("Animate")
            if animate then
                local function s(obj,id) if obj then obj.AnimationId = id end end
                s(animate.idle and animate.idle.Animation1, originalTryardAnims.idle1)
                s(animate.idle and animate.idle.Animation2, originalTryardAnims.idle2)
                s(animate.walk and animate.walk.WalkAnim, originalTryardAnims.walk)
                s(animate.run  and animate.run.RunAnim,   originalTryardAnims.run)
                s(animate.jump and animate.jump.JumpAnim, originalTryardAnims.jump)
                s(animate.fall and animate.fall.FallAnim, originalTryardAnims.fall)
                s(animate.climb and animate.climb.ClimbAnim, originalTryardAnims.climb)
                s(animate.swim and animate.swim.Swim, originalTryardAnims.swim)
                s(animate.swimidle and animate.swimidle.SwimIdle, originalTryardAnims.swimidle)
            end
        end
        if tryardHeartbeatConn then tryardHeartbeatConn:Disconnect(); tryardHeartbeatConn = nil end
        return
    end
    local pack = ANIM_PACKS[packName]
    if not pack then return end
    if tryardHeartbeatConn then tryardHeartbeatConn:Disconnect() end
    tryardHeartbeatConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character
        if not c then return end
        local animate = c:FindFirstChild("Animate")
        if not animate then return end
        local function s(obj,id) if obj then obj.AnimationId = id end end
        s(animate.idle and animate.idle.Animation1, pack.idle1)
        s(animate.idle and animate.idle.Animation2, pack.idle2)
        s(animate.walk and animate.walk.WalkAnim, pack.walk)
        s(animate.run  and animate.run.RunAnim,   pack.run)
        s(animate.jump and animate.jump.JumpAnim, pack.jump)
        s(animate.fall and animate.fall.FallAnim, pack.fall)
        s(animate.climb and animate.climb.ClimbAnim, pack.climb)
        s(animate.swim and animate.swim.Swim, pack.swim)
        s(animate.swimidle and animate.swimidle.SwimIdle, pack.swimidle)
    end)
end

local function startAnimPack(packName)
    local char = LP.Character
    if char then
        saveOriginalAnims(char)
        applyAnimPack(packName)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do track:Stop(0) end
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    else
        applyAnimPack(packName)
    end
    currentAnimPack = packName
end

local function stopAnimPack()
    currentAnimPack = "Off"
    if animSelectorLabel then animSelectorLabel.Text = "Off" end
    applyAnimPack("Off")
end

DEFAULT_KB = {
    DropBrainrot = {kb = Enum.KeyCode.X, gp = nil},
    AutoLeft     = {kb = Enum.KeyCode.Z, gp = nil},
    AutoRight    = {kb = Enum.KeyCode.C, gp = nil},
    AutoBat      = {kb = Enum.KeyCode.E, gp = nil},
    TPFloor      = {kb = Enum.KeyCode.F, gp = nil},
    GuiHide      = {kb = Enum.KeyCode.LeftControl, gp = nil},
    CarryToggle  = {kb = Enum.KeyCode.Q, gp = nil},
    LaggerMode   = {kb = Enum.KeyCode.R, gp = nil},
    TPBat        = {kb = Enum.KeyCode.V, gp = nil},
    BatV2        = {kb = Enum.KeyCode.N, gp = nil},
    InstaReset   = {kb = Enum.KeyCode.H, gp = nil},
}

KB = {
    DropBrainrot = {kb = DEFAULT_KB.DropBrainrot.kb, gp = DEFAULT_KB.DropBrainrot.gp},
    AutoLeft     = {kb = DEFAULT_KB.AutoLeft.kb, gp = DEFAULT_KB.AutoLeft.gp},
    AutoRight    = {kb = DEFAULT_KB.AutoRight.kb, gp = DEFAULT_KB.AutoRight.gp},
    AutoBat      = {kb = DEFAULT_KB.AutoBat.kb, gp = DEFAULT_KB.AutoBat.gp},
    TPFloor      = {kb = DEFAULT_KB.TPFloor.kb, gp = DEFAULT_KB.TPFloor.gp},
    GuiHide      = {kb = DEFAULT_KB.GuiHide.kb, gp = DEFAULT_KB.GuiHide.gp},
    CarryToggle  = {kb = DEFAULT_KB.CarryToggle.kb, gp = DEFAULT_KB.CarryToggle.gp},
    LaggerMode   = {kb = DEFAULT_KB.LaggerMode.kb, gp = DEFAULT_KB.LaggerMode.gp},
    TPBat        = {kb = DEFAULT_KB.TPBat.kb, gp = DEFAULT_KB.TPBat.gp},
    BatV2        = {kb = DEFAULT_KB.BatV2.kb, gp = DEFAULT_KB.BatV2.gp},
    InstaReset   = {kb = DEFAULT_KB.InstaReset.kb, gp = DEFAULT_KB.InstaReset.gp},
}

_isResetting = false
_lastSavedJSON = nil

CONFIG = {
    AUTO_STEAL_ENABLED = false,
    STEAL_RANGE = 61,
}

local stealConnection = nil

local Steal = {
    AutoStealEnabled = false,
    StealRadius = CONFIG.STEAL_RANGE,
    StealDuration = 1.3,
    -- V2 "half hold" method fields
    HalfFireRange = 10,
    HalfHoldMin = 1.3,
    HalfHoldMax = 2.6,
    HalfEntryDelay = 0.3,
    Data = {}
}

local isStealing = false
local autoGrabSetDelayRadius = 9
local autoGrabStopPct     = 95   -- % of steal duration to pause at (1-95)
local autoGrabStopEnabled = true
local autoGrabVariant = "v1"
local batAimbotVariant = "v1"

local _plotsCache = nil
local _plotsCacheTime = 0
local function getPlotsRoot()
    local now = _tick()
    if _plotsCache and now - _plotsCacheTime < 2 and _plotsCache.Parent then
        return _plotsCache
    end
    _plotsCache = workspace:FindFirstChild("Plots")
    _plotsCacheTime = now
    return _plotsCache
end

local function isMyPlotByName(plotName)
    local plotsRoot = getPlotsRoot()
    if not plotsRoot then return false end
    local plot = plotsRoot:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then
            return yb.Enabled == true
        end
    end
    return false
end

local function findNearestPrompt()
    local char = LP.Character
    if not char then return nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end
    local plotsRoot = getPlotsRoot()
    if not plotsRoot then return nil, nil end
    local nearestPrompt, nearestDist, nearestName = nil, _huge, nil
    local rpos = root.Position
    for _, plot in ipairs(plotsRoot:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then continue end
        for _, pod in ipairs(pods:GetChildren()) do
            pcall(function()
                local base = pod:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                if spawn then
                    local sp = spawn.Position
                    local dx = sp.X - rpos.X
                    local dy = sp.Y - rpos.Y
                    local dz = sp.Z - rpos.Z
                    local dist = _sqrt(dx*dx + dy*dy + dz*dz)
                    if dist < nearestDist and dist <= Steal.StealRadius then
                        local att = spawn:FindFirstChild("PromptAttachment")
                        if att then
                            for _, child in ipairs(att:GetChildren()) do
                                if child:IsA("ProximityPrompt") and child.ActionText and child.ActionText:find("Steal") then
                                    nearestPrompt = child
                                    nearestDist = dist
                                    nearestName = pod.Name
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
    return nearestPrompt, nearestName
end

-- V2 "half hold" method: hold the prompt, wait a minimum hold time, then
-- poll for the prompt coming back into a tighter fire range. Once in range
-- (with a small entry delay if it just entered range this poll), fires the
-- trigger. If HalfHoldMax elapses without ever coming into fire range, it
-- gives up cleanly and frees the prompt for the next attempt.
local function executeStealV2(prompt, podName)
    if isStealing then return end

    -- Prune dead entries occasionally
    if math.random(30) == 1 then
        for p in pairs(Steal.Data) do
            if not p.Parent then Steal.Data[p] = nil end
        end
    end

    -- Build hold/trigger callback cache (same Steal.Data as before)
    if not Steal.Data[prompt] then
        Steal.Data[prompt] = { hold = {}, trigger = {}, ready = true }
        pcall(function()
            if getconnections then
                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if c.Function then table.insert(Steal.Data[prompt].hold, c.Function) end
                end
                for _, c in ipairs(getconnections(prompt.Triggered)) do
                    if c.Function then table.insert(Steal.Data[prompt].trigger, c.Function) end
                end
            end
        end)
    end

    local data = Steal.Data[prompt]
    if not data.ready then return end
    data.ready  = false
    isStealing  = true

    if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
    if progressPct  then progressPct.Text  = "0%" end

    -- Prompt-relative distance (keeps V2's approach, no animalData needed)
    local function promptDist()
        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return _huge end
        local part = prompt.Parent
        if part and part:IsA("Attachment") then part = part.Parent end
        if part and part:IsA("BasePart") then
            return (part.Position - hrp.Position).Magnitude
        end
        return _huge
    end

    task.spawn(function()
        -- ── Tuning (text_5 Semi V1 values, V2 vars as fallback) ──
        local holdMin    = math.max(tonumber(autoGrabStopTime) or Steal.HalfHoldMin or 1.29, 0.01)
        local holdMax    = Steal.HalfHoldMax or 2.69
        local entryDelay = Steal.HalfEntryDelay or 0.3
        local stealRange = tonumber(autoGrabSetDelayRadius) or Steal.HalfFireRange or 8
        local primeRange = Steal.StealRadius

        local t0 = _tick()

        -- ── Phase 1: fire hold callbacks, advance bar to 100% over holdMin ──
        for _, fn in ipairs(data.hold) do task.spawn(function() pcall(fn) end) end

        while _tick() - t0 < holdMin do
            if not Steal.AutoStealEnabled or not prompt.Parent then
                isStealing = false; data.ready = true
                if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                if progressPct  then progressPct.Text  = "0%" end
                return
            end
            if promptDist() > primeRange then
                isStealing = false; data.ready = true
                if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                if progressPct  then progressPct.Text  = "0%" end
                return
            end
            local pct = _clamp((_tick() - t0) / holdMin, 0, 1)
            if progressFill then progressFill.Size = UDim2.new(pct, 0, 1, 0) end
            if progressPct  then progressPct.Text  = _floor(pct * 100) .. "%" end
            task.wait()
        end

        if progressFill then progressFill.Size = UDim2.new(1, 0, 1, 0) end
        if progressPct  then progressPct.Text  = "100%" end

        -- ── Phase 2: hold at 100%, wait for entry into stealRange ──
        local alreadyInRange = promptDist() <= stealRange

        while true do
            if _tick() - t0 > holdMax then break end
            if not prompt.Parent or not Steal.AutoStealEnabled then break end

            local dist = promptDist()
            if dist > primeRange then
                isStealing = false; data.ready = true
                if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                if progressPct  then progressPct.Text  = "0%" end
                return
            end

            if dist <= stealRange then
                -- Phase 3: optional entry delay then fire
                if not alreadyInRange then task.wait(entryDelay) end

                pcall(function()
                    for _, fn in ipairs(data.trigger) do task.spawn(function() pcall(fn) end) end
                    local remote = ReplicatedStorage:FindFirstChild("StealAnimal")
                    if remote and podName then remote:FireServer(podName) end
                    if prompt then pcall(function() prompt:Fire() end) end
                    if _G.AutoCarrySpeed and _G.AutoCarrySpeed.WatchPickup then
                        _G.AutoCarrySpeed.WatchPickup(1.25)
                    end
                end)
                break
            end
            task.wait()
        end

        if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
        if progressPct  then progressPct.Text  = "0%" end
        data.ready = true
        isStealing = false
    end)
end

-- ============================================================
-- AUTO GRAB — NEW ENGINE (V1 only)
-- Engine: synced AnimalList + prompt cache + hold/trigger callbacks.
-- V1 keeps its own timing + progress-bar fill behavior. V2 is unchanged.
-- ============================================================
do
    local B = {
        plotSync      = { caches = {}, connections = {} },
        animals       = {},
        promptCache   = {},
        internalCache = {},
        lastScan      = 0,
        cooldown      = 0.05,
    }

    local function rootPart()
        local char = LP.Character
        return char and (char:FindFirstChild("HumanoidRootPart")
                         or char:FindFirstChild("UpperTorso")) or nil
    end

    -- progress bar (Meridian's own fill) --------------------------------
    local function barSet(p)
        if progressFill then progressFill.Size = UDim2.new(p, 0, 1, 0) end
        if progressPct then progressPct.Text = _floor(p * 100) .. "%" end
    end

    local function barZero()
        if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
        if progressPct then progressPct.Text = "0%" end
    end

    -- sync diff path resolver -------------------------------------------
    local function splitPath(path)
        if typeof(path) == "table" then return path end
        local out = {}
        for part in string.gmatch(tostring(path), "[^%.]+") do
            table.insert(out, tonumber(part) or part)
        end
        return out
    end

    local function resolvePath(path, root)
        local current, parent, key = root, nil, nil
        for _, part in ipairs(splitPath(path)) do
            parent = current
            key    = part
            current = current and current[part] or nil
        end
        return current, parent, key
    end

    local function applySyncDiff(channelName, packet)
        local cache = B.plotSync.caches[channelName]
        if typeof(cache) ~= "table" then return end

        local path, action, a, b = packet[1], packet[2], packet[3], packet[4]
        local current, parent, key = resolvePath(path, cache)

        if action == "Changed" then
            if parent ~= nil then parent[key] = a end
        elseif action == "ArrayInsert" then
            if current ~= nil then table.insert(current, b, a) end
        elseif action == "ArrayRemoved" then
            if current ~= nil then table.remove(current, b) end
        elseif action == "DictionaryInsert" then
            if current ~= nil then current[b] = a end
        elseif action == "DictionaryRemoved" then
            if current ~= nil then current[b] = nil end
        end
    end

    local function attachPlotChannel(remote, plots, requestData)
        if B.plotSync.connections[remote] then return end
        local channelName = tostring(remote.Name)
        if not plots:FindFirstChild(channelName) then return end

        if requestData and B.plotSync.caches[channelName] == nil then
            local ok, data = pcall(function()
                return requestData:InvokeServer(channelName)
            end)
            B.plotSync.caches[channelName] =
                (ok and typeof(data) == "table") and data or {}
        elseif B.plotSync.caches[channelName] == nil then
            B.plotSync.caches[channelName] = {}
        end

        B.plotSync.connections[remote] =
            remote.OnClientEvent:Connect(function(queue)
                for _, packet in ipairs(queue) do
                    applySyncDiff(channelName, packet)
                end
            end)
    end

    local function ensureSync()
        if B.syncReady then return true end
        if B.syncBusy then return false end
        B.syncBusy = true

        local ok = pcall(function()
            local rs = game:GetService("ReplicatedStorage")

            B.packages = rs:WaitForChild("Packages", 10)
            B.datas    = rs:WaitForChild("Datas", 10)
            B.plots    = workspace:WaitForChild("Plots", 10)

            if not (B.packages and B.datas and B.plots) then return end

            B.animalsData = require(B.datas:WaitForChild("Animals", 10))

            local sync = B.packages:WaitForChild("Synchronizer", 10)
            B.channelFolder = sync:WaitForChild("Channel", 10)
            B.routeRemote   = sync:WaitForChild("CommunicationRoute", 10)
            B.requestData   = sync:FindFirstChild("RequestData")

            for _, child in ipairs(B.channelFolder:GetChildren()) do
                if child:IsA("RemoteEvent") then
                    attachPlotChannel(child, B.plots, B.requestData)
                end
            end

            if not B.hooked then
                B.hooked = true

                B.channelFolder.ChildAdded:Connect(function(child)
                    if child:IsA("RemoteEvent") then
                        attachPlotChannel(child, B.plots, B.requestData)
                    end
                end)

                B.routeRemote.OnClientEvent:Connect(function(actions)
                    for _, action in ipairs(actions) do
                        local kind, channelName = action[1], tostring(action[2])
                        if B.plots and B.plots:FindFirstChild(channelName) then
                            if kind == "ListenerAdded" then
                                local remote = B.channelFolder
                                    and B.channelFolder:FindFirstChild(channelName)
                                if remote and remote:IsA("RemoteEvent") then
                                    attachPlotChannel(remote, B.plots, B.requestData)
                                end
                            elseif kind == "ListenerRemoved" then
                                for remote, conn in pairs(B.plotSync.connections) do
                                    if tostring(remote.Name) == channelName then
                                        pcall(function() conn:Disconnect() end)
                                        B.plotSync.connections[remote] = nil
                                        B.plotSync.caches[channelName]  = nil
                                        break
                                    end
                                end
                            end
                        end
                    end
                end)
            end

            B.syncReady = true
        end)

        B.syncBusy = false
        return ok and B.syncReady == true
    end

    -- plot owner / my-base exclusion ------------------------------------
    local function getPlotOwner(plot)
        local sign  = plot and plot:FindFirstChild("PlotSign")
        local frame = sign and sign:FindFirstChild("SurfaceGui")
                    and sign.SurfaceGui:FindFirstChild("Frame")
        local label = frame and frame:FindFirstChild("TextLabel")
        if not label or label.Text == "Empty Base" then return nil end
        return label.Text:gsub("'s [Bb]ase$", ""):gsub("%s+$", "")
    end

    local function isMyBaseAnimal(animalData)
        if not animalData or not animalData.plot or not B.plots then
            return false
        end
        local plot = B.plots:FindFirstChild(animalData.plot)
        if not plot then return false end
        local owner = getPlotOwner(plot)
        return owner == LP.DisplayName or owner == LP.Name
    end

    -- podium / prompt helpers -------------------------------------------
    local function podiumFor(animalData)
        local plot    = B.plots and B.plots:FindFirstChild(animalData.plot)
        local podiums = plot and plot:FindFirstChild("AnimalPodiums")
        return podiums and podiums:FindFirstChild(animalData.slot) or nil
    end

    local function animalPos(animalData)
        local podium = podiumFor(animalData)
        return podium and podium:GetPivot().Position or nil
    end

    local function distToAnimal(animalData)
        local root = rootPart()
        local pos  = animalPos(animalData)
        return root and pos and (root.Position - pos).Magnitude or _huge
    end

    -- true only when we have a character AND we are past `limit` studs
    local function farFrom(animalData, limit)
        return rootPart() ~= nil and distToAnimal(animalData) > limit
    end

    local function findPromptForAnimal(animalData)
        if not animalData then return nil end

        local cached = B.promptCache[animalData.uid]
        if cached and cached.Parent then return cached end

        local podium = podiumFor(animalData)
        local base   = podium and podium:FindFirstChild("Base")
        local spawn  = base and base:FindFirstChild("Spawn")
        local attach = spawn and spawn:FindFirstChild("PromptAttachment")
        if not attach then return nil end

        for _, prompt in ipairs(attach:GetChildren()) do
            if prompt:IsA("ProximityPrompt") then
                B.promptCache[animalData.uid] = prompt
                return prompt
            end
        end
        return nil
    end

    -- scan all plots (from synced AnimalList) ----------------------------
    local function scanAllPlots()
        if not ensureSync() then return 0 end
        local newCache = {}

        for _, plot in ipairs(B.plots:GetChildren()) do
            local cache = B.plotSync.caches[plot.Name]
            local animalList = cache and cache.AnimalList

            if typeof(animalList) == "table" then
                for slot, animalData in pairs(animalList) do
                    if type(animalData) == "table" then
                        local animalName = animalData.Index
                        local info = B.animalsData and B.animalsData[animalName]
                        if info then
                            table.insert(newCache, {
                                name = info.DisplayName or animalName,
                                plot = plot.Name,
                                slot = tostring(slot),
                                uid  = plot.Name .. "_" .. tostring(slot),
                            })
                        end
                    end
                end
            end
        end
        B.animals  = newCache
        B.lastScan = os.clock()
        return #newCache
    end

    -- closest animal inside the (GUI) steal radius -----------------------
    local function pickClosest()
        local root = rootPart()
        if not root then return nil end

        local best, bestDist = nil, _huge
        for _, animalData in ipairs(B.animals) do
            if not isMyBaseAnimal(animalData) then
                local pos  = animalPos(animalData)
                local dist = pos and (root.Position - pos).Magnitude or _huge
                if dist <= Steal.StealRadius and dist < bestDist then
                    best, bestDist = animalData, dist
                end
            end
        end
        return best
    end

    -- hold / trigger callbacks -------------------------------------------
    local function buildCallbacks(prompt)
        if B.internalCache[prompt] then return end

        if math.random(30) == 1 then
            for p in pairs(B.internalCache) do
                if not p.Parent then B.internalCache[p] = nil end
            end
        end

        local data = { holdCallbacks = {}, triggerCallbacks = {}, ready = true }

        local okHold, holds = pcall(getconnections, prompt.PromptButtonHoldBegan)
        if okHold and type(holds) == "table" then
            for _, conn in ipairs(holds) do
                if type(conn.Function) == "function" then
                    table.insert(data.holdCallbacks, conn.Function)
                end
            end
        end

        local okTrigger, triggers = pcall(getconnections, prompt.Triggered)
        if okTrigger and type(triggers) == "table" then
            for _, conn in ipairs(triggers) do
                if type(conn.Function) == "function" then
                    table.insert(data.triggerCallbacks, conn.Function)
                end
            end
        end

        if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 then
            B.internalCache[prompt] = data
        end
    end

    local function fireHolds(data)
        for _, fn in ipairs(data.holdCallbacks) do
            task.spawn(function() pcall(fn) end)
        end
    end

    local function fireTriggers(data)
        for _, fn in ipairs(data.triggerCallbacks) do
            task.spawn(function() pcall(fn) end)
        end
        pcall(function()
            if _G.AutoCarrySpeed and _G.AutoCarrySpeed.WatchPickup then
                _G.AutoCarrySpeed.WatchPickup(1.25)
            end
        end)
    end

    -- claim / release a prompt for one steal attempt ---------------------
    local function claim(prompt, animalData)
        if isStealing then return nil end
        if not prompt or not prompt.Parent or not animalData then return nil end

        buildCallbacks(prompt)
        local data = B.internalCache[prompt]
        if not data or not data.ready then return nil end

        data.ready = false
        isStealing = true
        barZero()
        return data
    end

    local function release(data)
        barZero()
        isStealing = false
        task.wait(B.cooldown)
        data.ready = true
    end

    -- ========================================================
    -- V1 — timed fire (fill up to stop %, wait for delay radius,
    --      finish fill, then fire)
    -- ========================================================
    local function executeSteal(prompt, animalData)
        local data = claim(prompt, animalData)
        if not data then return end

        task.spawn(function()
            fireHolds(data)

            local startTime = _tick()
            local duration = Steal.StealDuration
            local promptFired = false

            if autoGrabStopEnabled then
                local stopAt = _clamp(autoGrabStopPct / 100, 0.01, 0.95) * duration
                while isStealing and Steal.AutoStealEnabled do
                    local elapsed = _tick() - startTime
                    if elapsed >= stopAt then break end
                    barSet(_clamp(elapsed / duration, 0, 1))
                    if not prompt.Parent or not prompt.Parent.Parent then break end
                    if farFrom(animalData, Steal.StealRadius) then break end
                    task.wait()
                end

                local stopProgress = _clamp(stopAt / duration, 0, 1)
                barSet(stopProgress)

                local phase2Timeout = math.max(2.99 - stopAt - math.max(duration - stopAt, 0), 0.05)
                local phase2Start = _tick()

                while isStealing and Steal.AutoStealEnabled do
                    if _tick() - phase2Start >= phase2Timeout then
                        barZero()
                        data.ready = true
                        isStealing = false
                        task.wait()
                        local nextTarget = pickClosest()
                        local nextPrompt = nextTarget and findPromptForAnimal(nextTarget)
                        if nextPrompt then executeSteal(nextPrompt, nextTarget) end
                        return
                    end
                    if not prompt.Parent or not prompt.Parent.Parent then
                        isStealing = false
                        barZero()
                        data.ready = true
                        return
                    end
                    if rootPart() then
                        local dist = distToAnimal(animalData)
                        if dist <= autoGrabSetDelayRadius then
                            break
                        elseif dist > Steal.StealRadius then
                            isStealing = false
                            barZero()
                            data.ready = true
                            return
                        end
                    end
                    task.wait()
                end

                if isStealing and Steal.AutoStealEnabled then
                    local fillStart = _tick()
                    local fillDuration = math.max(duration - stopAt, 0.05)
                    while true do
                        local fp = _clamp((_tick() - fillStart) / fillDuration, 0, 1)
                        barSet(stopProgress + fp * (1 - stopProgress))
                        if fp >= 1 and not promptFired then
                            promptFired = true
                            fireTriggers(data)
                            break
                        end
                        task.wait()
                    end
                end
            else
                if progressFill then
                    TS:Create(progressFill, TweenInfo.new(1.3, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 1, 0) }):Play()
                end
                local startTime2 = _tick()
                while isStealing and Steal.AutoStealEnabled do
                    local elapsed = _tick() - startTime2
                    local pct = _clamp(elapsed / 1.3, 0, 1)
                    if progressPct then progressPct.Text = _floor(math.min(pct, 1) * 100) .. "%" end
                    if not prompt.Parent or not prompt.Parent.Parent then
                        if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                        break
                    end
                    if farFrom(animalData, Steal.StealRadius) then break end
                    if elapsed >= 1.3 and not promptFired then
                        promptFired = true
                        fireTriggers(data)
                        break
                    end
                    task.wait()
                end
            end

            release(data)
        end)
    end

    -- ========================================================
    -- background scan (every 5s while auto steal is on)
    -- ========================================================
    local function ensureScanThread()
        if B.scanThread then return end
        B.scanThread = task.spawn(function()
            while true do
                if Steal.AutoStealEnabled and autoGrabVariant == "v1" then pcall(scanAllPlots) end
                task.wait(5)
            end
        end)
    end

    -- non-blocking boot (sync can yield on first load)
    local function boot()
        if B.booting then return end
        B.booting = true
        task.spawn(function()
            ensureSync()
            ensureScanThread()
            pcall(scanAllPlots)
            B.booting = false
        end)
    end

    -- ========================================================
    -- lifecycle
    -- ========================================================
    function startAutoSteal()
        if autoGrabVariant ~= "v1" then return false end
        Steal.StealRadius = CONFIG.STEAL_RANGE
        Steal.AutoStealEnabled = true
        CONFIG.AUTO_STEAL_ENABLED = true
        boot()
        if stealConnection then
            local connected = false
            pcall(function() connected = stealConnection.Connected == true end)
            if connected then return true end
            pcall(function() stealConnection:Disconnect() end)
            stealConnection = nil
        end
        stealConnection = RunService.Heartbeat:Connect(function()
            if not Steal.AutoStealEnabled or isStealing then return end
            local target = pickClosest()
            if not target then return end
            local prompt = findPromptForAnimal(target)
            if prompt then executeSteal(prompt, target) end
        end)
        return true
    end
end

function stopAutoSteal()
    if stealConnection then
        stealConnection:Disconnect()
        stealConnection = nil
    end
    isStealing = false
    Steal.AutoStealEnabled = false
    CONFIG.AUTO_STEAL_ENABLED = false
    if progressFill then
        TS:Create(progressFill, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    end
    if progressPct then progressPct.Text = "0%" end
end

-- V2 lifecycle: mirrors V1's connection management, but drives
-- executeStealV2 (half-hold method) instead of the timed-fire method.
function startAutoStealV2()
    if autoGrabVariant ~= "v2" then return false end
    if stealConnection then
        local connected = false
        pcall(function() connected = stealConnection.Connected == true end)
        if connected then
            Steal.StealRadius = CONFIG.STEAL_RANGE
            Steal.AutoStealEnabled = true
            CONFIG.AUTO_STEAL_ENABLED = true
            return true
        end
        pcall(function() stealConnection:Disconnect() end)
        stealConnection = nil
    end
    Steal.StealRadius = CONFIG.STEAL_RANGE
    Steal.AutoStealEnabled = true
    CONFIG.AUTO_STEAL_ENABLED = true
    stealConnection = RunService.Heartbeat:Connect(function()
        if not Steal.AutoStealEnabled or isStealing then return end
        local p, n = findNearestPrompt()
        if p then executeStealV2(p, n) end
    end)
    return true
end

LP.CharacterAdded:Connect(function()
    if autoBatV2Enabled then _akV2.equipped = false end
    if autoBatV3Enabled then _akV3.equipped = false end
end)

medusaDebounce = false
medusaLastUsed = 0
dropActive = false
lastDropTime = 0
lastMoveDir = _V3new(0,0,0)
origFOV = nil
fovEnabled = false
fovValue = 70
customFovConn = nil
setFovVisual = nil
fovSliderSet = nil

_anyKeyListening = false
_aimbotConn = nil
_prevAutoRotate = nil
tpBatFloatingButton = nil
batV2FloatingButton = nil

enemySpeedConn = nil
movementLoop = nil
steppedConn = nil
alConn = nil
arConn = nil
stretchConn = nil
stretchFovConn = nil
antiLagDescConn = nil
dropConnections = {}
enemySpeedLabels = {}
Conns = {autoSteal = nil, batCounter = nil, anchor = {}, progress = nil, autoLeft = nil, autoRight = nil}
keyButtonRefs = {}
progressFill = nil
progressPct = nil
pbFrame = nil
speedLabel = nil
modeValLbl = nil
normalBox, carryBox, laggerBox, lagger2Box, radInput, batSpeedBox, laggerBatSpeedBox, uiScaleBox, pbBarScaleBox, stopAtBox = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
modeSelectBtn, dropModeBtnRef = nil, nil
autoBatSetVisual, autoLeftSetVisual, autoRightSetVisual, setBatCounterVisual, setMedusaVisual = nil, nil, nil, nil, nil
setAntiRagVisual, setJumpVisual, setUnwalkVisual, setAntiLagVisual, setLockUIVisual, setInstaGrab = nil, nil, nil, nil, nil, nil
setAntiDieVisual = nil
setEditModeVisual = nil
setESPVIsual = nil
adaptAutoCarrySelectorUpdate = nil
mobSetAutoBat, mobSetAutoLeft, mobSetAutoRight, mobSetDropBR, mobSetTpDown, mobSetCarry, mobSetLagger1, mobSetLagger2 = nil, nil, nil, nil, nil, nil, nil, nil
autoBatV2SetVisual = nil
autoBatV3SetVisual = nil
mirrorTpEnabled = false
mirrorTpSetVisual = nil
autoTPDownEnabled = false
autoTPDownHeight  = 20
autoTPDownSetVisual = nil
local _tpdConn      = nil
local _tpdLastTick  = 0
local _tpdDropGuard = false
miniBtn, main, gui = nil, nil, nil
MobilePanel = nil
instaResetFloatingButton = nil
showGui = nil
hideGui = nil
guiOpenState = true
mainUIScale = nil
animSelectorLabel = nil
pbScale = nil
pbBarScaleValue = 100
tabButtons = nil
colorSelectorLabel = nil

avatarStrokeRef = nil

GAMEPAD_KEYS = {
    [Enum.KeyCode.ButtonA] = true, [Enum.KeyCode.ButtonB] = true,
    [Enum.KeyCode.ButtonX] = true, [Enum.KeyCode.ButtonY] = true,
    [Enum.KeyCode.ButtonL1] = true, [Enum.KeyCode.ButtonR1] = true,
    [Enum.KeyCode.ButtonL2] = true, [Enum.KeyCode.ButtonR2] = true,
    [Enum.KeyCode.ButtonL3] = true, [Enum.KeyCode.ButtonR3] = true,
    [Enum.KeyCode.ButtonStart] = true, [Enum.KeyCode.ButtonSelect] = true,
    [Enum.KeyCode.DPadUp] = true, [Enum.KeyCode.DPadDown] = true,
    [Enum.KeyCode.DPadLeft] = true, [Enum.KeyCode.DPadRight] = true,
}

MOVE_KEYS = {
    [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true,
    [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
    [Enum.KeyCode.Up] = true, [Enum.KeyCode.Left] = true,
    [Enum.KeyCode.Down] = true, [Enum.KeyCode.Right] = true,
}

BAT_COUNTER_SLAP_LIST = {
    "Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap",
    "Emerald Slap", "Ruby Slap", "Dark Matter Slap", "Flame Slap",
    "Nuclear Slap", "Galaxy Slap", "Glitched Slap"
}

AP = {
    L1 = _V3new(-476.48, -6.28, 92.73),
    L2 = _V3new(-483.12, -4.95, 94.80),
    L_FACE = _V3new(-482.25, -4.96, 92.09),
    R1 = _V3new(-476.16, -6.52, 25.62),
    R2 = _V3new(-483.06, -5.03, 25.48),
    R_FACE = _V3new(-482.06, -6.93, 35.47),
}

function isGamepadInput(inp)
    return inp and inp.UserInputType and inp.UserInputType.Name:match("^Gamepad") ~= nil
end

function isBindableInput(inp)
    if not inp or inp.KeyCode == Enum.KeyCode.Unknown then return false end
    if inp.UserInputType == Enum.UserInputType.Keyboard then return true end
    return isGamepadInput(inp) and GAMEPAD_KEYS[inp.KeyCode] == true
end

function kbMatch(entry, kc)
    return kc and (kc == entry.kb or (entry.gp and kc == entry.gp))
end

local function doTpDown()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = _CFnew(root.Position.X, -7, root.Position.Z) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
        root.Velocity = _V3zero
    end)
end

-- ============================================================
-- MIRROR TP DOWN — Adapt engine (Y-drop detection)
-- ============================================================
local MIRROR_TP_DROP_THRESHOLD = 3
local MIRROR_TP_DOWN_Y        = -7.00
local mirrorTPPreviousY       = {}
local mirrorTPLastTeleport    = 0

local function mirrorTPActive()
    -- Adapt logic: mirror TP Down only activates when Auto Bat aimbot is on.
    -- TP BAT alone does not trigger it — keeps it clean and intentional.
    return isAimbotEnabled()
end

local function mirrorTPTeleportDown()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end
    local now = tick()
    if now - mirrorTPLastTeleport < 0.08 then return end
    mirrorTPLastTeleport = now
    local _, yaw = root.CFrame:ToEulerAnglesYXZ()
    local y = MIRROR_TP_DOWN_Y + (math.random() * 0.6 - 0.3)
    root.CFrame = CFrame.new(root.Position.X, y, root.Position.Z) * CFrame.Angles(0, yaw, 0)
    root.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 0.4, 0, (math.random() - 0.5) * 0.4)
end

RunService.Heartbeat:Connect(function()
    if not mirrorTpEnabled or not mirrorTPActive() then
        if next(mirrorTPPreviousY) then table.clear(mirrorTPPreviousY) end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local currentY  = root.Position.Y
                local previousY = mirrorTPPreviousY[plr.UserId]
                if previousY and previousY - currentY >= MIRROR_TP_DROP_THRESHOLD then
                    pcall(mirrorTPTeleportDown)
                    table.clear(mirrorTPPreviousY)
                    return
                end
                mirrorTPPreviousY[plr.UserId] = currentY
            end
        end
    end
end)
-- ============================================================

-- ============================================================
-- AUTO TP DOWN
-- ============================================================
local function _tpdFindGroundY(character, root, humanoid)
    if not character or not root or not humanoid then return nil end
    local filterList = { character }
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                table.insert(filterList, p.Character)
            end
        end
    end)
    local startY = root.Position.Y - root.Size.Y * 0.5 - 0.1
    local finalGroundY
    for _ = 1, 12 do
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = filterList
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        pcall(function() params.RespectCanCollide = true end)
        local hit
        pcall(function()
            hit = workspace:Raycast(
                Vector3.new(root.Position.X, startY, root.Position.Z),
                Vector3.new(0, -4000, 0), params)
        end)
        if not hit then break end
        local skip = false
        local inst = hit.Instance
        if inst then
            pcall(function()
                if inst:IsA("BasePart") and inst.CanCollide == false then skip = true end
                local model = inst:FindFirstAncestorOfClass("Model")
                if model and model:FindFirstChildOfClass("Humanoid") then skip = true end
            end)
        else
            skip = true
        end
        if skip then
            if inst then table.insert(filterList, inst) end
            startY = hit.Position.Y - 0.05
        else
            finalGroundY = hit.Position.Y
            break
        end
    end
    if not finalGroundY then return nil end
    local halfSize = 1
    pcall(function() halfSize = root.Size.Y * 0.5 end)
    if halfSize <= 0 then halfSize = 1 end
    local offset = halfSize * 3
    pcall(function()
        if humanoid.RigType == Enum.HumanoidRigType.R15 then
            offset = halfSize + (humanoid.HipHeight or halfSize * 2)
        end
    end)
    if offset ~= offset or offset < 1 or offset > 12 then offset = halfSize * 3 end
    return finalGroundY + offset + 0.15
end

local function _tpdDoAction(manual)
    if _tpdDropGuard then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not manual then
        if hum.FloorMaterial ~= Enum.Material.Air then return end
        local minY = tonumber(autoTPDownHeight) or 20
        minY = math.clamp(minY, 1, 100000)
        if root.Position.Y < minY then return end
    end
    local targetY = _tpdFindGroundY(char, root, hum)
    if not targetY then return end
    if not manual and (root.Position.Y - targetY) < 0.75 then return end
    root.CFrame = CFrame.new(root.Position.X, targetY, root.Position.Z)
        * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
    pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
    task.spawn(function()
        local deadline = os.clock() + 8
        while os.clock() < deadline do
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then break end
            if h.FloorMaterial ~= Enum.Material.Air then break end
            RunService.Heartbeat:Wait()
        end
    end)
end

local function startAutoTPDownLoop()
    if _tpdConn then return end
    _tpdLastTick = 0
    _tpdConn = RunService.Heartbeat:Connect(function()
        if not autoTPDownEnabled then return end
        local now = tick()
        if now - _tpdLastTick < 0.1 then return end
        _tpdLastTick = now
        pcall(_tpdDoAction, false)
    end)
end

local function stopAutoTPDownLoop()
    if _tpdConn then _tpdConn:Disconnect(); _tpdConn = nil end
end

local function toggleAutoTPDown(on)
    autoTPDownEnabled = on == true
    if autoTPDownEnabled then
        startAutoTPDownLoop()
    else
        stopAutoTPDownLoop()
    end
    if autoTPDownSetVisual then autoTPDownSetVisual(autoTPDownEnabled) end
    saveAllSettings()
end
-- ============================================================
AntiRagdollV1 = AntiRagdollV1 or {}
AntiRagdollV1.__index = AntiRagdollV1

local BOOST_SPEED = 400
local AR_DEFAULT_SPEED = 16

local stateV1 = {
    active = false,
    isBoosting = false,
    cachedChar = nil,
    ragdollConnections = {},
}

local function disconnectAllV1()
    for _, conn in ipairs(stateV1.ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    stateV1.ragdollConnections = {}
end

local function cacheCharacterV1()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    stateV1.cachedChar = { character = char, humanoid = hum, root = root }
    return true
end

local function isRagdolledV1()
    if not stateV1.cachedChar or not stateV1.cachedChar.humanoid then return false end
    local hum = stateV1.cachedChar.humanoid
    local st = hum:GetState()
    local ragdollStates = {
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }
    return ragdollStates[st] or false
end

local function forceExitRagdollV1()
    if not stateV1.cachedChar or not stateV1.cachedChar.humanoid or not stateV1.cachedChar.root then return end
    local hum = stateV1.cachedChar.humanoid
    local root = stateV1.cachedChar.root
    pcall(function()
        LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    for _, descendant in ipairs(stateV1.cachedChar.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or
           (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            descendant:Destroy()
        end
    end
    if not stateV1.isBoosting then
        stateV1.isBoosting = true
        hum.WalkSpeed = BOOST_SPEED
    end
    if hum.Health > 0 then
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
    root.Anchored = false
end

local function heartbeatLoopV1()
    while stateV1.active do
        task.wait()
        if isRagdolledV1() then
            forceExitRagdollV1()
        elseif stateV1.isBoosting and not isRagdolledV1() then
            stateV1.isBoosting = false
            if stateV1.cachedChar and stateV1.cachedChar.humanoid then
                stateV1.cachedChar.humanoid.WalkSpeed = AR_DEFAULT_SPEED
            end
        end
    end
end

function AntiRagdollV1.start()
    if stateV1.active then return end
    AntiRagdollV1.stop()
    if not cacheCharacterV1() then
        return
    end
    stateV1.active = true
    stateV1.isBoosting = false
    local camConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and stateV1.cachedChar and stateV1.cachedChar.humanoid then
            cam.CameraSubject = stateV1.cachedChar.humanoid
        end
    end)
    table.insert(stateV1.ragdollConnections, camConn)
    local respawnConn = LP.CharacterAdded:Connect(function()
        stateV1.isBoosting = false
        task.wait(0.5)
        cacheCharacterV1()
    end)
    table.insert(stateV1.ragdollConnections, respawnConn)
    task.spawn(heartbeatLoopV1)
end

function AntiRagdollV1.stop()
    stateV1.active = false
    if stateV1.isBoosting and stateV1.cachedChar and stateV1.cachedChar.humanoid then
        stateV1.cachedChar.humanoid.WalkSpeed = AR_DEFAULT_SPEED
    end
    stateV1.isBoosting = false
    disconnectAllV1()
    stateV1.cachedChar = nil
end

function AntiRagdollV1.isRunning() return stateV1.active end

local AntiRagdollV2 = {
    Enabled = false,
    Connection = nil,
    ResetCooldown = 0,
}

local function startAntiRagdollV2()
    if AntiRagdollV2.Connection then return end
    AntiRagdollV2.Enabled = true
    local _arv2Acc = 0
    AntiRagdollV2.Connection = RunService.Heartbeat:Connect(function(dt)
        if not AntiRagdollV2.Enabled then return end
        _arv2Acc = _arv2Acc + dt
        if _arv2Acc < 0.033 then return end  -- 30fps cap
        _arv2Acc = 0
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return end
        local state = hum:GetState()
        local now = _tick()
        if state == Enum.HumanoidStateType.Physics or
           state == Enum.HumanoidStateType.Ragdoll or
           state == Enum.HumanoidStateType.FallingDown then
            if now - AntiRagdollV2.ResetCooldown > 0.15 then
                AntiRagdollV2.ResetCooldown = now
                pcall(function()
                    if hum:GetState() == Enum.HumanoidStateType.GettingUp then return end
                    if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return end
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    root.Velocity = _V3zero
                    root.RotVelocity = _V3zero
                    root.AssemblyLinearVelocity = _V3zero
                    root.AssemblyAngularVelocity = _V3zero
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("Motor6D") then obj.Enabled = true end
                        if obj:IsA("Constraint") then obj.Enabled = true end
                    end
                    workspace.CurrentCamera.CameraSubject = hum
                    local PM = LP.PlayerScripts:FindFirstChild("PlayerModule")
                    if PM then
                        local CM = require(PM:FindFirstChild("ControlModule"))
                        if CM then CM:Enable() end
                    end
                    hum.AutoRotate = true
                    hum.PlatformStand = false
                    hum.Sit = false
                end)
            end
        end
    end)
end

local function stopAntiRagdollV2()
    AntiRagdollV2.Enabled = false
    if AntiRagdollV2.Connection then
        AntiRagdollV2.Connection:Disconnect()
        AntiRagdollV2.Connection = nil
    end
    AntiRagdollV2.ResetCooldown = 0
end

function setAntiRagdollMode(mode)
    if AntiRagdollV1.isRunning() then AntiRagdollV1.stop() end
    if AntiRagdollV2.Enabled then stopAntiRagdollV2() end
    antiRagdollMode = mode
    if mode == "v1" then AntiRagdollV1.start()
    elseif mode == "v2" then startAntiRagdollV2() end
    if _G.updateAntiRagdollUI then _G.updateAntiRagdollUI(mode) end
    saveAllSettings()
end

local AntiDieModule = {
    enabled = false,
    healthConn = nil,
    diedConn = nil,
    charConn = nil,
    humanoid = nil,
    _reviving = false,
}

local function disconnectHumanoid()
    if AntiDieModule.healthConn then AntiDieModule.healthConn:Disconnect(); AntiDieModule.healthConn = nil end
    if AntiDieModule.diedConn then AntiDieModule.diedConn:Disconnect(); AntiDieModule.diedConn = nil end
    AntiDieModule.humanoid = nil
end

local function activateOnCharacter(char)
    if not AntiDieModule.enabled then return end
    char = char or LP.Character or LP.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 3)
    if not hum or not AntiDieModule.enabled then return end
    disconnectHumanoid()
    AntiDieModule.humanoid = hum

    pcall(function()
        hum.BreakJointsOnDeath = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
    end)

    AntiDieModule.healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not AntiDieModule.enabled or not hum.Parent then return end
        if hum.Health <= 0 and not AntiDieModule._reviving then
            AntiDieModule._reviving = true
            pcall(function()
                hum.Health = hum.MaxHealth
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                if hum.Health > 0 then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
            task.delay(0.2, function() AntiDieModule._reviving = false end)
        end
    end)

    AntiDieModule.diedConn = hum.Died:Connect(function()
        if not AntiDieModule.enabled or not char.Parent then return end
        if AntiDieModule._reviving then return end
        AntiDieModule._reviving = true
        task.defer(function()
            if not AntiDieModule.enabled or not char.Parent or not hum.Parent then
                AntiDieModule._reviving = false
                return
            end
            pcall(function()
                hum.Health = hum.MaxHealth
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
            AntiDieModule._reviving = false
        end)
    end)
end

function AntiDieModule.start()
    AntiDieModule.enabled = true
    if AntiDieModule.charConn then AntiDieModule.charConn:Disconnect() end
    AntiDieModule.charConn = LP.CharacterAdded:Connect(function(char)
        if AntiDieModule.enabled then task.defer(function() activateOnCharacter(char) end) end
    end)
    task.defer(function() activateOnCharacter(LP.Character) end)
end

function AntiDieModule.stop()
    AntiDieModule.enabled = false
    if AntiDieModule.charConn then AntiDieModule.charConn:Disconnect(); AntiDieModule.charConn = nil end
    local hum = AntiDieModule.humanoid
    disconnectHumanoid()
    if hum and hum.Parent then
        pcall(function()
            hum.BreakJointsOnDeath = true
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end)
    end
end

_G.AntiDie = AntiDieModule

local AntiFlingShieldModule = {
    enabled = false,
    loop = nil,
    velocityThreshold = 80,
}

local function stabilizeRoot(root)
    if not root or not root.Parent then return end
    if batDesyncTpEnabled or autoBatV3Enabled then return end
    local velocity
    local ok = pcall(function() velocity = root.AssemblyLinearVelocity end)
    if not ok or typeof(velocity) ~= "Vector3" then
        local legacyOk
        legacyOk, velocity = pcall(function() return root.Velocity end)
        if not legacyOk or typeof(velocity) ~= "Vector3" then return end
    end
    if velocity.Magnitude <= AntiFlingShieldModule.velocityThreshold then return end
    local stabilized = _V3new(0, velocity.Y, 0)
    pcall(function() root.AssemblyLinearVelocity = stabilized end)
    pcall(function() root.AssemblyAngularVelocity = _V3zero end)
    pcall(function() root.Velocity = stabilized end)
    pcall(function() root.RotVelocity = _V3zero end)
end

function AntiFlingShieldModule.start()
    AntiFlingShieldModule.enabled = true
    if AntiFlingShieldModule.loop then AntiFlingShieldModule.loop:Disconnect() end
    local _afAcc = 0
    AntiFlingShieldModule.loop = RunService.Heartbeat:Connect(function(dt)
        if not AntiFlingShieldModule.enabled then return end
        _afAcc = _afAcc + dt
        if _afAcc < 0.05 then return end   -- 20fps is plenty for stabilization
        _afAcc = 0
        local char = LP.Character
        stabilizeRoot(char and char:FindFirstChild("HumanoidRootPart"))
    end)
end

function AntiFlingShieldModule.stop()
    AntiFlingShieldModule.enabled = false
    if AntiFlingShieldModule.loop then
        AntiFlingShieldModule.loop:Disconnect()
        AntiFlingShieldModule.loop = nil
    end
end

_G.AntiFlingShield = AntiFlingShieldModule

do
    local _ragCountdownRunning = false
    local function _getRagBillboard()
        local char = LP.Character
        if not char then return nil, nil end
        local head = char:FindFirstChild("Head")
        if not head then return nil, nil end
        local pGui = LP.PlayerGui
        local existing = pGui:FindFirstChild("RagCountdownBillboard")
        if existing then existing:Destroy() end
        local bb = Instance.new("BillboardGui")
        bb.Name = "RagCountdownBillboard"
        bb.Size = UDim2.new(0, 84, 0, 42)
        bb.StudsOffset = _V3new(0, 4.5, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = head
        bb.Parent = pGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextScaled = true
        lbl.TextColor3 = selectedColor
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.Text = ""
        lbl.Parent = bb
        local grad = Instance.new("UIGradient", lbl)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, selectedColor),
            ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, selectedColor),
        })
        grad.Rotation = 45
        grad.Offset = Vector2.new(0,0)
        return bb, lbl
    end

    local function _ragPunch(lbl, text)
        if not (lbl and lbl.Parent) then return end
        lbl.Text = text
    end

    local function _startRagCountdown()
        if _ragCountdownRunning then return end
        _ragCountdownRunning = true
        task.spawn(function()
            local bb, lbl = _getRagBillboard()
            if not bb then _ragCountdownRunning = false; return end
            local timeLeft = 2.5
            local step = 0.1
            while timeLeft > 0 and bb.Parent do
                _ragPunch(lbl, string.format("%.1f", timeLeft))
                task.wait(step)
                timeLeft = timeLeft - step
            end
            if bb and bb.Parent then
                _ragPunch(lbl, "READY!")
                task.wait(0.5)
                if bb and bb.Parent then bb:Destroy() end
            end
            _ragCountdownRunning = false
        end)
    end

    -- ── Kick Detector Timer (E01) ────────────────────────────────────────────
    local _kickTimerRunning   = false
    local _kickDetWasCarrying = false

    local function _isCarrying()
        local char = LP.Character
        if not char then return false end
        for _, child in ipairs(char:GetChildren()) do
            local n = child.Name:lower()
            if n:find("brainrot") or n:find("brain") or n:find("animal") or
               n:find("carry") or n:find("stolen") or n:find("held") or n:find("steal") then
                return true
            end
        end
        for attrName, attrValue in pairs(char:GetAttributes()) do
            local n = attrName:lower()
            if (n:find("carrying") or n:find("carry") or n:find("stealing") or
                n:find("isstealing") or n:find("hasbrainrot")) and attrValue == true then
                return true
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed > 0 and hum.WalkSpeed <= 25 and hum.WalkSpeed ~= 16 then
            return true
        end
        return false
    end

    local function _getKickBillboard()
        local char = LP.Character
        if not char then return nil, nil end
        local head = char:FindFirstChild("Head")
        if not head then return nil, nil end
        local pGui = LP.PlayerGui
        local existing = pGui:FindFirstChild("KickDetectorBillboard")
        if existing then existing:Destroy() end
        local bb = Instance.new("BillboardGui")
        bb.Name = "KickDetectorBillboard"
        bb.Size = UDim2.new(0, 84, 0, 28)
        bb.StudsOffset = _V3new(0, 7.0, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = head
        bb.Parent = pGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextScaled = true
        lbl.TextColor3 = selectedColor
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.Text = ""
        lbl.Parent = bb
        local grad = Instance.new("UIGradient", lbl)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   selectedColor),
            ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1,   selectedColor),
        })
        grad.Rotation = 45
        grad.Offset = Vector2.new(0, 0)
        return bb, lbl
    end

    local function _startKickCountdown()
        if _kickTimerRunning then return end
        _kickTimerRunning = true
        task.spawn(function()
            local bb, lbl = _getKickBillboard()
            if not bb then _kickTimerRunning = false; return end
            local duration = 3.0
            local startT   = tick()
            while bb.Parent do
                local remaining = math.max(0, duration - (tick() - startT))
                if remaining <= 0 then break end
                if lbl and lbl.Parent then
                    lbl.Text = string.format("E01 %.2f", remaining)
                end
                task.wait(0.03)
            end
            if lbl and lbl.Parent then
                lbl.Text = "STEAL!"
                local grad = lbl:FindFirstChildOfClass("UIGradient")
                if grad then
                    grad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 255, 100)),
                        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 255, 100)),
                    })
                end
            end
            task.wait(1.5)
            if bb and bb.Parent then bb:Destroy() end
            _kickTimerRunning = false
        end)
    end

    -- Poll for carry state
    task.spawn(function()
        while task.wait(0.1) do
            local carrying = _isCarrying()
            if not _kickDetWasCarrying and carrying then
                _startKickCountdown()
            end
            _kickDetWasCarrying = carrying
        end
    end)
    -- ── end Kick Detector Timer ──────────────────────────────────────────────

    local _wasRagdolled = false
    local _ragDetAcc = 0
    RunService.Heartbeat:Connect(function(dt)
        _ragDetAcc = _ragDetAcc + dt
        if _ragDetAcc < 0.033 then return end  -- 30fps is more than enough
        _ragDetAcc = 0
        local char = LP.Character
        if not char then _wasRagdolled = false; return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then _wasRagdolled = false; return end
        local st = hum:GetState()
        local inRag = st == Enum.HumanoidStateType.Physics
                   or st == Enum.HumanoidStateType.Ragdoll
                   or st == Enum.HumanoidStateType.FallingDown
        if inRag and not _wasRagdolled then
            _wasRagdolled = true
            _startRagCountdown()
        elseif not inRag then
            _wasRagdolled = false
        end
    end)
end

local espHighlightCache = {}
local espBillboardCache = {}
local espTracerCache = {}
local espConn = nil
local _espLastRun = 0
profileImageCache = {}

local function clearESP()
    for plr in pairs(espHighlightCache) do
        pcall(function() espHighlightCache[plr]:Destroy() end)
    end
    for plr in pairs(espBillboardCache) do
        pcall(function() espBillboardCache[plr]:Destroy() end)
    end
    for plr in pairs(espTracerCache) do
        for _, ln in ipairs(espTracerCache[plr]) do
            pcall(function() ln.Visible = false; ln:Remove() end)
        end
    end
    espHighlightCache = {}
    espBillboardCache = {}
    espTracerCache = {}
end

local function makeESPTracers()
    if not (Drawing and type(Drawing.new) == "function") then return nil end
    local color = getThemeColor()
    local outer = Drawing.new("Line")
    outer.Color = color
    outer.Thickness = 2.2
    outer.Transparency = 0.90
    outer.Visible = false
    local mid = Drawing.new("Line")
    mid.Color = color
    mid.Thickness = 1.2
    mid.Transparency = 0.74
    mid.Visible = false
    local core = Drawing.new("Line")
    core.Color = color
    core.Thickness = 0.6
    core.Transparency = 0.10
    core.Visible = false
    return {outer, mid, core}
end

local function updateESP()
    local now = _tick()
    if now - _espLastRun < 0.05 then return end
    _espLastRun = now
    if not espEnabled then clearESP(); return end
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myPos = myRoot.Position
    local myScreenPos, myOnScreen = camera:WorldToViewportPoint(myPos)
    local myVec = Vector2.new(myScreenPos.X, myScreenPos.Y)
    local currentPlayers = _GetPlayersCached()
    local plrSet = {}
    for _, p in ipairs(currentPlayers) do plrSet[p] = true end
    for plr in pairs(espHighlightCache) do
        if not plrSet[plr] then
            pcall(function() espHighlightCache[plr]:Destroy() end)
            espHighlightCache[plr] = nil
        end
    end
    for plr in pairs(espBillboardCache) do
        if not plrSet[plr] then
            pcall(function() espBillboardCache[plr]:Destroy() end)
            espBillboardCache[plr] = nil
        end
    end
    for plr in pairs(espTracerCache) do
        if not plrSet[plr] then
            for _, ln in ipairs(espTracerCache[plr]) do
                pcall(function() ln.Visible = false; ln:Remove() end)
            end
            espTracerCache[plr] = nil
        end
    end
    local color = getThemeColor()
    for _, plr in ipairs(currentPlayers) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then
            if espHighlightCache[plr] then
                pcall(function() espHighlightCache[plr]:Destroy() end)
                espHighlightCache[plr] = nil
            end
            if espBillboardCache[plr] then
                pcall(function() espBillboardCache[plr]:Destroy() end)
                espBillboardCache[plr] = nil
            end
            if espTracerCache[plr] then
                for _, ln in ipairs(espTracerCache[plr]) do
                    pcall(function() ln.Visible = false end)
                end
            end
            continue
        end
        local tRoot = char:FindFirstChild("HumanoidRootPart")
        local tHead = char:FindFirstChild("Head")
        local tHum = char:FindFirstChildOfClass("Humanoid")
        local alive = tRoot and tHead and tHum and tHum.Health > 0
        if alive then
            local hl = espHighlightCache[plr]
            if not hl or not hl.Parent or hl.Parent ~= char then
                if hl then pcall(function() hl:Destroy() end) end
                hl = Instance.new("Highlight")
                hl.Name = "MeridianHubESP"
                hl.FillColor = color
                hl.FillTransparency = 0.72
                hl.OutlineColor = color
                hl.OutlineTransparency = 0.05
                hl.Adornee = char
                hl.Parent = char
                espHighlightCache[plr] = hl
            end
            local bb = espBillboardCache[plr]
            if not bb or not bb.Parent then
                if bb then pcall(function() bb:Destroy() end) end
                bb = Instance.new("BillboardGui")
                bb.Name = "ProfilePic"
                bb.Size = UDim2.new(0, 56, 0, 56)
                bb.StudsOffset = _V3new(0, 3.8, 0)
                bb.Adornee = tHead
                bb.AlwaysOnTop = true
                bb.Parent = tHead
                local img = Instance.new("ImageLabel", bb)
                img.Size = UDim2.new(1, -6, 1, -6)
                img.Position = UDim2.new(0, 3, 0, 3)
                img.BackgroundTransparency = 1
                img.Image = "rbxassetid://0"
                img.ScaleType = Enum.ScaleType.Fit
                local circle = Instance.new("UICorner", img)
                circle.CornerRadius = UDim.new(1, 0)
                local stroke = Instance.new("UIStroke", img)
                stroke.Color = color
                stroke.Thickness = 1.5
                espBillboardCache[plr] = bb
                task.spawn(function()
                    local userId = plr.UserId
                    local url = profileImageCache[userId]
                    if not url then
                        local success, u = pcall(function()
                            return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                        end)
                        if success and u and u ~= "" then
                            url = u
                            profileImageCache[userId] = url
                        else
                            url = "rbxassetid://0"
                        end
                    end
                    if img then img.Image = url end
                end)
            else
                if bb.Adornee ~= tHead then bb.Adornee = tHead end
                bb.Enabled = true
            end
            local lines = espTracerCache[plr]
            if not lines then
                lines = makeESPTracers()
                espTracerCache[plr] = lines or {}
            end
            if lines and #lines > 0 then
                local destPos = tRoot.Position
                local pos, onScreen = camera:WorldToViewportPoint(destPos)
                if onScreen and pos.Z > 0 and myOnScreen then
                    local tVec = Vector2.new(pos.X, pos.Y)
                    for _, ln in ipairs(lines) do
                        ln.From = myVec
                        ln.To = tVec
                        ln.Visible = true
                    end
                else
                    for _, ln in ipairs(lines) do ln.Visible = false end
                end
            end
        else
            if espHighlightCache[plr] then
                pcall(function() espHighlightCache[plr]:Destroy() end)
                espHighlightCache[plr] = nil
            end
            if espBillboardCache[plr] then
                pcall(function() espBillboardCache[plr]:Destroy() end)
                espBillboardCache[plr] = nil
            end
            if espTracerCache[plr] then
                for _, ln in ipairs(espTracerCache[plr]) do
                    pcall(function() ln.Visible = false end)
                end
            end
        end
    end
end

local function startESPLoop()
    if espConn then espConn:Disconnect() end
    -- Heartbeat instead of RenderStepped: ESP has its own 0.05s internal gate,
    -- no reason to block the render thread 60x/sec just to return early.
    espConn = RunService.Heartbeat:Connect(updateESP)
end

local function stopESPLoop()
    if espConn then espConn:Disconnect(); espConn = nil end
    clearESP()
end

function toggleESP(on)
    espEnabled = on
    if on then startESPLoop() else stopESPLoop() end
    if setESPVIsual then setESPVIsual(on) end
end

local _enemySpeedAcc = 0
function updateEnemySpeedLabels()
    _enemySpeedAcc = _enemySpeedAcc + 1
    if _enemySpeedAcc < 6 then return end
    _enemySpeedAcc = 0

    local color = getThemeColor()
    local players = _GetPlayersCached()
    for i = 1, #players do
        local player = players[i]
        if player ~= LP then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local v = hrp.AssemblyLinearVelocity
                local speed = _sqrt(v.X*v.X + v.Z*v.Z)
                local label = enemySpeedLabels[player]
                if not label then
                    local head = char:FindFirstChild("Head")
                    if head then
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 100, 0, 25)
                        bb.StudsOffset = _V3new(0, 5.5, 0)
                        bb.AlwaysOnTop = true
                        bb.Name = "EnemySpeedGui"
                        bb.Parent = head
                        local tl = Instance.new("TextLabel", bb)
                        tl.Size = UDim2.new(1, 0, 1, 0)
                        tl.BackgroundTransparency = 1
                        tl.TextColor3 = color
                        tl.Font = Enum.Font.GothamBlack
                        tl.TextScaled = true
                        tl.TextStrokeTransparency = 0
                        tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        enemySpeedLabels[player] = tl
                        label = tl
                    end
                elseif label.Parent and label.Parent.Parent ~= char then
                    local head = char:FindFirstChild("Head")
                    if head then label.Parent.Parent = head end
                end
                if label then
                    label.Text = string.format("%.1f", speed)
                    if label.TextColor3 ~= color then label.TextColor3 = color end
                end
            else
                local label = enemySpeedLabels[player]
                if label and label.Parent and label.Parent.Parent then label.Parent.Parent = nil end
                enemySpeedLabels[player] = nil
            end
        end
    end
end

function startEnemySpeed()
    if enemySpeedConn then enemySpeedConn:Disconnect() end
    enemySpeedConn = RunService.Heartbeat:Connect(updateEnemySpeedLabels)
end

function stopEnemySpeed()
    if enemySpeedConn then enemySpeedConn:Disconnect(); enemySpeedConn = nil end
end

local function getClosestTargetBody()
    local char = LP.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local rpos = root.Position
    local closest, minDist = nil, _huge
    local plist = _GetPlayersCached()
    for i = 1, #plist do
        local plr = plist[i]
        if plr ~= LP then
            local c = plr.Character
            if c then
                local tRoot = c:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local dx = tRoot.Position.X - rpos.X
                        local dy = tRoot.Position.Y - rpos.Y
                        local dz = tRoot.Position.Z - rpos.Z
                        local d = dx*dx + dy*dy + dz*dz
                        if d < minDist then minDist = d; closest = tRoot end
                    end
                end
            end
        end
    end
    return closest
end

local function _bodyLockTick()
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
    local dist = (target.Position - root.Position).Magnitude
    if dist > bodyLockRange then
        if not hum.AutoRotate then hum.AutoRotate = true end
        return
    end
    if hum.AutoRotate then hum.AutoRotate = false end
    local targetVel = target.AssemblyLinearVelocity
    local speed3 = targetVel.Magnitude
    local predictTime = _clamp(speed3 / 80, 0.08, 0.35)
    local predictedPos = target.Position + targetVel * predictTime
    local targetHead = target.Parent and target.Parent:FindFirstChild("Head")
    local targetHeight = targetHead and targetHead.Position.Y or target.Position.Y
    local myHeight = root.Position.Y + (hum.HipHeight or 0)
    local heightDiff = targetHeight - myHeight
    local verticalCorrection = _clamp(heightDiff * 0.15, -1.5, 1.5)
    local flatTarget = _V3new(predictedPos.X, root.Position.Y + verticalCorrection, predictedPos.Z)
    local toPredict = flatTarget - root.Position
    if toPredict.Magnitude > 0.1 then
        local goalCF = _CFlookAt(root.Position, flatTarget)
        local diffCF = root.CFrame:Inverse() * goalCF
        local _, ry, _ = diffCF:ToEulerAnglesXYZ()
        ry = _clamp(ry, -2.5, 2.5)
        root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(_V3new(0, ry * 42, 0))
    end
end

function startBodyLock()
    if _bodyLockConn then _bodyLockConn:Disconnect() end
    local acc = 0
    _bodyLockConn = RunService.Heartbeat:Connect(function(dt)
        if not bodyLockEnabled then return end
        if _blSuppressCount > 0 then return end
        acc = acc + dt
        if acc < 0.033 then return end
        acc = 0
        _bodyLockTick()
    end)
end

function stopBodyLock()
    if _bodyLockConn then
        _bodyLockConn:Disconnect()
        _bodyLockConn = nil
    end
    local c = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyAngularVelocity = _V3zero
        root.AssemblyLinearVelocity = _V3new(root.AssemblyLinearVelocity.X, -0.1, root.AssemblyLinearVelocity.Z)
    end
    local hum2 = c and c:FindFirstChildOfClass("Humanoid")
    if hum2 then hum2.AutoRotate = true end
end

function _suppressBodyLock()
    _blSuppressCount = _blSuppressCount + 1
    if _blSuppressCount == 1 and bodyLockEnabled then
        _blWasEnabled = true
        stopBodyLock()
        if bodyLockSetVisual then bodyLockSetVisual(false) end
        if _blRestoreTimer then
            task.cancel(_blRestoreTimer)
            _blRestoreTimer = nil
        end
        _blSmoothRestore = false
    end
end

function _unsuppressBodyLock(delayed)
    if _blSuppressCount > 0 then
        _blSuppressCount = _blSuppressCount - 1
    end
    if _blSuppressCount == 0 and _blWasEnabled then
        _blWasEnabled = false
        if _blRestoreTimer then
            pcall(task.cancel, _blRestoreTimer)
            _blRestoreTimer = nil
        end
        local function restore()
            _blRestoreTimer = nil
            if bodyLockEnabled then
                _blSmoothRestore = true
                startBodyLock()
                if bodyLockSetVisual then bodyLockSetVisual(true) end
                task.delay(0.5, function() _blSmoothRestore = false end)
            end
        end
        if delayed then
            _blRestoreTimer = task.delay(1, restore)
        else
            restore()
        end
    end
end

function setupSpeedIndicator(char)
    local head = char:WaitForChild("Head", 5)
    if not head then return end
    local oldBB = head:FindFirstChild("MeridianHubSpeedIndicator")
    if oldBB then oldBB:Destroy() end
    local bb = Instance.new("BillboardGui", head)
    bb.Name = "MeridianHubSpeedIndicator"
    bb.Size = UDim2.new(0, 120, 0, 32)
    bb.StudsOffset = _V3new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    speedLabel = Instance.new("TextLabel", bb)
    speedLabel.Size = UDim2.new(1, 0, 1, 0)
    speedLabel.Position = UDim2.new(0, 0, 0, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Spd: 0.0"
    speedLabel.TextColor3 = getThemeColor()
    speedLabel.Font = Enum.Font.GothamBlack
    speedLabel.TextScaled = true
    speedLabel.TextStrokeTransparency = 0
    speedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    applyShimmerToText(speedLabel, 0.9)

end

local unwalkSavedAnimate = nil

function startUnwalk()
    local c = LP.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then
        for _, t in ipairs(hum:GetPlayingAnimationTracks()) do pcall(function() t:Stop() end) end
    end
    local anim = c:FindFirstChild("Animate")
    if anim then
        unwalkSavedAnimate = anim:Clone()
        anim:Destroy()
    end
end

function stopUnwalk()
    local c = LP.Character
    if c then
        local existing = c:FindFirstChild("Animate")
        if not existing then
            local src = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterCharacterScripts")
            local starterAnim = src and src:FindFirstChild("Animate")
            if starterAnim then
                starterAnim:Clone().Parent = c
            elseif unwalkSavedAnimate then
                unwalkSavedAnimate:Clone().Parent = c
            end
        end
    end
    unwalkSavedAnimate = nil
end

function refreshSpeedModeLabel()
    if modeValLbl then
        if laggerCarryToggled then modeValLbl.Text = "Lagger Carry"
        elseif laggerToggled then modeValLbl.Text = "Lagger"
        elseif speedMode then modeValLbl.Text = "Carry"
        else modeValLbl.Text = "Normal" end
    end
    if setCarryModeVisual then setCarryModeVisual(speedMode) end
    if setLaggerModeVisual then setLaggerModeVisual(laggerToggled) end
    if setLaggerCarryVisual then setLaggerCarryVisual(laggerCarryToggled) end
end

function resetMovementState()
    refreshSpeedModeLabel()
    if mobSetCarry then mobSetCarry(speedMode) end
    if setLaggerModeVisual then setLaggerModeVisual(laggerToggled) end
    if setLaggerCarryVisual then setLaggerCarryVisual(laggerCarryToggled) end
end

function toggleCarryMode()
    if laggerToggled or laggerCarryToggled then
        laggerToggled = false; laggerCarryToggled = false; speedMode = true
    else speedMode = not speedMode end
    resetMovementState()
end

function toggleLaggerCycle()
    if speedMode then
        speedMode = false
        laggerToggled = true
        laggerCarryToggled = false
    elseif laggerToggled then
        speedMode = false
        laggerToggled = false
        laggerCarryToggled = true
    else
        speedMode = true
        laggerToggled = false
        laggerCarryToggled = false
    end
    resetMovementState()
end

alPhase = 1
arPhase = 1

function stopAutoLeft()
    if alConn then alConn:Disconnect(); alConn = nil end
    alPhase = 1
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(_V3zero, false) end
    end
    if autoLeftSetVisual then autoLeftSetVisual(false) end
    if mobSetAutoLeft then mobSetAutoLeft(false) end
    _unsuppressBodyLock(true)
end

function startAutoLeft()
    if autoRightEnabled then
        autoRightEnabled = false
        stopAutoRight()
        if autoRightSetVisual then autoRightSetVisual(false) end
        if mobSetAutoRight then mobSetAutoRight(false) end
    end
    disableAllAimbots()
    _suppressBodyLock()
    if alConn then alConn:Disconnect() end
    alPhase = 1
    -- Snapshot active speed mode so we can restore it after the loop finishes.
    -- Supports carry, lagger, lagger carry, or normal — all handled.
    local _prevSpeedMode        = speedMode
    local _prevLaggerToggled    = laggerToggled
    local _prevLaggerCarryToggled = laggerCarryToggled
    alConn = RunService.Heartbeat:Connect(function()
        if not autoLeftEnabled then return end
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        -- Use getAutoPathSpeed so lagger mode runs at lagger speed mid-loop.
        local spd = getAutoPathSpeed()
        if alPhase == 1 then
            local tgt = _V3new(AP.L1.X, root.Position.Y, AP.L1.Z)
            if (tgt - root.Position).Magnitude < 1 then
                alPhase = 2
                local d = AP.L2 - root.Position
                local mv = _V3new(d.X, 0, d.Z).Unit
                hum:Move(mv, false)
                root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = AP.L1 - root.Position
            local mv = _V3new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif alPhase == 2 then
            local tgt = _V3new(AP.L2.X, root.Position.Y, AP.L2.Z)
            local dist = (tgt - root.Position).Magnitude
            if dist < 1 then
                hum:Move(_V3zero, false)
                root.AssemblyLinearVelocity = _V3zero
                autoLeftEnabled = false
                if alConn then alConn:Disconnect(); alConn = nil end
                alPhase = 1
                -- Restore the speed mode that was active before auto left started.
                speedMode        = _prevSpeedMode
                laggerToggled    = _prevLaggerToggled
                laggerCarryToggled = _prevLaggerCarryToggled
                refreshSpeedModeLabel()
                if autoLeftSetVisual then autoLeftSetVisual(false) end
                if mobSetAutoLeft then mobSetAutoLeft(false) end
                _unsuppressBodyLock(true)
                local facePos = _V3new(AP.L_FACE.X, root.Position.Y, AP.L_FACE.Z)
                if (facePos - root.Position).Magnitude > 0.01 then
                    root.CFrame = _CFnew(root.Position, facePos)
                end
                return
            end
            -- Pre-slow: drop to carry speed 10 studs before destination
            -- so the player arrives already at safe speed, preventing lagback on grab.
            local moveSpd = dist < 10
                and (laggerCarryToggled or laggerToggled and LAGGER_CARRY_SPEED or CS)
                or spd
            local d = AP.L2 - root.Position
            local mv = _V3new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            root.AssemblyLinearVelocity = _V3new(mv.X * moveSpd, root.AssemblyLinearVelocity.Y, mv.Z * moveSpd)
        end
    end)
end

function stopAutoRight()
    if arConn then arConn:Disconnect(); arConn = nil end
    arPhase = 1
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(_V3zero, false) end
    end
    if autoRightSetVisual then autoRightSetVisual(false) end
    if mobSetAutoRight then mobSetAutoRight(false) end
    _unsuppressBodyLock(true)
end

function startAutoRight()
    if autoLeftEnabled then
        autoLeftEnabled = false
        stopAutoLeft()
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        if mobSetAutoLeft then mobSetAutoLeft(false) end
    end
    disableAllAimbots()
    _suppressBodyLock()
    if arConn then arConn:Disconnect() end
    arPhase = 1
    -- Snapshot active speed mode so we can restore it after the loop finishes.
    local _prevSpeedMode        = speedMode
    local _prevLaggerToggled    = laggerToggled
    local _prevLaggerCarryToggled = laggerCarryToggled
    arConn = RunService.Heartbeat:Connect(function()
        if not autoRightEnabled then return end
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        -- Use getAutoPathSpeed so lagger mode runs at lagger speed mid-loop.
        local spd = getAutoPathSpeed()
        if arPhase == 1 then
            local tgt = _V3new(AP.R1.X, root.Position.Y, AP.R1.Z)
            if (tgt - root.Position).Magnitude < 1 then
                arPhase = 2
                local d = AP.R2 - root.Position
                local mv = _V3new(d.X, 0, d.Z).Unit
                hum:Move(mv, false)
                root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = AP.R1 - root.Position
            local mv = _V3new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif arPhase == 2 then
            local tgt = _V3new(AP.R2.X, root.Position.Y, AP.R2.Z)
            local dist = (tgt - root.Position).Magnitude
            if dist < 1 then
                hum:Move(_V3zero, false)
                root.AssemblyLinearVelocity = _V3zero
                autoRightEnabled = false
                if arConn then arConn:Disconnect(); arConn = nil end
                arPhase = 1
                -- Restore the speed mode that was active before auto right started.
                speedMode          = _prevSpeedMode
                laggerToggled      = _prevLaggerToggled
                laggerCarryToggled = _prevLaggerCarryToggled
                refreshSpeedModeLabel()
                if autoRightSetVisual then autoRightSetVisual(false) end
                if mobSetAutoRight then mobSetAutoRight(false) end
                _unsuppressBodyLock(true)
                local facePos = _V3new(AP.R_FACE.X, root.Position.Y, AP.R_FACE.Z)
                if (facePos - root.Position).Magnitude > 0.01 then
                    root.CFrame = _CFnew(root.Position, facePos)
                end
                return
            end
            -- Pre-slow: drop to carry speed 10 studs before destination
            -- so the player arrives already at safe speed, preventing lagback on grab.
            local moveSpd = dist < 10
                and (laggerCarryToggled or laggerToggled and LAGGER_CARRY_SPEED or CS)
                or spd
            local d = AP.R2 - root.Position
            local mv = _V3new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            root.AssemblyLinearVelocity = _V3new(mv.X * moveSpd, root.AssemblyLinearVelocity.Y, mv.Z * moveSpd)
        end
    end)
end

function getClosestTarget()
    local char = LP.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local rpos = root.Position
    local closest, minDist = nil, _huge
    local plist = _GetPlayersCached()
    for i = 1, #plist do
        local plr = plist[i]
        if plr ~= LP then
            local c = plr.Character
            if c then
                local tRoot = c:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local dx = tRoot.Position.X - rpos.X
                        local dy = tRoot.Position.Y - rpos.Y
                        local dz = tRoot.Position.Z - rpos.Z
                        local d = dx*dx + dy*dy + dz*dz
                        if d < minDist then minDist = d; closest = tRoot end
                    end
                end
            end
        end
    end
    return closest
end

function trySwing()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and not isBatTool(currentTool) then return end
        local bat = findBat()
        if bat then
            if bat.Parent ~= char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(bat) end) end
            end
            pcall(function() bat:Activate() end)
        end
    end)
end

function stopAimbotAdapt()
    if _aimbotConn then
        pcall(function() _aimbotConn:Disconnect() end)
        _aimbotConn = nil
    end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = (_prevAutoRotate == nil) and true or _prevAutoRotate
        hum.PlatformStand = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    if root then
        root.AssemblyLinearVelocity = _V3new(0, -0.1, 0)
        root.AssemblyAngularVelocity = _V3zero
    end
    _prevAutoRotate = nil
    lastMoveDir = _V3zero
    _unsuppressBodyLock(true)
end

function startAimbotAdapt()
    if _aimbotConn then return end
    _suppressBodyLock()
    local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum0 then
        if _prevAutoRotate == nil then _prevAutoRotate = hum0.AutoRotate end
        hum0.AutoRotate = false
    end

    local VYSE_HIT_DIST = 15    -- S2: wider hit window than V1's 8
    local _lastPos    = nil
    local _stuckTimer = 0
    local _lastT      = tick()

    _aimbotConn = RunService.RenderStepped:Connect(function()
        if not autoBatEnabled then return end
        pcall(function()
            local c = LP.Character
            if not c then return end
            local root = c:FindFirstChild("HumanoidRootPart")
            local hum  = c:FindFirstChildOfClass("Humanoid")
            if not root or not hum then return end
            hum.AutoRotate = false

            if not c:FindFirstChildOfClass("Tool") then
                local bat = findBat()
                if bat then pcall(function() hum:EquipTool(bat) end) end
            end

            local target = getClosestTarget()
            if not target then trySwing(); return end

            local targetVel = target.AssemblyLinearVelocity
            local myPos     = root.Position
            local targetPos = target.Position
            local predictPos = targetPos + targetVel * 0.14 + target.CFrame.LookVector * 0.3
            local direction  = predictPos - myPos
            local flatDir    = _V3new(direction.X, 0, direction.Z)

            -- S2 fix: near-zero flatDir would stall XZ movement; use LookVector instead
            if flatDir.Magnitude < 0.05 then
                flatDir = root.CFrame.LookVector
            else
                flatDir = flatDir.Unit
            end

            local desiredHeight = targetPos.Y + 5   -- S2: +5 for aggressive height chase
            local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8

            -- Ensure upward push when grounded + force Freefall so physics accepts the write
            if hum.FloorMaterial ~= Enum.Material.Air then
                yVel = math.max(yVel, 13)
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end)
            end
            yVel = _clamp(yVel, -70, 110)

            local _aimSpd = getAimbotSpeed()
            local desiredVel = _V3new(flatDir.X * _aimSpd, yVel, flatDir.Z * _aimSpd)
            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)

            -- Anti-stuck: detect when velocity isn't applying (rotation tracks, body doesn't move)
            local now = tick()
            local dt  = math.max(now - _lastT, 0.001)
            _lastT = now
            if _lastPos then
                local moved = (myPos - _lastPos).Magnitude
                -- less than ~4 studs/s means we're stuck despite having velocity
                if moved < 0.067 * dt * 60 then
                    _stuckTimer = _stuckTimer + dt
                    if _stuckTimer >= 0.25 then
                        -- Physics ownership may have lapsed — force state and hard-write vel
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end)
                        root.AssemblyLinearVelocity = desiredVel
                        _stuckTimer = 0
                    end
                else
                    _stuckTimer = 0
                end
            end
            _lastPos = myPos

            -- Rotation tracking
            local speed3      = targetVel.Magnitude
            local predictTime = _clamp(speed3 / 150, 0.05, 0.2)
            local predictedPos = targetPos + targetVel * predictTime
            local toPredict   = predictedPos - myPos
            if toPredict.Magnitude > 0.1 then
                local goalCF  = _CFlookAt(myPos, predictedPos)
                local diffCF  = root.CFrame:Inverse() * goalCF
                local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
                rx = _clamp(rx, -2.5, 2.5)
                ry = _clamp(ry, -2.5, 2.5)
                rz = _clamp(rz, -2.5, 2.5)
                root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(
                    _V3new(rx * 42, ry * 42, rz * 42)
                )
            end

            if (root.Position - target.Position).Magnitude <= VYSE_HIT_DIST then
                trySwing()
            end
        end)
    end)
end

function disableAutoBat()
    autoBatEnabled = false
    if autoBatSetVisual then autoBatSetVisual(false) end
    if mobSetAutoBat then mobSetAutoBat(false) end
    stopAimbotAdapt()
end

function enableAutoBat()
    if autoLeftEnabled then
        autoLeftEnabled = false
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        stopAutoLeft()
    end
    if autoRightEnabled then
        autoRightEnabled = false
        if autoRightSetVisual then autoRightSetVisual(false) end
        stopAutoRight()
    end
    if batDesyncTpEnabled then toggleBatDesyncTp() end
    if autoBatV2Enabled then disableBatV2() end
    autoBatEnabled = true
    if autoBatSetVisual then autoBatSetVisual(true) end
    if mobSetAutoBat then mobSetAutoBat(true) end
    startAimbotAdapt()
end

-- Akai shared helpers
local AKAI_AB = { SWING_CD=0.08, AB2_SWING_CD=0.35 }

local function _akCleanProxy(st)
    if st.bypassPart then pcall(function() st.bypassPart:Destroy() end) end
    if st.bypassWeld  then pcall(function() st.bypassWeld:Destroy()  end) end
    st.bypassPart = nil; st.bypassWeld = nil
end

local function _akCreateProxy(st)
    _akCleanProxy(st)
    local c   = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local p = Instance.new("Part")
    p.Name = "F1BatAimbotProxy"; p.Size = Vector3.new(1,1,1)
    p.Transparency = 1; p.CanCollide = false; p.Massless = true; p.Parent = c
    local w = Instance.new("Weld")
    w.Part0 = hrp; w.Part1 = p; w.C0 = CFrame.new(0,0,0); w.Parent = p
    st.bypassPart = p; st.bypassWeld = w
end

local function _akGetTarget(st)
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local now = tick()
    if now - st.lastScan <= 0.1 and st.target and st.target.Parent then
        local h = st.target.Parent:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then return st.target end
    end
    st.lastScan = now; st.target = nil
    local closest, minDist = nil, math.huge
    local plist = _GetPlayersCached()
    for i = 1, #plist do
        local plr = plist[i]
        if plr ~= LP and plr.Character then
            local tr  = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tr and hum and hum.Health > 0 then
                local d = (tr.Position - root.Position).Magnitude
                if d < minDist then minDist = d; closest = tr end
            end
        end
    end
    st.target = closest; return st.target
end

local function _akSwing(char, st)
    if st.hittingCD then return end
    st.hittingCD = true
    task.spawn(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        local bat = char:FindFirstChildOfClass("Tool")
        if not bat then
            local bp = LP:FindFirstChild("Backpack")
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    local n = t.Name:lower()
                    if n:find("bat") or n:find("slap") then bat = t; break end
                end
            end
        end
        if bat then
            if bat.Parent ~= char and hum then
                pcall(function() hum:EquipTool(bat) end)
                task.wait(0.05)
            end
            local remote = nil
            for _, d in ipairs(bat:GetDescendants()) do
                if d:IsA("RemoteEvent") then remote = d; break end
            end
            if remote then
                pcall(function() remote:FireServer() end)
                task.wait(0.12)
                pcall(function() remote:FireServer() end)
            else
                pcall(function() bat:Activate() end)
                task.wait(0.12)
                pcall(function() bat:Activate() end)
            end
        end
        task.delay(AKAI_AB.SWING_CD, function() st.hittingCD = false end)
    end)
end

local function _akLoop(char, root, hum, st, mode)
    -- proxy
    if not st.bypassPart or st.bypassPart.Parent ~= char then _akCreateProxy(st) end
    -- equip once
    if not st.equipped then
        st.equipped = true
        if not char:FindFirstChildOfClass("Tool") then
            local bp = LP:FindFirstChildOfClass("Backpack")
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    local n = t.Name:lower()
                    if n:find("bat") or n:find("slap") then
                        pcall(function() hum:EquipTool(t) end); break
                    end
                end
            end
        end
    end
    local target = _akGetTarget(st)
    if not target then
        hum.AutoRotate = true
        root.AssemblyAngularVelocity = Vector3.zero
        return
    end
    local myPos  = root.Position
    local tPos   = target.Position
    if mode == "bypass" then
        hum.AutoRotate = false
        local SPEED   = getAimbotSpeed()
        local F1_DIST = -1.8; local F1_V_OFF = 1.2
        local TURN    = 360;  local MAX_TURN  = 36
        local tVel    = target.AssemblyLinearVelocity
        local lead    = tVel.Magnitude > 1 and (tVel.Unit * 2) or Vector3.zero
        local aimPos  = tPos + lead + Vector3.new(0, F1_V_OFF, 0)
        local look    = aimPos - myPos
        local flat    = Vector3.new(look.X, 0, look.Z)
        if look.Magnitude > 0.01 and flat.Magnitude > 0.01 then
            local yaw   = math.deg(math.atan2(-flat.X, -flat.Z))
            local delta = (yaw - root.Orientation.Y + 180) % 360 - 180
            local abs   = math.abs(delta)
            local boost = 1 + 5 * math.clamp((abs - 20) / 140, 0, 1)
            local rate  = math.clamp(math.rad(delta) * TURN * boost, -MAX_TURN * boost, MAX_TURN * boost)
            local lerp  = math.min((35 + 65 * math.clamp((abs-20)/140,0,1)) * 0.016, 1)
            pcall(function()
                root.AssemblyAngularVelocity = root.AssemblyAngularVelocity:Lerp(Vector3.new(0, rate, 0), lerp)
            end)
        else
            pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
        end
        local dir     = look.Magnitude > 0.01 and look.Unit or Vector3.zero
        local standP  = aimPos - (dir * F1_DIST)
        local mDir    = standP - myPos
        local hDir    = Vector3.new(mDir.X, 0, mDir.Z)
        local hVel    = hDir.Magnitude > 0.1 and hDir.Unit * SPEED or Vector3.zero
        local vVel    = math.abs(mDir.Y) > 0.1 and Vector3.new(0, math.sign(mDir.Y) * 65, 0) or Vector3.new(0,-2,0)
        local targetVelFull = hVel + vVel
        st.smoothVel = (st.smoothVel or Vector3.zero):Lerp(targetVelFull, 0.65)
        if st.bypassPart then st.bypassPart.AssemblyLinearVelocity = st.smoothVel end
        if hDir.Magnitude > 0.5 then hum:Move(hDir.Unit, false) end
        if (tPos - myPos).Magnitude < 6 then _akSwing(char, st) end
    else
        hum.AutoRotate = false
        local SPEED   = getAimbotSpeed()
        local tVel    = target.AssemblyLinearVelocity
        local aimP    = tPos + (tVel * math.clamp(tVel.Magnitude/130, 0.05, 0.15)) + Vector3.new(0,1,0)
        local look    = aimP - myPos
        local flat    = Vector3.new(look.X, 0, look.Z)
        if look.Magnitude > 0.01 and flat.Magnitude > 0.01 then
            local yaw    = math.deg(math.atan2(-flat.X, -flat.Z))
            local yDelta = (yaw - root.Orientation.Y + 180) % 360 - 180
            local pitch  = math.deg(math.atan2(look.Y, flat.Magnitude))
            local pDelta = (pitch - root.Orientation.X + 180) % 360 - 180
            local yRate  = math.clamp(math.rad(yDelta) * 285, -40, 40)
            local pRate  = math.clamp(math.rad(pDelta) * 285, -40, 40)
            local yr     = math.rad(root.Orientation.Y)
            local right  = Vector3.new(math.cos(yr), 0, -math.sin(yr))
            root.AssemblyAngularVelocity = Vector3.new(0, yRate, 0) + (right * pRate)
        else
            root.AssemblyAngularVelocity = Vector3.zero
        end
        local dir   = look.Magnitude > 0.01 and look.Unit or Vector3.new(1,0,0)
        local standP = aimP - (dir * 2) + Vector3.new(0, 1.6, 0)
        local mDir  = standP - myPos
        local hDir  = Vector3.new(mDir.X, 0, mDir.Z)
        local hVel  = hDir.Magnitude > 0.1 and hDir.Unit * SPEED or Vector3.zero
        local vVel  = math.abs(mDir.Y) > 0.1 and Vector3.new(0, math.sign(mDir.Y)*52, 0) or Vector3.new(0,-2,0)
        local targetVelFull = hVel + vVel
        st.smoothVel = (st.smoothVel or Vector3.zero):Lerp(targetVelFull, 0.65)
        root.AssemblyLinearVelocity = st.smoothVel
        if hDir.Magnitude > 0.5 then hum:Move(hDir.Unit, false) end
        if (tPos - myPos).Magnitude < 6 then _akSwing(char, st) end
    end
end

local function _akReset(st)
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero end
    if st.bypassPart then st.bypassPart.AssemblyLinearVelocity = Vector3.zero end
    if hum then hum.AutoRotate = true end
    _akCleanProxy(st)
    st.target = nil; st.equipped = false
end

local function startBatV2Aimbot()
    if _batV2Conn then return end
    _akV2.equipped = false
    _batV2Conn = RunService.RenderStepped:Connect(function()
        if not autoBatV2Enabled then return end
        local char = LP.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        local hum  = char:FindFirstChildOfClass("Humanoid");  if not hum  then return end
        _akLoop(char, root, hum, _akV2, "normal")
    end)
end

local function stopBatV2Aimbot()
    if _batV2Conn then _batV2Conn:Disconnect(); _batV2Conn = nil end
    _akReset(_akV2)
end

function enableBatV2()
    if autoBatV2Enabled then return end
    if autoBatEnabled then disableAutoBat() end
    if batDesyncTpEnabled then toggleBatDesyncTp() end
    if autoLeftEnabled then
        autoLeftEnabled = false
        stopAutoLeft()
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        if mobSetAutoLeft then mobSetAutoLeft(false) end
    end
    if autoRightEnabled then
        autoRightEnabled = false
        stopAutoRight()
        if autoRightSetVisual then autoRightSetVisual(false) end
        if mobSetAutoRight then mobSetAutoRight(false) end
    end
    autoBatV2Enabled = true
    startBatV2Aimbot()
    if autoBatV2SetVisual then autoBatV2SetVisual(true) end
    if batV2FloatingButton then
        local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
        if btnFrame then paintFloatingBtn(btnFrame, true) end
    end
end

function disableBatV2()
    if not autoBatV2Enabled then return end
    autoBatV2Enabled = false
    stopBatV2Aimbot()
    if autoBatV2SetVisual then autoBatV2SetVisual(false) end
    if batV2FloatingButton then
        local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
        if btnFrame then paintFloatingBtn(btnFrame, false) end
    end
end

function toggleBatV2()
    if autoBatV2Enabled then disableBatV2()
    else enableBatV2() end
end

-- ============================================================
-- BYPASS AIMBOT — CLEAN (Bat Bypass: predictive chase)
-- Full replacement: ping-aware velocity prediction, acceleration +
-- air-control handling, direct AssemblyLinearVelocity chase toward
-- the predicted position, angular aim, and timed bat activation.
-- Speed: live-linked to Bat Aimbot Speed / Lagger Aimbot Speed.
-- ============================================================
local startBatV3Aimbot, stopBatV3Aimbot
do
    local _bbZ = {
        targetPlayer = nil, lastTargetPos = nil,
        targetVelocity = Vector3.zero, smoothedVelocity = Vector3.zero,
        velocityHistory = {}, accelerationHistory = {}, aerialVelocityHistory = {},
        previousDirection = nil, lastDirectionChangeTime = 0,
        airborneTime = 0, lastActivationTime = 0,
        currentPing = 0.1, realPingMs = 0,
    }
    local _bbCfg = {
        FOLLOW_SPEED = 60,
        ACTIVATE_DISTANCE = 13,
        MIN_FOLLOW_DISTANCE = 1,
        PREDICTION_TIME = 0.22,
        PREDICT_AHEAD = 3,
        MAX_VELOCITY_CHANGE = 150,
        VELOCITY_SMOOTHING = 0.2,
        MAX_HORIZONTAL_VELOCITY = 80,
        SERVER_TICKRATE = 1 / 60,
        MIN_PING_COMPENSATION = 0.03,
        MAX_PING_COMPENSATION = 0.25,
        ACCELERATION_PREDICTION_WEIGHT = 0.3,
        DIRECTION_CHANGE_DETECTION_TIME = 0.12,
        QUICK_DIRECTION_CHANGE_MULTIPLIER = 1.5,
        GRAVITY = 196.2,
        AIR_CONTROL_FACTOR = 0.8,
        MIN_AIRBORNE_TIME = 0.08,
    }
    local _bbPingToken = 0

    local function _bbAverage(vectors)
        if #vectors == 0 then return Vector3.zero end
        local sum = Vector3.zero
        for _, v in ipairs(vectors) do sum += v end
        return sum / #vectors
    end

    local function _bbPush(history, entry, maxEntries)
        table.insert(history, entry)
        if #history > maxEntries then table.remove(history, 1) end
    end

    local function _bbFindBat()
        local character = LP.Character
        if not character then return nil end
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then
            local n = tool.Name:lower()
            if n:find("bat", 1, true) or n:find("slap", 1, true) then return tool end
        end
        local backpack = LP:FindFirstChildOfClass("Backpack")
        if backpack then
            for _, child in ipairs(backpack:GetChildren()) do
                if child:IsA("Tool") then
                    local n = child.Name:lower()
                    if n:find("bat", 1, true) or n:find("slap", 1, true) then return child end
                end
            end
        end
        return nil
    end

    local function _bbReset()
        local z = _bbZ
        z.targetPlayer = nil
        z.lastTargetPos = nil
        z.targetVelocity = Vector3.zero
        z.smoothedVelocity = Vector3.zero
        z.velocityHistory = {}
        z.accelerationHistory = {}
        z.aerialVelocityHistory = {}
        z.previousDirection = nil
        z.airborneTime = 0
    end

    local function _bbClosestPlayer(rootPart)
        local best, closest = math.huge, nil
        for _, player in ipairs(_GetPlayersCached()) do
            if player ~= LP and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local mag = (rootPart.Position - hrp.Position).Magnitude
                    if mag < best then best = mag; closest = player end
                end
            end
        end
        return closest
    end

    local function _bbAngularAim(rootPart, direction)
        if direction.Magnitude < 0.01 then return end
        local look  = rootPart.CFrame.LookVector
        local dir   = direction.Unit
        local cross = look:Cross(dir)
        local angle = math.acos(math.clamp(look:Dot(dir), -1, 1))
        local axis  = cross.Magnitude > 0.001 and cross.Unit or Vector3.yAxis
        local w     = math.min(angle * 80, 100)
        rootPart.AssemblyAngularVelocity = angle > 0.05 and axis * w or Vector3.zero
    end

    local function _bbUpdatePing()
        local ok, result = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and type(result) == "number" then _bbZ.realPingMs = math.floor(result) end
        _bbZ.currentPing = math.clamp(
            _bbZ.realPingMs / 1000, _bbCfg.MIN_PING_COMPENSATION, _bbCfg.MAX_PING_COMPENSATION)
    end

    startBatV3Aimbot = function()
        if _akV3.conn then return end
        _akV3.equipped = false

        _akV3.conn = RunService.RenderStepped:Connect(function(deltaTime)
            if not autoBatV3Enabled then return end
            local z, zcfg = _bbZ, _bbCfg
            zcfg.FOLLOW_SPEED = getAimbotSpeed()

            local character = LP.Character
            local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
            if not rootPart or not humanoid or humanoid.Health <= 0 then return end
            humanoid.AutoRotate = false

            local tool = character:FindFirstChildOfClass("Tool") or _bbFindBat()
            if tool and tool.Parent ~= character then
                pcall(humanoid.EquipTool, humanoid, tool)
            end

            z.targetPlayer = _bbClosestPlayer(rootPart)
            local tChar = z.targetPlayer and z.targetPlayer.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
            if not tRoot or not tHum or tHum.Health <= 0 then
                _bbReset()
                return
            end

            local position = tRoot.Position
            local dt = math.max(deltaTime, 1 / 240)
            if z.lastTargetPos then
                local tVel = (position - z.lastTargetPos) / dt
                local change = tVel - z.targetVelocity
                if zcfg.MAX_VELOCITY_CHANGE < change.Magnitude then
                    tVel = z.targetVelocity + change.Unit * zcfg.MAX_VELOCITY_CHANGE
                end
                local flat = Vector3.new(tVel.X, 0, tVel.Z)
                if flat.Magnitude > zcfg.MAX_HORIZONTAL_VELOCITY then
                    local capped = flat.Unit * zcfg.MAX_HORIZONTAL_VELOCITY
                    tVel = Vector3.new(capped.X, tVel.Y, capped.Z)
                end
                _bbPush(z.accelerationHistory, (tVel - z.targetVelocity) / dt, 4)
                _bbPush(z.velocityHistory, tVel, 8)
                z.targetVelocity = tVel
                z.smoothedVelocity = z.smoothedVelocity:Lerp(tVel, zcfg.VELOCITY_SMOOTHING)
            end
            z.lastTargetPos = position

            local isAirborne = tHum.FloorMaterial == Enum.Material.Air
            z.airborneTime = isAirborne and z.airborneTime + dt or 0
            if isAirborne and z.airborneTime >= zcfg.MIN_AIRBORNE_TIME then
                _bbPush(z.aerialVelocityHistory, z.targetVelocity, 6)
            elseif not isAirborne then
                z.aerialVelocityHistory = {}
            end

            local smoothed = z.smoothedVelocity
            if isAirborne and #z.aerialVelocityHistory > 0 then
                local avg = _bbAverage(z.aerialVelocityHistory)
                smoothed = Vector3.new(avg.X, z.targetVelocity.Y, avg.Z) * zcfg.AIR_CONTROL_FACTOR
            end

            local quickTurn = false
            local flatTV = Vector3.new(z.targetVelocity.X, 0, z.targetVelocity.Z)
            if flatTV.Magnitude > 5 then
                local unit = flatTV.Unit
                if z.previousDirection and z.previousDirection:Dot(unit) < 0.5 then
                    quickTurn = tick() - z.lastDirectionChangeTime < zcfg.DIRECTION_CHANGE_DETECTION_TIME
                    z.lastDirectionChangeTime = tick()
                end
                z.previousDirection = unit
            end

            local predictionTime = z.currentPing + zcfg.SERVER_TICKRATE
            if quickTurn then predictionTime *= zcfg.QUICK_DIRECTION_CHANGE_MULTIPLIER end

            local predicted = position
                + smoothed * predictionTime
                + _bbAverage(z.accelerationHistory)
                    * zcfg.ACCELERATION_PREDICTION_WEIGHT
                    * predictionTime * predictionTime * 0.5

            local leadTime = zcfg.PREDICTION_TIME * 1.1
            local leadPos
            if isAirborne then
                leadPos = predicted + smoothed * leadTime
                    + Vector3.new(0, -0.5 * zcfg.GRAVITY * leadTime * leadTime, 0)
            else
                leadPos = predicted + smoothed * leadTime
            end
            local flatSm = Vector3.new(smoothed.X, 0, smoothed.Z)
            if flatSm.Magnitude > 1 then
                leadPos += flatSm.Unit * zcfg.PREDICT_AHEAD
            end

            local toTarget = leadPos - rootPart.Position
            _bbAngularAim(rootPart, toTarget)

            local inRange = (position - rootPart.Position).Magnitude <= zcfg.ACTIVATE_DISTANCE
            if inRange then inRange = tick() - z.lastActivationTime >= 0.3 end
            if inRange then
                if tool then pcall(tool.Activate, tool) end
                z.lastActivationTime = tick()
            end

            local flatTo = Vector3.new(toTarget.X, 0, toTarget.Z)
            if zcfg.MIN_FOLLOW_DISTANCE < toTarget.Magnitude then
                rootPart.AssemblyLinearVelocity = toTarget.Unit * zcfg.FOLLOW_SPEED
                if flatTo.Magnitude > 0.5 then humanoid:Move(flatTo.Unit, false) end
            else
                rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y * 0.5, 0)
                humanoid:Move(Vector3.zero, false)
            end
        end)

        -- ping sampler lives only while the bypass aimbot is on
        -- (spawned AFTER the connection exists so its loop condition holds)
        _bbPingToken += 1
        local myToken = _bbPingToken
        task.spawn(function()
            while _akV3.conn and _bbPingToken == myToken do
                pcall(_bbUpdatePing)
                task.wait(0.5)
            end
        end)
    end

    stopBatV3Aimbot = function()
        if _akV3.conn then _akV3.conn:Disconnect(); _akV3.conn = nil end
        _bbPingToken += 1
        _akV3.hittingCD = false
        _bbReset()
        _bbZ.lastActivationTime = 0
        local char = LP.Character
        if char then
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            if hum2 then hum2.AutoRotate = true end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
        _akV3.target = nil
        _akV3.equipped = false
    end
end

function enableBatV3()
    if autoBatV3Enabled then return end
    if autoBatEnabled then disableAutoBat() end
    if autoBatV2Enabled then disableBatV2() end
    if batDesyncTpEnabled then toggleBatDesyncTp() end
    if autoLeftEnabled then
        autoLeftEnabled = false; stopAutoLeft()
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        if mobSetAutoLeft then mobSetAutoLeft(false) end
    end
    if autoRightEnabled then
        autoRightEnabled = false; stopAutoRight()
        if autoRightSetVisual then autoRightSetVisual(false) end
        if mobSetAutoRight then mobSetAutoRight(false) end
    end
    autoBatV3Enabled = true
    startBatV3Aimbot()
    if autoBatV3SetVisual then autoBatV3SetVisual(true) end
    if mobSetAutoBat then mobSetAutoBat(isAimbotEnabled()) end
end

function disableBatV3()
    if not autoBatV3Enabled then return end
    autoBatV3Enabled = false
    stopBatV3Aimbot()
    if autoBatV3SetVisual then autoBatV3SetVisual(false) end
    if mobSetAutoBat then mobSetAutoBat(isAimbotEnabled()) end
end

function isAimbotEnabled()
    return (batAimbotVariant == "bypass" and autoBatV3Enabled)
        or (batAimbotVariant == "v2" and autoBatV2Enabled)
        or autoBatEnabled
end

local function updateTpBatButtonWithAntiDie(state)
    if tpBatFloatingButton then
        local btnFrame = tpBatFloatingButton:FindFirstChild("Frame")
        if btnFrame then
            local label = btnFrame:FindFirstChild("TextLabel")
            local stroke = btnFrame:FindFirstChildOfClass("UIStroke")
            if state then
                btnFrame.BackgroundColor3 = getThemeColor()
                if label then
                    label.Text = "TP\nBAT"
                    label.TextColor3 = Color3.fromRGB(0,0,0)
                end
                if stroke then
                    stroke.Color = Color3.fromRGB(255, 215, 0)
                    stroke.Thickness = 2.5
                end
            else
                if label then label.Text = "TP\nBAT" end
                paintFloatingBtn(btnFrame, batDesyncTpEnabled)
            end
        end
    end
end

-- ============================================================
-- TP BAT — CLEAN (Alvaro TP) — full replacement
-- Teleports onto the nearest enemy every Heartbeat, locks the
-- camera, hits with the bat. Recovery loop + desync spam while ON.
-- ============================================================

-- State kept for compat with the rest of main
local batDesyncTpEnabled    = false
local batDesyncTpSetVisual  = nil
local _tpBatUnwalkForced    = false
local tpBatEnabled          = false

do
    -- ========================================================
    -- CLEAN TP BAT (Alvaro TP) — full replacement of the old V1–V5 logic
    -- Each Heartbeat: teleport onto nearest enemy, camera lock, bat hit.
    -- Extras: character recovery loop + network desync spam while ON.
    -- ========================================================
    local localPlayer = LP

    local desyncLoopRunning = false
    local recoveryThread    = nil
    local networkSpamThread = nil
    local batDesyncTpConn   = nil
    local payloadNested     = nil
    local payloadBlockList  = nil

    _G.AlvaroTP = _G.AlvaroTP or {
        conn = nil, on = false, h = nil, hrp = nil,
        hittingCooldown = false, _charConn = nil,
    }

    -- --------------------------------------------------------
    -- Character recovery loop
    -- --------------------------------------------------------
    local function startCharacterRecoveryLoop()
        if recoveryThread then return end
        recoveryThread = task.spawn(function()
            while batDesyncTpEnabled do
                pcall(function()
                    local character = localPlayer.Character
                    if not character then
                        task.wait(0.1)
                        return
                    end
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    local hrp      = character:FindFirstChild("HumanoidRootPart")
                    if humanoid then
                        if humanoid.Health <= 0 then humanoid.Health = humanoid.MaxHealth end
                        if humanoid.PlatformStand then humanoid.PlatformStand = false end
                        if humanoid.Sit then humanoid.Sit = false end
                        local st = humanoid:GetState()
                        if st == Enum.HumanoidStateType.Physics
                            or st == Enum.HumanoidStateType.Ragdoll
                            or st == Enum.HumanoidStateType.FallingDown then
                            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                            humanoid:ChangeState(Enum.HumanoidStateType.Running)
                        end
                    end
                    if hrp and sethiddenproperty then
                        pcall(sethiddenproperty, hrp, "PhysicsRepRootPart", nil)
                    end
                    for _, d in ipairs(character:GetDescendants()) do
                        if d:IsA("BasePart") then d.CanCollide = false end
                    end
                end)
                task.wait(0.05)
            end
            recoveryThread = nil
        end)
    end

    local function stopCharacterRecoveryLoop()
        if recoveryThread then
            pcall(task.cancel, recoveryThread)
            recoveryThread = nil
        end
    end

    -- --------------------------------------------------------
    -- Network desync spam
    -- --------------------------------------------------------
    local function createNestedPayload()
        if payloadNested then return payloadNested end
        local rootTbl = {}
        local cursor  = rootTbl
        for _ = 1, 12 do
            local nested = {}
            cursor[1] = nested
            cursor = nested
        end
        payloadNested = rootTbl
        return rootTbl
    end

    local function createBlockListPayload()
        if payloadBlockList then return payloadBlockList end
        local nested = createNestedPayload()
        local list = table.create(800)
        for i = 1, 300 do list[i] = nested end
        payloadBlockList = list
        return list
    end

    local function setOutgoingBandwidthLimit(limit)
        pcall(function()
            game:GetService("NetworkClient"):SetOutgoingKBPSLimit(limit)
        end)
    end

    local function sendBlockListPayload()
        pcall(function()
            local ps = game:GetService("Players")
            if ps and ps:FindFirstChild("SetPlayerBlockList") then
                ps.SetPlayerBlockList:FireServer(createBlockListPayload())
            end
        end)
    end

    local function startNetworkSpamLoop()
        if networkSpamThread then return end
        networkSpamThread = task.spawn(function()
            task.wait(0.05)
            while batDesyncTpEnabled do
                setOutgoingBandwidthLimit(12000)
                sendBlockListPayload()
                task.wait(0.15)
            end
            setOutgoingBandwidthLimit(0)
            networkSpamThread = nil
        end)
    end

    local function stopNetworkSpamLoop()
        if networkSpamThread then
            pcall(task.cancel, networkSpamThread)
            networkSpamThread = nil
        end
        setOutgoingBandwidthLimit(0)
    end

    -- --------------------------------------------------------
    -- Bat + target helpers
    -- --------------------------------------------------------
    local function findAndEquipBat()
        local character = localPlayer.Character
        if not character then return nil end
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") then
                local n = child.Name:lower()
                if n:find("bat") or n:find("slap") then return child end
            end
        end
        local backpack = localPlayer:FindFirstChild("Backpack")
        if not backpack then return nil end
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") then
                local n = child.Name:lower()
                if n:find("bat") or n:find("slap") then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        pcall(function() humanoid:EquipTool(child) end)
                    end
                    return child
                end
            end
        end
        return nil
    end

    local function tryHitBatDesync()
        if desyncLoopRunning then return end
        desyncLoopRunning = true
        pcall(function()
            local bat = findAndEquipBat()
            if not bat then return end
            bat:Activate()
            local remoteEvent = bat:FindFirstChildWhichIsA("RemoteEvent")
            if remoteEvent then remoteEvent:FireServer() end
        end)
        task.delay(0.08, function() desyncLoopRunning = false end)
    end

    local function findNearestOpponent(rootPart)
        local best, closestPlayer = math.huge, nil
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player ~= localPlayer and player.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local mag = (rootPart.Position - hrp.Position).Magnitude
                if mag < best then best = mag; closestPlayer = player end
            end
        end
        return closestPlayer, best
    end

    local function teleportToTarget(myRoot, targetRoot)
        pcall(function()
            if myRoot.SetNetworkOwner then myRoot:SetNetworkOwner(nil) end
        end)
        task.wait()
        myRoot.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 2.5, 0))
        myRoot.AssemblyLinearVelocity = targetRoot.AssemblyLinearVelocity
        pcall(function()
            if myRoot.SetNetworkOwner then myRoot:SetNetworkOwner(localPlayer) end
        end)
    end

    -- --------------------------------------------------------
    -- Main tick
    -- --------------------------------------------------------
    local function updateBatDesyncTeleport()
        if not batDesyncTpEnabled then return end
        local character = localPlayer.Character
        local hrp       = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then return end

        local bat = findAndEquipBat()
        if bat and bat.Parent ~= character then
            pcall(function() humanoid:EquipTool(bat) end)
        end

        local player, distance = findNearestOpponent(hrp)
        if not player or distance > 100 then return end
        local targetRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        teleportToTarget(hrp, targetRoot)

        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.new(cam.CFrame.Position, targetRoot.Position)
        end

        tryHitBatDesync()

        pcall(function()
            for _, d in ipairs(character:GetDescendants()) do
                if d:IsA("BasePart") then d.CanCollide = false end
            end
        end)
    end

    -- --------------------------------------------------------
    -- Start / Stop (core)
    -- --------------------------------------------------------
    local function startAlvaroTP()
        if batDesyncTpConn then
            batDesyncTpConn:Disconnect()
            batDesyncTpConn = nil
        end
        batDesyncTpEnabled = true
        _G.AlvaroTP.on = true
        _G.AlvaroTP.conn = nil
        desyncLoopRunning = false
        local character = localPlayer.Character
        if character then
            _G.AlvaroTP.h   = character:FindFirstChildOfClass("Humanoid")
            _G.AlvaroTP.hrp = character:FindFirstChild("HumanoidRootPart")
        end
        batDesyncTpConn = RunService.Heartbeat:Connect(updateBatDesyncTeleport)
        _G.AlvaroTP.conn = batDesyncTpConn
        startCharacterRecoveryLoop()
        startNetworkSpamLoop()
        if _G.AmbitiousTPBatSetVisual then _G.AmbitiousTPBatSetVisual(true) end
    end

    local function stopAlvaroTP()
        batDesyncTpEnabled = false
        _G.AlvaroTP.on = false
        if batDesyncTpConn then
            batDesyncTpConn:Disconnect()
            batDesyncTpConn = nil
        end
        _G.AlvaroTP.conn = nil
        _G.AlvaroTP.hittingCooldown = false
        desyncLoopRunning = false
        stopCharacterRecoveryLoop()
        stopNetworkSpamLoop()
        local hrp = _G.AlvaroTP.hrp
        if hrp and hrp.Parent then
            pcall(function()
                if hrp.SetNetworkOwner then hrp:SetNetworkOwner(localPlayer) end
            end)
        end
        if _G.AmbitiousTPBatSetVisual then _G.AmbitiousTPBatSetVisual(false) end
    end

    -- --------------------------------------------------------
    -- Public API (names kept so the rest of main keeps working)
    -- --------------------------------------------------------
    function _G.AmbitiousStartTPBat()
        if batDesyncTpEnabled and batDesyncTpConn then return end
        -- TP bat forces Unwalk on (and remembers it so Stop can undo it)
        if not unwalkEnabled then
            startUnwalk()
            unwalkEnabled = true
            _tpBatUnwalkForced = true
            if setUnwalkVisual then setUnwalkVisual(true) end
        end
        tpBatEnabled = true
        _G.AmbitiousTPBatOn = true
        startAlvaroTP()
        return true
    end

    function _G.AmbitiousStopTPBat()
        tpBatEnabled = false
        _G.AmbitiousTPBatOn = false
        stopAlvaroTP()
        if _tpBatUnwalkForced then
            stopUnwalk()
            unwalkEnabled = false
            _tpBatUnwalkForced = false
            if setUnwalkVisual then setUnwalkVisual(false) end
        end
    end

    function _G.AmbitiousToggleTPBat()
        if batDesyncTpEnabled then
            _G.AmbitiousStopTPBat()
        else
            _G.AmbitiousStartTPBat()
        end
    end

    -- Single TP bat now — kept as a no-op so old callers don't error.
    function _G.AmbitiousSetTPBatVersion()
        return 1
    end

    _G.AlvaroTPBat = {
        toggle    = _G.AmbitiousToggleTPBat,
        start     = _G.AmbitiousStartTPBat,
        stop      = _G.AmbitiousStopTPBat,
        getStatus = function() return _G.AlvaroTP.on end,
    }

    -- --------------------------------------------------------
    -- Shift releases mouse lock while ON, respawn re-arm
    -- --------------------------------------------------------
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if _G.AlvaroTP.on then
            if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
                pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
            end
        end
    end)

    if _G.AlvaroTP._charConn then
        pcall(function() _G.AlvaroTP._charConn:Disconnect() end)
        _G.AlvaroTP._charConn = nil
    end

    local function updateAlvaroCharacterReferences(character)
        task.wait(0.15)
        _G.AlvaroTP.h   = character and character:FindFirstChildOfClass("Humanoid") or nil
        _G.AlvaroTP.hrp = character and character:FindFirstChild("HumanoidRootPart") or nil
        if batDesyncTpEnabled and not batDesyncTpConn then
            startAlvaroTP()
        end
    end

    _G.AlvaroTP._charConn = localPlayer.CharacterAdded:Connect(function(character)
        pcall(function() updateAlvaroCharacterReferences(character) end)
    end)
    if localPlayer.Character then
        task.spawn(function()
            pcall(function() updateAlvaroCharacterReferences(localPlayer.Character) end)
        end)
    end
end -- end do-block

_G.AmbitiousTPBatOn = false

-- ============================================================
-- [14] MANUAL TOGGLE
-- ============================================================
function _G.AmbitiousToggleTPBatManual()
    _G.AmbitiousTPBatSilent = false

    if _G.AmbitiousBatAimbotV2On then
        if _G.AmbitiousStopBatAimbotV2 then
            _G.AmbitiousStopBatAimbotV2()
        end
        if _G.AmbitiousStartTPBat then
            _G.AmbitiousStartTPBat()
        end
        return
    end

    if _G.AmbitiousToggleTPBat then
        _G.AmbitiousToggleTPBat()
    elseif _G.AmbitiousStartTPBat and _G.AmbitiousStopTPBat then
        if _G.AmbitiousTPBatOn then
            _G.AmbitiousStopTPBat()
        else
            _G.AmbitiousStartTPBat()
        end
    end
end

-- ============================================================
-- BRIDGE — keeps the old TP bat API working for the rest of main
-- ============================================================

-- No-collision hooks the new logic expects (ref-counted)
do
    local owners, conn = {}, nil
    _G.AmbitiousNoCollisionAcquire = function(tag)
        owners[tag] = true
        if conn then return end
        local cachedChar, parts, nextRefresh = nil, {}, 0
        conn = RunService.Stepped:Connect(function()
            local c = LP.Character
            if not c then return end
            local now = os.clock()
            if c ~= cachedChar or now >= nextRefresh then
                cachedChar, nextRefresh = c, now + 0.5
                table.clear(parts)
                for _, d in ipairs(c:GetDescendants()) do
                    if d:IsA("BasePart") then parts[#parts + 1] = d end
                end
            end
            for i = 1, #parts do
                local d = parts[i]
                if d.CanCollide then d.CanCollide = false end
            end
        end)
    end
    _G.AmbitiousNoCollisionRelease = function(tag)
        owners[tag] = nil
        if next(owners) == nil and conn then
            conn:Disconnect()
            conn = nil
        end
    end
end

-- Called by the new logic on start (true) and stop (false)
_G.AmbitiousTPBatSetVisual = function(on)
    on = on and true or false
    batDesyncTpEnabled = on
    if batDesyncTpSetVisual then batDesyncTpSetVisual(on) end
    updateTpBatButtonWithAntiDie(on)

    if not on then
        pcall(function()
            local char = LP.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = true; hum.PlatformStand = false end
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                if sethiddenproperty then sethiddenproperty(root, "PhysicsRepRootPart", nil) end
            end
        end)
    end
end

function startBatDesyncTp()
    if _G.AmbitiousStartTPBat then _G.AmbitiousStartTPBat() end
end

function stopBatDesyncTp()
    if _G.AmbitiousStopTPBat then _G.AmbitiousStopTPBat() end
end

function toggleBatDesyncTp()
    if batDesyncTpEnabled then
        stopBatDesyncTp()
    else
        stopAllExclusiveModes()
        startBatDesyncTp()
    end
    if batDesyncTpSetVisual then batDesyncTpSetVisual(batDesyncTpEnabled) end
    saveAllSettings()
end

function findBat()
    local char = LP.Character
    if not char then return nil end
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        local t = char:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
            local t = bp:FindFirstChild(name)
            if t and t:IsA("Tool") then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(t) end) end
                return t
            end
        end
    end
    for _, ch in ipairs(char:GetChildren()) do
        if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then
            return ch
        end
    end
    return nil
end

function isBatTool(tool)
    if not tool then return false end
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        if tool.Name == name then return true end
    end
    return tool.Name:lower():find("bat") or tool.Name:lower():find("slap")
end

function findBatForCounter()
    local char = LP.Character
    if not char then return nil end
    local backpack = LP:FindFirstChildOfClass("Backpack")
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        local tool = char:FindFirstChild(name) or (backpack and backpack:FindFirstChild(name))
        if tool then return tool end
    end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and (child.Name:lower():find("bat") or child.Name:lower():find("slap")) then
            return child
        end
    end
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and (child.Name:lower():find("bat") or child.Name:lower():find("slap")) then
                return child
            end
        end
    end
    return nil
end

function swingBatForCounter(bat, character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if bat.Parent ~= character and humanoid then
        pcall(function() humanoid:EquipTool(bat) end)
        task.wait(0.05)
    end
    local remote = bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
    if remote and remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer() end)
        task.wait(0.1)
        pcall(function() remote:FireServer() end)
    else
        pcall(function() bat:Activate() end)
        task.wait(0.1)
        pcall(function() bat:Activate() end)
    end
end

batCounterDebounce = false

function stopBatCounter()
    if Conns.batCounter then
        Conns.batCounter:Disconnect()
        Conns.batCounter = nil
    end
    batCounterDebounce = false
end

function startBatCounter()
    if Conns.batCounter then return end
    local _bcAcc = 0
    Conns.batCounter = RunService.Heartbeat:Connect(function(dt)
        if not batCounterEnabled then return end
        if batCounterDebounce then return end
        _bcAcc = _bcAcc + dt
        if _bcAcc < 0.05 then return end  -- 20fps, state changes aren't sub-frame
        _bcAcc = 0
        local character = LP.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            batCounterDebounce = true
            _suppressBodyLock()
            task.spawn(function()
                task.wait(0.15)
                local bat = findBatForCounter()
                if bat then swingBatForCounter(bat, character) end
                task.wait(0.3)
                batCounterDebounce = false
                _unsuppressBodyLock(true)
            end)
        end
    end)
end

function findMedusa()
    local c = LP.Character
    if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("medusa") or n:find("head") or n:find("stone") then return t end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                if n:find("medusa") or n:find("head") or n:find("stone") then return t end
            end
        end
    end
    return nil
end

function useMedusaCounter()
    if medusaDebounce then return end
    if _tick() - medusaLastUsed < MEDUSA_COOLDOWN then return end
    local c = LP.Character
    if not c then return end
    medusaDebounce = true
    local med = findMedusa()
    if not med then medusaDebounce = false; return end
    if med.Parent ~= c then
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2:EquipTool(med) end
    end
    pcall(function() med:Activate() end)
    medusaLastUsed = _tick()
    medusaDebounce = false
end

function onAnchorChanged(part)
    return part:GetPropertyChangedSignal("Anchored"):Connect(function()
        if medusaCounterEnabled and part.Anchored and part.Transparency == 1 then useMedusaCounter() end
    end)
end

function setupMedusaCounter(char)
    for _, c in pairs(Conns.anchor) do pcall(function() c:Disconnect() end) end
    Conns.anchor = {}
    if not char or not medusaCounterEnabled then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(Conns.anchor, onAnchorChanged(part))
        end
    end
    table.insert(Conns.anchor, char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then
            table.insert(Conns.anchor, onAnchorChanged(part))
        end
    end))
end

function stopMedusaCounter()
    for _, c in pairs(Conns.anchor) do pcall(function() c:Disconnect() end) end
    Conns.anchor = {}
end

local DROP_ASCEND_DURATION = 0.22
local DROP_ASCEND_SPEED = 160
local _dropConn = nil

function stopDropBrainrot()
    dropActive = false
    if _dropConn then
        _dropConn:Disconnect()
        _dropConn = nil
    end
    for _, t in ipairs(dropConnections) do
        if type(t) == "thread" then pcall(task.cancel, t)
        elseif type(t) == "RBXScriptConnection" then pcall(t.Disconnect, t) end
    end
    dropConnections = {}
    local c = LP.Character
    if c then
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = _V3zero end
    end
    if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
    if mobSetDropBR then mobSetDropBR(false) end
end

function runDropBrainrot()
    if dropActive then return end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    if dropMode == 1 then
        local speedH = 0
        if root then
            local vel = root.AssemblyLinearVelocity
            speedH = _V3new(vel.X, 0, vel.Z).Magnitude
        end
        local cooldown = (speedH > 5) and 0.6 or 0.25
        if _tick() - lastDropTime < cooldown then return end
        lastDropTime = _tick()
        dropActive = true
        if dropBrainrotSetVisual then dropBrainrotSetVisual(true) end
        if mobSetDropBR then mobSetDropBR(true) end
        local wasAutoBat = false
        if autoBatEnabled then
            wasAutoBat = true
            disableAutoBat()
            if autoBatSetVisual then autoBatSetVisual(false) end
            if mobSetAutoBat then mobSetAutoBat(false) end
        end
        local function finishDrop(threadRef)
            if threadRef and dropConnections then
                for i = #dropConnections, 1, -1 do
                    if dropConnections[i] == threadRef then
                        table.remove(dropConnections, i)
                        break
                    end
                end
            end
            dropActive = false
            local c = LP.Character
            if c then
                local r = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChildOfClass("Humanoid")
                if r then
                    r.AssemblyLinearVelocity = _V3zero
                    r.AssemblyAngularVelocity = _V3zero
                    if r.Position.Y < -100 then
                        r.CFrame = _CFnew(r.Position.X, 5, r.Position.Z)
                    end
                    local rp = RaycastParams.new()
                    rp.FilterDescendantsInstances = {c}
                    rp.FilterType = Enum.RaycastFilterType.Exclude
                    local rr = workspace:Raycast(r.Position, _V3new(0, -2000, 0), rp)
                    if rr then
                        local off = (h and h.HipHeight or 2) + (r.Size.Y / 2)
                        r.CFrame = _CFnew(r.Position.X, rr.Position.Y + off, r.Position.Z)
                    end
                    if h and h.Health > 0 then h:ChangeState(Enum.HumanoidStateType.Running) end
                end
            end
            if wasAutoBat then
                enableAutoBat()
                if autoBatSetVisual then autoBatSetVisual(true) end
                if mobSetAutoBat then mobSetAutoBat(true) end
            end
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
        end
        local flingThread = nil
        flingThread = task.spawn(function()
            local startTime = _tick()
            while dropActive and (_tick() - startTime) < 0.25 do
                RunService.Heartbeat:Wait()
                local c = LP.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if not r then break end
                local vel = r.AssemblyLinearVelocity
                vel = _V3new(0, vel.Y, 0)
                r.AssemblyLinearVelocity = vel * 10000 + _V3new(0, 10000, 0)
                RunService.RenderStepped:Wait()
                if r and r.Parent then r.AssemblyLinearVelocity = vel end
                RunService.Stepped:Wait()
                if r and r.Parent then r.AssemblyLinearVelocity = vel + _V3new(0, 0.1, 0) end
            end
            finishDrop(flingThread)
        end)
        table.insert(dropConnections, flingThread)
        task.delay(0.35, function()
            if dropActive then finishDrop(flingThread) end
        end)
        return
    end
    dropActive = true
    if dropBrainrotSetVisual then dropBrainrotSetVisual(true) end
    if mobSetDropBR then mobSetDropBR(true) end
    local t0 = _tick()
    if _dropConn then _dropConn:Disconnect() end
    _dropConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            dropActive = false
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
            return
        end
        if not dropActive then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
            return
        end
        if _tick() - t0 >= DROP_ASCEND_DURATION then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            pcall(function()
                local rp = RaycastParams.new()
                rp.FilterDescendantsInstances = {c}
                rp.FilterType = Enum.RaycastFilterType.Exclude
                local rr = workspace:Raycast(r.Position, _V3new(0, -3000, 0), rp)
                if rr then
                    local hum2 = c:FindFirstChildOfClass("Humanoid")
                    local off = ((hum2 and hum2.HipHeight) or 2) + (r.Size.Y / 2)
                    r.CFrame = _CFnew(r.Position.X, rr.Position.Y + off, r.Position.Z)
                    r.AssemblyLinearVelocity = _V3zero
                    r.AssemblyAngularVelocity = _V3zero
                end
                if hum2 and hum2.Health > 0 then hum2:ChangeState(Enum.HumanoidStateType.Running) end
            end)
            dropActive = false
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
            return
        end
        local lv = r.AssemblyLinearVelocity
        r.AssemblyLinearVelocity = _V3new(lv.X, DROP_ASCEND_SPEED, lv.Z)
    end)
end

function executeDropWithToggle(setVisual)
    if dropActive then return end
    task.spawn(function()
        if setVisual then setVisual(true) end
        runDropBrainrot()
        while dropActive do task.wait() end
        task.wait(0.1)
        if setVisual then setVisual(false) end
    end)
end

function applyAntiLagDerender(obj)
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("AnimationController") or obj:IsA("Animator") then
            for _, t in ipairs(obj:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end
        end
    end)
end

function enableAntiLag()
    antiLagEnabled = true
    task.spawn(function()
        local descs = workspace:GetDescendants()
        local i = 0
        local total = #descs
        while i < total and antiLagEnabled do
            for _ = 1, 200 do
                i = i + 1
                if i > total then break end
                applyAntiLagDerender(descs[i])
            end
            task.wait()
        end
    end)
    if antiLagDescConn then antiLagDescConn:Disconnect() end
    antiLagDescConn = workspace.DescendantAdded:Connect(function(obj)
        if antiLagEnabled then applyAntiLagDerender(obj) end
    end)
end

function disableAntiLag()
    antiLagEnabled = false
    if antiLagDescConn then antiLagDescConn:Disconnect(); antiLagDescConn = nil end
end

CUSTOM_FOV_BIND = "MeridianCustomFOV"

function enableCustomFov()
    local cam = workspace.CurrentCamera
    if cam and origFOV == nil then origFOV = cam.FieldOfView end
    fovEnabled = true
    if cam then
        pcall(function() cam.FieldOfViewMode = Enum.FieldOfViewMode.Diagonal end)
        pcall(function() cam.FieldOfView = fovValue end)
    end
    if customFovConn then customFovConn:Disconnect(); customFovConn = nil end
    pcall(function() RunService:UnbindFromRenderStep(CUSTOM_FOV_BIND) end)
    local prio = 200
    pcall(function() prio = Enum.RenderPriority.Camera.Value + 10 end)
    local ok = pcall(function()
        RunService:BindToRenderStep(CUSTOM_FOV_BIND, prio, function()
            if not fovEnabled then return end
            local c = workspace.CurrentCamera
            if c and c.FieldOfView ~= fovValue then
                c.FieldOfView = fovValue
            end
        end)
    end)
    if not ok then
        customFovConn = RunService.RenderStepped:Connect(function()
            if not fovEnabled then
                if customFovConn then customFovConn:Disconnect(); customFovConn = nil end
                return
            end
            local c = workspace.CurrentCamera
            if c then c.FieldOfView = fovValue end
        end)
    end
end

function disableCustomFov()
    fovEnabled = false
    pcall(function() RunService:UnbindFromRenderStep(CUSTOM_FOV_BIND) end)
    if customFovConn then customFovConn:Disconnect(); customFovConn = nil end
    local cam = workspace.CurrentCamera
    if cam then
        pcall(function() cam.FieldOfViewMode = Enum.FieldOfViewMode.Vertical end)
        pcall(function() cam.FieldOfView = origFOV or 70 end)
    end
end

function applyStretchFOV(val)
    local cam = workspace.CurrentCamera
    if cam then pcall(function() cam.FieldOfView = val end) end
end

function enableStretch()
    if stretchConn then return end
    stretchEnabled = true
    local cam = workspace.CurrentCamera
    if not cam then return end
    origFOV = cam.FieldOfView or 70
    applyStretchFOV(stretchFOV)
    -- Merged stretchConn + stretchFovConn into one RenderStepped instead of two
    stretchConn = RunService.RenderStepped:Connect(function()
        if not stretchEnabled then
            stretchConn:Disconnect()
            stretchConn = nil
            if stretchFovConn then stretchFovConn:Disconnect(); stretchFovConn = nil end
            return
        end
        local c = workspace.CurrentCamera
        if c then
            c.CFrame = c.CFrame * _CFnew(0,0,0,1,0,0,0,0.7,0,0,0,1)
            applyStretchFOV(stretchFOV)
        end
    end)
    stretchFovConn = nil  -- unified into stretchConn above
end

function disableStretch()
    stretchEnabled = false
    if stretchConn then stretchConn:Disconnect(); stretchConn = nil end
    if stretchFovConn then stretchFovConn:Disconnect(); stretchFovConn = nil end
    local cam = workspace.CurrentCamera
    if cam then pcall(function() cam.FieldOfView = origFOV or 70 end) end
end

local function saveLightingState()
    if _originalLighting then return end
    _originalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        Ambient = Lighting.Ambient,
        ColorCorrection = nil,
        Bloom = nil,
    }
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("ColorCorrectionEffect") then
            _originalLighting.ColorCorrection = {
                Enabled = e.Enabled,
                Brightness = e.Brightness,
                Contrast = e.Contrast,
                Saturation = e.Saturation,
                TintColor = e.TintColor,
            }
        elseif e:IsA("BloomEffect") then
            _originalLighting.Bloom = {
                Enabled = e.Enabled,
                Intensity = e.Intensity,
                Size = e.Size,
                Threshold = e.Threshold,
            }
        end
    end
end

local function restoreLightingState()
    if not _originalLighting then return end
    local old = _originalLighting
    Lighting.Brightness = old.Brightness
    Lighting.ClockTime = old.ClockTime
    Lighting.OutdoorAmbient = old.OutdoorAmbient
    Lighting.GlobalShadows = old.GlobalShadows
    Lighting.FogEnd = old.FogEnd
    Lighting.FogStart = old.FogStart
    Lighting.FogColor = old.FogColor
    Lighting.Ambient = old.Ambient
    if old.ColorCorrection then
        local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc then
            cc.Enabled = old.ColorCorrection.Enabled
            cc.Brightness = old.ColorCorrection.Brightness
            cc.Contrast = old.ColorCorrection.Contrast
            cc.Saturation = old.ColorCorrection.Saturation
            cc.TintColor = old.ColorCorrection.TintColor
        end
    end
    if old.Bloom then
        local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
        if bloom then
            bloom.Enabled = old.Bloom.Enabled
            bloom.Intensity = old.Bloom.Intensity
            bloom.Size = old.Bloom.Size
            bloom.Threshold = old.Bloom.Threshold
        end
    end
end

SKY_PRESETS_LIST = {"Off","Night","Aurora","Sunset","Galaxy","Cyber","Sakura","Pink Night","Blood Moon","Emerald Dawn","Volcanic","Arctic","Midnight Ocean","Vaporwave","Toxic","Solar Eclipse","Hellscape","Heaven","Storm","Sunrise","Deep Space","Lavender Dream","Inferno","Mint Sky"}

SKY_PRESETS = {
    ["Off"]={kind="off"},
    ["Night"]={clock=22,brightness=2,ambient={110,100,130},outAmb={120,110,140},sky={stars=4000,moon=18,sun=0,moonTex=true},atm={dens=0.45,color={120,60,180},decay={60,20,100},glare=0.5,haze=1.2}},
    ["Aurora"]={clock=14,brightness=3,ambient={150,120,150},outAmb={160,130,150},atm={dens=0.55,color={255,80,200},decay={255,20,150},glare=2.5,haze=3},clouds={cover=0.7,dens=0.7,color={255,240,250}}},
    ["Sunset"]={clock=17.2,brightness=2.5,ambient={170,120,100},outAmb={180,130,110},sky={stars=0,sun=25,moon=0},atm={dens=0.5,color={255,130,60},decay={255,80,30},glare=2,haze=2.5},clouds={cover=0.55,dens=0.55,color={255,200,140}}},
    ["Galaxy"]={clock=0,brightness=1.5,ambient={70,60,100},outAmb={80,70,110},sky={stars=10000,moon=30,sun=0},atm={dens=0.15,color={40,20,80},decay={20,10,50},glare=0.3,haze=0.5}},
    ["Cyber"]={clock=21,brightness=2.2,ambient={90,130,170},outAmb={100,140,180},sky={stars=2000,moon=12},atm={dens=0.4,color={0,200,255},decay={150,0,255},glare=2,haze=2},clouds={cover=0.4,dens=0.6,color={100,200,255}}},
    ["Sakura"]={clock=11,brightness=3.5,ambient={170,150,160},outAmb={180,160,170},sky={sun=8},atm={dens=0.3,color={255,200,220},decay={255,170,200},glare=1,haze=1.5},clouds={cover=0.6,dens=0.4,color={255,250,252}}},
    ["Pink Night"]={clock=23,brightness=2.2,ambient={120,60,110},outAmb={140,70,120},sky={stars=5000,moon=22,sun=0,moonTex=true},atm={dens=0.5,color={255,80,180},decay={140,30,100},glare=0.7,haze=1.4},clouds={cover=0.3,dens=0.5,color={180,90,150}}},
    ["Blood Moon"]={clock=22.5,brightness=1.6,ambient={130,40,40},outAmb={150,50,50},sky={stars=1500,moon=28,sun=0,moonTex=true},atm={dens=0.6,color={220,30,30},decay={120,10,10},glare=1.4,haze=2},clouds={cover=0.5,dens=0.7,color={120,30,30}}},
    ["Emerald Dawn"]={clock=6.5,brightness=2.8,ambient={130,170,140},outAmb={140,180,150},sky={sun=18,moon=0,stars=0},atm={dens=0.4,color={80,200,140},decay={40,150,90},glare=1.8,haze=2.2},clouds={cover=0.5,dens=0.5,color={200,255,220}}},
    ["Volcanic"]={clock=19,brightness=2,ambient={180,80,40},outAmb={200,90,50},sky={stars=200,sun=12,moon=0},atm={dens=0.75,color={255,60,0},decay={180,20,0},glare=3,haze=3.5},clouds={cover=0.8,dens=0.9,color={120,40,20}}},
    ["Arctic"]={clock=9,brightness=3.2,ambient={200,220,235},outAmb={210,230,245},sky={sun=10,stars=0,moon=0},atm={dens=0.3,color={180,220,255},decay={140,200,240},glare=1.5,haze=1.8},clouds={cover=0.7,dens=0.6,color={250,253,255}}},
    ["Midnight Ocean"]={clock=1.5,brightness=1.7,ambient={60,90,130},outAmb={70,100,140},sky={stars=6000,moon=24,sun=0,moonTex=true},atm={dens=0.5,color={20,60,140},decay={10,30,90},glare=0.6,haze=1.5}},
    ["Vaporwave"]={clock=19.5,brightness=2.4,ambient={180,120,200},outAmb={190,130,210},sky={stars=1000,moon=14},atm={dens=0.45,color={255,100,220},decay={120,60,255},glare=2.2,haze=2.4},clouds={cover=0.55,dens=0.55,color={200,150,255}}},
    ["Toxic"]={clock=13,brightness=2.5,ambient={140,180,80},outAmb={150,190,90},atm={dens=0.55,color={100,220,40},decay={60,150,20},glare=1.8,haze=2.6},clouds={cover=0.65,dens=0.7,color={180,255,120}}},
    ["Solar Eclipse"]={clock=12,brightness=0.9,ambient={50,40,60},outAmb={60,50,70},sky={stars=3500,sun=22,moon=0},atm={dens=0.5,color={255,140,40},decay={30,20,40},glare=2.8,haze=1.8}},
    ["Hellscape"]={clock=18,brightness=1.8,ambient={200,60,30},outAmb={220,70,40},sky={stars=100,sun=30,moon=0},atm={dens=0.85,color={255,30,0},decay={120,0,0},glare=3.5,haze=4},clouds={cover=0.95,dens=0.95,color={80,20,10}}},
    ["Heaven"]={clock=12,brightness=4,ambient={240,235,210},outAmb={250,245,220},sky={sun=16,moon=0,stars=0},atm={dens=0.25,color={255,250,220},decay={255,240,200},glare=3,haze=1.5},clouds={cover=0.85,dens=0.5,color={255,255,255}}},
    ["Storm"]={clock=15,brightness=1.4,ambient={90,90,110},outAmb={100,100,120},sky={stars=0,sun=6,moon=0},atm={dens=0.65,color={80,90,120},decay={40,50,80},glare=0.5,haze=3},clouds={cover=0.95,dens=0.95,color={60,65,80}}},
    ["Sunrise"]={clock=6.2,brightness=2.8,ambient={220,180,130},outAmb={230,190,140},sky={sun=22,stars=0,moon=0},atm={dens=0.45,color={255,180,100},decay={255,140,80},glare=2.4,haze=2.2},clouds={cover=0.4,dens=0.4,color={255,220,180}}},
    ["Deep Space"]={clock=0,brightness=1,ambient={30,25,50},outAmb={40,35,60},sky={stars=15000,moon=0,sun=0},atm={dens=0.08,color={15,5,40},decay={5,0,20},glare=0.2,haze=0.3}},
    ["Lavender Dream"]={clock=18.5,brightness=2.6,ambient={180,160,220},outAmb={190,170,230},sky={stars=800,moon=16,sun=0},atm={dens=0.4,color={200,160,255},decay={160,120,220},glare=1.4,haze=1.8},clouds={cover=0.55,dens=0.5,color={220,200,255}}},
    ["Inferno"]={clock=17.5,brightness=2.2,ambient={220,100,40},outAmb={235,110,50},sky={sun=26,moon=0,stars=0},atm={dens=0.6,color={255,90,20},decay={200,40,0},glare=3,haze=3.2},clouds={cover=0.7,dens=0.7,color={200,80,40}}},
    ["Mint Sky"]={clock=10,brightness=3.2,ambient={180,230,210},outAmb={190,240,220},sky={sun=10},atm={dens=0.32,color={150,255,210},decay={100,220,180},glare=1.6,haze=1.6},clouds={cover=0.55,dens=0.45,color={240,255,250}}},
}

local function _vC3(t) return Color3.fromRGB(t[1], t[2], t[3]) end

function _v4mpClearSky()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:GetAttribute("_AdaptDuelsSky") then
            pcall(function() child:Destroy() end)
        end
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for _, child in ipairs(terrain:GetChildren()) do
            if child:GetAttribute("_AdaptDuelsSky") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

function applyCustomSky(mode)
    _v4mpClearSky()
    local preset = SKY_PRESETS[mode]
    if not preset or preset.kind == "off" then
        Lighting.ClockTime = 14
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.fromRGB(127,127,127)
        Lighting.Ambient = Color3.fromRGB(127,127,127)
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = true
        skyTheme = "Off"
        return
    end
    Lighting.FogStart = 0
    Lighting.FogEnd = 100000
    Lighting.FogColor = Color3.fromRGB(200,200,200)
    Lighting.ColorShift_Top = Color3.fromRGB(0,0,0)
    Lighting.ColorShift_Bottom = Color3.fromRGB(0,0,0)
    Lighting.GlobalShadows = true
    Lighting.ClockTime = preset.clock or 14
    Lighting.Brightness = preset.brightness or 2
    if preset.outAmb then Lighting.OutdoorAmbient = _vC3(preset.outAmb) end
    if preset.ambient then Lighting.Ambient = _vC3(preset.ambient) end
    if preset.sky then
        local skyInst = Instance.new("Sky")
        skyInst:SetAttribute("_AdaptDuelsSky", true)
        if preset.sky.stars then skyInst.StarCount = preset.sky.stars end
        if preset.sky.moon then skyInst.MoonAngularSize = preset.sky.moon end
        if preset.sky.sun then skyInst.SunAngularSize = preset.sky.sun end
        if preset.sky.moonTex then skyInst.MoonTextureId = "rbxasset://sky/moon.jpg" end
        skyInst.Parent = Lighting
    end
    if preset.atm then
        local atm = Instance.new("Atmosphere")
        atm:SetAttribute("_AdaptDuelsSky", true)
        atm.Density = preset.atm.dens or 0.3
        atm.Color = _vC3(preset.atm.color)
        atm.Decay = _vC3(preset.atm.decay)
        atm.Glare = preset.atm.glare or 1
        atm.Haze = preset.atm.haze or 1
        atm.Parent = Lighting
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if preset.clouds and terrain then
        local clouds = Instance.new("Clouds")
        clouds:SetAttribute("_AdaptDuelsSky", true)
        clouds.Cover = preset.clouds.cover or 0.5
        clouds.Density = preset.clouds.dens or 0.5
        clouds.Color = _vC3(preset.clouds.color)
        clouds.Parent = terrain
    end
    skyTheme = mode
end

-- Keeps the saved sky alive: the game can wipe Lighting children or rewrite
-- ClockTime after load, which made the theme look like it never saved.
-- Global table on purpose (no new top-level locals).
SkyWatch = SkyWatch or { running = false }
function SkyWatch.ours()
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:GetAttribute("_AdaptDuelsSky") then return true end
    end
    return false
end
function SkyWatch.start()
    if SkyWatch.running then return end
    SkyWatch.running = true
    task.spawn(function()
        while SkyWatch.running do
            task.wait(1.5)
            pcall(function()
                if skyTheme == "Off" then return end
                local preset = SKY_PRESETS[skyTheme]
                if not preset or preset.kind == "off" then return end
                local wantsObjects = preset.sky or preset.atm
                if wantsObjects and not SkyWatch.ours() then
                    applyCustomSky(skyTheme)
                elseif not neonWeatherEnabled and preset.clock
                    and math.abs(Lighting.ClockTime - preset.clock) > 0.05 then
                    Lighting.ClockTime = preset.clock
                end
            end)
        end
    end)
end
SkyWatch.start()

-- ── Bat / Medusa skins + custom sounds ───────────────────────────────
-- Single global table on purpose: zero new top-level locals.
SkinSys = {
    bat = {
        match = function(n) n = n:lower(); return n:find("bat") ~= nil or n:find("slap") ~= nil end,
        order = {"Off", "DiamondSword", "Katana"},
        skins = {
            DiamondSword = {
                label = "Diamond Sword",
                mesh  = "rbxassetid://8827558932",
                tex   = "rbxassetid://8827558969",
                scale = Vector3.new(0.2, 0.2, 0.2),
                c0    = CFrame.new(-0.05, -0.1, -0.12) * CFrame.Angles(math.rad(90), math.rad(180), 300),
                view  = 4.9,
            },
            Katana = {
                label = "Katana",
                mesh  = "rbxassetid://13528902482",
                tex   = "rbxassetid://13528902373",
                scale = Vector3.new(1.4, 1.4, 1.4),
                c0    = CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(270), math.rad(180), math.rad(180)),
                view  = 6.6,
            },
        },
        sound = { id = "rbxassetid://5713085119", skip = 0.2, doublePlay = false, delay = nil },
    },
    medusa = {
        match = function(n) return n:lower():find("medusa") ~= nil end,
        order = {"Off", "Skull", "GoldenDesertEagle"},
        skins = {
            Skull = {
                label = "Skull",
                mesh  = "rbxassetid://2050312704",
                tex   = "rbxassetid://2050313393",
                scale = Vector3.new(1, 1, 1),
                c0    = CFrame.new(0, 0.65, -0.4) * CFrame.Angles(math.rad(330), 0, 0),
                view  = 4.2,
            },
            GoldenDesertEagle = {
                label = "Golden Desert Eagle",
                mesh  = "rbxassetid://430251413",
                tex   = "rbxassetid://435840335",
                scale = Vector3.new(0.01, 0.01, 0.01),
                c0    = CFrame.new(0, 0, -0.8) * CFrame.Angles(math.rad(330), math.rad(180), 0),
                view  = 3.0,
                sound = { id = "rbxassetid://3102797479", skip = 0, doublePlay = true, delay = 0.5 },
            },
        },
    },
    state  = setmetatable({}, {__mode = "k"}),
    hooked = setmetatable({}, {__mode = "k"}),
    conns  = {},
}

function SkinSys.label(cat, key)
    if key == "Off" then return "Off" end
    local s = SkinSys[cat].skins[key]
    return s and s.label or "Off"
end

function SkinSys.play(entry)
    local cs, data = entry.sound, entry.data
    if not cs or not cs.Parent then return end
    if entry.timer then pcall(task.cancel, entry.timer); entry.timer = nil end
    pcall(function()
        cs:Stop()
        cs.TimePosition = data.skip or 0
        cs.Volume = 1
        cs:Play()
    end)
    if data.doublePlay and data.delay then
        entry.timer = task.delay(data.delay, function()
            entry.timer = nil
            if cs and cs.Parent then
                pcall(function()
                    cs:Stop()
                    cs.TimePosition = data.skip or 0
                    cs.Volume = 1
                    cs:Play()
                end)
            end
        end)
    end
end

function SkinSys.hookSound(entry, snd)
    if not snd:IsA("Sound") then return end
    if snd.Name == "CustomSound" then return end
    if SkinSys.hooked[snd] then return end
    if entry.muted[snd] ~= nil then return end
    entry.muted[snd] = snd.Volume
    SkinSys.hooked[snd] = true
    local function trigger()
        if snd.Playing or snd.TimePosition > 0 then
            pcall(function() snd.Volume = 0; snd:Stop() end)
            SkinSys.play(entry)
        end
    end
    table.insert(entry.conns, snd:GetPropertyChangedSignal("Playing"):Connect(trigger))
    table.insert(entry.conns, snd:GetPropertyChangedSignal("TimePosition"):Connect(trigger))
    if snd.Playing then trigger() end
end

function SkinSys.remove(tool)
    local st = SkinSys.state[tool]
    if not st then return end
    SkinSys.state[tool] = nil
    for _, c in ipairs(st.conns) do pcall(function() c:Disconnect() end) end
    if st.timer then pcall(task.cancel, st.timer) end
    for snd, vol in pairs(st.muted) do
        SkinSys.hooked[snd] = nil
        pcall(function() snd.Volume = vol end)
    end
    for inst, tr in pairs(st.hidden) do
        pcall(function() inst.Transparency = tr end)
    end
    if st.part then pcall(function() st.part:Destroy() end) end
    if st.sound then pcall(function() st.sound:Destroy() end) end
end

function SkinSys.apply(tool, cat, key)
    local st = SkinSys.state[tool]
    if st and st.key == key and st.part and st.part.Parent then return end
    SkinSys.remove(tool)
    local skin = SkinSys[cat].skins[key]
    if not skin then return end
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
    if not handle then return end

    local sdata = skin.sound or SkinSys[cat].sound
    st = { key = key, hidden = {}, muted = {}, conns = {}, data = sdata }
    SkinSys.state[tool] = st

    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
            st.hidden[d] = d.Transparency
            d.Transparency = 1
        end
    end

    local part = Instance.new("Part")
    part.Name = "_MeridianSkin"
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 0
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
    local mesh = Instance.new("SpecialMesh", part)
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = skin.mesh
    mesh.TextureId = skin.tex
    mesh.Scale = skin.scale
    local weld = Instance.new("Weld", part)
    weld.Part0 = handle
    weld.Part1 = part
    weld.C0 = skin.c0
    part.Parent = tool
    st.part = part

    if sdata then
        local cs = Instance.new("Sound")
        cs.Name = "CustomSound"
        cs.SoundId = sdata.id
        cs.Volume = 1
        cs.Looped = false
        cs.Parent = handle
        st.sound = cs

        for _, d in ipairs(tool:GetDescendants()) do SkinSys.hookSound(st, d) end
        table.insert(st.conns, tool.DescendantAdded:Connect(function(d) SkinSys.hookSound(st, d) end))
    end
end

function SkinSys.refreshTool(tool)
    if not tool:IsA("Tool") then return end
    for _, cat in ipairs({"bat", "medusa"}) do
        if SkinSys[cat].match(tool.Name) then
            local key = (cat == "bat") and batSkin or medusaSkin
            if key == "Off" then SkinSys.remove(tool) else SkinSys.apply(tool, cat, key) end
            return
        end
    end
end

function SkinSys.refresh()
    local char = LP.Character
    local bp = LP:FindFirstChildOfClass("Backpack")
    for _, holder in ipairs({char, bp}) do
        if holder then
            for _, t in ipairs(holder:GetChildren()) do
                pcall(SkinSys.refreshTool, t)
            end
        end
    end
end

function SkinSys.watch()
    for _, c in ipairs(SkinSys.conns) do pcall(function() c:Disconnect() end) end
    SkinSys.conns = {}
    local function hook(holder)
        if not holder then return end
        table.insert(SkinSys.conns, holder.ChildAdded:Connect(function(t)
            task.defer(function() pcall(SkinSys.refreshTool, t) end)
        end))
    end
    hook(LP.Character)
    hook(LP:FindFirstChildOfClass("Backpack"))
    SkinSys.refresh()
end

function SkinSys.step(cat, dir)
    local order = SkinSys[cat].order
    local cur = (cat == "bat") and batSkin or medusaSkin
    local idx = 1
    for i, k in ipairs(order) do if k == cur then idx = i; break end end
    idx = idx + dir
    if idx < 1 then idx = #order end
    if idx > #order then idx = 1 end
    local key = order[idx]
    if cat == "bat" then batSkin = key else medusaSkin = key end
    SkinSys.refresh()
    return SkinSys.label(cat, key)
end

LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    SkinSys.watch()
end)
LP.ChildAdded:Connect(function(c)
    if c:IsA("Backpack") then task.defer(SkinSys.watch) end
end)
task.defer(SkinSys.watch)
-- ─────────────────────────────────────────────────────────────────────

local function applyNeonWeather()
    if not neonWeatherEnabled then
        restoreLightingState()
        return
    end
    if not _originalLighting then saveLightingState() end
    Lighting.Brightness = 3.5
    Lighting.ClockTime = 20
    Lighting.OutdoorAmbient = Color3.fromRGB(20, 40, 80)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 300
    Lighting.FogStart = 0
    Lighting.FogColor = Color3.fromRGB(0, 80, 200)
    Lighting.Ambient = Color3.fromRGB(30, 60, 120)
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Parent = Lighting
    end
    cc.Enabled = true
    cc.Brightness = 0.2
    cc.Contrast = 0.15
    cc.Saturation = 0.15
    cc.TintColor = Color3.fromRGB(180, 180, 190)
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    bloom.Enabled = true
    bloom.Intensity = 0.6
    bloom.Size = 25
    bloom.Threshold = 0.8
end

function toggleNeonWeather(state)
    if state == nil then
        neonWeatherEnabled = not neonWeatherEnabled
    else
        neonWeatherEnabled = state
    end
    applyNeonWeather()
    if setNeonWeatherVisual then setNeonWeatherVisual(neonWeatherEnabled) end
end

function paintFloatingBtn(btnFrame, active)
    if not btnFrame then return end
    local bg = btnFrame:FindFirstChild("BtnGrad")
    local label = btnFrame:FindFirstChild("TextLabel")
    local stroke = btnFrame:FindFirstChildOfClass("UIStroke")
    btnFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
    if active then
        local c = getThemeColor()
        if bg then
            bg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, c:Lerp(Color3.new(1,1,1), 0.55)),
                ColorSequenceKeypoint.new(0.45, c),
                ColorSequenceKeypoint.new(1.00, c:Lerp(Color3.new(0,0,0), 0.35)),
            })
        end
        if label then label.TextColor3 = Color3.fromRGB(255,255,255) end
        if stroke then
            stroke.Color = c
            stroke.Thickness = 1.5
            stroke.Transparency = 0.1
        end
    else
        if bg then
            bg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(252,252,253)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(233,233,236)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(168,168,176)),
            })
        end
        if label then label.TextColor3 = Color3.fromRGB(32,32,40) end
        if stroke then
            stroke.Color = Color3.fromRGB(120,120,128)
            stroke.Thickness = 1
            stroke.Transparency = 0.55
        end
    end
end

function applyFloatingButtonScale()
    for _, uiScale in ipairs(_floatingUIScales) do
        if uiScale and uiScale.Parent then
            uiScale.Scale = floatingButtonScale
        end
    end
end

local function drag(f)
    local dn, ds, sp, di = false, nil, nil, nil
    local endConn = nil
    local function stopDrag()
        dn = false
        di = nil
        if endConn then
            endConn:Disconnect()
            endConn = nil
        end
    end
    f.InputBegan:Connect(function(i)
        if uiLocked then return end
        if _isDraggingButton then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dn = true; ds = i.Position; sp = f.Position
            if endConn then endConn:Disconnect() end
            endConn = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then stopDrag() end
            end)
        end
    end)
    f.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
    f.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then di = i end
    end)
    UIS.InputChanged:Connect(function(i)
        if i == di and dn then
            if uiLocked then stopDrag(); return end
            if _isDraggingButton then return end
            if not ds or not sp then return end
            local nX = sp.X.Offset + (i.Position.X - ds.X)
            local nY = sp.Y.Offset + (i.Position.Y - ds.Y)
            f.Position = UDim2.new(sp.X.Scale, nX, sp.Y.Scale, nY)
        end
    end)
end

function setupMovementAndIndicators(char)
    if steppedConn then steppedConn:Disconnect(); steppedConn = nil end
    if movementLoop then movementLoop:Disconnect(); movementLoop = nil end

    local ccAcc = 0
    steppedConn = RunService.Heartbeat:Connect(function(dt)
        ccAcc = ccAcc + dt
        if ccAcc < 0.05 then return end
        ccAcc = 0
        local plist = _GetPlayersCached()
        for i = 1, #plist do
            local p = plist[i]
            if p ~= LP then
                local ch = p.Character
                if ch then
                    local parts = ch:GetChildren()
                    for j = 1, #parts do
                        local part = parts[j]
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end
    end)

    local _speedDisplayValue = 0
    local _lastSpeedShown    = -1
    local SPEED_COUNT_RATE   = 400  -- units/sec  (60 ÷ 0.15 ≈ 400 → full ramp in ~0.15 s)

    -- Adapt-style smooth speed: lerped current speed that ramps toward target.
    -- Resets to 0 on grab (WalkSpeed drop) so there's never an instant jump
    -- that triggers the game's velocity-based TP-back detection.
    local _moveLerpSpeed     = 0
    local _prevWS            = 999   -- last frame's WalkSpeed for pickup detection

    movementLoop = RunService.RenderStepped:Connect(function(dt)
        local char2 = LP.Character
        if not char2 then return end
        local hum = char2:FindFirstChildOfClass("Humanoid")
        local hrp = char2:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end

        -- WatchPickup: detect WalkSpeed transition from >25 → ≤25 (player grabbed).
        -- Reset lerp to 0 so carry speed ramps smoothly from standstill, same as Adapt.
        local curWS = hum.WalkSpeed or 16
        if curWS <= 25 and _prevWS > 25 then
            _moveLerpSpeed = 0
        end
        _prevWS = curWS

        if not autoBatEnabled and not autoLeftEnabled and not autoRightEnabled
           and not autoBatV2Enabled and not autoBatV3Enabled and not batDesyncTpEnabled then
            if _isRagdollState(hum) then
                lastMoveDir = _V3zero
                _moveLerpSpeed = 0
                local lv = hrp:FindFirstChild("_MeridianSpeedLV")
                if lv then lv.Enabled = false end
            else
                local md = hum.MoveDirection
                local targetSpd = getActiveMoveSpeed()
                local dir = nil
                if md.Magnitude > 0 then
                    lastMoveDir = md
                    dir = md
                elseif lastMoveDir.Magnitude > 0 then
                    for key in pairs(MOVE_KEYS) do
                        if UIS:IsKeyDown(key) then dir = lastMoveDir; break end
                    end
                end
                -- Ramp up smoothly (Adapt lerp pattern): SPEED_COUNT_RATE units/sec ramp up,
                -- instant snap down so stopping feels responsive.
                if dir then
                    if targetSpd > _moveLerpSpeed then
                        _moveLerpSpeed = math.min(targetSpd, _moveLerpSpeed + SPEED_COUNT_RATE * dt)
                    else
                        _moveLerpSpeed = targetSpd
                    end
                else
                    _moveLerpSpeed = 0
                end
                _applyVelocitySpeed(dir, _moveLerpSpeed, hrp)
            end
        else
            -- Auto bat / bat TP / auto path is running — disable LV, let them own the HRP.
            _moveLerpSpeed = 0
            local lv = hrp:FindFirstChild("_MeridianSpeedLV")
            if lv then lv.Enabled = false end
        end

        if speedLabel then
            local v = hrp.AssemblyLinearVelocity
            local s = _sqrt(v.X*v.X + v.Z*v.Z)
            if s < 0.05 then s = 0 end
            -- Count effect: display ramps toward actual speed at SPEED_COUNT_RATE units/sec.
            -- Any movement (even tiny) counts up; any stop counts down — never snaps instantly.
            if s > _speedDisplayValue then
                _speedDisplayValue = math.min(s, _speedDisplayValue + SPEED_COUNT_RATE * dt)
            elseif s < _speedDisplayValue then
                _speedDisplayValue = math.max(s, _speedDisplayValue - SPEED_COUNT_RATE * dt)
            end
            local shown = _floor(_speedDisplayValue * 10 + 0.5)
            if shown ~= _lastSpeedShown then
                _lastSpeedShown = shown
                speedLabel.Text = "Speed: " .. string.format("%.1f", shown / 10)
            end
        end
    end)
    setupSpeedIndicator(char)
    startEnemySpeed()
end

function toggleLockUI(state)
    if state == nil then uiLocked = not uiLocked else uiLocked = state end
    if uiLocked and editModeEnabled then
        editModeEnabled = false
        if setEditModeVisual then setEditModeVisual(false) end
    end
    if setLockUIVisual then setLockUIVisual(uiLocked) end
    if _G.lockShortcutBtn then _G.lockShortcutBtn.Text = uiLocked and "🔒" or "🔓" end
end

function disableAllAimbots()
    if autoBatEnabled then
        disableAutoBat()
        if autoBatSetVisual then autoBatSetVisual(false) end
        if mobSetAutoBat then mobSetAutoBat(false) end
    end
    if batDesyncTpEnabled then stopBatDesyncTp() end
    if autoBatV2Enabled then
        disableBatV2()
        if autoBatV2SetVisual then autoBatV2SetVisual(false) end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, false) end
        end
    end
    if autoBatV3Enabled then
        disableBatV3()
        if autoBatV3SetVisual then autoBatV3SetVisual(false) end
    end
end

-- Stops all 4 exclusive movement modes and syncs every visual.
-- Call this before enabling any one of them so only one is ever active.
function stopAllExclusiveModes()
    if autoBatEnabled or autoBatV2Enabled or autoBatV3Enabled then
        if autoBatV3Enabled then
            disableBatV3()
            if autoBatV3SetVisual then autoBatV3SetVisual(false) end
        end
        if autoBatV2Enabled then
            disableBatV2()
            if autoBatV2SetVisual then autoBatV2SetVisual(false) end
            if batV2FloatingButton then
                local f = batV2FloatingButton:FindFirstChild("Frame")
                if f then paintFloatingBtn(f, false) end
            end
        end
        disableAutoBat()
        if autoBatSetVisual then autoBatSetVisual(false) end
        if mobSetAutoBat then mobSetAutoBat(false) end
    end
    if batDesyncTpEnabled then
        stopBatDesyncTp()
        if tpBatFloatingButton then
            local f = tpBatFloatingButton:FindFirstChild("Frame")
            if f then paintFloatingBtn(f, false) end
        end
    end
    if autoLeftEnabled then
        autoLeftEnabled = false
        stopAutoLeft()
        if mobSetAutoLeft then mobSetAutoLeft(false) end
    end
    if autoRightEnabled then
        autoRightEnabled = false
        stopAutoRight()
        if mobSetAutoRight then mobSetAutoRight(false) end
    end
end

function stopAllBackgroundTasks()
    if movementLoop then movementLoop:Disconnect(); movementLoop = nil end
    if steppedConn then steppedConn:Disconnect(); steppedConn = nil end
    stopEnemySpeed()
    if stretchEnabled then disableStretch() end
    if stretchConn then stretchConn:Disconnect(); stretchConn = nil end
    if stretchFovConn then stretchFovConn:Disconnect(); stretchFovConn = nil end
    if AntiRagdollV1.isRunning() then AntiRagdollV1.stop() end
    if AntiRagdollV2.Enabled then stopAntiRagdollV2() end
    if antiDieEnabled then AntiDieModule.stop() end
    if antiFlingEnabled then AntiFlingShieldModule.stop() end
    stopBatCounter()
    stopMedusaCounter()
    stopAutoSteal()
    disableAutoBat()
    if batDesyncTpEnabled then stopBatDesyncTp() end
    if autoBatV2Enabled then disableBatV2() end
    if autoBatV3Enabled then disableBatV3() end
    stopAutoLeft()
    stopAutoRight()
    if unwalkEnabled and not _tpBatUnwalkForced then stopUnwalk() end
    if antiLagEnabled then disableAntiLag() end
    if espEnabled then toggleESP(false) end
    if dropActive then stopDropBrainrot() end
    if bodyLockEnabled then stopBodyLock() end
    _blSuppressCount = 0
    _blWasEnabled = false
    if _blRestoreTimer then
        pcall(task.cancel, _blRestoreTimer)
        _blRestoreTimer = nil
    end
    if _bodyLockConn then
        _bodyLockConn:Disconnect()
        _bodyLockConn = nil
    end
    for _, t in ipairs(dropConnections) do
        if type(t) == "thread" then pcall(task.cancel, t)
        elseif type(t) == "RBXScriptConnection" then pcall(t.Disconnect, t) end
    end
    dropConnections = {}
    dropActive = false
    alPhase = 1
    arPhase = 1
    lastDropTime = 0
    medusaDebounce = false
    medusaLastUsed = 0
end

function buildConfigTable()
    local config = {
        normalSpeed = NS,
        carrySpeed = CS,
        laggerSpeed1 = LAGGER_SPEED,
        laggerSpeed2 = LAGGER_CARRY_SPEED,
        stealRadius = CONFIG.STEAL_RANGE,
        antiRagdollMode = antiRagdollMode,
        autoGrabVariant = autoGrabVariant,
        autoGrabStopPct = autoGrabStopPct,
        autoGrabStopEnabled = autoGrabStopEnabled,
        antiDieEnabled = antiDieEnabled,
        antiFlingEnabled = antiFlingEnabled,
        unwalk = unwalkEnabled,
        autoSteal = CONFIG.AUTO_STEAL_ENABLED,
        medusaCounter = medusaCounterEnabled,
        batCounter = batCounterEnabled,
        laggerToggled = laggerToggled,
        laggerCarryToggled = laggerCarryToggled,
        carryMode = speedMode,
        adaptAutoCarry = adaptAutoCarryEnabled,
        adaptAutoCarryMode = _G._AdaptAutoCarryMode or "WHEN NEAR",
        batAimbotSpeed    = BAT_AIMBOT_SPEED,
        laggerAimbotSpeed = LAGGER_AIMBOT_SPEED,
        dropMode = dropMode,
        batAimbotVariant = batAimbotVariant,
        stretchEnabled = stretchEnabled,
        stretchFOV = stretchFOV,
        fovEnabled = fovEnabled,
        fovValue = fovValue,
        uiScale = uiScaleValue,
        animPack = currentAnimPack,
        espEnabled = espEnabled,
        antiLag = antiLagEnabled,
        tpBatEnabled = batDesyncTpEnabled,
        mirrorTpEnabled = mirrorTpEnabled,
        autoTPDownEnabled = autoTPDownEnabled,
        autoTPDownHeight  = autoTPDownHeight,
        neonWeather = neonWeatherEnabled,
        skyTheme = skyTheme,
        batSkin = batSkin,
        medusaSkin = medusaSkin,
        autoBatV2Enabled = autoBatV2Enabled,
        autoBatV3Enabled = autoBatV3Enabled,
        mobileButtonPositions = savedButtonPositions,
        dropBrainrotKey = {kb = KB.DropBrainrot.kb and KB.DropBrainrot.kb.Name, gp = KB.DropBrainrot.gp and KB.DropBrainrot.gp.Name},
        autoLeftKey = {kb = KB.AutoLeft.kb and KB.AutoLeft.kb.Name, gp = KB.AutoLeft.gp and KB.AutoLeft.gp.Name},
        autoRightKey = {kb = KB.AutoRight.kb and KB.AutoRight.kb.Name, gp = KB.AutoRight.gp and KB.AutoRight.gp.Name},
        autoBatKey = {kb = KB.AutoBat.kb and KB.AutoBat.kb.Name, gp = KB.AutoBat.gp and KB.AutoBat.gp.Name},
        tpFloorKey = {kb = KB.TPFloor.kb and KB.TPFloor.kb.Name, gp = KB.TPFloor.gp and KB.TPFloor.gp.Name},
        carryToggleKey = {kb = KB.CarryToggle.kb and KB.CarryToggle.kb.Name, gp = KB.CarryToggle.gp and KB.CarryToggle.gp.Name},
        laggerModeKey = {kb = KB.LaggerMode.kb and KB.LaggerMode.kb.Name, gp = KB.LaggerMode.gp and KB.LaggerMode.gp.Name},
        tpBatKey = {kb = KB.TPBat.kb and KB.TPBat.kb.Name, gp = KB.TPBat.gp and KB.TPBat.gp.Name},
        batV2Key = {kb = KB.BatV2.kb and KB.BatV2.kb.Name, gp = KB.BatV2.gp and KB.BatV2.gp.Name},
        instaResetKey = {kb = KB.InstaReset.kb and KB.InstaReset.kb.Name, gp = KB.InstaReset.gp and KB.InstaReset.gp.Name},
        tpBatFloatingPos = tpBatFloatingPos,
        batV2FloatingPos = batV2FloatingPos,
        instaResetFloatingPos = instaResetFloatingPos,
        bodyLockEnabled = bodyLockEnabled,
        bodyLockRange = bodyLockRange,
        progressBarPos = savedProgressBarPos,
        progressBarWidth = pbBarWidth,
        progressBarHeight = pbBarHeight,
        progressBarScale = pbBarScaleValue,
        lockUI = uiLocked,
        editMode = editModeEnabled,
        backgroundIndex = backgroundIndex,
        backgroundImages = backgroundImages,
        backgroundImageTransparency = backgroundImageTransparency,
        floatingButtonScale = floatingButtonScale,
        outfitIndex = currentOutfitIndex,
        themeColor = currentColorTheme,
        guiOpen = guiOpenState,
    }
    if pbFrame then
        config.progressBarPos = {
            XScale = pbFrame.Position.X.Scale,
            XOffset = pbFrame.Position.X.Offset,
            YScale = pbFrame.Position.Y.Scale,
            YOffset = pbFrame.Position.Y.Offset
        }
    end
    -- mobilePanelPos no longer used: each button is now a fully independent
    -- floating element and saves its own position in mobileButtonPositions.
    return config
end

function saveAllSettings()
    if _isResetting then return true end
    local config = buildConfigTable()
    local json = HS:JSONEncode(config)
    if json == _lastSavedJSON then return true end
    local success, err = pcall(function() writefile(CONFIG_FILE, json) end)
    if success then _lastSavedJSON = json end
    return success
end

function loadAllSettings()
    if not isfile or not isfile(CONFIG_FILE) then return false end
    local success, data = pcall(function() return HS:JSONDecode(readfile(CONFIG_FILE)) end)
    if not success or not data then return false end
    NS = data.normalSpeed or NS
    CS = data.carrySpeed or CS
    LAGGER_SPEED = data.laggerSpeed1 or LAGGER_SPEED
    LAGGER_CARRY_SPEED = data.laggerSpeed2 or LAGGER_CARRY_SPEED
    CONFIG.STEAL_RANGE = data.stealRadius or CONFIG.STEAL_RANGE
    if radInput then radInput.Text = tostring(CONFIG.STEAL_RANGE) end
    uiLocked = data.lockUI ~= nil and data.lockUI or true
    editModeEnabled = data.editMode or false
    if data.antiRagdollMode then
        antiRagdollMode = data.antiRagdollMode
    else
        antiRagdollMode = data.antiRagdoll and "v2" or "off"
    end
    antiDieEnabled = data.antiDieEnabled or false
    antiFlingEnabled = data.antiFlingEnabled or false
    CONFIG.AUTO_STEAL_ENABLED = data.autoSteal or false
    autoGrabVariant = data.autoGrabVariant or "v1"
    if autoGrabVariant ~= "v1" and autoGrabVariant ~= "v2" then autoGrabVariant = "v1" end
    medusaCounterEnabled = data.medusaCounter or false
    batCounterEnabled = data.batCounter or false
    unwalkEnabled = data.unwalk or false
    antiLagEnabled = data.antiLag or false
    laggerToggled = data.laggerToggled or false
    speedMode = data.carryMode or false
    laggerCarryToggled = data.laggerCarryToggled or false
    adaptAutoCarryEnabled = data.adaptAutoCarry or false
    if data.adaptAutoCarryMode == "ON STEAL" or data.adaptAutoCarryMode == "WHEN NEAR" then
        _G._AdaptAutoCarryMode = data.adaptAutoCarryMode
    else
        _G._AdaptAutoCarryMode = _G._AdaptAutoCarryMode or "WHEN NEAR"
    end
    uiScaleValue = data.uiScale and _clamp(_floor(data.uiScale + 0.5), 50, 150) or 80
    if mainUIScale then mainUIScale.Scale = uiScaleValue / 100 end
    if uiScaleBox then uiScaleBox.Text = tostring(uiScaleValue) end
    espEnabled = data.espEnabled or false
    if espEnabled then toggleESP(true) else toggleESP(false) end
    do
        local legacyThemeNames = {
            Gris="Gray", Morado="Purple", Azul="Blue", Rosado="Pink", Verde="Green", Vainilla="Vanilla",
            Negro="Black", Violeta="Violet", Rojo="Red", Naranja="Orange", Dorado="Gold",
        }
        if data.themeColor and legacyThemeNames[data.themeColor] then
            data.themeColor = legacyThemeNames[data.themeColor]
        end
    end
    if data.themeColor and COLOR_THEMES[data.themeColor] then
        currentColorTheme = data.themeColor
        selectedColor = COLOR_THEMES[data.themeColor]
        task.defer(function()
            updateAllUIThemeColors(selectedColor)
            if colorSelectorLabel then
                colorSelectorLabel.Text = currentColorTheme
                colorSelectorLabel.TextColor3 = selectedColor
            end
        end)
    end
    autoBatV2Enabled = data.autoBatV2Enabled or false
    if autoBatV2Enabled then
        task.defer(function()
            enableBatV2()
            if autoBatV2SetVisual then autoBatV2SetVisual(true) end
        end)
    else
        if autoBatV2SetVisual then autoBatV2SetVisual(false) end
    end
    autoBatV3Enabled = false
    if data.autoBatV3Enabled then
        task.defer(function()
            enableBatV3()
            if autoBatV3SetVisual then autoBatV3SetVisual(true) end
            if mobSetAutoBat then mobSetAutoBat(isAimbotEnabled()) end
        end)
    else
        if autoBatV3SetVisual then autoBatV3SetVisual(false) end
    end
    local tpBatStateLoaded = data.tpBatEnabled or false
    if tpBatStateLoaded then
        task.defer(function()
            startBatDesyncTp()
            if batDesyncTpSetVisual then batDesyncTpSetVisual(true) end
            updateTpBatButtonWithAntiDie(true)
        end)
    else
        if batDesyncTpSetVisual then batDesyncTpSetVisual(false) end
        updateTpBatButtonWithAntiDie(false)
    end
    mirrorTpEnabled = data.mirrorTpEnabled or false
    if data.autoTPDownEnabled ~= nil then autoTPDownEnabled = data.autoTPDownEnabled == true end
    if tonumber(data.autoTPDownHeight) then
        autoTPDownHeight = math.clamp(math.floor(tonumber(data.autoTPDownHeight)), 1, 100000)
    end
    if autoTPDownEnabled then startAutoTPDownLoop() end
    skyTheme = data.skyTheme or "Off"
    if not SKY_PRESETS[skyTheme] then skyTheme = "Off" end
    if skyTheme ~= "Off" then
        pcall(applyCustomSky, skyTheme)
        task.delay(3, function()
            if skyTheme ~= "Off" and not SkyWatch.ours() then pcall(applyCustomSky, skyTheme) end
        end)
    end
    if skySelectorLabel then skySelectorLabel.Text = skyTheme end
    batSkin = SkinSys.bat.skins[data.batSkin] and data.batSkin or "Off"
    medusaSkin = SkinSys.medusa.skins[data.medusaSkin] and data.medusaSkin or "Off"
    if batSkinLabel then batSkinLabel.Text = SkinSys.label("bat", batSkin) end
    if medusaSkinLabel then medusaSkinLabel.Text = SkinSys.label("medusa", medusaSkin) end
    pcall(SkinSys.refresh)
    neonWeatherEnabled = data.neonWeather or false
    if neonWeatherEnabled then
        task.defer(function() toggleNeonWeather(true) end)
    else
        toggleNeonWeather(false)
    end
    if data.animPack and ANIM_PACKS[data.animPack] then
        startAnimPack(data.animPack)
    else
        currentAnimPack = "Off"
        stopAnimPack()
    end
    local function lk(e, d)
        if not d then return end
        if d.kb and Enum.KeyCode[d.kb] then e.kb = Enum.KeyCode[d.kb] end
        if d.gp and Enum.KeyCode[d.gp] then e.gp = Enum.KeyCode[d.gp] end
    end
    lk(KB.DropBrainrot, data.dropBrainrotKey)
    lk(KB.AutoLeft, data.autoLeftKey)
    lk(KB.AutoRight, data.autoRightKey)
    lk(KB.AutoBat, data.autoBatKey)
    lk(KB.TPFloor, data.tpFloorKey)
    lk(KB.CarryToggle, data.carryToggleKey)
    lk(KB.LaggerMode, data.laggerModeKey)
    lk(KB.TPBat, data.tpBatKey)
    lk(KB.BatV2, data.batV2Key)
    lk(KB.InstaReset, data.instaResetKey)
    if data.mobileButtonPositions then savedButtonPositions = data.mobileButtonPositions end
    if data.tpBatFloatingPos then tpBatFloatingPos = data.tpBatFloatingPos end
    if data.batV2FloatingPos then batV2FloatingPos = data.batV2FloatingPos end
    if data.instaResetFloatingPos then instaResetFloatingPos = data.instaResetFloatingPos end
    if data.progressBarPos then savedProgressBarPos = data.progressBarPos end
    if data.progressBarWidth then pbBarWidth = _clamp(data.progressBarWidth, 200, 600) end
    if data.progressBarHeight then pbBarHeight = _clamp(data.progressBarHeight, 40, 200) end
    if data.progressBarScale then pbBarScaleValue = _clamp(data.progressBarScale, 50, 150) end
    if pbScale then pbScale.Scale = pbBarScaleValue / 100 end
    if pbBarScaleBox then pbBarScaleBox.Text = tostring(pbBarScaleValue) end
    if data.autoGrabStopPct then
        autoGrabStopPct = _clamp(data.autoGrabStopPct, 1, 95)
        if stopAtBox then stopAtBox.Text = tostring(autoGrabStopPct) end
    end
    if data.autoGrabStopEnabled ~= nil then autoGrabStopEnabled = data.autoGrabStopEnabled end
    if data.bodyLockEnabled ~= nil then
        bodyLockEnabled = data.bodyLockEnabled
        if bodyLockEnabled then
            task.defer(function()
                if bodyLockSetVisual then bodyLockSetVisual(true) end
                startBodyLock()
            end)
        end
    end
    if data.bodyLockRange then
        bodyLockRange = data.bodyLockRange
        if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
    end
    dropMode = data.dropMode or 1
    if data.batAimbotVariant == "v1" or data.batAimbotVariant == "v2" or data.batAimbotVariant == "bypass" then batAimbotVariant = data.batAimbotVariant end
    stretchEnabled = data.stretchEnabled or false
    fovValue = data.fovValue or 70
    fovEnabled = data.fovEnabled or false
    if fovSliderSet then fovSliderSet(fovValue) end
    if fovEnabled then enableCustomFov() end
    if setFovVisual then setFovVisual(fovEnabled) end
    stretchFOV = data.stretchFOV or 120
    BAT_AIMBOT_SPEED = data.batAimbotSpeed or BAT_AIMBOT_SPEED
    LAGGER_AIMBOT_SPEED = data.laggerAimbotSpeed or LAGGER_AIMBOT_SPEED
    backgroundIndex = data.backgroundIndex ~= nil and tonumber(data.backgroundIndex) or 0
    backgroundImageTransparency = data.backgroundImageTransparency or 0
    -- backgroundImages is hardcoded; config cannot override it
    floatingButtonScale = data.floatingButtonScale or 1
    if data.outfitIndex and data.outfitIndex >= 1 and data.outfitIndex <= #OUTFITS then
        currentOutfitIndex = data.outfitIndex
        task.defer(function()
            pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
            if outfitSelectorLabel then
                outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
            end
        end)
    end

    guiOpenState = data.guiOpen ~= nil and data.guiOpen or true

    autoBatEnabled = false
    autoLeftEnabled = false
    autoRightEnabled = false
    if dropModeBtnRef then dropModeBtnRef.Text = dropMode == 1 and "Fling" or "Jump Drop" end
    refreshSpeedModeLabel()
    _lastSavedJSON = HS:JSONEncode(buildConfigTable())
    return true
end

function forceResetUI()
    if normalBox then normalBox.Text = tostring(NS) end
    if carryBox then carryBox.Text = tostring(CS) end
    if radInput then radInput.Text = tostring(CONFIG.STEAL_RANGE) end
    if laggerBox then laggerBox.Text = tostring(LAGGER_SPEED) end
    if lagger2Box then lagger2Box.Text = tostring(LAGGER_CARRY_SPEED) end
    if batSpeedBox then batSpeedBox.Text = tostring(BAT_AIMBOT_SPEED) end
    if laggerBatSpeedBox then laggerBatSpeedBox.Text = tostring(LAGGER_AIMBOT_SPEED) end
    if uiScaleBox then uiScaleBox.Text = tostring(uiScaleValue) end
    if pbBarScaleBox then pbBarScaleBox.Text = tostring(pbBarScaleValue) end
    if stopAtBox then stopAtBox.Text = tostring(autoGrabStopPct) end
    if dropModeBtnRef then dropModeBtnRef.Text = dropMode == 1 and "Fling" or "Jump Drop" end
    if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
    local function safeSet(fn, val) if fn then fn(val) end end
    safeSet(autoBatSetVisual, false)
    safeSet(autoLeftSetVisual, false)
    safeSet(autoRightSetVisual, false)
    safeSet(setBatCounterVisual, false)
    safeSet(setMedusaVisual, false)
    safeSet(setUnwalkVisual, false)
    safeSet(setAntiLagVisual, false)
    safeSet(setLockUIVisual, false)
    safeSet(setEditModeVisual, false)
    safeSet(setInstaGrab, false)
    safeSet(batDesyncTpSetVisual, false)
    safeSet(setESPVIsual, false)
    safeSet(bodyLockSetVisual, false)
    safeSet(setNeonWeatherVisual, false)
    safeSet(autoBatV2SetVisual, false)
    safeSet(autoBatV3SetVisual, false)
    safeSet(setAntiDieVisual, false)
    if _G.stretchToggleSetter then _G.stretchToggleSetter(false) end
    safeSet(mobSetAutoBat, false)
    safeSet(mobSetAutoLeft, false)
    safeSet(mobSetAutoRight, false)
    safeSet(mobSetDropBR, false)
    safeSet(mobSetTpDown, false)
    safeSet(mobSetCarry, false)
    safeSet(mobSetLagger1, false)
    safeSet(mobSetLagger2, false)
    refreshSpeedModeLabel()
    updateProgressBarVisibility()
    disableAntiLag()
    toggleNeonWeather(false)
    skyTheme = "Off"
    pcall(applyCustomSky, "Off")
    if skySelectorLabel then skySelectorLabel.Text = "Off" end
    batSkin = "Off"
    medusaSkin = "Off"
    if batSkinLabel then batSkinLabel.Text = "Off" end
    if medusaSkinLabel then medusaSkinLabel.Text = "Off" end
    pcall(SkinSys.refresh)
    disableBatV2()
    if antiDieEnabled then
        AntiDieModule.stop()
        antiDieEnabled = false
    end
    if antiFlingEnabled then
        AntiFlingShieldModule.stop()
        antiFlingEnabled = false
    end
    updateTpBatButtonWithAntiDie(false)
    for _, ref in ipairs(keyButtonRefs) do
        local entry = ref.entry
        local label = (entry.gp and entry.gp.Name) or (entry.kb and entry.kb.Name) or "None"
        ref.btn.Text = label
    end
    currentColorTheme = "Gray"
    selectedColor = COLOR_THEMES["Gray"]
    if colorSelectorLabel then
        colorSelectorLabel.Text = "Gray"
        colorSelectorLabel.TextColor3 = selectedColor
    end
    updateAllUIThemeColors(selectedColor)
    if miniBtn then miniBtn.TextColor3 = selectedColor end
    local pGui = LP:FindFirstChild("PlayerGui")
    if pGui then
        local bb = pGui:FindFirstChild("RagCountdownBillboard")
        if bb then
            local lbl = bb:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.TextColor3 = selectedColor end
        end
    end
    if MobilePanel then
        for _, btn in ipairs(MobilePanel:GetChildren()) do
            if btn:IsA("TextButton") then
                local label = btn:FindFirstChildOfClass("TextLabel")
                if label then
                    local isActive = btn.BackgroundColor3 == selectedColor
                    if not isActive then label.TextColor3 = selectedColor end
                end
            end
        end
    end
    saveAllSettings()
end

local DEFAULT_BUTTON_SCREEN_POSITIONS = {
    DropBR    = { XScale=1, XOffset=-140, YScale=0, YOffset=10  },
    AutoLeft  = { XScale=1, XOffset=-74,  YScale=0, YOffset=10  },
    AutoBat   = { XScale=1, XOffset=-140, YScale=0, YOffset=78  },
    AutoRight = { XScale=1, XOffset=-74,  YScale=0, YOffset=78  },
    TpDown    = { XScale=1, XOffset=-140, YScale=0, YOffset=146 },
    Carry     = { XScale=1, XOffset=-74,  YScale=0, YOffset=146 },
    Lagger1   = { XScale=1, XOffset=-140, YScale=0, YOffset=214 },
    Lagger2   = { XScale=1, XOffset=-74,  YScale=0, YOffset=214 },
}

function resetFloatingPositions()
    if MobilePanel then
        savedButtonPositions = {}
        for _, btn in ipairs(MobilePanel:GetChildren()) do
            if btn:IsA("TextButton") then
                local def = DEFAULT_BUTTON_SCREEN_POSITIONS[btn.Name]
                if def then
                    btn.Position = UDim2.new(def.XScale, def.XOffset, def.YScale, def.YOffset)
                end
            end
        end
    end
    if tpBatFloatingButton and tpBatFloatingButton:FindFirstChild("Frame") then
        local btnFrame = tpBatFloatingButton:FindFirstChild("Frame")
        btnFrame.Position = UDim2.new(1, -70, 0, 78)
        tpBatFloatingPos = nil
    end
    if batV2FloatingButton and batV2FloatingButton:FindFirstChild("Frame") then
        local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
        btnFrame.Position = UDim2.new(1, -70, 0, 10)
        batV2FloatingPos = nil
    end
    if instaResetFloatingButton and instaResetFloatingButton:FindFirstChild("Frame") then
        instaResetFloatingButton.Frame.Position = UDim2.new(1, -70, 0, 146)
        instaResetFloatingPos = nil
    end
    if pbFrame then
        pbFrame.Position = UDim2.new(0.5, -200, 1, -60)
        savedProgressBarPos = nil
    end
    tpBatFloatingPos = nil
    batV2FloatingPos = nil
end

function resetToFactoryDefaults()
    _isResetting = true
    local ok, err = pcall(function()
        stopAllBackgroundTasks()
        stopAutoSteal()
        stopBatCounter()
            stopMedusaCounter()
        if AntiRagdollV1.isRunning() then AntiRagdollV1.stop() end
        if AntiRagdollV2.Enabled then stopAntiRagdollV2() end
        if antiDieEnabled then AntiDieModule.stop() end
        if antiFlingEnabled then AntiFlingShieldModule.stop() end
        stopUnwalk()
        disableAutoBat()
        if batDesyncTpEnabled then stopBatDesyncTp() end
        disableBatV2()
        stopBodyLock()
        if espEnabled then toggleESP(false) end
        if stretchEnabled then disableStretch() end
        if antiLagEnabled then disableAntiLag() end
        if dropActive then stopDropBrainrot() end
        toggleNeonWeather(false)
        skyTheme = "Off"
        pcall(applyCustomSky, "Off")
        if skySelectorLabel then skySelectorLabel.Text = "Off" end
        batSkin = "Off"
        medusaSkin = "Off"
        if batSkinLabel then batSkinLabel.Text = "Off" end
        if medusaSkinLabel then medusaSkinLabel.Text = "Off" end
        pcall(SkinSys.refresh)
        if antiDieEnabled then
            AntiDieModule.stop()
            antiDieEnabled = false
        end
        if antiFlingEnabled then
            AntiFlingShieldModule.stop()
            antiFlingEnabled = false
        end
        NS = 60
        CS = 29
        LAGGER_SPEED = 15
        LAGGER_CARRY_SPEED = 24.5
        CONFIG.STEAL_RANGE = 61
        speedMode = false
        laggerToggled = false
        laggerCarryToggled = false
        antiRagdollMode = "off"
        antiDieEnabled = false
        antiFlingEnabled = false
        medusaCounterEnabled = false
        batCounterEnabled = false
        autoBatEnabled = false
        autoLeftEnabled = false
        autoRightEnabled = false
        unwalkEnabled = false
        antiLagEnabled = false
        uiLocked = true
        editModeEnabled = false
        CONFIG.AUTO_STEAL_ENABLED = false
        BAT_AIMBOT_SPEED    = 58
        LAGGER_AIMBOT_SPEED = 58
        dropMode = 1
        stretchEnabled = false
        stretchFOV = 120
        fovValue = 70
        disableCustomFov()
        if fovSliderSet then fovSliderSet(70) end
        if setFovVisual then setFovVisual(false) end
        uiScaleValue = 80
        if mainUIScale then mainUIScale.Scale = uiScaleValue / 100 end
        pbBarScaleValue = 100
        if pbScale then pbScale.Scale = 1 end
        espEnabled = false
        bodyLockEnabled = false
        bodyLockRange = 20
        autoBatV2Enabled = false
        autoBatV3Enabled = false
        backgroundIndex = 0
        backgroundImages = {"99555977825356", "89784309464164", "138550322570942", "87012219126399", "123172079672908", "136020876423499", "115963355153377", "123836362734324", "97540240979096", "139659785448167", "73211468627724", "99803890852075", "122260603259941", "127365118869203", "130033760149642"}
        backgroundImageTransparency = 0
        floatingButtonScale = 1
        if batDesyncTpEnabled then stopBatDesyncTp() end
        currentAnimPack = "Off"
        stopAnimPack()
        currentOutfitIndex = 1
        currentColorTheme = "Gray"
        selectedColor = COLOR_THEMES["Gray"]
        for key, val in pairs(DEFAULT_KB) do
            if KB[key] then
                KB[key].kb = val.kb
                KB[key].gp = val.gp
            end
        end
        if isfile and isfile(CONFIG_FILE) then
            pcall(delfile, CONFIG_FILE)
        end
        resetFloatingPositions()
        forceResetUI()
        updateProgressBarVisibility()
        refreshSpeedModeLabel()
        _lastSavedJSON = nil
        saveAllSettings()
    end)
    _isResetting = false
    if not ok then warn("[resetToFactoryDefaults]", err) end
    return ok
end

function updateProgressBarVisibility()
    if pbFrame then
        pbFrame.Visible = true
        if savedProgressBarPos then
            pbFrame.Position = UDim2.new(
                savedProgressBarPos.XScale or 0.5,
                savedProgressBarPos.XOffset or -200,
                savedProgressBarPos.YScale or 1,
                savedProgressBarPos.YOffset or -82
            )
        end
    end
end

function applyShimmerToText(obj, speed)
    speed = speed or 0.8
    local color = getThemeColor()
    local grad = Instance.new("UIGradient", obj)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(200,200,200)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(200,200,200)),
        ColorSequenceKeypoint.new(1, color),
    })
    grad.Rotation = 45
    grad.Offset = Vector2.new(0,0)
    task.spawn(function()
        local t = 0
        while grad and grad.Parent do
            t = t + 0.025
            grad.Offset = Vector2.new(math.sin(t * speed) * 0.4, 0)
            task.wait(0.05)   -- 20fps shimmer, visually identical to 25fps
        end
    end)
    return grad
end

-- ============================================================
-- INSTA RESET MODULE — Adapt engine
-- ============================================================
local AdaptResetCooldown      = false
local AdaptResetThread        = nil
local AdaptResetSuccessful    = false
local AdaptStopResetSequence  = false
local AdaptCameraLocked       = false
local AdaptLockedCameraCFrame = nil
local AdaptResetMaxDuration   = 0.05
local _lastInstaResetRequest  = 0

function _G.AdaptInstantReset()
    if AdaptResetCooldown then return end
    AdaptResetCooldown     = true
    AdaptResetSuccessful   = false
    AdaptStopResetSequence = false
    AdaptCameraLocked      = false

    local character = LP.Character
    if not character then AdaptResetCooldown = false return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then AdaptResetCooldown = false return end

    local cam = workspace.CurrentCamera
    if cam then
        AdaptLockedCameraCFrame = cam.CFrame
        AdaptCameraLocked       = true
        cam.CFrame              = AdaptLockedCameraCFrame
    end

    local isRespawning  = false

    AdaptResetThread = task.spawn(function()
        local attempts          = 0
        local maxAttempts       = 40
        local originalHipHeight = humanoid.HipHeight

        while character and character.Parent and humanoid and humanoid.Health > 0
              and not isRespawning and not AdaptStopResetSequence do
            if LP.Character ~= character then
                isRespawning = true
                break
            end
            pcall(function()
                humanoid.HipHeight  = 1e30
                humanoid.AutoRotate = true
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then rootPart.CanCollide = false end
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = false
                    end
                end
            end)

            if not character or not character.Parent or not humanoid
               or humanoid.Health <= 0 or LP.Character ~= character then
                AdaptResetSuccessful = true
                break
            end

            attempts = attempts + 1
            if attempts >= maxAttempts then break end
            task.wait(AdaptResetMaxDuration)
        end

        if not AdaptResetSuccessful then
            if character and character.Parent and humanoid
               and humanoid.Health > 0 and not isRespawning then
                pcall(function() humanoid.Health = 0 end)
                task.wait(0.1)
                if not character.Parent or humanoid.Health <= 0 then
                    AdaptResetSuccessful = true
                end
            end
        end

        if not AdaptResetSuccessful and character and character.Parent and humanoid then
            pcall(function()
                humanoid.HipHeight = originalHipHeight
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then rootPart.CanCollide = true end
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end)
        end

        AdaptCameraLocked      = false
        AdaptResetCooldown     = false
        AdaptResetThread       = nil
        AdaptStopResetSequence = false
    end)
end

function _G.AdaptStopInstantReset()
    AdaptStopResetSequence = true
    if AdaptResetThread then
        pcall(task.cancel, AdaptResetThread)
        AdaptResetThread = nil
    end
    AdaptResetCooldown   = false
    AdaptCameraLocked    = false
end

LP.CharacterAdded:Connect(function()
    _G.AdaptStopInstantReset()
    AdaptResetSuccessful = false
end)

task.spawn(function()
    while true do
        task.wait(0.016)
        local cam = workspace.CurrentCamera
        if AdaptCameraLocked and AdaptLockedCameraCFrame and cam then
            cam.CFrame = AdaptLockedCameraCFrame
        end
    end
end)

-- throttled public trigger (0.75s cooldown)
_G.InstaReset = { Trigger = function()
    local now = os.clock()
    if now - _lastInstaResetRequest < 0.75 then return end
    _lastInstaResetRequest = now
    _G.AdaptInstantReset()
end }
-- ============================================================

function buildGui()
    local SILVER_DARK = Color3.fromRGB(100, 100, 110)
    local BG = Color3.fromRGB(0,0,0)
    local BG2 = Color3.fromRGB(10,10,10)
    local ROW_BG = Color3.fromRGB(10,10,10)
    local ROW_BORDER = Color3.fromRGB(50,50,50)
    local WHITE = Color3.fromRGB(255,255,255)
    local INP = Color3.fromRGB(15,15,15)
    local OFF = Color3.fromRGB(25,25,30)
    local TAB_INACT = SILVER_DARK
    local GUI_W, GUI_H = 330, 480

    local old = game:GetService("CoreGui"):FindFirstChild("MeridianHub")
    if old then old:Destroy() end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then local o = pg:FindFirstChild("MeridianHub"); if o then o:Destroy() end end

    gui = Instance.new("ScreenGui")
    gui.Name = "MERIDIAN"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10
    gui.IgnoreGuiInset = true
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    local guiOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not guiOk then gui.Parent = LP:WaitForChild("PlayerGui") end

    main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, GUI_W, 0, GUI_H)
    main.Position = UDim2.new(0, 20, 0, 2)
    main.BackgroundColor3 = BG
    main.BackgroundTransparency = 1
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)

    local bgImage = Instance.new("ImageLabel", main)
    bgImage.Name = "BackgroundImage"
    bgImage.Size = UDim2.new(1, 0, 1, 0)
    bgImage.Position = UDim2.new(0, 0, 0, 0)
    bgImage.BackgroundTransparency = 1
    bgImage.Image = (backgroundIndex > 0 and backgroundImages[backgroundIndex]) and ("rbxassetid://" .. backgroundImages[backgroundIndex]) or ""
    bgImage.ImageTransparency = backgroundImageTransparency
    bgImage.ScaleType = Enum.ScaleType.Crop
    bgImage.ZIndex = 0
    bgImage.ClipsDescendants = true
    bgImage.Visible = backgroundIndex > 0
    Instance.new("UICorner", bgImage).CornerRadius = UDim.new(0, 18)

    local function applyBackground(index)
        backgroundIndex = index or 0
        if backgroundIndex == 0 or not backgroundImages[backgroundIndex] then
            bgImage.Visible = false
            bgImage.Image = ""
        else
            bgImage.Image = "rbxassetid://" .. backgroundImages[backgroundIndex]
            bgImage.ImageTransparency = backgroundImageTransparency
            bgImage.Visible = true
        end
        saveAllSettings()
    end

    mainUIScale = Instance.new("UIScale", main)
    mainUIScale.Scale = uiScaleValue / 100

    local titleFrame = Instance.new("Frame", main)
    titleFrame.Size = UDim2.new(1, -100, 0, 40)
    titleFrame.Position = UDim2.new(0, 30, 0, 4)
    titleFrame.BackgroundTransparency = 1
    titleFrame.ZIndex = 20

    local headerImg = Instance.new("ImageLabel", main)
    headerImg.Name = "HeaderImage"
    headerImg.AnchorPoint = Vector2.new(0.5, 0)
    headerImg.Position = UDim2.new(0.5, 0, 0, -10)
    headerImg.Size = UDim2.new(1, 0, 0, 120)
    headerImg.BackgroundTransparency = 1
    headerImg.Image = "rbxassetid://127245120655691"
    headerImg.ScaleType = Enum.ScaleType.Fit
    headerImg.ImageTransparency = 0
    headerImg.ZIndex = 25
    Instance.new("UICorner", headerImg).CornerRadius = UDim.new(0, 18)

    local closeBtn = Instance.new("TextButton", main)
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,35)
    closeBtn.BackgroundTransparency = 0.6
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "−"
    closeBtn.TextColor3 = WHITE
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 26
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 200
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    closeBtn.MouseEnter:Connect(function()
        TS:Create(closeBtn, TweenInfo.new(0.12), {TextColor3 = WHITE, BackgroundColor3 = getThemeColor()}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TS:Create(closeBtn, TweenInfo.new(0.12), {TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(30,30,35)}):Play()
    end)

    -- Lock shortcut: sits beside the minus button, mirrors the Lock UI
    -- toggle on the Visual page so the panel can be locked/unlocked
    -- without opening that tab.
    local lockShortcutBtn = Instance.new("TextButton", main)
    lockShortcutBtn.Size = UDim2.new(0, 32, 0, 32)
    lockShortcutBtn.Position = UDim2.new(1, -78, 0, 8)
    lockShortcutBtn.BackgroundColor3 = Color3.fromRGB(30,30,35)
    lockShortcutBtn.BackgroundTransparency = 0.6
    lockShortcutBtn.BorderSizePixel = 0
    lockShortcutBtn.Text = uiLocked and "🔒" or "🔓"
    lockShortcutBtn.TextColor3 = WHITE
    lockShortcutBtn.Font = Enum.Font.GothamBlack
    lockShortcutBtn.TextSize = 15
    lockShortcutBtn.AutoButtonColor = false
    lockShortcutBtn.ZIndex = 200
    Instance.new("UICorner", lockShortcutBtn).CornerRadius = UDim.new(0, 8)

    lockShortcutBtn.MouseEnter:Connect(function()
        TS:Create(lockShortcutBtn, TweenInfo.new(0.12), {TextColor3 = WHITE, BackgroundColor3 = getThemeColor()}):Play()
    end)
    lockShortcutBtn.MouseLeave:Connect(function()
        TS:Create(lockShortcutBtn, TweenInfo.new(0.12), {TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(30,30,35)}):Play()
    end)
    lockShortcutBtn.MouseButton1Click:Connect(function()
        toggleLockUI()
    end)
    _G.lockShortcutBtn = lockShortcutBtn

    miniBtn = Instance.new("TextButton", gui)
    miniBtn.Size = UDim2.new(0, 118, 0, 30)
    miniBtn.Position = UDim2.new(0, 16, 0, 58)
    miniBtn.BackgroundColor3 = BG2
    miniBtn.BackgroundTransparency = 0
    miniBtn.BorderSizePixel = 0
    miniBtn.Text = "MERIDIAN"
    miniBtn.TextColor3 = selectedColor
    miniBtn.Font = Enum.Font.GothamBlack
    miniBtn.TextSize = 12
    miniBtn.ZIndex = 20
    miniBtn.Visible = false
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0, 8)
    applyShimmerToText(miniBtn, 0.9)

    -- Floating button drag: movable only while Lock UI is OFF, same rule
    -- as the main panel. A short tap (didn't move) still opens the GUI.
    do
        local miniDragging = false
        local miniMoved = false
        local miniDragStart = nil
        local miniStartPos = nil
        local miniMovedDist = 0

        miniBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                miniDragging = true
                miniMoved = false
                miniMovedDist = 0
                miniDragStart = input.Position
                miniStartPos = miniBtn.Position
            end
        end)

        miniBtn.InputChanged:Connect(function(input)
            if not miniDragging or uiLocked then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - miniDragStart
                miniMovedDist = delta.Magnitude
                if miniMovedDist > 3 then miniMoved = true end
                miniBtn.Position = UDim2.new(
                    miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X,
                    miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y
                )
            end
        end)

        local function endMiniDrag(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if not miniDragging then return end
            miniDragging = false
            if not miniMoved then
                showGui()
            end
            miniMoved = false
            miniDragStart = nil
            miniStartPos = nil
            miniMovedDist = 0
        end

        miniBtn.InputEnded:Connect(endMiniDrag)
        UIS.InputEnded:Connect(endMiniDrag)
    end

    local slideTween = nil
    local mainOriginalPos = main.Position

    showGui = function()
        if slideTween then slideTween:Cancel() end
        if not main then return end
        main.Visible = true
        miniBtn.Visible = false
        main.Position = UDim2.new(0, -GUI_W - 20, 0, 2)
        slideTween = TS:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = mainOriginalPos})
        slideTween:Play()
        slideTween.Completed:Connect(function() slideTween = nil end)
        guiOpenState = true
        _lastSavedJSON = ""
        saveAllSettings()
    end

    hideGui = function()
        if slideTween then slideTween:Cancel() end
        if not main or not main.Visible then return end
        if miniBtn then miniBtn.Visible = true end
        local targetPos = UDim2.new(0, -GUI_W - 20, 0, 2)
        slideTween = TS:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos})
        slideTween:Play()
        task.delay(0.42, function()
            if main then main.Visible = false end
            slideTween = nil
        end)
        guiOpenState = false
        _lastSavedJSON = ""
        saveAllSettings()
    end

    closeBtn.MouseButton1Click:Connect(hideGui)

    local tabBar = Instance.new("Frame", main)
    tabBar.Size = UDim2.new(1, 0, 0, 40)
    tabBar.Position = UDim2.new(0, 0, 1, -40)
    tabBar.BackgroundTransparency = 1
    tabBar.ZIndex = 10

    local tabLayout = Instance.new("UIListLayout", tabBar)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 2)

    local tabContent = Instance.new("Frame", main)
    tabContent.Size = UDim2.new(1, 0, 1, -126)
    tabContent.Position = UDim2.new(0, 0, 0, 86)
    tabContent.BackgroundTransparency = 1
    tabContent.ClipsDescendants = true
    tabContent.ZIndex = 5

    local tabs = {"Speed", "Combat", "Visual", "Config", "Keybinds"}
    tabButtons = {}
    local contentPages = {}

    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabBar)
        btn.Size = UDim2.new(0, 60, 1, -8)
        btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
        btn.BackgroundTransparency = 0.5
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = TAB_INACT
        btn.Font = Enum.Font.GothamBlack
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.ZIndex = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = ROW_BORDER
        stroke.Thickness = 1

        local page = Instance.new("ScrollingFrame", tabContent)
        page.Size = UDim2.new(1, 0, 1, 0)
        page.Position = UDim2.new(0, 0, 0, 0)
        page.BackgroundColor3 = Color3.fromRGB(5,5,5)
        page.BackgroundTransparency = 0.6
        page.BorderSizePixel = 0
        page.ClipsDescendants = true
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = Color3.fromRGB(30,30,35)
        page.ScrollBarImageTransparency = 0.3
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.ScrollingDirection = Enum.ScrollingDirection.Y
        page.ZIndex = 6
        Instance.new("UICorner", page).CornerRadius = UDim.new(0, 16)
        page.Visible = (i == 1)

        local layout = Instance.new("UIListLayout", page)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local padding = Instance.new("UIPadding", page)
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.PaddingTop = UDim.new(0, 6)
        padding.PaddingBottom = UDim.new(0, 20)

        contentPages[name] = page

        btn.MouseButton1Click:Connect(function()
            for _, pg in pairs(contentPages) do pg.Visible = false end
            page.Visible = true
            for _, b in ipairs(tabButtons) do
                b.TextColor3 = TAB_INACT
                b.BackgroundColor3 = Color3.fromRGB(0,0,0)
            end
            btn.TextColor3 = getThemeColor()
            btn.BackgroundColor3 = Color3.fromRGB(20,20,20)
        end)

        table.insert(tabButtons, btn)
    end

    if tabButtons[1] then
        tabButtons[1].TextColor3 = getThemeColor()
        tabButtons[1].BackgroundColor3 = Color3.fromRGB(20,20,20)
    end

    local pageCounters = {}

    local function getNextOrder(page)
        if not pageCounters[page] then pageCounters[page] = 0 end
        pageCounters[page] = pageCounters[page] + 1
        return pageCounters[page]
    end

    local function mkSect(page, txt)
        local f = Instance.new("Frame", page)
        f.Size = UDim2.new(1, 0, 0, 26)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.LayoutOrder = getNextOrder(page)
        f.ZIndex = 7
        local l = Instance.new("TextLabel", f)
        l.Size = UDim2.new(1, -16, 1, 0)
        l.Position = UDim2.new(0, 8, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt:upper()
        l.TextColor3 = getThemeColor()
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextStrokeColor3 = Color3.fromRGB(60,60,60)
        l.TextStrokeTransparency = 0.3
        l.ZIndex = 8
        local line = Instance.new("Frame", f)
        line.Size = UDim2.new(1, -24, 0, 1.5)
        line.Position = UDim2.new(0, 12, 1, -4)
        line.BackgroundColor3 = getThemeColor()
        line.BackgroundTransparency = 0.6
        line.BorderSizePixel = 0
        line.ZIndex = 8
        return f
    end

    local function mkRow(page, h)
        local f = Instance.new("Frame", page)
        f.Size = UDim2.new(1, -4, 0, h or 38)
        f.BackgroundColor3 = ROW_BG
        f.BackgroundTransparency = 0.7
        f.BorderSizePixel = 0
        f.LayoutOrder = getNextOrder(page)
        f.ZIndex = 7
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
        local rowStroke = Instance.new("UIStroke", f)
        rowStroke.Color = ROW_BORDER
        rowStroke.Thickness = 1
        rowStroke.Transparency = 0.5
        f.MouseEnter:Connect(function()
            TS:Create(f, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(28,28,28)}):Play()
        end)
        f.MouseLeave:Connect(function()
            TS:Create(f, TweenInfo.new(0.1), {BackgroundColor3 = ROW_BG}):Play()
        end)
        return f
    end

    local function mkLabel(row, txt)
        local l = Instance.new("TextLabel", row)
        l.Size = UDim2.new(0.55, 0, 1, 0)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = WHITE
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        l.TextStrokeTransparency = 0.5
        l.ZIndex = 8
        local c = getThemeColor()
        local grad = Instance.new("UIGradient", l)
        grad.Name = "LabelThemeGrad"
        grad.Rotation = 0
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    c),
            ColorSequenceKeypoint.new(0.35, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.65, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1,    c),
        })
        return l
    end

    local function mkPill(row, offset)
        local pill = Instance.new("Frame", row)
        pill.Name = "Track"
        pill.Size = UDim2.new(0, 34, 0, 18)
        pill.AnchorPoint = Vector2.new(0.5, 0.5)
        pill.Position = UDim2.new(1, -(offset or 48), 0.5, 0)
        pill.BackgroundColor3 = Color3.fromRGB(255,255,255)
        pill.BackgroundTransparency = 0.2
        pill.BorderSizePixel = 0
        pill.ZIndex = 8
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 9)
        local stroke = Instance.new("UIStroke", pill)
        stroke.Color = ROW_BORDER
        stroke.Thickness = 1
        stroke.Transparency = 0.45
        stroke.Name = "PillStroke"

        local dot = Instance.new("Frame", pill)
        dot.Name = "Knob"
        dot.Size = UDim2.new(0, 13, 0, 13)
        dot.AnchorPoint = Vector2.new(0, 0)
        dot.Position = UDim2.new(0, 3, 0.5, -6)
        dot.BackgroundColor3 = Color3.fromRGB(18,18,22)
        dot.BorderSizePixel = 0
        dot.ZIndex = 9
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local shine = Instance.new("Frame", dot)
        shine.Name = "Shine"
        shine.Size = UDim2.new(1, -4, 0, 4)
        shine.Position = UDim2.new(0, 2, 0, 2)
        shine.BackgroundColor3 = WHITE
        shine.BackgroundTransparency = 0.72
        shine.BorderSizePixel = 0
        shine.ZIndex = 10
        Instance.new("UICorner", shine).CornerRadius = UDim.new(0, 4)

        return pill, dot
    end

    local function animPill(pill, dot, on)
        local stroke = pill:FindFirstChildOfClass("UIStroke")
        local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TS:Create(dot, info, {
            Position = on and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
        }):Play()
        if on then
            local c = getThemeColor()
            local grad = pill:FindFirstChildOfClass("UIGradient")
            if not grad then
                grad = Instance.new("UIGradient", pill)
                grad.Rotation = 90
            end
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, c:Lerp(Color3.new(1,1,1), 0.40)),
                ColorSequenceKeypoint.new(1, c:Lerp(Color3.new(0,0,0), 0.25)),
            })
            grad.Enabled = true
            TS:Create(pill, info, {
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0,
            }):Play()
        else
            local grad = pill:FindFirstChildOfClass("UIGradient")
            if grad then grad.Enabled = false end
            TS:Create(pill, info, {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 0.2,
            }):Play()
        end
        if stroke then
            TS:Create(stroke, info, {
                Color = on and getThemeColor() or ROW_BORDER,
                Transparency = on and 0.2 or 0.45,
                Thickness = 1,
            }):Play()
        end
    end

    local function mkSlider(row, minV, maxV, default, cb)
        local W = 118
        local track = Instance.new("Frame", row)
        track.Size = UDim2.new(0, W, 0, 4)
        track.Position = UDim2.new(1, -(W + 44), 0.5, -2)
        track.BackgroundColor3 = INP
        track.BackgroundTransparency = 0.3
        track.BorderSizePixel = 0
        track.ZIndex = 8
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame", track)
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = getThemeColor()
        fill.BorderSizePixel = 0
        fill.ZIndex = 9
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", track)
        knob.Size = UDim2.new(0, 13, 0, 13)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.BackgroundColor3 = WHITE
        knob.BorderSizePixel = 0
        knob.ZIndex = 11
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local kStroke = Instance.new("UIStroke", knob)
        kStroke.Color = getThemeColor()
        kStroke.Thickness = 2

        local valLabel = Instance.new("TextLabel", row)
        valLabel.Size = UDim2.new(0, 34, 0, 20)
        valLabel.Position = UDim2.new(1, -38, 0.5, -10)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(default)
        valLabel.TextColor3 = WHITE
        valLabel.Font = Enum.Font.GothamBlack
        valLabel.TextSize = 11
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.ZIndex = 9

        local hit = Instance.new("TextButton", row)
        hit.Size = UDim2.new(0, W + 16, 0, 26)
        hit.Position = UDim2.new(1, -(W + 52), 0.5, -13)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.AutoButtonColor = false
        hit.ZIndex = 12

        local current = default

        local function render(a)
            a = _clamp(a, 0, 1)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            fill.BackgroundColor3 = getThemeColor()
            kStroke.Color = getThemeColor()
        end

        local function applyFromX(px)
            local left = track.AbsolutePosition.X
            local width = track.AbsoluteSize.X
            if width <= 0 then width = W end
            if left <= 0 then return end
            local a = (px - left) / width
            a = _clamp(a, 0, 1)
            local v = _floor(minV + (maxV - minV) * a + 0.5)
            current = v
            valLabel.Text = tostring(v)
            render(a)
            if cb then pcall(cb, v) end
        end

        local dragging = false

        hit.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                _isDraggingButton = true
                applyFromX(i.Position.X)
            end
        end)

        hit.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                _isDraggingButton = false
            end
        end)

        UIS.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                applyFromX(i.Position.X)
            end
        end)

        UIS.InputEnded:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                _isDraggingButton = false
            end
        end)

        local function setValue(v)
            v = _clamp(tonumber(v) or minV, minV, maxV)
            current = v
            valLabel.Text = tostring(v)
            render((v - minV) / (maxV - minV))
        end

        setValue(default)
        return setValue
    end

    local function mkToggle(page, txt, cb)
        local row = mkRow(page, 38)
        mkLabel(row, txt)
        local pill, dot = mkPill(row, 48)
        local on = false
        local function sv(s) on = s; animPill(pill, dot, s) end
        local clk = Instance.new("TextButton", pill)
        clk.Size = UDim2.new(1,0,1,0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.AutoButtonColor = false
        clk.ZIndex = 10
        clk.MouseButton1Click:Connect(function()
            if not uiLocked then
                pcall(cb, not on)
            else
                on = not on
                sv(on)
                pcall(cb, on)
            end
        end)
        return sv
    end

    local function mkSelector(parent, default, options, cb)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(0, 160, 1, 0)
        container.Position = UDim2.new(1, -168, 0, 0)
        container.BackgroundTransparency = 1
        container.ZIndex = 8
        local leftBtn = Instance.new("TextButton", container)
        leftBtn.Size = UDim2.new(0, 28, 0, 26)
        leftBtn.Position = UDim2.new(0, 0, 0.5, -13)
        leftBtn.BackgroundColor3 = INP
        leftBtn.BackgroundTransparency = 0.7
        leftBtn.BorderSizePixel = 0
        leftBtn.Text = "<"
        leftBtn.TextColor3 = WHITE
        leftBtn.Font = Enum.Font.GothamBlack
        leftBtn.TextSize = 13
        leftBtn.AutoButtonColor = false
        leftBtn.ZIndex = 9
        Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)
        local leftStroke = Instance.new("UIStroke", leftBtn)
        leftStroke.Color = ROW_BORDER
        leftStroke.Thickness = 1
        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(0, 80, 0, 26)
        label.Position = UDim2.new(0.5, -40, 0.5, -13)
        label.BackgroundTransparency = 1
        label.Text = default
        label.TextColor3 = WHITE
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.ZIndex = 9
        local rightBtn = Instance.new("TextButton", container)
        rightBtn.Size = UDim2.new(0, 28, 0, 26)
        rightBtn.Position = UDim2.new(1, -28, 0.5, -13)
        rightBtn.BackgroundColor3 = INP
        rightBtn.BackgroundTransparency = 0.7
        rightBtn.BorderSizePixel = 0
        rightBtn.Text = ">"
        rightBtn.TextColor3 = WHITE
        rightBtn.Font = Enum.Font.GothamBlack
        rightBtn.TextSize = 13
        rightBtn.AutoButtonColor = false
        rightBtn.ZIndex = 9
        Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 6)
        local rightStroke = Instance.new("UIStroke", rightBtn)
        rightStroke.Color = ROW_BORDER
        rightStroke.Thickness = 1
        local function updateLabel(newText) label.Text = newText end
        leftBtn.MouseButton1Click:Connect(function()
            if cb then cb(-1, updateLabel) end
        end)
        rightBtn.MouseButton1Click:Connect(function()
            if cb then cb(1, updateLabel) end
        end)
        return label
    end

    local function mkBox(parent, default, w, xOff, cb)
        local tb = Instance.new("TextBox", parent)
        local bw = w or 50
        local xo = math.max(xOff or 56, bw + 12)
        tb.Size = UDim2.new(0, bw, 0, 24)
        tb.Position = UDim2.new(1, -xo, 0.5, -12)
        tb.BackgroundColor3 = INP
        tb.BackgroundTransparency = 0.7
        tb.BorderSizePixel = 0
        tb.Text = tostring(default)
        tb.TextColor3 = WHITE
        tb.Font = Enum.Font.GothamBlack
        tb.TextSize = 11
        tb.ClearTextOnFocus = false
        tb.ZIndex = 8
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
        local bs = Instance.new("UIStroke", tb)
        bs.Color = ROW_BORDER
        bs.Thickness = 1.2
        bs.Transparency = 0.25
        tb.Focused:Connect(function() TS:Create(bs, TweenInfo.new(0.12), {Color = getThemeColor(), Transparency = 0}):Play() end)
        tb.FocusLost:Connect(function()
            TS:Create(bs, TweenInfo.new(0.12), {Color = ROW_BORDER, Transparency = 0.25}):Play()
            if cb then
                local n = tonumber(tb.Text)
                if n then
                    local corrected = cb(n)
                    tb.Text = tostring(corrected or n)
                else
                    tb.Text = tostring(default)
                end
            end
        end)
        return tb
    end

    local function mkKeyButton(parent, kbEntry)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(0, 80, 0, 24)
        btn.Position = UDim2.new(1, -88, 0.5, -12)
        btn.BackgroundColor3 = INP
        btn.BackgroundTransparency = 0.5
        btn.BorderSizePixel = 0
        local function getLabel() return (kbEntry.gp and kbEntry.gp.Name) or (kbEntry.kb and kbEntry.kb.Name) or "None" end
        btn.Text = getLabel()
        btn.TextColor3 = WHITE
        btn.Font = Enum.Font.GothamBlack
        btn.TextSize = 9
        btn.ZIndex = 8
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local bs = Instance.new("UIStroke", btn)
        bs.Color = ROW_BORDER
        bs.Thickness = 1
        local li = false; local lc; local pv = btn.Text; local listenStart = 0
        btn.Activated:Connect(function()
            if li then li = false; _anyKeyListening = false; if lc then lc:Disconnect(); lc = nil end; btn.Text = pv; btn.TextColor3 = WHITE; return end
            pv = btn.Text; li = true; _anyKeyListening = true; listenStart = _tick(); btn.Text = "..."; btn.TextColor3 = WHITE
            lc = UIS.InputBegan:Connect(function(inp)
                if not li then return end
                if inp.KeyCode == Enum.KeyCode.Escape then li = false; _anyKeyListening = false; if lc then lc:Disconnect(); lc = nil end; btn.Text = pv; btn.TextColor3 = WHITE; return end
                local isGp = isGamepadInput(inp)
                if isGp and _tick()-listenStart < 0.15 then return end
                if not isBindableInput(inp) then return end
                btn.Text = inp.KeyCode.Name; pv = inp.KeyCode.Name; btn.TextColor3 = WHITE
                li = false; _anyKeyListening = false; if lc then lc:Disconnect(); lc = nil end
                if isGp then kbEntry.gp = inp.KeyCode; kbEntry.kb = nil else kbEntry.kb = inp.KeyCode; kbEntry.gp = nil end
            end)
        end)
        table.insert(keyButtonRefs, {btn = btn, entry = kbEntry})
        return btn
    end

    local function addKeybindRow(page, labelText, kbEntry)
        local row = mkRow(page, 36)
        mkLabel(row, labelText)
        mkKeyButton(row, kbEntry)
    end

    local speedPage = contentPages["Speed"]
    mkSect(speedPage, "Speed Settings")

    -- ── Speed card builder ────────────────────────────────────
    local function mkSpeedCard(page, labelText, subText, val1, val2, cb1, cb2)
        local CARD_H = 50
        local colW   = 52
        local colGap = 8
        local padR   = 12

        local card = Instance.new("Frame", page)
        card.Size = UDim2.new(1, -4, 0, CARD_H)
        card.BackgroundColor3 = ROW_BG
        card.BackgroundTransparency = 0.7
        card.BorderSizePixel = 0
        card.LayoutOrder = getNextOrder(page)
        card.ZIndex = 7
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Color = ROW_BORDER
        cardStroke.Thickness = 1
        cardStroke.Transparency = 0.5
        card.MouseEnter:Connect(function()
            TS:Create(card, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(28,28,28)}):Play()
        end)
        card.MouseLeave:Connect(function()
            TS:Create(card, TweenInfo.new(0.1), {BackgroundColor3 = ROW_BG}):Play()
        end)

        local lbl = Instance.new("TextLabel", card)
        lbl.Size = UDim2.new(1, -(padR + colW * 2 + colGap + 18), 0, 18)
        lbl.AnchorPoint = Vector2.new(0, 0.5)
        lbl.Position = UDim2.new(0, 10, 0.5, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = WHITE
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        lbl.TextStrokeTransparency = 0.5
        lbl.ZIndex = 8
        do
            local c = getThemeColor()
            local grad = Instance.new("UIGradient", lbl)
            grad.Name = "LabelThemeGrad"
            grad.Rotation = 0
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,    c),
                ColorSequenceKeypoint.new(0.35, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(0.65, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1,    c),
            })
        end

        local col2Off = padR + colW
        local col1Off = col2Off + colGap + colW

        local function mkHeader(txt, off)
            local h = Instance.new("TextLabel", card)
            h.Size = UDim2.new(0, colW, 0, 11)
            h.Position = UDim2.new(1, -off, 0, 6)
            h.BackgroundTransparency = 1
            h.Text = txt
            h.TextColor3 = Color3.fromRGB(140, 140, 155)
            h.Font = Enum.Font.GothamBlack
            h.TextSize = 9
            h.TextXAlignment = Enum.TextXAlignment.Center
            h.ZIndex = 8
            return h
        end
        mkHeader("NORMAL", col1Off)
        mkHeader("CARRY",  col2Off)

        local function mkSpeedBox(off, val, cb)
            local tb = Instance.new("TextBox", card)
            tb.Size = UDim2.new(0, colW, 0, 24)
            tb.Position = UDim2.new(1, -off, 0, 20)
            tb.BackgroundColor3 = INP
            tb.BackgroundTransparency = 0.7
            tb.BorderSizePixel = 0
            tb.Text = tostring(val)
            tb.TextColor3 = WHITE
            tb.Font = Enum.Font.GothamBlack
            tb.TextSize = 12
            tb.ClearTextOnFocus = false
            tb.ZIndex = 8
            Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
            local bs = Instance.new("UIStroke", tb)
            bs.Color = ROW_BORDER; bs.Thickness = 1.2; bs.Transparency = 0.25
            tb.Focused:Connect(function()
                TS:Create(bs, TweenInfo.new(0.12), {Color = getThemeColor(), Transparency = 0}):Play()
            end)
            tb.FocusLost:Connect(function()
                TS:Create(bs, TweenInfo.new(0.12), {Color = ROW_BORDER, Transparency = 0.25}):Play()
                local n = tonumber(tb.Text)
                if n and n > 0 and n <= 500 then
                    cb(n); saveAllSettings()
                else
                    tb.Text = tostring(val)
                end
            end)
            return tb
        end

        local tb1 = mkSpeedBox(col1Off, val1, cb1)
        local tb2 = mkSpeedBox(col2Off, val2, cb2)
        return tb1, tb2
    end

    normalBox, carryBox = mkSpeedCard(speedPage, "Normal", "default mode",
        NS, CS,
        function(v) NS = v end,
        function(v) CS = v end)

    laggerBox, lagger2Box = mkSpeedCard(speedPage, "Lagger", "lagger / carry lagger",
        LAGGER_SPEED, LAGGER_CARRY_SPEED,
        function(v) LAGGER_SPEED = v end,
        function(v) LAGGER_CARRY_SPEED = v end)
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Current Mode")
        modeValLbl = Instance.new("TextLabel", row)
        modeValLbl.Size = UDim2.new(0, 110, 1, 0)
        modeValLbl.Position = UDim2.new(1, -118, 0, 0)
        modeValLbl.BackgroundTransparency = 1
        modeValLbl.Text = "Normal"
        modeValLbl.TextColor3 = WHITE
        modeValLbl.Font = Enum.Font.GothamBlack
        modeValLbl.TextSize = 11
        modeValLbl.TextXAlignment = Enum.TextXAlignment.Right
        modeValLbl.ZIndex = 8
        local clk = Instance.new("TextButton", row)
        clk.Size = UDim2.new(1,0,1,0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.AutoButtonColor = false
        clk.ZIndex = 8
        clk.MouseButton1Click:Connect(function() toggleCarryMode() end)
    end

    mkSect(speedPage, "Auto Movement")
    autoLeftSetVisual = mkToggle(speedPage, "Auto Left", function(on)
        if on then stopAllExclusiveModes() end
        autoLeftEnabled = on
        if on then startAutoLeft() else stopAutoLeft() end
        if mobSetAutoLeft then mobSetAutoLeft(on) end
    end)
    autoRightSetVisual = mkToggle(speedPage, "Auto Right", function(on)
        if on then stopAllExclusiveModes() end
        autoRightEnabled = on
        if on then startAutoRight() else stopAutoRight() end
        if mobSetAutoRight then mobSetAutoRight(on) end
    end)

    autoTPDownSetVisual = mkToggle(speedPage, "Auto TP Down", function(on)
        toggleAutoTPDown(on)
    end)
    if autoTPDownSetVisual then autoTPDownSetVisual(autoTPDownEnabled) end
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Trigger Height")
        mkBox(row, autoTPDownHeight, 56, 66, function(v)
            v = math.clamp(math.floor(v + 0.5), 1, 100000)
            autoTPDownHeight = v
            saveAllSettings()
            return v
        end)
    end

    -- ── Auto Carry ───────────────────────────────────────────────────────
    local _acOptions = {"OFF", "WHEN NEAR", "ON STEAL"}
    local _acIdx = adaptAutoCarryEnabled and ((_G._AdaptAutoCarryMode == "ON STEAL") and 3 or 2) or 1
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Auto Carry")
        local selLabel = mkSelector(row, _acOptions[_acIdx], _acOptions, function(dir, update)
            _acIdx = _acIdx + dir
            if _acIdx < 1 then _acIdx = #_acOptions
            elseif _acIdx > #_acOptions then _acIdx = 1 end
            local chosen = _acOptions[_acIdx]
            update(chosen)
            adaptAutoCarryEnabled = (chosen ~= "OFF")
            _G._AdaptAutoCarry = adaptAutoCarryEnabled
            if adaptAutoCarryEnabled then
                _G._AdaptAutoCarryMode = chosen
                if type(_G._AdaptStartAutoCarry) == "function" then
                    pcall(_G._AdaptStartAutoCarry)
                end
            else
                if type(_G._AdaptStopAutoCarry) == "function" then
                    pcall(_G._AdaptStopAutoCarry)
                end
            end
            saveAllSettings()
        end)
        adaptAutoCarrySelectorUpdate = function(idx)
            _acIdx = idx
            if selLabel then selLabel.Text = _acOptions[idx] end
        end
    end

    mkSect(speedPage, "TP & Reset")
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "TP Down")
        local clk = Instance.new("TextButton", row)
        clk.Size = UDim2.new(0.58, 0, 1, 0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.AutoButtonColor = false
        clk.ZIndex = 8
        clk.MouseButton1Click:Connect(function() doTpDown() end)
        local actLbl = Instance.new("TextLabel", row)
        actLbl.Size = UDim2.new(0, 70, 1, 0)
        actLbl.Position = UDim2.new(1, -78, 0, 0)
        actLbl.BackgroundTransparency = 1
        actLbl.Text = "ACTIVATE"
        actLbl.TextColor3 = getThemeColor()
        actLbl.Font = Enum.Font.GothamBlack
        actLbl.TextSize = 9
        actLbl.TextXAlignment = Enum.TextXAlignment.Right
        actLbl.ZIndex = 8
    end

    local combatPage = contentPages["Combat"]

    mkSect(combatPage, "Auto Steal")
    setInstaGrab = mkToggle(combatPage, "Auto Steal", function(on)
        CONFIG.AUTO_STEAL_ENABLED = on
        if on then
            if autoGrabVariant == "v2" then pcall(startAutoStealV2) else pcall(startAutoSteal) end
        else
            stopAutoSteal()
        end
        updateProgressBarVisibility()
    end)

    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Bar Scale")
        -- Uses pbScale (UIScale) so every descendant scales proportionally.
        local currentScale = _clamp(pbBarScaleValue, 50, 150)
        pbBarScaleBox = mkBox(row, currentScale, 56, 66, function(v)
            v = _clamp(math.floor(v), 50, 150)
            pbBarScaleValue = v
            if pbScale then pbScale.Scale = v / 100 end
            saveAllSettings()
            return v
        end)
    end

    -- ── Stop At row (V1 only) ──────────────────────────────────────────────
    local stopAtRow
    do
        stopAtRow = mkRow(combatPage, 38)
        stopAtRow.Visible = (autoGrabVariant == "v1")
        mkLabel(stopAtRow, "Stop At")
        stopAtBox = mkBox(stopAtRow, autoGrabStopPct, 56, 66, function(v)
            v = _clamp(math.floor(v + 0.5), 1, 95)
            autoGrabStopPct = v
            if stopAtBox then stopAtBox.Text = tostring(v) end
            saveAllSettings()
            return v
        end)
        local pctLbl = Instance.new("TextLabel", stopAtRow)
        pctLbl.Size = UDim2.new(0, 18, 1, 0)
        pctLbl.Position = UDim2.new(1, -24, 0, 0)
        pctLbl.BackgroundTransparency = 1
        pctLbl.Text = "%"
        pctLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
        pctLbl.Font = Enum.Font.GothamBlack
        pctLbl.TextSize = 12
        pctLbl.TextXAlignment = Enum.TextXAlignment.Left
        pctLbl.ZIndex = 6
    end

    -- ── Auto Steal Version switcher (V1 / V2) ────────────────────────────────
    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Version")
        local agvSelectorBtn = Instance.new("TextButton", row)
        agvSelectorBtn.Size = UDim2.new(0, 100, 1, 0)
        agvSelectorBtn.Position = UDim2.new(1, -108, 0, 0)
        agvSelectorBtn.BackgroundColor3 = Color3.fromRGB(12,12,12)
        agvSelectorBtn.BackgroundTransparency = 0.7
        agvSelectorBtn.BorderSizePixel = 0
        agvSelectorBtn.Text = "V1 v"
        agvSelectorBtn.TextColor3 = Color3.fromRGB(255,255,255)
        agvSelectorBtn.Font = Enum.Font.GothamBlack
        agvSelectorBtn.TextSize = 12
        agvSelectorBtn.AutoButtonColor = false
        agvSelectorBtn.ZIndex = 8
        Instance.new("UICorner", agvSelectorBtn).CornerRadius = UDim.new(0, 6)
        local agvSelStroke = Instance.new("UIStroke", agvSelectorBtn)
        agvSelStroke.Color = Color3.fromRGB(50,50,50)
        agvSelStroke.Thickness = 1

        local AGV_OPTION_H = 30
        local agvOptions = {"V1", "V2"}
        local agvBodyOpenHeight = #agvOptions * AGV_OPTION_H + 8

        local agvBody = Instance.new("Frame", combatPage)
        agvBody.Size = UDim2.new(1, -4, 0, 0)
        agvBody.BackgroundColor3 = Color3.fromRGB(14,14,18)
        agvBody.BackgroundTransparency = 0.55
        agvBody.BorderSizePixel = 0
        agvBody.ClipsDescendants = true
        agvBody.LayoutOrder = getNextOrder(combatPage)
        agvBody.ZIndex = 7
        Instance.new("UICorner", agvBody).CornerRadius = UDim.new(0, 10)
        local agvBodyStroke = Instance.new("UIStroke", agvBody)
        agvBodyStroke.Color = Color3.fromRGB(50,50,50)
        agvBodyStroke.Thickness = 1
        agvBodyStroke.Transparency = 0.5

        local agvOptionButtons = {}
        for i, opt in ipairs(agvOptions) do
            local btn = Instance.new("TextButton", agvBody)
            btn.Size = UDim2.new(1, -8, 0, AGV_OPTION_H - 4)
            btn.Position = UDim2.new(0, 4, 0, 4 + (i-1)*AGV_OPTION_H)
            btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
            btn.BackgroundTransparency = 0.5
            btn.BorderSizePixel = 0
            btn.Text = opt
            btn.TextColor3 = Color3.fromRGB(255,255,255)
            btn.Font = Enum.Font.GothamBlack
            btn.TextSize = 12
            btn.ZIndex = 8
            btn.AutoButtonColor = false
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            agvOptionButtons[opt] = btn
        end

        local agvExpanded = false

        local function updateAutoGrabVariantUI(ver)
            local label = ver:upper()
            agvSelectorBtn.Text = label .. (agvExpanded and " ^" or " v")
            for opt, btn in pairs(agvOptionButtons) do
                if opt:lower() == ver then
                    btn.BackgroundColor3 = getThemeColor()
                    btn.BackgroundTransparency = 0
                    btn.TextColor3 = Color3.fromRGB(0,0,0)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    btn.BackgroundTransparency = 0.5
                    btn.TextColor3 = Color3.fromRGB(255,255,255)
                end
            end
        end

        local function setAgvExpanded(state)
            agvExpanded = state
            TS:Create(agvBody, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -4, 0, agvExpanded and agvBodyOpenHeight or 0)
            }):Play()
            updateAutoGrabVariantUI(autoGrabVariant)
        end

        local function applyAutoGrabVariant(ver)
            local wasEnabled = CONFIG.AUTO_STEAL_ENABLED
            autoGrabVariant = ver
            stopAutoSteal()
            if wasEnabled then
                CONFIG.AUTO_STEAL_ENABLED = true
                if ver == "v2" then
                    pcall(startAutoStealV2)
                else
                    pcall(startAutoSteal)
                end
            end
            if stopAtRow then stopAtRow.Visible = (ver == "v1") end
            updateAutoGrabVariantUI(ver)
            saveAllSettings()
        end

        for opt, btn in pairs(agvOptionButtons) do
            btn.MouseButton1Click:Connect(function()
                applyAutoGrabVariant(opt:lower())
                setAgvExpanded(false)
            end)
        end

        agvSelectorBtn.MouseButton1Click:Connect(function()
            setAgvExpanded(not agvExpanded)
        end)

        _G.updateAutoGrabVariantUI = updateAutoGrabVariantUI
        updateAutoGrabVariantUI(autoGrabVariant)
    end
    -- ── end Auto Steal Version switcher ──

    do
        -- Steal Radius hidden from UI (editable via CONFIG.STEAL_RANGE directly)
        radInput = Instance.new("TextBox")
        radInput.Text = tostring(CONFIG.STEAL_RANGE)
        radInput:GetPropertyChangedSignal("Text"):Connect(function()
            local v = tonumber(radInput.Text)
            if v and v >= 5 and v <= 300 then
                CONFIG.STEAL_RANGE = _floor(v+0.5)
                Steal.StealRadius = CONFIG.STEAL_RANGE
                saveAllSettings()
            end
        end)
    end

    mkSect(combatPage, "Anti Ragdoll")
    do
        -- Chip row: label + current-value chip with an arrow. Clicking it
        -- rolls the switcher open INLINE (own row, pushes rows below it
        -- down via UIListLayout) instead of floating an overlay elsewhere.
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Anti Ragdoll")
        local selectorBtn = Instance.new("TextButton", row)
        selectorBtn.Size = UDim2.new(0, 100, 1, 0)
        selectorBtn.Position = UDim2.new(1, -108, 0, 0)
        selectorBtn.BackgroundColor3 = Color3.fromRGB(12,12,12)
        selectorBtn.BackgroundTransparency = 0.7
        selectorBtn.BorderSizePixel = 0
        selectorBtn.Text = "Off v"
        selectorBtn.TextColor3 = Color3.fromRGB(255,255,255)
        selectorBtn.Font = Enum.Font.GothamBlack
        selectorBtn.TextSize = 12
        selectorBtn.AutoButtonColor = false
        selectorBtn.ZIndex = 8
        Instance.new("UICorner", selectorBtn).CornerRadius = UDim.new(0, 6)
        local selStroke = Instance.new("UIStroke", selectorBtn)
        selStroke.Color = Color3.fromRGB(50,50,50)
        selStroke.Thickness = 1

        -- Accordion body: its own row in the same page/layout, starts
        -- collapsed (Size.Y = 0, clipped). Expanding it tweens the height
        -- open, which is what makes the rows below "roll down" / add space.
        local OPTION_H = 30
        local options = {"Off", "V1", "V2"}
        local bodyOpenHeight = #options * OPTION_H + 8

        local body = Instance.new("Frame", combatPage)
        body.Size = UDim2.new(1, -4, 0, 0)
        body.BackgroundColor3 = Color3.fromRGB(14,14,18)
        body.BackgroundTransparency = 0.55
        body.BorderSizePixel = 0
        body.ClipsDescendants = true
        body.LayoutOrder = getNextOrder(combatPage)
        body.ZIndex = 7
        Instance.new("UICorner", body).CornerRadius = UDim.new(0, 10)
        local bodyStroke = Instance.new("UIStroke", body)
        bodyStroke.Color = Color3.fromRGB(50,50,50)
        bodyStroke.Thickness = 1
        bodyStroke.Transparency = 0.5

        local optionButtons = {}
        for i, opt in ipairs(options) do
            local btn = Instance.new("TextButton", body)
            btn.Size = UDim2.new(1, -8, 0, OPTION_H - 4)
            btn.Position = UDim2.new(0, 4, 0, 4 + (i-1)*OPTION_H)
            btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
            btn.BackgroundTransparency = 0.5
            btn.BorderSizePixel = 0
            btn.Text = opt
            btn.TextColor3 = Color3.fromRGB(255,255,255)
            btn.Font = Enum.Font.GothamBlack
            btn.TextSize = 12
            btn.ZIndex = 8
            btn.AutoButtonColor = false
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            optionButtons[opt] = btn
        end

        local expanded = false

        local function updateAntiRagdollUI(mode)
            local label = mode:gsub("^%l", string.upper)
            if mode == "off" then label = "Off" end
            selectorBtn.Text = label .. (expanded and " ^" or " v")
            -- Selected option lights up with the same accent used for an
            -- active toggle; unselected options stay dim/neutral.
            for opt, btn in pairs(optionButtons) do
                if opt:lower() == mode then
                    btn.BackgroundColor3 = getThemeColor()
                    btn.BackgroundTransparency = 0
                    btn.TextColor3 = Color3.fromRGB(0,0,0)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    btn.BackgroundTransparency = 0.5
                    btn.TextColor3 = Color3.fromRGB(255,255,255)
                end
            end
        end

        local function setExpanded(state)
            expanded = state
            TS:Create(body, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -4, 0, expanded and bodyOpenHeight or 0)
            }):Play()
            updateAntiRagdollUI(antiRagdollMode)
        end

        for opt, btn in pairs(optionButtons) do
            btn.MouseButton1Click:Connect(function()
                setAntiRagdollMode(opt:lower())
                setExpanded(false)
            end)
        end

        selectorBtn.MouseButton1Click:Connect(function()
            setExpanded(not expanded)
        end)

        _G.updateAntiRagdollUI = updateAntiRagdollUI
        updateAntiRagdollUI(antiRagdollMode)
    end

    setUnwalkVisual = mkToggle(combatPage, "Unwalk", function(on)
        unwalkEnabled = on
        if on then startUnwalk() else stopUnwalk() end
    end)

    setAntiDieVisual = mkToggle(combatPage, "Anti Die", function(on)
        antiDieEnabled = on
        if on then AntiDieModule.start() else AntiDieModule.stop() end
        saveAllSettings()
    end)
    if setAntiDieVisual then setAntiDieVisual(antiDieEnabled) end

    mkSect(combatPage, "Drop")
    dropBrainrotSetVisual = mkToggle(combatPage, "Drop Brainrot", function(on)
        if on then
            executeDropWithToggle(function(v)
                dropBrainrotSetVisual(v)
                if mobSetDropBR then mobSetDropBR(v) end
            end)
        end
    end)

    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Drop Mode")
        dropModeBtnRef = mkSelector(row, dropMode == 1 and "Fling" or "Jump Drop", {"Fling", "Jump Drop"}, function(dir, update)
            if dropActive then stopDropBrainrot() end
            dropMode = dropMode == 1 and 2 or 1
            update(dropMode == 1 and "Fling" or "Jump Drop")
        end)
    end

    mkSect(combatPage, "Counters")
    setBatCounterVisual = mkToggle(combatPage, "Bat Counter", function(on)
        batCounterEnabled = on
        if on then startBatCounter() else stopBatCounter() end
    end)

    setMedusaVisual = mkToggle(combatPage, "Medusa Counter", function(on)
        medusaCounterEnabled = on
        if on then
            if LP.Character then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
        else
            stopMedusaCounter()
        end
        if setMedusaVisual then setMedusaVisual(on) end
    end)

    mkSect(combatPage, "Defense")
    bodyLockSetVisual = mkToggle(combatPage, "Body Lock", function(on)
        bodyLockEnabled = on
        if on then
            if _blSuppressCount == 0 then startBodyLock() end
        else
            stopBodyLock()
        end
    end)
    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Body Lock Range")
        bodyLockRangeBox = mkBox(row, bodyLockRange, 50, 56, function(v)
            if v and v > 0 then
                bodyLockRange = _clamp(_floor(v), 5, 200)
                if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
            end
        end)
    end

    mkSect(combatPage, "Aimbots")
    do local row = mkRow(combatPage, 38); mkLabel(row, "Bat Aimbot Speed"); batSpeedBox = mkBox(row, BAT_AIMBOT_SPEED, 50, 56, function(v) if v > 0 and v <= 200 then BAT_AIMBOT_SPEED = v; saveAllSettings() end end) end
    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Lagger Aimbot Spd")
        laggerBatSpeedBox = mkBox(row, LAGGER_AIMBOT_SPEED, 50, 56, function(v)
            if v > 0 and v <= 200 then
                LAGGER_AIMBOT_SPEED = v
                saveAllSettings()
            end
        end)
    end

    autoBatSetVisual = mkToggle(combatPage, "Auto Bat", function(on)
        if on then
            stopAllExclusiveModes()
            if batAimbotVariant == "bypass" then enableBatV3()
            elseif batAimbotVariant == "v2" then enableBatV2()
            else enableAutoBat() end
        else
            if batAimbotVariant == "bypass" then disableBatV3()
            elseif batAimbotVariant == "v2" then disableBatV2()
            else disableAutoBat() end
        end
        if mobSetAutoBat then mobSetAutoBat(isAimbotEnabled()) end
    end)

    mirrorTpSetVisual = mkToggle(combatPage, "Mirror TP Down", function(on)
        mirrorTpEnabled = on
        saveAllSettings()
    end)
    if mirrorTpSetVisual then mirrorTpSetVisual(mirrorTpEnabled) end

    -- ── Aimbot switcher (V1 = Auto Bat engine / V2 = Bat V2 engine) ──
    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Aimbot Mode")
        local bavSelectorBtn = Instance.new("TextButton", row)
        bavSelectorBtn.Size = UDim2.new(0, 100, 1, 0)
        bavSelectorBtn.Position = UDim2.new(1, -108, 0, 0)
        bavSelectorBtn.BackgroundColor3 = Color3.fromRGB(12,12,12)
        bavSelectorBtn.BackgroundTransparency = 0.7
        bavSelectorBtn.BorderSizePixel = 0
        bavSelectorBtn.Text = "V1 v"
        bavSelectorBtn.TextColor3 = Color3.fromRGB(255,255,255)
        bavSelectorBtn.Font = Enum.Font.GothamBlack
        bavSelectorBtn.TextSize = 12
        bavSelectorBtn.AutoButtonColor = false
        bavSelectorBtn.ZIndex = 8
        Instance.new("UICorner", bavSelectorBtn).CornerRadius = UDim.new(0, 6)
        local bavSelStroke = Instance.new("UIStroke", bavSelectorBtn)
        bavSelStroke.Color = Color3.fromRGB(50,50,50)
        bavSelStroke.Thickness = 1

        local BAV_OPTION_H = 30
        local bavOptions = {"V1", "V2", "Bypass"}
        local bavBodyOpenHeight = #bavOptions * BAV_OPTION_H + 8

        local bavBody = Instance.new("Frame", combatPage)
        bavBody.Size = UDim2.new(1, -4, 0, 0)
        bavBody.BackgroundColor3 = Color3.fromRGB(14,14,18)
        bavBody.BackgroundTransparency = 0.55
        bavBody.BorderSizePixel = 0
        bavBody.ClipsDescendants = true
        bavBody.LayoutOrder = getNextOrder(combatPage)
        bavBody.ZIndex = 7
        Instance.new("UICorner", bavBody).CornerRadius = UDim.new(0, 10)
        local bavBodyStroke = Instance.new("UIStroke", bavBody)
        bavBodyStroke.Color = Color3.fromRGB(50,50,50)
        bavBodyStroke.Thickness = 1
        bavBodyStroke.Transparency = 0.5

        local bavOptionButtons = {}
        for i, opt in ipairs(bavOptions) do
            local btn = Instance.new("TextButton", bavBody)
            btn.Size = UDim2.new(1, -8, 0, BAV_OPTION_H - 4)
            btn.Position = UDim2.new(0, 4, 0, 4 + (i-1)*BAV_OPTION_H)
            btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
            btn.BackgroundTransparency = 0.5
            btn.BorderSizePixel = 0
            btn.Text = opt
            btn.TextColor3 = Color3.fromRGB(255,255,255)
            btn.Font = Enum.Font.GothamBlack
            btn.TextSize = 12
            btn.ZIndex = 8
            btn.AutoButtonColor = false
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            bavOptionButtons[opt] = btn
        end

        local bavExpanded = false

        local function updateBatAimbotVariantUI(ver)
            local label = ver:upper()
            bavSelectorBtn.Text = label .. (bavExpanded and " ^" or " v")
            for opt, btn in pairs(bavOptionButtons) do
                if opt:lower() == ver then
                    btn.BackgroundColor3 = getThemeColor()
                    btn.BackgroundTransparency = 0
                    btn.TextColor3 = Color3.fromRGB(0,0,0)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    btn.BackgroundTransparency = 0.5
                    btn.TextColor3 = Color3.fromRGB(255,255,255)
                end
            end
        end

        local function setBavExpanded(state)
            bavExpanded = state
            TS:Create(bavBody, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -4, 0, bavExpanded and bavBodyOpenHeight or 0)
            }):Play()
            updateBatAimbotVariantUI(batAimbotVariant)
        end

        local function applyBatAimbotVariant(ver)
            -- Switching engines while Auto Bat is running restarts it
            -- under the newly selected engine so the change takes effect
            -- immediately, matching how TP Bat's own V1/V2 switch works.
            local wasEnabled = autoBatEnabled or autoBatV2Enabled or autoBatV3Enabled
            if wasEnabled then
                disableAutoBat()
                disableBatV2()
                disableBatV3()
            end
            batAimbotVariant = ver
            if wasEnabled then
                if ver == "bypass" then
                    enableBatV3()
                elseif ver == "v2" then
                    enableBatV2()
                else
                    enableAutoBat()
                end
                -- sync the pill for whichever variant just started
                if autoBatSetVisual then autoBatSetVisual(isAimbotEnabled()) end
                if mobSetAutoBat then mobSetAutoBat(isAimbotEnabled()) end
            end
            updateBatAimbotVariantUI(ver)
            saveAllSettings()
        end

        for opt, btn in pairs(bavOptionButtons) do
            btn.MouseButton1Click:Connect(function()
                applyBatAimbotVariant(opt:lower())
                setBavExpanded(false)
            end)
        end

        bavSelectorBtn.MouseButton1Click:Connect(function()
            setBavExpanded(not bavExpanded)
        end)

        _G.updateBatAimbotVariantUI = updateBatAimbotVariantUI
        updateBatAimbotVariantUI(batAimbotVariant)
    end
    -- ── end Aimbot switcher ──

    batDesyncTpSetVisual = mkToggle(combatPage, "TP BAT", function(on)
        if on then
            stopAllExclusiveModes()
            if not batDesyncTpEnabled then toggleBatDesyncTp() end
        else
            if batDesyncTpEnabled then toggleBatDesyncTp() end
        end
    end)
    if batDesyncTpSetVisual then batDesyncTpSetVisual(batDesyncTpEnabled) end

    local visualPage = contentPages["Visual"]

    mkSect(visualPage, "Interface")

    setLockUIVisual = mkToggle(visualPage, "Lock UI", function(on)
        toggleLockUI(on)
    end)

    mkSect(visualPage, "Personalization")
    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Anim Pack")
        local currentIndex = 1
        for i, entry in ipairs(ANIM_PACK_ORDER) do
            if entry[2] == currentAnimPack then currentIndex = i; break end
        end
        local container = Instance.new("Frame", row)
        container.Size = UDim2.new(0, 160, 1, 0)
        container.Position = UDim2.new(1, -168, 0, 0)
        container.BackgroundTransparency = 1
        container.ZIndex = 8
        local leftBtn = Instance.new("TextButton", container)
        leftBtn.Size = UDim2.new(0, 28, 0, 26)
        leftBtn.Position = UDim2.new(0, 0, 0.5, -13)
        leftBtn.BackgroundColor3 = INP
        leftBtn.BackgroundTransparency = 0.7
        leftBtn.BorderSizePixel = 0
        leftBtn.Text = "<"
        leftBtn.TextColor3 = WHITE
        leftBtn.Font = Enum.Font.GothamBlack
        leftBtn.TextSize = 13
        leftBtn.AutoButtonColor = false
        leftBtn.ZIndex = 9
        Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)
        local leftStroke = Instance.new("UIStroke", leftBtn)
        leftStroke.Color = ROW_BORDER
        leftStroke.Thickness = 1
        animSelectorLabel = Instance.new("TextLabel", container)
        animSelectorLabel.Size = UDim2.new(0, 80, 0, 26)
        animSelectorLabel.Position = UDim2.new(0.5, -40, 0.5, -13)
        animSelectorLabel.BackgroundTransparency = 1
        animSelectorLabel.Text = ANIM_PACK_ORDER[currentIndex][2]
        animSelectorLabel.TextColor3 = WHITE
        animSelectorLabel.Font = Enum.Font.GothamBlack
        animSelectorLabel.TextSize = 12
        animSelectorLabel.TextXAlignment = Enum.TextXAlignment.Center
        animSelectorLabel.ZIndex = 9
        local rightBtn = Instance.new("TextButton", container)
        rightBtn.Size = UDim2.new(0, 28, 0, 26)
        rightBtn.Position = UDim2.new(1, -28, 0.5, -13)
        rightBtn.BackgroundColor3 = INP
        rightBtn.BackgroundTransparency = 0.7
        rightBtn.BorderSizePixel = 0
        rightBtn.Text = ">"
        rightBtn.TextColor3 = WHITE
        rightBtn.Font = Enum.Font.GothamBlack
        rightBtn.TextSize = 13
        rightBtn.AutoButtonColor = false
        rightBtn.ZIndex = 9
        Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 6)
        local rightStroke = Instance.new("UIStroke", rightBtn)
        rightStroke.Color = ROW_BORDER
        rightStroke.Thickness = 1
        local function updateAnimSelector(direction)
            local idx = 1
            for i, entry in ipairs(ANIM_PACK_ORDER) do
                if entry[2] == currentAnimPack then idx = i; break end
            end
            local newIdx = idx + direction
            if newIdx < 1 then newIdx = #ANIM_PACK_ORDER end
            if newIdx > #ANIM_PACK_ORDER then newIdx = 1 end
            local packName = ANIM_PACK_ORDER[newIdx][2]
            if packName == "Off" then
                stopAnimPack()
            else
                startAnimPack(packName)
            end
        end
        leftBtn.MouseButton1Click:Connect(function() updateAnimSelector(-1) end)
        rightBtn.MouseButton1Click:Connect(function() updateAnimSelector(1) end)
    end

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Outfit")
        local container = Instance.new("Frame", row)
        container.Size = UDim2.new(0, 160, 1, 0)
        container.Position = UDim2.new(1, -168, 0, 0)
        container.BackgroundTransparency = 1
        container.ZIndex = 8
        local leftBtn = Instance.new("TextButton", container)
        leftBtn.Size = UDim2.new(0, 28, 0, 26)
        leftBtn.Position = UDim2.new(0, 0, 0.5, -13)
        leftBtn.BackgroundColor3 = INP
        leftBtn.BackgroundTransparency = 0.7
        leftBtn.BorderSizePixel = 0
        leftBtn.Text = "<"
        leftBtn.TextColor3 = WHITE
        leftBtn.Font = Enum.Font.GothamBlack
        leftBtn.TextSize = 13
        leftBtn.AutoButtonColor = false
        leftBtn.ZIndex = 9
        Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)
        local leftStroke = Instance.new("UIStroke", leftBtn)
        leftStroke.Color = ROW_BORDER
        leftStroke.Thickness = 1
        outfitSelectorLabel = Instance.new("TextLabel", container)
        outfitSelectorLabel.Size = UDim2.new(0, 80, 0, 26)
        outfitSelectorLabel.Position = UDim2.new(0.5, -40, 0.5, -13)
        outfitSelectorLabel.BackgroundTransparency = 1
        outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
        outfitSelectorLabel.TextColor3 = WHITE
        outfitSelectorLabel.Font = Enum.Font.GothamBlack
        outfitSelectorLabel.TextSize = 12
        outfitSelectorLabel.TextXAlignment = Enum.TextXAlignment.Center
        outfitSelectorLabel.ZIndex = 9
        local rightBtn = Instance.new("TextButton", container)
        rightBtn.Size = UDim2.new(0, 28, 0, 26)
        rightBtn.Position = UDim2.new(1, -28, 0.5, -13)
        rightBtn.BackgroundColor3 = INP
        rightBtn.BackgroundTransparency = 0.7
        rightBtn.BorderSizePixel = 0
        rightBtn.Text = ">"
        rightBtn.TextColor3 = WHITE
        rightBtn.Font = Enum.Font.GothamBlack
        rightBtn.TextSize = 13
        rightBtn.AutoButtonColor = false
        rightBtn.ZIndex = 9
        Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 6)
        local rightStroke = Instance.new("UIStroke", rightBtn)
        rightStroke.Color = ROW_BORDER
        rightStroke.Thickness = 1
        local function updateOutfit(direction)
            local newIdx = currentOutfitIndex + direction
            if newIdx < 1 then newIdx = #OUTFITS end
            if newIdx > #OUTFITS then newIdx = 1 end
            currentOutfitIndex = newIdx
            pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
            if outfitSelectorLabel then
                outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
            end
            saveAllSettings()
        end
        leftBtn.MouseButton1Click:Connect(function() updateOutfit(-1) end)
        rightBtn.MouseButton1Click:Connect(function() updateOutfit(1) end)
    end

    mkSect(visualPage, "Color Theme")
    do
        local colorThemesList = {"Gray","Purple","Blue","Pink","Green","Vanilla","Black","Violet","Red","Cyan","Orange","Gold"}
        local swatchBtns = {}

        local swatchRow = Instance.new("Frame", visualPage)
        swatchRow.Name = "ColorSwatchRow"
        swatchRow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        swatchRow.BackgroundTransparency = 0.3
        swatchRow.Size = UDim2.new(1, 0, 0, 54)
        swatchRow.BorderSizePixel = 0
        swatchRow.LayoutOrder = 0

        local swatchScroll = Instance.new("ScrollingFrame", swatchRow)
        swatchScroll.Size = UDim2.new(1, -52, 1, 0)
        swatchScroll.Position = UDim2.new(0, 26, 0, 0)
        swatchScroll.BackgroundTransparency = 1
        swatchScroll.BorderSizePixel = 0
        swatchScroll.ScrollBarThickness = 0
        swatchScroll.ScrollingDirection = Enum.ScrollingDirection.X
        swatchScroll.CanvasSize = UDim2.new(0, (#colorThemesList) * 48 + 4, 0, 0)
        swatchScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
        swatchScroll.ZIndex = 5

        local swatchList = Instance.new("UIListLayout", swatchScroll)
        swatchList.FillDirection = Enum.FillDirection.Horizontal
        swatchList.Padding = UDim.new(0, 6)
        swatchList.SortOrder = Enum.SortOrder.LayoutOrder
        swatchList.VerticalAlignment = Enum.VerticalAlignment.Center
        local swatchPad = Instance.new("UIPadding", swatchScroll)
        swatchPad.PaddingLeft = UDim.new(0, 4)
        swatchPad.PaddingRight = UDim.new(0, 4)

        local swLeft = Instance.new("TextButton", swatchRow)
        swLeft.Name = "SwArrowLeft"
        swLeft.Text = "<"
        swLeft.Size = UDim2.new(0, 22, 0, 34)
        swLeft.Position = UDim2.new(0, 3, 0.5, -17)
        swLeft.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
        swLeft.BackgroundTransparency = 0.05
        swLeft.BorderSizePixel = 0
        swLeft.TextColor3 = WHITE
        swLeft.TextSize = 18
        swLeft.Font = Enum.Font.GothamBlack
        swLeft.AutoButtonColor = false
        swLeft.ZIndex = 8
        Instance.new("UICorner", swLeft).CornerRadius = UDim.new(0, 7)

        local swRight = Instance.new("TextButton", swatchRow)
        swRight.Name = "SwArrowRight"
        swRight.Text = ">"
        swRight.Size = UDim2.new(0, 22, 0, 34)
        swRight.Position = UDim2.new(1, -25, 0.5, -17)
        swRight.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
        swRight.BackgroundTransparency = 0.05
        swRight.BorderSizePixel = 0
        swRight.TextColor3 = WHITE
        swRight.TextSize = 18
        swRight.Font = Enum.Font.GothamBlack
        swRight.AutoButtonColor = false
        swRight.ZIndex = 8
        Instance.new("UICorner", swRight).CornerRadius = UDim.new(0, 7)

        swLeft.MouseButton1Click:Connect(function()
            local pos = swatchScroll.CanvasPosition
            TS:Create(swatchScroll, TweenInfo.new(0.2), {CanvasPosition = Vector2.new(math.max(0, pos.X - 54), 0)}):Play()
        end)
        swRight.MouseButton1Click:Connect(function()
            local pos = swatchScroll.CanvasPosition
            TS:Create(swatchScroll, TweenInfo.new(0.2), {CanvasPosition = Vector2.new(pos.X + 54, 0)}):Play()
        end)

        local function refreshSwatchHighlight()
            for _, entry in ipairs(swatchBtns) do
                local sel = entry.name == currentColorTheme
                local st = entry.btn:FindFirstChildOfClass("UIStroke")
                if st then
                    st.Color = sel and WHITE or Color3.fromRGB(60, 60, 60)
                    st.Transparency = sel and 0 or 0.5
                    st.Thickness = sel and 2 or 1
                end
                entry.btn.BackgroundTransparency = sel and 0 or 0.3
            end
        end

        for idx, themeName in ipairs(colorThemesList) do
            local themeColor = COLOR_THEMES[themeName]
            local swatch = Instance.new("TextButton", swatchScroll)
            swatch.Name = "Swatch_" .. themeName
            swatch.LayoutOrder = idx
            swatch.Size = UDim2.new(0, 42, 0, 38)
            swatch.BackgroundColor3 = Color3.new(1, 1, 1)
            swatch.BackgroundTransparency = themeName == currentColorTheme and 0 or 0.3
            swatch.BorderSizePixel = 0
            swatch.Text = ""
            swatch.AutoButtonColor = false
            swatch.ZIndex = 6
            Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 10)

            local swGrad = Instance.new("UIGradient", swatch)
            swGrad.Rotation = 135
            swGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,    themeColor:Lerp(Color3.new(1,1,1), 0.50)),
                ColorSequenceKeypoint.new(0.45, themeColor),
                ColorSequenceKeypoint.new(1,    themeColor:Lerp(Color3.new(0,0,0), 0.35)),
            })

            local st = Instance.new("UIStroke", swatch)
            st.Color = themeName == currentColorTheme and WHITE or Color3.fromRGB(60, 60, 60)
            st.Transparency = themeName == currentColorTheme and 0 or 0.5
            st.Thickness = themeName == currentColorTheme and 2 or 1

            -- Theme name label inside swatch
            local nameLabel = Instance.new("TextLabel", swatch)
            nameLabel.Size = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = themeName
            nameLabel.TextColor3 = WHITE
            nameLabel.Font = Enum.Font.GothamBlack
            nameLabel.TextSize = 9
            nameLabel.TextXAlignment = Enum.TextXAlignment.Center
            nameLabel.TextYAlignment = Enum.TextYAlignment.Center
            nameLabel.TextStrokeTransparency = 0.3
            nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            nameLabel.ZIndex = 7

            table.insert(swatchBtns, { btn = swatch, name = themeName })

            swatch.MouseButton1Click:Connect(function()
                applyColorTheme(themeName)
                refreshSwatchHighlight()
            end)
        end

        -- Single source of truth now — no second picker to keep in sync with.
        local _origApplyColorTheme = applyColorTheme
        applyColorTheme = function(themeName)
            _origApplyColorTheme(themeName)
            refreshSwatchHighlight()
        end

        refreshSwatchHighlight()
    end

    setESPVIsual = mkToggle(visualPage, "Player ESP", function(on) toggleESP(on) end)

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Stretch Rez")
        local stretchPill, stretchDot = mkPill(row, 48)
        local stretchOn = false
        local function setStretch(s)
            stretchOn = s
            animPill(stretchPill, stretchDot, s)
            if s then enableStretch() else disableStretch() end
            stretchEnabled = s
        end
        local stretchClk = Instance.new("TextButton", stretchPill)
        stretchClk.Size = UDim2.new(1,0,1,0)
        stretchClk.BackgroundTransparency = 1
        stretchClk.Text = ""
        stretchClk.AutoButtonColor = false
        stretchClk.ZIndex = 10
        stretchClk.MouseButton1Click:Connect(function() setStretch(not stretchOn) end)
        _G.stretchToggleSetter = setStretch
    end

    setFovVisual = mkToggle(visualPage, "FOV", function(on)
        if on then enableCustomFov() else disableCustomFov() end
    end)
    if setFovVisual then setFovVisual(fovEnabled) end

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "FOV Value")
        fovSliderSet = mkSlider(row, 20, 120, fovValue, function(v)
            fovValue = v
            if not fovEnabled then
                enableCustomFov()
                if setFovVisual then setFovVisual(true) end
            end
            local cam = workspace.CurrentCamera
            if cam then pcall(function() cam.FieldOfView = fovValue end) end
        end)
    end

    setAntiLagVisual = mkToggle(visualPage, "Anti Lag", function(on)
        if on then enableAntiLag() else disableAntiLag() end
    end)

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Sky Theme")
        local container = Instance.new("Frame", row)
        container.Size = UDim2.new(0, 160, 1, 0)
        container.Position = UDim2.new(1, -168, 0, 0)
        container.BackgroundTransparency = 1
        container.ZIndex = 8
        local leftBtn = Instance.new("TextButton", container)
        leftBtn.Size = UDim2.new(0, 28, 0, 26)
        leftBtn.Position = UDim2.new(0, 0, 0.5, -13)
        leftBtn.BackgroundColor3 = INP
        leftBtn.BackgroundTransparency = 0.7
        leftBtn.BorderSizePixel = 0
        leftBtn.Text = "<"
        leftBtn.TextColor3 = WHITE
        leftBtn.Font = Enum.Font.GothamBlack
        leftBtn.TextSize = 13
        leftBtn.AutoButtonColor = false
        leftBtn.ZIndex = 9
        Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)
        local leftStroke = Instance.new("UIStroke", leftBtn)
        leftStroke.Color = ROW_BORDER
        leftStroke.Thickness = 1
        skySelectorLabel = Instance.new("TextLabel", container)
        skySelectorLabel.Size = UDim2.new(0, 96, 0, 26)
        skySelectorLabel.Position = UDim2.new(0.5, -48, 0.5, -13)
        skySelectorLabel.BackgroundTransparency = 1
        skySelectorLabel.Text = skyTheme
        skySelectorLabel.TextColor3 = WHITE
        skySelectorLabel.Font = Enum.Font.GothamBlack
        skySelectorLabel.TextSize = 11
        skySelectorLabel.TextScaled = false
        skySelectorLabel.TextXAlignment = Enum.TextXAlignment.Center
        skySelectorLabel.ZIndex = 9
        local rightBtn = Instance.new("TextButton", container)
        rightBtn.Size = UDim2.new(0, 28, 0, 26)
        rightBtn.Position = UDim2.new(1, -28, 0.5, -13)
        rightBtn.BackgroundColor3 = INP
        rightBtn.BackgroundTransparency = 0.7
        rightBtn.BorderSizePixel = 0
        rightBtn.Text = ">"
        rightBtn.TextColor3 = WHITE
        rightBtn.Font = Enum.Font.GothamBlack
        rightBtn.TextSize = 13
        rightBtn.AutoButtonColor = false
        rightBtn.ZIndex = 9
        Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 6)
        local rightStroke = Instance.new("UIStroke", rightBtn)
        rightStroke.Color = ROW_BORDER
        rightStroke.Thickness = 1
        local function updateSkySelector(direction)
            local idx = 1
            for i, name in ipairs(SKY_PRESETS_LIST) do
                if name == skyTheme then idx = i; break end
            end
            local newIdx = idx + direction
            if newIdx < 1 then newIdx = #SKY_PRESETS_LIST end
            if newIdx > #SKY_PRESETS_LIST then newIdx = 1 end
            local name = SKY_PRESETS_LIST[newIdx]
            skyTheme = name
            pcall(applyCustomSky, name)
            if skySelectorLabel then skySelectorLabel.Text = name end
            pcall(saveAllSettings)
        end
        leftBtn.MouseButton1Click:Connect(function() updateSkySelector(-1) end)
        rightBtn.MouseButton1Click:Connect(function() updateSkySelector(1) end)
    end

    for _, cat in ipairs({"bat", "medusa"}) do
        local row = mkRow(visualPage, 38)
        mkLabel(row, cat == "bat" and "Bat Skin" or "Medusa Skin")
        local curKey = (cat == "bat") and batSkin or medusaSkin
        local lbl = mkSelector(row, SkinSys.label(cat, curKey), SkinSys[cat].order, function(dir, update)
            update(SkinSys.step(cat, dir))
            pcall(saveAllSettings)
        end)
        lbl.Size = UDim2.new(0, 96, 0, 30)
        lbl.Position = UDim2.new(0.5, -48, 0.5, -15)
        lbl.TextSize = 10
        lbl.TextWrapped = true
        if cat == "bat" then batSkinLabel = lbl else medusaSkinLabel = lbl end
    end

    local configPage = contentPages["Config"]

    -- ── BACKGROUND IMAGE PICKER ─────────────────────────────────────────────
    mkSect(configPage, "Background Image")
    do

        -- Slideable thumbnail row
        local sliderRow = Instance.new("Frame", configPage)
        sliderRow.Name = "BgSliderRow"
        sliderRow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        sliderRow.BackgroundTransparency = 0.3
        sliderRow.Size = UDim2.new(1, 0, 0, 54)
        sliderRow.BorderSizePixel = 0
        sliderRow.LayoutOrder = 0
        sliderRow.ZIndex = 4
        Instance.new("UICorner", sliderRow).CornerRadius = UDim.new(0, 11)
        local sliderStroke = Instance.new("UIStroke", sliderRow)
        sliderStroke.Color = ROW_BORDER
        sliderStroke.Thickness = 1.25
        sliderStroke.Transparency = 0.45

        local bgScroll = Instance.new("ScrollingFrame", sliderRow)
        bgScroll.Name = "BgScroll"
        bgScroll.Size = UDim2.new(1, -52, 1, 0)
        bgScroll.Position = UDim2.new(0.5, 0, 0, 0)
        bgScroll.AnchorPoint = Vector2.new(0.5, 0)
        bgScroll.BackgroundTransparency = 1
        bgScroll.BorderSizePixel = 0
        bgScroll.ScrollBarThickness = 0
        bgScroll.ScrollBarImageTransparency = 1
        bgScroll.ScrollingDirection = Enum.ScrollingDirection.X
        bgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        bgScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
        bgScroll.ZIndex = 5

        local bgList = Instance.new("UIListLayout", bgScroll)
        bgList.FillDirection = Enum.FillDirection.Horizontal
        bgList.Padding = UDim.new(0, 4)
        bgList.SortOrder = Enum.SortOrder.LayoutOrder
        bgList.VerticalAlignment = Enum.VerticalAlignment.Center
        local bgPad = Instance.new("UIPadding", bgScroll)
        bgPad.PaddingLeft = UDim.new(0, 4)
        bgPad.PaddingRight = UDim.new(0, 4)

        local bgLeft = Instance.new("TextButton", sliderRow)
        bgLeft.Name = "BgArrowLeft"
        bgLeft.Text = "<"
        bgLeft.Size = UDim2.new(0, 22, 0, 34)
        bgLeft.Position = UDim2.new(0, 3, 0.5, -17)
        bgLeft.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
        bgLeft.BackgroundTransparency = 0.05
        bgLeft.BorderSizePixel = 0
        bgLeft.TextColor3 = WHITE
        bgLeft.TextSize = 18
        bgLeft.Font = Enum.Font.GothamBlack
        bgLeft.AutoButtonColor = false
        bgLeft.ZIndex = 8
        Instance.new("UICorner", bgLeft).CornerRadius = UDim.new(0, 7)

        local bgRight = Instance.new("TextButton", sliderRow)
        bgRight.Name = "BgArrowRight"
        bgRight.Text = ">"
        bgRight.Size = UDim2.new(0, 22, 0, 34)
        bgRight.Position = UDim2.new(1, -25, 0.5, -17)
        bgRight.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
        bgRight.BackgroundTransparency = 0.05
        bgRight.BorderSizePixel = 0
        bgRight.TextColor3 = WHITE
        bgRight.TextSize = 18
        bgRight.Font = Enum.Font.GothamBlack
        bgRight.AutoButtonColor = false
        bgRight.ZIndex = 8
        Instance.new("UICorner", bgRight).CornerRadius = UDim.new(0, 7)

        bgLeft.MouseButton1Click:Connect(function()
            local pos = bgScroll.CanvasPosition
            TS:Create(bgScroll, TweenInfo.new(0.2), {CanvasPosition = Vector2.new(math.max(0, pos.X - 52), 0)}):Play()
        end)
        bgRight.MouseButton1Click:Connect(function()
            local pos = bgScroll.CanvasPosition
            TS:Create(bgScroll, TweenInfo.new(0.2), {CanvasPosition = Vector2.new(pos.X + 52, 0)}):Play()
        end)

        local bgThumbBtns = {}

        local function refreshBgHighlight()
            for idx, btn in pairs(bgThumbBtns) do
                local sel = idx == backgroundIndex
                local st = btn:FindFirstChildOfClass("UIStroke")
                if st then
                    st.Color = sel and WHITE or ROW_BORDER
                    st.Transparency = sel and 0 or 0.4
                    st.Thickness = sel and 1.5 or 1
                end
                if btn:IsA("ImageButton") then
                    btn.ImageTransparency = sel and 0 or 0.25
                end
            end
        end

        -- NONE button (index 0)
        local noneBtn = Instance.new("TextButton", bgScroll)
        noneBtn.Name = "BgNone"
        noneBtn.LayoutOrder = 1
        noneBtn.Size = UDim2.new(0, 44, 0, 36)
        noneBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        noneBtn.BorderSizePixel = 0
        noneBtn.Text = "NONE"
        noneBtn.TextColor3 = WHITE
        noneBtn.TextSize = 9
        noneBtn.Font = Enum.Font.GothamBlack
        noneBtn.AutoButtonColor = false
        noneBtn.ZIndex = 6
        Instance.new("UICorner", noneBtn).CornerRadius = UDim.new(0, 9)
        local noneStroke = Instance.new("UIStroke", noneBtn)
        noneStroke.Color = backgroundIndex == 0 and WHITE or ROW_BORDER
        noneStroke.Transparency = backgroundIndex == 0 and 0 or 0.4
        noneStroke.Thickness = backgroundIndex == 0 and 1.5 or 1
        bgThumbBtns[0] = noneBtn
        noneBtn.MouseButton1Click:Connect(function()
            applyBackground(0)
            refreshBgHighlight()
        end)

        local rebuildBgThumbs

        local function makeBgThumb(idx)
            local id = backgroundImages[idx]
            if not id then return end
            local thumb = Instance.new("ImageButton", bgScroll)
            thumb.Name = "BgThumb" .. idx
            thumb.LayoutOrder = idx + 1
            thumb.Size = UDim2.new(0, 44, 0, 36)
            thumb.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            thumb.BorderSizePixel = 0
            thumb.Image = "rbxassetid://" .. id
            thumb.ImageTransparency = idx == backgroundIndex and 0 or 0.25
            thumb.ScaleType = Enum.ScaleType.Crop
            thumb.AutoButtonColor = false
            thumb.ZIndex = 6
            Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 9)
            local st = Instance.new("UIStroke", thumb)
            st.Color = idx == backgroundIndex and WHITE or ROW_BORDER
            st.Transparency = idx == backgroundIndex and 0 or 0.4
            st.Thickness = idx == backgroundIndex and 1.5 or 1

            -- Index is always looked up from the live list by ID, never from a captured idx,
            -- so deleting one thumb can't shift the others onto the wrong image.
            local function currentIndex()
                return table.find(backgroundImages, id)
            end

            local pressToken = 0
            local longPressFired = false

            thumb.InputBegan:Connect(function(inp)
                if inp.UserInputType ~= Enum.UserInputType.MouseButton1
                    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
                pressToken = pressToken + 1
                local myToken = pressToken
                longPressFired = false
                local startPos = inp.Position
                local startCanvasX = bgScroll.CanvasPosition.X
                task.delay(0.6, function()
                    if myToken ~= pressToken then return end
                    if inp.UserInputState == Enum.UserInputState.End then return end
                    -- finger slid or the row scrolled = swipe, not a long press
                    if (inp.Position - startPos).Magnitude > 8 then return end
                    if math.abs(bgScroll.CanvasPosition.X - startCanvasX) > 4 then return end
                    local cur = currentIndex()
                    if not cur then return end
                    longPressFired = true
                    table.remove(backgroundImages, cur)
                    if backgroundIndex >= cur then
                        backgroundIndex = math.max(0, backgroundIndex - 1)
                    end
                    applyBackground(backgroundIndex)
                    rebuildBgThumbs()
                end)
            end)

            thumb.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    pressToken = pressToken + 1
                end
            end)

            -- MouseButton1Click only fires when press+release are on the SAME button,
            -- so a slight finger slide never selects the adjacent image.
            thumb.MouseButton1Click:Connect(function()
                if longPressFired then longPressFired = false; return end
                local cur = currentIndex()
                if cur then
                    applyBackground(cur)
                    refreshBgHighlight()
                end
            end)

            bgThumbBtns[idx] = thumb
        end

        rebuildBgThumbs = function()
            for i, btn in pairs(bgThumbBtns) do
                if i > 0 and btn then
                    btn:Destroy()
                    bgThumbBtns[i] = nil
                end
            end
            for i = 1, #backgroundImages do makeBgThumb(i) end
            refreshBgHighlight()
        end

        -- Build existing thumbnails
        for i = 1, #backgroundImages do makeBgThumb(i) end

        refreshBgHighlight()
    end

    -- ── COLOR THEME SWATCHES ────────────────────────────────────────────────
    mkSect(configPage, "UI Settings")
    do
        local row = mkRow(configPage, 38)
        mkLabel(row, "UI Scale")
        uiScaleBox = mkBox(row, uiScaleValue, 50, 56, function(v)
            local n = _clamp(_floor(v+0.5), 50, 150)
            uiScaleValue = n
            if mainUIScale then mainUIScale.Scale = n/100 end
            saveAllSettings()
        end)
    end

    do
        local row = mkRow(configPage, 38)
        mkLabel(row, "Float Scale")
        mkBox(row, _floor(floatingButtonScale * 100), 50, 56, function(v)
            local val = _clamp(v, 50, 200)
            floatingButtonScale = val / 100
            applyFloatingButtonScale()
            saveAllSettings()
        end)
    end

    mkSect(configPage, "Config Management")
    do
        local row = mkRow(configPage, 44)
        row.Size = UDim2.new(1, 0, 0, 44)
        local saveBtn = Instance.new("TextButton", row)
        saveBtn.Size = UDim2.new(1, -12, 0.8, 0)
        saveBtn.Position = UDim2.new(0, 6, 0.1, 0)
        saveBtn.BackgroundColor3 = Color3.fromRGB(30,30,35)
        saveBtn.BackgroundTransparency = 0.5
        saveBtn.BorderSizePixel = 0
        saveBtn.Text = "SAVE CONFIG"
        saveBtn.TextColor3 = WHITE
        saveBtn.Font = Enum.Font.GothamBlack
        saveBtn.TextSize = 13
        saveBtn.TextStrokeColor3 = Color3.fromRGB(60,60,60)
        saveBtn.TextStrokeTransparency = 0
        saveBtn.AutoButtonColor = false
        saveBtn.ZIndex = 8
        Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 8)
        local saveStroke = Instance.new("UIStroke", saveBtn)
        saveStroke.Color = ROW_BORDER
        saveStroke.Thickness = 1.2
        saveStroke.Transparency = 0.5
        saveBtn.MouseButton1Click:Connect(function()
            local ok = saveAllSettings()
            saveBtn.Text = ok and "SAVED ✓" or "ERROR"
            task.delay(1.2, function()
                if saveBtn and saveBtn.Parent then saveBtn.Text = "SAVE CONFIG" end
            end)
        end)
    end

    do
        local row = mkRow(configPage, 44)
        row.Size = UDim2.new(1, 0, 0, 44)
        local resetPosBtn = Instance.new("TextButton", row)
        resetPosBtn.Size = UDim2.new(1, -12, 0.8, 0)
        resetPosBtn.Position = UDim2.new(0, 6, 0.1, 0)
        resetPosBtn.BackgroundColor3 = Color3.fromRGB(30,30,35)
        resetPosBtn.BackgroundTransparency = 0.5
        resetPosBtn.BorderSizePixel = 0
        resetPosBtn.Text = "RESET POSITIONS"
        resetPosBtn.TextColor3 = WHITE
        resetPosBtn.Font = Enum.Font.GothamBlack
        resetPosBtn.TextSize = 13
        resetPosBtn.TextStrokeColor3 = Color3.fromRGB(60,60,60)
        resetPosBtn.TextStrokeTransparency = 0
        resetPosBtn.AutoButtonColor = false
        resetPosBtn.ZIndex = 8
        Instance.new("UICorner", resetPosBtn).CornerRadius = UDim.new(0, 8)
        local resetStroke = Instance.new("UIStroke", resetPosBtn)
        resetStroke.Color = ROW_BORDER
        resetStroke.Thickness = 1.2
        resetStroke.Transparency = 0.5
        local resetDebounce = false
        resetPosBtn.MouseButton1Click:Connect(function()
            if resetDebounce then return end
            resetDebounce = true
            resetFloatingPositions()
            saveAllSettings()
            resetPosBtn.Text = "RESET ✓"
            task.delay(1.2, function()
                if resetPosBtn and resetPosBtn.Parent then
                    resetPosBtn.Text = "RESET POSITIONS"
                    resetDebounce = false
                end
            end)
        end)
    end

    do
        local row = mkRow(configPage, 44)
        row.Size = UDim2.new(1, 0, 0, 44)
        local delBtn = Instance.new("TextButton", row)
        delBtn.Size = UDim2.new(1, -12, 0.8, 0)
        delBtn.Position = UDim2.new(0, 6, 0.1, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(140, 25, 65)
        delBtn.BackgroundTransparency = 0.5
        delBtn.BorderSizePixel = 0
        delBtn.Text = "DELETE SETTINGS"
        delBtn.TextColor3 = WHITE
        delBtn.Font = Enum.Font.GothamBlack
        delBtn.TextSize = 13
        delBtn.TextStrokeColor3 = Color3.fromRGB(60,60,60)
        delBtn.TextStrokeTransparency = 0
        delBtn.AutoButtonColor = false
        delBtn.ZIndex = 8
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 8)
        local delStroke = Instance.new("UIStroke", delBtn)
        delStroke.Color = ROW_BORDER
        delStroke.Thickness = 1.2
        delStroke.Transparency = 0.5
        local deleteState = 0
        local originalDeleteText = "DELETE SETTINGS"
        local delDebounce = false
        delBtn.MouseButton1Click:Connect(function()
            if delDebounce then return end
            if deleteState == 0 then
                deleteState = 1
                delBtn.Text = "CONFIRM?"
                delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 80)
                task.delay(2, function()
                    if delBtn and delBtn.Parent and deleteState == 1 then
                        deleteState = 0
                        delBtn.Text = originalDeleteText
                        delBtn.BackgroundColor3 = Color3.fromRGB(140, 25, 65)
                    end
                end)
            elseif deleteState == 1 then
                delDebounce = true
                local success = pcall(resetToFactoryDefaults)
                delBtn.Text = success and "DELETED ✓" or "ERROR"
                delBtn.BackgroundColor3 = Color3.fromRGB(140, 25, 65)
                deleteState = 0
                task.delay(1.5, function()
                    if delBtn and delBtn.Parent then
                        delBtn.Text = originalDeleteText
                        delBtn.BackgroundColor3 = Color3.fromRGB(140, 25, 65)
                        delDebounce = false
                    end
                end)
            end
        end)
    end

    local keyPage = contentPages["Keybinds"]
    mkSect(keyPage, "Keybinds")
    addKeybindRow(keyPage, "Carry Mode", KB.CarryToggle)
    addKeybindRow(keyPage, "Lagger Mode", KB.LaggerMode)
    addKeybindRow(keyPage, "Auto Left", KB.AutoLeft)
    addKeybindRow(keyPage, "Auto Right", KB.AutoRight)
    addKeybindRow(keyPage, "Auto Bat", KB.AutoBat)
    addKeybindRow(keyPage, "TP BAT", KB.TPBat)
    addKeybindRow(keyPage, "Bat V2", KB.BatV2)
    addKeybindRow(keyPage, "Insta Reset", KB.InstaReset)
    addKeybindRow(keyPage, "TP Down", KB.TPFloor)
    addKeybindRow(keyPage, "Drop Brainrot", KB.DropBrainrot)
    addKeybindRow(keyPage, "Hide GUI", KB.GuiHide)

    local spacer = Instance.new("Frame", keyPage)
    spacer.Size = UDim2.new(1, 0, 0, 16)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = getNextOrder(keyPage)
    spacer.ZIndex = 7

    pbFrame = Instance.new("Frame", gui)
    pbFrame.Size = UDim2.new(0, pbBarWidth, 0, pbBarHeight)
    pbFrame.Position = UDim2.new(0.5, -math.floor(pbBarWidth/2), 1, -66)
    pbFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    pbFrame.BackgroundTransparency = 0
    pbFrame.BorderSizePixel = 0
    pbFrame.Active = true
    pbFrame.ClipsDescendants = true
    pbFrame.Visible = true
    pbFrame.ZIndex = 10

    pbScale = Instance.new("UIScale", pbFrame)
    pbScale.Scale = pbBarScaleValue / 100

    if savedProgressBarPos then
        pbFrame.Position = UDim2.new(
            savedProgressBarPos.XScale or 0.5,
            savedProgressBarPos.XOffset or -200,
            savedProgressBarPos.YScale or 1,
            savedProgressBarPos.YOffset or -82
        )
    end

    local corner = Instance.new("UICorner", pbFrame)
    corner.CornerRadius = UDim.new(0, 16)

    local border = Instance.new("UIStroke", pbFrame)
    border.Color = getThemeColor()
    border.Thickness = 1.5
    border.Transparency = 0.3
    border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local topRow = Instance.new("Frame", pbFrame)
    topRow.Size = UDim2.new(1, -16, 0, 40)
    topRow.Position = UDim2.new(0, 8, 0, 4)
    topRow.BackgroundTransparency = 1
    topRow.ZIndex = 12

    local avatarCircle = Instance.new("ImageLabel", topRow)
    avatarCircle.Name = "AvatarCircle"
    avatarCircle.Size = UDim2.new(0, 40, 0, 40)
    avatarCircle.Position = UDim2.new(0, 0, 0, 2)
    avatarCircle.BackgroundColor3 = Color3.fromRGB(20,20,25)
    avatarCircle.BorderSizePixel = 0
    avatarCircle.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LP.UserId) .. "&w=150&h=150"
    avatarCircle.ScaleType = Enum.ScaleType.Crop
    avatarCircle.ZIndex = 13
    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end)
        if ok and url and url ~= "" and avatarCircle and avatarCircle.Parent then
            avatarCircle.Image = url
        end
    end)
    local avatarCorner = Instance.new("UICorner", avatarCircle)
    avatarCorner.CornerRadius = UDim.new(1, 0)
    local avatarStroke = Instance.new("UIStroke", avatarCircle)
    avatarStroke.Color = getThemeColor()
    avatarStrokeRef = avatarStroke
    avatarStroke.Thickness = 1.5
    avatarStroke.Transparency = 0.15
    avatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local usernameLabel = Instance.new("TextLabel", topRow)
    usernameLabel.Name = "UsernameLabel"
    usernameLabel.Size = UDim2.new(0.5, -105, 0, 18)
    usernameLabel.Position = UDim2.new(0, 48, 0, 2)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = LP.DisplayName
    usernameLabel.TextColor3 = Color3.fromRGB(255,255,255)
    usernameLabel.Font = Enum.Font.GothamBlack
    usernameLabel.TextSize = 15
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
    usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    usernameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    usernameLabel.TextStrokeTransparency = 0.2
    usernameLabel.ZIndex = 13
    usernameLabel.TextScaled = true
    local nameSizeLimit = Instance.new("UITextSizeConstraint", usernameLabel)
    nameSizeLimit.MaxTextSize = 15
    nameSizeLimit.MinTextSize = 8

    local fpsNeon = Instance.new("TextLabel", topRow)
    fpsNeon.Name = "FPSNeon"
    fpsNeon.Size = UDim2.new(0.5, -105, 0, 18)
    fpsNeon.Position = UDim2.new(0, 48, 0, 22)
    fpsNeon.BackgroundTransparency = 1
    fpsNeon.Text = "FPS: --"
    fpsNeon.TextColor3 = getThemeColor()
    fpsNeon.Font = Enum.Font.GothamBlack
    fpsNeon.TextSize = 13
    fpsNeon.TextXAlignment = Enum.TextXAlignment.Left
    fpsNeon.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    fpsNeon.TextStrokeTransparency = 0.2
    fpsNeon.ZIndex = 13

    local statusRow = Instance.new("Frame", topRow)
    statusRow.Name = "StatusRow"
    statusRow.AnchorPoint = Vector2.new(0.5, 0.5)
    statusRow.Size = UDim2.new(0, 130, 0, 18)
    statusRow.Position = UDim2.new(0.5, 0, 0.5, 0)
    statusRow.BackgroundTransparency = 1
    statusRow.ZIndex = 13
    local statusList = Instance.new("UIListLayout", statusRow)
    statusList.FillDirection = Enum.FillDirection.Horizontal
    statusList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    statusList.VerticalAlignment = Enum.VerticalAlignment.Center
    statusList.SortOrder = Enum.SortOrder.LayoutOrder
    statusList.Padding = UDim.new(0, 6)

    local statusLabel = Instance.new("TextLabel", statusRow)
    statusLabel.Name = "StatusLabel"
    statusLabel.LayoutOrder = 1
    statusLabel.AutomaticSize = Enum.AutomaticSize.X
    statusLabel.Size = UDim2.new(0, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "IDLE"
    statusLabel.TextColor3 = Color3.fromRGB(150,150,160)
    statusLabel.Font = Enum.Font.GothamBlack
    statusLabel.TextSize = 13
    statusLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    statusLabel.TextStrokeTransparency = 0.2
    statusLabel.ZIndex = 13

    local statusSep = Instance.new("Frame", statusRow)
    statusSep.Name = "StatusSep"
    statusSep.LayoutOrder = 2
    statusSep.Size = UDim2.new(0, 2, 0, 12)
    statusSep.BackgroundColor3 = Color3.fromRGB(120,120,130)
    statusSep.BorderSizePixel = 0
    statusSep.ZIndex = 13

    progressPct = Instance.new("TextLabel", statusRow)
    progressPct.Name = "ProgressPct"
    progressPct.LayoutOrder = 3
    progressPct.AutomaticSize = Enum.AutomaticSize.X
    progressPct.Size = UDim2.new(0, 0, 1, 0)
    progressPct.BackgroundTransparency = 1
    progressPct.Text = "0%"
    progressPct.TextColor3 = Color3.fromRGB(255,255,255)
    progressPct.Font = Enum.Font.GothamBlack
    progressPct.TextSize = 13
    progressPct.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    progressPct.TextStrokeTransparency = 0.2
    progressPct.ZIndex = 13

    local pingLabel = Instance.new("TextLabel", topRow)
    pingLabel.Name = "PingLabel"
    pingLabel.AnchorPoint = Vector2.new(1, 0.5)
    pingLabel.Size = UDim2.new(0, 110, 0, 18)
    pingLabel.Position = UDim2.new(1, 0, 0.5, 0)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Text = "PING: --ms"
    pingLabel.TextColor3 = getThemeColor()
    pingLabel.Font = Enum.Font.GothamBlack
    pingLabel.TextSize = 13
    pingLabel.TextXAlignment = Enum.TextXAlignment.Right
    pingLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    pingLabel.TextStrokeTransparency = 0.2
    pingLabel.ZIndex = 13

    -- Status text follows isStealing every frame — no separate hook needed
    -- into the steal engine, this just polls the existing state var.
    task.spawn(function()
        local lastSteal = nil
        while statusLabel and statusLabel.Parent do
            if isStealing then
                statusLabel.Text = "STEAL"
                statusLabel.TextColor3 = getThemeColor()
            elseif lastSteal ~= false then
                statusLabel.Text = "IDLE"
                statusLabel.TextColor3 = Color3.fromRGB(150,150,160)
            end
            lastSteal = isStealing and true or false
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        local t = 0
        local color = getThemeColor()
        local baseColor = color
        while fpsNeon and fpsNeon.Parent do
            t = t + 0.03
            local hueShift = math.sin(t * 1.5) * 0.08
            local newColor = Color3.new(
                _clamp(baseColor.r + hueShift, 0, 1),
                _clamp(baseColor.g + hueShift * 0.6, 0, 1),
                _clamp(baseColor.b - hueShift * 0.3, 0, 1)
            )
            fpsNeon.TextColor3 = newColor
            if pingLabel and pingLabel.Parent then pingLabel.TextColor3 = newColor end
            local bright = 0.8 + 0.2 * math.sin(t * 2.5)
            fpsNeon.TextStrokeTransparency = 0.1 + (1 - bright) * 0.3
            task.wait(0.05)
        end
    end)

    local progressRow = Instance.new("Frame", pbFrame)
    progressRow.Size = UDim2.new(1, -16, 0, 20)
    progressRow.Position = UDim2.new(0, 8, 0, 50)
    progressRow.BackgroundTransparency = 1
    progressRow.ZIndex = 11

    local fillRegion = Instance.new("Frame", progressRow)
    fillRegion.Size = UDim2.new(1, 0, 1, 0)
    fillRegion.BackgroundColor3 = Color3.fromRGB(22,22,28)
    fillRegion.BackgroundTransparency = 0
    fillRegion.BorderSizePixel = 0
    fillRegion.ClipsDescendants = true
    fillRegion.ZIndex = 12
    local fillCorner = Instance.new("UICorner", fillRegion)
    fillCorner.CornerRadius = UDim.new(1, 0)

    progressFill = Instance.new("Frame", fillRegion)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.Position = UDim2.new(0, 0, 0, 0)
    progressFill.BackgroundColor3 = getThemeColor()
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 13
    local fillCorner2 = Instance.new("UICorner", progressFill)
    fillCorner2.CornerRadius = UDim.new(1, 0)

    local fillGrad = Instance.new("UIGradient", progressFill)
    local color2 = getThemeColor()
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, color2),
        ColorSequenceKeypoint.new(0.50, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1.00, color2),
    })
    fillGrad.Rotation = 0

    local glowEnd = Instance.new("Frame", progressFill)
    glowEnd.Size = UDim2.new(0, 20, 1, 0)
    glowEnd.Position = UDim2.new(1, -20, 0, 0)
    glowEnd.BackgroundColor3 = Color3.fromRGB(255,255,255)
    glowEnd.BackgroundTransparency = 0.7
    glowEnd.BorderSizePixel = 0
    glowEnd.ZIndex = 14
    local glowCorner2 = Instance.new("UICorner", glowEnd)
    glowCorner2.CornerRadius = UDim.new(1, 0)
    local glowGrad2 = Instance.new("UIGradient", glowEnd)
    glowGrad2.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,255,255)),
    })
    glowGrad2.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})

    do
        local dn, ds, sp, di = false, nil, nil, nil
        local endConn = nil
        local function stopDragPB()
            dn = false; di = nil
            if endConn then endConn:Disconnect(); endConn = nil end
            if pbFrame then
                savedProgressBarPos = {
                    XScale = pbFrame.Position.X.Scale,
                    XOffset = pbFrame.Position.X.Offset,
                    YScale = pbFrame.Position.Y.Scale,
                    YOffset = pbFrame.Position.Y.Offset,
                }
                saveAllSettings()
            end
        end
        pbFrame.InputBegan:Connect(function(i)
            if uiLocked then return end
            if _isDraggingButton then return end
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dn = true; ds = i.Position; sp = pbFrame.Position
                if endConn then endConn:Disconnect() end
                endConn = i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then stopDragPB() end
                end)
            end
        end)
        pbFrame.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                stopDragPB()
            end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                stopDragPB()
            end
        end)
        pbFrame.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then di = i end
        end)
        UIS.InputChanged:Connect(function(i)
            if i == di and dn then
                if uiLocked then stopDragPB(); return end
                if _isDraggingButton then return end
                if not ds or not sp then return end
                local nX = sp.X.Offset + (i.Position.X - ds.X)
                local nY = sp.Y.Offset + (i.Position.Y - ds.Y)
                pbFrame.Position = UDim2.new(sp.X.Scale, nX, sp.Y.Scale, nY)
            end
        end)
    end

    task.spawn(function()
        local lastFrame = _tick()
        local fpsAvg = 60
        RunService.RenderStepped:Connect(function()
            local now = _tick()
            local dt = now - lastFrame
            lastFrame = now
            if dt > 0 and dt < 1 then
                fpsAvg = fpsAvg * 0.92 + (1 / dt) * 0.08
            end
        end)
        while true do
            local ping = 0
            pcall(function() ping = LP:GetNetworkPing() * 1000 end)
            if fpsNeon then
                fpsNeon.Text = string.format("FPS: %d", _floor(fpsAvg + 0.5))
                if pingLabel then
                    pingLabel.Text = string.format("PING: %dms", _floor(ping + 0.5))
                end
            end
            task.wait(0.75)
        end
    end)

    drag(main)
end

function createMobilePanel()
    local panel = Instance.new("ScreenGui")
    panel.Name = "MeridianHubMobilePanel"
    panel.ResetOnSpawn = false
    panel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(panel) end end)
    local okPanel = pcall(function() panel.Parent = game:GetService("CoreGui") end)
    if not okPanel then panel.Parent = LP:WaitForChild("PlayerGui") end

    local BTN_W, BTN_H = 60, 60

    -- Default screen positions for each button (absolute offset from top-right).
    -- Buttons are now fully independent floating elements parented directly to
    -- the ScreenGui, so dragging one never moves the others.
    local DEFAULT_POSITIONS = {
        DropBR    = { XScale=1, XOffset=-140, YScale=0, YOffset=10  },
        AutoLeft  = { XScale=1, XOffset=-74,  YScale=0, YOffset=10  },
        AutoBat   = { XScale=1, XOffset=-140, YScale=0, YOffset=78  },
        AutoRight = { XScale=1, XOffset=-74,  YScale=0, YOffset=78  },
        TpDown    = { XScale=1, XOffset=-140, YScale=0, YOffset=146 },
        Carry     = { XScale=1, XOffset=-74,  YScale=0, YOffset=146 },
        Lagger1   = { XScale=1, XOffset=-140, YScale=0, YOffset=214 },
        Lagger2   = { XScale=1, XOffset=-74,  YScale=0, YOffset=214 },
    }

    local WHITE = Color3.fromRGB(255, 255, 255)
    local INACTIVE_BG = Color3.fromRGB(10,10,10)

    local buttons = {}
    local buttonNames = {"DropBR", "AutoLeft", "AutoBat", "AutoRight", "TpDown", "Carry", "Lagger1", "Lagger2"}
    local buttonTexts = {"DROP\nBR", "AUTO\nLEFT", "BAT\nAIMBOT", "AUTO\nRIGHT", "TP\nDOWN", "CARRY\nSPD", "LAGGER", "LAGGER\nCARRY"}

    local function createButton(name, text, order, isToggle, callback)
        local btn = Instance.new("TextButton", panel)
        btn.Name = name
        btn.Size = UDim2.new(0, BTN_W, 0, BTN_H)
        btn.BackgroundColor3 = INACTIVE_BG
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 10

        local savedPos = savedButtonPositions[name]
        if savedPos and savedPos.XScale ~= nil then
            -- New format: full UDim2 data
            btn.Position = UDim2.new(savedPos.XScale or 1, savedPos.XOffset or 0,
                                     savedPos.YScale or 0, savedPos.YOffset or 0)
        elseif savedPos then
            -- Legacy format: plain X/Y offsets relative to old container
            local def = DEFAULT_POSITIONS[name] or { XScale=1, XOffset=-140, YScale=0, YOffset=10 }
            btn.Position = UDim2.new(def.XScale, def.XOffset, def.YScale, def.YOffset)
        else
            local def = DEFAULT_POSITIONS[name] or { XScale=1, XOffset=-140, YScale=0, YOffset=10 }
            btn.Position = UDim2.new(def.XScale, def.XOffset, def.YScale, def.YOffset)
        end

        btn.BackgroundColor3 = Color3.fromRGB(255,255,255)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 18)

        local bgGrad = Instance.new("UIGradient", btn)
        bgGrad.Name = "BtnGrad"
        bgGrad.Rotation = 90
        bgGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(252,252,253)),
            ColorSequenceKeypoint.new(0.45, Color3.fromRGB(233,233,236)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(168,168,176)),
        })

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(120,120,128)
        stroke.Thickness = 1
        stroke.Transparency = 0.55
        stroke.Name = "NormalStroke"

        local label = Instance.new("TextLabel", btn)
        label.Name = "TextLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(32,32,40)
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 11
        label.TextWrapped = true
        label.ZIndex = 11

        local btnUIScale = Instance.new("UIScale", btn)
        btnUIScale.Scale = floatingButtonScale
        table.insert(_floatingUIScales, btnUIScale)

        local active = false
        local function setActive(state)
            active = state
            btn:SetAttribute("MobActive", state and true or false)
            paintFloatingBtn(btn, state)
        end
        setActive(false)

        local dragging = false
        local hasMoved = false
        local dragStart = nil
        local startPos = nil
        local movedDistance = 0

        local function onInputBegan(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                hasMoved = false
                movedDistance = 0
                dragStart = input.Position
                startPos = btn.Position
                _isDraggingButton = true
            end
        end

        local function onInputChanged(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                movedDistance = delta.Magnitude
                if not uiLocked then
                    hasMoved = true
                    btn.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end
        end

        local function onInputEnded(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    if movedDistance < 3 then
                        if isToggle then
                            if not uiLocked then
                                if callback then callback(function() end) end
                            else
                                if callback then callback(setActive) end
                            end
                        else
                            if callback then callback(setActive, active) end
                        end
                    elseif not uiLocked and hasMoved then
                        savedButtonPositions[name] = {
                            XScale  = btn.Position.X.Scale,
                            XOffset = btn.Position.X.Offset,
                            YScale  = btn.Position.Y.Scale,
                            YOffset = btn.Position.Y.Offset,
                        }
                    end
                    dragging = false
                    hasMoved = false
                    dragStart = nil
                    startPos = nil
                    movedDistance = 0
                    _isDraggingButton = false
                end
            end
        end

        btn.InputBegan:Connect(onInputBegan)
        btn.InputChanged:Connect(onInputChanged)
        btn.InputEnded:Connect(onInputEnded)

        buttons[name] = {btn = btn, setActive = setActive, label = label}
        return setActive
    end

    for i, name in ipairs(buttonNames) do
        local text = buttonTexts[i]
        local callback
        if name == "DropBR" then
            callback = function(setActive)
                if autoBatEnabled then return end
                setActive(true)
                executeDropWithToggle(function(v)
                    if dropBrainrotSetVisual then dropBrainrotSetVisual(v) end
                end)
                task.delay(0.3, function() setActive(false) end)
            end
        elseif name == "AutoLeft" then
            callback = function(setActive)
                autoLeftEnabled = not autoLeftEnabled
                if autoLeftEnabled then stopAllExclusiveModes(); autoLeftEnabled = true end
                setActive(autoLeftEnabled)
                if autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
                if autoLeftSetVisual then autoLeftSetVisual(autoLeftEnabled) end
            end
        elseif name == "AutoBat" then
            callback = function(setActive)
                if not isAimbotEnabled() then
                    stopAllExclusiveModes()
                    if batAimbotVariant == "bypass" then enableBatV3()
                    elseif batAimbotVariant == "v2" then enableBatV2()
                    else enableAutoBat() end
                else
                    if batAimbotVariant == "bypass" then disableBatV3()
                    elseif batAimbotVariant == "v2" then disableBatV2()
                    else disableAutoBat() end
                end
                local active = isAimbotEnabled()
                setActive(active)
                if autoBatSetVisual then autoBatSetVisual(active) end
            end
        elseif name == "AutoRight" then
            callback = function(setActive)
                autoRightEnabled = not autoRightEnabled
                if autoRightEnabled then stopAllExclusiveModes(); autoRightEnabled = true end
                setActive(autoRightEnabled)
                if autoRightEnabled then startAutoRight() else stopAutoRight() end
                if autoRightSetVisual then autoRightSetVisual(autoRightEnabled) end
            end
        elseif name == "TpDown" then
            callback = function(setActive)
                doTpDown()
                setActive(true)
                task.delay(0.2, function() setActive(false) end)
            end
        elseif name == "Carry" then
            callback = function(setActive)
                if not speedMode then
                    speedMode = true; laggerToggled = false; laggerCarryToggled = false; setActive(true)
                    if buttons.Lagger1 and buttons.Lagger1.setActive then buttons.Lagger1.setActive(false) end
                    if buttons.Lagger2 and buttons.Lagger2.setActive then buttons.Lagger2.setActive(false) end
                else
                    speedMode = false; setActive(false)
                end
                refreshSpeedModeLabel()
            end
        elseif name == "Lagger1" then
            callback = function(setActive)
                if speedMode then speedMode = false; if mobSetCarry then mobSetCarry(false) end end
                if not laggerToggled then
                    laggerToggled = true; laggerCarryToggled = false; setActive(true)
                    if buttons.Lagger2 and buttons.Lagger2.setActive then buttons.Lagger2.setActive(false) end
                else
                    laggerToggled = false; setActive(false)
                end
                refreshSpeedModeLabel()
            end
        elseif name == "Lagger2" then
            callback = function(setActive)
                if speedMode then speedMode = false; if mobSetCarry then mobSetCarry(false) end end
                if not laggerCarryToggled then
                    laggerCarryToggled = true; laggerToggled = false; setActive(true)
                    if buttons.Lagger1 and buttons.Lagger1.setActive then buttons.Lagger1.setActive(false) end
                else
                    laggerCarryToggled = false; setActive(false)
                end
                refreshSpeedModeLabel()
            end
        end
        mobSetAutoBat = buttons.AutoBat and buttons.AutoBat.setActive
        mobSetAutoLeft = buttons.AutoLeft and buttons.AutoLeft.setActive
        mobSetAutoRight = buttons.AutoRight and buttons.AutoRight.setActive
        mobSetDropBR = buttons.DropBR and buttons.DropBR.setActive
        mobSetTpDown = buttons.TpDown and buttons.TpDown.setActive
        mobSetCarry = buttons.Carry and buttons.Carry.setActive
        mobSetLagger1 = buttons.Lagger1 and buttons.Lagger1.setActive
        mobSetLagger2 = buttons.Lagger2 and buttons.Lagger2.setActive

        local setActive = createButton(name, text, i-1, true, callback)
        if name == "AutoBat" then mobSetAutoBat = setActive end
        if name == "AutoLeft" then mobSetAutoLeft = setActive end
        if name == "AutoRight" then mobSetAutoRight = setActive end
        if name == "DropBR" then mobSetDropBR = setActive end
        if name == "TpDown" then mobSetTpDown = setActive end
        if name == "Carry" then mobSetCarry = setActive end
        if name == "Lagger1" then mobSetLagger1 = setActive end
        if name == "Lagger2" then mobSetLagger2 = setActive end
    end

    if buttons.AutoBat and buttons.AutoBat.setActive then buttons.AutoBat.setActive(autoBatEnabled) end
    if buttons.AutoLeft and buttons.AutoLeft.setActive then buttons.AutoLeft.setActive(autoLeftEnabled) end
    if buttons.AutoRight and buttons.AutoRight.setActive then buttons.AutoRight.setActive(autoRightEnabled) end
    if buttons.Carry and buttons.Carry.setActive then buttons.Carry.setActive(speedMode) end
    if buttons.Lagger1 and buttons.Lagger1.setActive then buttons.Lagger1.setActive(laggerToggled) end
    if buttons.Lagger2 and buttons.Lagger2.setActive then buttons.Lagger2.setActive(laggerCarryToggled) end

    -- Each button is now a fully independent floating element parented
    -- directly to the ScreenGui.  There is no shared container, so
    -- dragging one button never moves the others.

    return panel
end

function createTpBatFloatingButton()
    local panel = Instance.new("ScreenGui")
    panel.Name = "TpBatButton"
    panel.ResetOnSpawn = false
    panel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    panel.DisplayOrder = 21
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(panel) end end)
    local okPanel = pcall(function() panel.Parent = game:GetService("CoreGui") end)
    if not okPanel then panel.Parent = LP:WaitForChild("PlayerGui") end

    local btnFrame = Instance.new("Frame", panel)
    btnFrame.Size = UDim2.new(0, 60, 0, 60)
    btnFrame.Name = "Frame"
    if tpBatFloatingPos then
        btnFrame.Position = UDim2.new(tpBatFloatingPos.XScale or 1,
                                      tpBatFloatingPos.XOffset or -70,
                                      tpBatFloatingPos.YScale or 0,
                                      tpBatFloatingPos.YOffset or 78)
    else
        btnFrame.Position = UDim2.new(1, -70, 0, 78)
    end
    btnFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
    btnFrame.BackgroundTransparency = 0
    btnFrame.BorderSizePixel = 0
    btnFrame.ZIndex = 20
    Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 18)
    local bgGrad = Instance.new("UIGradient", btnFrame)
    bgGrad.Name = "BtnGrad"
    bgGrad.Rotation = 90
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(252,252,253)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(233,233,236)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(168,168,176)),
    })
    local stroke = Instance.new("UIStroke", btnFrame)
    stroke.Color = batDesyncTpEnabled and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(70,70,70)
    stroke.Thickness = batDesyncTpEnabled and 2.5 or 1.2
    stroke.Transparency = 0.3
    stroke.Name = "TpBatStroke"
    local label = Instance.new("TextLabel", btnFrame)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "TP\nBAT"
    label.TextColor3 = Color3.fromRGB(32,32,40)
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 11
    label.TextWrapped = true
    label.ZIndex = 21

    local uiScale = Instance.new("UIScale", btnFrame)
    uiScale.Scale = floatingButtonScale
    table.insert(_floatingUIScales, uiScale)

    local function setActive(state)
        label.Text = "TP\nBAT"
        paintFloatingBtn(btnFrame, state)
    end

    local dragging = false; local hasMoved = false; local dragStart, startPos
    btnFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; hasMoved = false; dragStart = inp.Position; startPos = btnFrame.Position
        end
    end)
    btnFrame.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local delta = inp.Position - dragStart
            if delta.Magnitude > 5 then hasMoved = true end
            if hasMoved and not uiLocked then
                btnFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                              startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
    btnFrame.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                if not hasMoved then
                    if not batDesyncTpEnabled then stopAllExclusiveModes() end
                    toggleBatDesyncTp()
                    setActive(batDesyncTpEnabled)
                elseif not uiLocked and hasMoved then
                    tpBatFloatingPos = {
                        XScale = btnFrame.Position.X.Scale,
                        XOffset = btnFrame.Position.X.Offset,
                        YScale = btnFrame.Position.Y.Scale,
                        YOffset = btnFrame.Position.Y.Offset
                    }
                end
                dragging = false; hasMoved = false
            end
        end
    end)

    tpBatFloatingButton = panel
    return panel
end

-- (removed: createBatV2FloatingButton function definition — this
-- standalone floating button duplicated the main grid's "BAT AIMBOT"
-- button; both called the same toggleAimbot(). All batV2FloatingButton
-- references elsewhere are safely nil-guarded and remain harmless.

function createInstaResetFloatingButton()
    local panel = Instance.new("ScreenGui")
    panel.Name = "InstaResetButton"
    panel.ResetOnSpawn = false
    panel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    panel.DisplayOrder = 23
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(panel) end end)
    local okPanel = pcall(function() panel.Parent = game:GetService("CoreGui") end)
    if not okPanel then panel.Parent = LP:WaitForChild("PlayerGui") end

    local btnFrame = Instance.new("Frame", panel)
    btnFrame.Size = UDim2.new(0, 60, 0, 60)
    btnFrame.Name = "Frame"
    if instaResetFloatingPos then
        btnFrame.Position = UDim2.new(instaResetFloatingPos.XScale or 1,
                                      instaResetFloatingPos.XOffset or -70,
                                      instaResetFloatingPos.YScale or 0,
                                      instaResetFloatingPos.YOffset or 146)
    else
        btnFrame.Position = UDim2.new(1, -70, 0, 146)
    end
    btnFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
    btnFrame.BorderSizePixel  = 0
    btnFrame.ZIndex           = 20
    Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 18)

    local bgGrad = Instance.new("UIGradient", btnFrame)
    bgGrad.Name = "BtnGrad"
    bgGrad.Rotation = 90
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(252,252,253)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(233,233,236)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(168,168,176)),
    })

    local stroke = Instance.new("UIStroke", btnFrame)
    stroke.Color = Color3.fromRGB(120,120,128)
    stroke.Thickness = 1
    stroke.Transparency = 0.55

    local label = Instance.new("TextLabel", btnFrame)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "INSTA\nRESET"
    label.TextColor3 = Color3.fromRGB(32,32,40)
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 11
    label.TextWrapped = true
    label.ZIndex = 21

    local uiScale = Instance.new("UIScale", btnFrame)
    uiScale.Scale = floatingButtonScale
    table.insert(_floatingUIScales, uiScale)

    local dragging, hasMoved, dragStart, startPos, activeInput
    local RESET_TAP_THRESHOLD = 12

    local function pointInside(pos)
        local ap = btnFrame.AbsolutePosition
        local as = btnFrame.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + as.X
           and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
    end

    local function setActive(state)
        if state then
            TS:Create(btnFrame, TweenInfo.new(0.05), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
            TS:Create(label,    TweenInfo.new(0.05), {TextColor3       = Color3.fromRGB(0,0,0)}):Play()
        else
            paintFloatingBtn(btnFrame, false)
        end
    end

    btnFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            if activeInput then return end
            activeInput = inp
            dragging    = true
            hasMoved    = false
            dragStart   = inp.Position
            startPos    = btnFrame.Position
        end
    end)

    UIS.InputChanged:Connect(function(inp)
        if not dragging or not activeInput then return end
        local isTouchMove = activeInput.UserInputType == Enum.UserInputType.Touch and inp == activeInput
        local isMouseMove = activeInput.UserInputType == Enum.UserInputType.MouseButton1
                            and inp.UserInputType == Enum.UserInputType.MouseMovement
        if not isTouchMove and not isMouseMove then return end
        local delta = inp.Position - dragStart
        if delta.Magnitude > RESET_TAP_THRESHOLD then hasMoved = true end
        if hasMoved and not uiLocked then
            btnFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function(inp)
        if inp ~= activeInput then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if dragging then
            local delta = inp.Position - dragStart
            local validTap = not hasMoved
                             and delta.Magnitude <= RESET_TAP_THRESHOLD
                             and pointInside(inp.Position)
            if validTap then
                setActive(true)
                if _G.InstaReset and _G.InstaReset.Trigger then
                    _G.InstaReset.Trigger()
                end
                task.delay(0.2, function() setActive(false) end)
            elseif not uiLocked and hasMoved then
                instaResetFloatingPos = {
                    XScale  = btnFrame.Position.X.Scale,
                    XOffset = btnFrame.Position.X.Offset,
                    YScale  = btnFrame.Position.Y.Scale,
                    YOffset = btnFrame.Position.Y.Offset,
                }
                pcall(saveAllSettings)
            end
            dragging    = false
            hasMoved    = false
            activeInput = nil
        end
    end)

    instaResetFloatingButton = panel
    return panel
end

function updateUIFromLoaded()
    task.wait()
    if normalBox then normalBox.Text = tostring(NS) end
    if carryBox then carryBox.Text = tostring(CS) end
    if radInput then radInput.Text = tostring(CONFIG.STEAL_RANGE) end
    if laggerBox then laggerBox.Text = tostring(LAGGER_SPEED) end
    if lagger2Box then lagger2Box.Text = tostring(LAGGER_CARRY_SPEED) end
    if batSpeedBox then batSpeedBox.Text = tostring(BAT_AIMBOT_SPEED) end
    if laggerBatSpeedBox then laggerBatSpeedBox.Text = tostring(LAGGER_AIMBOT_SPEED) end
    if uiScaleBox then uiScaleBox.Text = tostring(uiScaleValue) end
    if dropModeBtnRef then dropModeBtnRef.Text = dropMode == 1 and "Fling" or "Jump Drop" end
    if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
    refreshSpeedModeLabel()

    for _, ref in ipairs(keyButtonRefs) do
        local entry = ref.entry
        local label = (entry.gp and entry.gp.Name) or (entry.kb and entry.kb.Name) or "None"
        ref.btn.Text = label
    end

    if savedProgressBarPos and pbFrame then
        pbFrame.Position = UDim2.new(
            savedProgressBarPos.XScale or 0.5,
            savedProgressBarPos.XOffset or -200,
            savedProgressBarPos.YScale or 1,
            savedProgressBarPos.YOffset or -82
        )
    end

    local bgImg = main and main:FindFirstChild("BackgroundImage")
    if bgImg then
        bgImg.Image = (backgroundIndex > 0 and backgroundImages[backgroundIndex]) and ("rbxassetid://" .. backgroundImages[backgroundIndex]) or ""
        bgImg.ImageTransparency = backgroundImageTransparency
        bgImg.Visible = backgroundIndex > 0
    end

    applyFloatingButtonScale()

    if uiLocked and setLockUIVisual then setLockUIVisual(true) end
    if editModeEnabled and setEditModeVisual then setEditModeVisual(true) end

    if _G.updateAntiRagdollUI then _G.updateAntiRagdollUI(antiRagdollMode) end
    if antiRagdollMode == "v1" then
        AntiRagdollV1.start()
    elseif antiRagdollMode == "v2" then
        startAntiRagdollV2()
    end

    if antiDieEnabled then
        if setAntiDieVisual then setAntiDieVisual(true) end
        AntiDieModule.start()
    else
        if setAntiDieVisual then setAntiDieVisual(false) end
    end

    if _G.updateAutoGrabVariantUI then _G.updateAutoGrabVariantUI(autoGrabVariant) end
    if _G.updateBatAimbotVariantUI then _G.updateBatAimbotVariantUI(batAimbotVariant) end
    if CONFIG.AUTO_STEAL_ENABLED and setInstaGrab then
        setInstaGrab(true)
        if autoGrabVariant == "v2" then pcall(startAutoStealV2) else pcall(startAutoSteal) end
    end

    if medusaCounterEnabled then
        if setMedusaVisual then setMedusaVisual(true) end
        if LP.Character then setupMedusaCounter(LP.Character) end
    else
        if setMedusaVisual then setMedusaVisual(false) end
        stopMedusaCounter()
    end

    if batCounterEnabled and setBatCounterVisual then
        setBatCounterVisual(true)
        startBatCounter()
    end
    if unwalkEnabled and setUnwalkVisual then
        setUnwalkVisual(true)
        task.spawn(function() task.wait(0.5); startUnwalk() end)
    end
    if antiLagEnabled then
        if setAntiLagVisual then setAntiLagVisual(true) end
        enableAntiLag()
    else
        if setAntiLagVisual then setAntiLagVisual(false) end
        disableAntiLag()
    end
    if espEnabled then
        toggleESP(true)
        if setESPVIsual then setESPVIsual(true) end
    else
        toggleESP(false)
        if setESPVIsual then setESPVIsual(false) end
    end

    if batDesyncTpEnabled then
        if batDesyncTpSetVisual then batDesyncTpSetVisual(true) end
        if not tpBatEnabled then startBatDesyncTp() end
        updateTpBatButtonWithAntiDie(true)
    else
        if batDesyncTpSetVisual then batDesyncTpSetVisual(false) end
        updateTpBatButtonWithAntiDie(false)
    end
    if mirrorTpSetVisual then mirrorTpSetVisual(mirrorTpEnabled) end

    if autoBatV2Enabled then
        if autoBatV2SetVisual then autoBatV2SetVisual(true) end
        if not _batV2Conn then startBatV2Aimbot() end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then
                btnFrame.BackgroundColor3 = getThemeColor()
                local label = btnFrame:FindFirstChild("TextLabel")
                if label then label.TextColor3 = Color3.fromRGB(0,0,0) end
            end
        end
    else
        if autoBatV2SetVisual then autoBatV2SetVisual(false) end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, false) end
        end
    end

    if neonWeatherEnabled then
        applyNeonWeather()
        if setNeonWeatherVisual then setNeonWeatherVisual(true) end
    else
        restoreLightingState()
        if setNeonWeatherVisual then setNeonWeatherVisual(false) end
    end

    if stretchEnabled then
        enableStretch()
        if _G.stretchToggleSetter then _G.stretchToggleSetter(true) end
    else
        if _G.stretchToggleSetter then _G.stretchToggleSetter(false) end
    end

    if setFovVisual then setFovVisual(fovEnabled) end
    if fovSliderSet then fovSliderSet(fovValue) end

    if mobSetAutoBat then mobSetAutoBat(isAimbotEnabled()) end
    if mobSetAutoLeft then mobSetAutoLeft(autoLeftEnabled) end
    if mobSetAutoRight then mobSetAutoRight(autoRightEnabled) end
    if mobSetCarry then mobSetCarry(speedMode) end
    if mobSetLagger1 then mobSetLagger1(laggerToggled) end
    if mobSetLagger2 then mobSetLagger2(laggerCarryToggled) end

    if bodyLockEnabled and bodyLockSetVisual then
        if _blSuppressCount == 0 then
            bodyLockSetVisual(true)
            startBodyLock()
        else
            bodyLockSetVisual(false)
        end
    end

    updateProgressBarVisibility()
    startEnemySpeed()

    toggleLockUI(uiLocked)

    if colorSelectorLabel then
        colorSelectorLabel.Text = currentColorTheme
        colorSelectorLabel.TextColor3 = selectedColor
    end

    pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
    if outfitSelectorLabel then
        outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
    end

    if adaptAutoCarrySelectorUpdate then
        local idx = adaptAutoCarryEnabled and ((_G._AdaptAutoCarryMode == "ON STEAL") and 3 or 2) or 1
        adaptAutoCarrySelectorUpdate(idx)
        if adaptAutoCarryEnabled then
            _G._AdaptAutoCarry = true
            if type(_G._AdaptStartAutoCarry) == "function" then
                pcall(_G._AdaptStartAutoCarry)
            end
        end
    end
end

-- ── Adapt Auto Carry — built-in implementation ───────────────────────────────
-- Adapt Auto Carry — 1:1 port of Adapt Volt fn44 block.
--
-- State mapping (tbl22.family + tbl22.carry  →  Meridian):
--   "normal" carry=false  →  speedMode=false  laggerToggled=false  laggerCarryToggled=false
--   "normal" carry=true   →  speedMode=true   laggerToggled=false  laggerCarryToggled=false
--   "lagger" carry=false  →  speedMode=false  laggerToggled=true   laggerCarryToggled=false
--   "lagger" carry=true   →  speedMode=false  laggerToggled=false  laggerCarryToggled=true
--   tbl31.L / tbl31.R    →  alConn / arConn  (autoLeft / autoRight running)
do
    local _acStealConn    = nil    -- tbl38.stealConn
    local _acCharConn     = nil    -- tbl38.charConn
    local _acNearConn     = nil    -- tbl38.nearConn
    local _acActive       = false  -- tbl38.active
    local _acPrevious     = nil    -- tbl38.previous  { speedMode, laggerToggled, laggerCarryToggled }
    local _acNextNearScan = 0      -- tbl38.nextNearScan

    -- fn45(): sync UI after state change
    local function _acSync()
        resetMovementState()
        if _G._AdaptRefreshMovementModes then pcall(_G._AdaptRefreshMovementModes) end
        if _G._AdaptSyncMobile            then pcall(_G._AdaptSyncMobile)           end
    end

    -- fn46(): deactivate — restore the state that was saved on first activate
    local function _acDeactivate()
        if not _acActive then return end
        local prev  = _acPrevious
        _acActive   = false
        _acPrevious = nil
        if prev then
            speedMode          = prev.speedMode
            laggerToggled      = prev.laggerToggled
            laggerCarryToggled = prev.laggerCarryToggled
        end
        _acSync()
    end

    -- fn50(): disconnect all three connections
    local function _acDisconnect()
        if _acStealConn then _acStealConn:Disconnect(); _acStealConn = nil end
        if _acCharConn  then _acCharConn:Disconnect();  _acCharConn  = nil end
        if _acNearConn  then _acNearConn:Disconnect();  _acNearConn  = nil end
    end

    -- fn47(shouldCarry): core switch — mirrors Adapt's save/restore logic exactly
    local function _acSwitch(shouldCarry)
        -- tbl31.L or tbl31.R: auto-path running — clear active and bail
        if alConn or arConn then
            _acActive   = false
            _acPrevious = nil
            return
        end

        if not _G._AdaptAutoCarry or not shouldCarry then
            _acDeactivate()  -- fn46
            return
        end

        if _acActive then
            -- Already active: if the player manually changed mode family while
            -- auto carry was running, update the restore target (no carry).
            -- Mirrors: if tbl38.previous and tbl22.family ~= tbl38.previous.family
            if _acPrevious then
                local prevWasLagger = _acPrevious.laggerToggled or _acPrevious.laggerCarryToggled
                local nowIsLagger   = laggerToggled or laggerCarryToggled
                if prevWasLagger ~= nowIsLagger then
                    _acPrevious = {
                        speedMode          = false,
                        laggerToggled      = nowIsLagger,
                        laggerCarryToggled = false,
                    }
                end
            end
            -- Ensure carry is on: tbl22.carry = true
            if not speedMode then
                speedMode = true
                _acSync()
            end
            return
        end

        -- First activation: save current state, enter carry
        _acPrevious = {
            speedMode          = speedMode,
            laggerToggled      = laggerToggled,
            laggerCarryToggled = laggerCarryToggled,
        }
        _acActive          = true
        speedMode          = true
        laggerToggled      = false
        laggerCarryToggled = false
        _acSync()
    end

    -- fn48(): ON STEAL handler
    local function _acOnSteal()
        _acSwitch(LP:GetAttribute("Stealing") == true)
    end

    -- fn49(): WHEN NEAR handler — Stealing attr OR within 10 studs of prompt
    local function _acNear()
        local isCarrying = LP:GetAttribute("Stealing") == true
        local isNear     = false
        if not isCarrying then
            local char = LP.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local nearPrompt = findNearestPrompt()
                if nearPrompt and nearPrompt.Parent and nearPrompt.Parent.Parent then
                    isNear = (hrp.Position - nearPrompt.Parent.Parent.Position).Magnitude <= 10
                end
            end
        end
        _acSwitch(isCarrying or isNear)
    end

    _G._AdaptStartAutoCarry = function()
        _acDisconnect()  -- fn50: clear old connections
        _acDeactivate()  -- fn46: restore any saved state before re-init

        -- charConn: reset auto carry state on respawn (fn46 on CharacterAdded)
        _acCharConn = LP.CharacterAdded:Connect(_acDeactivate)

        if _G._AdaptAutoCarryMode == "WHEN NEAR" then
            _acNextNearScan = 0
            _acNearConn = RunService.Heartbeat:Connect(function()
                local now = os.clock()
                if now < _acNextNearScan then return end
                _acNextNearScan = now + 0.08  -- throttle: same as Adapt
                _acNear()
            end)
            _acNear()       -- immediate sync on start

        else  -- "ON STEAL"
            _acStealConn = LP:GetAttributeChangedSignal("Stealing"):Connect(_acOnSteal)
            _acOnSteal()    -- immediate sync on start
        end
    end

    _G._AdaptStopAutoCarry = function()
        _acDisconnect()  -- fn50
        _acDeactivate()  -- fn46
    end

    -- Lets getAimbotSpeed() see the real lagger mode while Auto Carry has it overridden
    _G._AdaptAutoCarryWasLagger = function()
        return _acActive and _acPrevious ~= nil
            and (_acPrevious.laggerToggled or _acPrevious.laggerCarryToggled) or false
    end

    -- Called by Adapt internals to re-check current state without restarting
    _G._AdaptSyncAutoCarry = function()
        if not _G._AdaptAutoCarry then return end
        if _G._AdaptAutoCarryMode == "WHEN NEAR" then
            _acNear()
        else
            _acOnSteal()
        end
    end

    -- Called when the steal/carry family switches mid-session (e.g. normal↔lagger)
    _G._AdaptAutoCarrySelectFamily = function(family, arg)
        if family ~= "normal" and family ~= "lagger" then return false end
        if not _acActive then return false end

        -- Update the restore-target with the new family preference
        if family == "normal" then
            _acPrevious = { speedMode = (arg == true), laggerToggled = false,          laggerCarryToggled = false            }
            speedMode = true; laggerToggled = false; laggerCarryToggled = false
        else  -- "lagger"
            _acPrevious = { speedMode = false,          laggerToggled = (arg ~= true), laggerCarryToggled = (arg == true)   }
            speedMode = false; laggerToggled = false; laggerCarryToggled = true
        end

        _acSync()
        return true
    end
end
-- ── end Adapt Auto Carry ──────────────────────────────────────────────────────

buildGui()

if loadAllSettings() then
    updateUIFromLoaded()
end

MobilePanel = createMobilePanel()
tpBatFloatingButton = createTpBatFloatingButton()

instaResetFloatingButton = createInstaResetFloatingButton()

if LP.Character then
    task.wait(0.1)
    if waitForCharReady(LP.Character, 5) then
        setupMovementAndIndicators(LP.Character)
        if currentAnimPack ~= "Off" then
            startAnimPack(currentAnimPack)
        end
        pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
    end
end

-- ============================================================
-- CONEXIÓN ÚNICA DE RESPAWN (evita race conditions)
-- ============================================================
local _respawnQueue = 0
LP.CharacterAdded:Connect(function(char)
    _respawnQueue = _respawnQueue + 1
    local myId = _respawnQueue

    if stealConnection then stealConnection:Disconnect(); stealConnection = nil end
    isStealing = false
    stopAutoLeft()
    stopAutoRight()
    stopBatCounter()
    stopMedusaCounter()
    if not _tpBatUnwalkForced then stopUnwalk() end
    stopDropBrainrot()
    if autoBatEnabled then disableAutoBat() end
    if batDesyncTpEnabled then stopBatDesyncTp() end
    if autoBatV2Enabled then disableBatV2() end
    if bodyLockEnabled then stopBodyLock() end

    local deadline = _tick() + 5
    while (not char.Parent) or (not char:FindFirstChild("HumanoidRootPart"))
          or (not char:FindFirstChildOfClass("Humanoid")) do
        if _tick() > deadline then return end
        if myId ~= _respawnQueue then return end
        task.wait(0.05)
    end

    _hookedVelParts = {}
    local _hrpRespawn = _setupVelChecked(char)
    _hookVelHRP(_hrpRespawn)

    setupMovementAndIndicators(char)

    if antiRagdollMode == "v1" then AntiRagdollV1.start()
    elseif antiRagdollMode == "v2" then startAntiRagdollV2() end

    if AntiDieModule.enabled then task.defer(function() activateOnCharacter(char) end) end
    if CONFIG.AUTO_STEAL_ENABLED then
        if autoGrabVariant == "v2" then pcall(startAutoStealV2) else pcall(startAutoSteal) end
    end
    if batDesyncTpEnabled then task.defer(startBatDesyncTp) end
    if autoBatV2Enabled then task.defer(startBatV2Aimbot) end
    if bodyLockEnabled and _blSuppressCount == 0 then startBodyLock() end

    if medusaCounterEnabled then
        setupMedusaCounter(char)
        if setMedusaVisual then setMedusaVisual(true) end
    else
        stopMedusaCounter()
        if setMedusaVisual then setMedusaVisual(false) end
    end

    if batCounterEnabled then startBatCounter() end
    if unwalkEnabled and not _tpBatUnwalkForced then startUnwalk() end

    if currentAnimPack ~= "Off" then
        task.wait(0.3)
        startAnimPack(currentAnimPack)
    end

    updateProgressBarVisibility()
    refreshSpeedModeLabel()

    pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
    if outfitSelectorLabel then
        outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
    end
end)

local lastLaggerToggle = 0
local LAGGER_COOLDOWN = 0.3

UIS.InputBegan:Connect(function(input, gpe)
    if _anyKeyListening then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if gpe or UIS:GetFocusedTextBox() then return end
    elseif not isGamepadInput(input) then
        return
    end
    if not isBindableInput(input) then return end

    local kc = input.KeyCode
    if not kc then return end

    if kbMatch(KB.LaggerMode, kc) then
        if _tick() - lastLaggerToggle >= LAGGER_COOLDOWN then
            lastLaggerToggle = _tick()
            toggleLaggerCycle()
        end
        return
    end
    if kbMatch(KB.CarryToggle, kc) then toggleCarryMode(); return end
    if kbMatch(KB.DropBrainrot, kc) then
        if not dropActive then
            if dropBrainrotSetVisual then dropBrainrotSetVisual(true) end
            executeDropWithToggle(dropBrainrotSetVisual)
        end
        return
    end
    if kbMatch(KB.TPFloor, kc) then doTpDown(); return end
    if kbMatch(KB.InstaReset, kc) then
        if _G.InstaReset and _G.InstaReset.Trigger then
            _G.InstaReset.Trigger()
        end
        return
    end
    if kbMatch(KB.AutoLeft, kc) then
        autoLeftEnabled = not autoLeftEnabled
        if autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
        if autoLeftSetVisual then autoLeftSetVisual(autoLeftEnabled) end
        if mobSetAutoLeft then mobSetAutoLeft(autoLeftEnabled) end
        return
    end
    if kbMatch(KB.AutoRight, kc) then
        autoRightEnabled = not autoRightEnabled
        if autoRightEnabled then startAutoRight() else stopAutoRight() end
        if autoRightSetVisual then autoRightSetVisual(autoRightEnabled) end
        if mobSetAutoRight then mobSetAutoRight(autoRightEnabled) end
        return
    end
    if kbMatch(KB.AutoBat, kc) then
        if not isAimbotEnabled() then
            stopAllExclusiveModes()
            if batAimbotVariant == "bypass" then enableBatV3()
            elseif batAimbotVariant == "v2" then enableBatV2()
            else enableAutoBat() end
        else
            if batAimbotVariant == "bypass" then disableBatV3()
            elseif batAimbotVariant == "v2" then disableBatV2()
            else disableAutoBat() end
        end
        if autoBatSetVisual then autoBatSetVisual(isAimbotEnabled()) end
        if mobSetAutoBat then mobSetAutoBat(isAimbotEnabled()) end
        return
    end
    if kbMatch(KB.TPBat, kc) then
        if not batDesyncTpEnabled then stopAllExclusiveModes() end
        toggleBatDesyncTp()
        if batDesyncTpSetVisual then batDesyncTpSetVisual(batDesyncTpEnabled) end
        if tpBatFloatingButton then
            local btnFrame = tpBatFloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, batDesyncTpEnabled) end
        end
        return
    end
    if kbMatch(KB.BatV2, kc) then
        toggleBatV2()
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, isAimbotEnabled()) end
        end
        return
    end
    if kbMatch(KB.GuiHide, kc) then
        if main then
            if main.Visible then hideGui() else showGui() end
        end
        return
    end
end)