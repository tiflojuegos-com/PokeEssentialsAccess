module PokeAccess
  # Awakening's DexNav (EncounterListUI in "Dex NAv"): lists the species encounterable on the current map as
  # icons, with a Window_AdvancedTextPokemon for the map name -- but no spoken output and no cursor (it draws
  # everything once in initialize and the loop only waits for B/C). Read the map name plus the species (and
  # each one's Pokedex status) once, when the screen opens.
  module AwakeningDexNav
    MAX = 20

    # The spoken encounter summary for the just-opened screen, from its @encarray of species ids, or nil.
    def self.text(scene)
      arr = PokeAccess.ivar(scene, :@encarray)
      map = ($game_map.name rescue nil)
      unless arr.is_a?(Array) && !arr.empty?
        return map ? PokeAccess::I18n.t(:aw_dexnav_none, :map => map.to_s) : nil
      end
      names = arr[0, MAX].map { |sp| species_label(sp) }.reject { |s| s.nil? || s.empty? }
      head = PokeAccess::I18n.t(:aw_dexnav_head, :map => map.to_s, :n => arr.length)
      [head, names.join(", ")].join(". ")
    rescue StandardError
      nil
    end

    # A species name suffixed with its Pokedex status (caught/seen/unknown).
    def self.species_label(sp)
      nm = (PBSpecies.getName(sp) rescue sp.to_s)
      owned = ($Trainer.hasOwned?(sp) rescue false)
      seen  = ($Trainer.hasSeen?(sp) rescue false)
      st = owned ? :dex_caught : (seen ? :dex_seen : :dex_unknown)
      "#{nm} (#{PokeAccess::I18n.t(st)})"
    rescue StandardError
      (PBSpecies.getName(sp) rescue sp.to_s)
    end
  end
end

PokeAccess::Game.define("awakening") do
  read_on_open("EncounterListUI", :initialize) { |scene| PokeAccess::AwakeningDexNav.text(scene) }
end
