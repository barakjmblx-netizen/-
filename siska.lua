-- ╔══════════════════════════════════════════════╗
-- ║  Piska.lua v2 — Farm + Stat Injector         ║
-- ║  Game: 120219252362013                       ║
-- ╚══════════════════════════════════════════════╝

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local lp      = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ╔══════════════╗
-- ║    CONFIG    ║
-- ╚══════════════╝
local CFG = {
    -- Farm toggles
    AutoTrain       = true,
    AutoSellAll     = true,
    AutoEquipBest   = true,
    AutoThrow       = false,

    -- Stat Injector
    AutoInjectStats = true,
    InjectInterval  = 2.0,       -- каждые N секунд
    TargetPower     = 999999,    -- Throw Power цель
    TargetMoney     = "$999M",   -- отображаемое значение (строка как в игре)

    -- Timing
    TrainDelay      = 0.05,
    SellDelay       = 5.0,
    ThrowDelay      = 0.1,

    ToggleKey       = Enum.KeyCode.RightControl,
}

-- ╔══════════════════╗
-- ║  REMOTE HELPERS  ║
-- ╚══════════════════╝
local function invokeRF(name, ...)
    local rf = Remotes:FindFirstChild(name)
    if rf and rf:IsA("RemoteFunction") then
        local ok, res = pcall(rf.InvokeServer, rf, ...)
        if ok then return res end
    end
end

local function fireRE(name, ...)
    local re = Remotes:FindFirstChild(name)
    if re and re:IsA("RemoteEvent") then
        pcall(re.FireServer, re, ...)
    end
end

-- ╔══════════════════════════════╗
-- ║   STAT INJECTOR              ║
-- ║   Три слоя: RF → RE → Local  ║
-- ╚══════════════════════════════╝

-- Слой 1: Player_SetThrowPower — прямой RF на сервер
local function injectViaRF()
    invokeRF("Player_SetThrowPower", CFG.TargetPower)
end

-- Слой 2: ReplicaWrite — пишем в реплику напрямую
-- ReplicaService хранит данные как {[path] = value}
-- Пробуем записать через RE который сервер слушает
local function injectViaReplica()
    -- ReplicaWrite path формат зависит от игры, пробуем стандартный
    local replicaWrite = ReplicatedStorage.RemoteEvents:FindFirstChild("ReplicaWrite")
    if replicaWrite then
        pcall(function()
            replicaWrite:FireServer({
                Path = {"Stats", "ThrowPower"},
                Value = CFG.TargetPower
            })
        end)
        pcall(function()
            replicaWrite:FireServer({
                Path = {"Currency", "Money"},
                Value = 999000000
            })
        end)
    end
end

-- Слой 3: Локальный патч leaderstats (визуально + некоторые игры читают обратно)
local function patchLeaderstats()
    local stats = lp:FindFirstChild("leaderstats")
    if not stats then return end

    local power = stats:FindFirstChild("Throw Power")
    local money = stats:FindFirstChild("Money")
    local mps   = stats:FindFirstChild("Money/s")

    if power then
        pcall(function() power.Value = CFG.TargetPower end)
    end
    if money then
        pcall(function() money.Value = CFG.TargetMoney end)
    end
    if mps then
        pcall(function() mps.Value = "$99.9M/s" end)
    end
end

-- Слой 4: Dev_Action — если у нас есть доступ (admin remote)
local function tryDevAction()
    -- Пробуем разные форматы — игра сама отфильтрует
    local actions = {
        {Action = "SetMoney",  Amount = 999000000},
        {Action = "GiveMoney", Amount = 999000000},
        {Action = "SetPower",  Value  = CFG.TargetPower},
        {Action = "AddPower",  Amount = CFG.TargetPower},
        {action = "set_money", value  = 999000000},
        {action = "set_power", value  = CFG.TargetPower},
    }
    for _, payload in ipairs(actions) do
        invokeRF("Dev_Action", payload)
        task.wait(0.05)
    end
