# Message history (Kyu's TextLog, class Log): a scrollable view of $PokemonGlobal.log painted into a bitmap,
# with no window the engine knows about.
#
# The two copies are the same code organised differently -- one paints in drawLines, the other inlines the
# painting inside update -- and `update` in both is a loop that returns only when the log is closed. So no
# method they share fires per scroll. What they do share is that their loops call Input.update every frame,
# so SceneWatcher holds the instance and reads @pos per frame instead.
#
# @pos behaves the same in both: it starts at log.length-1 and the paint loop advances it past what it drew.
module PokeAccess
  module TextLog
    # The indices of the entries the page is showing, oldest first, or nil when there is no log.
    #
    # A PAGE, not a cursor: the screen paints as many entries as fit and scrolls by pagefuls, so reading one
    # of them left the rest unheard on a screen whose only purpose is re-reading what was said. @lines is
    # how many the last paint drew and @pos - 1 is the newest of them.
    #
    # Known gap, left on purpose: scrolling down out of log ends with the newest shown at @pos rather than
    # @pos - 1, and the two cases leave identical state, so the reader cannot tell them apart. Guessing the
    # other way would name an entry the screen is not showing, which is the worse error.
    def self.page_range(scene)
      pos = PokeAccess.ivar(scene, :@pos)
      log = ($PokemonGlobal.log rescue nil)
      return nil if pos.nil? || !log.is_a?(Array) || log.empty?
      n = PokeAccess.ivar(scene, :@lines).to_i
      n = 1 if n < 1
      last = pos - 1
      last = log.length - 1 if last > log.length - 1
      return nil if last < 0
      first = last - n + 1
      first = 0 if first < 0
      (first..last).to_a
    end

    # The whole visible page as one spoken line.
    def self.page_text(scene)
      idx = page_range(scene)
      return nil if idx.nil? || idx.empty?
      PokeAccess::Util.join_parts(idx.map { |i| entry_text(i) })
    rescue StandardError
      nil
    end

    # The entry at an index as one cleaned line, or nil. Each entry is itself an array of drawn lines.
    def self.entry_text(i)
      log = ($PokemonGlobal.log rescue nil)
      return nil if i.nil? || !log.is_a?(Array) || i < 0 || i >= log.length
      entry = log[i]
      raw = entry.is_a?(Array) ? entry.join(" ") : entry.to_s
      PokeAccess.clean(raw)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::TextLogReader = PokeAccess::SceneWatcher.reader("Log", :update, :text_log, :optional => true) do |s|
  idx = PokeAccess::TextLog.page_range(s)
  [idx, lambda { PokeAccess::TextLog.page_text(s) }]
end
