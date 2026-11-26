# Route 1 (maps 290, 286, 285, 287 and 291, joined west to east): Tauros and Bouffalant stand in pairs and a pair serves
# once. Beating the Tauros sends the Bouffalant ramming the pair's log aside for good; beating the Bouffalant lets the
# player ride the Tauros. LOGS gives each Tauros its log's switch and map, FREE_PAIRS have no log, SPARE open nothing.
# A rider gets out to the woods from every pair but those of 290, shut in until the log of 286's EV55 (WEST) is aside.
module PokeAccess
  module RebornRouteBulls
    LOG_PAIRS = { 285 => [[12, 11], [62, 61], [63, 60]], 286 => [[49, 48], [52, 50], [53, 51], [55, 54]],
                  287 => [[26, 25], [28, 27]], 290 => [[82, 83]] }
    LOGS = { [285, 12] => [294, 285], [285, 62] => [300, 282], [285, 63] => [302, 289], [286, 49] => [309, 288],
             [286, 52] => [310, 283], [286, 53] => [312, 283], [286, 55] => [314, 286], [287, 26] => [305, 284],
             [287, 28] => [307, 289], [290, 82] => [316, 290] }
    FREE_PAIRS = { 285 => [[65, 66, 322]], 286 => [[65, 64, 321]], 287 => [[24, 23, 303]],
                   290 => [[93, 92, 318], [95, 94, 319], [97, 96, 320]], 291 => [[23, 24, 323]] }
    SPARE = { 285 => [[10, 17, 295]], 286 => [[76, 26, 308], [12, 26, 313]], 290 => [[36, 52, 317]] }
    WEST = [314, 315, 2, 15]

    # A pair's Tauros with what beating it moves: a log here or in the wood it names; nil once that log is aside.
    def self.tauros_label(ev)
      sw, map = LOGS[[$game_map.map_id, ev.id]]
      return nil if sw.nil? || $game_switches[sw]
      return :rba_r1_log_tauros if map == $game_map.map_id
      [:rbre_r1_log_tauros_far, { :place => PokeAccess::Locator.map_name(map) }]
    end

    # True while a rider from map's pairs gets out to the woods: 290's only once WEST's log is aside.
    def self.out?(map)
      map != 290 || $game_switches[WEST[0]] ? true : false
    end

    # The pairs without a log still standing whose rider gets out to the woods.
    def self.free_left
      FREE_PAIRS.inject(0) do |sum, (map, pairs)|
        next sum unless out?(map)
        sum + pairs.count { |_t, _b, sw| !$game_switches[sw] }
      end
    end

    # The free pairs of 290 that ramming WEST's log lets out; none once it is aside or its pair was ridden.
    def self.free_behind_west
      return 0 if $game_switches[WEST[0]] || $game_switches[WEST[1]]
      FREE_PAIRS[290].count { |_t, _b, sw| !$game_switches[sw] }
    end

    # With the assist, the rule and the rides the woods still ask for against the free pairs left. When those fall
    # short: first the ram that lets 290's out, and only past that the pairs of this stretch whose log opens nothing.
    def self.hint
      need = PokeAccess::RebornAventurineBugs.rides_left
      left = free_left
      more = free_behind_west
      lines = [PokeAccess::I18n.t(:rba_r1_hint), PokeAccess::I18n.t(:rbrj4_r1_rides, :need => need, :left => left)]
      if need > left && more > 0
        lines << PokeAccess::I18n.t(:rbrj4_r1_west_log, :x => WEST[2], :y => WEST[3], :more => more)
      end
      map = $game_map.map_id
      spare = (SPARE[map] || []).reject { |_x, _y, sw| $game_switches[sw] || !out?(map) }
      if need > left + more && !spare.empty?
        lines << PokeAccess::I18n.t(:rbrj4_r1_spare, :list => spare.map { |x, y, _sw| "#{x}, #{y}" }.join("; "))
      end
      PokeAccess.sentences(lines)
    end
  end
end

PokeAccess::Game.define("reborn") do
  bulls = PokeAccess::RebornRouteBulls
  (bulls::LOG_PAIRS.keys | bulls::FREE_PAIRS.keys).each do |map|
    pairs = bulls::LOG_PAIRS[map] || []
    free = bulls::FREE_PAIRS[map] || []
    mechanic(:state, map) do
      auto
      unless pairs.empty?
        name pairs.map { |tauros, _b| tauros }, lambda { |ev| bulls.tauros_label(ev) }, :assist => true
        name pairs.map { |_t, bouffalant| bouffalant }, :rba_r1_log_bouffalant, :assist => true
      end
      unless free.empty?
        name free.map { |tauros, _b, _sw| tauros }, :rbrj4_r1_free_tauros, :assist => true
        name free.map { |_t, bouffalant, _sw| bouffalant }, :rbrj4_r1_free_bouffalant, :assist => true
      end
      hint lambda { bulls.hint }
    end
  end
end
