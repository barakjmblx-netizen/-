-- Pop It Trading | Dump Only v3.0 — ULTRA DUMP
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

pcall(function()
    game:GetService("CoreGui"):FindFirstChild("PIMMenu"):Destroy()
end)

-- === LOG ===
local logBuf = {}
local LogText

local function lp(s)
    table.insert(logBuf, s)
    print(s)
    if LogText then
        LogText.Text = table.concat(logBuf, "\n")
        task.defer(function()
            local scr = LogText.Parent
            if scr and scr:IsA("ScrollingFrame") then
                scr.CanvasPosition = Vector2.new(0, 1e9)
            end
        end)
    end
end

local function lc()
    logBuf = {}
    if LogText then LogText.Text = "(пусто)" end
end

-- === ROOT ===
local SG = Instance.new("ScreenGui")
SG.Name = "PIMMenu"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = game:GetService("CoreGui")

local F = Instance.new("Frame", SG)
F.Size = UDim2.new(0, 300, 1, -80)
F.Position = UDim2.new(0, 8, 0, 60)
F.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
F.BorderSizePixel = 0
F.ClipsDescendants = true
Instance.new("UICorner", F).CornerRadius = UDim.new(0, 12)
local fs = Instance.new("UIStroke", F)
fs.Color = Color3.fromRGB(70, 50, 140)
fs.Thickness = 1

-- === DRAG ===
local drag, ds, dp = false, nil, nil
F.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true; ds = i.Position; dp = F.Position
    end
end)
F.InputChanged:Connect(function(i)
    if drag and (i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1) then
        local d = i.Position - ds
        F.Position = UDim2.new(dp.X.Scale, dp.X.Offset + d.X,
                               dp.Y.Scale, dp.Y.Offset + d.Y)
    end
end)
F.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = false
    end
end)

-- === TITLE BAR ===
local TB = Instance.new("Frame", F)
TB.Size = UDim2.new(1, 0, 0, 36)
TB.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
TB.BorderSizePixel = 0
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 12)

local TL = Instance.new("TextLabel", TB)
TL.Size = UDim2.new(1, -44, 1, 0)
TL.Position = UDim2.new(0, 10, 0, 0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.fromRGB(190, 160, 255)
TL.Text = "🔍 Ultra Dump v3"
TL.Font = Enum.Font.GothamBold
TL.TextSize = 13
TL.TextXAlignment = Enum.TextXAlignment.Left

local XB = Instance.new("TextButton", TB)
XB.Size = UDim2.new(0, 28, 0, 28)
XB.Position = UDim2.new(1, -32, 0, 4)
XB.BackgroundColor3 = Color3.fromRGB(160, 36, 54)
XB.Text = "✕"
XB.TextColor3 = Color3.new(1, 1, 1)
XB.Font = Enum.Font.GothamBold
XB.TextSize = 12
Instance.new("UICorner", XB).CornerRadius = UDim.new(0, 6)
XB.MouseButton1Up:Connect(function() SG:Destroy() end)

-- === DUMP BUTTON ===
local DumpBtn = Instance.new("TextButton", F)
DumpBtn.Size = UDim2.new(1, -12, 0, 36)
DumpBtn.Position = UDim2.new(0, 6, 0, 42)
DumpBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 90)
DumpBtn.Text = "▶  Run Ultra Dump"
DumpBtn.TextColor3 = Color3.new(1, 1, 1)
DumpBtn.Font = Enum.Font.GothamBold
DumpBtn.TextSize = 13
DumpBtn.BorderSizePixel = 0
Instance.new("UICorner", DumpBtn).CornerRadius = UDim.new(0, 8)

-- === CLEAR BUTTON ===
local ClrBtn = Instance.new("TextButton", F)
ClrBtn.Size = UDim2.new(1, -12, 0, 28)
ClrBtn.Position = UDim2.new(0, 6, 0, 84)
ClrBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
ClrBtn.Text = "🗑  Clear Log"
ClrBtn.TextColor3 = Color3.new(1, 1, 1)
ClrBtn.Font = Enum.Font.GothamSemibold
ClrBtn.TextSize = 12
ClrBtn.BorderSizePixel = 0
Instance.new("UICorner", ClrBtn).CornerRadius = UDim.new(0, 8)
ClrBtn.MouseButton1Up:Connect(function() lc() end)

