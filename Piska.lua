-- Pop It Trading | Mobile Menu v4.0
-- Compact: 44px buttons, 260w frame
-- Remotes wired from actual dump

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

pcall(function()
    game:GetService("CoreGui"):FindFirstChild("PIMMenu"):Destroy()
end)

-- === REMOTE REFS (from dump) ===
local RE = RS:WaitForChild("RemoteEvents", 5)
local function re(n) return RE and RE:FindFirstChild(n) end
local function rf(n) return RE and RE:FindFirstChild(n) end

-- === LOG ===
local logBuf = {}
local LogText -- forward ref

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

local function lc() logBuf = {} if LogText then LogText.Text = "(empty)" end end

-- === ROOT ===
local SG = Instance.new("ScreenGui")
SG.Name = "PIMMenu"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = game:GetService("CoreGui")

local F = Instance.new("Frame", SG)
F.Size = UDim2.new(0, 230, 0, 0)
F.AutomaticSize = Enum.AutomaticSize.Y
F.Position = UDim2.new(0, 8, 0, 60)
F.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
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
        F.Position = UDim2.new(dp.X.Scale, dp.X.Offset+d.X,
                               dp.Y.Scale, dp.Y.Offset+d.Y)
    end
end)
F.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch
    or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)

-- === TITLE ===
local TB = Instance.new("Frame", F)
TB.Size = UDim2.new(1, 0, 0, 32)
TB.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
TB.BorderSizePixel = 0
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 12)

