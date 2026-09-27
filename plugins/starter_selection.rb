# shiney570's Advanced Starter Selection (PokemonStarterSelection): three pictures to move between, then pressBall
# fades in the starter's name and types and asks whether to take it.
module PokeAccess
  module StarterSelection
    # The starter under the cursor by name, the picture it stands for; from @data, since @pokemon still holds the
    # previous ball. Its types stay unsaid: the screen paints them at opacity 0 until pressBall.
    def self.moved(scene)
      sel = PokeAccess.ivar(scene, :@select)
      return unless PokeAccess::Cursor.changed?(scene, :starter_sel, sel)
      data = PokeAccess.ivar(scene, :@data)
      pkmn = data.is_a?(Hash) ? data["pkmn_#{sel}"] : nil
      name = pkmn ? (pkmn.name rescue nil) : nil
      return if name.nil? || name.to_s.empty?
      parts = [[name.to_s, :brief]]
      PokeAccess::Info.set_info(:pokemon, pkmn, PokeAccess::Verbosity.full_line(parts))
      PokeAccess.speak_clean(PokeAccess::Verbosity.line(:pokemon_choice, parts), true)
    rescue StandardError
      nil
    end

    # The types pressBall fades in with the name, said from medium ahead of its question, which names the starter.
    def self.shown(scene)
      pkmn = PokeAccess.ivar(scene, :@pokemon)
      return unless pkmn
      types = (PokeAccess::Data.pokemon_types(pkmn) rescue []).join("/")
      name = (pkmn.name rescue nil).to_s
      PokeAccess::Info.set_info(:pokemon, pkmn, PokeAccess::Verbosity.full_line([[name, :brief], [types, :medium]]))
      t = PokeAccess::Verbosity.line(:pokemon_choice, [[types, :medium]])
      PokeAccess.speak_clean(t, false) unless t.empty?
    rescue StandardError
      nil
    end
  end
end

# hook_container: gettinginput runs pressBall, whose confirm window and naming screen the guard would drop as nested.
PokeAccess::Hooks.after_hook("PokemonStarterSelection", :gettinginput, :optional => true, :hook_container => true) do |scene, _result, _args|
  PokeAccess::StarterSelection.moved(scene)
end

PokeAccess::Hooks.before_hook("PokemonStarterSelection", :pressBall, :optional => true) do |scene, _args|
  PokeAccess::StarterSelection.shown(scene)
end

PokeAccess::Verbosity.define_reading(:pokemon_choice, :vb_pokemon_choice, :vbh_pokemon_choice)
