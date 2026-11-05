-- ╔══════════════════════════════════════════╗
-- ║  Piska.lua — Auto Farm                   ║
-- ║  Game: 120219252362013                   ║
-- ║  Target: Throw Power + Money Auto Farm   ║
-- ╚══════════════════════════════════════════╝

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ╔══════════════╗
-- ║    CONFIG    ║
-- ╚══════════════╝
local CFG = {
    -- Toggles
    AutoTrain     = true,
    AutoSellAll   = true,
    AutoThrow     = false,
    AutoEquipBest = true,

    -- Timing
    TrainDelay    = 0.05,  -- seconds between TapBonus calls
    SellDelay     = 5.0,   -- seconds between SellAll calls
    ThrowDelay    = 0.1,

    -- Keys
    ToggleKey     = Enum.KeyCode.RightControl,

    -- UI
    ShowGui       = true,
}

-- ╔══════════════════╗
-- ║  REMOTE HELPERS  ║
-- ╚══════════════════╝
local function getRemote(name)
    return Remotes:FindFirstChild(name)
end

local function invokeRF(name, ...)
    local rf = getRemote(name)
    if rf and rf:IsA("RemoteFunction") then
        local ok, res = pcall(function() return rf:InvokeServer(...) end)
        if ok then return res end
    end
end

local function fireRE(name, ...)
    local re = getRemote(name)
    if re and re:IsA("RemoteEvent") then
        pcall(function() re:FireServer(...) end)
    end
end

-- ╔══════════════════╗
-- ║   FARM MODULES   ║
-- ╚══════════════════╝

-- AUTO TRAINING (Throw Power grind)
local trainActive = false
local function autoTrain()
    if not CFG.AutoTrain then return end
    if trainActive then return end
    trainActive = true

    task.spawn(function()
        while CFG.AutoTrain do
            -- Start training session
            local started = invokeRF("Training_Start")
            if started then
                -- Spam TapBonus как можно быстрее
                for _ = 1, 50 do
                    if not CFG.AutoTrain then break end
                    invokeRF("Training_TapBonus")
                    task.wait(CFG.TrainDelay)
                end
                -- Stop и получаем награду
                invokeRF("Training_Stop")
            end
            task.wait(0.3)
        end
        trainActive = false
    end)
end

-- AUTO SELL ALL
local function autoSellAll()
    task.spawn(function()
        while CFG.AutoSellAll do
            invokeRF("Plot_SellAll")
            task.wait(CFG.SellDelay)
        end
    end)
end

-- AUTO EQUIP BEST ANIMAL
local function autoEquipBest()
    task.spawn(function()
        while CFG.AutoEquipBest do
            invokeRF("Plot_EquipBest")
            task.wait(10)
        end
    end)
end

-- AUTO THROW
local function autoThrow()
    task.spawn(function()
        while CFG.AutoThrow do
            local throwData = invokeRF("Throw_Start")
            if throwData then
                task.wait(0.05)
                invokeRF("Throw_Resolve", throwData)
                task.wait(0.05)
                invokeRF("Throw_Complete")
            end
            task.wait(CFG.ThrowDelay)
        end
    end)
end

-- ╔══════════════════╗
-- ║   IMGUI / HUD    ║
-- ╚══════════════════╝
local gui, frame, labels = nil, nil, {}

local function buildGui()
    if not CFG.ShowGui then return end

    -- Убираем старый если есть
    if lp.PlayerGui:FindFirstChild("ZFarm") then
        lp.PlayerGui:FindFirstChild("ZFarm"):Destroy()
    end

    gui = Instance.new("ScreenGui")
    gui.Name = "ZFarm"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = lp.PlayerGui

    frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 185)
    frame.Position = UDim2.new(0, 10, 0.5, -90)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 160, 255)
    stroke.Thickness = 1.5
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundColor3 = Color3.fromRGB(30, 80, 180)
    title.BorderSizePixel = 0
    title.Text = "  [Z] FARM  •  " .. tostring(Enum.KeyCode.RightControl.Name) .. " toggle"
    title.TextColor3 = Color3.fromRGB(220, 230, 255)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 32)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = frame

    local function makeToggle(labelText, cfgKey)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.LayoutOrder = #labels + 1
        row.Parent = frame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.28, 0, 0.8, 0)
        btn.Position = UDim2.new(0.72, 0, 0.1, 0)
        btn.BackgroundColor3 = CFG[cfgKey] and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(180, 50, 50)
        btn.Text = CFG[cfgKey] and "ON" or "OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = row

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 4)
        bc.Parent = btn

        btn.MouseButton1Click:Connect(function()
            CFG[cfgKey] = not CFG[cfgKey]
            btn.BackgroundColor3 = CFG[cfgKey] and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(180, 50, 50)
            btn.Text = CFG[cfgKey] and "ON" or "OFF"
            -- реинициализируем если включили
            if cfgKey == "AutoTrain" and CFG.AutoTrain then autoTrain() end
            if cfgKey == "AutoSellAll" and CFG.AutoSellAll then autoSellAll() end
            if cfgKey == "AutoEquipBest" and CFG.AutoEquipBest then autoEquipBest() end
            if cfgKey == "AutoThrow" and CFG.AutoThrow then autoThrow() end
        end)

        table.insert(labels, btn)
    end

    makeToggle("Auto Train (Throw Pwr)", "AutoTrain")
    makeToggle("Auto Sell All",          "AutoSellAll")
    makeToggle("Auto Equip Best",        "AutoEquipBest")
    makeToggle("Auto Throw",             "AutoThrow")

    -- Статус строка (money/s и power)
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name = "Status"
    statusLbl.Size = UDim2.new(1, 0, 0, 22)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3 = Color3.fromRGB(120, 200, 120)
    statusLbl.TextSize = 11
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.LayoutOrder = 99
    statusLbl.Parent = frame

    -- Обновляем статус каждую секунду
    task.spawn(function()
        while gui and gui.Parent do
            local stats = lp:FindFirstChild("leaderstats")
            if stats then
                local money = stats:FindFirstChild("Money")
                local power = stats:FindFirstChild("Throw Power")
                local mps   = stats:FindFirstChild("Money/s")
                statusLbl.Text = string.format(
                    "💰 %s  ⚡ %s  📈 %s",
                    money and money.Value or "?",
                    power and power.Value or "?",
                    mps   and mps.Value   or "?"
                )
            end
            task.wait(1)
        end
    end)
end

-- ╔══════════════════╗
-- ║  HOTKEY TOGGLE   ║
-- ╚══════════════════╝
local farmEnabled = true

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == CFG.ToggleKey then
        farmEnabled = not farmEnabled
        CFG.AutoTrain     = farmEnabled
        CFG.AutoSellAll   = farmEnabled
        CFG.AutoEquipBest = farmEnabled
        -- обновляем кнопки
        for i, btn in ipairs(labels) do
            btn.BackgroundColor3 = farmEnabled and Color3.fromRGB(40,180,90) or Color3.fromRGB(180,50,50)
            btn.Text = farmEnabled and "ON" or "OFF"
        end
        if farmEnabled then
            autoTrain()
            autoSellAll()
            autoEquipBest()
        end
    end
end)

-- ╔══════════════════╗
-- ║     INIT         ║
-- ╚══════════════════╝
task.wait(1) -- дать игре загрузиться

buildGui()

if CFG.AutoTrain     then autoTrain()     end
if CFG.AutoSellAll   then autoSellAll()   end
if CFG.AutoEquipBest then autoEquipBest() end
if CFG.AutoThrow     then autoThrow()     end

print("[Z] Farm loaded — RightCtrl to toggle all")