end

-- Слой 5: Player_SetSetting — иногда игры хранят там всё
local function injectViaSetting()
    invokeRF("Player_SetSetting", "ThrowPower", CFG.TargetPower)
    invokeRF("Player_SetSetting", "Money",      999000000)
end

-- Мастер-инжектор — стреляем всеми слоями
local function runStatInjector()
    task.spawn(function()
        while CFG.AutoInjectStats do
            injectViaRF()
            injectViaReplica()
            patchLeaderstats()
            injectViaSetting()
            tryDevAction()
            task.wait(CFG.InjectInterval)
        end
    end)
end

-- ╔══════════════════╗
-- ║   FARM MODULES   ║
-- ╚══════════════════╝
local trainActive = false
local function autoTrain()
    if not CFG.AutoTrain or trainActive then return end
    trainActive = true
    task.spawn(function()
        while CFG.AutoTrain do
            local ok = invokeRF("Training_Start")
            if ok then
                for _ = 1, 50 do
                    if not CFG.AutoTrain then break end
                    invokeRF("Training_TapBonus")
                    task.wait(CFG.TrainDelay)
                end
                invokeRF("Training_Stop")
            end
            task.wait(0.3)
        end
        trainActive = false
    end)
end

local function autoSellAll()
    task.spawn(function()
        while CFG.AutoSellAll do
            invokeRF("Plot_SellAll")
            task.wait(CFG.SellDelay)
        end
    end)
end

local function autoEquipBest()
    task.spawn(function()
        while CFG.AutoEquipBest do
            invokeRF("Plot_EquipBest")
            task.wait(10)
        end
    end)
end

local function autoThrow()
    task.spawn(function()
        while CFG.AutoThrow do
            local data = invokeRF("Throw_Start")
            if data then
                task.wait(0.05)
                invokeRF("Throw_Resolve", data)
                task.wait(0.05)
                invokeRF("Throw_Complete")
            end
            task.wait(CFG.ThrowDelay)
        end
    end)
end

-- ╔══════════════════╗
-- ║      GUI         ║
-- ╚══════════════════╝
local labels = {}

