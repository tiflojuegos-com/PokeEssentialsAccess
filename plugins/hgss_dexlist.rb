# The HGSS Dex List plugin's list sprite (PokedexListSprite), read on every pbRefresh; the sprite answering to
# dexlist and index is what tells it from a stock Pokedex.
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

    # The focused row as its square shows it: the painted number and the species (unknown when unseen), from
    # medium owned or seen, in full shiny where the number is gold; the info key keeps the whole row.
    def self.text(spr)
      list = (spr.dexlist rescue nil)
      i = (spr.index rescue nil)
      return nil unless list.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < list.length
      row = list[i]
      return nil unless row.is_a?(Hash)
      num = row[:number].to_i
      num -= 1 if row[:shift]
      sp = row[:species]
      nm = seen?(sp) ? (PokeAccess::Data.species_name(sp) rescue nil) : nil
      if nm.nil? || nm.to_s.empty?
        PokeAccess::Info.set_info(:text, PokeAccess::I18n.t(:dexlist_unknown, :num => num))
        return PokeAccess::I18n.t(:dexlist_unknown, :num => num)
      end
      mine = owned?(sp)
      parts = [[PokeAccess::I18n.t(:dexlist_entry, :num => num, :name => nm), :brief],
               [PokeAccess::I18n.t(mine ? :dex_caught : :dex_seen), :medium]]
      parts.push([PokeAccess::I18n.t(:pk_shiny), :full]) if mine && gold?(sp)
      PokeAccess::Verbosity.info_line(:dex_entry, parts)
    rescue StandardError
      nil
    end

    # Whether the player owns this species, asked the way the square asks it (the ball and the full sprite).
    def self.owned?(species)
      ($player.owned?(species) rescue false) ? true : false
    end

    # Whether the square paints its number in gold: an owned species whose last seen form was shiny, in a
    # plugin set to mark those.
    def self.gold?(species)
      return false unless (PokedexListSprite::USE_GOLD_NUMBER_FOR_SHINY rescue false)
      form = ($player.pokedex.last_form_seen(species) rescue nil)
      form.is_a?(Array) && form[2] ? true : false
    rescue StandardError
      false
    end

    # Whether the player has seen this species, as the panel asks it; true when there is nothing to ask.
    def self.seen?(species)
      return true if species.nil?
      ($player.seen?(species) rescue true) ? true : false
    rescue StandardError
      true
    end

    # Speaks the focused entry when it changes, keyed on its text too (a search or a reorder keeps the index).
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

# Back from a species entry, pbRefresh repaints the same row: the slot is reset so it is read again.
PokeAccess::Hooks.around_hook("PokemonPokedex_Scene", :pbDexEntry, :optional => true) do |scene, nxt, _a|
  begin
    nxt.call
  ensure
    PokeAccess::Cursor.reset(scene, :hgss_dex)
  end
end
