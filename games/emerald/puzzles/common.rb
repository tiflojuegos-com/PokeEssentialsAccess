# What Emerald's puzzles share: where a tile lies from the player, and which layout a room's moving statues stand in.
module PokeAccess
  module EmPuzzles
    # The steps from the player to (x, y), or "here" on it.
    def self.place(x, y)
      phrase = PokeAccess::Puzzles.offset_phrase(x - $game_player.x, y - $game_player.y)
      phrase.empty? ? PokeAccess::I18n.t(:em_here) : phrase
    end

    LETTERS = "abcdefghijklmnopqrstuvwxyz"

    # What a maze's table ([event ids, one string per row]) gives for (x, y): the event its letter names, :walk for
    # '*', or nil for '.' and off the table.
    def self.grid_choice(table, x, y)
      ids, rows = table
      row = rows[y]
      c = row && x >= 0 ? row[x, 1] : nil
      return nil if c.nil? || c.empty? || c == "."
      return :walk if c == "*"
      ids[LETTERS.index(c)]
    end

    # Replays a trigger's pages (a profile's table of [trigger, [var, least] or nil, needs self switch A, {event =>
    # [dx, dy]}, [var, :set/:add/:sub, n] or nil, self switch A after or nil]) from the live flags and places: the
    # places of the events it turns after each of n steps onto it, fewer once no page answers a step.
    def self.replay(map, trigger, pages, n)
      ids = pages.map { |pg| pg[3].keys }.flatten.uniq
      pos = {}
      ids.each do |id|
        ev = $game_map.events[id]
        pos[id] = [ev.x, ev.y] if ev
      end
      vars = {}
      pages.each { |pg| vars[pg[1][0]] = $game_variables[pg[1][0]].to_i if pg[1] }
      pages.each { |pg| vars[pg[4][0]] ||= $game_variables[pg[4][0]].to_i if pg[4] }
      on = $game_self_switches[[map, trigger, "A"]] ? true : false
      out = []
      n.times do
        pg = live_page(pages, vars, on)
        break unless pg && pg[0] == 1
        on = play(pg, pos, vars, on)
        8.times do
          auto = live_page(pages, vars, on)
          break unless auto && auto[0] == 3
          on = play(auto, pos, vars, on)
        end
        out << pos.dup
      end
      out
    end

    # The last page of a table whose conditions hold for vars and the self switch, or nil.
    def self.live_page(pages, vars, on)
      pages.reverse.find { |pg| (pg[1].nil? || vars[pg[1][0]].to_i >= pg[1][1]) && (!pg[2] || on) }
    end

    # Plays one page of a table on the places and vars; answers the self switch after it.
    def self.play(pg, pos, vars, on)
      pg[3].each do |id, (dx, dy)|
        x, y = pos[id]
        pos[id] = [x + dx, y + dy] if x
      end
      if pg[4]
        var, op, n = pg[4]
        vars[var] = op == :set ? n : op == :add ? vars[var].to_i + n : vars[var].to_i - n
      end
      pg[5].nil? ? on : pg[5]
    end

    # The index of the layout ({event id => [x, y]}) the events stand in now, or nil when they match none.
    def self.layout_index(layouts)
      layouts.index do |lay|
        lay.all? do |id, (x, y)|
          ev = $game_map.events[id]
          ev && ev.x == x && ev.y == y
        end
      end
    end
  end
end
