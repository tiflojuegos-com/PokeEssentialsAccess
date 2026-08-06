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
      # A map with no encounters does not get an empty array: getEncData fills it with the sentinel [7], and
      # the screen decides by popping the last entry and comparing it to 7 before writing "Sin encuentros
      # disponibles". Reading the array as-is turned that sentinel into species 7 and announced one wild
      # Squirtle on a map the screen says is empty -- and the none key below was unreachable.
      #
      # The empty case is the one place this deliberately does NOT mirror the screen: with an empty array
      # the screen prints a total of zero, which says the same thing in a worse way for someone listening.
      if !arr.is_a?(Array) || arr.empty? || arr.last == 7
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
  # Before main, not after initialize. The constructor's last statement IS main, and main is the blocking
  # loop, so an after-hook on the constructor only returns once the player has already closed the screen --
  # the summary arrived after it was of any use. A before-hook on the loop itself fires at the one moment
  # that counts: everything is built and nothing has been drawn yet.
  before("EncounterListUI", :main) { |scene, _a| PokeAccess::AwakeningDexNav.text(scene) }
end
