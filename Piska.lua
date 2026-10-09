-- Pop It Trading | Full Remote Dump
-- Surfaces: RemoteEvent, RemoteFunction, BindableEvent, BindableFunction
-- Output: console + clipboard (if executor supports setclipboard)

local function dumpGame()
    local Players        = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ServerScriptService = game:GetService("ServerScriptService")
    local StarterGui     = game:GetService("StarterGui")
    local StarterPack    = game:GetService("StarterPack")
    local Workspace      = game:GetService("Workspace")
    local LocalPlayer    = Players.LocalPlayer

    local lines = {}
    local function push(s) table.insert(lines, s) end
    local function header(s) push("\n=== " .. s .. " ===") end
    local function indent(k, v) push(string.format("  %-45s %s", k, tostring(v))) end

    -- === REMOTE SWEEP ===
    local function sweepRemotes(root, rootName)
        header("REMOTES: " .. rootName)
        local count = 0
        for _, obj in ipairs(root:GetDescendants()) do
            local path = obj:GetFullName()
            local t = obj.ClassName
            if t == "RemoteEvent" or t == "RemoteFunction"
            or t == "BindableEvent" or t == "BindableFunction" then
                indent(t, path)
                count = count + 1
            end
        end
        if count == 0 then push("  (none found)") end
    end

    sweepRemotes(ReplicatedStorage, "ReplicatedStorage")
    sweepRemotes(Workspace, "Workspace")

    -- StarterGui / StarterPack — client-accessible
    pcall(function() sweepRemotes(StarterGui, "StarterGui") end)
    pcall(function() sweepRemotes(StarterPack, "StarterPack") end)

    -- Player-owned remotes
    pcall(function()
        sweepRemotes(LocalPlayer, "LocalPlayer")
    end)

    -- === MODULE SWEEP (ReplicatedStorage) ===
    header("MODULES: ReplicatedStorage")
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") then
            indent("ModuleScript", obj:GetFullName())
        end
    end

    -- === VALUES (config/state exposed client-side) ===
    header("VALUES: ReplicatedStorage")
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        local t = obj.ClassName
        if t == "StringValue" or t == "NumberValue" or t == "IntValue"
        or t == "BoolValue" or t == "ObjectValue" or t == "Color3Value"
        or t == "Vector3Value" then
            indent(t .. " [" .. obj.Name .. "]", tostring(obj.Value))
        end
    end

    -- === LEADERSTATS ===
    header("LEADERSTATS: LocalPlayer")
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then
        for _, v in ipairs(stats:GetChildren()) do
            indent(v.ClassName .. " [" .. v.Name .. "]", tostring(v.Value))
        end
    else
        push("  (no leaderstats found)")
    end

    -- === PLAYER DATA (all child instances) ===
    header("PLAYER DATA: LocalPlayer children")
    for _, obj in ipairs(LocalPlayer:GetChildren()) do
        if obj.Name ~= "leaderstats" then
            indent(obj.ClassName, obj.Name)
            -- One level deep
            for _, child in ipairs(obj:GetChildren()) do
                indent("  " .. child.ClassName .. " [" .. child.Name .. "]", tostring(
                    pcall(function() return child.Value end) and child.Value or "N/A"
                ))
            end
        end
    end

    -- === BACKPACK ===
    header("BACKPACK")
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            indent(item.ClassName, item.Name)
        end
    else
        push("  (empty)")
    end

    -- === EQUIPPED (Character tools) ===
    header("EQUIPPED")
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then
                indent("Tool", obj.Name)
            end
        end
    end

    -- === PLAYERSCRIPTS / LOCALGUIS ===
    header("PLAYER SCRIPTS")
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if ps then
        for _, obj in ipairs(ps:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                indent(obj.ClassName, obj:GetFullName())
            end
        end
    end

    header("LOCAL GUIS (PlayerGui)")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                indent(obj.ClassName, obj:GetFullName())
            end
        end
    end

    -- === WORKSPACE TOP-LEVEL (map structure) ===
    header("WORKSPACE TOP-LEVEL")
    for _, obj in ipairs(Workspace:GetChildren()) do
        indent(obj.ClassName, obj.Name)
    end

    -- === OUTPUT ===
    local result = table.concat(lines, "\n")
    print(result)
    if setclipboard then
        setclipboard(result)
        print("\n[DUMP] Copied to clipboard.")
    else
        print("\n[DUMP] setclipboard not available — console only.")
    end
end

dumpGame()
