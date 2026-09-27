module PokeAccess
  # Encounter List UI (EncounterList_Scene): the focused encounter type's species, drawn as icons, said on drawPresent
  # through the shared EncounterList helpers, or none on drawAbsent; opening clears the cursor so a reopened screen
  # reads again.
  module EncounterListUI
    # Reads the focused encounter type when @index changes.
    def self.read_present(s)
      idx = PokeAccess.ivar(s, :@index)
      t = PokeAccess::Cursor.on_change(s, :encounter_list, idx) { text_for(s) }
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # The focused encounter type's summary, also stored whole for the info key; its name from the plugin's
    # USER_DEFINED_NAMES (nested or top-level), else the engine's. getEncData is private in some builds, hence send.
    def self.text_for(s)
      enc, key = (s.send(:getEncData) rescue [nil, nil])
      return nil unless enc.is_a?(Array)
      user_names = (PokeAccess.const_at("EncounterListSettings::USER_DEFINED_NAMES") ||
                    PokeAccess.const_at("USER_DEFINED_NAMES"))
      type_name = ((user_names[key] rescue nil) || (GameData::EncounterType.get(key).real_name rescue nil) || key.to_s)
      el = PokeAccess::EncounterList
      bases = enc.map { |sp| el.base_species(sp) }
      entries = []
      enc.each_with_index do |sp, i|
        entries.push(shown_entry(s, i, el.entry(sp, bases.select { |b| b == el.base_species(sp) }.length > 1)))
      end
      PokeAccess::Info.set_info(:text, el.summary(type_name, entries, true))
      el.summary(type_name, entries)
    rescue StandardError
      nil
    end

    # An entry as the screen's icon for it shows it (icon_state); the Pokedex's state where no icon says one.
    def self.shown_entry(s, i, e)
      st = icon_state(PokeAccess.sprite(s, "icon_#{i}"))
      st ? [e[0], st] : e
    end

    # The Pokedex state an encounter icon paints, the same in every copy of the plugin: unknown for the "?"
    # placeholder (species 0) or a black shadow, seen for a greyed icon, caught in colour; nil without an icon.
    def self.icon_state(icon)
      return nil unless icon
      return :dex_unknown if (icon.species rescue nil) == 0
      c = (icon.color rescue nil)
      return :dex_unknown if c && c.alpha.to_i > 0 && c.red.to_i == 0 && c.green.to_i == 0 && c.blue.to_i == 0
      t = (icon.tone rescue nil)
      (t && t.gray.to_i >= 255) ? :dex_seen : :dex_caught
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.before_hook("EncounterList_Scene", :pbStartScene, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :encounter_list) }
PokeAccess::Hooks.after_hook("EncounterList_Scene", :drawPresent, :optional => true) { |s, _r, _a| PokeAccess::EncounterListUI.read_present(s) }
PokeAccess::Hooks.after_hook("EncounterList_Scene", :drawAbsent, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:enc_none, :loc => ($game_map.name rescue nil).to_s), true)
end
