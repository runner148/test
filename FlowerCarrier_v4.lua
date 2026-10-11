--[[ Flower Carrier v3
  Методы захвата:
    Grabby - тул (поле, берёт сразу много предметов). Перед первым использованием
             в сессии ОДИН РАЗ вручную возьмите и поставьте предмет Grabby grabber:
             скрипт запомнит названия действий и UUID тула (метка "Grabby: готов").
    Рука   - обычная рука (один предмет, ремоуты 253-256).
  Режимы: Teleport (быстро) и Walk (пешком).
  Индексы ремоутов могут съехать после обновления игры.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local RS         = game:GetService("ReplicatedStorage")

local env = (getgenv and getgenv()) or _G
env.GG = env.GG or {}
local GG = env.GG -- общая память с GrabbyRecorder (названия действий тула, UUID)

local lp   = Players.LocalPlayer
local kids = RS:WaitForChild("REM"):GetChildren()
if #kids < 257 then warn("[carrier] ремоутов меньше 257, индексы, скорее всего, съехали") end

-- ===== НАСТРОЙКИ (меняются в GUI) =====
local CFG = {
    Method       = "Grabby",   -- "Grabby" или "Hand"
    ItemName     = "BurningBloom", -- пусто = любой предмет с Draggable
    Mode         = "Teleport", -- "Teleport" или "Walk"
    LoopAll      = true,
    MaxItems     = 10,         -- поездок (Grabby) или предметов (Рука)
    GrabDistance = 4,          -- на каком расстоянии от предмета встаём
    FieldRadius  = 14,         -- Grabby: какие помеченные предметы считаем "нашими"
    CarryForward = 5,          -- на сколько студов вперёд держим предметы
    CarryHeight  = -1,
    SkipNearDrop = 12,         -- предметы ближе этого к точке выгрузки не трогаем
    MaxRange     = 600,
    GrabTimeout  = 2.5,
    WalkTimeout  = 90,
    Pause        = 1,
}

local HAND = { GRAB = 254, CONFIRM = 253, MOVE = 255, RELEASE = 256 }
local TOOL = { EQUIP = 214, UNEQUIP = 215, ACT = 216 }

-- ===== СОСТОЯНИЕ =====
local running, stopFlag = false, false
local dropCF = nil
local cleanupFn = nil
local run, startBtn, modeBtn, loopBtn, methodBtn, statusLabel

local function setStatus(t)
    if statusLabel then statusLabel.Text = t end
    print("[carrier]", t)
end

local function fire(key, data)
    local r = kids[HAND[key]]
    if r then pcall(r.FireServer, r, data) end
end

local function toolFire(idx, data)
    local r = kids[idx]
    if r then pcall(r.FireServer, r, data) end
end

local function toolAct(key, data)
    local rec = GG[key] or GG.stop
    if not (rec and GG.toolUuid) then return false end
    toolFire(TOOL.ACT, { Name = rec.Name, UUID = GG.toolUuid, Data = data })
    return true
end

local function grabbyReady()
    return GG.toolUuid ~= nil and GG.grab ~= nil and GG.drop ~= nil and GG.stop ~= nil
end

-- ===== ЗАПИСЬ ДЕЙСТВИЙ GRABBY (вручную 1 раз за сессию) =====
env.CarrierKids = kids
env.CarrierRec = function(self, a)
    if self == kids[TOOL.EQUIP] then GG.last = "equip" return end
    if self == kids[TOOL.UNEQUIP] then GG.last = "unequip" return end
    if self ~= kids[TOOL.ACT] then return end
    local d = a and a.Data
    if type(d) ~= "table" then return end
    if d.Position ~= nil then
        GG.grab = { Name = a.Name }
        GG.last = "grab"
        if a.UUID then GG.toolUuid = a.UUID end
    elseif d.CF ~= nil then
        GG.drop = { Name = a.Name }
        GG.last = "drop"
        if a.UUID then GG.toolUuid = a.UUID end
    elseif next(d) == nil then
        GG.stop = { Name = a.Name }
        GG["stop_" .. (GG.last or "?")] = { Name = a.Name }
        GG.last = "stop"
    end
end

if not env.CarrierHooked and hookmetamethod then
    env.CarrierHooked = true
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local K = env.CarrierKids
        if K and getnamecallmethod() == "FireServer"
            and (self == K[TOOL.EQUIP] or self == K[TOOL.UNEQUIP] or self == K[TOOL.ACT])
            and not (checkcaller and checkcaller()) then
            local a = ({ ... })[1]
            if type(a) ~= "table" then a = nil end
            task.spawn(env.CarrierRec, self, a)
        end
        return old(self, ...)
    end)
end

-- ===== ОБЩИЕ ФУНКЦИИ =====
local function getChar()
    local c = lp.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then return hrp, hum end
end

local function getFolder()
    local w = workspace:FindFirstChild("World")
    return w and w:FindFirstChild("LooseItems")
end

local function partOf(item)
    return (item:IsA("BasePart") and item) or item:FindFirstChild("default")
        or item:FindFirstChildWhichIsA("BasePart", true)
end

local function surfacePoint(item, fromPos, center)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { item }
    local hit = workspace:Raycast(fromPos, center - fromPos, rp)
    return hit and hit.Position or center
end

local function skipDistance()
    if CFG.Method == "Grabby" then
        return math.max(CFG.SkipNearDrop, CFG.FieldRadius + CFG.CarryForward + 6)
    end
    return CFG.SkipNearDrop
end

-- "RoughPlank, LooseTree" -> { RoughPlank = true, LooseTree = true }
local function parseNames(s)
    local set = {}
    for n in tostring(s):gmatch("[^,]+") do
        n = n:match("^%s*(.-)%s*$")
        if n ~= "" then set[n] = true end
    end
    return set
end

local function findItems(origin)
    local list = {}
    local folder = getFolder()
    if not folder then return list end
    local skipD = skipDistance()
    local names = parseNames(CFG.ItemName)
    local anyName = next(names) == nil
    for _, v in ipairs(folder:GetChildren()) do
        local nameOk = (anyName and v:GetAttribute("Draggable") == true) or names[v.Name]
        if nameOk and not v:GetAttribute("PlayerDragging")
            and v:GetAttribute("ActivelyDragging") ~= true then
            local ok, p = pcall(function() return v:GetPivot().Position end)
            if ok then
                local d = (p - origin).Magnitude
                if d > skipD and d <= CFG.MaxRange then
                    table.insert(list, { item = v, d = d })
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end

local function approach(hrp, hum, ip)
    if CFG.Mode == "Teleport" then
        local flat = Vector3.new(hrp.Position.X - ip.X, 0, hrp.Position.Z - ip.Z)
        flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
        hrp.CFrame = CFrame.new(ip + flat * CFG.GrabDistance + Vector3.new(0, 3, 0))
        task.wait(0.4)
    else
        local t = os.clock()
        while (hrp.Position - ip).Magnitude > CFG.GrabDistance + 1.5
            and os.clock() - t < CFG.WalkTimeout and not stopFlag do
            hum:MoveTo(ip)
            task.wait(0.2)
        end
    end
end

local function carryPos(hrp)
    return hrp.Position + hrp.CFrame.LookVector * CFG.CarryForward + Vector3.new(0, CFG.CarryHeight, 0)
end

-- "магниты" на предметах: тянут их к точке перед игроком
local function startMagnets(entries)
    local list = {}
    for _, e in ipairs(entries) do
        local att = Instance.new("Attachment")
        att.Parent = e.part

        local ap = Instance.new("AlignPosition")
        ap.Mode = Enum.PositionAlignmentMode.OneAttachment
        ap.Attachment0 = att
        ap.MaxForce = math.huge
        ap.MaxVelocity = math.huge
        ap.Responsiveness = 50
        ap.Parent = att

        local ao = Instance.new("AlignOrientation")
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.Attachment0 = att
        ao.CFrame = CFrame.new()
        ao.MaxTorque = math.huge
        ao.Responsiveness = 50
        ao.Parent = att

        list[#list + 1] = { item = e.item, part = e.part, att = att, ap = ap, off = e.off }
    end
    return list
end

local function updateMagnets(list, c)
    for _, m in ipairs(list) do m.ap.Position = c + m.off end
end

local function destroyMagnets(list)
    for _, m in ipairs(list) do pcall(function() m.att:Destroy() end) end
end

-- доставка в точку выгрузки; held() говорит, держит ли ещё сервер предметы
local function deliver(hrp, hum, magnets, held)
    if CFG.Mode == "Teleport" then
        task.wait(0.3)
        hrp.CFrame = dropCF
        task.wait(0.1)
        local c = carryPos(hrp)
        for _, m in ipairs(magnets) do
            pcall(function() m.item:PivotTo(CFrame.new(c + m.off)) end)
        end
        task.wait(1)
        if (hrp.Position - dropCF.Position).Magnitude > 25 then
            return false, "античит вернул назад"
        end
    else
        local t1 = os.clock()
        while (hrp.Position - dropCF.Position).Magnitude > 4
            and os.clock() - t1 < CFG.WalkTimeout and not stopFlag do
            if not held() then return false, "предметы потеряны по пути" end
            hum:MoveTo(dropCF.Position)
            task.wait(0.25)
        end
        task.wait(0.8)
    end
    if not held() then return false, "сервер забрал предметы" end
    return true, "ok"
end

-- ===== МЕТОД: РУКА (один предмет) =====
local function carryHand(item)
    local hrp, hum = getChar()
    if not hrp then return false, "нет персонажа" end
    local part = partOf(item)
    if not part then return false, "у предмета нет детали" end

    approach(hrp, hum, item:GetPivot().Position)
    if stopFlag then return false, "остановлено" end
    if not item.Parent then return false, "предмет исчез" end

    local c0 = item:GetPivot().Position
    fire("GRAB", { Object = item, WorldPos = surfacePoint(item, hrp.Position, c0) })
    fire("CONFIRM", {})

    local t0 = os.clock()
    repeat task.wait(0.05)
    until item:GetAttribute("PlayerDragging") == lp.Name or os.clock() - t0 > CFG.GrabTimeout
    if item:GetAttribute("PlayerDragging") ~= lp.Name then
        return false, "захват не принят (далеко?)"
    end

    local magnets = startMagnets({ { item = item, part = part, off = Vector3.zero } })
    local conn = RunService.Heartbeat:Connect(function()
        local c = carryPos(hrp)
        updateMagnets(magnets, c)
        fire("MOVE", { WorldPos = c })
    end)

    local released = false
    local function release()
        if released then return end
        released = true
        conn:Disconnect()
        destroyMagnets(magnets)
        fire("CONFIRM", {})
        fire("RELEASE", {})
        cleanupFn = nil
    end
    cleanupFn = release

    local ok, msg = deliver(hrp, hum, magnets, function()
        return item:GetAttribute("PlayerDragging") == lp.Name
    end)

    release()
    task.wait(0.3)
    return ok, msg, { item }
end

-- ===== МЕТОД: GRABBY GRABBER (поле, много предметов) =====
local function carryGrabby(item)
    if not grabbyReady() then
        return false, "Grabby не записан: возьмите и поставьте предмет им вручную 1 раз"
    end
    local hrp, hum = getChar()
    if not hrp then return false, "нет персонажа" end
    local folder = getFolder()
    if not folder then return false, "нет LooseItems" end

    -- какие предметы уже были помечены до нас (чужие не трогаем)
    local before = {}
    for _, v in ipairs(folder:GetChildren()) do
        if v:GetAttribute("ActivelyDragging") == true then before[v] = true end
    end

    approach(hrp, hum, item:GetPivot().Position)
    if stopFlag then return false, "остановлено" end
    if not item.Parent then return false, "предмет исчез" end

    -- достать тул
    toolFire(TOOL.EQUIP, { UUID = GG.toolUuid })
    task.wait(0.4)
    toolAct("stop_equip", {})
    task.wait(0.3)

    -- взять: точка на поверхности предмета, луч от камеры
    local camPos = workspace.CurrentCamera.CFrame.Position
    local pos = surfacePoint(item, camPos, item:GetPivot().Position)
    toolAct("grab", { Position = pos, CamCF = camPos })
    toolAct("stop_grab", {})

    local function field()
        local out = {}
        for _, v in ipairs(folder:GetChildren()) do
            if v:GetAttribute("ActivelyDragging") == true and not before[v] then
                local p = partOf(v)
                if p and (p.Position - pos).Magnitude <= CFG.FieldRadius then
                    out[#out + 1] = { item = v, part = p }
                end
            end
        end
        return out
    end

    local t0, list = os.clock(), {}
    repeat
        task.wait(0.05)
        list = field()
    until #list > 0 or os.clock() - t0 > CFG.GrabTimeout
    if #list == 0 then
        toolFire(TOOL.UNEQUIP, { UUID = GG.toolUuid })
        toolAct("stop_unequip", {})
        return false, "захват не принят (Grabby)"
    end
    task.wait(0.3)
    list = field() -- добираем остальные предметы поля

    local entries, moved = {}, {}
    for _, e in ipairs(list) do
        entries[#entries + 1] = { item = e.item, part = e.part, off = e.part.Position - pos }
        moved[#moved + 1] = e.item
    end
    local magnets = startMagnets(entries)
    local conn = RunService.Heartbeat:Connect(function()
        updateMagnets(magnets, carryPos(hrp))
    end)

    local released = false
    local function release()
        if released then return end
        released = true
        toolAct("drop", { CF = CFrame.new(carryPos(hrp)) * hrp.CFrame.Rotation })
        toolAct("stop_drop", {})
        task.wait(0.5)
        conn:Disconnect()
        destroyMagnets(magnets)
        toolFire(TOOL.UNEQUIP, { UUID = GG.toolUuid })
        toolAct("stop_unequip", {})
        cleanupFn = nil
    end
    cleanupFn = release

    local ok, msg = deliver(hrp, hum, magnets, function()
        for _, m in ipairs(magnets) do
            if m.item:GetAttribute("ActivelyDragging") == true then return true end
        end
        return false
    end)

    local center = carryPos(hrp)
    release()
    task.wait(1)

    local n = 0
    for _, m in ipairs(magnets) do
        local ok2, p = pcall(function() return m.part.Position end)
        if ok2 and (p - center).Magnitude <= CFG.FieldRadius + 6 then n += 1 end
    end
    if ok then
        msg = ("доставлено %d из %d"):format(n, #magnets)
        ok = n > 0
    end
    return ok, msg, moved
end

-- ===== GUI (компактное, с прокруткой) =====
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local guiParent
pcall(function() guiParent = gethui() end)
if not guiParent then
    pcall(function() guiParent = game:GetService("CoreGui") end)
end
guiParent = guiParent or lp:WaitForChild("PlayerGui")

local old = guiParent:FindFirstChild("FlowerCarrierGui")
if old then old:Destroy() end

local W, HFULL = 236, 216
local gui = mk("ScreenGui", { Name = "FlowerCarrierGui", ResetOnSpawn = false }, guiParent)
local frame = mk("Frame", {
    Size = UDim2.fromOffset(W, HFULL),
    Position = UDim2.new(0, 10, 0, 60),
    BackgroundColor3 = Color3.fromRGB(28, 28, 36),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)

local title = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(45, 45, 60),
    Text = "  Carrier v3",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, title)

statusLabel = mk("TextLabel", {
    Position = UDim2.new(0, 6, 0, 30),
    Size = UDim2.new(1, -12, 0, 28),
    BackgroundTransparency = 1,
    Text = "Готов",
    TextColor3 = Color3.fromRGB(150, 220, 160),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, frame)

local scroll = mk("ScrollingFrame", {
    Position = UDim2.new(0, 6, 0, 60),
    Size = UDim2.new(1, -12, 0, 116),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, frame)
mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, scroll)
mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, scroll)

local order = 0
local function nextOrder() order += 1 return order end

local function mkMiniBtn(text, xOffset, cb)
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(24, 20),
        Position = UDim2.new(1, xOffset, 0, 4),
        BackgroundColor3 = Color3.fromRGB(70, 70, 90),
        Text = text, TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold, TextSize = 13,
    }, title)
    mk("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
    b.Activated:Connect(cb)
end

local minimized = false
local startBtn
mkMiniBtn("X", -28, function()
    stopFlag = true
    if cleanupFn then pcall(cleanupFn) end
    gui:Destroy()
end)
mkMiniBtn("-", -56, function()
    minimized = not minimized
    statusLabel.Visible = not minimized
    scroll.Visible = not minimized
    if startBtn then startBtn.Visible = not minimized end
    frame.Size = UDim2.fromOffset(W, minimized and 28 or HFULL)
end)

-- перетаскивание окна за заголовок
local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, i.Position, frame.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

local function button(text, cb)
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(55, 55, 72),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium, TextSize = 12,
        Text = text, LayoutOrder = nextOrder(),
    }, scroll)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    b.Activated:Connect(function() cb(b) end)
    return b
end

local function inputRow(label, key, isNumber)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = nextOrder(),
    }, scroll)
    mk("TextLabel", {
        Size = UDim2.new(0.58, 0, 1, 0), BackgroundTransparency = 1, Text = label,
        TextColor3 = Color3.fromRGB(210, 210, 220), Font = Enum.Font.Gotham, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local box = mk("TextBox", {
        Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 54), TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false,
        Text = tostring(CFG[key]),
    }, row)
    mk("UICorner", { CornerRadius = UDim.new(0, 5) }, box)
    box.FocusLost:Connect(function()
        if isNumber then
            local v = tonumber(box.Text)
            if v then CFG[key] = v else box.Text = tostring(CFG[key]) end
        else
            CFG[key] = box.Text -- пустое имя разрешено (любой предмет)
        end
    end)
    return box
end

local grabbyLabel = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "",
    TextColor3 = Color3.fromRGB(240, 200, 120), Font = Enum.Font.Gotham, TextSize = 11,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(),
}, scroll)