local function buildGui()
    if lp.PlayerGui:FindFirstChild("ZFarm") then
        lp.PlayerGui:FindFirstChild("ZFarm"):Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ZFarm"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = lp.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 235, 0, 265)
    frame.Position = UDim2.new(0, 10, 0.5, -132)
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(80, 160, 255)
    stroke.Thickness = 1.5

    -- Title bar
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(20, 70, 170)
    title.BorderSizePixel = 0
    title.Text = "  [Z] FARM v2  •  RCtrl toggle"
    title.TextColor3 = Color3.fromRGB(220, 235, 255)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

    local pad = Instance.new("UIPadding", frame)
    pad.PaddingTop    = UDim.new(0, 36)
    pad.PaddingLeft   = UDim.new(0, 8)
    pad.PaddingRight  = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 6)

    local layout = Instance.new("UIListLayout", frame)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 3)

    -- Секция-разделитель
    local function makeSection(text, order)
        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(1, 0, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = "── " .. text .. " ──"
        lbl.TextColor3 = Color3.fromRGB(100, 150, 255)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.LayoutOrder = order
    end

    -- Toggle строка
    local function makeToggle(labelText, cfgKey, order, onToggle)
        local row = Instance.new("Frame", frame)
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.68, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(200, 205, 220)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(0.3, 0, 0.78, 0)
        btn.Position = UDim2.new(0.7, 0, 0.11, 0)
        btn.BackgroundColor3 = CFG[cfgKey]
            and Color3.fromRGB(35, 170, 85)
            or  Color3.fromRGB(170, 45, 45)
        btn.Text = CFG[cfgKey] and "ON" or "OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

        btn.MouseButton1Click:Connect(function()
            CFG[cfgKey] = not CFG[cfgKey]
            btn.BackgroundColor3 = CFG[cfgKey]
                and Color3.fromRGB(35, 170, 85)
                or  Color3.fromRGB(170, 45, 45)
            btn.Text = CFG[cfgKey] and "ON" or "OFF"
            if onToggle then onToggle(CFG[cfgKey]) end
        end)

        table.insert(labels, {btn = btn, key = cfgKey})
    end

    makeSection("FARM",        1)
    makeToggle("Auto Train",       "AutoTrain",       2, function(v) if v then autoTrain() end end)
    makeToggle("Auto Sell All",    "AutoSellAll",     3, function(v) if v then autoSellAll() end end)
    makeToggle("Auto Equip Best",  "AutoEquipBest",   4, function(v) if v then autoEquipBest() end end)
    makeToggle("Auto Throw",       "AutoThrow",       5, function(v) if v then autoThrow() end end)

    makeSection("STAT INJECT",    6)
    makeToggle("💉 Inject Stats",  "AutoInjectStats", 7, function(v) if v then runStatInjector() end end)

    -- Live stats display
    local statsBox = Instance.new("Frame", frame)
    statsBox.Size = UDim2.new(1, 0, 0, 52)
    statsBox.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
    statsBox.BorderSizePixel = 0
    statsBox.LayoutOrder = 8
    Instance.new("UICorner", statsBox).CornerRadius = UDim.new(0, 6)

    local statsPad = Instance.new("UIPadding", statsBox)
    statsPad.PaddingLeft  = UDim.new(0, 8)
    statsPad.PaddingTop   = UDim.new(0, 4)

    local statsLbl = Instance.new("TextLabel", statsBox)
    statsLbl.Size = UDim2.new(1, -8, 1, -4)
    statsLbl.BackgroundTransparency = 1
    statsLbl.TextColor3 = Color3.fromRGB(100, 220, 130)
    statsLbl.TextSize = 12
    statsLbl.Font = Enum.Font.Code
    statsLbl.TextXAlignment = Enum.TextXAlignment.Left
    statsLbl.TextYAlignment = Enum.TextYAlignment.Top
    statsLbl.TextWrapped = true

    -- Обновляем stats label
    task.spawn(function()
        while gui and gui.Parent do
            local s = lp:FindFirstChild("leaderstats")
            if s then
                statsLbl.Text = string.format(
                    "💰 %s\n⚡ Power: %s\n📈 %s",
                    s:FindFirstChild("Money")        and s.Money.Value        or "—",
                    s:FindFirstChild("Throw Power")  and s["Throw Power"].Value or "—",
                    s:FindFirstChild("Money/s")      and s["Money/s"].Value   or "—"
                )
            end
            task.wait(0.5)
        end
    end)
end

-- ╔══════════════════╗
-- ║   HOTKEY          ║
-- ╚══════════════════╝
local allOn = true
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == CFG.ToggleKey then
        allOn = not allOn
        CFG.AutoTrain       = allOn
        CFG.AutoSellAll     = allOn
        CFG.AutoEquipBest   = allOn
        CFG.AutoInjectStats = allOn
        for _, t in ipairs(labels) do
            local v = CFG[t.key]
            t.btn.BackgroundColor3 = v
                and Color3.fromRGB(35, 170, 85)
                or  Color3.fromRGB(170, 45, 45)
            t.btn.Text = v and "ON" or "OFF"
        end
        if allOn then
            autoTrain(); autoSellAll()
            autoEquipBest(); runStatInjector()
        end
    end
end)

-- ╔══════════════════╗
-- ║      INIT        ║
-- ╚══════════════════╝
task.wait(1.5)
buildGui()

if CFG.AutoTrain       then autoTrain()        end
if CFG.AutoSellAll     then autoSellAll()       end
if CFG.AutoEquipBest   then autoEquipBest()     end
if CFG.AutoThrow       then autoThrow()         end
if CFG.AutoInjectStats then runStatInjector()   end

print("[Z] v2 loaded — farm + stat injector active")
