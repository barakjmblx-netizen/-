-- Pop It Trading | Mobile Menu v3.0
-- Added: Log Panel with full dump output + copy button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

pcall(function()
    game:GetService("CoreGui"):FindFirstChild("MobileAugMenu"):Destroy()
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MobileAugMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = game:GetService("CoreGui")

-- === LOG BUFFER ===
local logLines = {}
local function logPush(s)
    table.insert(logLines, s)
    print(s)
end
local function logClear()
    logLines = {}
end
local function logGet()
    return table.concat(logLines, "\n")
end

-- === MAIN FRAME ===
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 290, 0, 420)
Frame.Position = UDim2.new(0.5, -145, 0.5, -210)
Frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
Frame.BorderSizePixel = 0
Frame.ClipsDescendants = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke", Frame)
stroke.Color = Color3.fromRGB(80, 60, 160)
stroke.Thickness = 1.5

-- === LOG PANEL (overlay, hidden by default) ===
local LogPanel = Instance.new("Frame")
LogPanel.Size = UDim2.new(1, 0, 1, 0)
LogPanel.Position = UDim2.new(1, 0, 0, 0) -- off-screen right
LogPanel.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
LogPanel.BorderSizePixel = 0
LogPanel.ZIndex = 10
LogPanel.ClipsDescendants = true
LogPanel.Parent = Frame
Instance.new("UICorner", LogPanel).CornerRadius = UDim.new(0, 16)

-- Log title bar
local LogBar = Instance.new("Frame")
LogBar.Size = UDim2.new(1, 0, 0, 48)
LogBar.BackgroundColor3 = Color3.fromRGB(20, 14, 44)
LogBar.BorderSizePixel = 0
LogBar.ZIndex = 11
LogBar.Parent = LogPanel
Instance.new("UICorner", LogBar).CornerRadius = UDim.new(0, 16)

local LogTitle = Instance.new("TextLabel", LogBar)
LogTitle.Size = UDim2.new(1, -60, 1, 0)
LogTitle.Position = UDim2.new(0, 14, 0, 0)
LogTitle.BackgroundTransparency = 1
LogTitle.TextColor3 = Color3.fromRGB(180, 140, 255)
LogTitle.Text = "📋 Log"
LogTitle.Font = Enum.Font.GothamBold
LogTitle.TextSize = 15
LogTitle.TextXAlignment = Enum.TextXAlignment.Left
LogTitle.ZIndex = 12

local BackBtn = Instance.new("TextButton", LogBar)
BackBtn.Size = UDim2.new(0, 36, 0, 36)
BackBtn.Position = UDim2.new(1, -42, 0, 6)
BackBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
BackBtn.Text = "←"
BackBtn.TextColor3 = Color3.new(1,1,1)
BackBtn.Font = Enum.Font.GothamBold
BackBtn.TextSize = 16
BackBtn.ZIndex = 12
Instance.new("UICorner", BackBtn).CornerRadius = UDim.new(0, 8)

-- Log scroll area
local LogScroll = Instance.new("ScrollingFrame", LogPanel)
LogScroll.Size = UDim2.new(1, -12, 1, -108)
LogScroll.Position = UDim2.new(0, 6, 0, 52)
LogScroll.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 3
LogScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 60, 160)
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScroll.ZIndex = 11
Instance.new("UICorner", LogScroll).CornerRadius = UDim.new(0, 8)

local LogPad = Instance.new("UIPadding", LogScroll)
LogPad.PaddingTop = UDim.new(0, 6)
LogPad.PaddingLeft = UDim.new(0, 8)
LogPad.PaddingRight = UDim.new(0, 8)
LogPad.PaddingBottom = UDim.new(0, 6)

local LogText = Instance.new("TextLabel", LogScroll)
LogText.Size = UDim2.new(1, 0, 0, 0)
LogText.AutomaticSize = Enum.AutomaticSize.Y
LogText.BackgroundTransparency = 1
LogText.TextColor3 = Color3.fromRGB(160, 220, 160)
LogText.Font = Enum.Font.Code
LogText.TextSize = 11
LogText.TextXAlignment = Enum.TextXAlignment.Left
LogText.TextYAlignment = Enum.TextYAlignment.Top
LogText.TextWrapped = true
LogText.RichText = false
LogText.Text = "(empty — run a dump first)"
LogText.ZIndex = 12

