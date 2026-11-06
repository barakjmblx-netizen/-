-- ╔══════════════════════════════════════════════╗
-- ║  Piska.lua v5.1                              ║
-- ║  Game: 120219252362013 | PlaceVersion 1221   ║
-- ╚══════════════════════════════════════════════╝

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

local lp      = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
assert(Remotes, "[Z] Remotes not found")

-- ╔══════════════╗
-- ║    CONFIG    ║
-- ╚══════════════╝
local CFG = {
    -- Farm
    AutoTrain        = false,
    AutoThrow        = false,
    AutoEquipBest    = false,

    -- Stat farm (легитимные RF)
    AutoPowerFarm    = false,   -- спам Training_TapBonus без анимации
    AutoMoneyFarm    = false,   -- спам Plot_SellAll без анимации
    PowerTapRate     = 0.01,    -- секунд между тапами (чем меньше — тем быстрее)
    SellRate         = 0.5,     -- секунд между продажами

    -- Прямой инжект (fallback)
    AutoInjectStats  = false,
    InjectInterval   = 0.5,
    StatMoney        = "$999B",
    StatPower        = 99999,
    StatMPS          = "$999M/s",

    -- Throw
    HideThrowAnim    = true,
    BlockReturnTP    = true,
    HideTrainAnim    = true,
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

-- ╔═══════════════════════════════════════════════╗
-- ║  POWER FARM — имитируем тренировку            ║
-- ║  Training_Start → много TapBonus → Stop       ║
-- ║  Сервер сам начисляет power по своей логике   ║
-- ╚═══════════════════════════════════════════════╝
-- Как это работает в игре:
-- 1. Training_Start — открывает сессию тренировки на сервере
-- 2. Training_TapBonus — каждый вызов = один тап = +power (сервер считает)
-- 3. Training_Stop — закрывает сессию, фиксирует результат
-- Мы делаем то же самое но без анимации и GUI

local function hideTrainingGui(state)
    local tg = lp.PlayerGui:FindFirstChild("TrainingGui")
    if tg then tg.Enabled = not state end
end

-- ╔═══════════════════════════════════════════════╗
-- ║  MONEY FARM — имитируем продажу петов         ║
-- ║  Plot_SellAll → сервер считает доход          ║
-- ║  Plot_EquipBest → лучший пет → больше Money/s ║
-- ╚═══════════════════════════════════════════════╝
-- Как это работает:
-- 1. Plot_EquipBest — сервер экипирует лучшего пета
-- 2. Plot_SellAll   — продаёт всё накопленное в загоне
-- Деньги начисляются сервером легитимно
-- Money/s растёт от качества экипированного пета

-- ╔═════════════════╗
-- ║  THREADS        ║
-- ╚═════════════════╝
local threads = {}
local function killThread(key)
    if threads[key] then task.cancel(threads[key]); threads[key] = nil end
end

-- ── AUTO TRAIN (полный цикл, фоновый) ───────────
local function startTrain()
    killThread("train")
    threads["train"] = task.spawn(function()
        while CFG.AutoTrain do
            if CFG.HideTrainAnim then hideTrainingGui(true) end
            local ok = rf("Training_Start")
            if ok then
                for _ = 1, 60 do
                    if not CFG.AutoTrain then break end
                    rf("Training_TapBonus")
                    task.wait(0.03)
                end
                rf("Training_Stop")
            end
            if CFG.HideTrainAnim then hideTrainingGui(false) end
            task.wait(0.2)
        end
        hideTrainingGui(false)
    end)
end

-- ── POWER FARM (максимальный спам тапов) ────────
-- Отдельный агрессивный режим: старт → тапы без лимита → рестарт
-- Без задержки на анимацию, без GUI
local function startPowerFarm()
    killThread("powerfarm")
    threads["powerfarm"] = task.spawn(function()
        while CFG.AutoPowerFarm do
            hideTrainingGui(true)

            -- начинаем сессию
            local sessionOk = rf("Training_Start")
            if not sessionOk then
                task.wait(0.3)
                -- пробуем ещё раз (иногда сервер не отвечает с первого раза)
                sessionOk = rf("Training_Start")
            end

            if sessionOk then
                -- спам тапов — сервер начисляет power за каждый
                -- используем минимальную задержку чтобы не флудить слишком быстро
                local tapCount = 0
                local maxTaps  = 100  -- за одну сессию
                while CFG.AutoPowerFarm and tapCount < maxTaps do
                    local result = rf("Training_TapBonus")
                    -- result обычно содержит новое значение power или true
                    -- если сервер вернул false/nil — сессия закончилась
                    if result == false or result == nil then break end
                    tapCount += 1
                    task.wait(CFG.PowerTapRate)
                end
                rf("Training_Stop")
            end

            hideTrainingGui(false)
            -- короткая пауза между сессиями
            task.wait(0.1)
        end
        hideTrainingGui(false)
    end)
end

-- ── MONEY FARM (спам продаж) ─────────────────────
-- Логика: экипируем лучшего пета → продаём всё → повторяем
-- Money/s зависит от экипированного пета, Plot_SellAll продаёт накопленное
local function startMoneyFarm()
    killThread("moneyfarm")
    threads["moneyfarm"] = task.spawn(function()
        -- сначала один раз экипируем лучшего
        rf("Plot_EquipBest")
        task.wait(0.5)

        while CFG.AutoMoneyFarm do
            -- продаём всё что накопилось
            local result = rf("Plot_SellAll")
            -- result обычно сумма продажи — логируем в консоль
            if result and result ~= 0 then
                -- продажа прошла успешно
            end

            -- каждые ~10 итераций переэкипируем чтобы всегда был лучший пет
            task.wait(CFG.SellRate)
        end
    end)
end

-- ── AUTO THROW ───────────────────────────────────
local blockTP = false
local savedCF = nil

local frozenTracks = {}
local function freezeAllAnims()
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
        if not frozenTracks[t] then
            frozenTracks[t] = t.Speed
            pcall(t.AdjustSpeed, t, 0)
        end
    end
end
local function unfreezeAllAnims()
    for t, spd in pairs(frozenTracks) do pcall(t.AdjustSpeed, t, spd) end
    frozenTracks = {}
end

local function findThrowPart()
    local ws = game:GetService("Workspace")
    for _, kw in ipairs({"ThrowZone","ThrowPad","ThrowPoint","LaunchPad","ThrowArea","Throw"}) do
        local obj = ws:FindFirstChild(kw, true)
        if obj then
            if obj:IsA("BasePart") then return obj end
            if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
        end
    end
    for _, v in ipairs(ws:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("throw") then return v end
    end
end

local function startThrow()
    killThread("throw")
    threads["throw"] = task.spawn(function()
        while CFG.AutoThrow do
            local char = lp.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(0.5); continue end

            local throwPart = findThrowPart()
            if throwPart then
                hrp.CFrame = CFrame.new(throwPart.Position + Vector3.new(0,4,0))
                task.wait(0.05)
            end

            savedCF = hrp.CFrame
            blockTP = CFG.BlockReturnTP

            if CFG.HideThrowAnim then freezeAllAnims() end

            local data = rf("Throw_Start")
            if data then
                rf("Throw_Resolve", data)
                rf("Throw_Complete")
            end

            task.wait(0.5)
            blockTP = false
            if CFG.HideThrowAnim then task.defer(unfreezeAllAnims) end
            task.wait(0.1)
        end
        blockTP = false
    end)
end

-- ── AUTO EQUIP ───────────────────────────────────
local function startEquip()
    killThread("equip")
    threads["equip"] = task.spawn(function()
        while CFG.AutoEquipBest do
            rf("Plot_EquipBest")
            task.wait(8)
        end
    end)
end

-- ── ПРЯМОЙ ИНЖЕКТ (fallback если RF не работают) ─
local replicaHooked = false
local function hookReplicaNewindex()
    if replicaHooked then return end
    replicaHooked = true
    pcall(function()
        local mt = getrawmetatable(game)
        local oldNI = mt.__newindex
        setreadonly(mt, false)
        mt.__newindex = function(self, key, value)
            if CFG.AutoInjectStats and typeof(self) == "Instance" then
                local n = self.Name
                if n == "Money"       and self:IsA("StringValue") then value = CFG.StatMoney end
                if n == "Throw Power" and self:IsA("IntValue")    then value = CFG.StatPower end
                if n == "Money/s"     and self:IsA("StringValue") then value = CFG.StatMPS   end
            end
            return oldNI(self, key, value)
        end
        setreadonly(mt, true)
    end)
end

local function startInject()
    pcall(hookReplicaNewindex)
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

-- ── BLOCK RETURN TP ──────────────────────────────
local function hookReturnBlock()
    RunService.Heartbeat:Connect(function()
        if not blockTP then return end
        local char = lp.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not savedCF then return end
        if (hrp.Position - savedCF.Position).Magnitude > 15 then
            hrp.CFrame = savedCF
        end
    end)
end

-- ╔══════════════════════════════════════╗
-- ║  GUI                                 ║
-- ╚══════════════════════════════════════╝
local C = {
    bg      = Color3.fromRGB(13,13,20),
    panel   = Color3.fromRGB(22,24,36),
    accent  = Color3.fromRGB(55,120,255),
    dim     = Color3.fromRGB(28,55,130),
    on      = Color3.fromRGB(30,165,80),
    off     = Color3.fromRGB(165,40,40),
    text    = Color3.fromRGB(210,215,230),
    sub     = Color3.fromRGB(110,115,145),
    head    = Color3.fromRGB(80,145,255),
    inputBg = Color3.fromRGB(18,20,32),
    green   = Color3.fromRGB(100,220,130),
    purple  = Color3.fromRGB(100,55,200),
    gold    = Color3.fromRGB(200,160,30),
    teal    = Color3.fromRGB(30,160,140),
}
local FB = Enum.Font.GothamBold
local FR = Enum.Font.Gotham
local FM = Enum.Font.Code

local function mkCorner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 7) end
local function mkStroke(p,col,th) local s=Instance.new("UIStroke",p); s.Color=col or C.accent; s.Thickness=th or 1.5 end
local function mkPad(p,l,r,t,b)
    local pad=Instance.new("UIPadding",p)
    pad.PaddingLeft=UDim.new(0,l or 0); pad.PaddingRight=UDim.new(0,r or 0)
    pad.PaddingTop=UDim.new(0,t or 0);  pad.PaddingBottom=UDim.new(0,b or 0)
end
local function mkList(p,dir,pad)
    local l=Instance.new("UIListLayout",p)
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.Padding=UDim.new(0,pad or 4)
    return l
end

local function buildGui()
    local old = lp.PlayerGui:FindFirstChild("ZFarm")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name="ZFarm"; gui.ResetOnSpawn=false
    gui.DisplayOrder=999; gui.IgnoreGuiInset=true
    gui.Parent=lp.PlayerGui

    local main = Instance.new("Frame", gui)
    main.Size=UDim2.new(0,310,0,500); main.Position=UDim2.new(0.5,-155,0.5,-250)
    main.BackgroundColor3=C.bg; main.BorderSizePixel=0
    main.Active=true; main.Draggable=true
    mkCorner(main,12); mkStroke(main,C.accent,1.5)

    -- HEADER
    local header=Instance.new("Frame",main)
    header.Size=UDim2.new(1,0,0,40); header.BackgroundColor3=C.dim; header.BorderSizePixel=0
    mkCorner(header,12)

    local htitle=Instance.new("TextLabel",header)
    htitle.Size=UDim2.new(1,-50,1,0); htitle.Position=UDim2.new(0,14,0,0)
    htitle.BackgroundTransparency=1; htitle.Text="⚡ Z FARM  v5.1"
    htitle.TextColor3=Color3.fromRGB(220,235,255); htitle.TextSize=15
    htitle.Font=FB; htitle.TextXAlignment=Enum.TextXAlignment.Left

    local minBtn=Instance.new("TextButton",header)
    minBtn.Size=UDim2.new(0,30,0,24); minBtn.Position=UDim2.new(1,-36,0.5,-12)
    minBtn.BackgroundColor3=Color3.fromRGB(45,50,75); minBtn.Text="—"
    minBtn.TextColor3=C.text; minBtn.TextSize=14; minBtn.Font=FB; minBtn.BorderSizePixel=0
    mkCorner(minBtn,5)

    -- TABBAR
    local tabBar=Instance.new("Frame",main)
    tabBar.Size=UDim2.new(1,-16,0,30); tabBar.Position=UDim2.new(0,8,0,44)
    tabBar.BackgroundColor3=C.panel; tabBar.BorderSizePixel=0
    mkCorner(tabBar,7); mkList(tabBar,Enum.FillDirection.Horizontal,2); mkPad(tabBar,3,3,3,3)

    -- SCROLL
    local scroll=Instance.new("ScrollingFrame",main)
    scroll.Size=UDim2.new(1,-16,1,-130); scroll.Position=UDim2.new(0,8,0,78)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=C.accent
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.CanvasSize=UDim2.new(0,0,0,0)
    mkList(scroll,Enum.FillDirection.Vertical,4); mkPad(scroll,0,4,0,8)

    -- STATUS
    local sbar=Instance.new("Frame",main)
    sbar.Size=UDim2.new(1,-16,0,38); sbar.Position=UDim2.new(0,8,1,-46)
    sbar.BackgroundColor3=C.panel; sbar.BorderSizePixel=0; mkCorner(sbar,7)

    local slbl=Instance.new("TextLabel",sbar)
    slbl.Size=UDim2.new(1,-12,1,0); slbl.Position=UDim2.new(0,8,0,0)
    slbl.BackgroundTransparency=1; slbl.TextColor3=C.green
    slbl.TextSize=11; slbl.Font=FM; slbl.TextXAlignment=Enum.TextXAlignment.Left
    slbl.Text="waiting..."

    task.spawn(function()
        while gui and gui.Parent do
            local s=lp:FindFirstChild("leaderstats")
            if s then
                local m=s:FindFirstChild("Money")
                local p=s:FindFirstChild("Throw Power")
                local r=s:FindFirstChild("Money/s")
                slbl.Text=("💰 %s   ⚡ %s   📈 %s"):format(
                    m and tostring(m.Value) or "?",
                    p and tostring(p.Value) or "?",
                    r and tostring(r.Value) or "?"
                )
            end
            task.wait(0.4)
        end
    end)

    -- TAB SYSTEM
    local tabBtns,tabFrames={},{}
    local function switchTab(name)
        for n,f in pairs(tabFrames) do f.Visible=(n==name) end
        for n,b in pairs(tabBtns) do
            b.BackgroundColor3=(n==name) and C.accent or Color3.fromRGB(32,36,55)
            b.TextColor3=(n==name) and Color3.fromRGB(255,255,255) or C.sub
        end
        scroll.CanvasPosition=Vector2.new(0,0)
    end

    local tabOrder=0
    local function addTab(name,icon)
        tabOrder+=1
        local btn=Instance.new("TextButton",tabBar)
        btn.Size=UDim2.new(0.24,-2,1,0); btn.BackgroundColor3=Color3.fromRGB(32,36,55)
        btn.Text=icon.." "..name; btn.TextColor3=C.sub; btn.TextSize=11
        btn.Font=FB; btn.BorderSizePixel=0; btn.LayoutOrder=tabOrder
        mkCorner(btn,5); tabBtns[name]=btn

        local frame=Instance.new("Frame",scroll)
        frame.Size=UDim2.new(1,0,0,0); frame.AutomaticSize=Enum.AutomaticSize.Y
        frame.BackgroundTransparency=1; frame.BorderSizePixel=0
        frame.Visible=false; frame.LayoutOrder=tabOrder
        mkList(frame,Enum.FillDirection.Vertical,4); tabFrames[name]=frame

        btn.MouseButton1Click:Connect(function() switchTab(name) end)
        return frame
    end

    -- ROW BUILDERS
    local function addSection(parent,text)
        local lbl=Instance.new("TextLabel",parent)
        lbl.Size=UDim2.new(1,0,0,16); lbl.BackgroundTransparency=1
        lbl.Text=text; lbl.TextColor3=C.head; lbl.TextSize=10; lbl.Font=FB
        lbl.TextXAlignment=Enum.TextXAlignment.Left; mkPad(lbl,4,0,0,0)
    end

    local function addToggleRow(parent,label,cfgKey,onToggle)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,36); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(1,-70,1,0); lbl.Position=UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text
        lbl.TextSize=13; lbl.Font=FR; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local btn=Instance.new("TextButton",row)
        btn.Size=UDim2.new(0,56,0,24); btn.Position=UDim2.new(1,-62,0.5,-12)
        btn.BackgroundColor3=CFG[cfgKey] and C.on or C.off
        btn.Text=CFG[cfgKey] and "ON" or "OFF"
        btn.TextColor3=Color3.fromRGB(255,255,255); btn.TextSize=12; btn.Font=FB; btn.BorderSizePixel=0
        mkCorner(btn,5)
        btn.MouseButton1Click:Connect(function()
            CFG[cfgKey]=not CFG[cfgKey]
            btn.BackgroundColor3=CFG[cfgKey] and C.on or C.off
            btn.Text=CFG[cfgKey] and "ON" or "OFF"
            if onToggle then onToggle(CFG[cfgKey]) end
        end)
        return btn
    end

    local function addInputRow(parent,label,cfgKey,isNum)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,36); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(0.38,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.sub
        lbl.TextSize=12; lbl.Font=FR; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local box=Instance.new("TextBox",row)
        box.Size=UDim2.new(0,110,0,24); box.Position=UDim2.new(0.4,0,0.5,-12)
        box.BackgroundColor3=C.inputBg; box.Text=tostring(CFG[cfgKey])
        box.TextColor3=Color3.fromRGB(170,215,255); box.TextSize=12; box.Font=FM
        box.ClearTextOnFocus=false; box.BorderSizePixel=0
        mkCorner(box,5); mkStroke(box,C.dim,1); mkPad(box,6,6,0,0)
        local setBtn=Instance.new("TextButton",row)
        setBtn.Size=UDim2.new(0,38,0,24); setBtn.Position=UDim2.new(1,-44,0.5,-12)
        setBtn.BackgroundColor3=C.accent; setBtn.Text="SET"
        setBtn.TextColor3=Color3.fromRGB(255,255,255); setBtn.TextSize=11; setBtn.Font=FB; setBtn.BorderSizePixel=0
        mkCorner(setBtn,5)
        local function apply(val)
            if isNum then local n=tonumber(val); if n then CFG[cfgKey]=n end
            else CFG[cfgKey]=val end
            box.Text=tostring(CFG[cfgKey])
            setBtn.BackgroundColor3=C.on
            task.delay(0.4,function() setBtn.BackgroundColor3=C.accent end)
        end
        setBtn.MouseButton1Click:Connect(function() apply(box.Text) end)
        box.FocusLost:Connect(function(enter) if enter then apply(box.Text) end end)
    end

    local function addActionBtn(parent,label,color,onClick)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        local btn=Instance.new("TextButton",row)
        btn.Size=UDim2.new(1,-16,0,24); btn.Position=UDim2.new(0,8,0.5,-12)
        btn.BackgroundColor3=color or C.accent; btn.Text=label
        btn.TextColor3=Color3.fromRGB(255,255,255); btn.TextSize=12; btn.Font=FB; btn.BorderSizePixel=0
        mkCorner(btn,5)
        btn.MouseButton1Click:Connect(function()
            onClick(); local orig=btn.BackgroundColor3
            btn.BackgroundColor3=C.on
            task.delay(0.4,function() btn.BackgroundColor3=orig end)
        end)
        return btn
    end

    local function addGuiToggle(parent,guiName)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,30); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,6)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(1,-68,1,0); lbl.Position=UDim2.new(0,8,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=guiName; lbl.TextColor3=C.text
        lbl.TextSize=11; lbl.Font=FM; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local function getState()
            local g=lp.PlayerGui:FindFirstChild(guiName)
            return g and g:IsA("ScreenGui") and g.Enabled or false
        end
        local btn=Instance.new("TextButton",row)
        btn.Size=UDim2.new(0,52,0,20); btn.Position=UDim2.new(1,-58,0.5,-10)
        btn.BackgroundColor3=getState() and C.on or C.off
        btn.Text=getState() and "ON" or "OFF"
        btn.TextColor3=Color3.fromRGB(255,255,255); btn.TextSize=11; btn.Font=FB; btn.BorderSizePixel=0
        mkCorner(btn,4)
        btn.MouseButton1Click:Connect(function()
            local g=lp.PlayerGui:FindFirstChild(guiName)
            if g and g:IsA("ScreenGui") then
                g.Enabled=not g.Enabled
                btn.BackgroundColor3=g.Enabled and C.on or C.off
                btn.Text=g.Enabled and "ON" or "OFF"
            end
        end)
    end

    local function addNote(parent, text)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,46); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        mkPad(row,8,8,6,6)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
        lbl.Text=text; lbl.TextColor3=C.sub; lbl.TextSize=11; lbl.Font=FR
        lbl.TextWrapped=true; lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.TextYAlignment=Enum.TextYAlignment.Top
    end

    -- ════════════════════════════════════════
    -- ТАБ 1: FARM
    -- ════════════════════════════════════════
    local farmF=addTab("Farm","🌾")

    addSection(farmF,"── ⚡ POWER FARM (легитимно) ──")
    addToggleRow(farmF,"🏋️ Power Farm (тапы)",  "AutoPowerFarm", function(v)
        if v then startPowerFarm() else killThread("powerfarm"); hideTrainingGui(false) end
    end)
    addInputRow(farmF,"⏱ Tap rate (сек)", "PowerTapRate", true)
    addNote(farmF,"Имитирует тренировку: старт → 100 тапов → стоп.\nСервер сам начисляет Throw Power легитимно.")

    addSection(farmF,"── 💰 MONEY FARM (легитимно) ──")
    addToggleRow(farmF,"💸 Money Farm (продажи)", "AutoMoneyFarm", function(v)
        if v then startMoneyFarm() else killThread("moneyfarm") end
    end)
    addInputRow(farmF,"⏱ Sell rate (сек)", "SellRate", true)
    addNote(farmF,"Экипирует лучшего пета → Plot_SellAll.\nДеньги начисляются сервером легитимно.")

    addSection(farmF,"── ЖИВОТНЫЕ ──")
    addToggleRow(farmF,"🐾 Auto Equip Best", "AutoEquipBest", function(v)
        if v then startEquip() else killThread("equip") end
    end)
    addActionBtn(farmF,"⚡ Equip Best NOW", Color3.fromRGB(40,80,160), function() rf("Plot_EquipBest") end)
    addActionBtn(farmF,"💸 Sell All NOW",   Color3.fromRGB(160,80,40), function() rf("Plot_SellAll") end)

    addSection(farmF,"── СТАРЫЙ AUTO TRAIN ──")
    addToggleRow(farmF,"🏋️ Auto Train (с GUI)", "AutoTrain", function(v)
        if v then startTrain() else killThread("train"); rf("Training_Stop"); hideTrainingGui(false) end
    end)
    addToggleRow(farmF,"🙈 Hide Train Anim",   "HideTrainAnim", nil)

    -- ════════════════════════════════════════
    -- ТАБ 2: THROW
    -- ════════════════════════════════════════
    local throwF=addTab("Throw","🎯")
    addSection(throwF,"── АВТО БРОСОК ──")
    addToggleRow(throwF,"🎯 Auto Throw",      "AutoThrow",      function(v)
        if v then startThrow() else killThread("throw"); blockTP=false end
    end)
    addToggleRow(throwF,"⚡ Skip Animations", "HideThrowAnim",  nil)
    addToggleRow(throwF,"🔒 Block Return TP", "BlockReturnTP",  nil)
    addNote(throwF,"Block Return TP держит позицию во время\nброска, блокирует телепорт назад в загон.\nТелепорт к зоне броска происходит тихо.")

    -- ════════════════════════════════════════
    -- ТАБ 3: STATS
    -- ════════════════════════════════════════
    local statsF=addTab("Stats","📊")
    addSection(statsF,"── ПРЯМОЙ ИНЖЕКТ (fallback) ──")
    addNote(statsF,"Используй если легитимный фарм не даёт\nнужных значений. Патчит __newindex игры.")
    addInputRow(statsF,"💰 Money",    "StatMoney", false)
    addInputRow(statsF,"⚡ Power",    "StatPower", true)
    addInputRow(statsF,"📈 Money/s", "StatMPS",   false)
    addToggleRow(statsF,"🔄 Auto Inject", "AutoInjectStats", function(v)
        if v then startInject() else killThread("inject") end
    end)
    addActionBtn(statsF,"💉 Inject Once", C.purple, injectOnce)

    -- ════════════════════════════════════════
    -- ТАБ 4: GUI
    -- ════════════════════════════════════════
    local guiF=addTab("GUI","🖥")
    addSection(guiF,"── PLAYER GUI SCREENS ──")
    for _,name in ipairs({
        "StudioAnimals","ScreenFX","HUD","IndexGui","AnimalsPanelGui",
        "SellShop","ProtectedSell","BackpackGui","ShopRewards","Announcements",
        "ServerLuckHUD","GiftMenu","GiftRequest","Tutorial","UpgradePopup",
        "AdminAbuse","AdminVote","AdminAbuseEffects","AdminFlash","OfflineReminder",
        "PackOffer","TopbarCenteredClipped","TopbarStandardClipped",
        "TopbarStandard","TopbarCentered","TrainingGui","FoodShop",
        "StatsGui","ExclusiveShop","TouchGui","OfflineEarnings","GamepadHints",
    }) do addGuiToggle(guiF,name) end

    -- MINIMIZE
    local minimized=false
    minBtn.MouseButton1Click:Connect(function()
        minimized=not minimized
        tabBar.Visible=not minimized; scroll.Visible=not minimized; sbar.Visible=not minimized
        main.Size=minimized and UDim2.new(0,310,0,42) or UDim2.new(0,310,0,500)
        minBtn.Text=minimized and "▲" or "—"
    end)

    switchTab("Farm")
end

-- HOTKEY
UserInputService.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.RightControl then
        local g=lp.PlayerGui:FindFirstChild("ZFarm")
        if g then g.Enabled=not g.Enabled end
    end
end)

-- INIT
task.wait(2)
hookReturnBlock()
buildGui()
print("[Z] v5.1 loaded ✓  |  RCtrl = show/hide")
