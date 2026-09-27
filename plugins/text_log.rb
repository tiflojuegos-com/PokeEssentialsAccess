# Message history (Kyu's TextLog, class Log): a painted view of $PokemonGlobal.log whose update loops until
# closed, so SceneWatcher reads the page each frame, rebuilt from @pos and @lines the way the last move drew it.
module PokeAccess
  module TextLog
    # The indices of the entries the page shows, oldest first, or nil with no log: drawn forward from @pos - @lines
    # after a move down, else built back from @pos - 1 (the opening page, a move up, or a start past the log).
    def self.page_range(scene)
      pos = PokeAccess.ivar(scene, :@pos)
      log = ($PokemonGlobal.log rescue nil)
      return nil if pos.nil? || !log.is_a?(Array) || log.empty?
      lines = PokeAccess.ivar(scene, :@lines).to_i
      start = pos - lines
      return forward_page(log, start) if moved_down?(scene, pos, lines) && start >= 0 && start < log.length
      n = lines < 1 ? 1 : lines
      last = pos - 1
      last = log.length - 1 if last > log.length - 1
      return nil if last < 0
      first = last - n + 1
      first = 0 if first < 0
      (first..last).to_a
    end

    # Whether the page on screen was drawn by a move down: @pos grows only going down, shrinks only going up, and a
    # move that leaves it in place is a down that fit no more than one entry when it zeroes @lines. Kept on the scene.
    def self.moved_down?(scene, pos, lines)
      prev = scene.instance_variable_get(:@access_log_state)
      down = prev ? prev[2] : false
      if prev && pos != prev[0]
        down = pos > prev[0]
      elsif prev && lines != prev[1]
        down = (lines == 0)
      end
      scene.instance_variable_set(:@access_log_state, [pos, lines, down])
      down
    end

    # The entries a page drawn down from first holds, by the game's rule: each is 32 pixels a line plus INTERPAD
    # between entries, drawn while it fits the screen less PADY above and below.
    def self.forward_page(log, first)
      room = (Graphics.height rescue 384).to_i - 2 * (PokeAccess.const_at("PADY") || 25).to_i
      pad = (PokeAccess.const_at("INTERPAD") || 4).to_i
      out = []
      total = 0
      k = first < 0 ? 0 : first
      while total <= room && k < log.length
        h = 32 * (log[k].is_a?(Array) ? log[k].length : 1)
        out.push(k) if total + h <= room
        total += h + pad
        k += 1
      end
      out
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
