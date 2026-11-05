# Jungla Simfo's maze (maps 129 to 138): the Kiwono's song in its first map as the scene sings it and each time they are asked to, and in
# each room the flowers before each exit; with the assist, the room's note and the exit with the flowers of its colour, which is the one
# that goes on. Every wrong exit lands on (19, 12) of the first map.
module PokeAccess
  module ArmoniaJungle
    FIRST = 130
    SONG_MAP = 129
    SCENE = 13
    SONG_TEXT = 4
    BLUE = :arm_simfo_c_blue
    PINK = :arm_simfo_c_pink
    YELLOW = :arm_simfo_c_yellow
    WHITE = :arm_simfo_c_white
    VOICES = { 1 => [:arm_simfo_v_re, BLUE], 2 => [:arm_simfo_v_la, YELLOW], 3 => [:arm_simfo_v_do, PINK], 4 => [:arm_simfo_v_fa, WHITE] }
    SONG = [1, 3, 2, 4, 1, 1, 3, 2, 3]
    SIDES = [:arm_simfo_at_north, :arm_simfo_at_east, :arm_simfo_at_south, :arm_simfo_at_west]
    EXITS = /\A(tp|pepe|morgan)/
    # Each room: its flowers in the order of SIDES, the event that stands for the way on in the puzzles list, the exits that send back.
    ROOMS = {
      130 => [[PINK, BLUE, YELLOW, WHITE], 4, [2, 3, 5..16]],
      131 => [[PINK, WHITE, BLUE, YELLOW], 1, [3..15]],
      132 => [[WHITE, YELLOW, PINK, BLUE], 1, [4..12]],
      133 => [[YELLOW, WHITE, BLUE, PINK], 1, [3..16]],
      134 => [[BLUE, PINK, WHITE, YELLOW], 1, [3..15]],
      135 => [[PINK, WHITE, YELLOW, BLUE], 1, [3..16]],
      136 => [[YELLOW, BLUE, PINK, WHITE], 14, [4..12]],
      137 => [[WHITE, YELLOW, PINK, BLUE], 1, [3..16]],
      138 => [[PINK, BLUE, WHITE, YELLOW], 1, [3..15]]
    }

    # Whether Thorn's scene, which every way to the Kiwono crosses and which shows the song first, is over.
    def self.sung?
      $game_self_switches[[SONG_MAP, SCENE, "A"]]
    end

    # The song as a line: each note with its Kiwono's colour, in order.
    def self.song
      voices = SONG.map { |ev| PokeAccess::I18n.t(VOICES[ev][0]) }
      PokeAccess::I18n.t(:arm_simfo_song, :notes => voices.join(", "))
    end

    # What the room shows: the colour of the flowers on each side.
    def self.flowers
      row = ROOMS[$game_map.map_id][0]
      parts = (0...SIDES.length).map { |i| "#{PokeAccess::I18n.t(row[i])} #{PokeAccess::I18n.t(SIDES[i])}" }
      [:arm_simfo_flowers, { :list => parts.join(", ") }]
    end

    # The side of the room an exit lies on, as an index into SIDES.
    def self.side_of(ev)
      return 0 if ev.y <= 3
      return 2 if ev.y >= 27
      ev.x >= 27 ? 1 : 3
    end

    # The note of the room the player is in, as [its voice, its colour].
    def self.note; VOICES[SONG[$game_map.map_id - FIRST]]; end

    # An exit's name, by the flowers before it; with the assist, the one that goes on says so.
    def self.exit_name(ev)
      colour = ROOMS[$game_map.map_id][0][side_of(ev)]
      key = PokeAccess::Puzzles.assist? && colour == note[1] ? :arm_simfo_right_exit : :arm_simfo_exit
      [key, { :c => PokeAccess::I18n.t(colour) }]
    end

    # The hint of the room the player is in: its place in the maze, its note and the way on.
    def self.hint
      map = $game_map.map_id
      voice, colour = note
      side = ROOMS[map][0].index(colour)
      [:arm_simfo_hint, { :n => map - FIRST + 1, :note => PokeAccess::I18n.t(voice), :c => PokeAccess::I18n.t(colour),
                          :at => PokeAccess::I18n.t(SIDES[side]) }]
    end
  end
end

PokeAccess::Game.define("armonia") do
  jungle = PokeAccess::ArmoniaJungle

  mechanic(:state, 129) do
    auto
    [[1, :arm_simfo_blue], [2, :arm_simfo_yellow], [3, :arm_simfo_pink], [4, :arm_simfo_white]].each do |ev, key|
      name ev, lambda { |_ev| jungle.sung? ? key : :arm_simfo_kiwono }
    end
    info { jungle.song }
    hint :arm_simfo_key
    active { jungle.sung? }
    watch :self => [jungle::SCENE, "A"], :say => :arm_simfo_rule
    on_reach jungle::SCENE, { :text => jungle::SONG_TEXT }, lambda { jungle.song }
    on_reach 1..4, { :choice => 0 }, lambda { jungle.song }
    sent_back :arm_simfo_wrong, :to => [19, 12], :maps => jungle::ROOMS.keys
    arrival_hint lambda { jungle.sung? ? :arm_simfo_rule : :arm_simfo_start }
  end

  jungle::ROOMS.each do |map, room|
    mechanic(:state, map) do
      auto
      hide room[2], :assist => true
      name jungle::EXITS, lambda { |ev| jungle.exit_name(ev) },
           :when => lambda { |ev| PokeAccess::Puzzles.assist? && ev.id == room[1] }
      phase lambda { true }, :title => lambda { jungle.flowers }, :entry_title => true, :hint => lambda { jungle.hint }
      arrival_hint :arm_simfo_room, :once => true
    end
  end
end
