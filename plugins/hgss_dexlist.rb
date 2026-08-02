# The HGSS Dex List plugin replaces the Pokedex's list window with a SPRITE (PokedexListSprite), so neither
# the generic command reader nor the auto-detect net can see it: the whole list -- the main thing the
# Pokedex is for -- goes unread, and only the search screen was covered.
#
# The plugin reopens PokemonPokedex_Scene, a class every Essentials game already has, so the hook alone
# proves nothing: what says the plugin is installed is the list sprite answering to species/dexlist, and a
# vanilla Window_Pokedex does not. Asking the sprite is therefore both the read and the gate -- this file
# stays inert on a game with the stock Pokedex even though its hook binds there.
#
# pbRefresh repaints on every cursor move and on every page turn, which is exactly the read point.
module PokeAccess
  module HGSSDexList
    # The list sprite, only when it is the plugin's (the stock one answers to neither of these).
    def self.list(scene)
      sprites = PokeAccess.ivar(scene, :@sprites)
      s = sprites.is_a?(Hash) ? sprites["pokedex"] : nil
      return nil unless s && s.respond_to?(:dexlist) && s.respond_to?(:index)
      s
    rescue StandardError
      nil
    end

    # The focused row: its dex number and species, or that the slot is still unknown.
    def self.text(spr)
      list = (spr.dexlist rescue nil)
      i = (spr.index rescue nil)
      return nil unless list.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < list.length
      row = list[i]
      return nil unless row.is_a?(Hash)
      num = row[:number]
      nm = (PokeAccess::Data.species_name(row[:species]) rescue nil)
      return PokeAccess::I18n.t(:dexlist_unknown, :num => num) if nm.nil? || nm.to_s.empty?
      PokeAccess::I18n.t(:dexlist_entry, :num => num, :name => nm)
    rescue StandardError
      nil
    end

    # Speaks the focused entry when it changes, deduped per scene.
    def self.read(scene)
      spr = list(scene)
      return if spr.nil?
      PokeAccess::Cursor.announce(scene, :hgss_dex, (spr.index rescue nil), true) { text(spr) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonPokedex_Scene", :pbRefresh, :optional => true) do |scene, _r, _a|
  PokeAccess::HGSSDexList.read(scene)
end
