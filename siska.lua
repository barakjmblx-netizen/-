-- ╔══════════════════════════════════════════════╗
-- ║  Piska.lua v4 — Fixed GUI + New Dump         ║
-- ║  Game: 120219252362013 | v1221               ║
-- ╚══════════════════════════════════════════════╝

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local lp      = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

if not Remotes then
    warn("[Z] Remotes not found!")
    return
end

-- ╔══════════════╗
-- ║    CONFIG    ║
-- ╚══════════════╝
local CFG = {
    AutoTrain       = false,
    AutoThrow       = false,
    AutoEquipBest   = false,
    AutoInjectStats = false,
    InjectInterval  = 1.0,
    StatMoney       = "$999B",
    StatPower       = 99999,
    StatMPS         = "$999M/s",
    SkipThrowAnim   = true,
}

-- ╔══════════════════╗
-- ║  REMOTE HELPERS  ║
-- ╚══════════════════╝
local function rf(name, ...)
    local r = Remotes:FindFirstChild(name)
    if r and r:IsA("RemoteFunction") then
        local ok, res = pcall(r.InvokeServer, r, ...)
        if ok then return res end
    end
end

-- ╔═══════════════╗
-- ║  FARM LOOPS   ║
-- ╚═══════════════╝
local threads = {}

local function killThread(key)
    if threads[key] then
        task.cancel(threads[key])
        threads[key] = nil
    end
end

local function startTrain()
    killThread("train")
    threads["train"] = task.spawn(function()
        while CFG.AutoTrain do
            local ok = rf("Training_Start")
            if ok then
                for _ = 1, 60 do
                    if not CFG.AutoTrain then break end
                    rf("Training_TapBonus")
                    task.wait(0.03)
                end
                rf("Training_Stop")
            end
            task.wait(0.2)
        end
    end)
end

local frozenTracks = {}
local function freezeAnims(state)
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if state then
        for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
            frozenTracks[t] = t.Speed
            t:AdjustSpeed(0)
        end
    else
        for t, spd in pairs(frozenTracks) do
            pcall(t.AdjustSpeed, t, spd)
        end
        frozenTracks = {}
    end
end

local function startThrow()
    killThread("throw")
    threads["throw"] = task.spawn(function()
        while CFG.AutoThrow do
            -- найти throw zone
            local ws = game:GetService("Workspace")
            local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            for _, kw in ipairs({"ThrowZone","ThrowPad","ThrowPoint","LaunchPad","Throw"}) do
                local obj = ws:FindFirstChild(kw, true)
                if obj and obj:IsA("BasePart") and hrp then
                    if (hrp.Position - obj.Position).Magnitude > 20 then
                        hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0,3,0))
                        task.wait(0.1)
                    end
                    break
                end
            end
            if CFG.SkipThrowAnim then freezeAnims(true) end
            local data = rf("Throw_Start")
            if data then
                rf("Throw_Resolve", data)
                rf("Throw_Complete")
            end
            if CFG.SkipThrowAnim then task.defer(function() freezeAnims(false) end) end
            task.wait(0.15)
        end
    end)
end

local function startEquip()
    killThread("equip")
    threads["equip"] = task.spawn(function()
        while CFG.AutoEquipBest do
            rf("Plot_EquipBest")
            task.wait(8)
        end
    end)
end

local function startInject()
    killThread("inject")
    threads["inject"] = task.spawn(function()
        while CFG.AutoInjectStats do
            local stats = lp:FindFirstChild("leaderstats")
            if stats then
                local m = stats:FindFirstChild("Money")
                local p = stats:FindFirstChild("Throw Power")
                local r = stats:FindFirstChild("Money/s")
                if m then pcall(function() m.Value = CFG.StatMoney end) end
                if p then pcall(function() p.Value = CFG.StatPower end) end
                if r then pcall(function() r.Value = CFG.StatMPS   end) end
            end
            rf("Player_SetThrowPower", CFG.StatPower)
            task.wait(CFG.InjectInterval)
        end
    end)
end

