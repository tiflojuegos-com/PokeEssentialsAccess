# The raid plugin's styled databox (raids and triple layouts): the player's side shows the Pokemon's own sex sign
# and level, a foe its name alone, with the level only in the Basic style. Other boxes keep core's rule.
module PokeAccess
  module SS2StyledBox
    # The raid plugin's styled databox of a battler, or nil.
    def self.box(b)
      k = PokeAccess.const_at("Battle::Scene::RaidPokemonDataBox")
      box = PokeAccess::Battle.styled_box(b)
      k && box.is_a?(k) ? box : nil
    end

    def self.basic?(box)
      (PokeAccess.ivar(box, :@style).id rescue nil) == :Basic
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  override("PokeAccess::Battle", :shown_sex) do |_mod, original, args|
    b = args[0]
    if PokeAccess::SS2StyledBox.box(b)
      s = (b.index.even? rescue false) ? PokeAccess::Party.sign((b.gender rescue nil)) : nil
      s ? " #{s}" : ""
    else
      original.call
    end
  end
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    b = args[0]
    box = PokeAccess::SS2StyledBox.box(b)
    if box.nil?
      original.call
    elsif (b.index.even? rescue false) || PokeAccess::SS2StyledBox.basic?(box)
      b.level
    end
  end
end
