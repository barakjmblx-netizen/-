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

-- === LOG STATE ===
local logBuf = {}
local LogText
local autoSave = true               -- после дампа автоматически создавать .txt
local UI_MAX_CHARS = 15000          -- лимит текста в TextLabel (Roblox режет длинные строки)

-- Папки по очереди: пробуем первую рабочую (Delta Android → workspace executor-а → корень)
local DUMP_DIR_CANDIDATES = {
    "/storage/emulated/0/Delta/Dump/",
    "Dump/",
    "",
}
local DUMP_DIR = DUMP_DIR_CANDIDATES[1]
local _dirResolved = false

local function tsNow()
    if os.date then return os.date("%Y%m%d_%H%M%S") end
    return tostring(math.floor(tick()))
end

-- Выбираем папку, в которую реально можно писать
local function resolveDir()
    if _dirResolved then return DUMP_DIR end
    _dirResolved = true
    if not writefile then return DUMP_DIR end
    for _, c in ipairs(DUMP_DIR_CANDIDATES) do
        local ok = pcall(function()
            if c ~= "" and isfolder and makefolder and not isfolder(c) then makefolder(c) end
            writefile(c .. "_test.txt", "ok")
            if delfile then pcall(delfile, c .. "_test.txt") end
        end)
        if ok then DUMP_DIR = c; break end
    end
    return DUMP_DIR
end

-- Хвост лога для UI (полный текст всегда уходит в .txt)
local function tailText(buf, maxChars)
    local n = #buf
    if n == 0 then return "" end
    local size, first = 0, n
    for i = n, 1, -1 do
        size = size + #buf[i] + 1
        if size > maxChars and i < n then break end
        first = i
    end
    local s = table.concat(buf, "\n", first, n)
    if first > 1 then s = "… (показан хвост, полный лог — в .txt)\n" .. s end
    if #s > maxChars + 100 then s = s:sub(-maxChars) end
    return s
end

local function saveFullLog(path)
    if not writefile then return false, "writefile недоступен" end
    return pcall(function()
        resolveDir()
        writefile(path, table.concat(logBuf, "\n"))
    end)
end

-- ── Батчинг обновлений UI ─────────────────────────────────────────
local _logDirty = false
local function lp(s)
    table.insert(logBuf, s)
    if LogText and not _logDirty then
        _logDirty = true
        task.defer(function()
            _logDirty = false
            if LogText then
                LogText.Text = tailText(logBuf, UI_MAX_CHARS)
                local scr = LogText.Parent
                if scr and scr:IsA("ScrollingFrame") then
                    scr.CanvasPosition = Vector2.new(0, 1e9)
                end
            end
        end)
    end
end

local function lc()
    logBuf = {}
    if LogText then LogText.Text = "(пусто)" end
end

-- ================================================================
-- ROOT GUI
-- ================================================================
local SG = Instance.new("ScreenGui")
SG.Name = "PIMMenu"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = game:GetService("CoreGui")

-- ================================================================
-- ГЛАВНОЕ МЕНЮ (компактное, только кнопки управления)
-- ================================================================
local menuCollapsed = false
local MENU_H_EXPANDED  = 280   -- высота со всеми кнопками
local MENU_H_COLLAPSED = 40    -- только title bar

local F = Instance.new("Frame", SG)
F.Size = UDim2.new(0, 220, 0, MENU_H_EXPANDED)
F.Position = UDim2.new(0, 8, 0, 60)
F.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
F.BorderSizePixel = 0
F.ClipsDescendants = true
Instance.new("UICorner", F).CornerRadius = UDim.new(0, 12)
local fs = Instance.new("UIStroke", F)
fs.Color = Color3.fromRGB(70, 50, 140)
fs.Thickness = 1

-- drag главного меню
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
    or i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
end)

-- ── Title bar главного меню ───────────────────────────────────────
local TB = Instance.new("Frame", F)
TB.Size = UDim2.new(1, 0, 0, 36)
TB.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
TB.BorderSizePixel = 0
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 12)

