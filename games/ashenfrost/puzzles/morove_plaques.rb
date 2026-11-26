# Morove's inscriptions (Case Seventeen, variable 257 at 2): with Cobalt's key (variable 260 from 1, Map685 EV23) each
# one read adds 1 to 260 once (self switch A); at 6 the game sets 7 and counts the task in 259. The camp's two tablets
# (Map684 EV27 and EV28) mark each other. Listed without the assist, which adds how many are left, and where.
module PokeAccess
  module AshenPlaques
    DAY = 257
    KEY = 260
    DONE = 7
    # Each inscription: its map and the events that read it, marking each other.
    PLAQUES = [[684, [27, 28]], [686, [65]], [686, [68]], [687, [4]], [688, [35]]]

    # Whether the inscriptions are the task of the day.
    def self.open?
      $game_variables[DAY].to_i == 2 && $game_variables[KEY].to_i < DONE
    end

    # Whether an inscription has been read since the key: its events' self switch A.
    def self.read?(plaque)
      plaque[1].any? { |id| $game_self_switches[[plaque[0], id, "A"]] }
    end

    # How many have been read, as the game counts them.
    def self.translated
      v = $game_variables[KEY].to_i
      return PLAQUES.length if v >= DONE
      [[v - 1, 0].max, PLAQUES.length].min
    end

    # The events of a map that are inscriptions.
    def self.ids_on(map)
      PLAQUES.select { |p| p[0] == map }.map { |p| p[1] }.flatten
    end

    # Whether an event of this map is an inscription still to read on the day they are asked for.
    def self.unread?(ev)
      plaque = PLAQUES.find { |p| p[0] == $game_map.map_id && p[1].include?(ev.id) }
      plaque && open? && !read?(plaque) ? true : false
    end

    # The assist's line: the key first, then the maps the inscriptions left stand on.
    def self.hint
      return nil unless open?
      return [:afd_plaques_key, { :temple => map_name(686) }] if $game_variables[KEY].to_i < 1
      left = PLAQUES.reject { |p| read?(p) }
      [:afd_plaques_left, { :n => left.length, :places => left.map { |p| map_name(p[0]) }.uniq.join(", ") }]
    end

    # A map's name as the game gives it.
    def self.map_name(map)
      (PokeAccess::Locator.map_name(map) rescue nil).to_s
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  plaques = PokeAccess::AshenPlaques
  plaques::PLAQUES.map { |p| p[0] }.uniq.each do |map|
    mechanic(:state, map, :part => :afd_plaques) do
      auto
      name plaques.ids_on(map), :afd_plaque, :when => lambda { |ev| plaques.unread?(ev) }
      count :afd_plaques_count, :value => lambda { plaques.translated }, :of => plaques::PLAQUES.length, :assist => true,
                                :hide_zero => true
      hint lambda { plaques.hint }
      active { plaques.open? }
    end
  end
end
