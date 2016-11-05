module sb.events.internal_events;
import std.datetime;

// Global app events
struct SbAppLoadedEvent {}
struct SbAppKilledEvent {}
struct SbNextFrameEvent {
    double time, dt;
    uint   frameId;
}

// And app / frame time state
struct SbFrameState {
    double currentTime, dt;
    uint   currentFrameId;
}

// SbEvents relating to SbModule load / reload pipeline:
//   ModuleLoading => ModuleLoaded | ModuleLoadFailed
//struct SbModuleLoadingEvent {}
//struct SbModuleLoadedEvent  {}
//struct SbModuleLoadFailedEvent {}

// SbEvents for module run state pipeline:
//   ModuleRunning => ModuleKilled | ModuleError
//struct SbModuleRunningEvent {}
//struct SbModuleKilledEvent  {}
//struct SbModuleErrorEvent   {}

// All module + app events for lifetime of program:
//  SbAppLoadedEvent  =>  SbNextFrameEvent*  =>  SbAppKilledEvent
//
// while running:
//   SbModuleLoadingEvent =>
//       SbModuleLoadFailedEvent |
//       SbModuleLoadedEvent =>
//           SbModuleRunningEvent =>
//               SbModuleKilledEvent |        (normal exit)
//               SbModuleErrorEvent  |        (runtime exception)
//               SbModuleLoadingEvent => ...  (module reloaded)
//

