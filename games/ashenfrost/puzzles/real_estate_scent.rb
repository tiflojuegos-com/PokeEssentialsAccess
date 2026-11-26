# The Real Estate Office (map 212, Case Four) as Truffles (switch 71): four smells sparkle on the landlady's office
# floor, each named by its colour (HiddenItem_Smell_*). The red one, the cup (EV11), gives the evidence Sylvester (EV9)
# waits for.
module PokeAccess
  module AshenRealEstate
    MAP = 212
    TRUFFLES = 71
    CUP = 11
    COLOURS = { /Smell_Green/ => :afh_scent_green, /Smell_Yellow/ => :afh_scent_yellow, /Smell_Red/ => :afh_scent_red }

    # A smell's name by the colour its sparkle wears, while Truffles plays; nil otherwise.
    def self.label(ev)
      return nil unless $game_switches[TRUFFLES]
      graphic = (ev.character_name rescue "").to_s
      COLOURS.each { |pattern, key| return key if graphic =~ pattern }
      nil
    end

    # Whether the cup is still to smell.
    def self.cup_left?
      $game_switches[TRUFFLES] && !$game_self_switches[[MAP, CUP, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  office = PokeAccess::AshenRealEstate
  mechanic(:state, office::MAP, :part => :scent) do
    auto
    name [8, 10, 11, 12], lambda { |ev| office.label(ev) }
    phase lambda { PokeAccess::Puzzles.assist? && office.cup_left? }, :quiet => true, :hint => :afh_scent_hint
    active { office.cup_left? }
  end
end