local TL = Instance.new("TextLabel", TB)
TL.Size = UDim2.new(1, -38, 1, 0)
TL.Position = UDim2.new(0, 10, 0, 0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.fromRGB(190, 160, 255)
TL.Text = "⚡ Pop It"
TL.Font = Enum.Font.GothamBold
TL.TextSize = 13
TL.TextXAlignment = Enum.TextXAlignment.Left

local XB = Instance.new("TextButton", TB)
XB.Size = UDim2.new(0, 26, 0, 26)
XB.Position = UDim2.new(1, -30, 0, 3)
XB.BackgroundColor3 = Color3.fromRGB(160, 36, 54)
XB.Text = "✕"
XB.TextColor3 = Color3.new(1,1,1)
XB.Font = Enum.Font.GothamBold
XB.TextSize = 11
Instance.new("UICorner", XB).CornerRadius = UDim.new(0, 6)
XB.MouseButton1Up:Connect(function() SG:Destroy() end)

-- === STATUS ===
local ST = Instance.new("TextLabel", F)
ST.Size = UDim2.new(1, -12, 0, 20)
ST.Position = UDim2.new(0, 6, 0, 34)
ST.BackgroundTransparency = 1
ST.TextColor3 = Color3.fromRGB(90, 210, 120)
ST.Font = Enum.Font.Gotham
ST.TextSize = 11
ST.TextXAlignment = Enum.TextXAlignment.Left
ST.Text = "● Ready"

local function ss(msg, col)
    ST.Text = "● "..msg
    ST.TextColor3 = col or Color3.fromRGB(90,210,120)
end

-- === BUTTON LIST ===
local BL = Instance.new("Frame", F)
BL.Size = UDim2.new(1, 0, 0, 0)
BL.AutomaticSize = Enum.AutomaticSize.Y
BL.Position = UDim2.new(0, 0, 0, 56)
BL.BackgroundTransparency = 1

local BLL = Instance.new("UIListLayout", BL)
BLL.Padding = UDim.new(0, 4)
BLL.HorizontalAlignment = Enum.HorizontalAlignment.Center

local BLP = Instance.new("UIPadding", BL)
BLP.PaddingLeft = UDim.new(0, 6)
BLP.PaddingRight = UDim.new(0, 6)
BLP.PaddingBottom = UDim.new(0, 8)

-- LOG PANEL (child of F, slides over)
local LP_Frame = Instance.new("Frame", F)
LP_Frame.Size = UDim2.new(1, 0, 0, 320)
LP_Frame.Position = UDim2.new(1, 0, 0, 0)
LP_Frame.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
LP_Frame.BorderSizePixel = 0
LP_Frame.ZIndex = 20
LP_Frame.ClipsDescendants = true
LP_Frame.Visible = false
Instance.new("UICorner", LP_Frame).CornerRadius = UDim.new(0, 12)

local LPBar = Instance.new("Frame", LP_Frame)
LPBar.Size = UDim2.new(1, 0, 0, 30)
LPBar.BackgroundColor3 = Color3.fromRGB(18, 12, 40)
LPBar.BorderSizePixel = 0
LPBar.ZIndex = 21
Instance.new("UICorner", LPBar).CornerRadius = UDim.new(0, 12)

local LPTitle = Instance.new("TextLabel", LPBar)
LPTitle.Size = UDim2.new(1, -36, 1, 0)
LPTitle.Position = UDim2.new(0, 10, 0, 0)
LPTitle.BackgroundTransparency = 1
LPTitle.TextColor3 = Color3.fromRGB(170, 130, 255)
LPTitle.Text = "📋 Log"
LPTitle.Font = Enum.Font.GothamBold
LPTitle.TextSize = 12
LPTitle.TextXAlignment = Enum.TextXAlignment.Left
LPTitle.ZIndex = 22

local BackB = Instance.new("TextButton", LPBar)
BackB.Size = UDim2.new(0, 26, 0, 24)
BackB.Position = UDim2.new(1, -30, 0, 3)
BackB.BackgroundColor3 = Color3.fromRGB(44, 44, 72)
BackB.Text = "←"
BackB.TextColor3 = Color3.new(1,1,1)
BackB.Font = Enum.Font.GothamBold
BackB.TextSize = 12
BackB.ZIndex = 22
Instance.new("UICorner", BackB).CornerRadius = UDim.new(0, 6)

local LogScr = Instance.new("ScrollingFrame", LP_Frame)
LogScr.Size = UDim2.new(1, -8, 1, -72)
LogScr.Position = UDim2.new(0, 4, 0, 33)
LogScr.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
LogScr.BorderSizePixel = 0
LogScr.ScrollBarThickness = 2
LogScr.ScrollBarImageColor3 = Color3.fromRGB(70, 50, 140)
LogScr.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScr.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScr.ZIndex = 21
Instance.new("UICorner", LogScr).CornerRadius = UDim.new(0, 6)

local LPad = Instance.new("UIPadding", LogScr)
LPad.PaddingAll = UDim.new(0, 5)

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
LogText.Text = "(empty)"
LogText.ZIndex = 22

local CopyB = Instance.new("TextButton", LP_Frame)
CopyB.Size = UDim2.new(1, -12, 0, 30)
CopyB.Position = UDim2.new(0, 6, 1, -36)
CopyB.BackgroundColor3 = Color3.fromRGB(36, 100, 60)
CopyB.Text = "📋 Copy"
CopyB.TextColor3 = Color3.new(1,1,1)
CopyB.Font = Enum.Font.GothamBold
CopyB.TextSize = 12
CopyB.ZIndex = 22
Instance.new("UICorner", CopyB).CornerRadius = UDim.new(0, 8)

CopyB.MouseButton1Up:Connect(function()
    local s = table.concat(logBuf, "\n")
    if s == "" then CopyB.Text = "⚠ Empty"
    elseif setclipboard then setclipboard(s); CopyB.Text = "✓ Copied"
    else CopyB.Text = "⚠ No API" end
    task.delay(1.6, function() CopyB.Text = "📋 Copy" end)
end)

local function openLog()
    LP_Frame.Visible = true
    LP_Frame.Position = UDim2.new(0, 0, 0, 0)
end
BackB.MouseButton1Up:Connect(function()
    LP_Frame.Visible = false
end)

-- === BUTTON FACTORY ===
local function btn(icon, label, col, cb)
    local b = Instance.new("TextButton", BL)
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = col
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

    local il = Instance.new("TextLabel", b)
    il.Size = UDim2.new(0, 34, 1, 0)
    il.BackgroundTransparency = 1
    il.TextColor3 = Color3.new(1,1,1)
    il.Text = icon
    il.Font = Enum.Font.GothamBold
    il.TextSize = 16

    local tl = Instance.new("TextLabel", b)
    tl.Size = UDim2.new(1, -38, 1, 0)
    tl.Position = UDim2.new(0, 36, 0, 0)
    tl.BackgroundTransparency = 1
    tl.TextColor3 = Color3.new(1,1,1)
    tl.Text = label
    tl.Font = Enum.Font.GothamSemibold
    tl.TextSize = 12
    tl.TextXAlignment = Enum.TextXAlignment.Left

    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.06), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(col.R*255+40,255)/255,
                math.min(col.G*255+40,255)/255,
                math.min(col.B*255+40,255)/255)
        }):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3=col}):Play()
        cb()
    end)
    return b