-- === LOG SCROLL ===
local LogScr = Instance.new("ScrollingFrame", F)
LogScr.Size = UDim2.new(1, -8, 1, -162)
LogScr.Position = UDim2.new(0, 4, 0, 118)
LogScr.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
LogScr.BorderSizePixel = 0
LogScr.ScrollBarThickness = 3
LogScr.ScrollBarImageColor3 = Color3.fromRGB(80, 60, 160)
LogScr.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScr.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", LogScr).CornerRadius = UDim.new(0, 8)
local LPad = Instance.new("UIPadding", LogScr)
LPad.PaddingAll = UDim.new(0, 6)

LogText = Instance.new("TextLabel", LogScr)
LogText.Size = UDim2.new(1, 0, 0, 0)
LogText.AutomaticSize = Enum.AutomaticSize.Y
LogText.BackgroundTransparency = 1
LogText.TextColor3 = Color3.fromRGB(140, 210, 140)
LogText.Font = Enum.Font.Code
LogText.TextSize = 10
LogText.TextXAlignment = Enum.TextXAlignment.Left
LogText.TextYAlignment = Enum.TextYAlignment.Top
LogText.TextWrapped = true
LogText.Text = "(пусто — нажми Run Ultra Dump)"

-- === COPY BUTTON ===
local CopyBtn = Instance.new("TextButton", F)
CopyBtn.Size = UDim2.new(1, -12, 0, 36)
CopyBtn.Position = UDim2.new(0, 6, 1, -42)
CopyBtn.BackgroundColor3 = Color3.fromRGB(36, 100, 60)
CopyBtn.Text = "📋  Скопировать лог"
CopyBtn.TextColor3 = Color3.new(1, 1, 1)
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 13
CopyBtn.BorderSizePixel = 0
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 8)
CopyBtn.MouseButton1Up:Connect(function()
    local s = table.concat(logBuf, "\n")
    if s == "" then
        CopyBtn.Text = "⚠  Лог пустой"
    elseif setclipboard then
        setclipboard(s)
        CopyBtn.Text = "✓  Скопировано!"
    else
        CopyBtn.Text = "⚠  Нет setclipboard"
    end
    task.delay(2, function() CopyBtn.Text = "📋  Скопировать лог" end)
end)

-- ================================================================
-- HELPERS
-- ================================================================
local function safeGet(fn)
    local ok, v = pcall(fn)
    if ok then return tostring(v) else return "ERR:" .. tostring(v) end
end

