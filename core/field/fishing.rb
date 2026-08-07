module PokeAccess
  # Fishing has a reflex test: when a Pokemon bites, the engine shows "Oh! A bite!" and waits a fraction
  # of a second for the button -- invisible to a screen-reader player -- so the bite is announced the
  # instant the reflex test starts, in time to react.
  #
  # The message the engine passes to that test ALREADY says a Pokemon bit, and the dialogue reader queues
  # it. Two announcements inside a half-second window is one too many, and the queued copy was still
  # playing when the throw had already resolved, so the game's own line is suppressed for this one call.
  def self.say_fishing_bite(message)
    say_dialogue_skip(message)
    speak(I18n.t(:fish_bite), true)
  end
end

# pbWaitForInput is the fishing reflex test (and nothing else) in both engines, a top-level method;
# announce the bite before it blocks for the button.
#
# El mensaje es args[1]. La firma es pbWaitForInput(msgWindow, message, frames) en las dos eras, asi que
# args[0] es la VENTANA: pasarsela a say_dialogue_skip no suprimia nada -- la linea del juego se colaba
# igual -- y encima el aviso propio se le montaba encima dentro de una ventana de medio segundo.
PokeAccess::Hooks.wrap_global("pbWaitForInput", "hook_fishing", :before) { |args, _r| PokeAccess.say_fishing_bite(args[1]) }
