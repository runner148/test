--[=[
  RareFinder Standalone — отдельный скрипт только для поиска редких объектов.
  Не зависит от Carrier и не использует его профили/состояние.
  Ищет Shiny-деревья/руды по атрибутам и звёзды/светлячков/призраков в World.LooseItems.
  При находке уведомляет и телепортирует игрока к объекту. Есть Продолжить / Пауза / Стоп.
  Настройки хранятся отдельно по UserId и PlaceId, если executor поддерживает readfile/writefile.
]=]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")
local KEY = tostring(game.PlaceId) .. "_" .. tostring(lp.UserId)
local SETTINGS_FILE = "RareFinder_" .. KEY .. ".json"

local settings = {
    scanInterval = 1,
    teleportOffset = 6,
    shinyTrees = true, shinyOres = true, goldenApple = true,
    blueStars = true, purpleStars = true,
    blueFireflies = true, purpleFireflies = true,
    ghosts = true, ghostFireflies = true,
}

local function loadSettings()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    local ok, exists = pcall(isfile, SETTINGS_FILE)
    if not ok or not exists then return end
    local good, raw = pcall(readfile, SETTINGS_FILE)
    if not good then return end
    local parsed, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if parsed and type(data) == "table" then
        for k, v in pairs(settings) do
            if data[k] ~= nil and type(data[k]) == type(v) then settings[k] = data[k] end
        end
    end
end
local function saveSettings()
    if type(writefile) ~= "function" then return end
    pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(settings)) end)
end
loadSettings()

