module PokeAccess
  # Uranium's trainer card front, which draws the game's rules (Nuzlocke, Randomizer or both) as one icon in its
  # corner: the icon's words join what the core reads off the card, where the icon sits.
  module UraniumCard
    # Where pbDrawTrainerCardFront draws the rules icon.
    RULES_AT = [480, 15]

    # Notes the rules the card's icon shows into the capture of the card being read.
    def self.note_rules
      modes = PokeAccess::UraniumLoad.modes($PokemonGlobal)
      return if modes.empty?
      PokeAccess::PaintCapture.note(modes.join(", "), :positions, RULES_AT[0], RULES_AT[1])
    end
  end
end

PokeAccess::Game.define("uranium") do
  around("PokemonTrainerCardScene", :pbDrawTrainerCardFront) do |_s, nxt, _a|
    r = nxt.call
    PokeAccess::UraniumCard.note_rules
    r
  end
end
