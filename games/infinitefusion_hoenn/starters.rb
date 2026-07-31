# Hoenn's own starter picker (StartersSelectionScene, 053_PIF_Hoenn/StartersSelectionScene.rb). It is the
# first interactive screen of a new game and draws everything as sprites: the focused starter is only implied
# by which poke ball is open, so a blind player could not tell the three apart. The scene runs its own
# blocking loop, but the cursor lives in @index and the game calls updateStarterSelectionGraphics on every
# change (including the very first pick from the closed-ball state), so an after-hook there is enough.
module PokeAccess
  module IF2Starters
    # Speaks the focused starter once per change: its species name, and its position in the row.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      list = PokeAccess.ivar(scene, :@starters_species)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      name = (PokeAccess::Data.species_name(list[idx]) || list[idx].to_s)
      PokeAccess::Cursor.announce(scene, :if2_starter, idx, true) do
        PokeAccess::I18n.t(:if2_starter, :name => name, :n => idx + 1, :tot => list.length)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("StartersSelectionScene", :updateStarterSelectionGraphics) { |s, _r, _a| PokeAccess::IF2Starters.focus(s) }
  after("StartersSelectionSceneSingle", :updateStarterSelectionGraphics) { |s, _r, _a| PokeAccess::IF2Starters.focus(s) }
end
