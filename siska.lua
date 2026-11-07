-- ╔══════════════════════════════════════════════╗
-- ║  Piska.lua v7.0  «Ghost Mode»                ║
-- ║  Game: 120219252362013 | PlaceVersion 1221   ║
-- ╚══════════════════════════════════════════════╝
--
-- v7 ключевые изменения:
--   • GHOST TRAIN: хуки запускаются при старте, тренировка
--     идёт асинхронно — ты видишь нормальный мир, сервер
--     думает что ты в зале. Training_Bonus перехватывается
--     автоматически и кликается невидимо.
--   • GHOST THROW: бросок происходит без телепорта ты
--     остаёшься на месте, сервер обрабатывает бросок как будто
--     ты на площадке.
--   • THROW POWER MULTIPLIER: хукаем Throw_Start/Resolve,
--     патчим значение в данных броска × множитель.
--   • AUTO BUY BAIT (FoodShop): Shop_ClaimFree / Shop_Buy
--   • AUTO BUY STAND UPGRADE (Stand_Upgrade)
--   • AUTO BUY FENCE UPGRADE (Plot_UpgradeFence)
--   • Хуки ставятся при загрузке, не требуют ручного Init
--   • ThrowSequence GUI скрывается (динамический, как TrainingSequence)
--   • Player attrs: IncomeRate/CashMultiplier патчим локально

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

