-- bin\x64\plugins\cyber_engine_tweaks\mods\m3_gtr_audio\init.lua
-- Multi-band AudioXL engine audio controller (smoothed 30Hz, persistent single-layer voices, gain-capped)

local M3GTR = {
    targetRecords = {
        "Vehicle.m3_gtr_mostwanted_purchasable",
        "Vehicle.ctrlsec_m3_gtr_mostwanted_basic",
        "Vehicle.ctrlsec_m3_gtr_mostwanted_base",
    },
    targetSubstr = "m3_gtr_mostwanted",
    targetHashes = {},

    emitterName = "m3_gtr_engine",

    -- Live-tunable settings (editable in CET console via GetMod("m3_gtr_audio").*)
    masterGain           = 0.85,  -- Overall volume (keep 0.50 - 1.10; total mix is capped by maxTotalGain)
    maxTotalGain         = 0.95,  -- Hard sum ceiling across all simultaneous bands (prevents digital clipping)
    fppGainScale         = 0.90,  -- Interior layer scale in FPP
    tppGainScale         = 1.00,  -- Exterior layer scale in TPP
    offThrottleGainScale = 1.30,  -- Bug 2 fix: Raised to 1.30 so off_* braking overrun stays prominent over idle
    rpmGainMin           = 0.85,  -- Low/mid-RPM overrun & slides cut over tire screech
    rpmGainMax           = 1.00,  -- Progressive build toward redline
    backfireScale        = 0.75,
    splutterScale        = 0.55,
    minRPM               = 700.0,
    maxRPM               = 8000.0,
    splutterRPM          = 7550.0,

    -- Synthetic reverse RPM scaling (overrides CP2077 gear==0 idle RPM pinning)
    reverseMaxSpeed      = 14.0,  -- m/s (~50 km/h) where reverse reaches reverseMaxRPM
    reverseMaxRPM        = 4000.0,-- Peak synthetic RPM when reversing at full speed

    -- Bug 2 fix: Engaged-drivetrain engine braking RPM floor & asymmetric RPM smoothing
    clutchDisengageSpeed = 3.5,   -- m/s (~12 km/h) below which clutch feathers out toward idle
    engagedClutchRPM     = 1850.0,-- Floor RPM at clutch disengagement threshold (3.5 m/s)
    engagedLowSpeed      = 4.0,   -- m/s anchor for ~2000 RPM engaged floor
    engagedLowRPM        = 2000.0,
    engagedHighSpeed     = 35.0,  -- m/s (~126 km/h) anchor for 5200 RPM engaged floor
    engagedHighRPM       = 5200.0,
    rpmAttackRate        = 14.0,  -- Fast smoothing on rev-up for crisp throttle response
    rpmReleaseRate       = 6.0,   -- Natural wind-down smoothing to mask brake-lockup rawRPM dips

    -- Bug 1 fix: Post-mount emitter settle & Position()-verified startup hook recovery
    mountEmitterAttachDelay = 0.25, -- Require stateSettled for >=0.25s before calling AttachEmitter
    mountPostAttachDelay    = 0.15, -- Wait >=0.15s (~4-5 ticks) after AttachEmitter before PlayVoice()
    mountSettleDelay        = 0.35, -- Minimum ready hold before startEngine()
    mountMaxWait            = 1.60, -- Fallback cap once vehicle PSM state & camera are settled
    mountHardFailsafe       = 4.00, -- Absolute cap in case a modded vehicle never enters standard PSM states
    emitterVerifyWindow     = 1.20, -- Passive emitter presence guard during initial driving
    startupVerifyWindow     = 3.00, -- Post-start hook verification window (disarms immediately once healthy)
    startupRetryInterval    = 0.45, -- Retry cadence while no voice's Position() is advancing
    emitterRetryCooldown    = 0.066,-- ~0.07s cooldown after AttachEmitter before calling PlayVoice()
    emitterCooldownMinTicks = 2,    -- Guaranteed >=2 audio ticks between AttachEmitter and PlayVoice()

    -- Load detection thresholds (computed from smoothedRPM / smoothedAbsSpeed)
    onThrottleDRPM       = 45.0,   -- Positive RPM/s deadzone to trigger on_* bands via telemetry
    onThrottleDSpd       = 0.25,   -- Positive abs(speed) m/s^2 deadzone to trigger on_* bands via telemetry
    offThrottleDRPM      = -350.0, -- Hard RPM/s drop that overrides to off_* overrun
    offThrottleDSpd      = -0.75,  -- Hard abs(speed) m/s^2 drop that overrides to off_* overrun
    loadAttackRate       = 12.0,   -- Responsive throttle attack
    loadReleaseRate      = 16.0,   -- Fast overrun transition on lift-off/slide
    shiftHoldTime        = 0.25,   -- Keep load=1.0 briefly across upshifts

    -- Smoothing & voice parameters
    audioTickRate        = 0.033,  -- Update AudioXL at ~30 Hz
    glideTime            = 0.035,  -- Matches tick rate for seamless interpolation
    startThresh          = 0.015,  -- First-time lazy spawn threshold
    muteThresh           = 0.004,  -- Clamp tiny weights to exact 0.0 gain (voice stays alive, silent)
    camStopFade          = 0.04,   -- Clean fade when switching FPP <-> TPP

    diagInterval         = 1.0,
    debugLog             = false,  -- Toggle live: GetMod("m3_gtr_audio").debugLog = true

    -- Re-balanced bands:
    -- Bug 2 fix: Lowered idle gain to 0.68 so it does not trigger premature ceilingScale ducking during off_* braking
    -- Preserved: low=500 on vlow/off_vlow (no 700-750 RPM dead zone) & boosted off_vlow..off_high gains (0.95 - 1.05)
    bands = {
        { key = "idle",     ext = "m3_idle",     int = "m3_idle_in",     baseRPM = 750,  low = 400,  peak = 700,  high = 2000, kind = "idle", gain = 0.68 },
        { key = "vlow",     ext = "m3_on_vlow",  int = "m3_on_vlow_in",  baseRPM = 1800, low = 500,  peak = 1650, high = 3300, kind = "on",   gain = 0.95 },
        { key = "low",      ext = "m3_on_low",   int = "m3_on_low_in",   baseRPM = 3000, low = 1700, peak = 3000, high = 4800, kind = "on",   gain = 1.00 },
        { key = "mid",      ext = "m3_on_mid",   int = "m3_on_mid_in",   baseRPM = 4800, low = 3100, peak = 4800, high = 6600, kind = "on",   gain = 0.95 },
        { key = "high",     ext = "m3_on_high",  int = "m3_on_high_in",  baseRPM = 6800, low = 4900, peak = 6800, high = 9500, kind = "on",   gain = 1.00, plateau = true },

        { key = "off_vlow", ext = "m3_off_vlow", int = "m3_off_vlow_in", baseRPM = 1800, low = 500,  peak = 1650, high = 3300, kind = "off",  gain = 0.95 },
        { key = "off_low",  ext = "m3_off_low",  int = "m3_off_low_in",  baseRPM = 3000, low = 1700, peak = 3000, high = 4800, kind = "off",  gain = 0.98 },
        { key = "off_mid",  ext = "m3_off_mid",  int = "m3_off_mid_in",  baseRPM = 4800, low = 3100, peak = 4800, high = 6600, kind = "off",  gain = 1.02 },
        { key = "off_high", ext = "m3_off_high", int = "m3_off_high_in", baseRPM = 6800, low = 4900, peak = 6800, high = 9500, kind = "off",  gain = 1.05, plateau = true },
    },

    backfires     = { "m3_bf_1", "m3_bf_2", "m3_bf_3" },
    allSounds     = {},
    loopSoundsSet = {},

    -- Runtime state
    axl                    = nil,
    emitterAttached        = false,
    mountedVehHash         = nil,
    isM3                   = false,
    mountPending           = false,
    mountElapsed           = 0.0,
    mountReadyElapsed      = 0.0,
    mountTotalElapsed      = 0.0,
    mountPostAttachElapsed = 0.0,
    engineRunning          = false,
    engineElapsed          = 0.0,
    emitterVerifyTimer     = 0.0,
    emitterCooldown        = 0.0,
    emitterCooldownTicks   = 0,
    startupVerifyActive    = false,
    startupVerifyElapsed   = 0.0,
    startupVerifyTimer     = 0.0,
    startupRetries         = 0,
    pendingStartSound      = nil,
    lastFPP                = nil,
    lastLoadOn             = false,
    isReversing            = false,
    inputSeen              = false,
    inputAccel             = 0.0,
    inputBrake             = 0.0,
    voices                 = {}, -- soundName -> { handle, layer, gain, age, lastPos, healthy }
    prevRPM                = 700.0,
    smoothedRPM            = 700.0,
    prevSmoothedRPM        = 700.0,
    smoothedSpeed          = 0.0,
    smoothedAbsSpeed       = 0.0,
    prevSmoothedAbsSpeed   = 0.0,
    prevGear               = 0,
    load                   = 0.0,
    shiftHold              = 0.0,
    bfCooldown             = 0.0,
    audioAccum             = 0.0,
    diagTimer              = 0.0,
    lastRawSum             = 0.0,
    lastFinalSum           = 0.0,
    bbWarned               = false,
}

