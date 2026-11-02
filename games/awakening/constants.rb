# Awakening profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("awakening") do
  # The game's ninth battle weather (PBWeather MIASMA = 9).
  names(:weather_names, 9 => "Miasma")

  # Its statues (pbMoverEstatuas) are pulled with the action button, and pushed holding the way toward them.
  pull_script(/pbMoverEstatuas/)

  # Its Kernel.pbSurf refuses while anyone walks along as a dependent event.
  surf_company(:dependents)

  # The hint letters of the buttons the game kept (its Input moves X, Y and Z and reads A, S, D, F and G raw).
  key_hints "Z" => :a, "X" => :b, "C" => :c, "Q" => :l, "W" => :r

  # M, J, G and T are the mod's coordinates, previous entry, field and info keys. The game reads them as buttons of its
  # Input (0189 PSystem_Controls): M for the region map (0282 Atajos Teclado) and, by code too, the fireball (0067
  # Scene_Map); J for the Lens of Truth; G for the battle's information (0098 PokeBattle_Scene) and the message log (0273
  # Textlog); T for its Z, which saves (0282 Atajos Teclado).
  button_labels :z => :awk_ext_key_t
  remap_extra(:awk_map, 0x4D, :awk_ext_key_m, :button => :M)
  remap_extra(:awk_lens, 0x4A, :awk_ext_key_j, :button => :J)
  remap_extra(:awk_info, 0x47, :awk_ext_key_g, :button => :G)
  key_defaults(:awk_map => "Alt+M", :awk_lens => "Alt+J", :awk_info => "Alt+G", :z => "Alt+T")

  # Its v17 party panel draws pokerus in the state slot.
  override("PokeAccess::Party", :panel_pokerus?) { |_mod, _original, _args| true }
end