end

-- === ACTIONS (real remotes from dump) ===

local function doMoney()
    ss("Injecting...", Color3.fromRGB(255,200,50))
    lp("\n[MONEY INJECT]")
    pcall(function()
        -- Direct cash remotes from dump
        local targets = {"BuyCash","BuyCash500","BuyCash1000","BuyCash10000"}
        for _, name in ipairs(targets) do
            local r = re(name)
            if r then
                lp("  FireServer -> "..name)
                pcall(function() r:FireServer() end)
            end
        end
        -- GetItem — general item grant surface
        local gi = re("GetItem")
        if gi then
            lp("  FireServer -> GetItem")
            pcall(function() gi:FireServer() end)
        end
        -- Leaderstats direct write
        local s = LP:FindFirstChild("leaderstats")
        if s then
            for _, v in ipairs(s:GetChildren()) do
                pcall(function()
                    lp("  Write leaderstats."..v.Name.." += 999999")
                    v.Value = v.Value + 999999
                end)
            end
        end
    end)
    lp("  [done]")
    ss("Money done", Color3.fromRGB(90,210,120))
end

local function doDupe()
    ss("Duping...", Color3.fromRGB(255,200,50))
    lp("\n[DUPE]")
    pcall(function()
        -- ReDrop — re-grant last dropped item
        local rd = re("ReDrop")
        if rd then lp("  FireServer -> ReDrop"); pcall(function() rd:FireServer() end) end
        -- OpenSpawnerReward
        local osr = re("OpenSpawnerReward")
        if osr then lp("  FireServer -> OpenSpawnerReward"); pcall(function() osr:FireServer() end) end
        -- ClaimPrize (RemoteFunction)
        local cp = rf("ClaimPrize")
        if cp then lp("  Invoke -> ClaimPrize"); pcall(function() cp:InvokeServer() end) end
        -- FruitClaim
        local fc = rf("FruitClaim")
        if fc then lp("  Invoke -> FruitClaim"); pcall(function() fc:InvokeServer() end) end
        -- Backpack clone
        local bp = LP:FindFirstChild("Backpack")
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                pcall(function()
                    lp("  Clone -> "..tool.Name)
                    tool:Clone().Parent = bp
                end)
            end
        end
    end)
    lp("  [done]")
    ss("Dupe done", Color3.fromRGB(90,210,120))
end

local function doSpin()
    ss("Spinning wheel...", Color3.fromRGB(255,200,50))
    lp("\n[SPIN WHEEL]")
    pcall(function()
        -- RequireWheelItemData first, then SpinWheel
        local rwd = rf("RequireWheelItemData")
        if rwd then
            lp("  Invoke -> RequireWheelItemData")
            pcall(function()
                local data = rwd:InvokeServer()
                lp("  WheelData: "..tostring(data))
            end)
        end
        local sw = rf("SpinWheel")
        if sw then
            lp("  Invoke -> SpinWheel")
            pcall(function()
                local result = sw:InvokeServer()
                lp("  Result: "..tostring(result))
            end)
        end
    end)
    lp("  [done]")
    ss("Spin done", Color3.fromRGB(90,210,120))
    openLog()
end

local function doCalendar()
    ss("Claiming calendar...", Color3.fromRGB(255,200,50))
    lp("\n[CALENDAR CLAIM]")
    pcall(function()
        local gc = rf("GetCalendarItems")
        if gc then
            lp("  Invoke -> GetCalendarItems")
            pcall(function()
                local items = gc:InvokeServer()
                lp("  Items: "..tostring(items))
            end)
        end
        -- Claim each day 1-31
        local cd = rf("ClaimCalendarDay")
        if cd then
            for day = 1, 31 do
                pcall(function()
                    local r = cd:InvokeServer(day)
                    if r then lp("  Day "..day.." -> "..tostring(r)) end
                end)
            end
        end
    end)
    lp("  [done]")
    ss("Calendar done", Color3.fromRGB(90,210,120))
    openLog()
end

