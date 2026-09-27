module PokeAccess
  # Insurgence's Pokedex forms page (PokedexFormScene, 096_PokemonNestAndForm.rb) repaints the species and its form in
  # pbUpdate, every frame, and has no pbRefresh for the core's reader: the page is said when the form on show changes.
  module InsurgenceDexForms
    # Says the form on show (the core's reading of the page) once per species, gender and form.
    def self.update(scene)
      key = [PokeAccess.ivar(scene, :@species), PokeAccess.ivar(scene, :@gender), PokeAccess.ivar(scene, :@form)]
      PokeAccess::Cursor.on_change(scene, :ins_dex_form, key) { PokeAccess::DexEntry.gen6_form(scene) }
    end
  end
end

PokeAccess::Game.define("insurgence") do
  after("PokedexFormScene", :pbUpdate) { |s, _r, _a| PokeAccess::InsurgenceDexForms.update(s) }

  # While the chooser is up the page stays quiet (its window is read) and its preview forms are passed over; closing it
  # says the page again, the chosen form or the one kept on cancel.
  around("PokedexFormScene", :pbChooseForm) do |s, nxt, _a|
    begin
      nxt.call
    ensure
      PokeAccess::Cursor.reset(s, :ins_dex_form)
    end
  end
end
