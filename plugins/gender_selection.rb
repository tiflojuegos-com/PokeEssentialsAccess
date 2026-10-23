# The new-game gender picker (PokemonGenderSelection), two pictures with no text; @select is 1 neutral, 2 the boy,
# 4 the girl, and odd values the confirm step. input runs every frame of the picker's loop.
module PokeAccess
  module GenderSelection
    BOY = 2
    GIRL = 4

    # The spoken name of a cursor value; nil for the neutral start and the confirm values, a step that runs whole
    # inside input.
    def self.label(sel)
      return PokeAccess::I18n.t(:gsel_boy) if sel == BOY
      return PokeAccess::I18n.t(:gsel_girl) if sel == GIRL
      nil
    end
  end
end

# The controls, once, as the picker opens; they name no side, as the games disagree on which one is the boy.
PokeAccess::Hooks.before_hook("PokemonGenderSelection", :main_method, :optional => true) do |_s, _a|
  PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:gsel_help), PokeAccess::I18n.t(:gsel_help_hint)), true)
end

# The highlighted choice as the cursor moves, every read cutting in; hook_container, since input runs the confirm
# step's pbConfirmMessage, whose reader the guard would drop as nested.
PokeAccess::FocusReader.define("PokemonGenderSelection", :on => :input, :index => :@select, :slot => :gender_sel,
                               :queue => false, :optional => true, :hook_container => true) do |sel|
  PokeAccess::GenderSelection.label(sel)
end
