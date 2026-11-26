# Rosewell Gallery flashback of Case Four (maps 187 to 189): three spotlights three tiles wide (map 188, events 2, 4, 6)
# sweep the gallery; one that reaches the player sends them back to (14, 8) on map 187. The office computer (map 189,
# EV1) takes "Rose" (said by assist_answers.rb) and turns them off (switch 88); the way out (EV9) waits for it.
module PokeAccess
  module AshenRosewell
    ENTRANCE = 187
    GALLERY = 188

    # Whether the computer has turned the spotlights off.
    def self.lights_off?; $game_switches[88] ? true : false; end
  end
end

PokeAccess::Game.define("ashenfrost") do
  gallery = PokeAccess::AshenRosewell
  mechanic(:state, gallery::GALLERY, :part => :afa_spotlights) do
    auto
    obstacle(/\ASpotlight\z/, :moving => true, :label => :afa_spotlight)
    arrival_hint :afa_gallery_rule, :once => true
    phase lambda { PokeAccess::Puzzles.assist? && !gallery.lights_off? }, :hint => :afa_gallery_hint
    solved(nil, :quiet => true) { gallery.lights_off? }
  end

  mechanic(:state, gallery::ENTRANCE, :part => :afa_spotlights) do
    auto
    sent_back :afa_gallery_caught, :maps => [gallery::GALLERY], :to => [14, 8], :from => [5, 14, 4, 36]
  end
end
