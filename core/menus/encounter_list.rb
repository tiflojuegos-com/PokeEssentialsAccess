module PokeAccess
  # Encounter List UI (a fangame addon: the Sky base ships one, other games their own overrides): shows the
  # species on the current map as icons with no text. The header beside them -- map name, encounter type and
  # total -- IS written out; the species are the part with nothing to read, and the part this covers. Both the Sky-base scene and the overrides redraw the
  # focused encounter type via drawPresent on each left/right change (an override may lack the pbEncounter
  # loop), so drawPresent is the single universal hook; drawAbsent fires for a type with no encounters.
  # Reads the focused type's species list (name + Pokedex status), deduped per scene instance via
  # Cursor (pbStartScene resets the slot so reopening on the same type still reads). No-op without the class.
  module EncounterList
    MAX = 15

    # Reads the focused encounter type when @index changes.
    def self.read_present(s)
      idx = PokeAccess.ivar(s, :@index)
      t = PokeAccess::Cursor.on_change(s, :encounter_list, idx) { text_for(s) }
      PokeAccess.speak(t, true) if t && !t.to_s.empty?
    rescue StandardError
      nil
    end

    # The spoken summary for the scene's current encounter type (type name, species and each one's Pokedex
    # status, all from live game APIs). getEncData is private in some implementations, so call it via send.
    #
    # The type name comes from the plugin's own table, looked for where each build keeps it: royal nests it
    # inside EncounterListSettings, and asking only for the top-level constant left that game reading the
    # engine's internal encounter-type name instead of the one the screen actually shows.
    def self.text_for(s)
      enc, key = (s.send(:getEncData) rescue [nil, nil])
      return nil unless enc.is_a?(Array)
      user_names = (PokeAccess.const_at("EncounterListSettings::USER_DEFINED_NAMES") ||
                    PokeAccess.const_at("USER_DEFINED_NAMES"))
      type_name = ((user_names[key] rescue nil) || (GameData::EncounterType.get(key).real_name rescue nil) || key.to_s)
      entries = enc.map do |sp|
        nm = (PokeAccess::Data.species_name(sp) || sp.to_s)
        dex = (PokeAccess::Engine.player.pokedex rescue nil)
        st = (dex.owned?(sp) rescue false) ? :dex_caught :
             ((dex.seen?(sp) rescue false) ? :dex_seen : :dex_unknown)
        [nm, st]
      end
      summary(type_name, entries)
    rescue StandardError
      nil
    end

    # Formats the type header and species list (name + status), capped so the utterance stays manageable.
    # Pure (no engine calls), so it is unit-testable.
    def self.summary(type_name, entries)
      return nil if entries.nil?
      head = PokeAccess::I18n.t(:enc_type, :type => type_name, :n => entries.length)
      return head if entries.empty?
      shown = entries[0, MAX].map { |nm, st| "#{nm} #{PokeAccess::I18n.t(st)}" }
      more = entries.length > MAX ? ", " + PokeAccess::I18n.t(:enc_more, :n => entries.length - MAX) : ""
      "#{head}: #{shown.join(', ')}#{more}"
    end
  end
end
