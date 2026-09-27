module PokeAccess
  # The Ekans snake minigame's setup menu (@index over @options, each Symbol named through Ekans_Game.option_name and
  # .rhs_text), its record table, its score during the game, and its pause and game-over panels; where the snake and
  # the berries are is not read.
  module EkansSnake
    def self.row(scene)
      opts = PokeAccess.ivar(scene, :@options)
      i = PokeAccess.ivar(scene, :@index)
      return unless opts.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < opts.length
      c = opts[i]
      name = PokeAccess.clean((Ekans_Game.option_name(c) rescue "").to_s)
      return if name.empty?
      value = PokeAccess.clean((Ekans_Game.rhs_text(c) rescue "").to_s)
      text = value.empty? ? name : "#{name}, #{value}"
      PokeAccess::Cursor.announce(scene, :ekans_row, [i, value], true) { text }
    rescue StandardError
      nil
    end

    # The record table as one spoken block from the array the screen paints, its cells grouped into rows by y.
    def self.scores_text(positions)
      return nil unless positions.is_a?(Array)
      rows = {}
      order = []
      positions.each do |cell|
        t = PokeAccess.clean(cell[0].to_s)
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

# draw runs on open and on every move or value change; the value joins the dedup key, as a change keeps the index.
PokeAccess::Hooks.after_hook("Ekans_Interface_Main", :draw, :optional => true) do |scene, _r, _a|
  PokeAccess::EkansSnake.row(scene)
end

# Back from a game or the records on the same row and value: reset the dedup so the row is said again. A container,
# since the record screen it opens has its own hook.
PokeAccess::Hooks.after_hook("Ekans_Interface_Main", :do_action, :optional => true, :hook_container => true) do |scene, _r, _a|
  PokeAccess::Cursor.reset(scene, :ekans_row)
end

# The record table, read from get_text_pos: the constructor paints it and then blocks until a key.
PokeAccess::Hooks.after_hook("Ekans_Interface_Hiscores", :get_text_pos, :optional => true) do |_s, ret, _a|
  t = PokeAccess::EkansSnake.scores_text(ret)
  PokeAccess.speak(t, false) if t
end

# The pause and game-over panels, whose words exist only in their images: said in the mod's own (lang/).
PokeAccess::Hooks.before_hook("Ekans_Interface_Game", :do_pause_menu, :optional => true) do |_s, _a|
  PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:ekans_pause), PokeAccess::I18n.t(:ekans_pause_hint)), true)
end
PokeAccess::Hooks.before_hook("Ekans_Interface_Game", :lose_game, :optional => true) do |scene, _a|
  n = (PokeAccess.ivar(scene, :@adapter).score rescue nil)
  PokeAccess.speak(PokeAccess::I18n.t(:ekans_gameover, :n => n.to_i), true)
end

# The score line (update_score_display) as painted, captured on each berry that changes it and as the game starts.
PokeAccess::Hooks.around_hook("Ekans_Interface_Game", :update_score_display, :optional => true) do |_s, nxt, _a|
  PokeAccess::PaintCapture.speak_around(:ekans_score, true) { nxt.call }
end
