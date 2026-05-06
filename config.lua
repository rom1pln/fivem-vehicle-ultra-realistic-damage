Config = {}

-- Intensité globale (0.0–2.0)
Config.GlobalSeverity = 1.10

-- Tickrates (perf)
Config.Ticks = {
  Main = 10,           -- ms (Δv / sauts)
  PerfDecay = 500,
  Leak = 2000,
  HandlingReapply = 1500
}

-- Seuils Δv (m/s)
Config.Impact = {
  MinorDeltaV    = 3.5,
  ModerateDeltaV = 7.0,
  SevereDeltaV   = 12.0,
}

-- Angle d’impact
Config.Angle = { Front = 1.30, Rear = 1.10, Side = 1.40 }

-- Probabilités (0..1)
Config.Failures = {
  TyreBurstSideMinor    = 0.12,
  TyreBurstSideModerate = 0.40,
  TyreBurstSideSevere   = 0.80,

  WindowShatterMinor    = 0.25,
  WindowShatterModerate = 0.65,
  WindowShatterSevere   = 0.95,

  DoorBreakModerate     = 0.18,
  DoorBreakSevere       = 0.50,

  LightFailModerate     = 0.30,
  LightFailSevere       = 0.75,
}

-- Dégradations mécaniques / fuites
Config.Mechanics = {
  PowerLossMinor     = 0.12,
  PowerLossModerate  = 0.30,
  PowerLossSevere    = 0.60,

  EngineHitMinor     = 60.0,
  EngineHitModerate  = 200.0,
  EngineHitSevere    = 450.0,

  BodyHitMinor       = 80.0,
  BodyHitModerate    = 220.0,
  BodyHitSevere      = 450.0,

  TankHitModerate    = 140.0,
  TankHitSevere      = 320.0,

  RadiatorLeakModerate = { chance = 0.35, hpPerTick = 2.5, duration = 80 },
  RadiatorLeakSevere   = { chance = 0.75, hpPerTick = 5.0, duration = 150 },

  FuelLeakModerate = { chance = 0.25 },
  FuelLeakSevere   = 0.60,

  SmokeAtEngineHP  = 450.0,
  FireAtEngineHP   = 220.0
}

-- Sauts / suspensions
Config.Jumps = {
  HardLandingVz      = 7.5,    -- m/s
  MediumLandingVz    = 5.5,
  MinAirTimeForHard  = 900,    -- ms
  MinAirTimeForMed   = 500,

  -- Multiplicateurs à appliquer par rapport aux VALEURS D’ORIGINE (baseline)
  SuspensionDamage = {
    [0] = { fSuspensionCompDamp = 1.00, fSuspensionReboundDamp = 1.00, fSuspensionForce = 1.00, fAntiRollBarForce = 1.00, fTractionCurveMax = 1.00 },
    [1] = { fSuspensionCompDamp = 0.85, fSuspensionReboundDamp = 0.88, fSuspensionForce = 0.92, fAntiRollBarForce = 0.92, fTractionCurveMax = 0.96 },
    [2] = { fSuspensionCompDamp = 0.70, fSuspensionReboundDamp = 0.75, fSuspensionForce = 0.80, fAntiRollBarForce = 0.80, fTractionCurveMax = 0.92 },
    [3] = { fSuspensionCompDamp = 0.55, fSuspensionReboundDamp = 0.60, fSuspensionForce = 0.68, fAntiRollBarForce = 0.65, fTractionCurveMax = 0.88 },
  },

  -- Atterrissages très durs → événements
  HardLandingEvents = {
    WheelHealthDrop = { min = 250.0, max = 500.0 },
    TyreBurstChance = 0.55,
    LockWheelChance = 0.20,
    SteerBiasMax    = 0.30,
    BurstAllWheelsAtVz = 10.5, -- si |vZ| >= → éclater 2–4 pneus
  }
}

-- Surfaces
Config.Surface = {
  ASPHALT   = { punctureMul = 1.0, rimHitMul = 1.0, curbBonus = 1.3 },
  CONCRETE  = { punctureMul = 1.1, rimHitMul = 1.0, curbBonus = 1.4 },
  GRAVEL    = { punctureMul = 1.2, rimHitMul = 1.2, curbBonus = 1.0 },
  ROCK      = { punctureMul = 1.6, rimHitMul = 1.8, curbBonus = 1.0 },
  SAND      = { punctureMul = 0.7, rimHitMul = 1.2, curbBonus = 1.0 },
  MUD       = { punctureMul = 0.6, rimHitMul = 1.3, curbBonus = 1.0 },
  SNOW      = { punctureMul = 0.9, rimHitMul = 1.1, curbBonus = 1.0 },
  CURB      = { punctureMul = 2.0, rimHitMul = 2.2, curbBonus = 2.0 },
}

-- Trottoir
Config.Curb = {
  SpeedKmhMin = 35.0,
  FrontOnly   = true,
  BasePunctureChance = 0.30,
}

-- Reset / réparation
Config.Repair = {
  AutoDetect = true,      -- reset auto si gros saut de HP
  EngineJump = 300.0,
  BodyJump   = 300.0,
}

-- Effet conducteur — SHAKE UNIQUEMENT
Config.Driver = {
  ScreenShakeMinor    = 0.25,
  ScreenShakeModerate = 0.55,
  ScreenShakeSevere   = 0.95
}

-- Divers
Config.DisableVanillaDeformation = false
Config.DefaultWheelHealth = 1000.0
