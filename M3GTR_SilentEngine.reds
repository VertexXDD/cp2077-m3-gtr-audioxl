module M3GTRSilentEngine

import Codeware.*
import AudioXL.*

public class M3GTRSilentEnginePatcher extends AudioXLPatcher {
  public func Name() -> String {
    return "M3GTR_SilentEngine";
  }

  public func Apply(md: ref<audioCookedMetadataResource>) -> Void {
    let sys = AudioXLSystem.Get();
    if !IsDefined(sys) { return; }

    let targetName: CName = n"v_car_ctrlsec_m3_gtr_no_eng";
    if IsDefined(sys.FindRecord(md, targetName)) {
      return;
    }

    let source = sys.FindRecord(md, n"v_car_herrera_outlaw") as audioVehicleMetadata;
    if !IsDefined(source) {
      this.missed += 1;
      return;
    }

    let audio = new audioVehicleMetadata();
    audio.name = targetName;
    audio.acousticIsolationFactor = source.acousticIsolationFactor;
    audio.collisionCooldown = source.collisionCooldown;
    audio.dopplerFactor = source.dopplerFactor;
    audio.emitterPositionData = source.emitterPositionData;
    audio.exitDelay = source.exitDelay;
    // Intentionally omitted: audio.gearSweeteners (vanilla shift/backfire sweeteners)
    audio.hasRadioReceiver = source.hasRadioReceiver;
    audio.matchingStartupRadioStations = source.matchingStartupRadioStations;
    audio.maxPlayingDistance = source.maxPlayingDistance;
    audio.maxRpm = source.maxRpm;
    audio.minRpm = source.minRpm;
    audio.radioPlaysWhenEngineStartsProbability = source.radioPlaysWhenEngineStartsProbability;
    audio.radioReceiverType = source.radioReceiverType;
    audio.suspensionSqueekTimeout = source.suspensionSqueekTimeout;
    audio.testWheelMaterial = source.testWheelMaterial;
    audio.trafficEmitterMetadata = source.trafficEmitterMetadata;
    audio.usesPoliceRadioStation = source.usesPoliceRadioStation;
    audio.vehicleCollisionSettings = source.vehicleCollisionSettings;
    audio.vehicleGridDestructionSettings = source.vehicleGridDestructionSettings;
    audio.vehiclePartSettings = source.vehiclePartSettings;
    audio.wheelData = source.wheelData;
    audio.generalData = source.generalData;
    // Intentionally omitted: audio.mechanicalData (vanilla engine synth & throttle/shift audio)

    ArrayPush(md.entries, audio);
    this.applied += 1;
  }
}

public class M3GTRSilentEngineService extends ScriptableService {
  private let m_registered: Bool;

  private cb func OnLoad() {
    this.TryRegister();
  }

  private cb func OnInitialize() {
    this.TryRegister();
  }

  private func TryRegister() -> Void {
    if this.m_registered { return; }
    let sys = AudioXLSystem.Get();
    if !IsDefined(sys) { return; }
    AudioXLAPI.RegisterPatcher(new M3GTRSilentEnginePatcher());
    this.m_registered = true;
  }
}