local TL = Instance.new("TextLabel", TB)
TL.Size = UDim2.new(1, -76, 1, 0)
TL.Position = UDim2.new(0, 10, 0, 0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.fromRGB(190, 160, 255)
TL.Text = "🔍 Ultra Dump v4"
TL.Font = Enum.Font.GothamBold
TL.TextSize = 13
TL.TextXAlignment = Enum.TextXAlignment.Left

-- Кнопка свернуть/развернуть
local MinBtn = Instance.new("TextButton", TB)
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -64, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
MinBtn.Text = "▼"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 11
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Кнопка закрыть
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

-- ── Контейнер кнопок (скрывается при свёртке) ────────────────────
local BtnBox = Instance.new("Frame", F)
BtnBox.Size = UDim2.new(1, 0, 1, -40)
BtnBox.Position = UDim2.new(0, 0, 0, 40)
BtnBox.BackgroundTransparency = 1
BtnBox.BorderSizePixel = 0

local BtnLayout = Instance.new("UIListLayout", BtnBox)
BtnLayout.SortOrder = Enum.SortOrder.LayoutOrder
BtnLayout.Padding = UDim.new(0, 6)
BtnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local BtnPad = Instance.new("UIPadding", BtnBox)
BtnPad.PaddingTop = UDim.new(0, 6)
BtnPad.PaddingLeft = UDim.new(0, 6)
BtnPad.PaddingRight = UDim.new(0, 6)

local function makeBtn(parent, text, color, order)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.BorderSizePixel = 0
    b.LayoutOrder = order
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local DumpBtn  = makeBtn(BtnBox, "▶  Run Ultra Dump",       Color3.fromRGB(40, 40, 90),  1)
local LogBtn   = makeBtn(BtnBox, "📄  Лог дампа",            Color3.fromRGB(40, 70, 90),  2)
local RTBtn    = makeBtn(BtnBox, "⚡  Реал-тайм: ВЫКЛ",      Color3.fromRGB(50, 40, 20),  3)
RTBtn.TextSize = 12
local RTLogBtn = makeBtn(BtnBox, "📡  RT Лог",               Color3.fromRGB(30, 60, 80),  4)

-- Переключатель: создавать .txt после дампа
local AutoBtn = makeBtn(BtnBox, "💾  Файл .txt: ВКЛ", Color3.fromRGB(30, 90, 50), 5)
AutoBtn.TextSize = 12
AutoBtn.MouseButton1Up:Connect(function()
    autoSave = not autoSave
    if autoSave then
        AutoBtn.Text = "💾  Файл .txt: ВКЛ"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(30, 90, 50)
    else
        AutoBtn.Text = "💾  Файл .txt: ВЫКЛ"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
end)

-- ── Свернуть / развернуть ─────────────────────────────────────────
MinBtn.MouseButton1Up:Connect(function()
    menuCollapsed = not menuCollapsed
    if menuCollapsed then
        F.Size = UDim2.new(0, 220, 0, MENU_H_COLLAPSED)
        BtnBox.Visible = false
        MinBtn.Text = "▲"
    else
        F.Size = UDim2.new(0, 220, 0, MENU_H_EXPANDED)
        BtnBox.Visible = true
        MinBtn.Text = "▼"
    end
end)

-- ================================================================
-- ОКНО ЛОГА
-- ================================================================
local LF = Instance.new("Frame", SG)
LF.Size = UDim2.new(0, 310, 1, -80)
LF.Position = UDim2.new(0, 236, 0, 60)
LF.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
LF.BorderSizePixel = 0
LF.ClipsDescendants = true
LF.Visible = false
Instance.new("UICorner", LF).CornerRadius = UDim.new(0, 12)
local lfs = Instance.new("UIStroke", LF)
lfs.Color = Color3.fromRGB(70, 50, 140)
lfs.Thickness = 1

-- drag окна лога
local ldrag, lds, ldp = false, nil, nil
LF.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        ldrag = true; lds = i.Position; ldp = LF.Position
    end
end)
LF.InputChanged:Connect(function(i)
    if ldrag and (i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1) then
        local d = i.Position - lds
        LF.Position = UDim2.new(ldp.X.Scale, ldp.X.Offset + d.X,
                                ldp.Y.Scale, ldp.Y.Offset + d.Y)
    end
end)
LF.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then ldrag = false end
end)

-- title bar окна лога
local LTB = Instance.new("Frame", LF)
LTB.Size = UDim2.new(1, 0, 0, 36)
LTB.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
LTB.BorderSizePixel = 0
Instance.new("UICorner", LTB).CornerRadius = UDim.new(0, 12)

local LTL = Instance.new("TextLabel", LTB)
LTL.Size = UDim2.new(1, -44, 1, 0)
LTL.Position = UDim2.new(0, 10, 0, 0)
LTL.BackgroundTransparency = 1
LTL.TextColor3 = Color3.fromRGB(190, 160, 255)
LTL.Text = "📄 Лог"
LTL.Font = Enum.Font.GothamBold
LTL.TextSize = 13
LTL.TextXAlignment = Enum.TextXAlignment.Left

local LXB = Instance.new("TextButton", LTB)
LXB.Size = UDim2.new(0, 28, 0, 28)
LXB.Position = UDim2.new(1, -32, 0, 4)
LXB.BackgroundColor3 = Color3.fromRGB(160, 36, 54)
LXB.Text = "✕"
LXB.TextColor3 = Color3.new(1, 1, 1)
LXB.Font = Enum.Font.GothamBold
LXB.TextSize = 12
Instance.new("UICorner", LXB).CornerRadius = UDim.new(0, 6)
LXB.MouseButton1Up:Connect(function() LF.Visible = false end)

LogBtn.MouseButton1Up:Connect(function() LF.Visible = not LF.Visible end)

-- Строка кнопок лога: [Очистить] [Скопировать] [Сохранить файл]
local LBtnRow = Instance.new("Frame", LF)
LBtnRow.Size = UDim2.new(1, -12, 0, 32)
LBtnRow.Position = UDim2.new(0, 6, 0, 42)
LBtnRow.BackgroundTransparency = 1
LBtnRow.BorderSizePixel = 0
local LBtnLayout = Instance.new("UIListLayout", LBtnRow)
LBtnLayout.FillDirection = Enum.FillDirection.Horizontal
LBtnLayout.SortOrder = Enum.SortOrder.LayoutOrder
LBtnLayout.Padding = UDim.new(0, 4)

local function makeLogBtn(parent, text, color, order)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0.33, -3, 1, 0)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.BorderSizePixel = 0
    b.LayoutOrder = order
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local ClrBtn  = makeLogBtn(LBtnRow, "🗑 Очистить",   Color3.fromRGB(90, 20, 20),   1)
local CopyBtn = makeLogBtn(LBtnRow, "📋 Копировать", Color3.fromRGB(36, 90, 60),   2)
local SaveBtn = makeLogBtn(LBtnRow, "💾 Сохранить",  Color3.fromRGB(50, 60, 110),  3)

ClrBtn.MouseButton1Up:Connect(function() lc() end)

CopyBtn.MouseButton1Up:Connect(function()
    local s = table.concat(logBuf, "\n")
    if s == "" then
        CopyBtn.Text = "⚠ Пусто"
    elseif setclipboard then
        setclipboard(s)
        CopyBtn.Text = "✓ Скопировано"
    else
        CopyBtn.Text = "⚠ Нет API"
    end
    task.delay(2, function() CopyBtn.Text = "📋 Копировать" end)
end)

SaveBtn.MouseButton1Up:Connect(function()
    if #logBuf == 0 then
        SaveBtn.Text = "⚠ Лог пуст"
        task.delay(2, function() SaveBtn.Text = "💾 Сохранить" end)
        return
    end
    local path = resolveDir() .. "dump_" .. tsNow() .. ".txt"
    local ok, err = saveFullLog(path)
    if ok then
        SaveBtn.Text = "✓ Сохранено!"
        SaveBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 50)
    else
        SaveBtn.Text = "✗ Ошибка"
        print("[DumpSave] err: " .. tostring(err))
    end
    task.delay(3, function()
        SaveBtn.Text = "💾 Сохранить"
        SaveBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 110)
    end)
