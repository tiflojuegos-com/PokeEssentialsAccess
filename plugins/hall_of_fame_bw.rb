# Hall of Fame PC viewer (the "Hall de la Fama BW" plugin, HallOfFameViewerScene): browse past Hall entries
# team by team. Left/Right walk the six members, the confirm key steps back an entry, and update_display
# redraws after every one of those -- and once from pbStartScene -- so it is both the opening read and the
# cursor read.
#
# The two copies differ a long way outside this screen, but the viewer itself matches: @hallEntry,
# @pokemonIndex, @hallIndex, update_display, hallOfFameLastNumber and speciesName mean the same in both.
# The entry number is not @hallIndex but the plugin's own formula, because entries are stored newest-last
# while it numbers them by when they happened.
module PokeAccess
  module HallOfFameBW
    # The 1-based number the plugin shows for the focused entry, or the index + 1 if the counter is absent.
    def self.entry_number(hall_index)
      total = ($PokemonGlobal.hallOfFame.size rescue 0)
      ($PokemonGlobal.hallOfFameLastNumber + hall_index - total + 1 rescue (hall_index + 1))
    end

    # The rest of what the panel paints under the name: types, owner, trainer ID and where it was caught.
    # Through the plugin's own accessors (types as an array, owner.name, owner.public_id padded to five),
    # since these two games do not have the gen-6 names.
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

    # Where it was caught, resolved the way the panel resolves it: the stored obtain_text wins, then the map
    # name, and finally the panel's own "unknown place" default, which it paints rather than hiding the line.
    def self.caught_in(pk)
      txt = (pk.obtain_text rescue nil)
      return txt.to_s if txt && !txt.to_s.empty?
      id = (pk.obtain_map rescue nil)
      m = id.is_a?(Integer) && id > 0 ? (pbGetMapNameFromId(id) rescue nil) : nil
      (m && !m.to_s.empty?) ? m.to_s : PokeAccess::I18n.t(:hofbw_unknown_place)
    rescue StandardError
      nil
    end

    # The sex word the panel glues to the SPECIES name, or "". Male and female only: a genderless entry gets
    # no symbol on screen.
    def self.sex_suffix(pk)
      g = (pk.gender rescue nil)
      return "" unless g == 0 || g == 1
      " " + PokeAccess::I18n.t(g == 0 ? :pk_male : :pk_female)
    rescue StandardError
      ""
    end

    # The focused team member: which entry, where in the team, and the Pokemon. speciesName is the plugin's
    # own accessor, so a renamed or fused species comes out as the screen shows it.
    def self.read(scene)
      entry = PokeAccess.ivar(scene, :@hallEntry)
      return unless entry.is_a?(Array)
      pi = PokeAccess.ivar_i(scene, :@pokemonIndex)
      hi = PokeAccess.ivar_i(scene, :@hallIndex)
      return unless PokeAccess::Cursor.changed?(scene, :hof, [hi, pi])
      pk = (entry[pi] rescue nil)
      return unless pk
      parts = [PokeAccess::I18n.t(:hofbw_entry, :n => entry_number(hi)),
               PokeAccess::I18n.t(:hofbw_pos, :n => pi + 1, :tot => entry.length)]
      nm = (pk.name rescue nil)
      sp = (pk.speciesName rescue nil)
      parts.push(nm) if nm && !nm.to_s.empty? && nm != sp
      parts.push(sp.to_s + sex_suffix(pk)) if sp && !sp.to_s.empty?
      lv = (pk.level rescue nil)
      parts.push(PokeAccess::I18n.t(:hofbw_level, :n => lv)) if lv
      parts.concat(extra(pk))
      PokeAccess.speak_clean(parts.join(", "), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("HallOfFameViewerScene", :update_display, :optional => true) do |scene, _r, _a|
  PokeAccess::HallOfFameBW.read(scene)
end

# The entry CEREMONY (SalonDeFama.registrar -> HallDeLaFama): the plugin replaces the engine's
# pbHallOfFameEntry wholesale, so the core HallOfFame reader never runs in these games. Every line the
# ceremony shows -- titles, dex stats, per-Pokemon cards -- goes through its three window builders, the
# one seam shared by all its gen-styled variants; read there and the whole ceremony speaks.
["create_text_window", "create_title_window", "create_info_window"].each do |m|
  PokeAccess::Hooks.after_hook("HallDeLaFama", m.to_sym, :optional => true) do |_s, _r, args|
    t = args[0]
    PokeAccess.say_dialogue(t.to_s) if t && !t.to_s.strip.empty?
  end
end
