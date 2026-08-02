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
        single?(scene) ? name :
          PokeAccess::I18n.t(:if2_starter, :name => name, :n => idx + 1, :tot => list.length)
      end
    rescue StandardError
      nil
    end

    # The one-starter variant pads its row with two invisible placeholders and pins @index to 1 (it forces
    # it back on every direction key), so the position is ALWAYS a false "2 of 3". There is nothing to
    # position yourself among, so it gets the name alone.
    def self.single?(scene)
      scene.class.to_s == "StartersSelectionSceneSingle"
    rescue StandardError
      false
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  # One registration covers both: StartersSelectionSceneSingle inherits updateStarterSelectionGraphics and
  # does not redefine it, so registering it again only chained a second wrapper onto the same implementation.
  after("StartersSelectionScene", :updateStarterSelectionGraphics) { |s, _r, _a| PokeAccess::IF2Starters.focus(s) }
end
