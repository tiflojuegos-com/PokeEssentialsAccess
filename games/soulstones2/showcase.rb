# Soulstones 2's footer on Tectonic's Party Showcase paints the difficulty line blue when the difficulty has been
# raised since the start of the game ($game_variables[985]) and red when it has been lowered; said after that line.
module PokeAccess
  module SS2Showcase
    # The [starting difficulty, current mode] pairs writeBottomText paints blue and red.
    RAISED = [["Adept", 2], ["Standard", 2], ["Standard", 1]]
    LOWERED = [["Unfair", 1], ["Unfair", 0], ["Adept", 0]]

    # What the colour of the difficulty line says, or nil when it keeps the page's own colour.
    def self.difficulty_shift
      pair = [($game_variables[985] rescue nil), ($player.difficulty_mode rescue nil)]
      return PokeAccess::I18n.t(:ss2_diff_raised) if RAISED.include?(pair)
      return PokeAccess::I18n.t(:ss2_diff_lowered) if LOWERED.include?(pair)
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  around("PokemonPartyShowcase_Scene", :writeBottomText, :optional => true) do |_s, nxt, _a|
    r = nxt.call
    shift = PokeAccess::SS2Showcase.difficulty_shift
    PokeAccess::PaintCapture.note(shift, :icons) if shift && PokeAccess::PaintCapture.armed?(:showcase)
    r
  end
end
