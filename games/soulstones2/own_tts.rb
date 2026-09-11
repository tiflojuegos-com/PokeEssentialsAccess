# This game ships a screen reader of its own (Reborn TextToSpeech, off in the shipped scripts). A player who
# turns it on hears everything twice, and the mod cannot pick which voice to silence, so it says so once,
# on the first map, and names the file to edit.
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

# On the first map change, which is the earliest moment the player is listening and the mod is fully up.
# NOT an after-hook on Scene_Map#main: that method does not return until the player leaves the map, so the
# notice would arrive on the way out.
PokeAccess::Events.on(:map_changed) { PokeAccess::SS2OwnTTS.warn_once }
