module PokeAccess
  # The bite: the engine shows "Oh! A bite!" and waits a fraction of a second for the button, so the bite is
  # announced the instant the reflex test starts and the game's own (queued) line for it is suppressed. With
  # FISHINGAUTOHOOK the engine returns before showing it, and the catch narrates itself.
  def self.say_fishing_bite(message)
    return if defined?(::FISHINGAUTOHOOK) && ::FISHINGAUTOHOOK
    say_dialogue_skip(message)
    speak(I18n.t(:fish_bite), true)
  end
end

# pbWaitForInput is the fishing reflex test (and nothing else) in both engines, a top-level method;
# announce the bite before it blocks for the button.
#
# The message is args[1]. The signature is pbWaitForInput(msgWindow, message, frames) in both eras, so
# args[0] is the WINDOW: handing it to say_dialogue_skip suppressed nothing -- the game's line slipped
# through anyway -- and the mod's own notice then piled on top of it within half a second.
PokeAccess::Hooks.wrap_global("pbWaitForInput", "hook_fishing", :before) { |args, _r| PokeAccess.say_fishing_bite(args[1]) }
