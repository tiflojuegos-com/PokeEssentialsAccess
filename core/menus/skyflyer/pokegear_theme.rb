module PokeAccess
  # Pokegear theme selector (LinKazamine's plugin, PokemonPokegearTheme_Scene): theme buttons as sprites
  # driven by @index over @commands ([image, name] pairs), with no command window. Reads the focused theme
  # name on change. pbUpdate marks the selected button each frame.
  module PokegearTheme
    def self.poll(scene)
      PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :pgtheme_last) { |entry| (entry[1] rescue nil) }
    end
  end
end

# pbUpdate runs each frame and highlights the @index button; read the focused theme name on change.
PokeAccess::Hooks.after_hook("PokemonPokegearTheme_Scene", :pbUpdate) do |scene, _r, _a|
  PokeAccess::PokegearTheme.poll(scene)
end