end)

-- === LOG SCROLL ===
-- TouchScrollEnabled для телефонов
local LogScr = Instance.new("ScrollingFrame", LF)
LogScr.Size = UDim2.new(1, -8, 1, -88)
LogScr.Position = UDim2.new(0, 4, 0, 82)
LogScr.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
LogScr.BorderSizePixel = 0
LogScr.ScrollBarThickness = 6          -- толще для пальца
LogScr.ScrollBarImageColor3 = Color3.fromRGB(100, 80, 200)
LogScr.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScr.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScr.ScrollingDirection = Enum.ScrollingDirection.Y
LogScr.ElasticBehavior = Enum.ElasticBehavior.Always  -- iOS-подобная прокрутка
Instance.new("UICorner", LogScr).CornerRadius = UDim.new(0, 8)

local LPad = Instance.new("UIPadding", LogScr)
LPad.PaddingLeft = UDim.new(0, 6)
LPad.PaddingRight = UDim.new(0, 6)
LPad.PaddingTop = UDim.new(0, 6)
LPad.PaddingBottom = UDim.new(0, 6)

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

-- ================================================================
-- РЕАЛ-ТАЙМ СОСТОЯНИЕ
-- ================================================================
local rtActive   = false
local rtThread   = nil      -- task handle
local rtBuf      = {}       -- RT лог для окна (хвост)
local rtLogText  = nil      -- TextLabel в окне RT
local rtFile     = nil      -- путь к RT .txt файлу
local rtDirty    = false
local rtPending  = {}       -- строки, ещё не сброшенные в файл

-- Сброс накопленных строк в файл (раз в пару секунд, а не на каждую строку)
local function rtFlush()
    if not (writefile and rtFile) or #rtPending == 0 then return end
    local chunk = table.concat(rtPending, "\n") .. "\n"
    rtPending = {}
    pcall(function()
        if appendfile then
            appendfile(rtFile, chunk)
        else
            local ok, ex = pcall(readfile, rtFile)
            writefile(rtFile, (ok and ex or "") .. chunk)
        end
    end)
end

local function rtLog(s)
    local line = (os.date and os.date("%H:%M:%S") or "--:--:--") .. "  " .. s
    table.insert(rtBuf, line)
    if #rtBuf > 3500 then
        local keep = {}
        for i = #rtBuf - 2999, #rtBuf do keep[#keep + 1] = rtBuf[i] end
        rtBuf = keep
    end
    if rtFile then table.insert(rtPending, line) end
    if rtLogText and not rtDirty then
        rtDirty = true
        task.defer(function()
            rtDirty = false
            if rtLogText then
                rtLogText.Text = tailText(rtBuf, UI_MAX_CHARS)
                local scr = rtLogText.Parent
                if scr and scr:IsA("ScrollingFrame") then
                    scr.CanvasPosition = Vector2.new(0, 1e9)
                end
            end
        end)
    end
end

-- ================================================================
-- ОКНО RT-ЛОГА
-- ================================================================
local RTF = Instance.new("Frame", SG)
RTF.Size = UDim2.new(0, 310, 1, -80)
RTF.Position = UDim2.new(0, 554, 0, 60)
RTF.BackgroundColor3 = Color3.fromRGB(8, 10, 8)
RTF.BorderSizePixel = 0
RTF.ClipsDescendants = true
RTF.Visible = false
Instance.new("UICorner", RTF).CornerRadius = UDim.new(0, 12)
local rtfs = Instance.new("UIStroke", RTF)
rtfs.Color = Color3.fromRGB(50, 140, 70)
rtfs.Thickness = 1

local rtdrag, rtds, rtdp = false, nil, nil
RTF.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        rtdrag = true; rtds = i.Position; rtdp = RTF.Position
    end
end)
RTF.InputChanged:Connect(function(i)
    if rtdrag and (i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1) then
        local d = i.Position - rtds
        RTF.Position = UDim2.new(rtdp.X.Scale, rtdp.X.Offset + d.X,
                                 rtdp.Y.Scale, rtdp.Y.Offset + d.Y)
    end
end)
RTF.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then rtdrag = false end
end)

local RTTB = Instance.new("Frame", RTF)
RTTB.Size = UDim2.new(1, 0, 0, 36)
RTTB.BackgroundColor3 = Color3.fromRGB(14, 28, 14)
RTTB.BorderSizePixel = 0
Instance.new("UICorner", RTTB).CornerRadius = UDim.new(0, 12)

local RTTL = Instance.new("TextLabel", RTTB)
RTTL.Size = UDim2.new(1, -44, 1, 0)
RTTL.Position = UDim2.new(0, 10, 0, 0)
RTTL.BackgroundTransparency = 1
RTTL.TextColor3 = Color3.fromRGB(100, 230, 120)
RTTL.Text = "⚡ Реал-тайм лог"
RTTL.Font = Enum.Font.GothamBold
RTTL.TextSize = 13
RTTL.TextXAlignment = Enum.TextXAlignment.Left

local RTXB = Instance.new("TextButton", RTTB)
RTXB.Size = UDim2.new(0, 28, 0, 28)
RTXB.Position = UDim2.new(1, -32, 0, 4)
RTXB.BackgroundColor3 = Color3.fromRGB(160, 36, 54)
RTXB.Text = "✕"
RTXB.TextColor3 = Color3.new(1,1,1)
RTXB.Font = Enum.Font.GothamBold
RTXB.TextSize = 12
Instance.new("UICorner", RTXB).CornerRadius = UDim.new(0, 6)
RTXB.MouseButton1Up:Connect(function() RTF.Visible = false end)

RTLogBtn.MouseButton1Up:Connect(function() RTF.Visible = not RTF.Visible end)