local LOG2 = math.log(2)

local function log(fmt, ...)
    if M3GTR.debugLog then
        print(string.format("[M3GTR] " .. fmt, ...))
    end
end

local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

local function rpmToCents(rpm, baseRPM)
    local ratio = clamp(rpm / baseRPM, 0.25, 4.0)
    return clamp(1200.0 * (math.log(ratio) / LOG2), -1200.0, 1200.0)
end

local function bandWeight(rpm, low, peak, high, plateau)
    if rpm <= low then
        return 0.0
    elseif rpm < peak then
        return (rpm - low) / (peak - low)
    elseif plateau then
        return 1.0
    elseif rpm >= high then
        return 0.0
    else
        return (high - rpm) / (high - peak)
    end
end

local function getAXL()
    if M3GTR.axl then return M3GTR.axl end
    local container = Game.GetScriptableSystemsContainer()
    if not container then return nil end
    M3GTR.axl = container:Get("AudioXL.AudioXLLua")
    return M3GTR.axl
end

local function getNativeAXL()
    return AudioXL_AudioXLNative or AudioXLNative
end

local function activeEmitterName()
    return M3GTR.emitterAttached and M3GTR.emitterName or "axl_handle_2d"
end

-- Bug 1 fix: Enforce a >=2-tick (~0.07s) cooldown so AttachEmitter and PlayVoice never run on the same frame
local function startEmitterCooldown()
    M3GTR.emitterCooldown = M3GTR.emitterRetryCooldown
    M3GTR.emitterCooldownTicks = M3GTR.emitterCooldownMinTicks
end

local function isInEmitterCooldown()
    return (M3GTR.emitterCooldownTicks > 0) or (M3GTR.emitterCooldown > 0.0)
end

local function stopSoundCleanly(axl, soundName, handle, fadeOut)
    local fade = fadeOut or 0.04
    if handle then
        pcall(function() handle:Stop(fade) end)
    end
    if axl then
        pcall(function() axl:StopOn(activeEmitterName(), soundName, fade) end)
        pcall(function() axl:Stop(soundName, fade) end)
    end
end

-- Non-destructive emitter check/attach; returns (emitterName, newlyAttached)
local function ensureVehicleEmitter(axl, veh)
    if not axl then return "", false end
    local okHas, has = pcall(function() return axl:HasEmitter(M3GTR.emitterName) end)
    if okHas and has then
        M3GTR.emitterAttached = true
        return M3GTR.emitterName, false
    end

    M3GTR.emitterAttached = false
    if veh then
        local ok, attached = pcall(function() return axl:AttachEmitter(M3GTR.emitterName, veh) end)
        if ok and attached then
            M3GTR.emitterAttached = true
            return M3GTR.emitterName, true
        end
    end
    return "", false
end

-- Bug 1 fix: Destructive emitter recreation used ONLY during unhealthy-voice startup recovery
local function recreateVehicleEmitter(axl, veh)
    if not axl then return "", false end
    pcall(function() axl:StopOn(M3GTR.emitterName, "", 0.0) end)
    pcall(function() axl:DetachEmitter(M3GTR.emitterName) end)
    pcall(function() axl:DestroyEmitter(M3GTR.emitterName) end)
    M3GTR.emitterAttached = false

    if veh then
        local ok, attached = pcall(function() return axl:AttachEmitter(M3GTR.emitterName, veh) end)
        if ok and attached then
            M3GTR.emitterAttached = true
            return M3GTR.emitterName, true
        end
    end
    return "", false
end

