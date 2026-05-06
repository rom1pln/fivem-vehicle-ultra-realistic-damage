-- ==============================
-- Ultra Realistic Damage v2.4
-- (camera shake + full clean reset)
-- ==============================
local ped, veh = nil, 0
local lastSpeed = 0.0
local lastVel = vector3(0,0,0)
local lastEngHp, lastBodyHp = 1000.0, 1000.0

local perfDecayEnd = 0
local torqueMul = 1.0

-- fuites
local leakState = { radiator = {active=false, untilTime=0, hp=0.0}, fuel=false }

-- état véhicule (cache)
-- vehState[id] = { suspLevel=0, steerBias=0.0, lastAirStart=0, wasInAir=false, bones={}, baselineHandling={} }
local vehState = {}

-- Champs de handling utilisés
local HANDLING_FIELDS = { 'fSuspensionCompDamp','fSuspensionReboundDamp','fSuspensionForce','fAntiRollBarForce','fTractionCurveMax' }

-- ===== Utils =====
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
local function lerp(a,b,t) return a+(b-a)*t end
local function prob(p) return math.random() < p end
local function sign(x) if x<0 then return -1 elseif x>0 then return 1 else return 0 end end

local function updatePedVeh()
  ped = PlayerPedId()
  if IsPedInAnyVehicle(ped, false) then
    local v = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(v, -1) == ped then veh = v; return end
  end
  veh = 0
end

local function captureBaselineHandling(v)
  local base = {}
  for _,field in ipairs(HANDLING_FIELDS) do
    local val = GetVehicleHandlingFloat(v, 'CHandlingData', field)
    if val then base[field] = val end
  end
  return base
end

