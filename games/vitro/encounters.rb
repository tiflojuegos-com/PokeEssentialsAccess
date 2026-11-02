# Vitro's encounter list (0286_UI de encuentros, on raZ's) joins each map's encounters in pages turned with left and right, and
# marks with a small icon what only appears at some time or some way: drawAllTexts paints "<map> : <page>" and how many are
# caught, or that the zone has no wild Pokemon.
module PokeAccess
  module VitroEncounters
    # The word for each icon a species may carry.
    ICONS = { :day => :vitro_enc_day, :night => :vitro_enc_night, :surf => :vitro_enc_surf, :rod => :vitro_enc_rod,
              :headbutt => :vitro_enc_headbutt, :rocksmash => :vitro_enc_rock, :bugcontest => :vitro_enc_bug,
              :radio => :vitro_enc_radio }

    # A species of the page as [name with its icon's word, Pokedex state key]; a silhouette, one not seen, says only that.
    def self.entry(row)
      species = row[:species]
      name = PokeAccess::Data.species_name(species) || species.to_s
      icon = ICONS[row[:icon_type]]
      name = PokeAccess::I18n.t(:enc_form, :name => name, :form => PokeAccess::I18n.t(icon)) if icon
      state = PokeAccess::Util.dex_owned?(species) ? :dex_caught : (PokeAccess::Util.dex_seen?(species) ? :dex_seen : :dex_unknown)
      [name, state]
    end

    # The page's text at a level, whole for the info key.
    def self.text(head, entries, owned, whole = false)
      PokeAccess.sentences([PokeAccess::EncounterList.summary(head, entries, whole),
                            PokeAccess::I18n.t(:rea_enc_owned, :n => owned)])
    end

    # Says a page as drawAllTexts paints it, the first queued and each turn cutting in; the info key keeps it whole.
    def self.page(scene, args)
      name, encounters, owned = args
      head = PokeAccess.clean(_INTL("{1} : {2}", pbGetMapNameFromId(PokeAccess.ivar(scene, :@mapid)), name))
      return none(scene, head) if encounters.nil?
      entries = encounters.map { |row| entry(row) }
      PokeAccess::Info.set_info(:text, text(head, entries, owned, true))
      PokeAccess::Cursor.announce(scene, :vitro_encounters, PokeAccess.ivar(scene, :@current_page), true, false) do
        text(head, entries, owned)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A zone with no wild Pokemon, as the screen says it.
    def self.none(scene, head)
      line = PokeAccess.sentences([head, PokeAccess.clean(_INTL("¡Esta zona no tiene Pokémon salvajes!"))])
      PokeAccess::Info.set_info(:text, line)
      PokeAccess::Cursor.announce(scene, :vitro_encounters, :none, true, false) { line }
    end
  end
end

PokeAccess::Game.define("vitro") do
  after("EncounterListUI", :drawAllTexts, :optional => true) do |scene, _r, args|
    PokeAccess::VitroEncounters.page(scene, args)
  end
  clear_info_on("EncounterListUI", :dispose)
end
