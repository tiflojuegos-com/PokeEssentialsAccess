# The HGSS Dex List plugin replaces the Pokedex list window with a sprite (PokedexListSprite), which no
# generic reader can see.
#
# It reopens PokemonPokedex_Scene, a class every game has, so the hook alone proves nothing: what says the
# plugin is installed is the list sprite answering to species/dexlist, which a vanilla Window_Pokedex does
# not. Asking the sprite is both the read and the gate, so this file stays inert on a stock Pokedex.
#
# pbRefresh repaints on every cursor move and page turn, which is the read point.
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
    #
    # The A-Z, weight and height orders do not filter unseen species, and the panel prints "?????" for
    # those, so the name goes through the same seen? gate the panel uses.
    def self.text(spr)
      list = (spr.dexlist rescue nil)
      i = (spr.index rescue nil)
      return nil unless list.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < list.length
      row = list[i]
      return nil unless row.is_a?(Hash)
      num = row[:number]
      nm = seen?(row[:species]) ? (PokeAccess::Data.species_name(row[:species]) rescue nil) : nil
      return PokeAccess::I18n.t(:dexlist_unknown, :num => num) if nm.nil? || nm.to_s.empty?
      PokeAccess::I18n.t(:dexlist_entry, :num => num, :name => nm)
    rescue StandardError
      nil
    end

    # Whether the player has seen this species, asked the same way the panel asks it. A copy with no pokedex
    # to ask answers yes, so a missing accessor cannot silence the whole list.
    def self.seen?(species)
      return true if species.nil?
      ($player.seen?(species) rescue true) ? true : false
    rescue StandardError
      true
    end

    # Speaks the focused entry when it changes, deduped per scene.
    #
    # The row's own text is in the key, not just the index: a search or an order change rebuilds the list
    # under a cursor that has not moved, so an index-only key left the new first entry unspoken.
    def self.read(scene)
      spr = list(scene)
      return if spr.nil?
      t = text(spr)
      PokeAccess::Cursor.announce(scene, :hgss_dex, [(spr.index rescue nil), t], true) { t }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonPokedex_Scene", :pbRefresh, :optional => true) do |scene, _r, _a|
  PokeAccess::HGSSDexList.read(scene)
end