local function getVehState(v)
  local id = v
  local st = vehState[id]
  if st then return st end

  -- cache os
  local bones = {}
  local names = {"bumper_f","bumper_r","bonnet","boot","wheel_lf","wheel_rf","wheel_lr","wheel_rr"}
  for _,bn in ipairs(names) do
    local idx = GetEntityBoneIndexByName(v, bn)
    if idx ~= -1 then bones[#bones+1] = idx end
  end

  vehState[id] = {
    suspLevel=0, steerBias=0.0,
    lastAirStart=0, wasInAir=false,
    bones=bones,
    baselineHandling=captureBaselineHandling(v)
  }
  return vehState[id]
end

local function restoreHandlingBaseline(v)
  local st = getVehState(v)
  for _,field in ipairs(HANDLING_FIELDS) do
    local base = st.baselineHandling[field]
    if base then SetVehicleHandlingFloat(v, 'CHandlingData', field, base) end
  end
end

local function setHandlingFromBaseline(v, level)
  local st = getVehState(v)
  local layer = Config.Jumps.SuspensionDamage[level] or Config.Jumps.SuspensionDamage[0]
  for _,field in ipairs(HANDLING_FIELDS) do
    local base = st.baselineHandling[field]
    if base and layer[field] then
      SetVehicleHandlingFloat(v, 'CHandlingData', field, base * layer[field])
    end
  end
end

local function impactAngleMultiplier(v, relVel)
  local fw = GetEntityForwardVector(v)
  local right = vector3(fw.y, -fw.x, fw.z)
  local fDot = fw.x*relVel.x + fw.y*relVel.y + fw.z*relVel.z
  local rDotAbs = math.abs(right.x*relVel.x + right.y*relVel.y + right.z*relVel.z)
  if math.abs(fDot) >= rDotAbs then
    if fDot < 0 then return Config.Angle.Front else return Config.Angle.Rear end
  else
    return Config.Angle.Side
  end
end

-- Déformation localisée (utilise le cache d’os)
local function deformLocalized(v, intensity)
  local st = getVehState(v)
  if #st.bones == 0 then return end
  for i=1,#st.bones do
    local pos = GetWorldPositionOfEntityBone(v, st.bones[i])
    SetVehicleDamage(v, pos.x, pos.y, pos.z, intensity*(0.8+math.random()*0.4), 0.25, true)
  end
end

-- Effet tremblement caméra
local function accidentShake(sev)
  local shake = (sev=="minor" and Config.Driver.ScreenShakeMinor)
             or (sev=="moderate" and Config.Driver.ScreenShakeModerate)
             or Config.Driver.ScreenShakeSevere
  ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", shake)
end

-- Vitres/Portes/Feux/Pneus
local function glassDamage(v, sev)
  local p = (sev=="minor" and Config.Failures.WindowShatterMinor)
         or (sev=="moderate" and Config.Failures.WindowShatterModerate)
         or Config.Failures.WindowShatterSevere
  for i=0,7 do if IsVehicleWindowIntact(v,i) and prob(p) then SmashVehicleWindow(v,i) end end
end

local function doorDamage(v, sev)
  if sev=="minor" then return end
  local p = (sev=="severe") and Config.Failures.DoorBreakSevere or Config.Failures.DoorBreakModerate
  for d=0,5 do if prob(p) then SetVehicleDoorBroken(v,d,false) end end
end

local function lightDamage(v, sev)
  local p = (sev=="severe") and Config.Failures.LightFailSevere or Config.Failures.LightFailModerate
  if sev=="minor" then p = p*0.3 end
  if prob(p) then SetVehicleLights(v,1) end
end

local function tyreBurstSide(v, sev, isSide)
  if not isSide then return end
  local p = (sev=="minor" and Config.Failures.TyreBurstSideMinor)
         or (sev=="moderate" and Config.Failures.TyreBurstSideModerate)
         or Config.Failures.TyreBurstSideSevere
  local n = GetVehicleNumberOfWheels(v)
  for w=0,n-1 do
    if not IsVehicleTyreBurst(v,w,false) and prob(p) then
      SetVehicleTyreBurst(v,w,true,1000.0)
    end
  end
end

-- Moteur / Carrosserie / Réservoir
local function engineBodyTankHit(v, sev, angMul)
  local m,g = Config.Mechanics, Config.GlobalSeverity
  local eng = GetVehicleEngineHealth(v)
  local body = GetVehicleBodyHealth(v)
  local tank = GetVehiclePetrolTankHealth(v)
  local eHit = (sev=="minor" and m.EngineHitMinor) or (sev=="moderate" and m.EngineHitModerate) or m.EngineHitSevere
  local bHit = (sev=="minor" and m.BodyHitMinor)   or (sev=="moderate" and m.BodyHitModerate)   or m.BodyHitSevere
  eng = eng - eHit*angMul*g
  body = body - bHit*angMul*g
  if sev~="minor" then tank = tank - ((sev=="moderate" and m.TankHitModerate) or m.TankHitSevere)*g end
  SetVehicleEngineHealth(v, clamp(eng, -4000.0, 1000.0))
  SetVehicleBodyHealth(v, clamp(body, 0.0, 1000.0))
  SetVehiclePetrolTankHealth(v, clamp(tank, -1000.0, 1000.0))
end

local function startPerfLoss(sev)
  local m,g = Config.Mechanics, Config.GlobalSeverity
  local add = (sev=="minor" and m.PowerLossMinor) or (sev=="moderate" and m.PowerLossModerate) or m.PowerLossSevere
  torqueMul = clamp(1.0 - add*g, 0.25, 1.0)
  perfDecayEnd = GetGameTimer() + 15000
end

local function maybeLeaks(v, sev, angMul)
  local now,m = GetGameTimer(), Config.Mechanics
  if sev=="minor" then return end
  local rad = (sev=="moderate") and m.RadiatorLeakModerate or m.RadiatorLeakSevere
  local frontalBonus = (angMul==Config.Angle.Front) and 0.20 or 0.0
  if (not leakState.radiator.active) and prob(rad.chance + frontalBonus) then
    leakState.radiator.active=true
    leakState.radiator.untilTime = now + rad.duration*1000
    leakState.radiator.hp = rad.hpPerTick
  end
  local fchance = (sev=="moderate") and m.FuelLeakModerate.chance or m.FuelLeakSevere
  if (not leakState.fuel) and prob(fchance) then leakState.fuel = true end
end

-- Suspensions / handling (à partir de la baseline)
local function applySuspHandling(v, level)
  level = clamp(level,0,3)
  setHandlingFromBaseline(v, level)
end

local function damageWheel(v, severe, idx)
  local dropMin = Config.Jumps.HardLandingEvents.WheelHealthDrop.min
  local dropMax = Config.Jumps.HardLandingEvents.WheelHealthDrop.max
  local drop = severe and dropMax or lerp(dropMin, dropMax, 0.5)
  local cur = GetVehicleWheelHealth(v, idx)
  if not cur or cur <= 0 then cur = Config.DefaultWheelHealth end
  SetVehicleWheelHealth(v, idx, clamp(cur - drop, 0.0, 1000.0))
  if severe and prob(Config.Jumps.HardLandingEvents.TyreBurstChance) then
    SetVehicleTyreBurst(v, idx, true, 1000.0)
  end
  if severe and prob(Config.Jumps.HardLandingEvents.LockWheelChance) then
    SetVehicleWheelHealth(v, idx, 1.0)
  end
end

local function induceSteerBias(v)
  local st = getVehState(v)
  local add = (0.05 + math.random()*0.10) * sign(math.random()-0.5)
  st.steerBias = clamp(st.steerBias + add, -Config.Jumps.HardLandingEvents.SteerBiasMax, Config.Jumps.HardLandingEvents.SteerBiasMax)
  SetVehicleSteerBias(v, st.steerBias)
end

-- SURFACES
local function mapSurfaceType(id)
  if id==4 or id==7 or id==9 then return "ASPHALT" end
  if id==1 or id==3 then return "CONCRETE" end
  if id==6 then return "GRAVEL" end
  if id==8 or id==10 then return "ROCK" end
  if id==11 or id==12 then return "SAND" end
  if id==13 then return "MUD" end
  if id==99 then return "CURB" end
  return "ASPHALT"
end

local function getWheelSurfaceType(v, w)
  local id = GetVehicleWheelSurfaceMaterial(v, w) or 4
  return mapSurfaceType(id)
end

-- Sauts / atterrissages (jump abusé)
local function processJumpLanding(v, vNow)
  local st = getVehState(v)
  local inAir = IsEntityInAir(v)
  local now = GetGameTimer()

  if inAir and not st.wasInAir then
    st.wasInAir = true
    st.lastAirStart = now
  elseif not inAir and st.wasInAir then
    st.wasInAir = false
    local airTime = now - st.lastAirStart
    local vZ = math.abs(vNow.z)
    local hard = (vZ >= Config.Jumps.HardLandingVz) or (airTime >= Config.Jumps.MinAirTimeForHard)
    local medium = (vZ >= Config.Jumps.MediumLandingVz) or (airTime >= Config.Jumps.MinAirTimeForMed)

    if hard or medium then
      local add = hard and 2 or 1
      st.suspLevel = clamp(st.suspLevel + add, 0, 3)
      applySuspHandling(v, st.suspLevel)

      local n = GetVehicleNumberOfWheels(v)
      if hard then
        if vZ >= Config.Jumps.HardLandingEvents.BurstAllWheelsAtVz then
          for w=0,n-1 do
            SetVehicleTyreBurst(v, w, true, 1000.0)
            damageWheel(v, true, w)
          end
        else
          for i=1,2 do damageWheel(v, true, math.random(0, n-1)) end
          if prob(0.4) then damageWheel(v, true, math.random(0, n-1)) end
        end
        induceSteerBias(v)
        deformLocalized(v, 1000.0)
        accidentShake("moderate")
      else
        damageWheel(v, false, math.random(0, n-1))
        deformLocalized(v, 500.0)
        accidentShake("minor")
      end
    end
  end
end

-- Trottoir trop vite → crevaison
local function curbStrikeCheck(v, deltaV, angMul, speedNow)
  if speedNow*3.6 < Config.Curb.SpeedKmhMin then return end
  if angMul ~= Config.Angle.Front and Config.Curb.FrontOnly then return end
  local p = Config.Curb.BasePunctureChance
  local n = GetVehicleNumberOfWheels(v)
  local wheelsFront = math.min(1, n-1)
  for w=0,wheelsFront do
    local surf = getWheelSurfaceType(v, w)
    local sCfg = Config.Surface[surf] or Config.Surface.ASPHALT
    local bonus = sCfg.curbBonus or 1.0
    if prob(p * (sCfg.punctureMul or 1.0) * bonus) then
      if not IsVehicleTyreBurst(v, w, false) then
        SetVehicleTyreBurst(v, w, true, 1000.0)
      end
    end
  end
end

-- ===== Collisions Δv =====
CreateThread(function()
  math.randomseed(GetGameTimer())
  while true do
    Wait(Config.Ticks.Main)
    updatePedVeh()
    if veh == 0 then
      lastSpeed = 0.0; lastVel = vector3(0,0,0)
      goto cont
    end

    local vNow = GetEntityVelocity(veh)
    local speedNow = #(vNow)
    local deltaV = lastSpeed - speedNow

    -- Sauts
    processJumpLanding(veh, vNow)

    -- Détection repair (auto)
    if Config.Repair.AutoDetect then
      local eng = GetVehicleEngineHealth(veh)
      local body = GetVehicleBodyHealth(veh)
      if (eng - lastEngHp >= Config.Repair.EngineJump) or (body - lastBodyHp >= Config.Repair.BodyJump) then
        TriggerEvent('veh_damage:reset')
      end
      lastEngHp, lastBodyHp = eng, body
    end

    -- Collision/Δv
    if deltaV > 0 and HasEntityCollidedWithAnything(veh) and deltaV > 2.0 then
      local relVel = vector3(lastVel.x - vNow.x, lastVel.y - vNow.y, lastVel.z - vNow.z)
      local angMul = impactAngleMultiplier(veh, relVel)
      local sev
      if deltaV >= Config.Impact.SevereDeltaV then sev = "severe"
      elseif deltaV >= Config.Impact.ModerateDeltaV then sev = "moderate"
      elseif deltaV >= Config.Impact.MinorDeltaV then sev = "minor" end

      if sev then
        accidentShake(sev)

        local isSide = (angMul == Config.Angle.Side)
        engineBodyTankHit(veh, sev, angMul * Config.GlobalSeverity)
        glassDamage(veh, sev)
        doorDamage(veh, sev)
        tyreBurstSide(veh, sev, isSide)
        lightDamage(veh, sev)
        startPerfLoss(sev)
        maybeLeaks(veh, sev, angMul)

        if sev=="severe" then deformLocalized(veh, 1200.0) else deformLocalized(veh, 600.0) end

        curbStrikeCheck(veh, deltaV, angMul, speedNow)

        if GetVehicleBodyHealth(veh) <= 120.0 then
          SetVehicleUndriveable(veh, true)
          SetVehicleEngineOn(veh, false, true, true)
        end
      end
    end

    lastSpeed = speedNow
    lastVel = vNow
    ::cont::
  end
end)

-- Pertes de perfs / feu
CreateThread(function()
  while true do
    Wait(Config.Ticks.PerfDecay)
    if veh ~= 0 then
      local now = GetGameTimer()
      if perfDecayEnd > 0 then
        local t = clamp((perfDecayEnd - now)/15000.0, 0.0, 1.0)
        local curMul = lerp(1.0, torqueMul, t)
        SetVehicleEnginePowerMultiplier(veh, (curMul-1.0)*100.0)
        SetVehicleEngineTorqueMultiplier(veh, curMul)
        if now >= perfDecayEnd then
          perfDecayEnd = 0
          SetVehicleEnginePowerMultiplier(veh, 0.0)
          SetVehicleEngineTorqueMultiplier(veh, 1.0)
        end
      end

      local eng = GetVehicleEngineHealth(veh)
      if eng < Config.Mechanics.SmokeAtEngineHP then
        SetVehicleCheatPowerIncrease(veh, 0.0)
        if eng < Config.Mechanics.FireAtEngineHP and leakState.fuel and not IsEntityOnFire(veh) then
          if prob(0.12 * Config.GlobalSeverity) then StartEntityFire(veh) end
        end
      end
    end
  end
end)

-- Fuites
CreateThread(function()
  while true do
    Wait(Config.Ticks.Leak)
    if veh ~= 0 then
      local now = GetGameTimer()
      if leakState.radiator.active then
        if now <= leakState.radiator.untilTime then
          local eng = GetVehicleEngineHealth(veh)
          SetVehicleEngineHealth(veh, clamp(eng - leakState.radiator.hp * Config.GlobalSeverity, -4000.0, 1000.0))
        else
          leakState.radiator.active = false
          leakState.radiator.hp = 0.0
        end
      end
    end
  end
end)

-- Ré-application handling / steerBias à partir de la baseline
CreateThread(function()
  while true do
    Wait(Config.Ticks.HandlingReapply)
    if veh ~= 0 then
      local st = getVehState(veh)
      setHandlingFromBaseline(veh, st.suspLevel or 0)
      if st.steerBias and st.steerBias ~= 0 then SetVehicleSteerBias(veh, st.steerBias) end
    end
  end
end)

-- ===== RESET propre (commande + event + export) =====
local function fixWheelsAndTyres(v)
  local n = GetVehicleNumberOfWheels(v)
  for w=0,n-1 do
    if IsVehicleTyreBurst(v, w, true) or IsVehicleTyreBurst(v, w, false) then
      -- Si dispo dans ta build FiveM :
      if SetVehicleTyreFixed then SetVehicleTyreFixed(v, w) end
    end
    -- Restaure la santé de roue (évite une roue "grippée")
    SetVehicleWheelHealth(v, w, Config.DefaultWheelHealth)
  end
end

local function resetVehicleState(v)
  local id = v
  -- fuites / perfs / biais
  leakState.radiator.active = false
  leakState.radiator.hp = 0.0
  leakState.fuel = false
  perfDecayEnd = 0
  torqueMul = 1.0

  -- multipliers moteur remis à zéro
  SetVehicleEnginePowerMultiplier(v, 0.0)
  SetVehicleEngineTorqueMultiplier(v, 1.0)
  SetVehicleCheatPowerIncrease(v, 0.0)
  SetVehicleSteerBias(v, 0.0)

  -- handling : revenir EXACTEMENT à la baseline
  restoreHandlingBaseline(v)
  local st = getVehState(v)
  st.suspLevel = 0
  st.steerBias = 0.0

  -- roues/pneus OK
  fixWheelsAndTyres(v)
end

RegisterCommand('vrestart', function()
  if veh ~= 0 then
    -- Réparation GTA (visuel + HP)
    SetVehicleFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineOn(veh, true, true, false)

    -- Reset complet custom
    resetVehicleState(veh)
    TriggerEvent('chat:addMessage', { args = {'Vehicule', 'Réinitialisé après réparation (performances restaurées).'} })
  end
end)

RegisterNetEvent('veh_damage:reset', function()
  if veh ~= 0 then
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
    resetVehicleState(veh)
  end
end)

exports('ResetVehicleDamageState', function(v)
  if v and v ~= 0 then resetVehicleState(v) end
end)

-- Optionnel : réduire la “solidité magique” GTA
if Config.DisableVanillaDeformation then
  CreateThread(function()
    while true do
      Wait(1000)
      updatePedVeh()
      if veh ~= 0 then
        SetVehicleCanBeVisiblyDamaged(veh, true)
        SetVehicleStrong(veh, false)
      end
    end
  end)
end