-- Copy button (bottom of log panel)
local CopyBtn = Instance.new("TextButton", LogPanel)
CopyBtn.Size = UDim2.new(1, -24, 0, 44)
CopyBtn.Position = UDim2.new(0, 12, 1, -56)
CopyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 80)
CopyBtn.Text = "📋  Copy to Clipboard"
CopyBtn.TextColor3 = Color3.new(1,1,1)
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 13
CopyBtn.ZIndex = 12
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 12)

CopyBtn.MouseButton1Up:Connect(function()
    local content = logGet()
    if content == "" then
        CopyBtn.Text = "⚠ Log is empty"
    elseif setclipboard then
        setclipboard(content)
        CopyBtn.Text = "✓ Copied!"
    else
        CopyBtn.Text = "⚠ No clipboard API"
    end
    task.delay(1.8, function()
        CopyBtn.Text = "📋  Copy to Clipboard"
    end)
end)

-- Slide animation
local logOpen = false
local function openLog()
    logOpen = true
    TweenService:Create(LogPanel, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
end
local function closeLog()
    logOpen = false
    TweenService:Create(LogPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {
        Position = UDim2.new(1, 0, 0, 0)
    }):Play()
end
BackBtn.MouseButton1Up:Connect(closeLog)

local function updateLogDisplay()
    local content = logGet()
    LogText.Text = content ~= "" and content or "(empty)"
    -- Scroll to bottom
    task.defer(function()
        LogScroll.CanvasPosition = Vector2.new(0, math.huge)
    end)
end

-- === DRAG (title bar) ===
local dragging, dragStart, startPos = false, nil, nil

local TitleBar = Instance.new("Frame", Frame)
TitleBar.Size = UDim2.new(1, 0, 0, 48)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 20, 55)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 16)

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(200, 170, 255)
TitleLabel.Text = "⚡ Pop It Menu"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size = UDim2.new(0, 36, 0, 36)
CloseBtn.Position = UDim2.new(1, -42, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = i.Position; startPos = Frame.Position
    end
end)
TitleBar.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1) then
        local d = i.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                   startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
TitleBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- === STATUS ===
local Status = Instance.new("TextLabel", Frame)
Status.Size = UDim2.new(1, -20, 0, 26)
Status.Position = UDim2.new(0, 10, 0, 52)
Status.BackgroundTransparency = 1
Status.TextColor3 = Color3.fromRGB(100, 220, 140)
Status.Font = Enum.Font.Gotham
Status.TextSize = 12
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Text = "● Ready"

local function setStatus(msg, color)
    Status.Text = "● " .. msg
    Status.TextColor3 = color or Color3.fromRGB(100, 220, 140)
end

-- === SCROLL CONTAINER ===
local Scroll = Instance.new("ScrollingFrame", Frame)
Scroll.Size = UDim2.new(1, 0, 1, -84)
Scroll.Position = UDim2.new(0, 0, 0, 82)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 60, 160)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 8)
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local Pad = Instance.new("UIPadding", Scroll)
Pad.PaddingTop = UDim.new(0, 6)
Pad.PaddingLeft = UDim.new(0, 10)
Pad.PaddingRight = UDim.new(0, 10)
Pad.PaddingBottom = UDim.new(0, 10)

