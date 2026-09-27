module PokeAccess
  # Announces the bite as the reflex test starts, skipping the game's own queued line; nothing under
  # FISHINGAUTOHOOK, where the engine returns before showing it.
  def self.say_fishing_bite(message)
    return if defined?(::FISHINGAUTOHOOK) && ::FISHINGAUTOHOOK
    say_dialogue_skip(message)
    speak(I18n.t(:fish_bite), true)
  end
end

# pbWaitForInput(msgWindow, message, frames), the fishing reflex test in both eras: announces the bite before it
# waits for the button.
PokeAccess::Hooks.wrap_global("pbWaitForInput", "hook_fishing", :before) { |args, _r| PokeAccess.say_fishing_bite(args[1]) }