-- RT кнопки-строка
local RTBtnRow = Instance.new("Frame", RTF)
RTBtnRow.Size = UDim2.new(1, -12, 0, 32)
RTBtnRow.Position = UDim2.new(0, 6, 0, 42)
RTBtnRow.BackgroundTransparency = 1
RTBtnRow.BorderSizePixel = 0
local RTBtnLay = Instance.new("UIListLayout", RTBtnRow)
RTBtnLay.FillDirection = Enum.FillDirection.Horizontal
RTBtnLay.SortOrder = Enum.SortOrder.LayoutOrder
RTBtnLay.Padding = UDim.new(0, 4)

local function makeRT2Btn(parent, text, color, order)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1/3, -3, 1, 0)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.BorderSizePixel = 0
    b.LayoutOrder = order
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local RTClrBtn  = makeRT2Btn(RTBtnRow, "🗑 Очистить",  Color3.fromRGB(90, 20, 20),  1)
local RTCopyBtn = makeRT2Btn(RTBtnRow, "📋 Копир.",    Color3.fromRGB(36, 90, 60),  2)
local RTSaveBtn = makeRT2Btn(RTBtnRow, "💾 В файл",    Color3.fromRGB(50, 60, 110), 3)

RTClrBtn.MouseButton1Up:Connect(function()
    rtBuf = {}
    if rtLogText then rtLogText.Text = "(пусто)" end
end)
RTCopyBtn.MouseButton1Up:Connect(function()
    local s = table.concat(rtBuf, "\n")
    if s == "" then RTCopyBtn.Text = "⚠ Пусто"
    elseif setclipboard then setclipboard(s); RTCopyBtn.Text = "✓ OK"
    else RTCopyBtn.Text = "⚠ Нет API" end
    task.delay(2, function() RTCopyBtn.Text = "📋 Копир." end)
end)
-- Ручной снимок текущего RT-лога в отдельный .txt
-- (живая запись в realtime_*.txt идёт сама, пока реал-тайм включён)
RTSaveBtn.MouseButton1Up:Connect(function()
    if not writefile then
        RTSaveBtn.Text = "⚠ Нет API"
    elseif #rtBuf == 0 then
        RTSaveBtn.Text = "⚠ Пусто"
    else
        local path = resolveDir() .. "realtime_snapshot_" .. tsNow() .. ".txt"
        local ok = pcall(writefile, path, table.concat(rtBuf, "\n"))
        RTSaveBtn.Text = ok and "✓ Сохранено" or "✗ Ошибка"
    end
    task.delay(2, function() RTSaveBtn.Text = "💾 В файл" end)
end)

-- RT scroll
local RTScr = Instance.new("ScrollingFrame", RTF)
RTScr.Size = UDim2.new(1, -8, 1, -88)
RTScr.Position = UDim2.new(0, 4, 0, 82)
RTScr.BackgroundColor3 = Color3.fromRGB(4, 10, 4)
RTScr.BorderSizePixel = 0
RTScr.ScrollBarThickness = 6
RTScr.ScrollBarImageColor3 = Color3.fromRGB(60, 180, 90)
RTScr.CanvasSize = UDim2.new(0, 0, 0, 0)
RTScr.AutomaticCanvasSize = Enum.AutomaticSize.Y
RTScr.ScrollingDirection = Enum.ScrollingDirection.Y
RTScr.ElasticBehavior = Enum.ElasticBehavior.Always
Instance.new("UICorner", RTScr).CornerRadius = UDim.new(0, 8)

local RTPad = Instance.new("UIPadding", RTScr)
RTPad.PaddingLeft  = UDim.new(0, 6)
RTPad.PaddingRight = UDim.new(0, 6)
RTPad.PaddingTop   = UDim.new(0, 6)
RTPad.PaddingBottom= UDim.new(0, 6)

rtLogText = Instance.new("TextLabel", RTScr)
rtLogText.Size = UDim2.new(1, 0, 0, 0)
rtLogText.AutomaticSize = Enum.AutomaticSize.Y
rtLogText.BackgroundTransparency = 1
rtLogText.TextColor3 = Color3.fromRGB(100, 240, 130)
rtLogText.Font = Enum.Font.Code
rtLogText.TextSize = 10
rtLogText.TextXAlignment = Enum.TextXAlignment.Left
rtLogText.TextYAlignment = Enum.TextYAlignment.Top
rtLogText.TextWrapped = true
rtLogText.Text = "(реал-тайм не запущен)"

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
-- ASYNC HELPER: запускает fn параллельно, возвращает join-функцию
-- ================================================================
local function asyncSection(fn)
    local done = false
    task.spawn(function()
        pcall(fn)
        done = true
    end)
    return function()
        while not done do task.wait() end
    end
end

