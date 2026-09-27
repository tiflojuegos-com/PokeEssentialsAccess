# The "Hall de la Fama BW" plugin: its Hall of Fame PC viewer (read on each update_display) and entry ceremony.
module PokeAccess
  module HallOfFameBW
    # The 1-based number the plugin shows for the focused entry, or the index + 1 if the counter is absent.
    def self.entry_number(hall_index)
      total = ($PokemonGlobal.hallOfFame.size rescue 0)
      ($PokemonGlobal.hallOfFameLastNumber + hall_index - total + 1 rescue (hall_index + 1))
    end

    # The rest of what the panel paints under the name: types, owner, trainer ID and where it was caught.
    def self.extra(pk)
      out = []
      names = (pk.types.uniq.map { |ty| (PokeAccess::Data.type_name(ty) rescue nil) } rescue [])
      names = names.compact.reject { |s| s.to_s.empty? }
      out.push(PokeAccess::I18n.t(:hofbw_types, :t => names.join("/"))) unless names.empty?
      ot = (pk.owner.name rescue nil)
      out.push(PokeAccess::I18n.t(:hofbw_ot, :name => ot)) if ot && !ot.to_s.empty?
      id = (pk.owner.public_id rescue nil)
      out.push(PokeAccess::I18n.t(:hofbw_id, :n => sprintf("%05d", id))) if id
      out.push(PokeAccess::I18n.t(:hofbw_caught, :map => caught_in(pk))) if caught_in(pk)
      out
    rescue StandardError
      []
    end

    # Where it was caught, as the panel resolves it: obtain_text, else the map name, else "unknown place".
    def self.caught_in(pk)
      txt = (pk.obtain_text rescue nil)
      return txt.to_s if txt && !txt.to_s.empty?
      id = (pk.obtain_map rescue nil)
      m = id.is_a?(Integer) && id > 0 ? (pbGetMapNameFromId(id) rescue nil) : nil
      (m && !m.to_s.empty?) ? m.to_s : PokeAccess::I18n.t(:hofbw_unknown_place)
    rescue StandardError
      nil
    end

    # The sex sign the panel glues to the species name, as painted, or "" (a genderless entry shows none).
    def self.sex_suffix(pk)
      g = PokeAccess::Party.gender_glyph(pk)
      g ? " #{g}" : ""
    rescue StandardError
      ""
    end

    # What the card's species bar shows: the species with its sex sign. A copy that draws something else in
    # that bar overrides this.
    def self.species_bar(pk, sp)
      sp.to_s + sex_suffix(pk)
    end

    # The gen-5 ceremony card of one team member, composed from what its two bars paint: the nickname when
    # it differs from the species, the species bar, and the level.
    def self.card(pk)
      return nil unless pk
      sp = (pk.speciesName rescue nil)
      sp = (GameData::Species.get(pk.species).name rescue nil) if sp.nil? || sp.to_s.empty?
      nm = (pk.name rescue nil)
      parts = []
      parts.push(nm) if nm && !nm.to_s.empty? && nm != sp
      parts.push(species_bar(pk, sp)) if sp && !sp.to_s.empty?
      lv = (pk.level rescue nil)
      parts.push(PokeAccess::I18n.t(:hofbw_level, :n => lv)) if lv
      parts.empty? ? nil : parts.join(", ")
    rescue StandardError
      nil
    end

    # The gen-5 finale: the champion line with the region the plugin names, then the player and the play
    # time its lower bar shows.
    def self.finale(scene)
      region = (PokeAccess.const_at("HallDeLaFama_REGION") rescue nil).to_s
      first = region.empty? ? PokeAccess::I18n.t(:hofbw_champion_any) : PokeAccess::I18n.t(:hofbw_champion, :region => region)
      name = (PokeAccess::Engine.player.name rescue nil).to_s
      time = (scene.get_play_time_formatted rescue nil)
      second = nil
      unless name.empty?
        second = time ? PokeAccess::I18n.t(:hofbw_finale, :name => name, :time => time) : name
      end
      PokeAccess::Util.join_parts([first, second], " ")
    rescue StandardError
      nil
    end

    # A ceremony text window on screen, once per text it shows.
    def self.say_window(win)
      t = PokeAccess.ivar(win, :@text).to_s
      return if t.strip.empty? || !PokeAccess::Cursor.changed?(win, :hof_text, t)
      PokeAccess.say_dialogue(t)
    end

    # The focused team member: entry, place in the team and the Pokemon (its species via the plugin's speciesName).
    def self.read(scene)
      entry = PokeAccess.ivar(scene, :@hallEntry)
      return unless entry.is_a?(Array)
      pi = PokeAccess.ivar_i(scene, :@pokemonIndex)
      hi = PokeAccess.ivar_i(scene, :@hallIndex)
      prev = PokeAccess::Cursor.current(scene, :hof)
      return unless PokeAccess::Cursor.changed?(scene, :hof, [hi, pi])
      pk = (entry[pi] rescue nil)
      return unless pk
      record = PokeAccess::I18n.t(:hofbw_entry, :n => entry_number(hi))
      nm = (pk.name rescue nil)
      nm = nil if nm.nil? || nm.to_s.empty?
      sp = (pk.speciesName rescue nil)
      sp = nil if sp.nil? || sp.to_s.empty?
      nm = nil if nm == sp
      lv = (pk.level rescue nil)
      level = lv ? PokeAccess::I18n.t(:hofbw_level, :n => lv) : nil
      more = extra(pk)
      whole = [record, nm, sp ? sp.to_s + sex_suffix(pk) : nil, level].concat(more)
      PokeAccess::Info.set_info(:text, PokeAccess.clean(PokeAccess::Util.join_parts(whole, ", ")))
      new_record = !prev.is_a?(Array) || prev[0] != hi
      shown_sp = PokeAccess::Verbosity.keep?(:hall_of_fame, :full) ? whole[2] : sp
      parts = [[record, new_record ? :brief : :full], [PokeAccess::Verbosity.position(pi + 1, entry.length), :brief],
               [nm, :brief], [shown_sp, :brief], [level, :medium]]
      more.each { |m| parts.push([m, :full]) }
      PokeAccess.speak_clean(PokeAccess::Verbosity.line(:hall_of_fame, parts), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("HallOfFameViewerScene", :update_display, :optional => true) do |scene, _r, _a|
  PokeAccess::HallOfFameBW.read(scene)
end

# The entry ceremony (HallDeLaFama, replacing pbHallOfFameEntry): gen-4 styles' HallOfFameTextWindow text, read
# when a window is shown or rewritten while shown, never when built (the gen-5 style builds one it never shows).
PokeAccess::Hooks.after_hook("HallOfFameTextWindow", :visible=, :optional => true) do |win, _r, args|
  PokeAccess::HallOfFameBW.say_window(win) if args[0]
end
PokeAccess::Hooks.after_hook("HallOfFameTextWindow", :text=, :optional => true) do |win, _r, _a|
  PokeAccess::HallOfFameBW.say_window(win) if (win.visible rescue false)
end

# The gen-5 style's per-Pokemon card and finale, composed from the data their bars paint.
PokeAccess::Hooks.after_hook("HallDeLaFama", :gen5_pokemon_info, :optional => true) do |_s, _r, args|
  t = PokeAccess::HallOfFameBW.card(args[0])
  PokeAccess.say_dialogue(t) if t
end

PokeAccess::Hooks.after_hook("HallDeLaFama", :create_gen5_final_windows, :optional => true) do |scene, _r, _a|
  t = PokeAccess::HallOfFameBW.finale(scene)
  PokeAccess.say_dialogue(t) if t
end

PokeAccess::Verbosity.define_reading(:hall_of_fame, :vb_hall_of_fame, :vbh_hall_of_fame)
