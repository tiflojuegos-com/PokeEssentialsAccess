# The Subseven Sanctum. The escape (map 330), switch 432 on and 528 off: fifteen orderlies (events 15 to 29) watch
# straight ahead and a sighting sends the player back to the cell; six waits, each opened by a guard turning or passing,
# get past them. The scripture: four Arceus statues ask four digits from the books of the cell and library.
module PokeAccess
  module RebornSanctum
    WAITS = [[46, 19, :rbb_s7_wait1], [33, 9, :rbb_s7_wait2], [28, 17, :rbb_s7_wait3], [3, 27, :rbb_s7_wait4],
             [9, 16, :rbb_s7_wait5], [8, 8, :rbb_s7_wait6]]
    BOOKS = { 4 => :rbb_s7_book_purple, 5 => :rbb_s7_book_blue, 6 => :rbb_s7_book_green }
    ARCS = [[428, 21, :rbb_s7_statue_red, :rbb_s7_arc_red], [429, 22, :rbb_s7_statue_blue, :rbb_s7_arc_blue],
            [431, 23, :rbb_s7_statue_green, :rbb_s7_arc_green], [430, 24, :rbb_s7_statue_purple, :rbb_s7_arc_purple]]

    def self.escape?
      $game_switches[432] && !$game_switches[528]
    end

    def self.facing(id)
      ev = $game_map.events[id]
      ev ? ev.direction : 0
    end

    # True while the guard of each wait looks or walks away, in the order of WAITS.
    def self.clear?(i)
      p = $game_map.events[25]
      case i
      when 0 then facing(17) == 8
      when 1 then !p.nil? && p.x == 32 && p.y <= 14 && p.direction == 2
      when 2 then !p.nil? && p.x >= 29 && (p.direction == 6 || p.direction == 8)
      when 3 then facing(28) == 8
      when 4 then facing(29) == 8
      else facing(29) == 2
      end
    end

    # A guard's name with the way it faces, during the escape alone.
    def self.guard(ev)
      escape? ? [:rbb_s7_guard, { :dir => PokeAccess::Puzzles.face_name(ev.direction) }] : nil
    end

    def self.story
      $game_variables[159].to_i
    end
  end
end

PokeAccess::Game.define("reborn") do
  s7 = PokeAccess::RebornSanctum
  watchers(330)
  mechanic(:state, 330, :part => :escape) do
    auto
    name 15..29, lambda { |ev| s7.guard(ev) }, :when => lambda { |_ev| s7.escape? }
    arrival_hint lambda { s7.escape? ? :rbb_s7_stealth_rule : nil }, :once => true
    hint :rbb_s7_stealth_hint
    s7::WAITS.each_with_index do |w, i|
      spot :at => [w[0], w[1]], :label => w[2], :assist => true, :onto => true, :when => lambda { s7.escape? }
      box = at(w[0], w[0], w[1], w[1])
      phase lambda { s7.escape? && box.call && s7.clear?(i) }, :hint => :rbb_s7_now
    end
    active { s7.escape? }
    solved(nil, :quiet => true) { $game_switches[528] }
  end
  mechanic(:state, 331, :part => :cell) do
    auto
    sent_back :rbb_s7_caught, :maps => [330], :to => [16, 6]
    name 9, lambda { |_ev| PokeAccess::Puzzles.assist? ? :rbb_s7_book_red : :rbb_s7_book }
  end
  mechanic(:state, 332, :part => :library) do
    auto
    name 4..9, lambda { |ev| (PokeAccess::Puzzles.assist? && s7::BOOKS[ev.id]) || :rbb_s7_book }
  end
  mechanic(:state, 329, :part => :scripture) do
    auto
    s7::ARCS.each do |sw, id, statue, arc|
      name id, statue
      watch :switch => sw, :label => arc, :say => arc
    end
    name 25..32, :rbb_s7_seal, :grouped => true, :when => lambda { |_ev| s7.story < 16 }
    count :rbb_s7_arcs, :switches => [428, 429, 431, 430], :announce => false
    arrival_hint lambda { s7.story >= 14 && s7.story < 16 ? :rbb_s7_scripture_rule : nil }
    hint :rbb_s7_scripture_hint
    active { s7.story >= 14 && s7.story < 16 }
    solved(nil, :quiet => true) { s7.story >= 16 }
  end
end
