module PokeAccess
  # The Ekans snake minigame: its setup menu and its record table.
  #
  # The menu is an ordinary vertical list -- @index over @options, redrawn by draw on every move and on every
  # value change -- but it belongs to a class that inherits from nothing, so the generic window reader never
  # had a chance at it. Each row is a Symbol, and the plugin resolves it to a label and a right-hand value
  # through Ekans_Game.option_name and .rhs_text, which is where both halves of a row come from.
  #
  # The GAME itself is deliberately not covered here. It is real-time and needs a narration model of its own
  # -- what to announce and how often, without drowning the player -- rather than a focus reader, and doing
  # that badly is worse than leaving it silent.
  module EkansSnake
    def self.row(scene)
      opts = PokeAccess.ivar(scene, :@options)
      i = PokeAccess.ivar(scene, :@index)
      return unless opts.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < opts.length
      c = opts[i]
      name = PokeAccess.clean((Ekans_Game.option_name(c) rescue "").to_s).to_s.strip
      return if name.empty?
      value = PokeAccess.clean((Ekans_Game.rhs_text(c) rescue "").to_s).to_s.strip
      text = value.empty? ? name : "#{name}, #{value}"
      PokeAccess::Cursor.announce(scene, :ekans_row, [i, value], true) { text }
    rescue StandardError
      nil
    end

    # The record table as one spoken block, built from the very array the screen paints.
    #
    # Grouped by the y each cell is drawn at, so a table row comes out as a row instead of three loose
    # values. The screen has no cursor and no scroll -- it is painted once and waits for a key -- so one
    # read covers it whole, the "no records yet" case included.
    def self.scores_text(positions)
      return nil unless positions.is_a?(Array)
      rows = {}
      order = []
      positions.each do |cell|
        t = PokeAccess.clean(cell[0].to_s).to_s.strip
        next if t.empty?
        y = cell[2]
        order.push(y) unless rows.has_key?(y)
        rows[y] ||= []
        rows[y].push(t)
      end
      return nil if order.empty?
      order.map { |y| rows[y].join(", ") }.join(". ")
    rescue StandardError
      nil
    end
  end
end

# draw runs when the menu opens and on every cursor move or value change, so it covers the opening read and
# both kinds of change. The value is part of the dedup key: changing a setting leaves the cursor where it is.
PokeAccess::Hooks.after_hook("Ekans_Interface_Main", :draw, :optional => true) do |scene, _r, _a|
  PokeAccess::EkansSnake.row(scene)
end

# Starting a game or opening the records comes back to the same row with the same value, so the redraw that
# follows finds an unchanged key and would place the player nowhere. hook_container because the record
# screen this method opens is itself read by a hook of ours.
PokeAccess::Hooks.after_hook("Ekans_Interface_Main", :do_action, :optional => true, :hook_container => true) do |scene, _r, _a|
  PokeAccess::Cursor.reset(scene, :ekans_row)
end

# The record table is painted inside the constructor, which then blocks until a key closes it, so the point
# where the rows exist and the screen is still up is the method that builds them.
PokeAccess::Hooks.after_hook("Ekans_Interface_Hiscores", :get_text_pos, :optional => true) do |_s, ret, _a|
  t = PokeAccess::EkansSnake.scores_text(ret)
  PokeAccess.speak(t, false) if t
end
