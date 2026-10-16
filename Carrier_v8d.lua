--[[ Carrier v8d
  Вкладки: Предметы / Деревья / Руды / Настр.
  Кнопка "Меню" (перетаскиваемая) показывает и скрывает окно.

  Предметы: методы Grabby (поле, много предметов) и Рука; режимы Teleport и Walk.
    Teleport: телепорт к предмету, сразу захват, телепорт в точку выгрузки, держим HoldTime, отпускаем.
    Перед первым использованием Grabby в сессии ОДИН РАЗ вручную возьмите и поставьте им предмет.
  Деревья / Руды: подойти к цели, достать нужный инструмент, бить до срубания/добычи,
    затем (по желанию) перенести получившиеся предметы в точку выгрузки.
    Перед первым использованием ударьте вручную дерево топором и руду киркой минимум по 2 раза
    (так записывается удар и запоминается, какой инструмент для чего).
  Настр.: все параметры, профили (сохранение в файл, если executor умеет, иначе в память сессии).
]]

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui  = game:GetService("StarterGui")

local env = (getgenv and getgenv()) or _G
env.GG = env.GG or {}
local GG = env.GG
env.TM = env.TM or {}
local TM = env.TM
TM.tools = TM.tools or {}
TM.toolFor = TM.toolFor or {}
-- Старые макросы были записаны с общим TM.A, из-за чего второй тип инструмента
-- мог сохранить некорректную последовательность. Сбрасываем их один раз после обновления.
if TM.MacroSchema ~= 2 then
    for _, rec in pairs(TM.tools) do
        rec.macro = nil
        rec.cur = nil
        rec.A = nil
        rec.kinds = nil
    end
    TM.toolFor = {}
    TM.MacroSchema = 2
end

local lp   = Players.LocalPlayer
local kids = RS:WaitForChild("REM"):GetChildren()