local old = playerGui:FindFirstChild("RareFinderStandalone")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "RareFinderStandalone"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
pcall(function() gui.Parent = playerGui end)
if not gui.Parent then gui.Parent = game:GetService("CoreGui") end

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local main = make("Frame", {
    Name="Main", Size=UDim2.fromOffset(310, 430), Position=UDim2.new(0, 12, 0.18, 0),
    BackgroundColor3=Color3.fromRGB(24, 27, 34), BorderSizePixel=0,
}, gui)
make("UICorner", {CornerRadius=UDim.new(0, 8)}, main)
make("UIStroke", {Color=Color3.fromRGB(75, 88, 105), Thickness=1}, main)
local title = make("TextLabel", {
    Size=UDim2.new(1,-42,0,38), Position=UDim2.fromOffset(12,4), BackgroundTransparency=1,
    Text="RareFinder", TextColor3=Color3.fromRGB(240,245,250),
    TextSize=16, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left,
}, main)
local hide = make("TextButton", {
    Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-34,0,8), Text="—",
    TextSize=18, Font=Enum.Font.GothamBold, TextColor3=Color3.new(1,1,1),
    BackgroundColor3=Color3.fromRGB(55,63,75), BorderSizePixel=0,
}, main)
make("UICorner", {CornerRadius=UDim.new(0,5)}, hide)
local content = make("Frame", {Size=UDim2.new(1,-20,1,-52), Position=UDim2.fromOffset(10,44), BackgroundTransparency=1}, main)
local status = make("TextLabel", {
    Size=UDim2.new(1,0,0,38), BackgroundColor3=Color3.fromRGB(35,41,51), BorderSizePixel=0,
    Text="Готов. Выбери категории и нажми «Продолжить».", TextWrapped=true, TextSize=12,
    Font=Enum.Font.Gotham, TextColor3=Color3.fromRGB(220,226,235),
}, content)
make("UICorner", {CornerRadius=UDim.new(0,5)}, status)
local scroll = make("ScrollingFrame", {
    Size=UDim2.new(1,0,1,-124), Position=UDim2.fromOffset(0,44), BackgroundTransparency=1,
    BorderSizePixel=0, ScrollBarThickness=5, CanvasSize=UDim2.fromOffset(0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
}, content)
make("UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, scroll)
local rowIndex = 0
local function rowLabel(text)
    rowIndex += 1
    return make("TextLabel", {LayoutOrder=rowIndex, Size=UDim2.new(1,-4,0,22), BackgroundTransparency=1,
        Text=text, TextColor3=Color3.fromRGB(170,195,220), TextSize=12, Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left}, scroll)
end
local function toggle(key, label)
    rowIndex += 1
    local b = make("TextButton", {LayoutOrder=rowIndex, Size=UDim2.new(1,-4,0,26), BorderSizePixel=0,
        BackgroundColor3=settings[key] and Color3.fromRGB(38,94,75) or Color3.fromRGB(55,59,68),
        Text="", AutoButtonColor=true}, scroll)
    make("UICorner", {CornerRadius=UDim.new(0,4)}, b)
    local function refresh()
        b.Text=(settings[key] and "✓  " or "○  ") .. label
        b.TextColor3=settings[key] and Color3.fromRGB(230,255,240) or Color3.fromRGB(215,220,228)
        b.TextSize=13; b.Font=Enum.Font.Gotham; b.TextXAlignment=Enum.TextXAlignment.Left
        b.BackgroundColor3=settings[key] and Color3.fromRGB(38,94,75) or Color3.fromRGB(55,59,68)
    end
    refresh()
    b.MouseButton1Click:Connect(function() settings[key]=not settings[key]; refresh(); saveSettings() end)
end
local function numberSetting(label, key, placeholder)
    rowIndex += 1
    local r = make("Frame", {LayoutOrder=rowIndex, Size=UDim2.new(1,-4,0,30), BackgroundTransparency=1}, scroll)
    make("TextLabel", {Size=UDim2.new(0.66,0,1,0), BackgroundTransparency=1, Text=label,
        TextColor3=Color3.fromRGB(220,226,235), TextSize=12, Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left}, r)
    local box = make("TextBox", {Size=UDim2.new(0.34,-3,1,0), Position=UDim2.new(0.66,3,0,0),
        BackgroundColor3=Color3.fromRGB(43,49,60), BorderSizePixel=0, Text=tostring(settings[key]),
        PlaceholderText=placeholder or "число", ClearTextOnFocus=false, TextColor3=Color3.new(1,1,1),
        TextSize=12, Font=Enum.Font.Gotham}, r)
    make("UICorner", {CornerRadius=UDim.new(0,4)}, box)
    box.FocusLost:Connect(function()
        local n=tonumber(box.Text)
        if n and n >= 0 and n < math.huge then settings[key]=n; box.Text=tostring(n); saveSettings()
        else box.Text=tostring(settings[key]); status.Text="Нужно ввести конечное число ≥ 0." end
    end)
end
rowLabel("КАТЕГОРИИ")
toggle("shinyTrees", "Shiny-деревья")
toggle("shinyOres", "Shiny-руды")
toggle("goldenApple", "Золотые яблоки")
toggle("blueStars", "Синие звёзды")
toggle("purpleStars", "Фиолетовые звёзды")
toggle("blueFireflies", "Синие светлячки")
toggle("purpleFireflies", "Фиолетовые светлячки")
toggle("ghosts", "Синие/фиолетовые призраки")
toggle("ghostFireflies", "Призрачные светлячки")
rowLabel("ПАРАМЕТРЫ (без верхнего лимита)")
numberSetting("Интервал проверки, сек.", "scanInterval")
numberSetting("Высота телепорта, студы", "teleportOffset")
local buttons = make("Frame", {Size=UDim2.new(1,0,0,72), Position=UDim2.new(0,0,1,-72), BackgroundTransparency=1}, content)
local function actionButton(text, x, width, color)
    local b=make("TextButton", {Size=UDim2.new(width, -4, 0,30), Position=UDim2.new(x,2,0,0),
        BackgroundColor3=color, BorderSizePixel=0, Text=text, TextColor3=Color3.new(1,1,1),
        TextSize=13, Font=Enum.Font.GothamBold}, buttons)
    make("UICorner", {CornerRadius=UDim.new(0,5)}, b)
    return b
end
local resumeBtn=actionButton("Продолжить",0,0.34,Color3.fromRGB(37,118,83))
local pauseBtn=actionButton("Пауза",0.34,0.32,Color3.fromRGB(145,103,37))
local stopBtn=actionButton("Стоп",0.66,0.34,Color3.fromRGB(145,55,55))
local mini = make("TextButton", {Visible=false, Size=UDim2.fromOffset(120,34), Position=UDim2.new(0,20,0.4,0),
    BackgroundColor3=Color3.fromRGB(24,27,34), Text="RareFinder открыть", TextColor3=Color3.new(1,1,1),
    TextSize=12, Font=Enum.Font.GothamBold, BorderSizePixel=0}, gui)
make("UICorner", {CornerRadius=UDim.new(0,6)}, mini)

-- Responsive sizing: keep the window inside the current screen, including phones.
local MIN_W, MIN_H = 270, 330
local function clampWindowSize(w, h)
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    local maxW, maxH = math.max(MIN_W, vp.X - 16), math.max(MIN_H, vp.Y - 32)
    return math.clamp(w, MIN_W, maxW), math.clamp(h, MIN_H, maxH)
end
local function fitWindowToScreen()
    local w, h = clampWindowSize(main.AbsoluteSize.X, main.AbsoluteSize.Y)
    main.Size = UDim2.fromOffset(w, h)
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    local x = math.clamp(main.AbsolutePosition.X, 0, math.max(0, vp.X - w))
    local y = math.clamp(main.AbsolutePosition.Y, 0, math.max(0, vp.Y - h))
    main.Position = UDim2.fromOffset(x, y)
    scroll.Size = UDim2.new(1, 0, 1, -124)
end
local resizeGrip = make("TextButton", {
    Name="ResizeGrip", Size=UDim2.fromOffset(28,28), AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,-3,1,-3), BackgroundColor3=Color3.fromRGB(55,63,75),
    BorderSizePixel=0, Text="↘", TextColor3=Color3.fromRGB(235,240,248),
    TextSize=17, Font=Enum.Font.GothamBold, AutoButtonColor=true,
}, main)
make("UICorner", {CornerRadius=UDim.new(0,5)}, resizeGrip)
local resizing, resizeStart, sizeStart = false, nil, nil
resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        sizeStart = main.AbsoluteSize
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then resizing = false end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local w, h = clampWindowSize(sizeStart.X + delta.X, sizeStart.Y + delta.Y)
        main.Size = UDim2.fromOffset(w, h)
        scroll.Size = UDim2.new(1, 0, 1, -124)
        fitWindowToScreen()
    end
end)
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindowToScreen)
end
fitWindowToScreen()

