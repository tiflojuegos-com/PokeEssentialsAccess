# Message history (Kyu's TextLog, class Log), a third-party plugin several fangames ship: a scrollable view
# of past messages held in $PokemonGlobal.log, painted into a bitmap with no window the engine knows about.
#
# The copies are the SAME code organised differently, and that organisation is the whole problem:
#
#   * one keeps the page painting in drawLines, called from its modal loop on every scroll
#   * the other inlines the very same painting inside update
#
# and `update` in BOTH is a `loop do` that only returns when the player closes the log. So an after-hook on
# update fires exactly once, at close -- which is what the previous per-profile reader for the inlined
# variant did, announcing a single entry on the way out. drawLines is a fine hook point but the inlined
# variant does not have it, so there is no method shared by both that fires per scroll.
#
# What both DO share is that their loops call Input.update every iteration, so the mod's per-frame poller
# runs inside them. Hence SceneWatcher: hold the instance while the modal method runs and read @pos each
# frame. One mechanism, both shapes, and no dependence on where the painting happens to live.
#
# @pos is the same in both (it starts at log.length-1 and the paint loop advances it past what it drew), so
# the entry that just became current is at @pos-1 in either copy.
module PokeAccess
  module TextLog
    # The index of the focused entry, clamped, or nil when there is no log. Deduping on this rather than on
    # raw @pos matters at the ends of the list, where @pos still moves but the focused entry does not.
    def self.focus_index(scene)
      pos = PokeAccess.ivar(scene, :@pos)
      log = ($PokemonGlobal.log rescue nil)
      return nil if pos.nil? || !log.is_a?(Array) || log.empty?
      i = pos - 1
      i = 0 if i < 0
      i = log.length - 1 if i > log.length - 1
      i
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

PokeAccess::TextLogReader = PokeAccess::SceneWatcher.reader("Log", :update, :text_log) do |s|
  i = PokeAccess::TextLog.focus_index(s)
  [i, lambda { PokeAccess::TextLog.entry_text(i) }]
end
