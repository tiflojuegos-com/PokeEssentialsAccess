# The crystals of Silver Rise (maps 30 to 40): seven crystals with no sprite, each touched once, form a bridge of crystal in
# another room ("You hear crystals form in the distance"), switches 299 to 305. The way out is the bridge of switch 299,
# on the peak (map 31), formed by the crystal at the north end of map 38; map 38 is crossed by the bridges of switches 303
# and 304, formed by two crystals of the peak (checked against the floor of map 38 with each bridge laid). The other four
# bridges lead off the way. The ice of maps 31 and 37 the core routes by itself. In Silver Forest (map 26), four more
# crystals with no sprite (switches 307 to 310) move crystals elsewhere on the map, which the core says as they open.
module PokeAccess
  module DesolationSilverRise
    # Crystal: [map, event, switch].
    CRYSTALS = [[31, 37, 303], [31, 110, 304], [38, 2, 299], [36, 34, 300], [39, 2, 301], [31, 107, 302], [40, 34, 305]]
    # The switches of the two crystals of the peak, touched in any order, and of the one at the end of map 38.
    PEAK = [303, 304]
    WAY_OUT = 299
    # Each bridge's switch, map and the middle of its pieces.
    BRIDGES = { 299 => [31, 51, 25], 300 => [30, 26, 14], 301 => [31, 104, 44], 302 => [36, 18, 17], 303 => [38, 15, 36],
                304 => [38, 14, 24], 305 => [39, 48, 20] }

    # The switches of the needed crystals that can be touched now: those of the peak still to touch, else the way
    # out's until it is formed.
    def self.pending
      left = PEAK.reject { |s| $game_switches[s] }
      return left unless left.empty?
      $game_switches[WAY_OUT] ? [] : [WAY_OUT]
    end

    # The way out from what is formed, with the assist.
    def self.hint
      return :deso_silver_hint_peak unless PEAK.all? { |s| $game_switches[s] }
      $game_switches[WAY_OUT] ? nil : :deso_silver_hint_room
    end

    # A crystal's label: needed and touchable now, with the assist; else a plain crystal.
    def self.label(switch)
      PokeAccess::Puzzles.assist? && pending.include?(switch) ? :deso_silver_crystal_next : :deso_silver_crystal
    end
  end
end

PokeAccess::Game.define("desolation") do
  rise = PokeAccess::DesolationSilverRise
  mechanic(:state, 26) do
    auto
    name [10, 12, 19, 32], :deso_silver_crystal
  end
  [30, 31, 36, 38, 39, 40].each do |map|
    mechanic(:state, map) do
      auto
      rise::CRYSTALS.each do |m, ev, s|
        next unless m == map
        name ev, lambda { |_e| rise.label(s) }, :when => lambda { |_e| !$game_switches[s] }
        on_reach ev, { :text => /crystals form/i }, :deso_silver_bridge_formed, :assist => true
      end
      rise::BRIDGES.each do |s, (m, x, y)|
        spot(:at => [x, y], :label => :deso_silver_bridge, :when => lambda { $game_switches[s] }) if m == map
      end
      hint lambda { rise.hint }
      solved { $game_switches[299] }
    end
  end
end