local function refreshButtons()
    methodBtn.Text = "Захват: " .. (CFG.Method == "Grabby" and "Grabby grabber" or "Рука")
    modeBtn.Text = "Режим: " .. CFG.Mode
    loopBtn.Text = "Повторять: " .. (CFG.LoopAll and "ДА" or "НЕТ")
end

methodBtn = button("", function()
    CFG.Method = CFG.Method == "Grabby" and "Hand" or "Grabby"
    refreshButtons()
end)
modeBtn = button("", function()
    CFG.Mode = CFG.Mode == "Teleport" and "Walk" or "Teleport"
    refreshButtons()
end)
loopBtn = button("", function()
    CFG.LoopAll = not CFG.LoopAll
    refreshButtons()
end)
refreshButtons()

button("Точка выгрузки = здесь", function()
    local hrp = getChar()
    if hrp then
        dropCF = hrp.CFrame
        setStatus("Точка выгрузки сохранена")
    end
end)

inputRow("Предмет", "ItemName", false)
inputRow("Макс. поездок/шт", "MaxItems", true)
inputRow("Дист. захвата", "GrabDistance", true)
inputRow("Радиус поля", "FieldRadius", true)
inputRow("Вперёд (студы)", "CarryForward", true)
inputRow("Высота", "CarryHeight", true)
inputRow("Пауза, сек", "Pause", true)