local function header(title)
    lp("\n╔══════════════════════════════╗")
    lp("║  " .. title .. string.rep(" ", 29 - #title) .. "║")
    lp("╚══════════════════════════════╝")
end

-- ================================================================
-- ULTRA DUMP
-- ================================================================
local function doFullDump()
    DumpBtn.Text = "⏳ Дамп идёт..."
    DumpBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
    lc()

    -- ── 1. GAME INFO ──────────────────────────────────────────────
    header("GAME INFO")
    lp("  PlaceId        : " .. safeGet(function() return game.PlaceId end))
    lp("  GameId         : " .. safeGet(function() return game.GameId end))
    lp("  PlaceVersion   : " .. safeGet(function() return game.PlaceVersion end))
    lp("  JobId          : " .. safeGet(function() return game.JobId end))
    lp("  CreatorId      : " .. safeGet(function() return game.CreatorId end))
    lp("  CreatorType    : " .. safeGet(function() return game.CreatorType end))
    lp("  VIPServerId    : " .. safeGet(function() return game.VIPServerId end))
    lp("  PrivateServerId: " .. safeGet(function() return game.PrivateServerId end))

    -- ── 2. LOCAL PLAYER INFO ──────────────────────────────────────
    header("LOCAL PLAYER INFO")
    lp("  Name           : " .. safeGet(function() return LP.Name end))
    lp("  DisplayName    : " .. safeGet(function() return LP.DisplayName end))
    lp("  UserId         : " .. safeGet(function() return LP.UserId end))
    lp("  AccountAge     : " .. safeGet(function() return LP.AccountAge end) .. " дней")
    lp("  MembershipType : " .. safeGet(function() return LP.MembershipType end))
    lp("  Team           : " .. safeGet(function() return LP.Team and LP.Team.Name or "nil" end))

    -- ── 3. CHARACTER / HUMANOID ───────────────────────────────────
    header("CHARACTER / HUMANOID")
    pcall(function()
        local char = LP.Character
        if not char then lp("  Character: nil"); return end
        lp("  Character.Name   : " .. char.Name)
        lp("  Position         : " .. safeGet(function()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            return hrp and tostring(hrp.Position) or "no HRP"
        end))
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            lp("  Health           : " .. safeGet(function() return hum.Health end))
            lp("  MaxHealth        : " .. safeGet(function() return hum.MaxHealth end))
            lp("  WalkSpeed        : " .. safeGet(function() return hum.WalkSpeed end))
            lp("  JumpPower        : " .. safeGet(function() return hum.JumpPower end))
            lp("  State            : " .. safeGet(function() return hum:GetState() end))
            lp("  RigType          : " .. safeGet(function() return hum.RigType end))
        end
        local accs = {}
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Accessory") then table.insert(accs, v.Name) end
        end
        lp("  Accessories      : " .. (#accs > 0 and table.concat(accs, ", ") or "none"))
    end)

    -- ── 4. LEADERSTATS / STATS ────────────────────────────────────
    header("LEADERSTATS / STATS")
    pcall(function()
        local function dumpFolder(folder, prefix)
            if not folder then return end
            for _, v in ipairs(folder:GetChildren()) do
                local val = ""
                pcall(function() val = tostring(v.Value) end)
                lp("  " .. prefix .. v.Name .. " [" .. v.ClassName .. "] = " .. val)
                dumpFolder(v, prefix .. "  ")
            end
        end
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            lp("  [leaderstats]")
            dumpFolder(ls, "    ")
        else
            lp("  leaderstats: not found")
        end
        for _, child in ipairs(LP:GetChildren()) do
            if child:IsA("Folder") and child.Name ~= "leaderstats" then
                lp("  [Folder: " .. child.Name .. "]")
                dumpFolder(child, "    ")
            end
        end
    end)

    -- ── 5. BACKPACK / TOOLS ───────────────────────────────────────
    header("BACKPACK / TOOLS")
    pcall(function()
        local bp = LP:FindFirstChild("Backpack")
        if bp then
            local tools = bp:GetChildren()
            lp("  Кол-во инструментов: " .. #tools)
            for _, t in ipairs(tools) do
                lp("  [" .. t.ClassName .. "] " .. t.Name)
            end
        else
            lp("  Backpack: не найден")
        end
        local char = LP.Character
        if char then
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Tool") then lp("  [EQUIPPED] " .. v.Name) end
            end
        end
    end)

    -- ── 6. PLAYER GUI STRUCTURE ───────────────────────────────────
    header("PLAYER GUI STRUCTURE")
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then lp("  PlayerGui: не найден"); return end
        for _, gui in ipairs(pg:GetChildren()) do
            lp("  [" .. gui.ClassName .. "] " .. gui.Name
                .. (gui:IsA("ScreenGui") and " | Enabled=" .. tostring(gui.Enabled) or ""))
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    lp("    [" .. obj.ClassName .. "] " .. obj:GetFullName()
                        .. " | Disabled=" .. tostring(obj.Disabled))
                end
            end
        end
    end)

    -- ── 7. REMOTES ────────────────────────────────────────────────
    header("REMOTES (ReplicatedStorage)")
    pcall(function()
        local reCount, rfCount, beCount, bfCount = 0, 0, 0, 0
        for _, obj in ipairs(RS:GetDescendants()) do
            local t = obj.ClassName
            if     t == "RemoteEvent"       then reCount += 1; lp("  [RE] " .. obj:GetFullName())
            elseif t == "RemoteFunction"    then rfCount += 1; lp("  [RF] " .. obj:GetFullName())
            elseif t == "BindableEvent"     then beCount += 1; lp("  [BE] " .. obj:GetFullName())
            elseif t == "BindableFunction"  then bfCount += 1; lp("  [BF] " .. obj:GetFullName())
            end
        end
        lp("  Итого RE=" .. reCount .. " RF=" .. rfCount
            .. " BE=" .. beCount .. " BF=" .. bfCount)
    end)

    -- ── 8. MODULES ────────────────────────────────────────────────
    header("MODULE SCRIPTS")
    pcall(function()
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("ModuleScript") then
                lp("  [Module] " .. obj:GetFullName())
            end
        end
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("ModuleScript") then
                    lp("  [Module/GUI] " .. obj:GetFullName())
                end
            end
        end
    end)

    -- ── 9. ALL RS VALUES ──────────────────────────────────────────
    header("ALL RS VALUES / CONFIGS")
    pcall(function()
        for _, obj in ipairs(RS:GetDescendants()) do
            local t = obj.ClassName
            if t == "StringValue" or t == "NumberValue" or t == "IntValue"
            or t == "BoolValue" or t == "Color3Value" or t == "Vector3Value"
            or t == "CFrameValue" or t == "ObjectValue" then
                local val = ""
                pcall(function() val = tostring(obj.Value) end)
                lp("  [" .. t .. "] " .. obj:GetFullName() .. " = " .. val)
            end
        end
    end)

    -- ── 10. CONFIGURATION INSTANCES ───────────────────────────────
    header("CONFIGURATION OBJECTS")
    pcall(function()
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("Configuration") then
                lp("  [Config] " .. obj:GetFullName())
                for _, attr in ipairs(obj:GetChildren()) do
                    local val = ""
                    pcall(function() val = tostring(attr.Value) end)
                    lp("    ." .. attr.Name .. " [" .. attr.ClassName .. "] = " .. val)
                end
            end
        end
    end)

    -- ── 11. ATTRIBUTES ────────────────────────────────────────────
    header("ATTRIBUTES (RS + Player)")
    pcall(function()
        for _, obj in ipairs(RS:GetChildren()) do
            local attrs = obj:GetAttributes()
            local count = 0
            for _ in pairs(attrs) do count += 1 end
            if count > 0 then
                lp("  RS/" .. obj.Name .. ":")
                for k, v in pairs(attrs) do
                    lp("    ." .. k .. " = " .. tostring(v))
                end
            end
        end
        local pa = LP:GetAttributes()
        local pc = 0
        for _ in pairs(pa) do pc += 1 end
        lp("  Player attrs: " .. pc)
        for k, v in pairs(pa) do
            lp("    ." .. k .. " = " .. tostring(v))
        end
    end)

    -- ── 12. WORKSPACE INFO ────────────────────────────────────────
    header("WORKSPACE INFO")
    pcall(function()
        local ws = game:GetService("Workspace")
        lp("  Gravity            : " .. safeGet(function() return ws.Gravity end))
        lp("  StreamingEnabled   : " .. safeGet(function() return ws.StreamingEnabled end))
        lp("  StreamingMinRadius : " .. safeGet(function() return ws.StreamingMinRadius end))
        for _, obj in ipairs(ws:GetChildren()) do
            lp("  [" .. obj.ClassName .. "] " .. obj.Name)
        end
    end)

    -- ── 13. STARTERPACK / STARTERGUI ──────────────────────────────
    header("STARTERPACK / STARTERGUI")
    pcall(function()
        local sp = game:GetService("StarterPack")
        for _, obj in ipairs(sp:GetDescendants()) do
            lp("  [SP/" .. obj.ClassName .. "] " .. obj:GetFullName())
        end
        local sg2 = game:GetService("StarterGui")
        for _, obj in ipairs(sg2:GetDescendants()) do
            lp("  [SG/" .. obj.ClassName .. "] " .. obj:GetFullName())
        end
    end)

    -- ══════════════════════════════════════════════════════════════
    -- ── 14. FOLDERS / INVENTORY DUMP (NEW) ───────────────────────
    -- ══════════════════════════════════════════════════════════════
    header("FOLDERS / INVENTORY (LP+RS)")
    pcall(function()
        -- Ключевые слова для инвентарей в Pop It Trading
        local invKeywords = {
            "inventory","items","pets","eggs","collection","equip",
            "owned","data","storage","popit","fruit","reward","chest",
            "shop","currencies","coin","cash","gems","token"
        }
        local function isInvFolder(name)
            local lo = name:lower()
            for _, kw in ipairs(invKeywords) do
                if lo:find(kw) then return true end
            end
            return false
        end

        local function dumpObj(obj, depth)
            local pad = string.rep("  ", depth)
            local val = ""
            pcall(function() val = " = " .. tostring(obj.Value) end)
            lp(pad .. "[" .. obj.ClassName .. "] " .. obj.Name .. val)
            if depth < 6 then
                for _, child in ipairs(obj:GetChildren()) do
                    dumpObj(child, depth + 1)
                end
            elseif #obj:GetChildren() > 0 then
                lp(pad .. "  ... (" .. #obj:GetChildren() .. " детей, обрезано)")
            end
        end

        -- Scan LP
        lp("  >> LocalPlayer Folders:")
        for _, obj in ipairs(LP:GetChildren()) do
            if obj:IsA("Folder") or isInvFolder(obj.Name) then
                dumpObj(obj, 2)
            end
        end

        -- Scan RS
        lp("  >> ReplicatedStorage Folders:")
        for _, obj in ipairs(RS:GetChildren()) do
            if obj:IsA("Folder") or isInvFolder(obj.Name) then
                dumpObj(obj, 2)
            end
        end

        -- PlayerData folder specifically
        local pd = LP:FindFirstChild("PlayerData")
            or LP:FindFirstChild("Data")
            or RS:FindFirstChild("PlayerData")
            or RS:FindFirstChild("Data")
        if pd then
            lp("  >> Найден Data-объект: " .. pd:GetFullName())
            dumpObj(pd, 2)
        end
    end)


    -- ══════════════════════════════════════════════════════════════
    -- ── 15. SCRIPT SOURCE DUMP / DECOMPILE ATTEMPT (NEW) ─────────
    -- ══════════════════════════════════════════════════════════════
    header("SCRIPT SOURCE (decompile attempt)")
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        local targets = {}

        -- Собираем все LocalScript / ModuleScript из PlayerGui и RS
        if pg then
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    table.insert(targets, obj)
                end
            end
        end
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("ModuleScript") then
                table.insert(targets, obj)
            end
        end

        lp("  Скриптов найдено: " .. #targets)
        for _, scr in ipairs(targets) do
            lp("  ── " .. scr:GetFullName() .. " ──")
            -- Метод 1: pcall require (только ModuleScript)
            if scr:IsA("ModuleScript") then
                local ok, result = pcall(require, scr)
                if ok then
                    local t = type(result)
                    if t == "table" then
                        local keys = {}
                        for k in pairs(result) do
                            table.insert(keys, tostring(k))
                            if #keys >= 30 then break end
                        end
                        lp("    [require OK] table keys: " .. table.concat(keys, ", "))
                    else
                        lp("    [require OK] type=" .. t .. " val=" .. tostring(result))
                    end
                else
                    lp("    [require FAIL] " .. tostring(result))
                end
            end
            -- Метод 2: .Source (работает только без FiM-защиты)
            local ok2, src = pcall(function() return scr.Source end)
            if ok2 and src and #src > 0 then
                -- Первые 300 символов
                local preview = src:sub(1, 300):gsub("\n", "↵")
                lp("    [.Source OK] " .. preview .. (#src > 300 and "..." or ""))
                lp("    [.Source len] " .. #src .. " байт")
            else
                lp("    [.Source LOCKED]")
            end
        end
    end)

    -- ══════════════════════════════════════════════════════════════
    -- ── 16. DATASTORE KEY SCAN (NEW) ─────────────────────────────
    -- ══════════════════════════════════════════════════════════════
    header("DATASTORE KEY SCAN")
    pcall(function()
        -- DataStoreService недоступен клиентски напрямую,
        -- но ищем ключи через RS values и атрибуты
        local dsHints = {}

        -- Ищем строки похожие на DS-ключи в StringValue
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("StringValue") then
                local v = ""
                pcall(function() v = obj.Value end)
                -- DS-ключи обычно: "Player_12345678" или содержат UserId
                if v:find(tostring(LP.UserId))
                or v:find("Player_")
                or v:find("_data")
                or v:find("_save")
                or v:find("_store") then
                    lp("  [DS-hint StringValue] " .. obj:GetFullName() .. " = " .. v)
                    table.insert(dsHints, v)
                end
            end
        end

        -- Ищем объекты с именами похожими на DataStore
        local dsKeywords = {"datastore","savedata","playerdata","gamedata","store","save","key","profile"}
        for _, obj in ipairs(RS:GetDescendants()) do
            local lo = obj.Name:lower()
            for _, kw in ipairs(dsKeywords) do
                if lo:find(kw) then
                    lp("  [DS-name] " .. obj:GetFullName() .. " [" .. obj.ClassName .. "]")
                    break
                end
            end
        end

        -- Пробуем ProfileService / DataService через require
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("ModuleScript") then
                local lo = obj.Name:lower()
                if lo:find("profile") or lo:find("datastore") or lo:find("savemanager")
                or lo:find("dataservice") or lo:find("saveservice") then
                    lp("  [DS-Module] " .. obj:GetFullName())
                    local ok, m = pcall(require, obj)
                    if ok and type(m) == "table" then
                        local keys = {}
                        for k in pairs(m) do table.insert(keys, tostring(k)) end
                        lp("    keys: " .. table.concat(keys, ", "))
                    else
                        lp("    require fail: " .. tostring(m))
                    end
                end
            end
        end

        -- Прямой доступ через DataStoreService (только если есть доступ)
        local ok, dss = pcall(function() return game:GetService("DataStoreService") end)
        if ok and dss then
            lp("  DataStoreService: доступен")
            -- Пробуем стандартные имена хранилищ
            local storeNames = {
                "PlayerData","SaveData","GameData","Coins","Cash",
                "Inventory","Items","Pets","Progress","Settings",
                "PopItData","Trading","Backpack"
            }
            for _, name in ipairs(storeNames) do
                local ok2, store = pcall(function()
                    return dss:GetDataStore(name)
                end)
                if ok2 and store then
                    local ok3, val = pcall(function()
                        return store:GetAsync("Player_" .. LP.UserId)
                    end)
                    if ok3 and val ~= nil then
                        lp("  [DS:" .. name .. "] Player_" .. LP.UserId .. " =>")
                        local ok4, json = pcall(function()
                            return HttpService:JSONEncode(val)
                        end)
                        if ok4 then
                            lp("    " .. json:sub(1, 500) .. (#json > 500 and "..." or ""))
                        else
                            lp("    " .. tostring(val))
                        end
                    elseif ok3 then
                        lp("  [DS:" .. name .. "] => nil (нет данных)")
                    else
                        lp("  [DS:" .. name .. "] ERR: " .. tostring(val))
                    end
                end
            end
        else
            lp("  DataStoreService: нет доступа (клиент)")
        end
    end)

    -- ══════════════════════════════════════════════════════════════
    -- ── 17. REMOTES FIREALL SPAM (NEW) ───────────────────────────
    -- ══════════════════════════════════════════════════════════════
    header("REMOTES FIREALL SPAM")
    pcall(function()
        lp("  Пробуем FireServer на каждом RE...")
        local fired, failed = 0, 0
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj.ClassName == "RemoteEvent" then
                local ok, err = pcall(function()
                    obj:FireServer()
                end)
                if ok then
                    fired += 1
                    lp("  [OK] " .. obj:GetFullName())
                else
                    failed += 1
                    lp("  [ERR] " .. obj:GetFullName() .. " => " .. tostring(err))
                end
                task.wait(0.05) -- небольшая задержка чтобы не банить
            end
        end
        lp("  Итого: OK=" .. fired .. " ERR=" .. failed)

        -- RemoteFunctions — InvokeServer
        lp("\n  Пробуем InvokeServer на каждом RF...")
        local invoked, invFailed = 0, 0
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj.ClassName == "RemoteFunction" then
                local ok, result = pcall(function()
                    return obj:InvokeServer()
                end)
                if ok then
                    invoked += 1
                    local res = ""
                    pcall(function()
                        res = HttpService:JSONEncode(result)
                    end)
                    if res == "" then res = tostring(result) end
                    lp("  [OK] " .. obj:GetFullName() .. " => " .. res:sub(1, 120))
                else
                    invFailed += 1
                    lp("  [ERR] " .. obj:GetFullName() .. " => " .. tostring(result))
                end
                task.wait(0.05)
            end
        end
        lp("  Итого RF: OK=" .. invoked .. " ERR=" .. invFailed)
    end)

    -- ── 18. ANIMATIONS ON CHARACTER ───────────────────────────────
    header("ANIMATIONS ON CHARACTER")
    pcall(function()
        local char = LP.Character
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Animation") or obj:IsA("AnimationController")
                or obj:IsA("Animator") then
                    lp("  [" .. obj.ClassName .. "] " .. obj:GetFullName())
                end
            end
        end
    end)

    -- ── 19. TELEPORT DATA ─────────────────────────────────────────
    header("TELEPORT DATA")
    pcall(function()
        local TP = game:GetService("TeleportService")
        lp("  LocalPlayerTeleportData: " .. safeGet(function()
            local d = TP:GetLocalPlayerTeleportData()
            return d and HttpService:JSONEncode(d) or "nil"
        end))
    end)

    -- ── 20. DEEP PLAYER INSTANCES ─────────────────────────────────
    header("DEEP: ALL PLAYER INSTANCES")
    pcall(function()
        for _, obj in ipairs(LP:GetDescendants()) do
            local val = ""
            pcall(function() val = " = " .. tostring(obj.Value) end)
            lp("  [" .. obj.ClassName .. "] " .. obj:GetFullName() .. val)
        end
    end)

    lp("\n╔══════════════════════════════╗")
    lp("║          END DUMP            ║")
    lp("╚══════════════════════════════╝")
    lp("  Строк в логе: " .. #logBuf)

    DumpBtn.Text = "▶  Run Ultra Dump"
    DumpBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 90)
end

DumpBtn.MouseButton1Up:Connect(doFullDump)
