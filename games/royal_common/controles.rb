# The opening's controls screen (ButtonEventScene): Royal's copy registers no paragraph and shows one picture with the
# whole list (bg_controles, _en in English), said from its transcription as the screen is set up. Each game paints a
# picture of its own, so each profile names the transcription of its picture (RoyalControls.key).
module PokeAccess
  module RoyalControls
    @key = nil

    class << self
      # The lang key of the transcribed picture the game paints, set by its profile.
      attr_accessor :key
    end

    # Speaks the transcribed picture with its keys as the player has them now, unless the scene registered paragraphs
    # of its own (core's controls help says those). The picture paints the default letters, whatever F1 has moved.
    def self.say(scene)
      labels = PokeAccess.ivar(scene, :@access_labels)
      return unless @key && (labels.nil? || labels.empty?)
      text = PokeAccess::KeyHints.localize(PokeAccess::I18n.t(@key), PokeAccess::KeyHints::RGSS_LETTERS)
      PokeAccess.speak(text, true)
    end
  end
end

PokeAccess::Game.define("royal_common") do
  after("ButtonEventScene", :set_up_screen, :optional => true) { |scene, _r, _a| PokeAccess::RoyalControls.say(scene) }
end
