# The opening's controls screen (ButtonEventScene): Royal's copy registers no paragraph and shows one picture with the
# whole list (bg_controles, _en in English), said from its transcription (royal_controls) as the screen is set up.
module PokeAccess
  module RoyalControls
    # Speaks the transcribed picture with its keys as the player has them now, unless the scene registered paragraphs
    # of its own (core's controls help says those). The picture paints the default letters, whatever F1 has moved.
    def self.say(scene)
      labels = PokeAccess.ivar(scene, :@access_labels)
      return unless labels.nil? || labels.empty?
      text = PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:royal_controls), PokeAccess::KeyHints::RGSS_LETTERS)
      PokeAccess.speak(text, true)
    end
  end
end

PokeAccess::Game.define("royal") do
  after("ButtonEventScene", :set_up_screen, :optional => true) { |scene, _r, _a| PokeAccess::RoyalControls.say(scene) }
end
