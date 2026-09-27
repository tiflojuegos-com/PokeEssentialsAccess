module PokeAccess
  # Pokegear theme selector (LinKazamine's plugin): sprite buttons over @commands, [image, name] pairs.
  module PokegearTheme
    def self.poll(scene)
      PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :pgtheme_last) { |entry| (entry[1] rescue nil) }
    end
  end
end

# Reads the focused theme name when it changes, from pbUpdate (every frame).
PokeAccess::Hooks.after_hook("PokemonPokegearTheme_Scene", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::PokegearTheme.poll(scene)
end
