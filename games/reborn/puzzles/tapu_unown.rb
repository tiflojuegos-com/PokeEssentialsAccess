# Tabula Rasa (map 855), the Tapus' quest: each door of Victory Road B5F sets variable 621 to its stage (1 Ruby, 2
# Amethyst, 3 Emerald, 4 Sapphire). The Unown at (29, 26) fights as a letter of ELECTRICGRASSYMISTYPSYCHIC (variable
# 779), so a stage's letters spell its terrain; a battle ending on it opens the Tapu (switches 1666 to 1669).
module PokeAccess
  module RebornTapus
    MAP = 855
    UNOWN = 12
    STAGE = 621
    LETTER = 779
    LETTERS = "ELECTRICGRASSYMISTYPSYCHIC"
    TERRAINS = { 1 => :rbi_tapu_electric, 2 => :rbi_tapu_psychic, 3 => :rbi_tapu_grassy, 4 => :rbi_tapu_misty }
    DONE = { 1 => 1666, 2 => 1667, 3 => 1668, 4 => 1669 }

    # The stage the player came in by, or nil outside the quest.
    def self.stage
      s = $game_variables[STAGE].to_i
      TERRAINS.key?(s) ? s : nil
    end

    # The letter the Unown fights as now.
    def self.letter
      LETTERS[$game_variables[LETTER].to_i % LETTERS.length, 1]
    end

    # True when the stage's terrain has already been made.
    def self.stage_done?
      s = stage
      s ? ($game_switches[DONE[s]] ? true : false) : true
    end

    # With the assist, the terrain the battle must end with.
    def self.hint
      return nil if stage_done?
      [:rbi_tapu_hint, { :terrain => PokeAccess::I18n.t(TERRAINS[stage]) }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  tapu = PokeAccess::RebornTapus
  mechanic(:state, tapu::MAP, :part => :unown) do
    auto
    name tapu::UNOWN, :rbi_tapu_unown
    on_use tapu::UNOWN, lambda { |_ev| [:rbi_tapu_letter, { :letter => tapu.letter }] }
    hint lambda { tapu.hint }
    info { nil }
    active { PokeAccess::Puzzles.assist? && !tapu.stage_done? }
  end
end
