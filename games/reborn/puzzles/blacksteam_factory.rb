# Blacksteam Factory B1F (map 11): the cell bars (events 2 and 3) melt in three attacks from the middle cage (event 15,
# variable 110): Cyndaquil heats them (variable 107 to 11), Vanillite cools (12), Roggenrola breaks (13), each while the
# guard sleeps (switch 167). Variables 108 to 115 hold each cage's Pokémon (see SPECIES); Abra (event 7) teleports.
module PokeAccess
  module RebornBlacksteam
    CAGES = { 108 => 13, 109 => 8, 110 => 15, 111 => 12, 112 => 10, 113 => 14, 114 => 9, 115 => 11 }
    MIDDLE = 110
    SPECIES = { 1 => :rba_bf_vanillite, 2 => :rba_bf_lickitung, 3 => :rba_bf_roggenrola, 4 => :rba_bf_makuhita,
                5 => :rba_bf_loudred, 6 => :rba_bf_jigglypuff, 7 => :rba_bf_cyndaquil }
    LOUDRED = 5
    JIGGLYPUFF = 6
    NEEDED = { 11 => 1, 12 => 3 }
    CYNDAQUIL = 7
    BARS = [2, 3]

    # The bars' stage, variable 107: 11 hot, 12 cold, 13 broken.
    def self.stage; $game_variables[107].to_i; end

    # What a cage holds, by its variable.
    def self.content(var); $game_variables[var].to_i; end

    # The Pokémon the middle cage needs for the next attack; nil once the bars are broken.
    def self.needed
      return nil if stage >= 13
      NEEDED[stage] || CYNDAQUIL
    end

    # A cage's name, by what it holds.
    def self.cage_label(ev)
      var = CAGES.keys.find { |v| CAGES[v] == ev.id }
      c = content(var)
      return :rba_bf_cage_empty if c == 0
      SPECIES[c] ? [:rba_bf_cage, { :name => PokeAccess::I18n.t(SPECIES[c]) }] : :rba_bf_cage_plain
    end

    # The bars' name, by how the attacks left them.
    def self.bars_label(_ev)
      { 11 => :rba_bf_bars_hot, 12 => :rba_bf_bars_cold }[stage] || :rba_bf_bars
    end

    # With the assist, the next thing to do. Loudred's cry wakes Abra and the guard (switch 168), Jigglypuff's song
    # sleeps them; Abra teleports only awake (164) and linked (165), and a teleport ends the link.
    def self.hint
      want = needed
      return nil unless want
      if content(MIDDLE) == want
        return :rba_bf_hint_release if $game_switches[165]
        return :rba_bf_hint_attack if $game_switches[167]
        return go(JIGGLYPUFF) if $game_switches[168]
        return go(LOUDRED)
      end
      if $game_switches[165]
        return go(want) if content(MIDDLE) == 0
        return :rba_bf_hint_take_out
      end
      return :rba_bf_hint_abra if $game_switches[164]
      go(LOUDRED)
    end

    # The line that sends the player to the cage holding c.
    def self.go(c)
      [:rba_bf_hint_go, { :name => PokeAccess::I18n.t(SPECIES[c]) }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  cells = PokeAccess::RebornBlacksteam
  mechanic(:state, 11) do
    auto
    name cells::CAGES.values, lambda { |ev| cells.cage_label(ev) }
    name cells::BARS, lambda { |ev| cells.bars_label(ev) }, :grouped => true
    hint lambda { cells.hint }
    active { cells.stage < 13 }
    solved { cells.stage >= 13 }
  end
end