local function injectOnce()
    local stats = lp:FindFirstChild("leaderstats")
    if stats then
        local m = stats:FindFirstChild("Money")
        local p = stats:FindFirstChild("Throw Power")
        local r = stats:FindFirstChild("Money/s")
        if m then pcall(function() m.Value = CFG.StatMoney end) end
        if p then pcall(function() p.Value = CFG.StatPower end) end
        if r then pcall(function() r.Value = CFG.StatMPS   end) end
    end
    rf("Player_SetThrowPower", CFG.StatPower)
end

-- ╔══════════════════════════════════════╗
-- ║  GUI                                 ║
-- ╚══════════════════════════════════════╝
local C = {
    bg       = Color3.fromRGB(13,13,20),
    panel    = Color3.fromRGB(22,24,36),
    accent   = Color3.fromRGB(55,120,255),
    dim      = Color3.fromRGB(28,55,130),
    on       = Color3.fromRGB(30,165,80),
    off      = Color3.fromRGB(165,40,40),
    text     = Color3.fromRGB(210,215,230),
    sub      = Color3.fromRGB(110,115,145),
    head     = Color3.fromRGB(80,145,255),
    inputBg  = Color3.fromRGB(18,20,32),
    green    = Color3.fromRGB(100,220,130),
}
local FB = Enum.Font.GothamBold
local FR = Enum.Font.Gotham
local FM = Enum.Font.Code

local function mkCorner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 7)
end
local function mkStroke(p, col, th)
    local s = Instance.new("UIStroke", p)
    s.Color = col or C.accent; s.Thickness = th or 1.5
end
local function mkPad(p, l, r, t, b)
    local pad = Instance.new("UIPadding", p)
    pad.PaddingLeft   = UDim.new(0, l or 0)
    pad.PaddingRight  = UDim.new(0, r or 0)
    pad.PaddingTop    = UDim.new(0, t or 0)
    pad.PaddingBottom = UDim.new(0, b or 0)
end
local function mkList(p, dir, pad)
    local l = Instance.new("UIListLayout", p)
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Padding       = UDim.new(0, pad or 4)
    return l
end