-- ================================================================
-- ULTRA DUMP
-- ================================================================
local function doFullDump()
    DumpBtn.Text = "⏳ Дамп идёт..."
    DumpBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
    lc()
    local _dumpStart = tick()

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
    -- ── 14–16 запускаем ПАРАЛЛЕЛЬНО (тяжёлые секции) ─────────────
    -- ══════════════════════════════════════════════════════════════

    local join14 = asyncSection(function()
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
    end) -- end asyncSection 14

    local join15 = asyncSection(function()
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
    end) -- end asyncSection 15

    local join16 = asyncSection(function()
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
    end) -- end asyncSection 16

    -- Ждём завершения параллельных секций 14-16 перед 17
    join14(); join15(); join16()

    -- ══════════════════════════════════════════════════════════════
    -- ── 17. REMOTES FIREALL SPAM (NEW) — параллельно ─────────────
    -- ══════════════════════════════════════════════════════════════
    header("REMOTES FIREALL SPAM")
    pcall(function()
        -- Собираем списки заранее (не итерируем дважды)
        local reList, rfList = {}, {}
        for _, obj in ipairs(RS:GetDescendants()) do
            local c = obj.ClassName
            if c == "RemoteEvent" then
                table.insert(reList, obj)
            elseif c == "RemoteFunction" then
                table.insert(rfList, obj)
            end
        end

        -- FireServer — все параллельно, без wait
        lp("  Пробуем FireServer на " .. #reList .. " RE (параллельно)...")
        local fired, failed = 0, 0
        local reDone = 0
        for _, obj in ipairs(reList) do
            task.spawn(function()
                local ok, err = pcall(function() obj:FireServer() end)
                if ok then
                    fired += 1
                    lp("  [OK] " .. obj:GetFullName())
                else
                    failed += 1
                    lp("  [ERR] " .. obj:GetFullName() .. " => " .. tostring(err))
                end
                reDone += 1
            end)
        end
        -- Ждём завершения всех spawn (не блокируем надолго)
        local reTimeout = tick() + 5
        while reDone < #reList and tick() < reTimeout do task.wait() end
        lp("  Итого RE: OK=" .. fired .. " ERR=" .. failed)

        -- InvokeServer — параллельно
        lp("\n  Пробуем InvokeServer на " .. #rfList .. " RF (параллельно)...")
        local invoked, invFailed = 0, 0
        local rfDone = 0
        for _, obj in ipairs(rfList) do
            task.spawn(function()
                local ok, result = pcall(function() return obj:InvokeServer() end)
                if ok then
                    invoked += 1
                    local res = ""
                    pcall(function() res = HttpService:JSONEncode(result) end)
                    if res == "" then res = tostring(result) end
                    lp("  [OK] " .. obj:GetFullName() .. " => " .. res:sub(1, 120))
                else
                    invFailed += 1
                    lp("  [ERR] " .. obj:GetFullName() .. " => " .. tostring(result))
                end
                rfDone += 1
            end)
        end
        local rfTimeout = tick() + 8  -- InvokeServer медленнее
        while rfDone < #rfList and tick() < rfTimeout do task.wait() end
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
    local elapsed = math.floor((tick() - _dumpStart) * 10 + 0.5) / 10
    lp("  Время дампа : " .. elapsed .. " сек")

    -- Итоговый .txt (если executor даёт writefile)
    if autoSave then
        if writefile then
            local path = resolveDir() .. "dump_" .. tsNow() .. ".txt"
            lp("  Файл .txt   : " .. path)
            local ok, err = saveFullLog(path)
            if not ok then lp("  ✗ Ошибка записи txt: " .. tostring(err)) end
        else
            lp("  ✗ writefile недоступен — txt не создан (используй 📋 Копировать)")
        end
    end
    DumpBtn.Text = "✓ Готово за " .. elapsed .. "с"
    DumpBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 40)
    task.delay(4, function()
        DumpBtn.Text = "▶  Run Ultra Dump"
        DumpBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 90)
    end)
end

DumpBtn.MouseButton1Up:Connect(doFullDump)

-- ================================================================
-- ⚡ РЕАЛ-ТАЙМ ДВИЖОК — секции 21–24
-- ================================================================

-- ⚡ РЕАЛ-ТАЙМ ДВИЖОК v2 — ловит ВСЕ события, а не только валюту.
-- Подписки на события (Changed / DescendantAdded / OnClientEvent ...) вместо опроса.
-- Каждое событие: время + тип + путь + что изменилось. Всё пишется в realtime_*.txt.

local RT_CFG = {
    values     = true,  -- любые Value-объекты (Int/Number/String/Bool/Object...) у игроков, RS, Workspace
    attrs      = true,  -- атрибуты (Attributes) на объектах игроков / RS / персонажа
    structure  = true,  -- добавление / удаление объектов (инвентарь, предметы, трейды, GUI)
    gui        = true,  -- смена текста, Visible / Enabled у окон и попапов
    remotesIn  = true,  -- RemoteEvent сервер → клиент
    remotesOut = true,  -- FireServer / InvokeServer клиент → сервер (нужен hookmetamethod)
    bindables  = true,  -- BindableEvent внутри игры
    players    = true,  -- вход / выход игроков
    chat       = true,  -- сообщения чата
    character  = true,  -- спавн, смерть, здоровье, состояния персонажа
    purchases  = true,  -- покупки за Robux / геймпассы
    console    = true,  -- print / warn / error самой игры
    workspace  = true,  -- верхний уровень Workspace (новые объекты на карте)
}

local RT_FLUSH_INTERVAL = 2      -- как часто сбрасывать лог в .txt (сек)
local SPAM_LIMIT, SPAM_WINDOW = 8, 5   -- не больше 8 строк от одного источника за 5 сек

local RT_ROOTS = {
    { name = "Players",           mode = "full", structure = true  },
    { name = "ReplicatedStorage", mode = "full", structure = true  },
    { name = "Workspace",         mode = "lite", structure = false },
    { name = "ReplicatedFirst",   mode = "lite", structure = false },
    { name = "Lighting",          mode = "lite", structure = false },
    { name = "Teams",             mode = "lite", structure = false },
}

local _rtConns      = {}
local _rtHooked     = setmetatable({}, { __mode = "k" })
local _rtSpam       = {}
local _rtOutHooked  = false
local _rtSession    = 0
local _rtPG         = nil
local _rtCount      = { values = 0, remotes = 0, hooked = 0 }

local function rtConn(c)
    if c then table.insert(_rtConns, c) end
end

local function rtPath(inst)
    local ok, n = pcall(inst.GetFullName, inst)
    return ok and n or tostring(inst)
end

-- Сериализация аргументов (JSONEncode ломается на Instance / Vector3 и т.п.)
local function rtSer(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        return '"' .. v:sub(1, 100) .. '"'
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Instance" then
        return "<" .. rtPath(v) .. ">"
    elseif t == "table" then
        if depth >= 3 then return "{…}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 12 then
                parts[#parts + 1] = "…"
                break
            end
            parts[#parts + 1] = tostring(k) .. "=" .. rtSer(x, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return t .. ":" .. tostring(v)
end

local function rtArgs(args)
    local parts = {}
    for i = 1, args.n do parts[i] = rtSer(args[i]) end
    local s = table.concat(parts, ", ")
    if #s > 300 then s = s:sub(1, 300) .. "…" end
    return s
end

local function rtFmt(v)
    local t = typeof(v)
    if t == "string" then return "«" .. v:sub(1, 120) .. "»" end
    if t == "Instance" then return rtPath(v) end
    return tostring(v):sub(1, 120)
end

-- ── Антиспам: быстро меняющиеся таймеры / счётчики не забивают лог ──
local function rtSweepSpam(force)
    local now = tick()
    for k, s in pairs(_rtSpam) do
        if force or now - s.t0 > s.win then
            if s.skipped > 0 then
                rtLog("[спам скрыт] " .. k .. " — ещё " .. s.skipped .. " событий за " .. s.win .. "с")
            end
            _rtSpam[k] = nil
        end
    end
end

local function rtEvent(key, msg, limit, window)
    if not rtActive then return end
    limit  = limit  or SPAM_LIMIT
    window = window or SPAM_WINDOW
    local now = tick()
    local s = _rtSpam[key]
    if s and now - s.t0 > s.win then
        if s.skipped > 0 then
            rtLog("[спам скрыт] " .. key .. " — ещё " .. s.skipped .. " событий за " .. s.win .. "с")
        end
        s = nil
    end
    if not s then
        s = { t0 = now, n = 0, skipped = 0, win = window }
        _rtSpam[key] = s
    end
    s.n = s.n + 1
    if s.n > limit then
        s.skipped = s.skipped + 1
        return
    end
    rtLog(msg)
end

-- Каждую подписку на объект делаем один раз
local function once(inst, flag)
    local f = _rtHooked[inst]
    if not f then
        f = {}
        _rtHooked[inst] = f
    end
    if f[flag] then return false end
    f[flag] = true
    _rtCount.hooked = _rtCount.hooked + 1
    return true
end

-- ── Value-объекты: валюта, статы, любые счётчики ──
local function hookValue(inst)
    if not once(inst, "v") then return end
    _rtCount.values = _rtCount.values + 1
    local last
    pcall(function() last = inst.Value end)
    rtConn(inst.Changed:Connect(function(new)
        local old = last
        last = new
        if not rtActive then return end
        local path = rtPath(inst)
        local msg
        if type(new) == "number" and type(old) == "number" then
            local d = new - old
            msg = string.format("[ЗНАЧЕНИЕ] %s  %s%.6g  (было %.6g → стало %.6g)",
                path, d > 0 and "▲ +" or "▼ ", d, old, new)
        else
            msg = "[ЗНАЧЕНИЕ] " .. path .. "  " .. rtFmt(old) .. " → " .. rtFmt(new)
        end
        rtEvent("val:" .. path, msg)
    end))
end

-- ── Атрибуты ──
local function hookAttrs(inst)
    if not once(inst, "a") then return end
    local ok, prev = pcall(inst.GetAttributes, inst)
    if not ok then return end
    rtConn(inst.AttributeChanged:Connect(function(name)
        local new = inst:GetAttribute(name)
        local old = prev[name]
        prev[name] = new
        if not rtActive then return end
        local path = rtPath(inst) .. "@" .. name
        local msg
        if type(new) == "number" and type(old) == "number" then
            local d = new - old
            msg = string.format("[АТРИБУТ] %s  %s%.6g  (было %.6g → стало %.6g)",
                path, d > 0 and "▲ +" or "▼ ", d, old, new)
        else
            msg = "[АТРИБУТ] " .. path .. "  " .. rtFmt(old) .. " → " .. rtFmt(new)
        end
        rtEvent("attr:" .. path, msg)
    end))
end

-- ── GUI: смена текста, показ / скрытие окон и попапов ──
local function hookGui(inst, pg)
    if not pg or not inst:IsDescendantOf(pg) then return end

    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        if once(inst, "t") then
            local last = inst.Text
            rtConn(inst:GetPropertyChangedSignal("Text"):Connect(function()
                local new = inst.Text
                local old = last
                last = new
                if not rtActive or old == new or (old == "" and new == "") then return end
                local path = rtPath(inst)
                rtEvent("txt:" .. path,
                    "[GUI-текст] " .. path .. "  " .. rtFmt(old:sub(1, 80)) .. " → " .. rtFmt(new:sub(1, 80)),
                    6, 30)
            end))
        end
    end

    if inst:IsA("GuiObject") then
        if once(inst, "vis") then
            local last = inst.Visible
            rtConn(inst:GetPropertyChangedSignal("Visible"):Connect(function()
                local new = inst.Visible
                if not rtActive or new == last then return end
                last = new
                local path = rtPath(inst)
                rtEvent("vis:" .. path,
                    "[GUI-окно] " .. path .. " → " .. (new and "ПОКАЗАНО" or "СКРЫТО"), 6, 30)
            end))
        end
    elseif inst:IsA("ScreenGui") then
        if once(inst, "en") then
            local last = inst.Enabled
            rtConn(inst:GetPropertyChangedSignal("Enabled"):Connect(function()
                local new = inst.Enabled
                if not rtActive or new == last then return end
                last = new
                local path = rtPath(inst)
                rtEvent("en:" .. path,
                    "[GUI-экран] " .. path .. " → " .. (new and "ВКЛЮЧЁН" or "ВЫКЛЮЧЕН"), 6, 30)
            end))
        end
    end
end

-- ── Remote / Bindable события (сервер → клиент) ──
local function hookRemote(inst)
    if RT_CFG.remotesIn and (inst:IsA("RemoteEvent") or inst.ClassName == "UnreliableRemoteEvent") then
        if once(inst, "re") then
            _rtCount.remotes = _rtCount.remotes + 1
            rtConn(inst.OnClientEvent:Connect(function(...)
                if not rtActive then return end
                local args = table.pack(...)
                local path = rtPath(inst)
                rtEvent("re:" .. path, "[СЕРВЕР→КЛИЕНТ] " .. path .. "  args: " .. rtArgs(args), 20, 5)
            end))
        end
    elseif RT_CFG.bindables and inst:IsA("BindableEvent") then
        if once(inst, "be") then
            rtConn(inst.Event:Connect(function(...)
                if not rtActive then return end
                local args = table.pack(...)
                local path = rtPath(inst)
                rtEvent("be:" .. path, "[BINDABLE] " .. path .. "  args: " .. rtArgs(args), 20, 5)
            end))
        end
    end
end

-- mode "full" — всё; mode "lite" — только Value-объекты и remotes (для тяжёлого Workspace)
local function hookInstance(inst, mode, pg)
    if RT_CFG.values and inst:IsA("ValueBase") then hookValue(inst) end
    hookRemote(inst)
    if mode == "full" then
        if RT_CFG.attrs then hookAttrs(inst) end
        if RT_CFG.gui then hookGui(inst, pg) end
    end
end

-- Подписка на новые / удалённые объекты в дереве
local function watchTree(root, mode, withStructure)
    rtConn(root.DescendantAdded:Connect(function(d)
        if not rtActive then return end
        pcall(hookInstance, d, mode, _rtPG)
        if withStructure and RT_CFG.structure then
            local par = d.Parent and rtPath(d.Parent) or "?"
            local extra = ""
            if d:IsA("ValueBase") then
                pcall(function() extra = " = " .. rtFmt(d.Value) end)
            end
            rtEvent("add:" .. par,
                "[+ДОБАВЛЕНО] " .. rtPath(d) .. " [" .. d.ClassName .. "]" .. extra, 12, 5)
        end
    end))
    if withStructure and RT_CFG.structure then
        rtConn(root.DescendantRemoving:Connect(function(d)
            if not rtActive then return end
            local par = d.Parent and rtPath(d.Parent) or "?"
            rtEvent("del:" .. par,
                "[−УДАЛЕНО] " .. rtPath(d) .. " [" .. d.ClassName .. "]", 12, 5)
        end))
    end
end

-- Первичный проход по уже существующим объектам (с паузами, чтобы не фризить игру)
local function scanTree(root, mode, alive)
    local ok, list = pcall(root.GetDescendants, root)
    if not ok then return end
    for i = 1, #list do
        if not alive() then return end
        pcall(hookInstance, list[i], mode, _rtPG)
        if i % 1500 == 0 then task.wait() end
    end
end

-- ── Исходящие вызовы клиент → сервер (если executor умеет hookmetamethod) ──
local function rtHookOutgoing()
    if _rtOutHooked or not (hookmetamethod and getnamecallmethod) then return false end
    local ok = pcall(function()
        local old
        local hook = function(self, ...)
            local method = getnamecallmethod()
            if rtActive and RT_CFG.remotesOut
                and (method == "FireServer" or method == "InvokeServer") then
                local okc, cn = pcall(function() return self.ClassName end)
                if okc and (cn == "RemoteEvent" or cn == "RemoteFunction"
                    or cn == "UnreliableRemoteEvent") then
                    local args = table.pack(...)
                    task.defer(function()
                        local path = rtPath(self)
                        rtEvent("out:" .. path,
                            "[КЛИЕНТ→СЕРВЕР] " .. path .. "  " .. method .. "(" .. rtArgs(args) .. ")",
                            20, 5)
                    end)
                end
            end
            return old(self, ...)
        end
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(hook) or hook)
    end)
    _rtOutHooked = ok
    return ok
end

-- ── Игроки, чат, персонаж, покупки, консоль, верхний уровень Workspace ──
local function hookChatLegacy(p)
    if not once(p, "chat") then return end
    rtConn(p.Chatted:Connect(function(msg)
        rtEvent("chat", "[ЧАТ] " .. p.Name .. ": " .. tostring(msg):sub(1, 200), 20, 10)
    end))
end

local function hookCharacter(char, alive)
    if not RT_CFG.character or not char then return end
    rtLog("[ПЕРСОНАЖ] заспавнился: " .. rtPath(char))
    task.spawn(function()
        if alive() then
            scanTree(char, "full", alive)
            watchTree(char, "full", true)
        end
        local hum = char:WaitForChild("Humanoid", 5)
        if hum and alive() then
            rtConn(hum.Died:Connect(function() rtEvent("died", "[ПЕРСОНАЖ] умер", 5, 5) end))
            local lastHp = hum.Health
            rtConn(hum.HealthChanged:Connect(function(hp)
                local d = hp - lastHp
                lastHp = hp
                rtEvent("hp", string.format("[ПЕРСОНАЖ] здоровье %.4g (%s%.4g)",
                    hp, d >= 0 and "+" or "", d), 10, 5)
            end))
            rtConn(hum.StateChanged:Connect(function(o, n)
                rtEvent("state", "[ПЕРСОНАЖ] состояние " .. tostring(o) .. " → " .. tostring(n), 10, 5)
            end))
        end
    end)
end

local function rtWatchExtras(alive)
    -- игроки
    if RT_CFG.players then
        rtConn(Players.PlayerAdded:Connect(function(p)
            rtLog("[ИГРОК +] " .. p.Name .. " (" .. p.DisplayName .. ")")
        end))
        rtConn(Players.PlayerRemoving:Connect(function(p)
            rtLog("[ИГРОК −] " .. p.Name .. " (" .. p.DisplayName .. ")")
        end))
    end

    -- чат
    if RT_CFG.chat then
        local usedTCS = false
        pcall(function()
            local TCS = game:GetService("TextChatService")
            if TCS.ChatVersion == Enum.ChatVersion.TextChatService then
                usedTCS = true
                rtConn(TCS.MessageReceived:Connect(function(m)
                    local who = m.TextSource and m.TextSource.Name or "система"
                    rtEvent("chat", "[ЧАТ] " .. who .. ": " .. tostring(m.Text):sub(1, 200), 20, 10)
                end))
            end
        end)
        if not usedTCS then
            for _, p in ipairs(Players:GetPlayers()) do hookChatLegacy(p) end
            rtConn(Players.PlayerAdded:Connect(hookChatLegacy))
        end
    end

    -- персонаж
    if RT_CFG.character then
        if LP.Character then hookCharacter(LP.Character, alive) end
        rtConn(LP.CharacterAdded:Connect(function(c) hookCharacter(c, alive) end))
        rtConn(LP.CharacterRemoving:Connect(function() rtLog("[ПЕРСОНАЖ] удалён") end))
    end

    -- покупки
    if RT_CFG.purchases then
        local MPS = game:GetService("MarketplaceService")
        pcall(function()
            rtConn(MPS.PromptProductPurchaseFinished:Connect(function(uid, pid, bought)
                rtLog("[ПОКУПКА] продукт " .. tostring(pid) .. " user " .. tostring(uid)
                    .. " → " .. (bought and "куплено" or "отмена"))
            end))
        end)
        pcall(function()
            rtConn(MPS.PromptGamePassPurchaseFinished:Connect(function(plr, id, bought)
                rtLog("[ПОКУПКА] геймпасс " .. tostring(id) .. " → " .. (bought and "куплено" or "отмена"))
            end))
        end)
        pcall(function()
            rtConn(MPS.PromptPurchaseFinished:Connect(function(plr, id, bought)
                rtLog("[ПОКУПКА] ассет " .. tostring(id) .. " → " .. (bought and "куплено" or "отмена"))
            end))
        end)
    end

    -- консоль игры (print / warn / error)
    if RT_CFG.console then
        pcall(function()
            local LS = game:GetService("LogService")
            rtConn(LS.MessageOut:Connect(function(msg, mtype)
                local kind = "OUT"
                if mtype == Enum.MessageType.MessageError then kind = "ERR"
                elseif mtype == Enum.MessageType.MessageWarning then kind = "WARN" end
                rtEvent("con:" .. msg:sub(1, 40), "[КОНСОЛЬ " .. kind .. "] " .. msg:sub(1, 250), 3, 10)
            end))
        end)
    end

    -- верхний уровень Workspace
    if RT_CFG.workspace then
        rtConn(workspace.ChildAdded:Connect(function(c)
            rtEvent("wsadd", "[WORKSPACE +] " .. c.Name .. " [" .. c.ClassName .. "]", 15, 5)
        end))
        rtConn(workspace.ChildRemoved:Connect(function(c)
            rtEvent("wsdel", "[WORKSPACE −] " .. c.Name .. " [" .. c.ClassName .. "]", 15, 5)
        end))
    end

    -- исходящие ремоуты
    if RT_CFG.remotesOut then
        if not rtHookOutgoing() and not _rtOutHooked then
            rtLog("  (!) hookmetamethod недоступен — исходящие FireServer не логируются")
        end
    end
end

-- ── Запуск / остановка ──
local function startRealtime()
    if rtActive then return end
    rtActive = true
    _rtSession = _rtSession + 1
    local session = _rtSession
    local function alive() return rtActive and _rtSession == session end

    rtBuf, rtPending = {}, {}
    _rtSpam = {}
    _rtHooked = setmetatable({}, { __mode = "k" })
    _rtConns = {}
    _rtCount = { values = 0, remotes = 0, hooked = 0 }
    _rtPG = LP:FindFirstChildOfClass("PlayerGui")

    -- RT .txt файл (пишется всё время, пока реал-тайм включён)
    rtFile = nil
    if writefile then
        local ok = pcall(function()
            local path = resolveDir() .. "realtime_" .. tsNow() .. ".txt"
            writefile(path, "=== РЕАЛ-ТАЙМ " .. tsNow() .. " ===\n")
            rtFile = path
        end)
        if not ok then rtFile = nil end
    end

    rtLog("=== Реал-тайм запущен ===")
    rtLog("  Файл: " .. (rtFile or "НЕТ (writefile недоступен — запись в txt невозможна)"))
    local on = {}
    for k, v in pairs(RT_CFG) do if v then on[#on + 1] = k end end
    table.sort(on)
    rtLog("  Ловим: " .. table.concat(on, ", "))

    rtThread = task.spawn(function()
        -- 1) подписки на новые события
        for _, r in ipairs(RT_ROOTS) do
            local ok, svc = pcall(game.GetService, game, r.name)
            if ok and svc then pcall(watchTree, svc, r.mode, r.structure) end
        end
        pcall(rtWatchExtras, alive)

        -- 2) подписка на всё, что уже существует
        task.spawn(function()
            for _, r in ipairs(RT_ROOTS) do
                if not alive() then return end
                local ok, svc = pcall(game.GetService, game, r.name)
                if ok and svc then scanTree(svc, r.mode, alive) end
            end
            if alive() then
                rtLog(string.format("  Подписано: объектов %d, Value %d, Remote %d",
                    _rtCount.hooked, _rtCount.values, _rtCount.remotes))
            end
        end)

        -- 3) периодический сброс в файл + чистка антиспама
        while alive() do
            task.wait(RT_FLUSH_INTERVAL)
            pcall(rtSweepSpam)
            rtFlush()
        end
    end)

    RTBtn.Text = "⚡  Реал-тайм: ВКЛ"
    RTBtn.BackgroundColor3 = Color3.fromRGB(30, 110, 50)
    RTF.Visible = true
end

local function stopRealtime()
    if not rtActive then return end
    rtActive = false
    for _, c in ipairs(_rtConns) do
        pcall(function() c:Disconnect() end)
    end
    _rtConns = {}
    rtThread = nil
    rtSweepSpam(true)
    rtLog("=== Реал-тайм остановлен ===")
    rtFlush()
    RTBtn.Text = "⚡  Реал-тайм: ВЫКЛ"
    RTBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 20)
end

RTBtn.MouseButton1Up:Connect(function()
    if rtActive then stopRealtime() else startRealtime() end
end)

-- Останавливаем RT при выходе из игры
LP.AncestryChanged:Connect(function()
    stopRealtime()
end)
