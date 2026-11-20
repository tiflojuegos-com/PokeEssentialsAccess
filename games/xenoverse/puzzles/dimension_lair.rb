# The Team Dimension's lair: the laser barrier of map 369 (event 1) goes off with the switch at the far end of the duct the
# starter crawls through (map 378, event 17, switch 893). In the duct, Magnemite named for their sight ("Trainer(n)",
# events 1 to 3, 5 to 7 and 12) walk their rounds and send the starter back to map 369 once it stands in line within n
# tiles of where one faces, with nothing between; touch tiles with no sprite (events 9 to 11) do the same, and leave the
# map, so routes keep off them. Each Magnemite is named with the way it faces, as it is seen, and the free camera says
# the tiles in its sight; being a trap, the routes keep off those tiles with the assist alone.
module PokeAccess
  module XenoLair
    DUCT = 378
    MAGNEMITE = [1, 2, 3, 5, 6, 7, 12]
    SIGHT_RE = /Trainer\((\d+)\)/
    STEP = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    FACING = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # A Magnemite's name with the way it faces.
    def self.label(ev)
      [:xv_lair_magnemite, { :pokemon => species, :dir => PokeAccess::I18n.t(FACING[ev.direction] || :dir_down) }]
    end

    # Magnemite's name as the game's data gives it.
    def self.species
      PokeAccess::Data.species_name(:MAGNEMITE)
    end

    # True when (x, y) of the duct lies in a Magnemite's sight, read once a frame.
    def self.seen?(x, y)
      key = PokeAccess::Frame.serial
      @sight = nil unless @sight_at == key
      @sight_at = key
      (@sight ||= sight)[[x, y]] ? true : false
    end

    # The tiles every drawn Magnemite of the duct sees, as [x, y] => true.
    def self.sight
      out = {}
      ($game_map.events || {}).each_value do |ev|
        reach = ev.name.to_s[SIGHT_RE, 1].to_i
        step = STEP[ev.direction]
        next if reach <= 0 || step.nil? || ev.character_name.to_s.empty?
        x = ev.x
        y = ev.y
        reach.times do
          x += step[0]
          y += step[1]
          break unless ($game_map.passable?(x, y, 0) rescue true)
          out[[x, y]] = true
        end
      end
      out
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  lair = PokeAccess::XenoLair
  seen = lambda { |x, y| lair.seen?(x, y) }
  terrain_rule(:maps => [lair::DUCT], :tiles => seen, :assist => true) { |x, y, _d| lair.seen?(x, y) ? false : nil }
  camera_tile(:maps => [lair::DUCT], :tiles => seen, :assist => true) do |x, y|
    lair.seen?(x, y) ? PokeAccess::I18n.t(:xv_lair_in_sight, :pokemon => lair.species) : nil
  end

  mechanic(:state, lair::DUCT) do
    auto
    name lair::MAGNEMITE, lambda { |ev| lair.label(ev) }
  end
end
