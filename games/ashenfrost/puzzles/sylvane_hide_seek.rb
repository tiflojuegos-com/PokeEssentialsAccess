# Hide-and-seek in Sylvane's House (maps 47, 49, 50, 52, 53, Case Nineteen): the dizzy guest (map 49, EV17) sets 287 to
# 1 and four children hide in plain sight, one per room; each found adds 1, the fourth sets 6. The game shows no count;
# the assist gives it, the rooms left and the hiders' names. A found child keeps its event name on map 49.
module PokeAccess
  module AshenHideSeek
    MAPS = [47, 49, 50, 52, 53]
    STEP = 287
    KIDS = 4
    DONE = 6
    # Each hider: its map, its event and the key of its room.
    HIDERS = [[47, 23, :afe_room_table], [50, 24, :afe_room_library], [52, 11, :afe_room_albums], [53, 12, :afe_room_eloise]]

    # The game's step, 1 to 5 while the children hide.
    def self.step
      $game_variables[STEP].to_i
    end

    # Whether the game is on.
    def self.playing?
      step.between?(1, KIDS + 1)
    end

    # How many children are found.
    def self.found
      playing? ? step - 1 : (step >= DONE ? KIDS : 0)
    end

    # Whether a hider is found: it sets its own self switch A.
    def self.found?(hider)
      $game_self_switches[[hider[0], hider[1], "A"]] ? true : false
    end

    # The assist's hint: the rooms where children still hide.
    def self.hint
      left = HIDERS.reject { |h| found?(h) }.map { |h| PokeAccess::I18n.t(h[2]) }
      [:afe_hide_hint, { :list => left.join(", ") }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  seek = PokeAccess::AshenHideSeek
  seek::MAPS.each do |map|
    hider = seek::HIDERS.find { |h| h[0] == map }
    mechanic(:state, map, :part => :afe_hide_seek) do
      auto
      active { PokeAccess::Puzzles.assist? && seek.playing? }
      solved(nil, :quiet => true) { seek.step >= seek::DONE }
      name hider[1], :afe_hider, :assist => true if hider
      count :afe_hide_found, :value => lambda { seek.found }, :of => seek::KIDS, :assist => true, :reset => false
      phase lambda { seek.playing? }, :hint => lambda { seek.hint }
    end
  end
end