-- === BUTTON FACTORY ===
local function MakeButton(icon, label, desc, color, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 64)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

    local iL = Instance.new("TextLabel", btn)
    iL.Size = UDim2.new(0, 48, 1, 0)
    iL.Position = UDim2.new(0, 8, 0, 0)
    iL.BackgroundTransparency = 1
    iL.TextColor3 = Color3.new(1,1,1)
    iL.Text = icon
    iL.Font = Enum.Font.GothamBold
    iL.TextSize = 26

    local tL = Instance.new("TextLabel", btn)
    tL.Size = UDim2.new(1, -64, 0, 28)
    tL.Position = UDim2.new(0, 58, 0, 8)
    tL.BackgroundTransparency = 1
    tL.TextColor3 = Color3.new(1,1,1)
    tL.Text = label
    tL.Font = Enum.Font.GothamBold
    tL.TextSize = 14
    tL.TextXAlignment = Enum.TextXAlignment.Left

    local dL = Instance.new("TextLabel", btn)
    dL.Size = UDim2.new(1, -64, 0, 20)
    dL.Position = UDim2.new(0, 58, 0, 34)
    dL.BackgroundTransparency = 1
    dL.TextColor3 = Color3.fromRGB(200,200,200)
    dL.Text = desc
    dL.Font = Enum.Font.Gotham
    dL.TextSize = 11
    dL.TextXAlignment = Enum.TextXAlignment.Left

    local baseColor = color
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.07), {
            BackgroundColor3 = Color3.fromRGB(
                math.clamp(baseColor.R*255+35,0,255)/255,
                math.clamp(baseColor.G*255+35,0,255)/255,
                math.clamp(baseColor.B*255+35,0,255)/255
            )
        }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = baseColor}):Play()
        callback()
    end)
    return btn
end

-- === CORE FUNCTIONS ===
local function injectMoney()
    setStatus("Injecting...", Color3.fromRGB(255,200,60))
    logPush("\n[MONEY INJECT] " .. os.date and os.date() or "")
    local ok, err = pcall(function()
        local root = ReplicatedStorage:FindFirstChild("Remotes")
            or ReplicatedStorage:FindFirstChild("Events")
            or ReplicatedStorage
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local n = obj.Name:lower()
                if n:find("cash") or n:find("money") or n:find("coin")
                or n:find("currency") or n:find("earn") or n:find("reward") then
                    logPush("  FIRE -> " .. obj:GetFullName())
                    pcall(function()
                        if obj:IsA("RemoteEvent") then obj:FireServer(999999)
                        else obj:InvokeServer(999999) end
                    end)
                end
            end
        end
        local s = LocalPlayer:FindFirstChild("leaderstats")
        if s then
            for _, v in ipairs(s:GetChildren()) do
                pcall(function()
                    logPush("  WRITE leaderstats." .. v.Name .. " += 999999")
                    v.Value = v.Value + 999999
                end)
            end
        end
    end)
    logPush(ok and "  [OK]" or "  [ERR] "..tostring(err))
    setStatus(ok and "Money injected" or "Error: "..tostring(err),
              ok and Color3.fromRGB(100,220,140) or Color3.fromRGB(255,80,80))
    updateLogDisplay()
end

local function dupeItems()
    setStatus("Duping...", Color3.fromRGB(255,200,60))
    logPush("\n[DUPE PASS]")
    local ok, err = pcall(function()
        local root = ReplicatedStorage:FindFirstChild("Remotes")
            or ReplicatedStorage:FindFirstChild("Events")
            or ReplicatedStorage
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local n = obj.Name:lower()
                if n:find("trade") or n:find("give") or n:find("item")
                or n:find("equip") or n:find("dupe") or n:find("transfer") then
                    logPush("  FIRE -> " .. obj:GetFullName())
                    pcall(function()
                        if obj:IsA("RemoteEvent") then
                            obj:FireServer(LocalPlayer, LocalPlayer.UserId, 999)
                        else obj:InvokeServer(LocalPlayer, LocalPlayer.UserId, 999) end
                    end)
                end
            end
        end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                logPush("  CLONE -> " .. tool.Name)
                pcall(function() tool:Clone().Parent = bp end)
            end
        end
    end)
    logPush(ok and "  [OK]" or "  [ERR] "..tostring(err))
    setStatus(ok and "Dupe pass complete" or "Error: "..tostring(err),
              ok and Color3.fromRGB(100,220,140) or Color3.fromRGB(255,80,80))
    updateLogDisplay()
end