local function stopLayerVoices(axl, layerTag, fadeOut)
    local toRemove = {}
    for soundName, entry in pairs(M3GTR.voices) do
        if entry and entry.layer == layerTag then
            stopSoundCleanly(axl, soundName, entry.handle, fadeOut)
            toRemove[#toRemove + 1] = soundName
        end
    end
    for i = 1, #toRemove do
        M3GTR.voices[toRemove[i]] = nil
    end
end

-- Bug 1 fix: Cleanly stop all active layer voices + m3_splutter before recreating emitter on retry
local function stopAllActiveVoices(axl, fadeOut)
    stopLayerVoices(axl, "ext", fadeOut)
    stopLayerVoices(axl, "int", fadeOut)
    stopLayerVoices(axl, "shared", fadeOut)
    stopSoundCleanly(axl, "m3_splutter", nil, fadeOut)
    for soundName, entry in pairs(M3GTR.voices) do
        stopSoundCleanly(axl, soundName, entry and entry.handle or nil, fadeOut)
    end
    M3GTR.voices = {}
end

-- Bug 1 fix: True only once at least one active voice's Position() is > 0.001 and advancing across ticks
local function hasAnyHealthyVoice()
    for _, entry in pairs(M3GTR.voices) do
        if entry and entry.healthy and entry.handle then
            local okPlay, playing = pcall(function() return entry.handle:IsPlaying() end)
            if okPlay and playing then
                return true
            end
        end
    end
    return false
end

local function countActiveM3LoopVoices(axl)
    local count = 0
    local ok, ps = pcall(function() return axl:PlayingSounds() end)
    if ok and ps then
        for _, s in ipairs(ps) do
            if M3GTR.loopSoundsSet[tostring(s)] then
                count = count + 1
            end
        end
    end
    return count
end

local function getSlotReportSummary()
    local nat = getNativeAXL()
    if not nat or not nat.SlotReport then return "n/a" end
    local ok, sr = pcall(function() return nat.SlotReport() end)
    if not ok or not sr then return "err" end
    local lines = {}
    for _, line in ipairs(sr) do
        local s = tostring(line)
        if s:find("voice%(s%)") or s:find("rows the feed") or s:find("hung up") then
            lines[#lines + 1] = s:gsub("^%s+", "")
        end
    end
    return table.concat(lines, " | ")
end

local function getRecordInfo(veh)
    local recID = veh:GetRecordID()
    local recStr = tostring(recID.value or recID)
    local matched = false

    for i, targetID in ipairs(M3GTR.targetHashes) do
        if recID == targetID or recStr == M3GTR.targetRecords[i] then
            matched = true
            break
        end
    end

    if not matched and recStr:lower():find(M3GTR.targetSubstr, 1, true) then
        matched = true
    end

    return recStr, matched
end

local function readTelemetry(veh)
    local rpm, speed, gear = M3GTR.minRPM, 0.0, 0
    local ok, err = pcall(function()
        local bb = veh:GetBlackboard()
        local defs = Game.GetAllBlackboardDefs().Vehicle
        if bb and defs then
            rpm   = bb:GetFloat(defs.RPMValue) or M3GTR.minRPM
            speed = bb:GetFloat(defs.SpeedValue) or 0.0
            gear  = bb:GetInt(defs.GearValue) or 0
        end
    end)

    if not ok and not M3GTR.bbWarned then
        M3GTR.bbWarned = true
        print("[M3GTR] WARNING: Blackboard telemetry read failed: " .. tostring(err))
    end

    return rpm, speed, gear
end

local function getVehiclePSMState(player)
    local vState = nil
    pcall(function()
        local psm = player:GetPlayerStateMachineBlackboard()
        local defs = Game.GetAllBlackboardDefs().PlayerStateMachine
        if psm and defs then
            vState = psm:GetInt(defs.Vehicle)
        end
    end)
    return vState
end

-- gamePSMVehicle: Default=0, Driving=1, Combat=2, Passenger=3, Transition=4, Turret=5, DriverCombat=6
local function isActiveVehicleState(vState)
    return vState == 1 or vState == 2 or vState == 3 or vState == 6
end

local function isCameraReady(veh)
    local ok, ready = pcall(function()
        local camMgr = veh:GetCameraManager()
        if not camMgr then return false end
        return camMgr:GetActivePerspective() ~= nil
    end)
    return ok and ready or false
end

-- Returns (isReady, isStateSettled)
local function isMountReady(player, veh)
    local vState = getVehiclePSMState(player)
    if not isActiveVehicleState(vState) then
        return false, false
    end

    if not isCameraReady(veh) then
        return false, false
    end

    local engineOn = false
    pcall(function()
        if veh.IsEngineTurnedOn then
            engineOn = veh:IsEngineTurnedOn()
        end
    end)
    if engineOn then return true, true end

    local rawRPM = 0.0
    pcall(function()
        local bb = veh:GetBlackboard()
        local defs = Game.GetAllBlackboardDefs().Vehicle
        if bb and defs then
            rawRPM = bb:GetFloat(defs.RPMValue) or 0.0
        end
    end)
    return (rawRPM > 100.0), true
end

local function isVehicleFPP(veh)
    local ok, fpp = pcall(function()
        local camMgr = veh:GetCameraManager()
        if not camMgr then return false end
        return camMgr:GetActivePerspective() == vehicleCameraPerspective.FPP
    end)
    return ok and fpp or false
end

local function stopEngine(reason, keepEmitter)
    M3GTR.mountPending           = false
    M3GTR.mountElapsed           = 0.0
    M3GTR.mountReadyElapsed      = 0.0
    M3GTR.mountTotalElapsed      = 0.0
    M3GTR.mountPostAttachElapsed = 0.0
    M3GTR.engineElapsed          = 0.0
    M3GTR.emitterVerifyTimer     = 0.0
    M3GTR.emitterCooldown        = 0.0
    M3GTR.emitterCooldownTicks   = 0
    M3GTR.startupVerifyActive    = false
    M3GTR.startupVerifyElapsed   = 0.0
    M3GTR.startupVerifyTimer     = 0.0
    M3GTR.startupRetries         = 0
    M3GTR.pendingStartSound      = nil
    M3GTR.inputSeen              = false
    M3GTR.inputAccel             = 0.0
    M3GTR.inputBrake             = 0.0
    M3GTR.isReversing            = false

    local axl = getAXL()
    local hasOrphanEmitter = false
    if not keepEmitter and axl and not M3GTR.emitterAttached then
        local okH, resH = pcall(function() return axl:HasEmitter(M3GTR.emitterName) end)
        hasOrphanEmitter = okH and resH or false
    end

    if not M3GTR.engineRunning and next(M3GTR.voices) == nil and (keepEmitter or (not M3GTR.emitterAttached and not hasOrphanEmitter)) then
        return
    end

    for soundName, entry in pairs(M3GTR.voices) do
        stopSoundCleanly(axl, soundName, entry and entry.handle or nil, 0.08)
    end
    M3GTR.voices = {}

    if axl then
        local em = activeEmitterName()
        for i = 1, #M3GTR.allSounds do
            local sName = M3GTR.allSounds[i]
            pcall(function() axl:StopOn(em, sName, 0.08) end)
            pcall(function() axl:Stop(sName, 0.08) end)
        end
        if not keepEmitter and (M3GTR.emitterAttached or hasOrphanEmitter) then
            pcall(function()
                axl:StopOn(M3GTR.emitterName, "", 0.08)
                axl:DetachEmitter(M3GTR.emitterName)
                axl:DestroyEmitter(M3GTR.emitterName)
            end)
        end
    end

    if not keepEmitter then
        M3GTR.emitterAttached = false
    end
    M3GTR.engineRunning = false
    M3GTR.lastFPP       = nil
    M3GTR.lastLoadOn    = false
    log("StopEngine (%s, keepEmitter=%s)", tostring(reason), tostring(keepEmitter == true))
end

-- Persistent voice driver with Position() health tracking and cooldown guard
local function drivePersistentVoice(axl, veh, soundName, layerTag, targetGain, targetCents, stepDt)
    local gain = (targetGain > M3GTR.muteThresh) and targetGain or 0.0
    local entry = M3GTR.voices[soundName]
    local h = entry and entry.handle or nil

    if h then
        local okPlay, playing = pcall(function() return h:IsPlaying() end)
        if okPlay and playing then
            entry.age = (entry.age or 0.0) + (stepDt or M3GTR.audioTickRate)

            -- Bug 1 fix: Verify true AudioXL playback via h:Position() > 0.001 advancing across ticks
            if not entry.healthy then
                local okPos, pos = pcall(function() return h:Position() end)
                if okPos and type(pos) == "number" and pos > 0.001 then
                    if entry.lastPos < 0.0 then
                        entry.lastPos = pos
                    elseif math.abs(pos - entry.lastPos) > 1e-4 then
                        entry.lastPos = pos
                        entry.healthy = true
                    end
                end
            end

            entry.gain = gain
            pcall(function() h:SetGain(gain, M3GTR.glideTime) end)
            pcall(function() h:SetPitch(targetCents, M3GTR.glideTime) end)
            return gain > 0.0
        else
            stopSoundCleanly(axl, soundName, h, 0.0)
            M3GTR.voices[soundName] = nil
            h = nil
        end
    end

    if gain > M3GTR.startThresh then
        if isInEmitterCooldown() then
            return false
        end

        -- Never call AttachEmitter and PlayVoice on the same frame
        local emitter, newlyAttached = ensureVehicleEmitter(axl, veh)
        if newlyAttached then
            startEmitterCooldown()
            return false
        end

        local okActive, active = pcall(function() return axl:IsPlaying(soundName) end)
        if okActive and active then
            stopSoundCleanly(axl, soundName, nil, 0.0)
        end

        local okSpawn, spawned = pcall(function()
            return axl:PlayVoice(soundName, emitter, gain, 0.0, 0.0, targetCents, 0.0, 0.0, true, 0.0)
        end)
        if okSpawn and spawned then
            M3GTR.voices[soundName] = {
                handle  = spawned,
                layer   = layerTag,
                gain    = gain,
                age     = 0.0,
                lastPos = -1.0,
                healthy = false,
            }
            return true
        end
    end

    return false
end

local function startEngine(veh)
    local axl = getAXL()
    if not axl then return end

    -- Preserve the settled emitter attached during mountPending
    stopEngine("restart", true)

    local emitter, newlyAttached = ensureVehicleEmitter(axl, veh)
    local startFPP = isVehicleFPP(veh)
    local startSound = startFPP and "m3_start_in" or "m3_start"
    local startGain = clamp(M3GTR.masterGain * 0.90, 0.0, M3GTR.maxTotalGain)

    if not newlyAttached then
        pcall(function()
            axl:PlayVoice(startSound, emitter, startGain, 0.0, 0.0, 0.0, 0.0, 0.0, false, 0.0)
        end)
        M3GTR.pendingStartSound = nil
        M3GTR.audioAccum        = M3GTR.audioTickRate
    else
        -- Fallback guard: if emitter had to be attached right now, enforce 2-tick cooldown before PlayVoice()
        startEmitterCooldown()
        M3GTR.pendingStartSound = { gain = startGain }
        M3GTR.audioAccum        = 0.0
    end

    M3GTR.engineRunning        = true
    M3GTR.engineElapsed        = 0.0
    M3GTR.emitterVerifyTimer   = 0.0
    M3GTR.startupVerifyActive  = true
    M3GTR.startupVerifyElapsed = 0.0
    M3GTR.startupVerifyTimer   = 0.0
    M3GTR.startupRetries       = 0
    M3GTR.lastFPP              = startFPP
    M3GTR.lastLoadOn           = false
    M3GTR.isReversing          = false
    M3GTR.prevRPM              = M3GTR.minRPM
    M3GTR.smoothedRPM          = M3GTR.minRPM
    M3GTR.prevSmoothedRPM      = M3GTR.minRPM
    M3GTR.smoothedSpeed        = 0.0
    M3GTR.smoothedAbsSpeed     = 0.0
    M3GTR.prevSmoothedAbsSpeed = 0.0
    M3GTR.prevGear             = 0
    M3GTR.load                 = 0.0
    M3GTR.shiftHold            = 0.0
    M3GTR.bfCooldown           = 0.0
    M3GTR.diagTimer            = 0.0
    M3GTR.lastRawSum           = 0.0
    M3GTR.lastFinalSum         = 0.0
    log("StartEngine | FPP=%s | startSound=%s | emitter=%s(newly=%s) | gain=%.2f",
        tostring(startFPP), startSound, activeEmitterName(), tostring(newlyAttached), startGain)
end

local function triggerBackfire(veh)
    local axl = getAXL()
    if not axl or isInEmitterCooldown() then return end
    local name = M3GTR.backfires[math.random(1, #M3GTR.backfires)]
    local emitter, newlyAttached = ensureVehicleEmitter(axl, veh)
    if newlyAttached then
        startEmitterCooldown()
        return
    end
    local pitchJitter = math.random(-80, 80)
    local bfGain = clamp(M3GTR.masterGain * M3GTR.backfireScale, 0.0, M3GTR.maxTotalGain)
    pcall(function()
        axl:PlayVoice(name, emitter, bfGain, 0.0, 0.0, pitchJitter, 0.0, 0.0, false, 0.0)
    end)
end

local function updateEngine(veh, dt)
    if not M3GTR.engineRunning or dt <= 0.0 then return end

    -- Throttle AudioXL parameter updates to ~30 Hz so glide ramps complete cleanly
    M3GTR.audioAccum = M3GTR.audioAccum + dt
    if M3GTR.audioAccum < M3GTR.audioTickRate then return end
    local stepDt = M3GTR.audioAccum
    M3GTR.audioAccum = 0.0

    local axl = getAXL()
    if not axl then return end

    -- Bug 1 fix: Advance post-AttachEmitter cooldown before any PlayVoice() calls
    if isInEmitterCooldown() then
        M3GTR.emitterCooldownTicks = math.max(0, M3GTR.emitterCooldownTicks - 1)
        M3GTR.emitterCooldown = math.max(0.0, M3GTR.emitterCooldown - stepDt)
    end

    -- Play deferred starter sound (fallback attach or retry #1) once emitter cooldown settles
    if M3GTR.pendingStartSound and not isInEmitterCooldown() then
        local ps = M3GTR.pendingStartSound
        local em, newly = ensureVehicleEmitter(axl, veh)
        if newly then
            startEmitterCooldown()
        else
            M3GTR.pendingStartSound = nil
            local startSound = isVehicleFPP(veh) and "m3_start_in" or "m3_start"
            pcall(function()
                axl:PlayVoice(startSound, em, ps.gain, 0.0, 0.0, 0.0, 0.0, 0.0, false, 0.0)
            end)
            log("Starter sound fired after emitter settle: %s (gain=%.2f)", startSound, ps.gain)
        end
    end

    -- Passive emitter presence check during initial driving (never destroys)
    M3GTR.engineElapsed = M3GTR.engineElapsed + stepDt
    if M3GTR.engineElapsed <= M3GTR.emitterVerifyWindow and not isInEmitterCooldown() then
        M3GTR.emitterVerifyTimer = M3GTR.emitterVerifyTimer + stepDt
        if M3GTR.emitterVerifyTimer >= 0.25 then
            M3GTR.emitterVerifyTimer = 0.0
            local okHas, hasEm = pcall(function() return axl:HasEmitter(M3GTR.emitterName) end)
            if not (okHas and hasEm) then
                log("Emitter verify: missing at %.2fs — attaching (non-destructive)", M3GTR.engineElapsed)
                M3GTR.emitterAttached = false
                local _, newly = ensureVehicleEmitter(axl, veh)
                if newly then
                    startEmitterCooldown()
                end
            elseif not M3GTR.emitterAttached then
                M3GTR.emitterAttached = true
            end
        end
    end

    local rawRPM, speed, gear = readTelemetry(veh)
    local rawAbsSpeed = math.abs(speed)

    -- Smooth signed speed (for direction) and unsigned speed (for acceleration/deceleration in both forward & reverse)
    M3GTR.smoothedSpeed = M3GTR.smoothedSpeed + (speed - M3GTR.smoothedSpeed) * clamp(stepDt * 8.0, 0.0, 1.0)
    M3GTR.smoothedAbsSpeed = M3GTR.smoothedAbsSpeed + (rawAbsSpeed - M3GTR.smoothedAbsSpeed) * clamp(stepDt * 8.0, 0.0, 1.0)

    local curSpeed = M3GTR.smoothedSpeed
    local curAbsSpeed = M3GTR.smoothedAbsSpeed
    local dAbsSpeed = (curAbsSpeed - M3GTR.prevSmoothedAbsSpeed) / stepDt

    -- Preserved: Detect reverse motion and synthesize reverse RPM floor when CP2077 pins gear==0 RPM near idle
    local isReversing = (curSpeed < -0.4) or (gear == 0 and speed < -0.20)
    M3GTR.isReversing = isReversing

    local effectiveRPM = rawRPM
    if isReversing then
        local revRatio = clamp(rawAbsSpeed / M3GTR.reverseMaxSpeed, 0.0, 1.0)
        local reverseSynthRPM = M3GTR.minRPM + (M3GTR.reverseMaxRPM - M3GTR.minRPM) * revRatio
        effectiveRPM = math.max(rawRPM, reverseSynthRPM)
    elseif speed > 1.0 then
        -- Bug 2 fix: Engaged-drivetrain engine braking RPM floor (stays coupled until ~3.5 m/s clutch disengage)
        local fwdSpd = curAbsSpeed
        local baseFloor
        if fwdSpd <= M3GTR.clutchDisengageSpeed then
            local tClutch = clamp((fwdSpd - 1.0) / (M3GTR.clutchDisengageSpeed - 1.0), 0.0, 1.0)
            baseFloor = M3GTR.minRPM + (M3GTR.engagedClutchRPM - M3GTR.minRPM) * tClutch
        elseif fwdSpd <= M3GTR.engagedLowSpeed then
            local tLow = clamp((fwdSpd - M3GTR.clutchDisengageSpeed) / (M3GTR.engagedLowSpeed - M3GTR.clutchDisengageSpeed), 0.0, 1.0)
            baseFloor = M3GTR.engagedClutchRPM + (M3GTR.engagedLowRPM - M3GTR.engagedClutchRPM) * tLow
        else
            local tHi = clamp((fwdSpd - M3GTR.engagedLowSpeed) / (M3GTR.engagedHighSpeed - M3GTR.engagedLowSpeed), 0.0, 1.0)
            baseFloor = M3GTR.engagedLowRPM + (M3GTR.engagedHighRPM - M3GTR.engagedLowRPM) * tHi
        end

        -- Gentle gear weighting when gear >= 1 (higher gears sit slightly lower; downshifts raise the floor)
        local gearScale = 1.0
        if gear >= 1 then
            gearScale = clamp(1.0 + (3.0 - gear) * 0.065, 0.80, 1.18)
        end

        local engagedFloorRPM = M3GTR.minRPM + (baseFloor - M3GTR.minRPM) * gearScale
        effectiveRPM = math.max(rawRPM, engagedFloorRPM)
    end

    -- Bug 2 fix: Asymmetric RPM smoothing (fast 14.0 rev-up, natural 6.0 wind-down)
    local rpm = clamp(effectiveRPM, M3GTR.minRPM, M3GTR.maxRPM)
    local rpmRate = (rpm > M3GTR.smoothedRPM) and M3GTR.rpmAttackRate or M3GTR.rpmReleaseRate
    M3GTR.smoothedRPM = M3GTR.smoothedRPM + (rpm - M3GTR.smoothedRPM) * clamp(stepDt * rpmRate, 0.0, 1.0)

    local curRPM = M3GTR.smoothedRPM
    local dRPM = (curRPM - M3GTR.prevSmoothedRPM) / stepDt

    -- Detect upshift so the brief RPM drop doesn't falsely flip to off-throttle
    local upshifted = (gear > M3GTR.prevGear) and (gear > 0) and (M3GTR.prevGear > 0)
    if upshifted then
        M3GTR.shiftHold = M3GTR.shiftHoldTime
    elseif M3GTR.shiftHold > 0.0 then
        M3GTR.shiftHold = math.max(0.0, M3GTR.shiftHold - stepDt)
    end

    -- Coasting defaults to off-throttle (0.0); on-throttle requires active acceleration/input
    local activeThrottleInput = false
    if M3GTR.inputSeen then
        if isReversing then
            activeThrottleInput = (M3GTR.inputBrake > 0.05)
        else
            activeThrottleInput = (M3GTR.inputAccel > 0.05)
        end
    end

    local hardDecel = (dRPM < M3GTR.offThrottleDRPM) or (dAbsSpeed < M3GTR.offThrottleDSpd)
    local accelTelemetry = (dRPM > M3GTR.onThrottleDRPM) or (dAbsSpeed > M3GTR.onThrottleDSpd)

    local targetLoad = 0.0
    if M3GTR.shiftHold > 0.0 and (not M3GTR.inputSeen or activeThrottleInput) then
        targetLoad = 1.0
    elseif M3GTR.inputSeen then
        if activeThrottleInput and not (hardDecel and curRPM > 1500.0 and curRPM < M3GTR.splutterRPM) then
            targetLoad = 1.0
        elseif (not activeThrottleInput) and dRPM > (M3GTR.onThrottleDRPM * 3.0) and dAbsSpeed > (M3GTR.onThrottleDSpd * 2.0) then
            -- Fallback if an autopilot/scripted drive accelerates without player pedal input
            targetLoad = 1.0
        end
    else
        -- Pure telemetry path before any OnAction input event has been observed
        if not hardDecel and (accelTelemetry or (curRPM > M3GTR.splutterRPM and dRPM > -150.0 and dAbsSpeed > -0.25)) then
            targetLoad = 1.0
        end
    end

    -- Attack/release smoothing for immediate overrun onset on throttle lift-off and slides
    local loadRate = (targetLoad > M3GTR.load) and M3GTR.loadAttackRate or M3GTR.loadReleaseRate
    M3GTR.load = M3GTR.load + (targetLoad - M3GTR.load) * clamp(stepDt * loadRate, 0.0, 1.0)

    -- Narrow crossfade around load=0.5 so on_* and off_* transition cleanly
    local onMix  = clamp((M3GTR.load - 0.25) / 0.50, 0.0, 1.0)
    local offMix = clamp((0.75 - M3GTR.load) / 0.50, 0.0, 1.0)

    if M3GTR.bfCooldown > 0.0 then
        M3GTR.bfCooldown = M3GTR.bfCooldown - stepDt
    else
        local shiftPop = upshifted and (M3GTR.prevRPM > 5200.0)
        local liftPop  = (M3GTR.shiftHold <= 0.0) and (M3GTR.prevSmoothedRPM > 5400.0) and (dRPM < -2200.0)
        if shiftPop or liftPop then
            triggerBackfire(veh)
            M3GTR.bfCooldown = 0.85
        end
    end

    -- Detect camera perspective transitions and stop ONLY the outgoing layer
    local fppNow = isVehicleFPP(veh)
    local camChanged = (M3GTR.lastFPP ~= nil) and (fppNow ~= M3GTR.lastFPP)
    if camChanged then
        stopLayerVoices(axl, fppNow and "ext" or "int", M3GTR.camStopFade)
    end
    M3GTR.lastFPP = fppNow

    local activeLayer = fppNow and "int" or "ext"

    -- Bug 1 fix: Post-start hook verification using real h:Position() advancement (not IsPlaying() alone)
    if M3GTR.startupVerifyActive then
        if hasAnyHealthyVoice() then
            M3GTR.startupVerifyActive = false
            log("Startup verify PASSED at %.2fs (retries=%d, activeLoops=%d) — healthy voice Position() advancing",
                M3GTR.startupVerifyElapsed, M3GTR.startupRetries, countActiveM3LoopVoices(axl))
        else
            M3GTR.startupVerifyElapsed = M3GTR.startupVerifyElapsed + stepDt
            if M3GTR.startupVerifyElapsed > M3GTR.startupVerifyWindow then
                M3GTR.startupVerifyActive = false
                log("Startup verify window ended at %.2fs (retries=%d, activeLoops=%d)",
                    M3GTR.startupVerifyElapsed, M3GTR.startupRetries, countActiveM3LoopVoices(axl))
            elseif not isInEmitterCooldown() then
                M3GTR.startupVerifyTimer = M3GTR.startupVerifyTimer + stepDt
                if M3GTR.startupVerifyTimer >= M3GTR.startupRetryInterval then
                    M3GTR.startupRetries = M3GTR.startupRetries + 1
                    M3GTR.startupVerifyTimer = 0.0
                    log("Startup verify retry #%d at %.2fs (activeLoops=%d) — no voice advancing Position(); recreating emitter",
                        M3GTR.startupRetries, M3GTR.startupVerifyElapsed, countActiveM3LoopVoices(axl))

                    -- 1. Stop all active voices + m3_splutter
                    stopAllActiveVoices(axl, 0.0)

                    -- 2. Destroy & re-attach emitter, then enforce 2-tick (~0.07s) cooldown before PlayVoice()
                    recreateVehicleEmitter(axl, veh)
                    startEmitterCooldown()

                    -- 3. On the first retry, also re-trigger the starter sound once the emitter settles
                    if M3GTR.startupRetries == 1 then
                        local startGain = clamp(M3GTR.masterGain * 0.90, 0.0, M3GTR.maxTotalGain)
                        M3GTR.pendingStartSound = { gain = startGain }
                    end
                end
            end
        end
    end

    local rpmNorm = clamp((curRPM - M3GTR.minRPM) / (M3GTR.maxRPM - M3GTR.minRPM), 0.0, 1.0)
    local rpmGain = M3GTR.rpmGainMin + (M3GTR.rpmGainMax - M3GTR.rpmGainMin) * rpmNorm
    local layerMix = (fppNow and M3GTR.fppGainScale or M3GTR.tppGainScale) * M3GTR.masterGain * rpmGain

    -- Pass 1: compute raw band gains and sum for automatic clip protection
    local planned = {}
    local rawSum = 0.0

    for i = 1, #M3GTR.bands do
        local b = M3GTR.bands[i]
        local w = bandWeight(curRPM, b.low, b.peak, b.high, b.plateau) * (b.gain or 1.0)
        if b.kind == "on" then
            w = w * onMix
        elseif b.kind == "off" then
            w = w * offMix * M3GTR.offThrottleGainScale
        end

        local g = w * layerMix
        local cents = rpmToCents(curRPM, b.baseRPM)
        local sName = fppNow and b.int or b.ext
        planned[i] = { sound = sName, gain = g, cents = cents }
        rawSum = rawSum + g
    end

    local splutRaw = clamp((curRPM - M3GTR.splutterRPM) / (M3GTR.maxRPM - M3GTR.splutterRPM), 0.0, 1.0) * M3GTR.masterGain * M3GTR.splutterScale
    rawSum = rawSum + splutRaw

    local ceilingScale = 1.0
    if rawSum > M3GTR.maxTotalGain and rawSum > 0.0 then
        ceilingScale = M3GTR.maxTotalGain / rawSum
    end

    M3GTR.lastRawSum = rawSum
    M3GTR.lastFinalSum = rawSum * ceilingScale

    -- Pass 2: drive persistent active-layer voices (never executes during post-AttachEmitter cooldown)
    local audibleCount = 0
    if not isInEmitterCooldown() then
        for i = 1, #planned do
            local p = planned[i]
            if drivePersistentVoice(axl, veh, p.sound, activeLayer, p.gain * ceilingScale, p.cents, stepDt) then
                audibleCount = audibleCount + 1
            end
        end

        if drivePersistentVoice(axl, veh, "m3_splutter", "shared", splutRaw * ceilingScale, 0.0, stepDt) then
            audibleCount = audibleCount + 1
        end
    end

    local loadOnNow = M3GTR.load >= 0.5
    local loadFlipped = (loadOnNow ~= M3GTR.lastLoadOn)
    M3GTR.lastLoadOn = loadOnNow

    M3GTR.diagTimer = M3GTR.diagTimer + stepDt
    if M3GTR.debugLog and (camChanged or loadFlipped or M3GTR.diagTimer >= M3GTR.diagInterval) then
        if M3GTR.diagTimer >= M3GTR.diagInterval then
            M3GTR.diagTimer = 0.0
        end
        local trackedCount = 0
        for _ in pairs(M3GTR.voices) do trackedCount = trackedCount + 1 end
        local evt = camChanged and "CAM" or (loadFlipped and "LOAD" or "TICK")
        log("[%s] RPM=%.0f | dRPM=%+.0f | Spd=%.1f(dAbs=%+.2f) | Gear=%d Rev=%s | Load=%.2f | FPP=%s | Healthy=%s | Sum=%.2f->%.2f | Aud=%d Trk=%d | %s",
            evt, curRPM, dRPM, curSpeed, dAbsSpeed, gear, tostring(isReversing), M3GTR.load, tostring(fppNow),
            tostring(hasAnyHealthyVoice()), M3GTR.lastRawSum, M3GTR.lastFinalSum, audibleCount, trackedCount, getSlotReportSummary())
    end

    M3GTR.prevRPM              = rpm
    M3GTR.prevSmoothedRPM      = curRPM
    M3GTR.prevSmoothedAbsSpeed = curAbsSpeed
    M3GTR.prevGear             = gear
end

-- Console helper: GetMod("m3_gtr_audio").Diag("TPP_MOUNT")
function M3GTR.Diag(arg1, arg2)
    local tag = (arg1 == M3GTR) and arg2 or arg1
    local p = Game.GetPlayer()
    local v = p and Game.GetMountedVehicle(p)
    local cm = v and v:GetCameraManager()
    local cam = cm and tostring(cm:GetActivePerspective()) or "nil"
    local vState = p and getVehiclePSMState(p)
    local axl = getAXL()
    local hasEm = false
    if axl then
        local okH, resH = pcall(function() return axl:HasEmitter(activeEmitterName()) end)
        hasEm = okH and resH or false
    end
    print(string.format("[M3DIAG:%s] CAM=%s | FPP=%s | PSM=%s | Pending=%s | Verify=%s(r=%d,t=%.2f) | Healthy=%s | Em=%s(has=%s) | RPM=%.0f | Spd=%.1f | Rev=%s | Load=%.2f | In=%s(%.2f/%.2f) | Sum=%.2f->%.2f",
        tostring(tag or "NOW"), cam, tostring(M3GTR.lastFPP), tostring(vState), tostring(M3GTR.mountPending),
        tostring(M3GTR.startupVerifyActive), M3GTR.startupRetries, M3GTR.startupVerifyElapsed,
        tostring(hasAnyHealthyVoice()), activeEmitterName(), tostring(hasEm),
        M3GTR.smoothedRPM, M3GTR.smoothedSpeed, tostring(M3GTR.isReversing), M3GTR.load,
        tostring(M3GTR.inputSeen), M3GTR.inputAccel, M3GTR.inputBrake,
        M3GTR.lastRawSum, M3GTR.lastFinalSum))
    local vc = 0
    for n, e in pairs(M3GTR.voices) do
        vc = vc + 1
        local h = e.handle
        local o1, hp = pcall(function() return h:IsPlaying() end)
        local o2, pos = pcall(function() return h:Position() end)
        print(string.format("  tracked[%s] (%s): gain=%.3f h:Play=%s pos=%s healthy=%s",
            n, tostring(e.layer), e.gain or -1, o1 and tostring(hp) or "ERR",
            (o2 and pos) and string.format("%.2f", pos) or "ERR",
            tostring(e.healthy)))
    end
    print("  trackedCount=" .. vc)
    if axl then
        local ps = axl:PlayingSounds() or {}
        local t = {}
        for _, s in ipairs(ps) do t[#t + 1] = tostring(s) end
        print("  axl:PlayingSounds(" .. #t .. "): " .. table.concat(t, ", "))
    end
    local nat = getNativeAXL()
    if nat and nat.SlotReport then
        local ok, sr = pcall(function() return nat.SlotReport() end)
        if ok and sr then
            print("  SlotReport(" .. #sr .. "):")
            for _, l in ipairs(sr) do print("    " .. tostring(l)) end
        end
    end
end

registerForEvent("onInit", function()
    for i, recName in ipairs(M3GTR.targetRecords) do
        M3GTR.targetHashes[i] = TweakDBID.new(recName)
    end

    M3GTR.allSounds = { "m3_start", "m3_start_in", "m3_splutter" }
    M3GTR.loopSoundsSet = { m3_splutter = true }
    for i = 1, #M3GTR.bands do
        local extName = M3GTR.bands[i].ext
        local intName = M3GTR.bands[i].int
        M3GTR.allSounds[#M3GTR.allSounds + 1] = extName
        M3GTR.allSounds[#M3GTR.allSounds + 1] = intName
        M3GTR.loopSoundsSet[extName] = true
        M3GTR.loopSoundsSet[intName] = true
    end
    for i = 1, #M3GTR.backfires do
        M3GTR.allSounds[#M3GTR.allSounds + 1] = M3GTR.backfires[i]
    end

    -- Track live player vehicle throttle/brake input alongside telemetry
    Observe("PlayerPuppet", "OnAction", function(_, action)
        if not M3GTR.isM3 then return end
        pcall(function()
            local cname = ListenerAction.GetName(action)
            local name = (cname and cname.value) or tostring(cname)
            if name == "Accelerate" or name == "Decelerate" then
                local aType = ListenerAction.GetType(action)
                local val = ListenerAction.GetValue(action) or 0.0
                if aType == gameinputActionType.BUTTON_RELEASED then
                    val = 0.0
                elseif aType == gameinputActionType.BUTTON_PRESSED and val <= 0.0 then
                    val = 1.0
                end
                if name == "Accelerate" then
                    M3GTR.inputAccel = val
                else
                    M3GTR.inputBrake = val
                end
                M3GTR.inputSeen = true
            end
        end)
    end)

    print("[M3GTR] Initialized (smoothed 30Hz, persistent single-layer voices, gain-capped)")
end)

registerForEvent("onUpdate", function(dt)
    local player = Game.GetPlayer()
    if not player then
        if M3GTR.mountedVehHash then
            M3GTR.mountedVehHash = nil
            M3GTR.isM3 = false
            stopEngine("no player")
        end
        return
    end

    local veh = Game.GetMountedVehicle(player)
    if not veh then
        if M3GTR.mountedVehHash then
            M3GTR.mountedVehHash = nil
            M3GTR.isM3 = false
            stopEngine("dismount")
        end
        return
    end

    local vehHash = tostring(veh:GetEntityID().hash)
    if vehHash ~= M3GTR.mountedVehHash then
        M3GTR.mountedVehHash = vehHash
        local recStr, matched = getRecordInfo(veh)
        M3GTR.isM3 = matched
        if matched then
            -- Bug 1 fix: Do NOT pre-attach emitter here during door-open/transition frames;
            -- wait until mountPending confirms settled Driving + camera state.
            stopEngine("mount_reset")
            M3GTR.mountPending = true
            M3GTR.mountElapsed = 0.0
            M3GTR.mountReadyElapsed = 0.0
            M3GTR.mountTotalElapsed = 0.0
            M3GTR.mountPostAttachElapsed = 0.0
            log("Mounted M3 (%s) — waiting for settled Driving/camera state before attaching emitter", recStr)
        else
            stopEngine("switched vehicle")
        end
    elseif M3GTR.isM3 then
        if M3GTR.mountPending then
            local ready, stateSettled = isMountReady(player, veh)
            M3GTR.mountTotalElapsed = M3GTR.mountTotalElapsed + dt

            if stateSettled then
                M3GTR.mountElapsed = M3GTR.mountElapsed + dt
            else
                M3GTR.mountElapsed = 0.0
            end

            if ready then
                M3GTR.mountReadyElapsed = M3GTR.mountReadyElapsed + dt
            else
                M3GTR.mountReadyElapsed = 0.0
            end

            -- Bug 1 fix: Attach emitter only after stateSettled >= 0.25s (or hard failsafe with camera ready),
            -- then wait >= 0.15s (~4-5 ticks) post-attach before calling startEngine()
            local failsafeReady = (M3GTR.mountTotalElapsed >= M3GTR.mountHardFailsafe) and isCameraReady(veh)
            local canAttach = (stateSettled and M3GTR.mountElapsed >= M3GTR.mountEmitterAttachDelay) or failsafeReady

            if canAttach then
                local axl = getAXL()
                if axl then
                    local _, newly = ensureVehicleEmitter(axl, veh)
                    if newly then
                        M3GTR.mountPostAttachElapsed = 0.0
                        log("Mount settled (%.2fs) — attached emitter '%s', waiting %.2fs before startEngine()",
                            M3GTR.mountElapsed, M3GTR.emitterName, M3GTR.mountPostAttachDelay)
                    elseif M3GTR.emitterAttached then
                        M3GTR.mountPostAttachElapsed = M3GTR.mountPostAttachElapsed + dt
                    end
                end
            end

            local mountCriteriaMet = (M3GTR.mountReadyElapsed >= M3GTR.mountSettleDelay)
                or (stateSettled and M3GTR.mountElapsed >= M3GTR.mountMaxWait)
                or failsafeReady

            local emitterSettled = M3GTR.emitterAttached and (M3GTR.mountPostAttachElapsed >= M3GTR.mountPostAttachDelay)
            local attachFallback = failsafeReady and (M3GTR.mountTotalElapsed >= M3GTR.mountHardFailsafe + 0.50)

            if mountCriteriaMet and (emitterSettled or attachFallback) then
                M3GTR.mountPending = false
                startEngine(veh)
            end
        else
            updateEngine(veh, dt)
        end
    end
end)

registerForEvent("onShutdown", function()
    stopEngine("CET shutdown/reload")
end)

return M3GTR