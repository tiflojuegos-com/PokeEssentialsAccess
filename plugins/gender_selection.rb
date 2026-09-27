# The new-game gender picker (PokemonGenderSelection), two pictures with no text; @select is 1 neutral, 2 the boy,
# 4 the girl, and odd values the confirm step. input runs every frame of the picker's loop.
module PokeAccess
  module GenderSelection
    BOY = 2
    GIRL = 4

    # The i18n key for a cursor value; nil for the confirm values, a step that runs whole inside input.
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

# The controls, once, as the picker opens; they name no side, as the games disagree on which one is the boy.
PokeAccess::Hooks.before_hook("PokemonGenderSelection", :main_method, :optional => true) do |_s, _a|
  PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:gsel_help), PokeAccess::I18n.t(:gsel_help_hint)), true)
end

# hook_container, since input runs the confirm step's pbConfirmMessage, whose reader the guard would drop as nested.
PokeAccess::Hooks.after_hook("PokemonGenderSelection", :input, :optional => true, :hook_container => true) do |s, _r, _a|
  PokeAccess::GenderSelection.announce(s)
end
