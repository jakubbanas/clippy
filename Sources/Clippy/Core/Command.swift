/// A user-triggerable action a feature contributes to the command launcher.
/// The launcher owns the single hotkey and lists every feature's commands in a
/// menu, so a new triggerable feature needs only to return one from `commands()`.
struct Command {
    let title: String
    let perform: () -> Void
}
