# The Mansion of memory (maps 55 to 59): the ghosts driven out of the library drop notes that spell the drawer's word, and the
# drawer brings on the fight with Alter, whose defeat opens the portal to the Heart of Chaos.
module PokeAccess
  module EdasMansion
    MAPS = [55, 56, 57, 58, 59]
    LIBRARY = 59
    STARTED = 301
    SCARED = 218
    OPENED = 95
    DEFEATED = 97
    WORD = "SARA"
    DRAWER = 12
    WARDROBE = [57, 13]
    ALTER = [8, 12]
    GHOSTS = [[57, 13, :edas_mansion_where_wardrobe], [58, 7, :edas_mansion_where_dining],
              [56, 3, :edas_mansion_where_lampent], [56, 5, :edas_mansion_where_banette]]
    NAMES = { 56 => [[[3, 5], :edas_mansion_ghost]], 58 => [[7, :edas_mansion_ghost]],
              59 => [[[30, 31, 32, 35], :edas_mansion_ghost]] }
    PEOPLE = [[19, :edas_mansion_alter], [21, :edas_mansion_sara], [22, :edas_mansion_cosette], [23, :edas_mansion_shean]]

    # Whether a switch is on.
    def self.on?(id)
      $game_switches[id] ? true : false
    end

    # The ghosts that have not dropped their note: the self switch A of their event is still off.
    def self.missing
      GHOSTS.reject { |map, event, _where| $game_self_switches[[map, event, "A"]] }
    end

    # How many ghosts have dropped their note.
    def self.found
      GHOSTS.length - missing.length
    end

    # Whether the ghosts are out of the library and the drawer is still shut.
    def self.hunting?
      on?(SCARED) && !on?(OPENED)
    end

    # Whether the wardrobe of the corridors still holds its ghost.
    def self.in_wardrobe?
      on?(SCARED) && !$game_self_switches[[WARDROBE[0], WARDROBE[1], "A"]]
    end

    # Whether the fight with Alter is still to come.
    def self.fight_ahead?
      on?(OPENED) && !on?(DEFEATED)
    end

    # The ghosts found so far, said as a count.
    def self.progress
      PokeAccess::I18n.t(:puzzle_progress, :label => PokeAccess::I18n.t(:edas_mansion_ghosts), :n => found, :of => GHOSTS.length)
    end

    # Where the ghosts still to find are, or, with all of them found, the word their notes spell.
    def self.hunt_hint
      places = missing.map { |_map, _event, where| PokeAccess::I18n.t(where) }
      return :edas_mansion_hint_word if places.empty?
      PokeAccess.sentences([PokeAccess::I18n.t(:edas_mansion_left), PokeAccess::Routes::Text.and_list(places)])
    end
  end
end

PokeAccess::Game.define("edas") do
  mansion = PokeAccess::EdasMansion
  mansion::MAPS.each do |map|
    mechanic(:state, map) do
      (mansion::NAMES[map] || []).each { |ids, label| name ids, label }
      solved(nil) { mansion.on?(mansion::DEFEATED) }
      phase lambda { mansion.on?(mansion::OPENED) }, :hint => :edas_mansion_hint_alter
      (0..mansion::GHOSTS.length).each do |n|
        title = n == 0 ? :edas_mansion_fled : lambda { mansion.progress }
        phase lambda { mansion.hunting? && mansion.found == n }, :title => title, :hint => lambda { mansion.hunt_hint }
      end
      phase lambda { mansion.on?(mansion::STARTED) }, :hint => :edas_mansion_hint_start
      if map == mansion::LIBRARY
        name mansion::DRAWER, :edas_mansion_drawer, :when => lambda { |_ev| !mansion.on?(mansion::DEFEATED) }
        mansion::PEOPLE.each { |id, label| name id, label, :when => false }
        answer mansion::DRAWER, mansion::WORD
        spot :at => mansion::ALTER, :label => :edas_mansion_alter_spot, :assist => true,
             :when => lambda { mansion.fight_ahead? }
      end
      if map == mansion::WARDROBE[0]
        spot :event => mansion::WARDROBE[1], :label => :edas_mansion_wardrobe_spot, :assist => true,
             :when => lambda { mansion.in_wardrobe? }
      end
    end
  end
end