startBtn = mk("TextButton", {
    Position = UDim2.new(0, 6, 0, 180),
    Size = UDim2.new(1, -12, 0, 30),
    BackgroundColor3 = Color3.fromRGB(40, 110, 60),
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 14, Text = "Старт",
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, startBtn)
startBtn.Activated:Connect(function()
    if running then
        stopFlag = true
        setStatus("Останавливаю...")
    else
        task.spawn(run)
    end
end)

-- метка готовности Grabby обновляется раз в секунду
task.spawn(function()
    while gui.Parent do
        if grabbyReady() then
            grabbyLabel.Text = "Grabby: готов (UUID " .. tostring(GG.toolUuid) .. ")"
            grabbyLabel.TextColor3 = Color3.fromRGB(150, 220, 160)
        else
            grabbyLabel.Text = "Grabby: возьмите и поставьте предмет им вручную 1 раз"
            grabbyLabel.TextColor3 = Color3.fromRGB(240, 200, 120)
        end
        task.wait(1)
    end
end)

-- ===== ГЛАВНЫЙ ЦИКЛ =====
run = function()
    if running then return end
    local hrp = getChar()
    if not hrp then setStatus("Нет персонажа") return end

    running, stopFlag = true, false
    startBtn.Text = "Стоп"
    startBtn.BackgroundColor3 = Color3.fromRGB(130, 50, 50)
    if not dropCF then dropCF = hrp.CFrame end

    local delivered, trips, skipped = 0, 0, {}
    local lastMsg = "Готово"

    while not stopFlag and trips < CFG.MaxItems do
        local target
        for _, e in ipairs(findItems(dropCF.Position)) do
            if not skipped[e.item] then target = e.item break end
        end
        if not target then lastMsg = "Предметов не осталось" break end

        trips += 1
        setStatus(("Поездка %d/%d (%s)..."):format(trips, CFG.MaxItems,
            CFG.Method == "Grabby" and "Grabby" or "Рука"))

        local carryFn = CFG.Method == "Grabby" and carryGrabby or carryHand
        local pc, ok, msg, moved = pcall(carryFn, target)
        if not pc then
            ok, msg = false, tostring(ok)
            if cleanupFn then pcall(cleanupFn) end
        end

        skipped[target] = true
        if moved then
            for _, m in ipairs(moved) do skipped[m] = true end
        end

        if ok then
            delivered += moved and #moved or 1
            lastMsg = tostring(msg)
        else
            lastMsg = "Ошибка: " .. tostring(msg)
            setStatus(lastMsg)
            if msg == "античит вернул назад" and CFG.Mode == "Teleport" then
                CFG.Mode = "Walk"
                refreshButtons()
                lastMsg = "Античит вернул назад, переключил на Walk"
            end
        end

        if not CFG.LoopAll then break end
        task.wait(CFG.Pause)
    end

    running = false
    startBtn.Text = "Старт"
    startBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 60)
    setStatus(("%s. Перенесено предметов: %d"):format(lastMsg, delivered))
end