local function buildGui()
    -- чисто сносим старый
    local old = lp.PlayerGui:FindFirstChild("ZFarm")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name           = "ZFarm"
    gui.ResetOnSpawn   = false
    gui.DisplayOrder   = 999
    gui.IgnoreGuiInset = true
    gui.Parent         = lp.PlayerGui

    -- ── MAIN FRAME ──────────────────────────────────
    local main = Instance.new("Frame", gui)
    main.Size             = UDim2.new(0, 310, 0, 480)
    main.Position         = UDim2.new(0.5,-155, 0.5,-240)
    main.BackgroundColor3 = C.bg
    main.BorderSizePixel  = 0
    main.Active           = true
    main.Draggable        = true
    mkCorner(main, 12)
    mkStroke(main, C.accent, 1.5)

    -- ── HEADER ──────────────────────────────────────
    local header = Instance.new("Frame", main)
    header.Size             = UDim2.new(1,0, 0,40)
    header.BackgroundColor3 = C.dim
    header.BorderSizePixel  = 0
    mkCorner(header, 12)

    local htitle = Instance.new("TextLabel", header)
    htitle.Size                = UDim2.new(1,-50, 1,0)
    htitle.Position            = UDim2.new(0,14, 0,0)
    htitle.BackgroundTransparency = 1
    htitle.Text                = "⚡ Z FARM  v4"
    htitle.TextColor3          = Color3.fromRGB(220,235,255)
    htitle.TextSize            = 15
    htitle.Font                = FB
    htitle.TextXAlignment      = Enum.TextXAlignment.Left

    local minBtn = Instance.new("TextButton", header)
    minBtn.Size             = UDim2.new(0,30,0,24)
    minBtn.Position         = UDim2.new(1,-36, 0.5,-12)
    minBtn.BackgroundColor3 = Color3.fromRGB(45,50,75)
    minBtn.Text             = "—"
    minBtn.TextColor3       = C.text
    minBtn.TextSize         = 14
    minBtn.Font             = FB
    minBtn.BorderSizePixel  = 0
    mkCorner(minBtn, 5)

    -- ── TABBAR ──────────────────────────────────────
    local tabBar = Instance.new("Frame", main)
    tabBar.Size             = UDim2.new(1,-16, 0,30)
    tabBar.Position         = UDim2.new(0,8, 0,44)
    tabBar.BackgroundColor3 = C.panel
    tabBar.BorderSizePixel  = 0
    mkCorner(tabBar, 7)
    mkList(tabBar, Enum.FillDirection.Horizontal, 2)
    mkPad(tabBar, 3,3,3,3)

    -- ── SCROLL ──────────────────────────────────────
    local scroll = Instance.new("ScrollingFrame", main)
    scroll.Size                = UDim2.new(1,-16, 1,-128)
    scroll.Position            = UDim2.new(0,8, 0,78)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel     = 0
    scroll.ScrollBarThickness  = 3
    scroll.ScrollBarImageColor3 = C.accent
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize          = UDim2.new(0,0,0,0)
    mkList(scroll, Enum.FillDirection.Vertical, 4)
    mkPad(scroll, 0,4,0,8)

    -- ── STATUS BAR ──────────────────────────────────
    local sbar = Instance.new("Frame", main)
    sbar.Size             = UDim2.new(1,-16, 0,36)
    sbar.Position         = UDim2.new(0,8, 1,-44)
    sbar.BackgroundColor3 = C.panel
    sbar.BorderSizePixel  = 0
    mkCorner(sbar, 7)

    local slbl = Instance.new("TextLabel", sbar)
    slbl.Size               = UDim2.new(1,-12, 1,0)
    slbl.Position           = UDim2.new(0,8, 0,0)
    slbl.BackgroundTransparency = 1
    slbl.TextColor3         = C.green
    slbl.TextSize           = 11
    slbl.Font               = FM
    slbl.TextXAlignment     = Enum.TextXAlignment.Left
    slbl.Text               = "loading..."

    task.spawn(function()
        while gui and gui.Parent do
            local s = lp:FindFirstChild("leaderstats")
            if s then
                local m = s:FindFirstChild("Money")
                local p = s:FindFirstChild("Throw Power")
                local r = s:FindFirstChild("Money/s")
                slbl.Text = ("💰 %s   ⚡ %s   📈 %s"):format(
                    m and tostring(m.Value) or "?",
                    p and tostring(p.Value) or "?",
                    r and tostring(r.Value) or "?"
                )
            end
            task.wait(0.5)
        end
    end)

    -- ══════════════════════════════════════════════
    -- TAB SYSTEM
    -- Каждый таб = отдельный Frame в scroll,
    -- просто Visible=true/false — надёжнее чем менять Parent
    -- ══════════════════════════════════════════════
    local tabBtns    = {}
    local tabFrames  = {}
    local activeTab  = nil

    local function switchTab(name)
        for n, f in pairs(tabFrames) do
            f.Visible = (n == name)
        end
        for n, b in pairs(tabBtns) do
            if n == name then
                b.BackgroundColor3 = C.accent
                b.TextColor3       = Color3.fromRGB(255,255,255)
            else
                b.BackgroundColor3 = Color3.fromRGB(32,36,55)
                b.TextColor3       = C.sub
            end
        end
        activeTab = name
        -- сброс скролла
        scroll.CanvasPosition = Vector2.new(0,0)
    end

    local tabOrder = 0
    local function addTab(name, icon)
        tabOrder = tabOrder + 1

        local btn = Instance.new("TextButton", tabBar)
        btn.Size             = UDim2.new(0.24,-2, 1,0)
        btn.BackgroundColor3 = Color3.fromRGB(32,36,55)
        btn.Text             = icon.." "..name
        btn.TextColor3       = C.sub
        btn.TextSize         = 11
        btn.Font             = FB
        btn.BorderSizePixel  = 0
        btn.LayoutOrder      = tabOrder
        mkCorner(btn, 5)
        tabBtns[name] = btn

        -- фрейм-контейнер внутри scroll
        local frame = Instance.new("Frame", scroll)
        frame.Size             = UDim2.new(1,0, 0,0)
        frame.AutomaticSize    = Enum.AutomaticSize.Y
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel  = 0
        frame.Visible          = false
        frame.LayoutOrder      = tabOrder
        mkList(frame, Enum.FillDirection.Vertical, 4)
        tabFrames[name] = frame

        btn.MouseButton1Click:Connect(function() switchTab(name) end)
        return frame
    end

    -- ── Helpers для строк внутри таба ──────────────

    local function addSection(parent, text)
        local lbl = Instance.new("TextLabel", parent)
        lbl.Size               = UDim2.new(1,0, 0,16)
        lbl.BackgroundTransparency = 1
        lbl.Text               = text
        lbl.TextColor3         = C.head
        lbl.TextSize           = 10
        lbl.Font               = FB
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        mkPad(lbl, 4,0,0,0)
        return lbl
    end

    local function addToggleRow(parent, label, cfgKey, onToggle)
        local row = Instance.new("Frame", parent)
        row.Size             = UDim2.new(1,0, 0,36)
        row.BackgroundColor3 = C.panel
        row.BorderSizePixel  = 0
        mkCorner(row, 7)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size               = UDim2.new(1,-70, 1,0)
        lbl.Position           = UDim2.new(0,10, 0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text               = label
        lbl.TextColor3         = C.text
        lbl.TextSize           = 13
        lbl.Font               = FR
        lbl.TextXAlignment     = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", row)
        btn.Size             = UDim2.new(0,56, 0,24)
        btn.Position         = UDim2.new(1,-62, 0.5,-12)
        btn.BackgroundColor3 = CFG[cfgKey] and C.on or C.off
        btn.Text             = CFG[cfgKey] and "ON" or "OFF"
        btn.TextColor3       = Color3.fromRGB(255,255,255)
        btn.TextSize         = 12
        btn.Font             = FB
        btn.BorderSizePixel  = 0
        mkCorner(btn, 5)

        btn.MouseButton1Click:Connect(function()
            CFG[cfgKey] = not CFG[cfgKey]
            btn.BackgroundColor3 = CFG[cfgKey] and C.on or C.off
            btn.Text             = CFG[cfgKey] and "ON" or "OFF"
            if onToggle then onToggle(CFG[cfgKey]) end
        end)
        return btn
    end

    local function addInputRow(parent, label, cfgKey, isNum)
        local row = Instance.new("Frame", parent)
        row.Size             = UDim2.new(1,0, 0,36)
        row.BackgroundColor3 = C.panel
        row.BorderSizePixel  = 0
        mkCorner(row, 7)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size               = UDim2.new(0.38,0, 1,0)
        lbl.Position           = UDim2.new(0,10, 0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text               = label
        lbl.TextColor3         = C.sub
        lbl.TextSize           = 12
        lbl.Font               = FR
        lbl.TextXAlignment     = Enum.TextXAlignment.Left

        local box = Instance.new("TextBox", row)
        box.Size             = UDim2.new(0,110, 0,24)
        box.Position         = UDim2.new(0.4,0, 0.5,-12)
        box.BackgroundColor3 = C.inputBg
        box.Text             = tostring(CFG[cfgKey])
        box.TextColor3       = Color3.fromRGB(170,215,255)
        box.TextSize         = 12
        box.Font             = FM
        box.ClearTextOnFocus = false
        box.BorderSizePixel  = 0
        mkCorner(box, 5)
        mkStroke(box, C.dim, 1)
        mkPad(box, 6,6,0,0)

        local setBtn = Instance.new("TextButton", row)
        setBtn.Size             = UDim2.new(0,38, 0,24)
        setBtn.Position         = UDim2.new(1,-44, 0.5,-12)
        setBtn.BackgroundColor3 = C.accent
        setBtn.Text             = "SET"
        setBtn.TextColor3       = Color3.fromRGB(255,255,255)
        setBtn.TextSize         = 11
        setBtn.Font             = FB
        setBtn.BorderSizePixel  = 0
        mkCorner(setBtn, 5)

        local function apply(val)
            if isNum then
                local n = tonumber(val)
                if n then CFG[cfgKey] = n end
            else
                CFG[cfgKey] = val
            end
            box.Text = tostring(CFG[cfgKey])
            setBtn.BackgroundColor3 = C.on
            task.delay(0.5, function() setBtn.BackgroundColor3 = C.accent end)
        end
        setBtn.MouseButton1Click:Connect(function() apply(box.Text) end)
        box.FocusLost:Connect(function(enter) if enter then apply(box.Text) end end)
    end

    local function addActionBtn(parent, label, color, onClick)
        local row = Instance.new("Frame", parent)
        row.Size             = UDim2.new(1,0, 0,34)
        row.BackgroundColor3 = C.panel
        row.BorderSizePixel  = 0
        mkCorner(row, 7)

        local btn = Instance.new("TextButton", row)
        btn.Size             = UDim2.new(1,-16, 0,24)
        btn.Position         = UDim2.new(0,8, 0.5,-12)
        btn.BackgroundColor3 = color or C.accent
        btn.Text             = label
        btn.TextColor3       = Color3.fromRGB(255,255,255)
        btn.TextSize         = 12
        btn.Font             = FB
        btn.BorderSizePixel  = 0
        mkCorner(btn, 5)

        btn.MouseButton1Click:Connect(function()
            onClick()
            local orig = btn.BackgroundColor3
            btn.BackgroundColor3 = C.on
            task.delay(0.4, function() btn.BackgroundColor3 = orig end)
        end)
        return btn
    end

    local function addGuiToggle(parent, guiName)
        local row = Instance.new("Frame", parent)
        row.Size             = UDim2.new(1,0, 0,30)
        row.BackgroundColor3 = C.panel
        row.BorderSizePixel  = 0
        mkCorner(row, 6)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size               = UDim2.new(1,-68, 1,0)
        lbl.Position           = UDim2.new(0,8, 0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text               = guiName
        lbl.TextColor3         = C.text
        lbl.TextSize           = 11
        lbl.Font               = FM
        lbl.TextXAlignment     = Enum.TextXAlignment.Left

        local function getState()
            local g = lp.PlayerGui:FindFirstChild(guiName)
            return g and g:IsA("ScreenGui") and g.Enabled or false
        end

        local btn = Instance.new("TextButton", row)
        btn.Size             = UDim2.new(0,52, 0,20)
        btn.Position         = UDim2.new(1,-58, 0.5,-10)
        btn.BackgroundColor3 = getState() and C.on or C.off
        btn.Text             = getState() and "ON" or "OFF"
        btn.TextColor3       = Color3.fromRGB(255,255,255)
        btn.TextSize         = 11
        btn.Font             = FB
        btn.BorderSizePixel  = 0
        mkCorner(btn, 4)

        btn.MouseButton1Click:Connect(function()
            local g = lp.PlayerGui:FindFirstChild(guiName)
            if g and g:IsA("ScreenGui") then
                g.Enabled            = not g.Enabled
                btn.BackgroundColor3 = g.Enabled and C.on or C.off
                btn.Text             = g.Enabled and "ON" or "OFF"
            end
        end)
    end

-- ══════════════════════════════════════════════
    -- ТАБ 1: FARM
    -- ══════════════════════════════════════════════
    local farmF = addTab("Farm", "🌾")

    addSection(farmF, "── ТРЕНИРОВКА ──")
    addToggleRow(farmF, "🏋️ Auto Train", "AutoTrain", function(v)
        if v then startTrain() else killThread("train") rf("Training_Stop") end
    end)

    addSection(farmF, "── ЖИВОТНЫЕ ──")
    addToggleRow(farmF, "🐾 Auto Equip Best", "AutoEquipBest", function(v)
        if v then startEquip() else killThread("equip") end
    end)
    addActionBtn(farmF, "⚡ Equip Best NOW",
        Color3.fromRGB(40,80,160), function() rf("Plot_EquipBest") end)

    addSection(farmF, "── ПРОДАЖА ──")
    addActionBtn(farmF, "💸 Sell All NOW",
        Color3.fromRGB(160,80,40), function() rf("Plot_SellAll") end)

    -- ══════════════════════════════════════════════
    -- ТАБ 2: THROW
    -- ══════════════════════════════════════════════
    local throwF = addTab("Throw", "🎯")

    addSection(throwF, "── АВТО БРОСОК ──")
    addToggleRow(throwF, "🎯 Auto Throw", "AutoThrow", function(v)
        if v then startThrow() else killThread("throw") end
    end)
    addToggleRow(throwF, "⚡ Skip Animations", "SkipThrowAnim", nil)

    addSection(throwF, "── INFO ──")
    local infoLbl = Instance.new("TextLabel", throwF)
    infoLbl.Size               = UDim2.new(1,0, 0,54)
    infoLbl.BackgroundColor3   = C.panel
    infoLbl.Text               = "Авто-бросок телепортирует к точке броска\nесли дальше 20 studs, скипает анимацию.\nТелепорт тихий — не мешает управлению."
    infoLbl.TextColor3         = C.sub
    infoLbl.TextSize           = 11
    infoLbl.Font               = FR
    infoLbl.TextWrapped        = true
    infoLbl.TextXAlignment     = Enum.TextXAlignment.Left
    infoLbl.TextYAlignment     = Enum.TextYAlignment.Top
    infoLbl.BorderSizePixel    = 0
    mkCorner(infoLbl, 7)
    mkPad(infoLbl, 8,8,6,6)

    -- ══════════════════════════════════════════════
    -- ТАБ 3: STATS
    -- ══════════════════════════════════════════════
    local statsF = addTab("Stats", "📊")

    addSection(statsF, "── ЗНАЧЕНИЯ ──")
    addInputRow(statsF, "💰 Money",     "StatMoney", false)
    addInputRow(statsF, "⚡ Power",     "StatPower", true)
    addInputRow(statsF, "📈 Money/s",  "StatMPS",   false)

    addSection(statsF, "── ИНЖЕКТ ──")
    addToggleRow(statsF, "🔄 Auto Inject", "AutoInjectStats", function(v)
        if v then startInject() else killThread("inject") end
    end)
    addActionBtn(statsF, "💉 Inject Once",
        Color3.fromRGB(90,50,180), injectOnce)

    -- ══════════════════════════════════════════════
    -- ТАБ 4: GUI
    -- ══════════════════════════════════════════════
    local guiF = addTab("GUI", "🖥")

    addSection(guiF, "── PLAYER GUI SCREENS ──")

    -- актуальный список из нового дампа
    local guiList = {
        "StudioAnimals","ScreenFX","HUD","IndexGui",
        "AnimalsPanelGui","SellShop","ProtectedSell","BackpackGui",
        "ShopRewards","Announcements","ServerLuckHUD","GiftMenu",
        "GiftRequest","Tutorial","UpgradePopup","AdminAbuse",
        "AdminVote","AdminAbuseEffects","AdminFlash","OfflineReminder",
        "PackOffer","TopbarCenteredClipped","TopbarStandardClipped",
        "TopbarStandard","TopbarCentered","TrainingGui","FoodShop",
        "StatsGui","ExclusiveShop","TouchGui","OfflineEarnings",
        "GamepadHints",
    }
    for _, name in ipairs(guiList) do
        addGuiToggle(guiF, name)
    end

    -- ══════════════════════════════════════════════
    -- Minimize
    -- ══════════════════════════════════════════════
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        tabBar.Visible  = not minimized
        scroll.Visible  = not minimized
        sbar.Visible    = not minimized
        main.Size = minimized
            and UDim2.new(0,310, 0,42)
            or  UDim2.new(0,310, 0,480)
        minBtn.Text = minimized and "▲" or "—"
    end)

    -- дефолтный таб
    switchTab("Farm")
end

-- ╔══════════════════╗
-- ║  HOTKEY           ║
-- ╚══════════════════╝
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightControl then
        local g = lp.PlayerGui:FindFirstChild("ZFarm")
        if g then g.Enabled = not g.Enabled end
    end
end)

-- ╔══════════════════╗
-- ║  INIT            ║
-- ╚══════════════════╝
task.wait(2)
buildGui()
print("[Z] v4 loaded ✓  |  RCtrl = show/hide")