local function dumpInventory()
    setStatus("Dumping inventory...", Color3.fromRGB(255,200,60))
    logPush("\n[INVENTORY DUMP]")
    local ok, err = pcall(function()
        local s = LocalPlayer:FindFirstChild("leaderstats")
        if s then
            logPush("  [Leaderstats]")
            for _, v in ipairs(s:GetChildren()) do
                logPush("    " .. v.Name .. ": " .. tostring(v.Value))
            end
        end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            logPush("  [Backpack]")
            for _, i in ipairs(bp:GetChildren()) do
                logPush("    " .. i.Name .. " [" .. i.ClassName .. "]")
            end
        end
        local char = LocalPlayer.Character
        if char then
            logPush("  [Equipped]")
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Tool") then
                    logPush("    " .. obj.Name)
                end
            end
        end
    end)
    logPush(ok and "  [OK]" or "  [ERR] "..tostring(err))
    setStatus(ok and "Inventory dumped" or "Error: "..tostring(err),
              ok and Color3.fromRGB(100,220,140) or Color3.fromRGB(255,80,80))
    updateLogDisplay()
end

local function fullDump()
    setStatus("Full dump running...", Color3.fromRGB(255,200,60))
    logClear()
    logPush("=== FULL GAME DUMP ===")

    local function sweep(root, name)
        logPush("\n-- " .. name)
        local found = 0
        for _, obj in ipairs(root:GetDescendants()) do
            local t = obj.ClassName
            if t=="RemoteEvent" or t=="RemoteFunction"
            or t=="BindableEvent" or t=="BindableFunction"
            or t=="ModuleScript" then
                logPush(string.format("  [%-18s] %s", t, obj:GetFullName()))
                found = found + 1
            end
        end
        if found == 0 then logPush("  (none)") end
    end

    pcall(function() sweep(ReplicatedStorage, "ReplicatedStorage") end)
    pcall(function() sweep(game:GetService("Workspace"), "Workspace") end)
    pcall(function() sweep(game:GetService("StarterGui"), "StarterGui") end)
    pcall(function() sweep(game:GetService("StarterPack"), "StarterPack") end)
    pcall(function() sweep(LocalPlayer, "LocalPlayer") end)

    -- Values
    logPush("\n-- CONFIG VALUES (ReplicatedStorage)")
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        local t = obj.ClassName
        if t=="StringValue" or t=="NumberValue" or t=="IntValue"
        or t=="BoolValue" or t=="Color3Value" or t=="Vector3Value" then
            logPush(string.format("  [%-12s] %-35s = %s", t, obj.Name, tostring(obj.Value)))
        end
    end

    -- Player data
    logPush("\n-- PLAYER DATA")
    for _, obj in ipairs(LocalPlayer:GetChildren()) do
        logPush("  " .. obj.ClassName .. " -> " .. obj.Name)
        for _, child in ipairs(obj:GetChildren()) do
            local val = ""
            pcall(function() val = tostring(child.Value) end)
            logPush("    " .. child.Name .. " [" .. child.ClassName .. "] " .. val)
        end
    end

    -- Workspace top-level
    logPush("\n-- WORKSPACE STRUCTURE")
    for _, obj in ipairs(game:GetService("Workspace"):GetChildren()) do
        logPush("  " .. obj.ClassName .. " -> " .. obj.Name)
    end

    logPush("\n=== END ===")
    setStatus("Full dump complete", Color3.fromRGB(100,220,140))
    updateLogDisplay()
    openLog()
end

local function openLogPanel()
    updateLogDisplay()
    openLog()
end

-- === BUTTONS ===
MakeButton("💰", "Get Money",    "Inject currency",         Color3.fromRGB(40,130,70),  injectMoney)
MakeButton("📦", "Dupe Items",   "Clone backpack items",    Color3.fromRGB(60,70,180),  dupeItems)
MakeButton("📋", "Dump Inv",     "Print inventory to log",  Color3.fromRGB(140,50,50),  dumpInventory)
MakeButton("🔍", "Full Dump",    "All remotes + open log",  Color3.fromRGB(90,50,140),  fullDump)
MakeButton("📜", "Log",          "View full output log",    Color3.fromRGB(40,80,120),  openLogPanel)
