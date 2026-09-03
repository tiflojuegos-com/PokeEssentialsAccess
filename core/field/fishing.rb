module PokeAccess
  # Fishing has a reflex test: when a Pokemon bites, the engine shows "Oh! A bite!" and waits a fraction
  # of a second for the button -- invisible to a screen-reader player -- so the bite is announced the
  # instant the reflex test starts, in time to react.
  #
  # The message the engine passes to that test ALREADY says a Pokemon bit, and the dialogue reader queues
  # it. Two announcements inside a half-second window is one too many, and the queued copy was still
  # playing when the throw had already resolved, so the game's own line is suppressed for this one call.
  # With FISHINGAUTOHOOK the engine returns before showing the message or opening a reaction window
  # (six gen-6 games have that early return), so there is no button to announce and no game line to
  # suppress; the catch narrates itself through the normal messages.
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
