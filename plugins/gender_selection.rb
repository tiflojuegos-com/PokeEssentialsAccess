# Player look / gender picker at the start of a new game (class PokemonGenderSelection), a third-party
# plugin several fangames ship under different script names ("Gender selection", "GenderSelect",
# "Seleccion Personajes"). The choice is two pictures with no text at all, so without a reader there is
# nothing to tell the two apart.
#
# The three copies are identical here: same four methods and the same @select convention -- 1 neutral, 2 the
# boy, 4 the girl, and the odd values 3 and 5 the confirm step, which the core dialogue reader speaks.
#
# input runs every frame of the picker's loop, which is why a plain after-hook is enough even though the
# scene blocks inside initialize and never becomes $scene.
module PokeAccess
  module GenderSelection
    BOY = 2
    GIRL = 4

    # The i18n key for a cursor value, or nil where the screen is not a picker any more.
    #
    # The confirm values answer nil on purpose: the whole confirm step -- the question, the player change and
    # a twenty-frame fade -- runs inside input before it returns, so a label for 3 or 5 lands on a screen
    # that is already gone.
    def self.label_key(sel)
      return :gsel_boy if sel == BOY
      return :gsel_girl if sel == GIRL
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

# The controls, once, before the picker takes over: two unlabelled pictures give no clue that left and
# right are the choice.
#
# The help names no direction on purpose: the games disagree on which side is which (armonia and realidea
# put the boy on RIGHT, awakening on LEFT) and the mapping is inside the method body where nothing can
# introspect it. Moving the cursor announces the choice, which is what actually locates the player.
PokeAccess::Hooks.before_hook("PokemonGenderSelection", :main_method, :optional => true) do |_s, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:gsel_help), true)
end

# hook_container because input is not a leaf: the confirm step runs a whole pbConfirmMessage inside it, and
# under the default reentrancy guard the command window's own reader is discarded as nested -- so the yes/no
# of an irreversible choice was answered with nothing spoken.
PokeAccess::Hooks.after_hook("PokemonGenderSelection", :input, :optional => true, :hook_container => true) do |s, _r, _a|
  PokeAccess::GenderSelection.announce(s)
end