local function doGroupReward()
    ss("Claiming group reward...", Color3.fromRGB(255,200,50))
    lp("\n[GROUP REWARD]")
    pcall(function()
        local rg = re("RequestGroupReward")
        if rg then
            lp("  FireServer -> RequestGroupReward")
            pcall(function() rg:FireServer() end)
        end
        local cg = re("ClaimGroupReward")
        if cg then
            lp("  FireServer -> ClaimGroupReward")
            pcall(function() cg:FireServer() end)
        end
        local cu = rf("CheckGroupUniqueReward")
        if cu then
            lp("  Invoke -> CheckGroupUniqueReward")
            pcall(function()
                local r = cu:InvokeServer()
                lp("  Result: "..tostring(r))
            end)
        end
    end)
    lp("  [done]")
    ss("Group reward done", Color3.fromRGB(90,210,120))
end

local function doCode()
    ss("Requesting code...", Color3.fromRGB(255,200,50))
    lp("\n[CODE REDEEM]")
    -- Common codes seen in Pop It Trading
    local codes = {"FREECASH","FREE","COINS","REWARD","UPDATE","SECRET","HOLIDAY"}
    pcall(function()
        local rc = re("RequestCode")
        if rc then
            for _, code in ipairs(codes) do
                pcall(function()
                    lp("  FireServer -> RequestCode("..code..")")
                    rc:FireServer(code)
                    task.wait(0.3)
                end)
            end
        end
    end)
    lp("  [done]")
    ss("Codes fired", Color3.fromRGB(90,210,120))
end

local function doFullDump()
    ss("Full dump...", Color3.fromRGB(255,200,50))
    lc()
    lp("=== FULL DUMP ===")

    local services = {
        {"ReplicatedStorage", RS},
        {"Workspace", game:GetService("Workspace")},
        {"StarterGui", game:GetService("StarterGui")},
        {"StarterPack", game:GetService("StarterPack")},
        {"Players.LocalPlayer", LP},
    }

    for _, pair in ipairs(services) do
        local name, svc = pair[1], pair[2]
        lp("\n-- "..name)
        pcall(function()
            for _, obj in ipairs(svc:GetDescendants()) do
                local t = obj.ClassName
                if t=="RemoteEvent" or t=="RemoteFunction"
                or t=="BindableEvent" or t=="BindableFunction"
                or t=="ModuleScript" then
                    lp("  ["..t.."] "..obj:GetFullName())
                end
            end
        end)
    end

    -- Values
    lp("\n-- VALUES")
    pcall(function()
        for _, obj in ipairs(RS:GetDescendants()) do
            local t = obj.ClassName
            if t=="StringValue" or t=="NumberValue" or t=="IntValue"
            or t=="BoolValue" or t=="Color3Value" or t=="Vector3Value" then
                lp("  ["..t.."] "..obj.Name.." = "..tostring(obj.Value))
            end
        end
    end)

    -- Player children (all, deep)
    lp("\n-- PLAYER INSTANCES")
    pcall(function()
        for _, obj in ipairs(LP:GetDescendants()) do
            local val = ""
            pcall(function() val = " = "..tostring(obj.Value) end)
            lp("  ["..obj.ClassName.."] "..obj:GetFullName()..val)
        end
    end)

    -- PlayerGui scripts
    lp("\n-- PLAYER GUI SCRIPTS")
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    lp("  ["..obj.ClassName.."] "..obj:GetFullName())
                end
            end
        end
    end)

    lp("\n=== END ===")
    ss("Dump done", Color3.fromRGB(90,210,120))
    openLog()
end

-- === WIRE ===
btn("💰","Money",        Color3.fromRGB(36,110,60),  doMoney)
btn("📦","Dupe",         Color3.fromRGB(50,60,160),  doDupe)
btn("🎰","Spin Wheel",   Color3.fromRGB(120,50,140), doSpin)
btn("📅","Calendar",     Color3.fromRGB(140,80,20),  doCalendar)
btn("👥","Group Reward", Color3.fromRGB(20,90,120),  doGroupReward)
btn("🎟","Codes",        Color3.fromRGB(100,36,36),  doCode)
btn("🔍","Full Dump",    Color3.fromRGB(40,40,70),   doFullDump)
btn("📜","Log",          Color3.fromRGB(28,28,50),   openLog)