-- ===================== НАСТРОЙКИ (схема) =====================
local S = {}
local function def(tab, group, key, label, typ, default, opts)
    S[#S + 1] = { tab = tab, group = group, key = key, label = label, type = typ, default = default, opts = opts }
end

-- вкладка "Предметы"
def("items", nil, "Method", "Метод", "enum", "Grabby", { "Grabby", "Hand" })
def("items", nil, "Mode", "Режим", "enum", "Teleport", { "Teleport", "Walk" })
def("items", nil, "LoopAll", "Повторять", "bool", true)
def("items", nil, "Unowned", "Бесхозные", "bool", true)
def("items", nil, "PreGrab", "Предзахват (схватить+уронить)", "bool", true)
def("items", nil, "MaxItems", "Макс. поездок/шт", "num", 10)
def("items", nil, "FieldRadius", "Радиус поля", "num", 14)
def("items", nil, "CarryForward", "Вперёд (студы)", "num", 5)
def("items", nil, "CarryHeight", "Высота", "num", -1)
def("hidden", nil, "ItemName", "Предметы", "text", "BurningBloom")
def("hidden", nil, "Lang", "Language", "enum", "RU", { "RU", "EN" })

-- вкладка "Деревья"
def("trees", nil, "TreeFilter", "Типы (через ,)", "text", "")
def("trees", nil, "TreeRegion", "Регионы (через ,)", "text", "")
def("trees", nil, "TreeOrder", "Порядок", "enum", "Ближайшие", { "Ближайшие", "Большие первыми", "Малые первыми" })
def("trees", nil, "TreeHitHeight", "Высота удара над низом", "num", 0.3)
def("trees", nil, "TreeMax", "Макс. деревьев", "num", 3)
def("trees", nil, "TreeMaxPower", "Макс. сила дерева (Power)", "num", 99)
def("trees", nil, "TreeCollect", "Собирать после", "bool", true)
def("hidden", nil, "TreeTool", "UUID топора", "text", "")

-- вкладка "Руды"
def("rocks", nil, "RockFilter", "Типы (через ,)", "text", "")
def("rocks", nil, "RockRegion", "Регионы (через ,)", "text", "")
def("rocks", nil, "RockOrder", "Порядок", "enum", "Ближайшие", { "Ближайшие", "Большие первыми", "Малые первыми" })
def("rocks", nil, "RockMax", "Макс. руд", "num", 3)
def("rocks", nil, "OreOnly", "Только руда (Ore)", "bool", false)
def("rocks", nil, "RockMaxPower", "Макс. сила руды (Power)", "num", 99)
def("rocks", nil, "RockCollect", "Собирать после", "bool", true)
def("hidden", nil, "RockTool", "UUID кирки", "text", "")

-- расширенные
def("adv", "Тайминги предметов", "GrabDelay", "Пауза до захвата, с", "num", 0.05)
def("adv", "Тайминги предметов", "HoldTime", "Держать в точке, с", "num", 0.1)
def("adv", "Тайминги предметов", "DropWait", "Пауза после отпускания", "num", 0.3)
def("adv", "Тайминги предметов", "RollbackCheck", "Проверка отката, с", "num", 0.3)
def("adv", "Тайминги предметов", "GrabTimeout", "Ждать захват, с", "num", 2.5)
def("adv", "Тайминги предметов", "Pause", "Пауза между, с", "num", 1)
def("adv", "Тайминги предметов", "EquipWait", "Пауза после достать", "num", 0.4)
def("adv", "Тайминги предметов", "PreGrabHold", "Предзахват: держать, с", "num", 0.15)
def("adv", "Тайминги предметов", "PreGrabWait", "Предзахват: пауза после, с", "num", 0.3)

def("adv", "Дистанции и поиск", "GrabDistance", "Дист. захвата", "num", 4)
def("adv", "Дистанции и поиск", "TeleportUp", "Высота при телепорте", "num", 3)
def("adv", "Дистанции и поиск", "SkipNearDrop", "Пропуск у точки", "num", 12)
def("adv", "Дистанции и поиск", "MaxRange", "Макс. дальность поиска", "num", 600)
def("adv", "Дистанции и поиск", "RollbackDist", "Порог отката, студы", "num", 25)
def("adv", "Дистанции и поиск", "WalkTimeout", "Макс. дорога пешком, с", "num", 90)

def("adv", "Перенос", "CarryResponsiveness", "Сила магнита", "num", 50)
def("adv", "Перенос", "KeepToolEquipped", "Не убирать тул между", "bool", true)
def("adv", "Перенос", "FreezePlayerOnCarry", "Фиксировать персонажа при Grabby/Teleport", "bool", true)
def("adv", "Перенос", "AutoWalkFallback", "При откате - пешком", "bool", true)

def("adv", "Бесхозные предметы", "UnownedRoots", "Где искать (пути)", "text", "World.VariantRegions")
def("adv", "Бесхозные предметы", "UnownedContainer", "Папка с плодами", "text", "Fruit")

def("adv", "Деревья и руды", "SwingLimit", "Макс. ударов по цели", "num", 60)
def("adv", "Деревья и руды", "SwingGap", "Пауза между ударами", "num", 0.05)
def("adv", "Деревья и руды", "StandDist", "Дист. до цели", "num", 4)
def("adv", "Деревья и руды", "StandHeight", "Высота стойки над целью", "num", 3)
def("adv", "Деревья и руды", "SwingExtra", "Добавка к заряду удара, с", "num", 0.12)
def("adv", "Деревья и руды", "SkipSpecial", "Пропуск особых (нужен свой инструмент)", "bool", true)
def("adv", "Телепорт", "TpLift", "Подъём при телепорте, студы", "num", 2)
def("adv", "Деревья и руды", "CollectDelay", "Пауза перед сбором", "num", 0.8)

def("adv", "Ремоуты (индексы)", "HandGrab", "Рука: взять", "num", 254)
def("adv", "Ремоуты (индексы)", "HandConfirm", "Рука: подтвердить", "num", 253)
def("adv", "Ремоуты (индексы)", "HandMove", "Рука: позиция", "num", 255)
def("adv", "Ремоуты (индексы)", "HandRelease", "Рука: отпустить", "num", 256)
def("adv", "Ремоуты (индексы)", "ToolEquip", "Тул: достать", "num", 214)
def("adv", "Ремоуты (индексы)", "ToolUnequip", "Тул: убрать", "num", 215)
def("adv", "Ремоуты (индексы)", "ToolAct", "Тул: действие", "num", 216)

def("adv", "Окно", "GuiScale", "Масштаб окна", "num", 1)

local CFG = {}
for _, s in ipairs(S) do CFG[s.key] = s.default end
env.CFG = CFG

-- ===================== ЯЗЫК (RU / EN) =====================
-- Перевод применяется только к тексту интерфейса и статусов. Логика работает на русских
-- служебных строках, поэтому значения настроек (например, "Ближайшие") не меняются.
local EN = {
    ["Меню"] = "Menu",
    ["Метод"] = "Method",
    ["Режим"] = "Mode",
    ["Повторять"] = "Repeat",
    ["Бесхозные"] = "Unowned",
    ["Предзахват (схватить+уронить)"] = "Pre-grab (grab+drop)",
    ["Макс. поездок/шт"] = "Max trips/items",
    ["Радиус поля"] = "Field radius",
    ["Вперёд (студы)"] = "Forward (studs)",
    ["Высота"] = "Height",
    ["Предметы"] = "Items",
    ["Типы (через ,)"] = "Types (comma-separated)",
    ["Регионы (через ,)"] = "Regions (comma-separated)",
    ["Порядок"] = "Order",
    ["Ближайшие"] = "Nearest",
    ["Большие первыми"] = "Largest first",
    ["Малые первыми"] = "Smallest first",
    ["Высота удара над низом"] = "Hit height above base",
    ["Макс. деревьев"] = "Max trees",
    ["Собирать после"] = "Collect after",
    ["UUID топора"] = "Axe UUID",
    ["Макс. руд"] = "Max ores",
    ["Только руда (Ore)"] = "Ore only",
    ["UUID кирки"] = "Pickaxe UUID",
    ["Тайминги предметов"] = "Item timings",
    ["Пауза до захвата, с"] = "Delay before grab, s",
    ["Держать в точке, с"] = "Hold at drop point, s",
    ["Пауза после отпускания"] = "Delay after release",
    ["Проверка отката, с"] = "Rollback check, s",
    ["Ждать захват, с"] = "Grab timeout, s",
    ["Пауза между, с"] = "Pause between, s",
    ["Пауза после достать"] = "Delay after equip",
    ["Предзахват: держать, с"] = "Pre-grab: hold, s",
    ["Предзахват: пауза после, с"] = "Pre-grab: delay after, s",
    ["Дистанции и поиск"] = "Distances and search",
    ["Дист. захвата"] = "Grab distance",
    ["Высота при телепорте"] = "Teleport height",
    ["Пропуск у точки"] = "Skip near drop point",
    ["Макс. дальность поиска"] = "Max search range",
    ["Порог отката, студы"] = "Rollback threshold, studs",
    ["Макс. дорога пешком, с"] = "Max walking time, s",
    ["Перенос"] = "Carrying",
    ["Сила магнита"] = "Magnet strength",
    ["Не убирать тул между"] = "Keep tool equipped",
    ["Фиксировать персонажа при Grabby/Teleport"] = "Lock character during Grabby/Teleport",
    ["При откате - пешком"] = "Walk after rollback",
    ["Бесхозные предметы"] = "Unowned items",
    ["Где искать (пути)"] = "Search paths",
    ["Папка с плодами"] = "Fruit folder",
    ["Деревья и руды"] = "Trees and ores",
    ["Макс. ударов по цели"] = "Max swings per target",
    ["Пауза между ударами"] = "Delay between swings",
    ["Дист. до цели"] = "Distance to target",
    ["Высота стойки над целью"] = "Stand height above target",
    ["Пауза перед сбором"] = "Delay before collecting",
    ["Ремоуты (индексы)"] = "Remotes (indices)",
    ["Рука: взять"] = "Hand: grab",
    ["Рука: подтвердить"] = "Hand: confirm",
    ["Рука: позиция"] = "Hand: position",
    ["Рука: отпустить"] = "Hand: release",
    ["Тул: достать"] = "Tool: equip",
    ["Тул: убрать"] = "Tool: unequip",
    ["Тул: действие"] = "Tool: action",
    ["Окно"] = "Window",
    ["Масштаб окна"] = "Window scale",
    ["%s(+%.2f с)"] = "%s(+%.2f s)",
    ["[carrier] запомнил удар для %s: %s"] = "[carrier] recorded swing for %s: %s",
    ["предметы потеряны по пути"] = "items lost on the way",
    ["сервер забрал предметы"] = "server took the items",
    ["нет персонажа"] = "no character",
    ["у предмета нет детали"] = "item has no part",
    ["остановлено"] = "stopped",
    ["предмет исчез"] = "item disappeared",
    ["захват не принят (далеко?)"] = "grab not accepted (too far?)",
    ["предмет исчез после предзахвата"] = "item disappeared after pre-grab",
    ["повторный захват не принят"] = "second grab not accepted",
    ["[carrier] предмет заменён копией:"] = "[carrier] item replaced by a copy:",
    ["античит вернул назад"] = "anti-cheat rolled you back",
    ["Grabby не записан: возьмите и поставьте предмет им вручную 1 раз"] = "Grabby not recorded: grab and drop an item with it manually once",
    ["нет LooseItems"] = "no LooseItems",
    ["захват не принят (Grabby)"] = "grab not accepted (Grabby)",
    ["доставлено %d из %d"] = "delivered %d of %d",
    ["Готово"] = "Done",
    ["Предметов не осталось"] = "No items left",
    ["Поездка %d/%d (%s)..."] = "Trip %d/%d (%s)...",
    ["Ошибка: "] = "Error: ",
    ["Античит вернул назад, переключил на Walk"] = "Anti-cheat rolled you back, switched to Walk",
    ["%s. Перенесено предметов: %d"] = "%s. Items moved: %d",
    ["нет записи удара: ударьте вручную "] = "no swing recorded: hit manually ",
    ["дерево топором"] = "a tree with an axe",
    ["руду киркой"] = "an ore with a pickaxe",
    [" 2+ раза"] = " 2+ times",
    ["у цели нет деталей"] = "target has no parts",
    ["лимит ударов"] = "swing limit",
    ["цель уничтожена"] = "target destroyed",
    ["дерево срублено"] = "tree felled",
    ["персонаж пропал"] = "character lost",
    ["нет деталей"] = "no parts",
    ["%s, ударов: %d"] = "%s, swings: %d",
    ["Сбор пропущен: Grabby не записан (возьмите и поставьте предмет им вручную)"] = "Collect skipped: Grabby not recorded (grab and drop an item with it manually)",
    ["Сбор: осталось %d..."] = "Collecting: %d left...",
    ["Нет персонажа"] = "No character",
    ["Целей не найдено (проверьте фильтры и регионы)"] = "No targets found (check filters and regions)",
    ["%s %d/%d (до цели %.0f)..."] = "%s %d/%d (target distance %.0f)...",
    ["Дерево"] = "Tree",
    ["Руда"] = "Ore",
    ["нет записи"] = "no record",
    ["Готово: целей %d, перенесено предметов %d"] = "Done: targets %d, items moved %d",
    ["Предмет пропал"] = "Item is gone",
    ["Несу выбранный предмет: "] = "Carrying selected item: ",
    ["Готово: %s (предметов: %d)"] = "Done: %s (items: %d)",
    ["Точка выгрузки: текущее место"] = "Drop point: current position",
    ["Деревья"] = "Trees",
    ["Руды"] = "Ores",
    ["Настр."] = "Settings",
    ["Готов"] = "Ready",
    ["Старт"] = "Start",
    ["Стоп"] = "Stop",
    ["Старт: предметы"] = "Start: items",
    ["Старт: деревья"] = "Start: trees",
    ["Старт: руды"] = "Start: ores",
    ["Старт (откройте вкладку)"] = "Start (open a tab)",
    ["Останавливаю..."] = "Stopping...",
    ["Откройте вкладку Предметы, Деревья или Руды"] = "Open the Items, Trees or Ores tab",
    ["ДА"] = "YES",
    ["НЕТ"] = "NO",
    ["Точка выгрузки = здесь"] = "Drop point = here",
    ["Точка выгрузки сохранена"] = "Drop point saved",
    [": нажмите, чтобы выбрать"] = ": tap to select",
    [" (нет рядом)"] = " (none nearby)",
    ["Рядом ничего не найдено. Впишите название в поле вручную."] = "Nothing found nearby. Type the name in the field manually.",
    ["Очистить"] = "Clear",
    ["Grabby: готов (UUID "] = "Grabby: ready (UUID ",
    ["Grabby: возьмите и поставьте предмет им вручную 1 раз"] = "Grabby: grab and drop an item with it manually once",
    ["Предметы (через ,)"] = "Items (comma-separated)",
    ["Выбрать из списка..."] = "Pick from list...",
    ["выкл"] = "off",
    ["добавить имя"] = "add name",
    ["перенести предмет"] = "carry item",
    ["Нажатие: "] = "Tap: ",
    ["Тап по предмету в мире: имя добавится в список (повторный тап уберёт)"] = "Tap an item in the world: its name is added to the list (tap again to remove)",
    ["Тап по предмету в мире: он сразу будет перенесён в точку выгрузки"] = "Tap an item in the world: it will be carried to the drop point right away",
    ["Очистить список предметов"] = "Clear item list",
    ["Список пуст: берутся любые предметы с Draggable"] = "List is empty: any Draggable item is used",
    ["Под нажатием ничего нет"] = "Nothing under the tap",
    ["Это не предмет: "] = "Not an item: ",
    ["Добавлено: "] = "Added: ",
    ["Убрано: "] = "Removed: ",
    ["Уже идёт работа: нажмите Стоп"] = "Already working: press Stop",
    ["Топор"] = "Axe",
    ["Кирка"] = "Pickaxe",
    ["выбран "] = "selected ",
    ["авто "] = "auto ",
    ["Нет записанных инструментов: ударьте вручную 2+ раза"] = "No recorded tools: hit manually 2+ times",
    ["Найдено %d: %s"] = "Found %d: %s",
    ["Выбрать тип из списка..."] = "Pick type from list...",
    ["Типы деревьев"] = "Tree types",
    ["Типы руд"] = "Ore types",
    ["Показать цели рядом"] = "Show nearby targets",
    ["Профиль"] = "Profile",
    ["Сохранить профиль"] = "Save profile",
    ["Профиль '%s' сохранён (%s)"] = "Profile '%s' saved (%s)",
    ["файл"] = "file",
    ["только память сессии"] = "session memory only",
    ["Загрузить профиль"] = "Load profile",
    ["Профиль '"] = "Profile '",
    ["' не найден"] = "' not found",
    ["' загружен"] = "' loaded",
    ["Список профилей"] = "List profiles",
    ["Профили: "] = "Profiles: ",
    ["нет"] = "none",
    [" (файлы недоступны)"] = " (files unavailable)",
    ["Сбросить все настройки"] = "Reset all settings",
    ["Настройки сброшены к значениям по умолчанию"] = "Settings reset to defaults",
    ["Закрыть скрипт"] = "Close script",
    ["Загружен профиль default"] = "Loaded profile default",
    [" (из памяти сессии)"] = " (from session memory)",
    ["недоступны (профили только в памяти)"] = "unavailable (profiles in memory only)",
    ["Телепорт"] = "Teleport",
    ["Макс. сила дерева (Power)"] = "Max tree power",
    ["Макс. сила руды (Power)"] = "Max ore power",
    ["Добавка к заряду удара, с"] = "Swing charge margin, s",
    ["Пропуск особых (нужен свой инструмент)"] = "Skip special (needs a specific tool)",
    ["Подъём при телепорте, студы"] = "Teleport lift, studs",
    ["Имя точки"] = "Spot name",
    ["Сохранить здесь"] = "Save here",
    ["Координаты X,Y,Z"] = "Coordinates X,Y,Z",
    ["Добавить по координатам"] = "Add by coordinates",
    ["Сохранённые точки:"] = "Saved spots:",
    ["Нет сохранённых точек"] = "No saved spots",
    ["Идти"] = "Go",
    ["Точка сохранена: "] = "Spot saved: ",
    ["Неверные координаты (нужно 3 или 12 чисел)"] = "Invalid coordinates (need 3 or 12 numbers)",
    ["Телепорт: "] = "Teleported: ",
    ["Точки задаёте только вы: координаты из файлов игры не читаются (риск оказаться в стене или под землёй)."] = "Spots are set by you only: coordinates are not read from game files (risk of ending up in a wall or underground).",
}

local function hasCyr(str) return str:find("[\208\209]") ~= nil end
local function escPat(str) return (str:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

local function tplToPattern(tpl)
    local pat, i, n = {}, 1, #tpl
    while i <= n do
        local c = tpl:sub(i, i)
        if c == "%" then
            local spec = tpl:match("^%%[%-%d%.]*[dsf]", i)
            if spec then
                local conv = spec:sub(-1)
                pat[#pat + 1] = (conv == "s" and "(.-)") or (conv == "d" and "(%-?%d+)") or "(%-?[%d%.]+)"
                i += #spec
            else
                pat[#pat + 1] = "%%"
                i += 1
            end
        else
            pat[#pat + 1] = escPat(c)
            i += 1
        end
    end
    return "^" .. table.concat(pat) .. "$"
end

local EN_TPL, EN_FRAG = {}, {}
for ru, en in pairs(EN) do
    if ru:find("%%[%-%d%.]*[dsf]") then
        EN_TPL[#EN_TPL + 1] = { pat = tplToPattern(ru), en = en }
    elseif #ru > 3 then
        EN_FRAG[#EN_FRAG + 1] = { ru = ru, en = en }
    end
end
table.sort(EN_FRAG, function(a, b) return #a.ru > #b.ru end)

local function replacePlain(str, from, to)
    local out, pos = {}, 1
    while true do
        local a, b = str:find(from, pos, true)
        if not a then break end
        out[#out + 1] = str:sub(pos, a - 1)
        out[#out + 1] = to
        pos = b + 1
    end
    out[#out + 1] = str:sub(pos)
    return table.concat(out)
end

local function L(str)
    if CFG.Lang ~= "EN" or type(str) ~= "string" or not hasCyr(str) then return str end
    local direct = EN[str]
    if direct and not str:find("%%[%-%d%.]*[dsf]") then return direct end
    for _, t in ipairs(EN_TPL) do
        local caps = { str:match(t.pat) }
        if #caps > 0 then
            for i, c in ipairs(caps) do
                if type(c) == "string" and hasCyr(c) then caps[i] = L(c) end
            end
            local ok, res = pcall(string.format, t.en, table.unpack(caps))
            if ok then return res end
        end
    end
    for _, f in ipairs(EN_FRAG) do
        if str:find(f.ru, 1, true) then str = replacePlain(str, f.ru, f.en) end
    end
    return str
end

-- ===================== СОСТОЯНИЕ =====================
local running, stopFlag = false, false
local dropCF = nil
local cleanupFn = nil
local toolOut = nil -- UUID инструмента, который достали мы
local statusLabel

local function setStatus(t)
    if statusLabel then statusLabel.Text = L(t) end
    print("[carrier]", t)
end

local function fireIdx(idx, data)
    local r = kids[tonumber(idx) or 0]
    if r then pcall(r.FireServer, r, data) end
end
local function handFire(key, data) fireIdx(CFG["Hand" .. key], data) end
local function toolFire(key, data) fireIdx(CFG["Tool" .. key], data) end
local function actRaw(uuid, name, data)
    toolFire("Act", { Name = name, UUID = uuid, Data = data })
end

-- ===================== ВСПОМОГАТЕЛЬНЫЕ (мир) =====================
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

local function flatDist(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function surfacePoint(item, fromPos, center)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { item }
    local hit = workspace:Raycast(fromPos, center - fromPos, rp)
    return hit and hit.Position or center
end

-- владелец: у "своего" предмета внутри лежит ObjectValue "Owner"
local function ownerState(item)
    local o = item:FindFirstChild("Owner")
    if not (o and o:IsA("ObjectValue")) or o.Value == nil then return "none" end
    return tostring(o.Value) == lp.Name and "me" or "other"
end

local function resolvePath(path)
    local cur = workspace
    for p in tostring(path):gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(p)
    end
    return cur
end

local function parseNames(s)
    local set = {}
    for n in tostring(s):gmatch("[^,]+") do
        n = n:match("^%s*(.-)%s*$")
        if n ~= "" then set[n] = true end
    end
    return set
end

local function tokenList(s)
    local out = {}
    for t in tostring(s or ""):gmatch("[^,]+") do
        t = t:match("^%s*(.-)%s*$"):lower()
        if t ~= "" then out[#out + 1] = t end
    end
    return out
end

-- нижняя точка детали по высоте (учитывает поворот)
local function bottomY(p)
    local cf, s = p.CFrame, p.Size
    local ext = (math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X
        + math.abs(cf.LookVector.Y) * s.Z) / 2
    return p.Position.Y - ext
end

-- дерево: самая нижняя деталь ствола; руда: ближайшая к игроку деталь
local function pickPart(node, from, kind)
    local best, bestKey
    for _, d in ipairs(node:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "FluffyLeaf" and d.Name ~= "SpawnLocation" then
            local key
            if kind == "tree" then
                key = math.floor(bottomY(d) + 0.5) * 1000 + (d.Position - from).Magnitude
            else
                key = (d.Position - from).Magnitude
            end
            if not bestKey or key < bestKey then best, bestKey = d, key end
        end
    end
    return best
end

-- точка удара: у дерева в ~1 студе над самым низом, у руды луч от игрока
local function aimPoint(p, from, kind)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { p }
    local origin, target
    if kind == "tree" then
        local y = bottomY(p) + CFG.TreeHitHeight
        origin = Vector3.new(from.X, y, from.Z)
        target = Vector3.new(p.Position.X, y, p.Position.Z)
    else
        origin, target = from, p.Position
    end
    local dir = target - origin
    if dir.Magnitude < 0.1 then return target end
    local hit = workspace:Raycast(origin, dir.Unit * (dir.Magnitude + 5), rp)
    return hit and hit.Position or target
end

local function nodeKindOf(part)
    local world = workspace:FindFirstChild("World")
    local tr = world and world:FindFirstChild("TreeRegions")
    local rr = world and world:FindFirstChild("RockRegions")
    if tr and part:IsDescendantOf(tr) then return "tree" end
    if rr and part:IsDescendantOf(rr) then return "rock" end
end

-- ===================== ЗАПИСЬ ДЕЙСТВИЙ (Grabby и удары) =====================
local function describeMacro(macro)
    local s = {}
    for _, e in ipairs(macro) do
        s[#s + 1] = ("%s(+%.2f с)"):format(e.kind, e.dt)
    end
    return table.concat(s, " -> ")
end

local function swingTime(macro)
    local t = 0
    for _, e in ipairs(macro) do t += e.dt end
    return t
end

env.TMHandler = function() end -- старый обработчик ToolMacro отключён, запись теперь здесь
env.CarrierKids = kids
env.CarrierIdx = { equip = CFG.ToolEquip, unequip = CFG.ToolUnequip, act = CFG.ToolAct }

env.CarrierRec = function(self, a)
    local I = env.CarrierIdx
    if self == kids[I.equip] then TM.lastKind = "equip" return end
    if self == kids[I.unequip] then TM.lastKind = "unequip" return end
    if self ~= kids[I.act] or type(a) ~= "table" then return end
    local d = a.Data
    if type(d) ~= "table" then return end
    local uuid = a.UUID and tostring(a.UUID)
    local now = os.clock()
    local ctx = TM.lastKind

    if d.Position ~= nil then
        GG.grab = { Name = a.Name }
        if uuid then GG.toolUuid = uuid end
        TM.lastKind = "grab"
    elseif d.CF ~= nil then
        GG.drop = { Name = a.Name }
        if uuid then GG.toolUuid = uuid end
        TM.lastKind = "drop"
    elseif d.HitPart ~= nil then
        if not uuid then return end
        local T = TM.tools[uuid]
        if not T then T = {} TM.tools[uuid] = T end
        -- У каждого инструмента своё имя основного действия: топор и кирка
        -- могут использовать разные action names, поэтому не делим их через TM.A.
        if T.A == nil then T.A = a.Name end
        local kind = (a.Name == T.A) and "A" or "C"
        if typeof(d.HitPart) == "Instance" then
            local nk = nodeKindOf(d.HitPart)
            if nk then
                TM.toolFor[nk] = uuid
                T.kinds = T.kinds or {}
                T.kinds[nk] = true
            end
        end
        TM.lastKind = kind
        if kind == "A" then
            if T.cur and #T.cur > 1 then
                T.macro = T.cur
                print(("[carrier] запомнил удар для %s: %s"):format(uuid, describeMacro(T.macro)))
            end
            T.cur = { { kind = "A", name = a.Name, hit = true, dt = 0 } }
            T.lastT = now
        elseif T.cur then
            T.cur[#T.cur + 1] = { kind = "C", name = a.Name, hit = true, dt = now - T.lastT }
            T.lastT = now
        end
    elseif next(d) == nil then
        if ctx == "equip" then
            TM.E = a.Name
            GG.stop_equip = { Name = a.Name }
        elseif ctx == "A" or ctx == "C" or ctx == "B" then
            local T = uuid and TM.tools[uuid]
            if T and T.cur then
                T.cur[#T.cur + 1] = { kind = "B", name = a.Name, hit = false, dt = now - T.lastT }
                T.lastT = now
            end
            TM.lastKind = "B"
            return
        elseif ctx == "grab" or ctx == "drop" or ctx == "unequip" then
            GG["stop_" .. ctx] = { Name = a.Name }
            GG.stop = { Name = a.Name }
        end
        TM.lastKind = "stop"
    end
end

if not env.CarrierHooked and hookmetamethod then
    env.CarrierHooked = true
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local K, I = env.CarrierKids, env.CarrierIdx
        if K and I and getnamecallmethod() == "FireServer"
            and (self == K[I.equip] or self == K[I.unequip] or self == K[I.act])
            and not (checkcaller and checkcaller()) then
            local a = ({ ... })[1]
            if type(a) ~= "table" then a = nil end
            task.spawn(env.CarrierRec, self, a)
        end
        return old(self, ...)
    end)
end

local function grabbyReady()
    return GG.toolUuid ~= nil and GG.grab ~= nil and GG.drop ~= nil and GG.stop ~= nil
end

-- действие Grabby по записанному названию
local function toolAct(key, data)
    local rec = GG[key] or GG.stop
    if not (rec and GG.toolUuid) then return false end
    actRaw(GG.toolUuid, rec.Name, data)
    return true
end

-- ===================== ИНСТРУМЕНТЫ =====================
local function unequipAllExcept(keep)
    local seen = {}
    for u in pairs(TM.tools) do seen[u] = true end
    if GG.toolUuid then seen[tostring(GG.toolUuid)] = true end
    for u in pairs(seen) do
        if u ~= keep then toolFire("Unequip", { UUID = u }) end
    end
end

local function equipTool(uuid)
    uuid = tostring(uuid)
    if toolOut == uuid then return end
    unequipAllExcept(uuid)
    task.wait(0.2)
    toolFire("Equip", { UUID = uuid })
    task.wait(0.15)
    local en = TM.E or (GG.stop_equip and GG.stop_equip.Name)
    if en then actRaw(uuid, en, {}) end
    task.wait(CFG.EquipWait)
    toolOut = uuid
end

local function unequipTool()
    if toolOut then
        toolFire("Unequip", { UUID = toolOut })
        if toolOut == tostring(GG.toolUuid) then toolAct("stop_unequip", {}) end
        toolOut = nil
    end
end

local function chooseTool(kind)
    local key = kind == "tree" and "TreeTool" or "RockTool"
    local u = tostring(CFG[key] or "")
    if u ~= "" and TM.tools[u] and TM.tools[u].macro then return u end
    local auto = TM.toolFor[kind]
    local autoRec = auto and TM.tools[auto]
    if autoRec and autoRec.macro and autoRec.kinds and autoRec.kinds[kind] then return auto end
end

-- ===================== ПРЕДМЕТЫ =====================
local function skipDistance()
    if CFG.Method == "Grabby" then
        return math.max(CFG.SkipNearDrop, CFG.FieldRadius + CFG.CarryForward + 6)
    end
    return CFG.SkipNearDrop
end

local function findItems(origin)
    local list = {}
    local folder = getFolder()
    local skipD = skipDistance()
    local names = parseNames(CFG.ItemName)
    local anyName = next(names) == nil

    if folder then
        for _, v in ipairs(folder:GetChildren()) do
            local nameOk = (anyName and v:GetAttribute("Draggable") == true) or names[v.Name]
            if nameOk and not v:GetAttribute("PlayerDragging")
                and v:GetAttribute("ActivelyDragging") ~= true
                and ownerState(v) ~= "other" then
                local ok, p = pcall(function() return v:GetPivot().Position end)
                if ok then
                    local d = (p - origin).Magnitude
                    if d > skipD and d <= CFG.MaxRange then
                        table.insert(list, { item = v, d = d })
                    end
                end
            end
        end
    end

    -- предметы без владельца (например, Shrub.Fruit.Blueberries)
    if CFG.Unowned then
        for rootPath in tostring(CFG.UnownedRoots):gmatch("[^,]+") do
            local root = resolvePath(rootPath:match("^%s*(.-)%s*$"))
            if root then
                for _, d in ipairs(root:GetDescendants()) do
                    if (d:IsA("Model") or d:IsA("BasePart"))
                        and d.Parent and d.Parent.Name == CFG.UnownedContainer
                        and (anyName or names[d.Name])
                        and ownerState(d) == "none"
                        and not (folder and d:IsDescendantOf(folder)) then
                        local ok, p = pcall(function() return d:GetPivot().Position end)
                        if ok then
                            local dist = (p - origin).Magnitude
                            if dist > skipD and dist <= CFG.MaxRange then
                                table.insert(list, { item = d, d = dist, unowned = true })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end

-- переместиться к точке (Teleport: сразу, Walk: пешком)
local function goTo(hrp, hum, pos, look)
    if CFG.Mode == "Teleport" then
        hrp.CFrame = look and CFrame.lookAt(pos, look) or CFrame.new(pos)
        task.wait(CFG.GrabDelay)
    else
        local t = os.clock()
        while (hrp.Position - pos).Magnitude > 3 and os.clock() - t < CFG.WalkTimeout and not stopFlag do
            hum:MoveTo(pos)
            task.wait(0.2)
        end
    end
end

-- подойти к предмету на дистанцию захвата
local function approach(hrp, hum, ip)
    if CFG.Mode == "Teleport" then
        local flat = Vector3.new(hrp.Position.X - ip.X, 0, hrp.Position.Z - ip.Z)
        flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
        hrp.CFrame = CFrame.new(ip + flat * CFG.GrabDistance + Vector3.new(0, CFG.TeleportUp, 0))
        task.wait(CFG.GrabDelay)
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
        -- Не используем бесконечную скорость: резкий разгон AlignPosition
        -- мог разбрасывать предметы при переносе/снятии ограничений.
        ap.MaxForce = math.huge
        ap.MaxVelocity = 45
        ap.Responsiveness = math.clamp(tonumber(CFG.CarryResponsiveness) or 25, 5, 35)
        ap.Parent = att

        local ao = Instance.new("AlignOrientation")
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.Attachment0 = att
        ao.CFrame = CFrame.new()
        ao.MaxTorque = math.huge
        ao.Responsiveness = CFG.CarryResponsiveness
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

-- Сбрасываем накопленную скорость после снятия AlignPosition/AlignOrientation.
-- Это не отменяет серверную проверку и не гарантирует фиксацию сервером.
local function stopItemVelocity(item)
    if not item or not item.Parent then return end
    local parts = {}
    if item:IsA("BasePart") then parts[1] = item end
    for _, d in ipairs(item:GetDescendants()) do
        if d:IsA("BasePart") then parts[#parts + 1] = d end
    end
    for _, part in ipairs(parts) do
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function stopEntriesVelocity(list)
    for _, entry in ipairs(list) do
        stopItemVelocity(entry.item)
    end
end

-- доставка: Teleport = сразу в точку и держим HoldTime, Walk = пешком
local function deliver(hrp, hum, magnets, held)
    if CFG.Mode == "Teleport" then
        hrp.CFrame = dropCF
        task.wait(0.03)
        local c = carryPos(hrp)
        for _, m in ipairs(magnets) do
            pcall(function()
                m.item:PivotTo(CFrame.new(c + m.off))
                stopItemVelocity(m.item)
            end)
        end
        task.wait(CFG.HoldTime)
    else
        local t1 = os.clock()
        while (hrp.Position - dropCF.Position).Magnitude > 4
            and os.clock() - t1 < CFG.WalkTimeout and not stopFlag do
            if not held() then return false, "предметы потеряны по пути" end
            hum:MoveTo(dropCF.Position)
            task.wait(0.25)
        end
        task.wait(0.5)
    end
    if not held() then return false, "сервер забрал предметы" end
    return true, "ok"
end

local function rolledBack(hrp)
    task.wait(CFG.RollbackCheck)
    return flatDist(hrp.Position, dropCF.Position) > CFG.RollbackDist
end

-- ----- метод: РУКА (один предмет) -----
-- схватить рукой и дождаться подтверждения; возвращает удерживаемый предмет
-- (после первого взятия бесхозный предмет может переехать в LooseItems как новый объект)
local function handGrab(item, hrp)
    local before = {}
    local loose = getFolder()
    if loose then
        for _, v in ipairs(loose:GetChildren()) do before[v] = true end
    end
    local c0 = item:GetPivot().Position
    handFire("Grab", { Object = item, WorldPos = surfacePoint(item, hrp.Position, c0) })
    handFire("Confirm", {})
    local t0 = os.clock()
    repeat
        task.wait(0.03)
        if item.Parent and item:GetAttribute("PlayerDragging") == lp.Name then
            return item
        elseif loose then
            for _, v in ipairs(loose:GetChildren()) do
                if not before[v] and v:GetAttribute("PlayerDragging") == lp.Name then return v end
            end
        end
    until os.clock() - t0 > CFG.GrabTimeout
    return nil
end

local function carryHand(item)
    local hrp, hum = getChar()
    if not hrp then return false, "нет персонажа" end
    local part = partOf(item)
    if not part then return false, "у предмета нет детали" end

    approach(hrp, hum, item:GetPivot().Position)
    if stopFlag then return false, "остановлено" end
    if not item.Parent then return false, "предмет исчез" end

    local held = handGrab(item, hrp)
    if not held then return false, "захват не принят (далеко?)" end

    -- предзахват: схватить, уронить на месте и только потом брать для переноса
    if CFG.PreGrab then
        task.wait(CFG.PreGrabHold)
        handFire("Confirm", {})
        handFire("Release", {})
        task.wait(CFG.PreGrabWait)
        if not held.Parent then return false, "предмет исчез после предзахвата" end
        -- ждём, пока сервер снимет метку "держит", чтобы не принять её за новый захват
        local tw = os.clock()
        while held.Parent and held:GetAttribute("PlayerDragging") == lp.Name and os.clock() - tw < 1.5 do
            task.wait(0.03)
        end
        item = held
        held = handGrab(item, hrp)
        if not held then return false, "повторный захват не принят" end
    end

    if held ~= item then
        print("[carrier] предмет заменён копией:", held:GetFullName())
        item = held
    end
    part = partOf(item)
    if not part then return false, "у предмета нет детали" end

    local magnets = startMagnets({ { item = item, part = part, off = Vector3.zero } })
    local conn = RunService.Heartbeat:Connect(function()
        local c = carryPos(hrp)
        updateMagnets(magnets, c)
        handFire("Move", { WorldPos = c })
    end)

    local released = false
    local function release()
        if released then return end
        released = true
        conn:Disconnect()
        destroyMagnets(magnets)
        stopEntriesVelocity(magnets)
        handFire("Confirm", {})
        handFire("Release", {})
        cleanupFn = nil
    end
    cleanupFn = release

    local ok, msg = deliver(hrp, hum, magnets, function()
        return item:GetAttribute("PlayerDragging") == lp.Name
    end)

    release()
    if ok and CFG.Mode == "Teleport" and rolledBack(hrp) then
        ok, msg = false, "античит вернул назад"
    end
    return ok, msg, { item }
end

-- В режиме Teleport временно фиксируем HRP при работе Grabby, чтобы физика
-- захваченных предметов/падение не сдвигали персонажа. Walk намеренно не фиксируется.
local function lockPlayerForGrabby(hrp, hum)
    if not CFG.FreezePlayerOnCarry or CFG.Mode ~= "Teleport" then
        return function() end
    end
    local wasAnchored = hrp.Anchored
    local wasAutoRotate = hum.AutoRotate
    local restored = false
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hum.AutoRotate = false
        hrp.Anchored = true
    end)
    return function()
        if restored then return end
        restored = true
        if hrp and hrp.Parent then
            pcall(function()
                hrp.Anchored = wasAnchored
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        if hum and hum.Parent then
            pcall(function() hum.AutoRotate = wasAutoRotate end)
        end
    end
end

-- ----- метод: GRABBY GRABBER (поле, много предметов) -----
local function carryGrabby(item)
    if not grabbyReady() then
        return false, "Grabby не записан: возьмите и поставьте предмет им вручную 1 раз"
    end
    local hrp, hum = getChar()
    if not hrp then return false, "нет персонажа" end
    local folder = getFolder()
    if not folder then return false, "нет LooseItems" end

    local before = {}
    for _, v in ipairs(folder:GetChildren()) do
        if v:GetAttribute("ActivelyDragging") == true then before[v] = true end
    end

    equipTool(GG.toolUuid) -- достаём заранее, чтобы после телепорта сразу брать
    if stopFlag then return false, "остановлено" end
    if not item.Parent then return false, "предмет исчез" end

    approach(hrp, hum, item:GetPivot().Position)
    if stopFlag then return false, "остановлено" end

    local restorePlayer = lockPlayerForGrabby(hrp, hum)
    local function restoreLockedPlayer()
        restorePlayer()
        if cleanupFn == restoreLockedPlayer then cleanupFn = nil end
    end
    cleanupFn = restoreLockedPlayer

    local pos
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

    -- схватить полем и дождаться пометки предметов
    local function grabOnce()
        local camPos = workspace.CurrentCamera.CFrame.Position
        pos = surfacePoint(item, camPos, item:GetPivot().Position)
        toolAct("grab", { Position = pos, CamCF = camPos })
        toolAct("stop_grab", {})
        local t0, found = os.clock(), {}
        repeat
            task.wait(0.03)
            found = field()
        until #found > 0 or os.clock() - t0 > CFG.GrabTimeout or stopFlag
        if #found > 0 then
            task.wait(0.15)
            found = field() -- добираем остальные предметы поля
        end
        return found
    end

    local list = grabOnce()
    if stopFlag then restoreLockedPlayer() return false, "остановлено" end

    -- предзахват: схватить, уронить на месте и только потом брать для переноса
    if #list > 0 and CFG.PreGrab then
        task.wait(CFG.PreGrabHold)
        if not item.Parent then item = list[1].item end -- бесхозный мог превратиться в копию
        toolAct("drop", { CF = CFrame.new(pos) })
        toolAct("stop_drop", {})
        local t1 = os.clock()
        repeat task.wait(0.05) until #field() == 0 or os.clock() - t1 > 1.5 or stopFlag
        if stopFlag then restoreLockedPlayer() return false, "остановлено" end
        task.wait(CFG.PreGrabWait)
        if not item.Parent then
            restoreLockedPlayer()
            return false, "предмет исчез после предзахвата"
        end
        list = grabOnce()
        if stopFlag then restoreLockedPlayer() return false, "остановлено" end
    end

    if #list == 0 then
        restoreLockedPlayer()
        if not CFG.KeepToolEquipped then unequipTool() end
        return false, "захват не принят (Grabby)"
    end

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
        task.wait(CFG.DropWait)
        conn:Disconnect()
        destroyMagnets(magnets)
        stopEntriesVelocity(magnets)
        restoreLockedPlayer()
        if cleanupFn == release then cleanupFn = nil end
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
    if not CFG.KeepToolEquipped then unequipTool() end

    if ok and CFG.Mode == "Teleport" and rolledBack(hrp) then
        ok, msg = false, "античит вернул назад"
    elseif ok then
        task.wait(0.4)
        local n = 0
        for _, m in ipairs(magnets) do
            local ok2, p = pcall(function() return m.part.Position end)
            if ok2 and (p - center).Magnitude <= CFG.FieldRadius + 6 then n += 1 end
        end
        msg = ("доставлено %d из %d"):format(n, #magnets)
        ok = n > 0
    end
    return ok, msg, moved
end

local function carryFn()
    return CFG.Method == "Grabby" and carryGrabby or carryHand
end

local function runItems()
    local delivered, trips, skipped = 0, 0, {}
    local lastMsg = "Готово"

    while not stopFlag and trips < CFG.MaxItems do
        local target
        for _, e in ipairs(findItems(dropCF.Position)) do
            if not skipped[e.item] then target = e.item break end
        end
        if not target then lastMsg = "Предметов не осталось" break end

        trips += 1
        setStatus(("Поездка %d/%d (%s)..."):format(trips, CFG.MaxItems, CFG.Method))

        local pc, ok, msg, moved = pcall(carryFn(), target)
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
            if msg == "античит вернул назад" and CFG.Mode == "Teleport" and CFG.AutoWalkFallback then
                CFG.Mode = "Walk"
                lastMsg = "Античит вернул назад, переключил на Walk"
            end
        end

        if not CFG.LoopAll then break end
        task.wait(CFG.Pause)
    end

    setStatus(("%s. Перенесено предметов: %d"):format(lastMsg, delivered))
end

-- ===================== ДЕРЕВЬЯ И РУДЫ =====================
local function nodeHay(node, kind)
    return table.concat({
        node.Name,
        tostring(node:GetAttribute(kind == "tree" and "TreeName" or "RockName") or ""),
        tostring(node:GetAttribute("AltName") or ""),
        tostring(node:GetAttribute("OreName") or ""),
    }, " "):lower()
end

-- требование силы удара из данных игры (ReplicatedStorage.INFO / ORE_INFO)
local function powerReq(node, kind)
    -- Отчёт ReplicatedStorageInspector показывает обычные материалы в ORE_INFO,
    -- а деревья и часть специальных целей — в INFO. Атрибуты имени могут отсутствовать,
    -- поэтому проверяем также TreeName/RockName и само имя модели.
    local info = RS:FindFirstChild("INFO")
    local oreInfo = RS:FindFirstChild("ORE_INFO")
    local names = {}
    local function addName(value)
        if value ~= nil then names[#names + 1] = tostring(value) end
    end
    addName(node:GetAttribute(kind == "tree" and "TreeName" or "RockName"))
    addName(node:GetAttribute("AltName"))
    addName(node:GetAttribute("OreName"))
    addName(node.Name)

    local seen = {}
    for _, name in ipairs(names) do
        if not seen[name] then
            seen[name] = true
            local cfgA = info and info:FindFirstChild(name)
            local cfgB = oreInfo and oreInfo:FindFirstChild(name)
            local first, second
            if kind == "rock" then first, second = cfgB, cfgA else first, second = cfgA, cfgB end
            if first and (first:GetAttribute("PowerRequirementType") ~= nil
                or first:GetAttribute("PowerRequirementMin") ~= nil) then
                return first:GetAttribute("PowerRequirementType"), first:GetAttribute("PowerRequirementMin")
            end
            if second and (second:GetAttribute("PowerRequirementType") ~= nil
                or second:GetAttribute("PowerRequirementMin") ~= nil) then
                return second:GetAttribute("PowerRequirementType"), second:GetAttribute("PowerRequirementMin")
            end
        end
    end
    return nil, nil
end

local function powerOk(node, kind)
    local t, mn = powerReq(node, kind)
    if t == nil then return true end
    local limit = kind == "tree" and CFG.TreeMaxPower or CFG.RockMaxPower
    if t == "Range" and type(mn) == "number" then return mn <= limit end
    return not CFG.SkipSpecial -- нужен конкретный инструмент
end

local function nodeSize(node)
    local ok, sz = pcall(function() return node:GetExtentsSize() end)
    return ok and (sz.X * sz.Y * sz.Z) or 0
end

local function findNodes(kind, from)
    local out = {}
    local world = workspace:FindFirstChild("World")
    local root = world and world:FindFirstChild(kind == "tree" and "TreeRegions" or "RockRegions")
    if not root then return out end
    local tokens = tokenList(kind == "tree" and CFG.TreeFilter or CFG.RockFilter)
    local regionTokens = tokenList(kind == "tree" and CFG.TreeRegion or CFG.RockRegion)
    local attr = kind == "tree" and "Choppable" or "Mineable"
    local order = kind == "tree" and CFG.TreeOrder or CFG.RockOrder
    local needSize = order ~= "Ближайшие"

    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("Model") and d:GetAttribute(attr) == true and ownerState(d) ~= "other" then
            local region = d
            while region.Parent and region.Parent ~= root do region = region.Parent end
            local okRegion = #regionTokens == 0
            for _, t in ipairs(regionTokens) do
                if region.Name:lower() == t then okRegion = true end
            end
            local hay = nodeHay(d, kind)
            local okName = #tokens == 0
            for _, t in ipairs(tokens) do
                if hay:find(t, 1, true) then okName = true end
            end
            if okRegion and okName and (kind ~= "rock" or not CFG.OreOnly or d:GetAttribute("OreName") ~= nil)
                and powerOk(d, kind) then
                local ok, p = pcall(function() return d:GetPivot().Position end)
                if ok then out[#out + 1] = { node = d, d = flatDist(p, from), size = needSize and nodeSize(d) or 0 } end
            end
        end
    end
    table.sort(out, function(a, b)
        if order == "Большие первыми" and a.size ~= b.size then return a.size > b.size end
        if order == "Малые первыми" and a.size ~= b.size then return a.size < b.size end
        return a.d < b.d
    end)
    return out
end

-- один узел: подойти, достать инструмент, бить до конца
local function harvestNode(node, kind)
    local hrp, hum = getChar()
    if not hrp then return false, "нет персонажа" end
    local uuid = chooseTool(kind)
    if not uuid then
        return false, "нет записи удара: ударьте вручную " .. (kind == "tree" and "дерево топором" or "руду киркой") .. " 2+ раза"
    end
    local T = TM.tools[uuid]

    local loose = getFolder()
    local before = {}
    if loose then
        for _, v in ipairs(loose:GetChildren()) do before[v] = true end
    end

    equipTool(uuid)
    if stopFlag then return false, "остановлено" end

    local part = pickPart(node, hrp.Position, kind)
    if not part then return false, "у цели нет деталей" end
    local base = part.Position
    local flat = Vector3.new(hrp.Position.X - base.X, 0, hrp.Position.Z - base.Z)
    flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
    local hitY = (kind == "tree") and (bottomY(part) + CFG.TreeHitHeight) or base.Y
    -- встаём СНАРУЖИ цели: луч от далёкой точки к центру находит её поверхность
    local center = Vector3.new(base.X, hitY, base.Z)
    local ext = node:GetExtentsSize()
    local reach = math.max(ext.X, ext.Z) / 2 + 12
    local rp0 = RaycastParams.new()
    rp0.FilterType = Enum.RaycastFilterType.Include
    rp0.FilterDescendantsInstances = { node }
    local far = center + flat * reach
    local res0 = workspace:Raycast(far, center - far, rp0)
    local surface = res0 and res0.Position or center
    local stand = Vector3.new(surface.X, surface.Y + CFG.StandHeight, surface.Z) + flat * CFG.StandDist
    local look = Vector3.new(surface.X, stand.Y, surface.Z)
    goTo(hrp, hum, stand, look)
    if stopFlag then return false, "остановлено" end

    local function newItems()
        local out = {}
        if loose then
            for _, v in ipairs(loose:GetChildren()) do
                if not before[v] then out[#out + 1] = v end
            end
        end
        return out
    end
    local function felled()
        if kind ~= "tree" then return false end
        for _, v in ipairs(newItems()) do
            if v.Name == "LooseTree" then return true end
        end
        return false
    end

    local swings, why = 0, "лимит ударов"
    while not stopFlag and swings < CFG.SwingLimit do
        if not node.Parent then why = "цель уничтожена" break end
        if felled() then why = "дерево срублено" break end
        if not hrp.Parent then return false, "персонаж пропал" end
        swings += 1

        local p = pickPart(node, hrp.Position, kind)
        if not p then why = "нет деталей" break end
        local pos = aimPoint(p, hrp.Position, kind)
        for _, e in ipairs(T.macro) do
            local w = e.dt + ((e.kind == "B") and CFG.SwingExtra or 0) -- запас на полный заряд удара
            if w > 0 then task.wait(w) end
            actRaw(uuid, e.name, e.hit and { HitPart = p, HitPosition = pos } or {})
        end
        task.wait(CFG.SwingGap)
    end

    task.wait(CFG.CollectDelay)
    local items = newItems()
    return why ~= "лимит ударов" or #items > 0, ("%s, ударов: %d"):format(why, swings), items
end

-- перенести предметы после добычи (Grabby: полем, Рука: по одному)
local function collectItems(items, kind)
    if CFG.Method == "Grabby" and not grabbyReady() then
        setStatus("Сбор пропущен: Grabby не записан (возьмите и поставьте предмет им вручную)")
        return 0
    end
    local pending = {}
    for _, v in ipairs(items) do
        if v.Parent then pending[#pending + 1] = v end
    end
    if kind == "tree" then
        table.sort(pending, function(a, b) return (a.Name == "LooseTree") and (b.Name ~= "LooseTree") end)
    end

    local delivered, guard = 0, 0
    while #pending > 0 and not stopFlag and guard < 30 do
        guard += 1
        local target = table.remove(pending, 1)
        if target.Parent then
            setStatus(("Сбор: осталось %d..."):format(#pending + 1))
            local pc, ok, msg, moved = pcall(carryFn(), target)
            if not pc then
                if cleanupFn then pcall(cleanupFn) end
            end
            if moved then
                local gone = {}
                for _, m in ipairs(moved) do gone[m] = true end
                for i = #pending, 1, -1 do
                    if gone[pending[i]] then table.remove(pending, i) end
                end
            end
            if pc and ok then delivered += moved and #moved or 1 end
            if pc and not ok and msg == "античит вернул назад" and CFG.Mode == "Teleport" and CFG.AutoWalkFallback then
                CFG.Mode = "Walk"
            end
        end
    end
    return delivered
end

local function runNodes(kind)
    local hrp = getChar()
    if not hrp then setStatus("Нет персонажа") return end
    local maxN = kind == "tree" and CFG.TreeMax or CFG.RockMax
    local collect = kind == "tree" and CFG.TreeCollect or CFG.RockCollect
    local nodes = findNodes(kind, hrp.Position)
    if #nodes == 0 then setStatus("Целей не найдено (проверьте фильтры и регионы)") return end

    local done, delivered = 0, 0
    for _, n in ipairs(nodes) do
        if stopFlag or done >= maxN then break end
        if n.node.Parent then
            setStatus(("%s %d/%d (до цели %.0f)..."):format(kind == "tree" and "Дерево" or "Руда", done + 1, maxN, n.d))
            local pc, ok, msg, items = pcall(harvestNode, n.node, kind)
            if not pc then
                ok, msg = false, tostring(ok)
            end
            if ok then
                done += 1
                setStatus(tostring(msg))
                if collect and items and #items > 0 then
                    delivered += collectItems(items, kind)
                end
            else
                setStatus("Ошибка: " .. tostring(msg))
                if not pc or msg:find("нет записи") then break end
            end
            task.wait(CFG.Pause)
        end
    end
    setStatus(("Готово: целей %d, перенесено предметов %d"):format(done, delivered))
end

-- ===================== ЗАПУСК РАБОТЫ =====================
-- перенос одного выбранного нажатием предмета (Grabby: вместе с полем)
local function runTap(item)
    if not (item and item.Parent) then setStatus("Предмет пропал") return end
    setStatus("Несу выбранный предмет: " .. item.Name)
    local pc, ok, msg, moved = pcall(carryFn(), item)
    if not pc then
        ok, msg = false, tostring(ok)
        if cleanupFn then pcall(cleanupFn) end
    end
    if ok then
        setStatus(("Готово: %s (предметов: %d)"):format(tostring(msg), moved and #moved or 1))
    else
        setStatus("Ошибка: " .. tostring(msg))
        if msg == "античит вернул назад" and CFG.Mode == "Teleport" and CFG.AutoWalkFallback then
            CFG.Mode = "Walk"
            setStatus("Античит вернул назад, переключил на Walk")
        end
    end
end

local updateStart -- задаётся в блоке GUI


-- ===================== ПОИСК РЕДКИХ ПРЕДМЕТОВ =====================
-- Детектор использует только уже видимые клиенту объекты/атрибуты.
-- Никакие неизвестные RemoteEvent/RemoteFunction здесь не вызываются.
local RARE = {
    shinyTrees = true, shinyOres = true, goldenApple = true,
    blueStars = true, purpleStars = true,
    blueFireflies = true, purpleFireflies = true,
    ghosts = true, ghostFireflies = true,
}
local rareMode = "Игрок к цели"
local rareMapLoading = true
local rareBusy = false
local rareCandidates, rareCandidateSet = {}, setmetatable({}, { __mode = "k" })
local rareSeen = setmetatable({}, { __mode = "k" })
local rareDescConn
local rareScanStarted = false

local function rareHasWord(s, ...)
    s = tostring(s or ""):lower():gsub("[%s_%-]", "")
    for i = 1, select("#", ...) do
        local word = tostring(select(i, ...)):lower():gsub("[%s_%-]", "")
        if word ~= "" and s:find(word, 1, true) then return true end
    end
    return false
end

local function rareAttrText(inst)
    local bits = { inst.Name }
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if ok and type(attrs) == "table" then
        for k, v in pairs(attrs) do
            bits[#bits + 1] = tostring(k)
            bits[#bits + 1] = tostring(v)
        end
    end
    return table.concat(bits, " ")
end

local function rareIsCandidate(inst)
    if not inst or not inst.Parent then return false end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return false end
    if inst:GetAttribute("Draggable") == true
        or inst:GetAttribute("TreeName") ~= nil
        or inst:GetAttribute("OreName") ~= nil
        or inst:GetAttribute("Choppable") == true
        or inst:GetAttribute("Mineable") == true
        or inst:GetAttribute("Style") ~= nil then
        return true
    end
    local t = rareAttrText(inst):lower()
    return rareHasWord(t, "goldenapple", "goldapple", "shiny", "glowworm", "firefly", "ghost", "star")
        and not rareHasWord(t, "ghosttoolupgrade")
end

local function rareAddCandidate(inst)
    if rareIsCandidate(inst) and not rareCandidateSet[inst] then
        rareCandidateSet[inst] = true
        rareCandidates[#rareCandidates + 1] = inst
    end
end

local function rareTextDeep(inst, inspectDeep)
    local bits = { rareAttrText(inst) }
    if inspectDeep and inst:IsA("Model") then
        local ok, descendants = pcall(function() return inst:GetDescendants() end)
        if ok then
            for _, d in ipairs(descendants) do
                bits[#bits + 1] = d.Name
                local aok, attrs = pcall(function() return d:GetAttributes() end)
                if aok and type(attrs) == "table" then
                    for k, v in pairs(attrs) do
                        bits[#bits + 1] = tostring(k)
                        bits[#bits + 1] = tostring(v)
                    end
                end
            end
        end
    end
    return table.concat(bits, " "):lower()
end

local function rareCategory(inst)
    if not inst or not inst.Parent then return nil end
    local isTree = inst:GetAttribute("TreeName") ~= nil or inst:GetAttribute("Choppable") == true
    local isOre = inst:GetAttribute("OreName") ~= nil or inst:GetAttribute("Mineable") == true
    local needsDeep = isTree or isOre or rareHasWord(inst.Name, "apple", "star", "glowworm", "firefly", "ghost")
    local txt = rareTextDeep(inst, needsDeep)
    local compact = txt:gsub("[%s_%-]", "")
    local blue = rareHasWord(compact, "blue", "azure")
    local purple = rareHasWord(compact, "purple", "violet")
    local ghost = rareHasWord(compact, "ghost", "specter", "spectre")
    local fly = rareHasWord(compact, "glowworm", "firefly", "fireflies", "glowworm")
    local star = rareHasWord(compact, "star")
    local shiny = rareHasWord(compact, "shiny")
    local apple = rareHasWord(compact, "goldenapple", "goldapple")
        or (rareHasWord(compact, "golden") and rareHasWord(compact, "apple"))

    if isTree and shiny and RARE.shinyTrees then return "Shiny дерево", inst end
    if isOre and shiny and RARE.shinyOres then return "Shiny руда", inst end
    if apple and RARE.goldenApple then return "Золотое яблоко", inst end
    if ghost and fly and RARE.ghostFireflies then return "Призрачный светлячок", inst end
    if ghost and not fly and (blue or purple) and RARE.ghosts then
        return purple and "Фиолетовый призрак" or "Синий призрак", inst
    end
    if fly and not ghost and blue and RARE.blueFireflies then return "Синий светлячок", inst end
    if fly and not ghost and purple and RARE.purpleFireflies then return "Фиолетовый светлячок", inst end
    if star and blue and RARE.blueStars then return "Синяя звезда", inst end
    if star and purple and RARE.purpleStars then return "Фиолетовая звезда", inst end
    return nil
end

local function rareNotify(message)
    setStatus(message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Carrier — редкая находка",
            Text = tostring(message),
            Duration = 8,
        })
    end)
end

local function rarePosition(inst)
    local ok, pos = pcall(function()
        if inst:IsA("Model") then return inst:GetPivot().Position end
        if inst:IsA("BasePart") then return inst.Position end
    end)
    if ok then return pos end
    return nil
end

local function rareTeleportPlayer(inst, label)
    local hrp = getChar()
    local pos = rarePosition(inst)
    if not hrp or not pos then return false end
    rareBusy = true
    local ok = pcall(function()
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0))
    end)
    if ok then rareNotify("Найдено: " .. label .. " — переместил игрока к цели") end
    task.wait(1)
    rareBusy = false
    return ok
end

local function rareHandle(inst, label)
    if rareBusy or not inst or not inst.Parent then return end
    rareBusy = true
    rareNotify("Найдено: " .. label)
    if rareMode == "Предмет к игроку" and inst:GetAttribute("Draggable") == true then
        local ok, result, msg = pcall(function() return carryFn()(inst) end)
        if not ok then
            rareNotify("Цель найдена, перенос предмета не сработал; перемещаю игрока")
            rareBusy = false
            rareTeleportPlayer(inst, label)
            return
        end
        if result then
            setStatus("Перенесено: " .. label)
        else
            rareNotify("Перенос не удался (" .. tostring(msg) .. "); перемещаю игрока")
            rareBusy = false
            rareTeleportPlayer(inst, label)
            return
        end
    else
        local pos = rarePosition(inst)
        local hrp = getChar()
        if pos and hrp then
            pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end)
        end
    end
    task.wait(1)
    rareBusy = false
end

local function rareTreeCountAndFarthest(origin)
    local world = workspace:FindFirstChild("World")
    local root = world and world:FindFirstChild("TreeRegions")
    if not root then return 0, nil end
    local count, best, bestDist = 0, nil, -1
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("Model") and d:GetAttribute("Choppable") == true then
            count += 1
            local ok, cf, size = pcall(function() return d:GetPivot(), d:GetExtentsSize() end)
            if ok and cf then
                local dist = (cf.Position - origin.Position).Magnitude
                if dist > bestDist then best, bestDist = { model = d, cf = cf, size = size }, dist end
            end
        end
    end
    return count, best
end

local function rareMapLoadLoop(startCF)
    while not stopFlag and running do
        if rareMapLoading and not rareBusy then
            local hrp = getChar()
            if hrp then
                local count, far = rareTreeCountAndFarthest(startCF)
                if far and far.model and far.model.Parent then
                    rareBusy = true
                    local targetPos = far.cf.Position + Vector3.new(0, (far.size and far.size.Y or 0) / 2 + 20, 0)
                    pcall(function() hrp.CFrame = CFrame.new(targetPos) end)
                    setStatus("Загрузка карты: над самым дальним загруженным деревом")
                    local lastCount, stableFor, elapsed = count, 0, 0
                    while not stopFlag and running and elapsed < 25 do
                        task.wait(1)
                        elapsed += 1
                        local nowCount = select(1, rareTreeCountAndFarthest(startCF))
                        if nowCount == lastCount then stableFor += 1 else
                            stableFor, lastCount = 0, nowCount
                        end
                        if stableFor >= 5 then break end
                    end
                    hrp = getChar()
                    if hrp and not stopFlag then
                        pcall(function() hrp.CFrame = startCF end)
                        setStatus("Карта загружена настолько, насколько доступно; вернулся в начальную точку")
                    end
                    rareBusy = false
                end
            end
        end
        -- Пятиминутный интервал между циклами загрузки.
        for _ = 1, 300 do
            if stopFlag or not running then break end
            task.wait(1)
        end
    end
end

local function runRareSearch()
    local hrp = getChar()
    if not hrp then setStatus("Нет персонажа") return end
    local startCF = hrp.CFrame
    rareCandidates, rareCandidateSet = {}, setmetatable({}, { __mode = "k" })
    rareSeen = setmetatable({}, { __mode = "k" })
    for _, d in ipairs(workspace:GetDescendants()) do rareAddCandidate(d) end
    if rareDescConn then pcall(function() rareDescConn:Disconnect() end) end
    rareDescConn = workspace.DescendantAdded:Connect(function(d)
        rareAddCandidate(d)
        local p = d.Parent
        while p and p ~= workspace do
            if p:IsA("Model") then rareAddCandidate(p) end
            p = p.Parent
        end
    end)

    if rareMapLoading then task.spawn(rareMapLoadLoop, startCF) end
    setStatus("Поиск редких предметов запущен; проверяю новые объекты постоянно")
    while not stopFlag do
        for i = #rareCandidates, 1, -1 do
            if stopFlag then break end
            local inst = rareCandidates[i]
            if not inst or not inst.Parent then
                table.remove(rareCandidates, i)
                if inst then rareCandidateSet[inst] = nil end
            elseif not rareBusy and not rareSeen[inst] then
                local label = rareCategory(inst)
                if label then
                    rareSeen[inst] = true
                    task.spawn(rareHandle, inst, label)
                    task.wait(0.15)
                end
            end
        end
        task.wait(1)
    end
    if rareDescConn then pcall(function() rareDescConn:Disconnect() end); rareDescConn = nil end
    rareBusy = false
    setStatus("Поиск редких предметов остановлен")
end

local function runJob(kind, arg)
    if running then return end
    local hrp = getChar()
    if not hrp then setStatus("Нет персонажа") return end
    running, stopFlag = true, false
    updateStart()
    if not dropCF then
        dropCF = hrp.CFrame
        setStatus("Точка выгрузки: текущее место")
    end

    local ok, err = pcall(function()
        if kind == "rare" then
            runRareSearch()
        elseif kind == "items" then
            runItems()
        elseif kind == "tap" then
            runTap(arg)
        else
            runNodes(kind == "trees" and "tree" or "rock")
        end
    end)
    if not ok then
        setStatus("Ошибка: " .. tostring(err))
        if cleanupFn then pcall(cleanupFn) end
    end
    pcall(unequipTool)
    running = false
    updateStart()
end

-- ===================== ПРОФИЛИ =====================
local PROFILE_FILE = "CarrierProfiles.json"
local canFile = (writefile ~= nil) and (readfile ~= nil)
local profiles = env.CarrierProfiles or {}

local function loadProfilesFromDisk()
    if canFile then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(PROFILE_FILE)) end)
        if ok and type(data) == "table" then profiles = data end
    end
    env.CarrierProfiles = profiles
end

local function saveProfilesToDisk()
    env.CarrierProfiles = profiles
    if canFile then
        pcall(function() writefile(PROFILE_FILE, HttpService:JSONEncode(profiles)) end)
    end
end

local locations = env.CarrierLocations or {}
env.CarrierLocations = locations

local function snapshot()
    local data = {}
    data._locations = locations
    for _, s in ipairs(S) do data[s.key] = CFG[s.key] end
    if dropCF then
        local p = dropCF.Position
        data._drop = { p.X, p.Y, p.Z }
    end
    return data
end

local function applySnapshot(data)
    for _, s in ipairs(S) do
        local v = data[s.key]
        if v ~= nil and type(v) == type(s.default) then CFG[s.key] = v end
    end
    if type(data._drop) == "table" and #data._drop == 3 then
        dropCF = CFrame.new(data._drop[1], data._drop[2], data._drop[3])
    end
    if type(data._locations) == "table" then
        for k in pairs(locations) do locations[k] = nil end
        for k, v in pairs(data._locations) do locations[k] = v end
    end
    env.CarrierIdx = { equip = CFG.ToolEquip, unequip = CFG.ToolUnequip, act = CFG.ToolAct }
end

-- ===================== GUI =====================
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
for _, n in ipairs({ "FlowerCarrierGui", "FlowerCarrierToggle" }) do
    local o = guiParent:FindFirstChild(n)
    if o then o:Destroy() end
end

local W, H = 280, 250
local gui = mk("ScreenGui", { Name = "FlowerCarrierGui", ResetOnSpawn = false }, guiParent)
local toggleGui = mk("ScreenGui", { Name = "FlowerCarrierToggle", ResetOnSpawn = false }, guiParent)

-- перевод всех подписей окна (RU <-> EN); поля ввода не трогаем
local function localizeAll()
    local en = CFG.Lang == "EN"
    for _, root in ipairs({ gui, toggleGui }) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local txt = d.Text
                if en then
                    if hasCyr(txt) then
                        d:SetAttribute("ru", txt)
                        d.Text = L(txt)
                    end
                else
                    local ru = d:GetAttribute("ru")
                    if ru ~= nil then
                        if not hasCyr(txt) then d.Text = ru end
                        d:SetAttribute("ru", nil)
                    end
                end
            end
        end
    end
end

local frame = mk("Frame", {
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0, 10, 0, 56),
    BackgroundColor3 = Color3.fromRGB(28, 28, 36),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
local uiScale = mk("UIScale", { Scale = 1 }, frame)

local title = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(45, 45, 60),
    Text = "  Carrier v8b",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, title)

local body = mk("Frame", {
    Position = UDim2.new(0, 0, 0, 28),
    Size = UDim2.new(1, 0, 1, -28),
    BackgroundTransparency = 1,
}, frame)

-- перетаскивание
local function makeDraggable(handle, target)
    local state = { moved = false }
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, target.Position
            state.moved = false
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            if d.Magnitude > 8 then state.moved = true end
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    return state
end
makeDraggable(title, frame)

-- кнопка показа/скрытия окна
local toggleBtn = mk("TextButton", {
    Size = UDim2.fromOffset(46, 30),
    Position = UDim2.new(1, -56, 0.5, -15),
    BackgroundColor3 = Color3.fromRGB(45, 45, 60),
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    Text = "Меню",
}, toggleGui)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, toggleBtn)
local toggleState = makeDraggable(toggleBtn, toggleBtn)
toggleBtn.Activated:Connect(function()
    if toggleState.moved then toggleState.moved = false return end
    frame.Visible = not frame.Visible
end)

local minimized = false
local resizeHandle
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
mkMiniBtn("X", -28, function() frame.Visible = false end) -- скрыть (вернуть кнопкой "Меню")
mkMiniBtn("-", -56, function()
    minimized = not minimized
    body.Visible = not minimized
    frame.Size = UDim2.fromOffset(W, minimized and 28 or H)
    resizeHandle.Visible = not minimized
end)
local refreshAll -- forward declaration used by settings refresh

-- вкладки
local TABS = {
    { id = "items", name = "Предметы" },
    { id = "trees", name = "Деревья" },
    { id = "rocks", name = "Руды" },
    { id = "tp", name = "Телепорт" },
    { id = "rare", name = "Поиск редких предметов" },
    { id = "adv", name = "Настр." },
}
local pages, tabButtons = {}, {}
local currentTab = "items"
local startBtn

local tabBar = mk("ScrollingFrame", {
    Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(1, -12, 0, 22),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollingDirection = Enum.ScrollingDirection.X,
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarImageColor3 = Color3.fromRGB(110, 110, 150),
}, body)
local tabLayout = mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 3),
}, tabBar)

statusLabel = mk("TextLabel", {
    Position = UDim2.new(0, 6, 0, 26), Size = UDim2.new(1, -12, 0, 26),
    BackgroundTransparency = 1, Text = "Готов",
    TextColor3 = Color3.fromRGB(150, 220, 160), Font = Enum.Font.Gotham, TextSize = 11,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, body)

local picker
local function closePicker()
    if picker then
        picker:Destroy()
        picker = nil
    end
end

local function showTab(id)
    currentTab = id
    closePicker()
    for tid, pg in pairs(pages) do pg.Visible = (tid == id) end
    for tid, b in pairs(tabButtons) do
        b.BackgroundColor3 = (tid == id) and Color3.fromRGB(80, 80, 130) or Color3.fromRGB(45, 45, 60)
    end
    if updateStart then updateStart() end
end

for i, t in ipairs(TABS) do
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(t.id == "rare" and 132 or 72, 19),
        BackgroundColor3 = Color3.fromRGB(45, 45, 60),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium, TextSize = 9, Text = t.name,
        LayoutOrder = i,
    }, tabBar)
    mk("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
    b.Activated:Connect(function() showTab(t.id) end)
    tabButtons[t.id] = b

    local pg = mk("ScrollingFrame", {
        Position = UDim2.new(0, 6, 0, 54), Size = UDim2.new(1, -12, 0, 126),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
    }, body)
    mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, pg)
    mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, pg)
    pages[t.id] = pg
end

startBtn = mk("TextButton", {
    Position = UDim2.new(0, 6, 0, 184), Size = UDim2.new(1, -12, 0, 32),
    BackgroundColor3 = Color3.fromRGB(40, 110, 60), TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 13, Text = "Старт",
}, body)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, startBtn)

-- Изменение реального размера окна перетаскиванием нижнего правого угла.
-- W/H хранят базовый размер; UIScale (если пользователь включил его в настройках)
-- учитывается при расчёте перемещения указателя.
resizeHandle = mk("TextButton", {
    Name = "ResizeHandle",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 0, 1, 0),
    Size = UDim2.fromOffset(20, 20),
    BackgroundColor3 = Color3.fromRGB(55, 55, 72),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Text = "◢",
    TextColor3 = Color3.fromRGB(210, 210, 230),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    AutoButtonColor = false,
    ZIndex = 20,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 5) }, resizeHandle)

local resizing, resizeInput, resizeStart, resizeW, resizeH = false, nil, nil, W, H
local function applyWindowSize(newW, newH)
    local scale = math.max(0.1, tonumber(uiScale.Scale) or 1)
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(900, 700)
    local maxW = math.max(260, math.min(720, math.floor(viewport.X / scale - 20)))
    local maxH = math.max(220, math.min(620, math.floor(viewport.Y / scale - 80)))
    W = math.clamp(math.floor(newW + 0.5), 260, maxW)
    H = math.clamp(math.floor(newH + 0.5), 220, maxH)
    frame.Size = UDim2.fromOffset(W, minimized and 28 or H)
    for _, pg in pairs(pages) do
        pg.Size = UDim2.new(1, -12, 0, math.max(80, H - 124))
    end
    startBtn.Position = UDim2.new(0, 6, 0, H - 66)
    resizeHandle.Visible = not minimized
end

resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeInput = input.UserInputType
        resizeStart = input.Position
        resizeW, resizeH = W, H
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing, resizeInput = false, nil
            end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if not resizing then return end
    local isPointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
        or (resizeInput == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch)
    if not isPointerMove then return end
    local delta = input.Position - resizeStart
    local scale = math.max(0.1, tonumber(uiScale.Scale) or 1)
    applyWindowSize(resizeW + delta.X / scale, resizeH + delta.Y / scale)
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or (resizeInput == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch) then
        resizing, resizeInput = false, nil
    end
end)

updateStart = function()
    if running then
        startBtn.Text = "Стоп"
        startBtn.BackgroundColor3 = Color3.fromRGB(130, 50, 50)
    else
        local names = { items = "Старт: предметы", trees = "Старт: деревья", rocks = "Старт: руды",
            adv = "Старт (откройте вкладку)", tp = "Старт (откройте вкладку)",
            rare = "Старт: поиск редкого" }
        startBtn.Text = names[currentTab] or "Старт"
        startBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 60)
    end
end

startBtn.Activated:Connect(function()
    if running then
        stopFlag = true
        setStatus("Останавливаю...")
        return
    end
    if currentTab == "adv" or currentTab == "tp" then
        setStatus("Откройте вкладку Предметы, Деревья или Руды")
        return
    end
    task.spawn(runJob, currentTab)
end)

-- строители строк
local orders = {}
local function nextOrder(page)
    orders[page] = (orders[page] or 0) + 1
    return orders[page]
end

local refreshers, live = {}, {}
refreshAll = function()
    for _, r in ipairs(refreshers) do pcall(r) end
end

local function mkBtn(page, text, cb)
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(55, 55, 72),
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, TextSize = 12,
        Text = text, LayoutOrder = nextOrder(page),
    }, page)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    b.Activated:Connect(function() cb(b) localizeAll() end)
    return b
end

local function mkLabel(page, text, color, h)
    return mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, h or 18), BackgroundTransparency = 1, Text = text,
        TextColor3 = color or Color3.fromRGB(170, 170, 200), Font = Enum.Font.GothamMedium, TextSize = 11,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(page),
    }, page)
end

local function mkInput(page, label, get, set, isNumber)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = nextOrder(page),
    }, page)
    mk("TextLabel", {
        Size = UDim2.new(0.56, 0, 1, 0), BackgroundTransparency = 1, Text = label,
        TextColor3 = Color3.fromRGB(210, 210, 220), Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
    }, row)
    local box = mk("TextBox", {
        Position = UDim2.new(0.58, 0, 0, 0), Size = UDim2.new(0.42, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 54), TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, Text = tostring(get()),
    }, row)
    mk("UICorner", { CornerRadius = UDim.new(0, 5) }, box)
    box.FocusLost:Connect(function()
        if isNumber then
            local v = tonumber(box.Text)
            if v then set(v) else box.Text = tostring(get()) end
        else
            set(box.Text)
        end
    end)
    refreshers[#refreshers + 1] = function() box.Text = tostring(get()) end
    return box
end

local function onChanged(s)
    if s.key == "GuiScale" then
        uiScale.Scale = math.clamp(tonumber(CFG.GuiScale) or 1, 0.5, 2)
    end
    if s.key == "ToolEquip" or s.key == "ToolUnequip" or s.key == "ToolAct" then
        env.CarrierIdx = { equip = CFG.ToolEquip, unequip = CFG.ToolUnequip, act = CFG.ToolAct }
    end
end

local function addSetting(page, s)
    if s.type == "bool" then
        local b
        local function r() b.Text = s.label .. ": " .. (CFG[s.key] and "ДА" or "НЕТ") end
        b = mkBtn(page, "", function()
            CFG[s.key] = not CFG[s.key]
            r()
            onChanged(s)
        end)
        r()
        refreshers[#refreshers + 1] = r
    elseif s.type == "enum" then
        local b
        local function r() b.Text = s.label .. ": " .. tostring(CFG[s.key]) end
        b = mkBtn(page, "", function()
            local idx = 1
            for i, o in ipairs(s.opts) do
                if o == CFG[s.key] then idx = i end
            end
            CFG[s.key] = s.opts[(idx % #s.opts) + 1]
            r()
            onChanged(s)
        end)
        r()
        refreshers[#refreshers + 1] = r
    else
        mkInput(page, s.label, function() return CFG[s.key] end, function(v)
            CFG[s.key] = v
            onChanged(s)
        end, s.type == "num")
    end
end

local function addDropButton(page)
    mkBtn(page, "Точка выгрузки = здесь", function()
        local hrp = getChar()
        if hrp then
            dropCF = hrp.CFrame
            setStatus("Точка выгрузки сохранена")
        end
    end)
end

-- ----- списки выбора (из мира и из ReplicatedStorage) -----
local function sortedOptions(counts, extra)
    local list = {}
    for name, n in pairs(counts) do list[#list + 1] = { name = name, count = n, extra = extra and extra[name] } end
    table.sort(list, function(a, b)
        if (a.count > 0) ~= (b.count > 0) then return a.count > 0 end
        return a.name:lower() < b.name:lower()
    end)
    return list
end

local function optionsItems()
    local counts = {}
    local folder = getFolder()
    if folder then
        for _, v in ipairs(folder:GetChildren()) do
            if v:GetAttribute("Draggable") == true then counts[v.Name] = (counts[v.Name] or 0) + 1 end
        end
    end
    for rootPath in tostring(CFG.UnownedRoots):gmatch("[^,]+") do
        local root = resolvePath(rootPath:match("^%s*(.-)%s*$"))
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if (d:IsA("Model") or d:IsA("BasePart")) and d.Parent and d.Parent.Name == CFG.UnownedContainer then
                    counts[d.Name] = (counts[d.Name] or 0) + 1
                end
            end
        end
    end
    return sortedOptions(counts)
end

local function optionsNodes(kind)
    local counts = {}
    local extraReq = {}
    local world = workspace:FindFirstChild("World")
    local root = world and world:FindFirstChild(kind == "tree" and "TreeRegions" or "RockRegions")
    local attr = kind == "tree" and "Choppable" or "Mineable"
    if root then
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("Model") and d:GetAttribute(attr) == true then
                local nm = d:GetAttribute(kind == "tree" and "TreeName" or "RockName")
                if nm then counts[tostring(nm)] = (counts[tostring(nm)] or 0) + 1 end
                local ore = d:GetAttribute("OreName")
                if ore then counts[tostring(ore)] = (counts[tostring(ore)] or 0) + 1 end
            end
        end
    end
    if kind == "rock" then
        -- названия всех руд из данных игры (ReplicatedStorage.ORE_INFO)
        local oreInfo = RS:FindFirstChild("ORE_INFO")
        if oreInfo then
            for _, c in ipairs(oreInfo:GetChildren()) do
                local mn = c:GetAttribute("PowerRequirementMin")
                if type(mn) == "number" then extraReq[c.Name] = " [P" .. mn .. "+]" end
                if counts[c.Name] == nil then counts[c.Name] = 0 end
            end
        end
    end
    return sortedOptions(counts, extraReq)
end

local function csvHas(csv, name, exact)
    for t in tostring(csv):gmatch("[^,]+") do
        t = t:match("^%s*(.-)%s*$")
        if (exact and t == name) or (not exact and t:lower() == name:lower()) then return true end
    end
    return false
end

local function csvToggle(csv, name, exact)
    local list, found = {}, false
    for t in tostring(csv):gmatch("[^,]+") do
        t = t:match("^%s*(.-)%s*$")
        if t ~= "" then
            local same = (exact and t == name) or (not exact and t:lower() == name:lower())
            if same then found = true else list[#list + 1] = t end
        end
    end
    if not found then list[#list + 1] = name end
    return table.concat(list, ", "), not found
end

local function openPicker(titleText, getOptions, getCsv, setCsv, exact)
    closePicker()
    picker = mk("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(24, 24, 32),
        BorderSizePixel = 0, ZIndex = 10, Active = true,
    }, body)
    mk("TextLabel", {
        Position = UDim2.new(0, 8, 0, 2), Size = UDim2.new(1, -16, 0, 20), BackgroundTransparency = 1,
        Text = titleText .. ": нажмите, чтобы выбрать", TextColor3 = Color3.fromRGB(240, 200, 120),
        Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    }, picker)
    local list = mk("ScrollingFrame", {
        Position = UDim2.new(0, 6, 0, 24), Size = UDim2.new(1, -12, 1, -62),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, picker)
    mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, list)
    mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, list)

    local rowBtns = {}
    local function rowText(o)
        return (csvHas(getCsv(), o.name, exact) and "[x] " or "[ ] ") .. o.name
            .. (o.count > 0 and (" (" .. o.count .. ")") or " (нет рядом)") .. (o.extra or "")
    end
    local function refreshRows()
        for _, r in ipairs(rowBtns) do r.btn.Text = rowText(r.opt) end
    end

    local opts = getOptions()
    for i, o in ipairs(opts) do
        local b = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(50, 50, 66),
            TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, Text = rowText(o), LayoutOrder = i,
        }, list)
        mk("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
        mk("UIPadding", { PaddingLeft = UDim.new(0, 6) }, b)
        rowBtns[#rowBtns + 1] = { btn = b, opt = o }
        b.Activated:Connect(function()
            setCsv((csvToggle(getCsv(), o.name, exact)))
            refreshAll()
            refreshRows()
        end)
    end
    if #opts == 0 then
        mk("TextLabel", {
            Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1,
            Text = "Рядом ничего не найдено. Впишите название в поле вручную.",
            TextColor3 = Color3.fromRGB(200, 200, 215), Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true,
        }, list)
    end

    local function bottomBtn(text, x, cb)
        local b = mk("TextButton", {
            Position = UDim2.new(x, 6, 1, -34), Size = UDim2.new(0.5, -9, 0, 30),
            BackgroundColor3 = Color3.fromRGB(70, 70, 100), TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = text,
        }, picker)
        mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        b.Activated:Connect(cb)
    end
    bottomBtn("Очистить", 0, function()
        setCsv("")
        refreshAll()
        refreshRows()
    end)
    bottomBtn("Готово", 0.5, closePicker)
end

-- ----- вкладка "Предметы" -----
do
    local P = pages.items
    local grabbyLabel = mkLabel(P, "", nil, 28)
    live[#live + 1] = function()
        if grabbyReady() then
            grabbyLabel.Text = "Grabby: готов (UUID " .. tostring(GG.toolUuid) .. ")"
            grabbyLabel.TextColor3 = Color3.fromRGB(150, 220, 160)
        else
            grabbyLabel.Text = "Grabby: возьмите и поставьте предмет им вручную 1 раз"
            grabbyLabel.TextColor3 = Color3.fromRGB(240, 200, 120)
        end
    end

    for _, s in ipairs(S) do
        if s.tab == "items" then addSetting(P, s) end
    end

    local nameBox = mkInput(P, "Предметы (через ,)", function() return CFG.ItemName end,
        function(v) CFG.ItemName = v end, false)

    mkBtn(P, "Выбрать из списка...", function()
        openPicker("Предметы", optionsItems, function() return CFG.ItemName end,
            function(v) CFG.ItemName = v end, true)
    end)

    -- нажатие по предметам в мире: выкл / добавить имя в список / перенести предмет
    local tapMode = "off"
    local tapBtn
    local function refreshTap()
        local names = { off = "выкл", name = "добавить имя", carry = "перенести предмет" }
        tapBtn.Text = "Нажатие: " .. names[tapMode]
        tapBtn.BackgroundColor3 = tapMode == "off" and Color3.fromRGB(55, 55, 72) or Color3.fromRGB(110, 90, 40)
    end
    tapBtn = mkBtn(P, "", function()
        tapMode = (tapMode == "off" and "name") or (tapMode == "name" and "carry") or "off"
        refreshTap()
        if tapMode == "name" then
            setStatus("Тап по предмету в мире: имя добавится в список (повторный тап уберёт)")
        elseif tapMode == "carry" then
            setStatus("Тап по предмету в мире: он сразу будет перенесён в точку выгрузки")
        end
    end)
    refreshTap()

    mkBtn(P, "Очистить список предметов", function()
        CFG.ItemName = ""
        refreshAll()
        setStatus("Список пуст: берутся любые предметы с Draggable")
    end)
    addDropButton(P)

    local tapConn
    tapConn = UIS.InputBegan:Connect(function(input, gp)
        if not gui.Parent then tapConn:Disconnect() return end
        if tapMode == "off" or gp then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = { lp.Character }
        local res = workspace:Raycast(ray.Origin, ray.Direction * 500, rp)
        if not res then setStatus("Под нажатием ничего нет") return end

        local folder = getFolder()
        local cur, found = res.Instance, nil
        while cur and cur ~= workspace do
            if cur:GetAttribute("Draggable") ~= nil or cur:GetAttribute("UUID") ~= nil
                or (folder and cur.Parent == folder)
                or (cur.Parent and cur.Parent.Name == CFG.UnownedContainer) then
                found = cur
                break
            end
            cur = cur.Parent
        end
        if not found then setStatus("Это не предмет: " .. res.Instance.Name) return end

        if tapMode == "name" then
            local newCsv, added = csvToggle(CFG.ItemName, found.Name, true)
            CFG.ItemName = newCsv
            refreshAll()
            setStatus((added and "Добавлено: " or "Убрано: ") .. found.Name)
            print("[carrier] выбор:", found:GetFullName())
        else
            if running then setStatus("Уже идёт работа: нажмите Стоп") return end
            task.spawn(runJob, "tap", found)
        end
    end)
end

-- ----- вкладки "Деревья" и "Руды" -----
local function toolLabel(kind)
    local key = kind == "tree" and "TreeTool" or "RockTool"
    local name = kind == "tree" and "Топор" or "Кирка"
    local chosen = tostring(CFG[key] or "")
    local eff = chooseTool(kind)
    local tag = eff and ("..." .. eff:sub(-4)) or "нет записи"
    local T = eff and TM.tools[eff]
    local sw = T and T.macro and (" " .. ("%.1f"):format(swingTime(T.macro)) .. (CFG.Lang == "EN" and "s" or "с")) or ""
    return name .. ": " .. (chosen ~= "" and "выбран " or "авто ") .. tag .. sw
end

local function cycleTool(kind)
    local key = kind == "tree" and "TreeTool" or "RockTool"
    local cands = {}
    for u, T in pairs(TM.tools) do
        if T.macro and T.kinds and T.kinds[kind] then cands[#cands + 1] = u end
    end
    table.sort(cands)
    if #cands == 0 then
        setStatus("Нет записанных инструментов: ударьте вручную 2+ раза")
        return
    end
    local cur = tostring(CFG[key] or "")
    local nextVal = cands[1]
    if cur ~= "" then
        nextVal = ""
        for i, u in ipairs(cands) do
            if u == cur and cands[i + 1] then nextVal = cands[i + 1] end
        end
    end
    CFG[key] = nextVal
end

local function scanNodes(kind)
    local hrp = getChar()
    if not hrp then return end
    local nodes = findNodes(kind, hrp.Position)
    local counts, order = {}, {}
    for _, n in ipairs(nodes) do
        local nm = tostring(n.node:GetAttribute(kind == "tree" and "TreeName" or "RockName") or n.node.Name)
        local ore = n.node:GetAttribute("OreName")
        if ore then nm = nm .. "/" .. tostring(ore) end
        if not counts[nm] then counts[nm] = 0 order[#order + 1] = nm end
        counts[nm] += 1
    end
    local s = {}
    for _, nm in ipairs(order) do s[#s + 1] = nm .. " x" .. counts[nm] end
    setStatus(("Найдено %d: %s"):format(#nodes, table.concat(s, ", ")))
end

for _, kind in ipairs({ "tree", "rock" }) do
    local P = pages[kind == "tree" and "trees" or "rocks"]
    local tb
    tb = mkBtn(P, toolLabel(kind), function()
        cycleTool(kind)
        tb.Text = toolLabel(kind)
    end)
    live[#live + 1] = function() tb.Text = toolLabel(kind) end
    refreshers[#refreshers + 1] = function() tb.Text = toolLabel(kind) end
    for _, s in ipairs(S) do
        if s.tab == (kind == "tree" and "trees" or "rocks") then addSetting(P, s) end
    end
    mkBtn(P, "Выбрать тип из списка...", function()
        openPicker(kind == "tree" and "Типы деревьев" or "Типы руд",
            function() return optionsNodes(kind) end,
            function() return kind == "tree" and CFG.TreeFilter or CFG.RockFilter end,
            function(v)
                if kind == "tree" then CFG.TreeFilter = v else CFG.RockFilter = v end
            end, false)
    end)
    mkBtn(P, "Показать цели рядом", function() scanNodes(kind) end)
    addDropButton(P)
end

-- Пустой обработчик оставлен для совместимости с загрузкой старых профилей.
local rebuildLocations = function() end

-- ----- вкладка "Телепорт" временно очищена по просьбе пользователя -----
do
    local P = pages.tp
    mkLabel(P, "Вкладка временно отключена. Функции телепорта будут добавлены позже после сбора данных.",
        Color3.fromRGB(240, 200, 120), 48)
end

-- ----- вкладка "Поиск редких предметов" -----
do
    local P = pages.rare
    mkLabel(P, "Поиск работает по видимым объектам и их атрибутам. Редкие варианты, отмеченные только цветом/материалом, могут пока не определяться.",
        Color3.fromRGB(240, 200, 120), 48)
    local function rareToggle(key, label)
        local b
        local function refresh()
            b.Text = label .. ": " .. (RARE[key] and "ВКЛ" or "ВЫКЛ")
        end
        b = mkBtn(P, "", function()
            RARE[key] = not RARE[key]
            refresh()
        end)
        refresh()
    end
    rareToggle("shinyTrees", "Shiny деревья")
    rareToggle("shinyOres", "Shiny руды")
    rareToggle("goldenApple", "Золотые яблоки")
    rareToggle("blueStars", "Синие звёзды")
    rareToggle("purpleStars", "Фиолетовые звёзды")
    rareToggle("blueFireflies", "Синие светлячки")
    rareToggle("purpleFireflies", "Фиолетовые светлячки")
    rareToggle("ghosts", "Синие/фиолетовые призраки")
    rareToggle("ghostFireflies", "Призрачные светлячки")
    local modeBtn
    local function refreshMode()
        modeBtn.Text = "Действие: " .. rareMode
    end
    modeBtn = mkBtn(P, "", function()
        rareMode = rareMode == "Игрок к цели" and "Предмет к игроку" or "Игрок к цели"
        refreshMode()
    end)
    refreshMode()
    local mapBtn
    local function refreshMap()
        mapBtn.Text = "Загрузка карты: " .. (rareMapLoading and "ВКЛ" or "ВЫКЛ")
    end
    mapBtn = mkBtn(P, "", function()
        rareMapLoading = not rareMapLoading
        refreshMap()
        if rareMapLoading then setStatus("Цикл загрузки карты включён; действует при следующем запуске поиска") end
    end)
    refreshMap()
    mkLabel(P, "Цикл карты: над самым дальним загруженным деревом на 20 студов выше вершины, затем возврат в начальную точку; повтор через 5 минут.",
        Color3.fromRGB(175, 195, 220), 44)
end

-- ----- вкладка "Настр." -----
do
    local P = pages.adv
    local langBtn
    local function refreshLang() langBtn.Text = "Language: " .. CFG.Lang .. " (tap to switch)" end
    langBtn = mkBtn(P, "", function()
        CFG.Lang = CFG.Lang == "RU" and "EN" or "RU"
        refreshAll()
        refreshLang()
        updateStart()
        localizeAll()
        setStatus(CFG.Lang == "EN" and "Language: English" or "Язык: русский")
    end)
    refreshLang()
    refreshers[#refreshers + 1] = refreshLang

    local profileName = "default"
    mkInput(P, "Профиль", function() return profileName end, function(v) profileName = v end, false)
    mkBtn(P, "Сохранить профиль", function()
        profiles[profileName] = snapshot()
        saveProfilesToDisk()
        setStatus(("Профиль '%s' сохранён (%s)"):format(profileName, canFile and "файл" or "только память сессии"))
    end)
    mkBtn(P, "Загрузить профиль", function()
        local data = profiles[profileName]
        if not data then setStatus("Профиль '" .. profileName .. "' не найден") return end
        applySnapshot(data)
        refreshAll()
        rebuildLocations()
        onChanged({ key = "GuiScale" })
        localizeAll()
        setStatus("Профиль '" .. profileName .. "' загружен")
    end)
    mkBtn(P, "Список профилей", function()
        local names = {}
        for k in pairs(profiles) do names[#names + 1] = k end
        table.sort(names)
        setStatus("Профили: " .. (#names > 0 and table.concat(names, ", ") or "нет")
            .. (canFile and "" or " (файлы недоступны)"))
    end)
    mkBtn(P, "Сбросить все настройки", function()
        for _, s in ipairs(S) do CFG[s.key] = s.default end
        applySnapshot({})
        refreshAll()
        onChanged({ key = "GuiScale" })
        setStatus("Настройки сброшены к значениям по умолчанию")
    end)
    mkBtn(P, "Закрыть скрипт", function()
        stopFlag = true
        if cleanupFn then pcall(cleanupFn) end
        pcall(unequipTool)
        gui:Destroy()
        toggleGui:Destroy()
    end)

    local lastGroup
    for _, s in ipairs(S) do
        if s.tab == "adv" then
            if s.group ~= lastGroup then
                mkLabel(P, "-- " .. s.group .. " --", Color3.fromRGB(240, 200, 120), 18)
                lastGroup = s.group
            end
            addSetting(P, s)
        end
    end
end

-- обновление живых меток раз в секунду
task.spawn(function()
    while gui.Parent do
        for _, f in ipairs(live) do pcall(f) end
        pcall(localizeAll)
        task.wait(1)
    end
end)

-- автозагрузка профиля "default"
loadProfilesFromDisk()
if profiles.default then
    applySnapshot(profiles.default)
    refreshAll()
    rebuildLocations()
    onChanged({ key = "GuiScale" })
    setStatus("Загружен профиль default" .. (canFile and "" or " (из памяти сессии)"))
end

showTab("items")
localizeAll()
print("[carrier] v8d готов. Файлы настроек:", canFile and PROFILE_FILE or "недоступны (профили только в памяти)")
