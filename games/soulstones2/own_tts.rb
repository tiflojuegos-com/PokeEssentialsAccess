# Soulstones 2 ships its own screen reader (Reborn TextToSpeech, off as shipped); with it on, the mod warns once
# of the two voices, naming the file to edit.
module PokeAccess
  module SS2OwnTTS
    # True while the game's own reader is switched on.
    def self.on?
      (::TTS_ENABLED rescue false) ? true : false
    end

    # Says it once per session, and only when there really are two voices.
    def self.warn_once
      return if @warned
      @warned = true
      return unless on?
      PokeAccess.write_marker("soulstones2: TTS_ENABLED del juego esta activo; dos voces a la vez\n")
      PokeAccess.speak(PokeAccess::I18n.t(:ss2_two_voices), false)
    rescue StandardError
      nil
    end

    # Forgets the notice, so a spec can drive it and a reloaded game says it again.
    def self.forget; @warned = false; end
  end
end

# On the first map change, not after Scene_Map#main, which returns only when the player leaves the map.
PokeAccess::Events.on(:map_changed) { PokeAccess::SS2OwnTTS.warn_once }