hide.MouseButton1Click:Connect(function() main.Visible=false; mini.Visible=true end)
mini.MouseButton1Click:Connect(function() main.Visible=true; mini.Visible=false end)

-- Drag window from title bar.
do
    local dragging, dragInput, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=main.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    title.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input==dragInput then
            local delta=input.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
end

local function notify(s)
    status.Text=tostring(s)
    pcall(function() StarterGui:SetCore("SendNotification", {Title="RareFinder", Text=tostring(s), Duration=7}) end)
end
local function hasWord(s, ...)
    s=tostring(s or ""):lower():gsub("[%s_%-]", "")
    for i=1,select("#",...) do
        local w=tostring(select(i,...)):lower():gsub("[%s_%-]","")
        if w~="" and s:find(w,1,true) then return true end
    end
    return false
end
local function attrText(inst)
    local bits={inst.Name}
    local ok, attrs=pcall(function() return inst:GetAttributes() end)
    if ok then for k,v in pairs(attrs) do bits[#bits+1]=tostring(k); bits[#bits+1]=tostring(v) end end
    return table.concat(bits," ")
end
local function looseFolderFor(inst)
    local world=workspace:FindFirstChild("World")
    local loose=world and world:FindFirstChild("LooseItems")
    local p=inst
    while p and p~=workspace do if p==loose and loose then return loose end; p=p.Parent end
    return nil
end
local function normalizeCandidate(inst)
    local loose=looseFolderFor(inst)
    if loose then
        local root=inst
        while root.Parent and root.Parent~=loose do root=root.Parent end
        if root.Parent==loose then return root end
    end
    local p=inst
    while p and p~=workspace do
        if p:IsA("Model") and (p:GetAttribute("TreeName")~=nil or p:GetAttribute("OreName")~=nil
            or p:GetAttribute("Choppable")==true or p:GetAttribute("Mineable")==true) then return p end
        p=p.Parent
    end
    if inst:IsA("Model") or inst:IsA("BasePart") then return inst end
    return nil
end
local function candidateAllowed(inst)
    if not inst or not inst.Parent or not (inst:IsA("Model") or inst:IsA("BasePart")) then return false end
    if inst:GetAttribute("TreeName")~=nil or inst:GetAttribute("OreName")~=nil
        or inst:GetAttribute("Choppable")==true or inst:GetAttribute("Mineable")==true then return true end
    local loose=looseFolderFor(inst)
    local t=attrText(inst):lower()
    local starFlyGhost=hasWord(t,"star","glowworm","firefly","ghost","specter","spectre")
    local golden=hasWord(t,"goldenapple","goldapple") or (hasWord(t,"golden") and hasWord(t,"apple"))
    if starFlyGhost and not loose then return false end
    if loose then return hasWord(t,"star","glowworm","firefly","ghost","specter","spectre","goldenapple","goldapple") end
    return golden
end
local function deepText(inst)
    local bits={attrText(inst)}
    if inst:IsA("Model") then
        local ok, desc=pcall(function() return inst:GetDescendants() end)
        if ok then for _,d in ipairs(desc) do
            bits[#bits+1]=attrText(d)
        end end
    end
    return table.concat(bits," "):lower()
end
local function classify(inst)
    if not inst or not inst.Parent then return nil end
    local tree=inst:GetAttribute("TreeName")~=nil or inst:GetAttribute("Choppable")==true
    local ore=inst:GetAttribute("OreName")~=nil or inst:GetAttribute("Mineable")==true
    local loose=looseFolderFor(inst)~=nil
    if not tree and not ore and not loose and not hasWord(inst.Name,"apple") then return nil end
    local txt=deepText(inst):gsub("[%s_%-]","")
    local blue=hasWord(txt,"blue","azure")
    local purple=hasWord(txt,"purple","violet")
    local ghost=hasWord(txt,"ghost","specter","spectre")
    local fly=hasWord(txt,"glowworm","firefly","fireflies")
    local star=hasWord(txt,"star")
    local shiny=hasWord(txt,"shiny")
    local apple=hasWord(txt,"goldenapple","goldapple") or (hasWord(txt,"golden") and hasWord(txt,"apple"))
    if tree and shiny and settings.shinyTrees then return "Shiny-дерево" end
    if ore and shiny and settings.shinyOres then return "Shiny-руда" end
    if apple and settings.goldenApple then return "Золотое яблоко" end
    if ghost and fly and settings.ghostFireflies then return "Призрачный светлячок" end
    if ghost and not fly and (blue or purple) and settings.ghosts then return purple and "Фиолетовый призрак" or "Синий призрак" end
    if fly and not ghost and blue and settings.blueFireflies then return "Синий светлячок" end
    if fly and not ghost and purple and settings.purpleFireflies then return "Фиолетовый светлячок" end
    if star and blue and settings.blueStars then return "Синяя звезда" end
    if star and purple and settings.purpleStars then return "Фиолетовая звезда" end
    return nil
end
local function targetPosition(inst)
    local ok,pos=pcall(function()
        if inst:IsA("Model") then return inst:GetPivot().Position end
        if inst:IsA("BasePart") then return inst.Position end
    end)
    return ok and pos or nil
end

local state="stopped" -- stopped / running / paused
local candidates, candidateSet={},setmetatable({}, {__mode="k"})
local seen=setmetatable({}, {__mode="k"})
local addedConn=nil
local runToken=0
local function addCandidate(inst)
    if not candidateAllowed(inst) then return end
    local root=normalizeCandidate(inst)
    if not root or not root.Parent or candidateSet[root] then return end
    candidateSet[root]=true
    candidates[#candidates+1]=root
end
local function disconnectScan()
    if addedConn then pcall(function() addedConn:Disconnect() end); addedConn=nil end
end
local function stopSearch()
    state="stopped"; runToken+=1; disconnectScan()
    notify("Поиск остановлен. Для нового запуска нажми «Продолжить».")
end
local function runLoop(token)
    while state~="stopped" and token==runToken do
        if state=="running" then
            for i=#candidates,1,-1 do
                if state~="running" or token~=runToken then break end
                local inst=candidates[i]
                if not inst or not inst.Parent then
                    table.remove(candidates,i); if inst then candidateSet[inst]=nil end
                elseif not seen[inst] then
                    local label=classify(inst)
                    if label then
                        seen[inst]=true
                        local pos=targetPosition(inst)
                        local char=lp.Character
                        local hrp=char and char:FindFirstChild("HumanoidRootPart")
                        if pos and hrp then
                            pcall(function() hrp.CFrame=CFrame.new(pos+Vector3.new(0,settings.teleportOffset,0)) end)
                            notify("Найдено: "..label.." — телепорт к цели")
                            task.wait(1)
                        else
                            notify("Найдено: "..label..", но позиция/персонаж недоступны")
                        end
                    end
                end
            end
            local interval=tonumber(settings.scanInterval) or 1
            if interval<=0 then interval=0.01 end
            task.wait(interval)
        else
            task.wait(0.15)
        end
    end
end
local function startOrResume()
    if state=="running" then notify("Поиск уже запущен."); return end
    if state=="paused" then state="running"; notify("Поиск продолжен."); return end
    candidates={}; candidateSet=setmetatable({}, {__mode="k"}); seen=setmetatable({}, {__mode="k"})
    for _,d in ipairs(workspace:GetDescendants()) do addCandidate(d) end
    disconnectScan()
    addedConn=workspace.DescendantAdded:Connect(function(d)
        addCandidate(d)
        local p=d.Parent
        while p and p~=workspace do if p:IsA("Model") then addCandidate(p) end; p=p.Parent end
    end)
    state="running"; runToken+=1
    local token=runToken
    notify("Поиск запущен. Кандидатов: "..tostring(#candidates))
    task.spawn(runLoop,token)
end
resumeBtn.MouseButton1Click:Connect(startOrResume)
pauseBtn.MouseButton1Click:Connect(function()
    if state=="running" then state="paused"; notify("Поиск на паузе. Нажми «Продолжить» для возобновления.")
    elseif state=="paused" then notify("Поиск уже на паузе.") else notify("Поиск остановлен; нажми «Продолжить».") end
end)
stopBtn.MouseButton1Click:Connect(stopSearch)

gui.Destroying:Connect(function() state="stopped"; runToken+=1; disconnectScan() end)
notify("Готов. Настройки отдельные для аккаунта "..tostring(lp.UserId).." и PlaceId "..tostring(game.PlaceId)..".")
