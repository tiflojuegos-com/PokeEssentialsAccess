# Hall of Fame PC viewer (the "Hall de la Fama BW" plugin, HallOfFameViewerScene): browse past Hall entries
# team by team. Left/Right walk the six members, the confirm key steps back an entry, and update_display
# redraws after every one of those -- and once from pbStartScene -- so it is both the opening read and the
# cursor read.
#
# The two copies diverge a long way outside this screen -- 464 lines against 290, with different function
# sets around it (one adds the Elite Four and Champion end-of-battle hooks and a "is this Pokemon in the
# Hall" query, the other adds per-entry lookup, time and date accessors and debug commands). What was
# compared, and what matters here, is the VIEWER: @hallEntry, @pokemonIndex, @hallIndex, update_display,
# hallOfFameLastNumber and speciesName are present and mean the same thing in both.
# That includes the entry number, which is not @hallIndex
# but the game's own formula -- hallOfFameLastNumber + @hallIndex - hallOfFame.size + 1 -- because entries
# are stored newest-last while the plugin numbers them by when they happened.
module PokeAccess
  module HallOfFameBW
    # The 1-based number the plugin shows for the focused entry, or the index + 1 if the counter is absent.
    def self.entry_number(hall_index)
      total = ($PokemonGlobal.hallOfFame.size rescue 0)
      ($PokemonGlobal.hallOfFameLastNumber + hall_index - total + 1 rescue (hall_index + 1))
    end

    # The focused team member: which entry, where in the team, and the Pokemon itself. speciesName is the
    # plugin's own accessor, so a species the game renames (or fuses) comes out the way the screen shows it.
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
      parts.push(nm) if nm && !nm.to_s.empty?
      sp = (pk.speciesName rescue nil)
      parts.push(sp) if sp && !sp.to_s.empty? && sp != nm
      lv = (pk.level rescue nil)
      parts.push(PokeAccess::I18n.t(:hofbw_level, :n => lv)) if lv
      PokeAccess.speak_clean(parts.join(", "), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("HallOfFameViewerScene", :update_display, :optional => true) do |scene, _r, _a|
  PokeAccess::HallOfFameBW.read(scene)
end
