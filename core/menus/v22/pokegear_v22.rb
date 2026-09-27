# Pokegear menu (PokemonPokegear_Scene, @commands of [image, name]) for forks without PokegearButton#selected=,
# which menus/v21/ui_v21.rb reads otherwise: the focused option, polled each frame.
unless PokeAccess::Engine.has?("PokegearButton#selected=")
  PokeAccess::Hooks.after_hook("PokemonPokegear_Scene", :pbUpdate) do |scene, _r, _a|
    PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :pg_last) { |entry| (entry[1] rescue nil) }
  end
end
