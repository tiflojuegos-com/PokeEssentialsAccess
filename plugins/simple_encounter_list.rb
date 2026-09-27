# raZ's Simple Encounter List Window (EncounterListUI; Awakening, Pokemon Z): the map's wild species, read the frame
# after getEncData fills @encarray, once their icons are drawn; a last 7 means no encounters. Realidea's edited copy
# (loadEncounterData) is read by its profile.
module PokeAccess
  module SimpleEncounterList
    @pending = nil

    # Marks the scene whose list was just filled, to be read once its icons are up.
    def self.filled(scene); @pending = scene; end

    # Forgets a list waiting to be read.
    def self.reset; @pending = nil; end

    # Once per frame: reads a filled list once its icons are drawn, or an empty one; a list whose window drew no icons
    # for its species (a window never finished) is dropped.
    def self.poll
      s = @pending
      return unless s
      @pending = nil
      enc = PokeAccess.ivar(s, :@encarray)
      icons = PokeAccess.ivar(s, :@pkmnsprite)
      none = !enc.is_a?(Array) || enc.empty? || enc.last == 7
      read(s) if none || (icons.is_a?(Array) && !icons.empty?)
    end

    # Speaks the map's species as the screen shows them, and keeps the whole list for the info key.
    def self.read(scene)
      enc = PokeAccess.ivar(scene, :@encarray)
      loc = ($game_map.name rescue nil).to_s
      if !enc.is_a?(Array) || enc.empty? || enc.last == 7
        PokeAccess.speak(PokeAccess::I18n.t(:enc_none, :loc => loc), true)
        return
      end
      entries = []
      enc.each_with_index do |sp, i|
        entries.push([(PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s, state(scene, i, sp)])
      end
      PokeAccess::Info.set_info(:text, PokeAccess::EncounterList.summary(loc, entries, true))
      PokeAccess.speak(PokeAccess::EncounterList.summary(loc, entries), true)
    rescue StandardError
      nil
    end

    # A species' state as its icon shows it: an icon dimmed (Awakening) or greyed (Pokemon Z) marks one not caught,
    # still recognisable, so it keeps its name and says so; otherwise the Pokedex's caught, seen or unknown.
    def self.state(scene, i, sp)
      icons = PokeAccess.ivar(scene, :@pkmnsprite)
      icon = icons.is_a?(Array) ? icons[i] : nil
      return :dex_not_caught if icon && faded?(icon)
      return :dex_caught if PokeAccess::Util.dex_owned?(sp)
      PokeAccess::Util.dex_seen?(sp) ? :dex_seen : :dex_unknown
    end

    # True for an icon drawn below full opacity or with a grey tone.
    def self.faded?(icon)
      (icon.opacity rescue 255).to_i < 255 || (icon.tone.gray rescue 0).to_f > 0
    end
  end
end

PokeAccess::Hooks.after_hook("EncounterListUI", :getEncData, :optional => true) { |s, _r, _a| PokeAccess::SimpleEncounterList.filled(s) }
PokeAccess::Keys.on_frame { PokeAccess::SimpleEncounterList.poll }
PokeAccess::Caches.register(:simple_encounter_list) { PokeAccess::SimpleEncounterList.reset }
