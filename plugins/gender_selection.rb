# Player look / gender picker at the start of a new game (class PokemonGenderSelection), a third-party
# plugin several fangames ship under different script names ("Gender selection", "GenderSelect",
# "Seleccion Personajes"). The choice is two pictures with no text at all, so without a reader there is
# nothing to tell the two apart.
#
# Verified identical in the three copies seen: the same four methods (initialize, input, main_method,
# continue) and the same @select convention -- 1 is the neutral start, 2/3 the boy, 4/5 the girl (the odd
# values are the "are you sure?" step, whose own pbMessage the core dialogue reader already speaks).
#
# input runs every frame of the picker's own loop, which is what makes a plain after-hook enough even
# though the scene blocks inside initialize and never becomes $scene.
module PokeAccess
  module GenderSelection
    BOY = [2, 3]
    GIRL = [4, 5]

    # The i18n key for a cursor value, or nil for the neutral start (which the opening line already covers).
    def self.label_key(sel)
      return :gsel_boy if BOY.include?(sel)
      return :gsel_girl if GIRL.include?(sel)
      nil
    end

    # Speaks the highlighted choice as the cursor moves, deduped per scene.
    def self.announce(scene)
      sel = PokeAccess.ivar(scene, :@select)
      PokeAccess::Cursor.announce(scene, :gender_sel, sel, true) do
        k = label_key(sel)
        k ? PokeAccess::I18n.t(k) : nil
      end
    rescue StandardError
      nil
    end
  end
end

# The controls, once, before the picker takes over the screen: with two unlabelled pictures the player has
# no way to learn that left and right are the choice.
#
# The help names no direction on purpose. The three games do NOT agree on which side is which: armonia and
# realidea map RIGHT to the boy, awakening maps LEFT to him, and the mapping lives inside the method body
# where nothing can introspect it -- so a help line that picked a side was dictating the controls backwards
# in one game, as the very first sentence of a new save. Moving the cursor announces the choice anyway,
# which is the part that actually tells the player where they are.
PokeAccess::Hooks.before_hook("PokemonGenderSelection", :main_method, :optional => true) do |_s, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:gsel_help), true)
end

PokeAccess::Hooks.after_hook("PokemonGenderSelection", :input, :optional => true) do |s, _r, _a|
  PokeAccess::GenderSelection.announce(s)
end