-- ╔══════════════════════════════════════════════════╗
-- ║  LOG (siska_log.txt)                             ║
-- ║  Пишется сразу на диск перед каждым шагом —      ║
-- ║  последняя строка покажет, где упало.            ║
-- ╚══════════════════════════════════════════════════╝
local LOG_FILE = "siska_log.txt"
local logBuf   = {}          -- запасной вариант, если нет appendfile
local t0       = os.clock()
local function log(msg)
    local line = string.format("[%s +%7.2fs] %s", os.date("%H:%M:%S"), os.clock() - t0, tostring(msg))
    if appendfile then
        pcall(appendfile, LOG_FILE, line .. "\n")
    elseif writefile then
        logBuf[#logBuf+1] = line
        pcall(writefile, LOG_FILE, table.concat(logBuf, "\n"))
    end
end
do  -- новый лог на каждый запуск
    if writefile then
        local exec = "?"
        if identifyexecutor then pcall(function() exec = tostring(identifyexecutor()) end) end
        pcall(writefile, LOG_FILE, "=== Piska v7 log | executor: " .. exec
            .. " | PlaceVersion: " .. tostring(game.PlaceVersion) .. " ===\n")
        logBuf[1] = "=== Piska v7 log ==="
    end
    log("script start | build r5: ReplicaSet via Disable, no hookfunction")
    log("API: hookfunction=" .. tostring(hookfunction ~= nil)
        .. " getconnections=" .. tostring(getconnections ~= nil)
        .. " newcclosure=" .. tostring(newcclosure ~= nil)
        .. " appendfile=" .. tostring(appendfile ~= nil)
        .. " readfile=" .. tostring(readfile ~= nil))
    -- ошибки скриптов игры/нашего скрипта тоже в лог
    pcall(function()
        game:GetService("ScriptContext").Error:Connect(function(msg, trace)
            log("LUA ERROR: " .. tostring(msg) .. " | " .. tostring(trace):sub(1, 200))
        end)
    end)
    -- метка жизни: по последней метке видно, когда именно игра упала
    task.spawn(function()
        local n = 0
        while true do
            task.wait(3)
            n += 1
            local fps = 0
            pcall(function() fps = math.floor(workspace:GetRealPhysicsFPS()) end)
            log("alive #" .. n .. " physFPS=" .. fps)
        end
    end)
end

local lp      = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
assert(Remotes, "[Z] Remotes not found")

-- ╔══════════════╗
-- ║    CONFIG    ║
-- ╚══════════════╝
local CFG = {
    -- Ghost Train (тренировка без видимой анимации)
    GhostTrain       = false,
    GhostTrainRate   = 0.015,  -- задержка между тапами
    GhostTrainTaps   = 100,    -- тапов за сессию

    -- Ghost Throw (бросок без телепорта)
    GhostThrow       = false,
    GhostThrowRate   = 0.6,    -- интервал бросков

    -- Множитель силы броска (патчим локально + в данных броска)
    ThrowMultiplier  = 1,      -- 1 = без изменений, 999999 = бесконечность
    ThrowMultiEnable = false,

    -- Auto Equip Best
    AutoEquipBest    = false,

    -- Money Farm
    AutoMoneyFarm    = false,
    SellRate         = 0.5,

    -- Auto Buy
    AutoBuyBait      = false,   -- Shop_Buy / Shop_ClaimFree для приманки
    AutoBuyStand     = false,   -- Stand_Upgrade авто апгрейд стенда
    AutoBuyFence     = false,   -- Plot_UpgradeFence авто апгрейд забора

    -- Stat inject через ReplicaSet+newindex
    AutoInjectStats  = false,
    InjectInterval   = 0.5,
    StatMoneyRaw     = 999e15,  -- $999Q
    StatMPSRaw       = 999e9,   -- $999B/s
    StatPower        = 99999,

    -- Прочее
    HideAllTrainGUI  = false,    -- скрывать Training*+Throw* ScreenGui
}

-- ╔══════════════════════════════════════════════════╗
-- ║  CONFIG SAVE / LOAD (txt-файл)                   ║
-- ║  Первый запуск: всё выключено, значения по       ║
-- ║  умолчанию. Дальше всё сохраняется в файл и      ║
-- ║  подгружается при следующих запусках.            ║
-- ╚══════════════════════════════════════════════════╝
local CONFIG_FILE = "siska_config.txt"
local pendingRestore = {}   -- {функция запуска, ...} для включённых тумблеров

local function loadConfig()
    log("loadConfig")
    if not (isfile and readfile) then log("loadConfig: no isfile/readfile"); return end
    local ok, text = pcall(function()
        if isfile(CONFIG_FILE) then return readfile(CONFIG_FILE) end
    end)
    if not ok or type(text) ~= "string" then log("loadConfig: no config file (defaults)"); return end
    log("loadConfig: file read, " .. #text .. " bytes")
    for line in text:gmatch("[^\r\n]+") do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k and CFG[k] ~= nil then
            if type(CFG[k]) == "boolean" then
                if v == "true" then CFG[k] = true
                elseif v == "false" then CFG[k] = false end
            elseif type(CFG[k]) == "number" then
                local n = tonumber(v)
                if n then CFG[k] = n end
            end
        end
    end
end

local function writeConfig()
    if not writefile then return end
    local keys = {}
    for k, v in pairs(CFG) do
        if type(v) == "boolean" or type(v) == "number" then keys[#keys+1] = k end
    end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local v = CFG[k]
        out[#out+1] = k .. "=" .. (type(v) == "number" and string.format("%.17g", v) or tostring(v))
    end
    pcall(writefile, CONFIG_FILE, table.concat(out, "\n"))
end

local saveQueued = false
local function saveConfig()   -- с задержкой, чтобы ползунок не писал файл на каждый пиксель
    if saveQueued then return end
    saveQueued = true
    task.delay(0.5, function()
        saveQueued = false
        writeConfig()
    end)
end

-- ╔══════════════════╗
-- ║  HELPERS         ║
-- ╚══════════════════╝
local seenRemote = {}
local function rf(name, ...)
    local r = Remotes:FindFirstChild(name)
    if r and r:IsA("RemoteFunction") then
        if not seenRemote[name] then seenRemote[name] = true; log("RF first call: " .. name) end
        local ok, res = pcall(r.InvokeServer, r, ...)
        if ok then return res end
        log("RF error " .. name .. ": " .. tostring(res):sub(1, 150))
    elseif not seenRemote["?" .. name] then
        seenRemote["?" .. name] = true
        log("RF not found: " .. name)
    end
end

local function re(name, ...)
    local r = Remotes:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then
        if not seenRemote["e" .. name] then seenRemote["e" .. name] = true; log("RE first fire: " .. name) end
        pcall(r.FireServer, r, ...)
    end
end

local function formatMoney(n)
    if not n then return "$0" end
    if n >= 1e18 then return string.format("$%.3gSp", n/1e18)
    elseif n >= 1e15 then return string.format("$%.3gQ", n/1e15)
    elseif n >= 1e12 then return string.format("$%.3gT", n/1e12)
    elseif n >= 1e9  then return string.format("$%.3gB", n/1e9)
    elseif n >= 1e6  then return string.format("$%.3gM", n/1e6)
    elseif n >= 1e3  then return string.format("$%.3gK", n/1e3)
    else return "$"..tostring(math.floor(n)) end
end

-- ╔══════════════════════════════════════════════════╗
-- ║  GHOST GUI WATCHER                               ║
-- ║  Скрываем TrainingSequence, ThrowSequence —      ║
-- ║  оба создаются динамически при Start RF          ║
-- ╚══════════════════════════════════════════════════╝
local function setupGuiWatcher()
    local function hideIfNeeded(child)
        if not CFG.HideAllTrainGUI then return end
        if child.Name == "TrainingSequence"
        or child.Name == "ThrowSequence" then
            pcall(function() child.Enabled = false end)
            -- на случай если Enabled устанавливается позже
            task.defer(function()
                pcall(function() child.Enabled = false end)
            end)
        end
    end
    lp.PlayerGui.ChildAdded:Connect(hideIfNeeded)
    -- скрываем уже существующие
    for _, c in ipairs(lp.PlayerGui:GetChildren()) do
        hideIfNeeded(c)
    end
end

-- Скрываем TrainingGui (статический)
local function setTrainingGui(hidden)
    local tg = lp.PlayerGui:FindFirstChild("TrainingGui")
    if tg then tg.Enabled = not hidden end
    local ts = lp.PlayerGui:FindFirstChild("TrainingSequence")
    if ts then ts.Enabled = not hidden end
end

-- ╔══════════════════════════════════════════════════╗
-- ║  TRAINING_BONUS AUTO-CLICKER                     ║
-- ║  Слушаем RE Training_Bonus (сервер шлёт когда    ║
-- ║  появляется кнопка x2). Автоматически вызываем   ║
-- ║  Training_TapBonus сразу — без участия игрока.   ║
-- ╚══════════════════════════════════════════════════╝
local function setupTrainingBonusHook()
    local bonusRE = Remotes:WaitForChild("Training_Bonus", 10)
    if not bonusRE then return end
    bonusRE.OnClientEvent:Connect(function(count, timestamp)
        -- Сервер прислал Training_Bonus — кнопка x2 показалась
        -- Немедленно нажимаем (RF TapBonus) столько раз сколько count
        task.spawn(function()
            for i = 1, math.max(1, count or 1) do
                rf("Training_TapBonus")
                task.wait(0.01)
            end
        end)
    end)
end

-- ╔══════════════════════════════════════════════════╗
-- ║  REPLICASET HOOK (stat inject)                   ║
-- ╚══════════════════════════════════════════════════╝
local replicaHooked = false
local function hookReplicaSet()
    if replicaHooked then return end
    local ok, err = pcall(function()
        log("RS 1: find remote")
        local reRE = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if not reRE then log("RS: RemoteEvents folder not found"); return end
        local rsRE = reRE:FindFirstChild("ReplicaSet")
        if not rsRE then log("RS: ReplicaSet remote not found"); return end
        if not getconnections then log("RS: no getconnections"); return end

        log("RS 2: getconnections")
        local conns = getconnections(rsRE.OnClientEvent)
        log("RS 3: connections found = " .. tostring(conns and #conns))

        -- собираем оригинальные обработчики (ничего пока не отключаем)
        local list = {}
        for i, conn in ipairs(conns) do
            local okF, fn = pcall(function() return conn.Function end)
            log("RS 4: conn #" .. i .. " Function=" .. (okF and type(fn) or "ERR"))
            if okF and type(fn) == "function" then list[#list+1] = {conn = conn, fn = fn} end
        end
        if #list == 0 then log("RS: nothing to wrap"); return end

        -- 1) сначала подключаем СВОЙ обработчик
        local originals = {}   -- заполняется только теми, кого реально удалось отключить
        local firstFire = true
        log("RS 5: connect own handler")
        rsRE.OnClientEvent:Connect(function(repId, path, value, ...)
            if firstFire then firstFire = false; log("RS: first event received") end
            if CFG.AutoInjectStats and type(path) == "table" then
                local f = path[1]
                if f == "Money"      then value = CFG.StatMoneyRaw end
                if f == "Money/s" or f == "MoneyPerSecond" then value = CFG.StatMPSRaw end
                if f == "ThrowPower" or f == "Throw Power" then value = CFG.StatPower end
            end
            for _, fn in ipairs(originals) do
                local okC, e = pcall(fn, repId, path, value, ...)
                if not okC then log("RS handler error: " .. tostring(e):sub(1, 150)) end
            end
        end)

        -- 2) потом по одному отключаем оригинальные и сразу передаём их нашему обработчику
        for i, item in ipairs(list) do
            log("RS 6: disable #" .. i)
            local okD = pcall(function() item.conn:Disable() end)
            if okD then originals[#originals+1] = item.fn end
            log("RS 6: disable #" .. i .. (okD and " ok" or " FAILED (оставлен как есть)"))
        end
        log("RS 7: done, wrapped = " .. #originals)
        replicaHooked = #originals > 0
    end)
    if not ok then log("RS ERROR: " .. tostring(err)) end
end

-- ╔══════════════════════════════════════════════════╗
-- ║  __NEWINDEX HOOK                                 ║
-- ╚══════════════════════════════════════════════════╝
local niHooked = false
local function hookNewindex()
    if niHooked then return end
    niHooked = true
    pcall(function()
        local mt = getrawmetatable(game)
        local oldNI = mt.__newindex
        setreadonly(mt, false)
        mt.__newindex = (newcclosure or function(f) return f end)(function(self, key, value)
            -- быстрый выход: почти все записи в игре идут здесь и не должны тормозить
            if key ~= "Value" or not CFG.AutoInjectStats then
                return oldNI(self, key, value)
            end
            if typeof(self) == "Instance" then
                local n = self.Name
                if n == "Money"       and self:IsA("StringValue") then value = formatMoney(CFG.StatMoneyRaw) end
                if n == "Throw Power" and self:IsA("IntValue")    then value = CFG.StatPower end
                if n == "Money/s"     and self:IsA("StringValue") then value = formatMoney(CFG.StatMPSRaw).."/s" end
            end
            return oldNI(self, key, value)
        end)
        setreadonly(mt, true)
    end)
end

-- ╔══════════════════════════════════════════════════╗
-- ║  THROW POWER MULTIPLIER HOOK                     ║
-- ║  Хукаем Throw_Start RF — патчим результат        ║
-- ║  Игра передаёт данные броска (force/direction),  ║
-- ║  умножаем силу в этих данных × ThrowMultiplier   ║
-- ╚══════════════════════════════════════════════════╝
local throwHooked = false
local inThrowHook = false   -- защита от рекурсии (внутри хука мы сами зовём rf)
local function hookThrowPower()
    if throwHooked then return end
    pcall(function()
        if not hookfunction then return end
        local throwRF = Remotes:FindFirstChild("Throw_Start")
        if not throwRF then return end

        local origInvoke
        origInvoke = hookfunction(throwRF.InvokeServer, (newcclosure or function(f) return f end)(function(self, ...)
            -- трогаем только Throw_Start, остальные RF проходят без изменений
            if self == throwRF and not inThrowHook
            and CFG.ThrowMultiEnable and CFG.ThrowMultiplier > 1 then
                inThrowHook = true
                local stats = lp:FindFirstChild("leaderstats")
                local basePow = 1000
                if stats then
                    local p = stats:FindFirstChild("Throw Power")
                    if p then basePow = tonumber(p.Value) or 1000 end
                end
                pcall(rf, "Player_SetThrowPower",
                    math.min(basePow * CFG.ThrowMultiplier, 2147483647))
                inThrowHook = false
            end
            return origInvoke(self, ...)
        end))
        throwHooked = true
    end)
end

-- ╔══════════════════════════════════════════════════╗
-- ║  THREADS                                         ║
-- ╚══════════════════════════════════════════════════╝
local threads = {}
local function killThread(key)
    if threads[key] then task.cancel(threads[key]); threads[key] = nil end
end

-- ── GHOST TRAIN ──────────────────────────────────
-- Тренировка идёт в фоне — ты видишь нормальный мир,
-- TrainingSequence/TrainingGui скрыты, Quality→Power растёт само.
-- Training_Bonus обрабатывается отдельным хуком (setupTrainingBonusHook)
local function startGhostTrain()
    killThread("ghosttrain")
    threads["ghosttrain"] = task.spawn(function()
        while CFG.GhostTrain do
            -- Прячем любые GUI тренировки
            setTrainingGui(true)

            local ok = rf("Training_Start")
            if not ok then
                setTrainingGui(false)
                task.wait(0.5)
                continue
            end

            -- Спам тапов — nil нормален, false = конец сессии
            for i = 1, CFG.GhostTrainTaps do
                if not CFG.GhostTrain then break end
                local r = rf("Training_TapBonus")
                if r == false then break end
                task.wait(CFG.GhostTrainRate)
            end

            rf("Training_Stop")
            setTrainingGui(false)
            task.wait(0.05)
        end
        setTrainingGui(false)
    end)
end

-- ── GHOST THROW ──────────────────────────────────
-- Бросок без телепорта: сохраняем позицию, делаем RF,
-- сервер думает что мы на площадке, клиент остаётся на месте.
-- ThrowSequence GUI скрывается через watcherом.
local blockTP = false
local savedCF  = nil

local function startGhostThrow()
    killThread("ghostthrow")
    threads["ghostthrow"] = task.spawn(function()
        while CFG.GhostThrow do
            local char = lp.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(0.5); continue end

            -- Запоминаем позицию — сервер будет телепортировать нас
            -- обратно в загон после броска, мы блокируем это
            savedCF = hrp.CFrame
            blockTP = true

            -- Если включён множитель — выставляем силу перед броском
            if CFG.ThrowMultiEnable and CFG.ThrowMultiplier > 1 then
                local stats = lp:FindFirstChild("leaderstats")
                local basePow = 1000
                if stats then
                    local p = stats:FindFirstChild("Throw Power")
                    if p then basePow = tonumber(p.Value) or 1000 end
                end
                pcall(rf, "Player_SetThrowPower", math.min(basePow * CFG.ThrowMultiplier, 2147483647))
            end

            -- Останавливаем все анимации чтобы не было видимого броска
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
                    pcall(t.AdjustSpeed, t, 0)
                end
            end

            -- Делаем бросок через RF
            local data = rf("Throw_Start")
            if data then
                rf("Throw_Resolve", data)
                rf("Throw_Complete")
            end

            -- Держим позицию ещё немного пока сервер не телепортирует нас
            task.wait(0.5)
            blockTP = false

            -- Возобновляем анимации
            if hum then
                for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
                    pcall(t.AdjustSpeed, t, 1)
                end
            end

            task.wait(CFG.GhostThrowRate)
        end
        blockTP = false
    end)
end

-- ── BLOCK RETURN TP ──────────────────────────────
local function setupReturnBlock()
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

-- ── MONEY FARM ───────────────────────────────────
local function startMoneyFarm()
    killThread("moneyfarm")
    threads["moneyfarm"] = task.spawn(function()
        rf("Plot_EquipBest")
        task.wait(0.5)
        local iter = 0
        while CFG.AutoMoneyFarm do
            rf("Plot_SellAll")
            iter += 1
            if iter % 10 == 0 then rf("Plot_EquipBest") end
            task.wait(CFG.SellRate)
        end
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

-- ── AUTO BUY BAIT ────────────────────────────────
-- Shop_ClaimFree = бесплатная приманка (если доступна)
-- Shop_Buy = покупка (если нужно)
-- Пробуем сначала ClaimFree, потом Buy
local function startAutoBuyBait()
    killThread("autobait")
    threads["autobait"] = task.spawn(function()
        while CFG.AutoBuyBait do
            -- Пробуем забрать бесплатное
            local freeRes = rf("Shop_ClaimFree")
            if not freeRes or freeRes == false then
                -- Если нет бесплатного — пробуем купить (index=1 первый слот)
                rf("Shop_Buy", 1)
            end
            task.wait(5) -- проверяем каждые 5 секунд
        end
    end)
end

-- ── AUTO UPGRADE STAND ───────────────────────────
-- Stand_Upgrade — апгрейдит стенд (продажный навес)
-- Делаем по одному апгрейду пока игра не откажет
local function startAutoUpgradeStand()
    killThread("autostand")
    threads["autostand"] = task.spawn(function()
        while CFG.AutoBuyStand do
            local res = rf("Stand_Upgrade")
            if res == false or res == nil then
                -- нет денег или макс уровень — ждём дольше
                task.wait(10)
            else
                task.wait(1)
            end
        end
    end)
end

-- ── AUTO UPGRADE FENCE ───────────────────────────
-- Plot_UpgradeFence — апгрейдит забор загона
local function startAutoUpgradeFence()
    killThread("autofence")
    threads["autofence"] = task.spawn(function()
        while CFG.AutoBuyFence do
            local res = rf("Plot_UpgradeFence")
            if res == false or res == nil then
                task.wait(10)
            else
                task.wait(1)
            end
        end
    end)
end

-- ── STAT INJECT ──────────────────────────────────
local function startInject()
    killThread("inject")
    pcall(hookReplicaSet)   -- хук ставится только когда реально нужен
    threads["inject"] = task.spawn(function()
        while CFG.AutoInjectStats do
            local stats = lp:FindFirstChild("leaderstats")
            if stats then
                local m = stats:FindFirstChild("Money")
                local p = stats:FindFirstChild("Throw Power")
                local r = stats:FindFirstChild("Money/s")
                if m then pcall(function() m.Value = formatMoney(CFG.StatMoneyRaw) end) end
                if p then pcall(function() p.Value = CFG.StatPower end) end
                if r then pcall(function() r.Value = formatMoney(CFG.StatMPSRaw).."/s" end) end
            end
            pcall(rf, "Player_SetThrowPower", CFG.StatPower)
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
        if m then pcall(function() m.Value = formatMoney(CFG.StatMoneyRaw) end) end
        if p then pcall(function() p.Value = CFG.StatPower end) end
        if r then pcall(function() r.Value = formatMoney(CFG.StatMPSRaw).."/s" end) end
    end
    pcall(rf, "Player_SetThrowPower", CFG.StatPower)
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
    orange  = Color3.fromRGB(220,120,30),
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
    local W_FULL, H_FULL = 300, 330      -- размер развёрнутого окна
    local W_MINI, H_MINI = 150, 40       -- размер свёрнутого
    local cam = workspace.CurrentCamera
    if cam then   -- на маленьком экране не вылезаем за края
        W_FULL = math.min(W_FULL, cam.ViewportSize.X - 20)
        H_FULL = math.min(H_FULL, cam.ViewportSize.Y - 20)
    end
    main.Size=UDim2.new(0,W_FULL,0,H_FULL); main.Position=UDim2.new(0.5,-W_FULL/2,0.5,-H_FULL/2)
    main.BackgroundColor3=C.bg; main.BorderSizePixel=0
    main.Active=true; main.ClipsDescendants=true
    mkCorner(main,12); mkStroke(main,C.accent,1.5)

    -- HEADER
    local header=Instance.new("Frame",main)
    header.Size=UDim2.new(1,0,0,40); header.BackgroundColor3=C.dim; header.BorderSizePixel=0
    mkCorner(header,12)
    local htitle=Instance.new("TextLabel",header)
    htitle.Size=UDim2.new(1,-50,1,0); htitle.Position=UDim2.new(0,14,0,0)
    htitle.BackgroundTransparency=1; htitle.Text="⚡ Z FARM v7"
    htitle.TextColor3=Color3.fromRGB(220,235,255); htitle.TextSize=13
    htitle.Font=FB; htitle.TextXAlignment=Enum.TextXAlignment.Left
    local minBtn=Instance.new("TextButton",header)
    minBtn.Size=UDim2.new(0,30,0,24); minBtn.Position=UDim2.new(1,-36,0.5,-12)
    minBtn.BackgroundColor3=Color3.fromRGB(45,50,75); minBtn.Text="—"
    minBtn.TextColor3=C.text; minBtn.TextSize=14; minBtn.Font=FB; minBtn.BorderSizePixel=0
    mkCorner(minBtn,5)

    -- TABBAR (5 табов)
    local tabBar=Instance.new("Frame",main)
    tabBar.Size=UDim2.new(1,-16,0,30); tabBar.Position=UDim2.new(0,8,0,44)
    tabBar.BackgroundColor3=C.panel; tabBar.BorderSizePixel=0
    mkCorner(tabBar,7); mkList(tabBar,Enum.FillDirection.Horizontal,2); mkPad(tabBar,3,3,3,3)

    -- SCROLL
    local scroll=Instance.new("ScrollingFrame",main)
    scroll.Size=UDim2.new(1,-16,1,-130); scroll.Position=UDim2.new(0,8,0,78)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=C.accent
    scroll.ScrollingEnabled=true; scroll.ScrollingDirection=Enum.ScrollingDirection.Y
    scroll.ElasticBehavior=Enum.ElasticBehavior.Always
    scroll.Active=true
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
    slbl.Text="loading..."
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
        btn.Size=UDim2.new(0.199,-2,1,0); btn.BackgroundColor3=Color3.fromRGB(32,36,55)
        btn.Text=icon; btn.TextColor3=C.sub; btn.TextSize=14
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
        lbl.TextSize=12; lbl.Font=FR; lbl.TextXAlignment=Enum.TextXAlignment.Left
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
            log("toggle " .. cfgKey .. " = " .. tostring(CFG[cfgKey]))
            if onToggle then onToggle(CFG[cfgKey]) end
            saveConfig()
        end)
        -- если тумблер был включён в сохранённом конфиге — запустим после старта
        if onToggle and CFG[cfgKey] then
            pendingRestore[#pendingRestore+1] = function() onToggle(true) end
        end
        return btn
    end

    local function addInputRow(parent,label,cfgKey,isNum)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,36); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(0.42,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.sub
        lbl.TextSize=11; lbl.Font=FR; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local box=Instance.new("TextBox",row)
        box.Size=UDim2.new(0,100,0,24); box.Position=UDim2.new(0.44,0,0.5,-12)
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
            saveConfig()
            setBtn.BackgroundColor3=C.on
            task.delay(0.4,function() setBtn.BackgroundColor3=C.accent end)
        end
        setBtn.MouseButton1Click:Connect(function() apply(box.Text) end)
        box.FocusLost:Connect(function(enter) if enter then apply(box.Text) end end)
        return box
    end

    -- Строка с множителем силы броска (ползунок + поле)
    local function addMultiplierRow(parent)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,70); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        mkPad(row,10,10,6,6)

        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(1,0,0,18); lbl.BackgroundTransparency=1
        lbl.Text="⚡ Throw Power Multiplier"; lbl.TextColor3=C.gold
        lbl.TextSize=12; lbl.Font=FB; lbl.TextXAlignment=Enum.TextXAlignment.Left

        -- Ползунок
        local track=Instance.new("Frame",row)
        track.Size=UDim2.new(1,-80,0,8); track.Position=UDim2.new(0,0,0,30)
        track.BackgroundColor3=Color3.fromRGB(40,45,70); track.BorderSizePixel=0
        mkCorner(track,4)
        local fill=Instance.new("Frame",track)
        fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=C.gold; fill.BorderSizePixel=0
        mkCorner(fill,4)
        local thumb=Instance.new("TextButton",track)
        thumb.Size=UDim2.new(0,16,0,16); thumb.Position=UDim2.new(0,-8,0.5,-8)
        thumb.BackgroundColor3=C.gold; thumb.Text=""; thumb.BorderSizePixel=0
        mkCorner(thumb,8)

        -- Поле ввода
        local box=Instance.new("TextBox",row)
        box.Size=UDim2.new(0,70,0,24); box.Position=UDim2.new(1,-70,0,28)
        box.BackgroundColor3=C.inputBg; box.Text="1"
        box.TextColor3=C.gold; box.TextSize=13; box.Font=FM
        box.ClearTextOnFocus=false; box.BorderSizePixel=0
        mkCorner(box,5); mkStroke(box,C.gold,1.2)

        local maxLog = 6 -- log10(1,000,000)
        local function updateSlider(val)
            val = math.max(1, val)
            CFG.ThrowMultiplier = val
            saveConfig()
            box.Text = tostring(val)
            local t = math.min(1, math.log10(math.max(1,val)) / maxLog)
            fill.Size = UDim2.new(t, 0, 1, 0)
            thumb.Position = UDim2.new(t, -8, 0.5, -8)
        end

        -- Перетаскивание
        local dragging = false
        thumb.MouseButton1Down:Connect(function()
            dragging = true
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType ~= Enum.UserInputType.MouseMovement
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
            local abs = track.AbsolutePosition
            local sz  = track.AbsoluteSize
            local t = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
            -- t → 10^(t*maxLog)
            local val = math.floor(10^(t*maxLog))
            updateSlider(val)
        end)

        box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if n and n >= 1 then updateSlider(n) end
        end)

        -- Пресеты
        local presets = {{l="x1",v=1},{l="x10",v=10},{l="x100",v=100},{l="x∞",v=2147483}}
        for i, pr in ipairs(presets) do
            local pb=Instance.new("TextButton",row)
            pb.Size=UDim2.new(0,38,0,18); pb.Position=UDim2.new((i-1)*0.25,0,0,46)
            pb.BackgroundColor3=C.dim; pb.Text=pr.l
            pb.TextColor3=C.gold; pb.TextSize=11; pb.Font=FB; pb.BorderSizePixel=0
            mkCorner(pb,4)
            pb.MouseButton1Click:Connect(function()
                updateSlider(pr.v)
                pb.BackgroundColor3=C.on
                task.delay(0.3,function() pb.BackgroundColor3=C.dim end)
            end)
        end

        updateSlider(CFG.ThrowMultiplier or 1)
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

    local function addNote(parent,text)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,42); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        mkPad(row,8,8,5,5)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
        lbl.Text=text; lbl.TextColor3=C.sub; lbl.TextSize=10; lbl.Font=FR
        lbl.TextWrapped=true; lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.TextYAlignment=Enum.TextYAlignment.Top
    end

    local function addRawPresetRow(parent,label,cfgKey)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,0,0,36); row.BackgroundColor3=C.panel; row.BorderSizePixel=0; mkCorner(row,7)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(0.3,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.sub
        lbl.TextSize=11; lbl.Font=FR; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local preview=Instance.new("TextLabel",row)
        preview.Size=UDim2.new(0,64,0,24); preview.Position=UDim2.new(0.32,0,0.5,-12)
        preview.BackgroundColor3=C.inputBg; preview.Text=formatMoney(CFG[cfgKey])
        preview.TextColor3=Color3.fromRGB(170,215,255); preview.TextSize=11; preview.Font=FM
        mkCorner(preview,5); mkPad(preview,4,0,0,0)
        local function bp(lbl2,val,xOff)
            local b=Instance.new("TextButton",row)
            b.Size=UDim2.new(0,30,0,24); b.Position=UDim2.new(1,xOff,0.5,-12)
            b.BackgroundColor3=C.dim; b.Text=lbl2; b.TextColor3=C.text; b.TextSize=9
            b.Font=FB; b.BorderSizePixel=0; mkCorner(b,4)
            b.MouseButton1Click:Connect(function()
                CFG[cfgKey]=val; preview.Text=formatMoney(val); saveConfig()
                b.BackgroundColor3=C.on; task.delay(0.3,function() b.BackgroundColor3=C.dim end)
            end)
        end
        bp("1B", 1e9,  -100); bp("1T", 1e12, -66); bp("1Q", 1e15, -32)
    end

    -- ════════════════════════════════════════
    -- ТАБ 1: 🏋️  TRAIN
    -- ════════════════════════════════════════
    local trainF=addTab("Train","🏋️")
    addSection(trainF,"── 👻 GHOST TRAIN ──")
    addNote(trainF,"Тренировка идёт в фоне.\nТы видишь мир, сервер видит зал.\nAnims/GUI скрыты автоматически.")
    addToggleRow(trainF,"👻 Ghost Train",    "GhostTrain", function(v)
        if v then startGhostTrain() else killThread("ghosttrain"); setTrainingGui(false) end
    end)
    addInputRow(trainF,"⏱ Tap rate (сек)", "GhostTrainRate", true)
    addInputRow(trainF,"🔢 Тапов/сессию",  "GhostTrainTaps", true)
    addNote(trainF,"Training_Bonus (кнопка x2) кликается\nавтоматически при получении RE от сервера.")
    addToggleRow(trainF,"🙈 Скрывать Training GUI", "HideAllTrainGUI", nil)
    addActionBtn(trainF,"🛑 Training_Stop",  C.off, function() rf("Training_Stop"); setTrainingGui(false) end)

    -- ════════════════════════════════════════
    -- ТАБ 2: 🎯  THROW
    -- ════════════════════════════════════════
    local throwF=addTab("Throw","🎯")
    addSection(throwF,"── 👻 GHOST THROW ──")
    addNote(throwF,"Бросок без телепорта. Ты остаёшься\nна месте, сервер обрабатывает бросок.\nThrowSequence GUI скрыт авто.")
    addToggleRow(throwF,"👻 Ghost Throw",   "GhostThrow",   function(v)
        if v then startGhostThrow() else killThread("ghostthrow"); blockTP=false end
    end)
    addInputRow(throwF,"⏱ Интервал (сек)", "GhostThrowRate", true)

    addSection(throwF,"── ⚡ THROW POWER MULTIPLIER ──")
    addToggleRow(throwF,"× Включить множитель", "ThrowMultiEnable", nil)
    addMultiplierRow(throwF)
    addNote(throwF,"Множитель × текущий ThrowPower перед\nкаждым броском через Player_SetThrowPower.\nx∞ = 2,147,483 (макс int32)")

    addSection(throwF,"── ПРОЧЕЕ ──")
    addActionBtn(throwF,"🎯 Бросить сейчас", C.accent, function()
        local d = rf("Throw_Start")
        if d then rf("Throw_Resolve",d); rf("Throw_Complete") end
    end)

    -- ════════════════════════════════════════
    -- ТАБ 3: 💰  FARM
    -- ════════════════════════════════════════
    local farmF=addTab("Farm","💰")
    addSection(farmF,"── MONEY FARM ──")
    addToggleRow(farmF,"💸 Money Farm",     "AutoMoneyFarm", function(v)
        if v then startMoneyFarm() else killThread("moneyfarm") end
    end)
    addInputRow(farmF,"⏱ Sell rate",       "SellRate", true)
    addToggleRow(farmF,"🐾 Auto Equip Best","AutoEquipBest", function(v)
        if v then startEquip() else killThread("equip") end
    end)
    addActionBtn(farmF,"⚡ Equip Best NOW", Color3.fromRGB(40,80,160), function() rf("Plot_EquipBest") end)
    addActionBtn(farmF,"💸 Sell All NOW",   Color3.fromRGB(160,80,40), function() rf("Plot_SellAll") end)

    addSection(farmF,"── AUTO BUY ──")
    addToggleRow(farmF,"🪱 Auto Buy Bait",    "AutoBuyBait",  function(v)
        if v then startAutoBuyBait()       else killThread("autobait")    end
    end)
    addToggleRow(farmF,"🏪 Auto Upgrade Stand","AutoBuyStand",  function(v)
        if v then startAutoUpgradeStand()  else killThread("autostand")   end
    end)
    addToggleRow(farmF,"🔒 Auto Upgrade Fence","AutoBuyFence",  function(v)
        if v then startAutoUpgradeFence()  else killThread("autofence")   end
    end)
    addNote(farmF,"Auto Buy Bait: Shop_ClaimFree → Shop_Buy.\nAuto Upgrade: Stand_Upgrade / Plot_UpgradeFence.")
    addActionBtn(farmF,"🪱 Claim Free NOW",  C.teal,   function() rf("Shop_ClaimFree") end)
    addActionBtn(farmF,"🏪 Upgrade Stand ×1",C.orange, function() rf("Stand_Upgrade") end)
    addActionBtn(farmF,"🔒 Upgrade Fence ×1",C.purple, function() rf("Plot_UpgradeFence") end)

    -- ════════════════════════════════════════
    -- ТАБ 4: 📊  STATS
    -- ════════════════════════════════════════
    local statsF=addTab("Stats","📊")
    addSection(statsF,"── STAT INJECT ──")
    addNote(statsF,"Хуки ставятся при старте скрипта.\nReplicaSet intercept + __newindex fallback.\nТребует hookfunction (Synapse X / KRNL).")
    addRawPresetRow(statsF,"💰 Money (raw)",   "StatMoneyRaw")
    addRawPresetRow(statsF,"📈 MPS (raw)",     "StatMPSRaw")
    addInputRow(statsF,"⚡ Throw Power",        "StatPower", true)
    addToggleRow(statsF,"🔄 Auto Inject",       "AutoInjectStats", function(v)
        if v then startInject() else killThread("inject") end
    end)
    addActionBtn(statsF,"💉 Inject Once", C.purple, injectOnce)

    -- ════════════════════════════════════════
    -- ТАБ 5: 🖥  GUI
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
        "ProximityPrompts","ThrowSequence","TrainingSequence",
    }) do addGuiToggle(guiF,name) end

    -- MINIMIZE (свернуть в маленький прямоугольник / развернуть)
    local minimized=false
    local function applyMin()
        tabBar.Visible=not minimized; scroll.Visible=not minimized; sbar.Visible=not minimized
        main.Size=minimized and UDim2.new(0,W_MINI,0,H_MINI) or UDim2.new(0,W_FULL,0,H_FULL)
        htitle.Text=minimized and "⚡ Z FARM" or "⚡ Z FARM v7"
        minBtn.Text=minimized and "▲" or "—"
    end
    minBtn.MouseButton1Click:Connect(function()
        minimized=not minimized
        applyMin()
    end)

    -- DRAG: двигаем окно только за шапку, чтобы не мешать скроллу пальцем
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=inp.Position; startPos=main.Position
            inp.Changed:Connect(function()
                if inp.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                                    startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)

    switchTab("Train")
end

-- HOTKEY
UserInputService.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.RightControl then
        local g=lp.PlayerGui:FindFirstChild("ZFarm")
        if g then g.Enabled=not g.Enabled end
    end
end)

-- ╔══════════════════════════════════════╗
-- ║  INIT                                ║
-- ╚══════════════════════════════════════╝
-- ╔══════════════════════════════════════════════════╗
-- ║  CRASH GUARD для хуков                           ║
-- ║  Перед установкой хука пишем "pending:имя" в     ║
-- ║  siska_boot.txt. Если игра вылетела во время     ║
-- ║  хука, при следующем запуске он помечается bad   ║
-- ║  и пропускается. Сброс: удалить siska_boot.txt   ║
-- ╚══════════════════════════════════════════════════╝
local BOOT_FILE = "siska_boot.txt"
local badHooks, pendingHook = {}, nil

local function readBoot()
    if not (isfile and readfile) then return end
    local ok, text = pcall(function()
        if isfile(BOOT_FILE) then return readfile(BOOT_FILE) end
    end)
    if not ok or type(text) ~= "string" then return end
    for line in text:gmatch("[^\r\n]+") do
        local kind, name = line:match("^(%a+):(.+)$")
        if kind == "bad" then badHooks[name] = true end
        if kind == "pending" then badHooks[name] = true; pendingHook = name end  -- вылетели на нём
    end
end

local function writeBoot(pending)
    if not writefile then return end
    local out = {}
    for name in pairs(badHooks) do out[#out+1] = "bad:" .. name end
    if pending then out[#out+1] = "pending:" .. pending end
    pcall(writefile, BOOT_FILE, table.concat(out, "\n"))
end

local function safeHook(name, fn)
    if badHooks[name] then
        log("hook SKIPPED (bad from previous crash): " .. name)
        print("[Z] хук " .. name .. " пропущен (из-за него был вылет). Сброс: удали " .. BOOT_FILE)
        return false
    end
    writeBoot(name)          -- если игра упадёт прямо сейчас — запомнится имя
    log("hook START: " .. name)   -- если упало — это последняя строка лога
    local ok, err = pcall(fn)
    writeBoot(nil)           -- прошло без вылета
    log("hook " .. (ok and "OK: " or "ERROR: ") .. name .. (ok and "" or (" | " .. tostring(err))))
    return ok
end

-- Меню появляется сразу. Хуки ставятся в фоне, по одному, когда игра уже загрузилась.
loadConfig()   -- подгружаем сохранённые настройки (если файла нет — всё по умолчанию)
readBoot()
log("readBoot: bad hooks from previous runs = " .. (next(badHooks) and "yes" or "none"))
if pendingHook then
    log("PREVIOUS RUN CRASHED ON HOOK: " .. pendingHook)
    print("[Z] прошлый запуск вылетел на хуке: " .. pendingHook .. " — он отключён")
end
writeBoot(nil)
log("buildGui: start")
local okGui, errGui = pcall(buildGui)
log("buildGui: " .. (okGui and "ok" or ("ERROR " .. tostring(errGui))))
task.spawn(function()
    log("init: waiting for game load")
    if not game:IsLoaded() then game.Loaded:Wait() end
    task.wait(3)                       -- даём игре полностью прогрузиться
    log("init: game loaded, setupGuiWatcher")
    pcall(setupGuiWatcher)             -- авто-скрытие TrainingSequence / ThrowSequence
    log("init: setupReturnBlock")
    pcall(setupReturnBlock)            -- блокируем return TP при броске
    task.wait(1)
    safeHook("ReplicaSet", hookReplicaSet)   -- патч ReplicaSet для stat inject
    task.wait(1.5)
    safeHook("InvokeServer", hookThrowPower) -- хук InvokeServer (только Throw_Start)
    task.wait(1.5)
    safeHook("newindex", hookNewindex)       -- патч __newindex (самый рискованный — последним)
    task.wait(1)
    task.spawn(setupTrainingBonusHook)  -- WaitForChild внутри, не блокирует
    log("hooks: ReplicaSet=" .. tostring(replicaHooked) .. " newindex=" .. tostring(niHooked)
        .. " throw=" .. tostring(throwHooked))
    print("[Z] Hooks: ReplicaSet=" .. (replicaHooked and "✓" or "✗")
        .. "  __newindex=" .. (niHooked and "✓" or "✗")
        .. "  throwHook=" .. (throwHooked and "✓" or "✗"))
    -- запускаем то, что было включено в сохранённом конфиге (после установки хуков)
    log("restore: " .. #pendingRestore .. " toggle(s) from config")
    for idx, start in ipairs(pendingRestore) do
        log("restore START #" .. idx)
        local ok, err = pcall(start)
        log("restore " .. (ok and "OK" or ("ERROR | " .. tostring(err))) .. " #" .. idx)
        task.wait(0.3)
    end
    log("init finished")
end)
print("[Z] v7.0 Ghost loaded ✓  |  RCtrl = show/hide  |  log: " .. LOG_FILE)
