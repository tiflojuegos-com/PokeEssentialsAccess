# Aquariopoli's Tide Gym, first trial (map 143): floor pads with Pokemon effigies, sixteen of them traps, touch tiles with
# no sprite (events 13 to 20 and 23 to 75, mostly in blocks of two by two) that drop the player to the floor below (map
# 144, 28,7) with no word. Four pillars (events 93, 94, 96 and 97) show a riddle written in the Unown alphabet, as a picture
# alone: walk on the grass, on the fire, on the water, and that luck is part of the game; a sighted player reads the
# letters, so each pillar says its riddle as it is read. A sighted player sees the pads but not which are traps, so they are
# listed with the assist alone; the routes keep off them either way, as they leave the map. The fourth badge (switch 227)
# ends it.
# Second trial (map 145): 5x5 floor blocks, each painted with an Unown letter (the A at the start to the Z, and two blank
# ones by the way out), hold teleport pads ('teleportblue') to other blocks; going through the letters in order leads to the
# way out. Each pad and tile is named with its block's letter, and a teleport says the letter reached; with the assist, a pad
# says the letter it leads to.
# Third trial (maps 148 and 149): twelve Alolan Exeggutor drawn in the map (events 4 to 15, no sprite); three of them (13, 14
# and 15) show a secret passage to a crypt of map 149, each with three sarcophagi, one holding a pearl. The three shells of
# the corridor to the leader (events 1 to 3) each vanish with their pearl, and do nothing without it. With the assist, the
# friendly Exeggutor and the shells say their pearl, and the pearl's sarcophagus is told apart.
module PokeAccess
  module XenoTideGym
    MAP = 143
    BELOW = 144
    TRAPS = [13..20, 23..75]
    RIDDLES = { 93 => :xv_tide_riddle_grass, 94 => :xv_tide_riddle_fire, 96 => :xv_tide_riddle_water,
                97 => :xv_tide_riddle_luck }
    LANDING = [28, 7]
    BADGE = 227

    LETTERS = 145
    BLOCKS = { [4, 11] => "A", [29, 26] => "B", [34, 11] => "C", [14, 31] => "D", [39, 26] => "E", [19, 16] => "F",
               [29, 36] => "G", [14, 21] => "H", [9, 36] => "I", [19, 26] => "J", [24, 11] => "K", [24, 31] => "L",
               [4, 31] => "M", [29, 16] => "N", [14, 11] => "O", [34, 31] => "P", [4, 21] => "Q", [9, 16] => "R",
               [34, 21] => "S", [39, 16] => "T", [9, 26] => "U", [19, 36] => "V", [44, 11] => "W", [44, 31] => "X",
               [44, 21] => "Y", [39, 36] => "Z" }
    WAY_OUT = [[24, 21], [24, 41]]
    PAD = /\Ateleportblue\z/

    PALMS_MAP = 148
    CRYPTS = 149
    PALMS = (4..15).to_a
    FRIENDLY = { 13 => :PERLACQUA, 14 => :PERLACQUA2, 15 => :PERLACQUA3 }
    SHELLS = { 1 => :PERLACQUA3, 2 => :PERLACQUA, 3 => :PERLACQUA2 }
    PEARLS = [5, 14, 27]
    CLOSED = "cofagrigus"

    # The centre of the 5x5 block of map 145 that holds (x, y), or nil.
    def self.block_at(x, y)
      return nil if x < 2 || y < 9
      [((x - 2) / 5) * 5 + 4, ((y + 1) / 5) * 5 + 1]
    end

    # The Unown letter painted on the block that holds (x, y), or nil off the letters.
    def self.letter_at(x, y)
      c = block_at(x, y)
      c ? BLOCKS[c] : nil
    end

    # The tile a page of the pad sends the player to on map 145, as [x, y], or nil.
    def self.destination(ev)
      list = PokeAccess.ivar(ev, :@list) || []
      cmd = list.find { |c| (c.code rescue 0) == 201 && c.parameters[0] == 0 && c.parameters[1] == LETTERS }
      cmd ? [cmd.parameters[2], cmd.parameters[3]] : nil
    end

    # What the pad's destination is with the assist: a letter's key and value, or the way out.
    def self.goes_to(ev)
      to = destination(ev)
      return nil unless to
      return [:xv_unown_to_exit, {}] if WAY_OUT.include?(block_at(to[0], to[1]))
      letter = letter_at(to[0], to[1])
      letter ? [:xv_unown_to_letter, { :letter => letter }] : nil
    end

    # A pad's name: the letter it stands on, and with the assist where it leads; nil while the event is no pad.
    def self.pad_label(ev)
      return nil unless ev.character_name.to_s =~ PAD
      here = letter_at(ev.x, ev.y)
      base = here ? PokeAccess::I18n.t(:xv_unown_pad, :letter => here) : PokeAccess::I18n.t(:xv_unown_pad_blank)
      to = PokeAccess::Puzzles.assist? ? goes_to(ev) : nil
      return base unless to
      PokeAccess::I18n.t(:xv_unown_pad_leads, :pad => base, :to => PokeAccess::I18n.t(to[0], to[1]))
    end

    # The line said as a teleport of map 145 lands on a letter, or nil.
    def self.arrival(to)
      return nil unless to[2] == LETTERS
      letter = letter_at(to[0], to[1])
      letter ? PokeAccess::I18n.t(:xv_unown_letter, :letter => letter) : nil
    end

    # A crypt sarcophagus's name: open as it shows, or closed, the pearl's told apart with the assist.
    def self.sarcophagus_label(ev)
      return :xv_tide_sarcophagus_open unless ev.character_name.to_s == CLOSED
      PokeAccess::Puzzles.assist? && PEARLS.include?(ev.id) ? :xv_tide_sarcophagus_pearl : :xv_tide_sarcophagus
    end

    # A palm's name, with the assist the pearl of the crypt a friendly one leads to.
    def self.palm_label(ev)
      pokemon = PokeAccess::Data.species_name(:EXEGGUTOR)
      pearl = PokeAccess::Puzzles.assist? ? FRIENDLY[ev.id] : nil
      return pokemon unless pearl
      [:xv_tide_palm_friendly, { :pokemon => pokemon, :item => PokeAccess::Data.item_name(pearl) }]
    end

    # A shell's name; with the assist, the pearl it takes.
    def self.shell_label(ev)
      return :xv_tide_shell unless PokeAccess::Puzzles.assist?
      [:xv_tide_shell_takes, { :item => PokeAccess::Data.item_name(SHELLS[ev.id]) }]
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  tide = PokeAccess::XenoTideGym
  mechanic(:state, tide::MAP) do
    auto
    name tide::RIDDLES.keys, :xv_tide_pillar
    tide::RIDDLES.each { |id, riddle| on_use id, riddle }
    hide tide::TRAPS, :when => lambda { |_ev| !PokeAccess::Puzzles.assist? }
    name tide::TRAPS, :xv_tide_trap, :grouped => true, :assist => true
    solved { $game_switches[tide::BADGE] }
  end

  mechanic(:state, tide::BELOW) do
    auto
    sent_back :xv_tide_fell, :maps => [tide::MAP], :to => tide::LANDING
  end

  mechanic(:state, tide::LETTERS) do
    auto
    name tide::PAD, lambda { |ev| tide.pad_label(ev) }
    solved { $game_switches[tide::BADGE] }
  end
  letters = { :maps => [tide::LETTERS], :tiles => lambda { |x, y| !tide.letter_at(x, y).nil? } }
  camera_tile(letters) { |x, y| PokeAccess::I18n.t(:xv_unown_letter, :letter => tide.letter_at(x, y)) }
  PokeAccess::Locator.teleport_cause(:xv_unown_letters) { |_from, to| tide.arrival(to) }

  mechanic(:state, tide::PALMS_MAP) do
    auto
    name tide::PALMS, lambda { |ev| tide.palm_label(ev) }
    name tide::SHELLS.keys, lambda { |ev| tide.shell_label(ev) }
    solved { $game_switches[tide::BADGE] }
  end

  mechanic(:state, tide::CRYPTS) do
    auto
    name(/cofagrigus|sarcofago/, lambda { |ev| tide.sarcophagus_label(ev) },
         :when => lambda { |ev| ev.character_name.to_s == tide::CLOSED })
  end
end
