module PokeAccess
  # Infinite Fusion 2's move picker for a fusion (FusionMovesOptionsScene, when setFusionMoves cannot merge the two move
  # sets itself): an options window (Window_PokemonOptionFusionMoves) whose first row takes every move of one of the
  # two Pokemon, the head's on the left and the body's on the right, then four rows of two moves and Confirm. The use
  # key takes or leaves the move under the cursor, painted blue once taken, and a counter keeps how many are taken.
  # Under the list a panel and a box show the focused move's data and description, or the fusion's stats and what the
  # first row takes. The window carries the column from row to row after the options reader has run, so this reader
  # follows it alone.
  module HoennFusionMoves
    # A window's painted text, cleaned; "" when it has none.
    def self.painted(scene, key)
      PokeAccess.clean((PokeAccess.sprite(scene, key).text rescue nil).to_s)
    end

    # The row at i with the cursor on column col: the first row by the line its box paints, a move with its data, an
    # empty slot as such; Confirm by its painted word with the counter, or nil while that word is not kept yet.
    def self.row(scene, i, col)
      win = PokeAccess.sprite(scene, "option")
      return confirm_row(scene, win, i) if i >= (PokeAccess.ivar(win, :@options) || []).length
      return header(scene) if i == 0
      name = cell_name(scene, i, col)
      return empty_slot(scene) if name.empty? || name == "-"
      move_line(scene, i, col, name)
    end

    # Confirm by its painted word with the counter, or nil while that word is not kept yet; the info key gets the same.
    def self.confirm_row(scene, win, i)
      word = PokeAccess::Options.exit_label(win, i)
      return nil unless word
      line = PokeAccess.sentences([word, painted(scene, "counter")])
      PokeAccess::Info.set_info(:text, line)
      line
    end

    # Keeps the fusion's stats the first row paints in the panel (draw_pokemon_info; rows as painted), a label and its
    # value per line, for its info key.
    def self.stats_painted(scene, rows)
      scene.instance_variable_set(:@access_if2_fm_stats, PokeAccess::PaintCapture.lines(rows))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The text the window paints in row i, column col, cleaned.
    def self.cell_name(scene, i, col)
      opts = PokeAccess.ivar(PokeAccess.sprite(scene, "option"), :@options)
      PokeAccess.clean((opts[i].values[col] rescue nil).to_s)
    end

    # The first row by the line its box paints for the column ("Select all moves from X"); the info key gets the
    # fusion's stats its panel paints, or that line where none were kept.
    def self.header(scene)
      line = painted(scene, "textbox")
      stats = PokeAccess.ivar(scene, :@access_if2_fm_stats)
      sheet = stats.is_a?(Array) && !stats.empty? ? PokeAccess.sentences(stats) : line
      PokeAccess::Info.set_info(:text, sheet) unless sheet.empty?
      line
    end

    # An empty slot as such; the info key gets what the box paints for it.
    def self.empty_slot(scene)
      box = painted(scene, "textbox")
      PokeAccess::Info.set_info(:text, box) unless box.empty?
      PokeAccess::I18n.t(:row_empty)
    end

    # A move cell at the learn move reading's level: its name, whether it is taken, then the move's type, category,
    # power, accuracy and PP and the description the box paints; the info key keeps the move whole.
    def self.move_line(scene, i, col, name)
      args = facts(move_at(scene, i, col), painted(scene, "textbox"))
      PokeAccess::Info.set_info(:text, PokeAccess::MoveInfo.line(name, *args))
      PokeAccess::MoveInfo.leveled(:learn_move, label(scene, i, col), *args)
    end

    # MoveInfo's type name, power, accuracy and options (category, PP, description) for a move, from the move data the
    # panel is painted from; a part the data lacks is left out, and with no move only the description stays.
    def self.facts(move, desc)
      id = move ? PokeAccess::MoveInfo.id_of(move) : nil
      return [nil, nil, nil, { :desc => desc }] if id.nil?
      data = PokeAccess::Data
      tot = data.move_total_pp(id)
      tot = nil unless tot.is_a?(Integer) && tot > 0
      [data.move_type_name(id), data.move_power(id), data.move_accuracy(id),
       { :cat => PokeAccess::MoveInfo.category_word(data.move_category(id)), :pp => tot, :total_pp => tot,
         :desc => desc }]
    end

    # The move in row i, column col, or nil: the first row and an empty slot hold none.
    def self.move_at(scene, i, col)
      return nil if i < 1
      (PokeAccess.ivar(scene, :@move_slots)[i - 1][col] rescue nil)
    end

    # Whether the move in row i, column col is among the taken ones.
    def self.taken?(scene, i, col)
      move = move_at(scene, i, col)
      return false if move.nil?
      scene.selected_moves.any? { |m| m.id == move.id }
    end

    # The name a move cell paints, with whether its move is taken.
    def self.label(scene, i, col)
      name = cell_name(scene, i, col)
      taken?(scene, i, col) ? "#{name}, #{PokeAccess::I18n.t(:if2_fm_taken)}" : name
    end

    # What has to change for the cell under the cursor to be said again: the row, the column, or the move taken or
    # left.
    def self.cell_key(scene, idx)
      win = PokeAccess.sprite(scene, "option")
      col = (win[idx] rescue 0).to_i
      [idx, col, taken?(scene, idx, col)]
    end

    # The cell under the cursor. The first read leads with the screen's title and its counter; a read after the use
    # key took or left the move is its name, whether it is taken and the counter.
    def self.cell(scene, idx)
      key = cell_key(scene, idx)
      last = PokeAccess.ivar(scene, :@access_if2_fm)
      line = if last && last[0, 2] == key[0, 2] && last[2] != key[2]
               PokeAccess.sentences([label(scene, idx, key[1]), painted(scene, "counter")])
             else
               row(scene, idx, key[1])
             end
      return nil if line.nil? || line.empty?
      scene.instance_variable_set(:@access_if2_fm, key)
      return line if last
      PokeAccess.sentences([painted(scene, "titleMsg"), painted(scene, "counter"), line])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  # pbUpdate runs each frame of the picker's loop and of its fades, the window's update inside.
  focus_reader("FusionMovesOptionsScene", :on => :pbUpdate, :index => "option", :slot => :if2_fm,
               :hook_container => true,
               :key => lambda { |scene, idx| PokeAccess::HoennFusionMoves.cell_key(scene, idx) }) do |idx, scene|
    PokeAccess::HoennFusionMoves.cell(scene, idx)
  end

  # Left and right are said by the reader above, with the column the window carries over.
  override("PokeAccess::Options", :value_label) do |_mod, original, args|
    fusion = defined?(::Window_PokemonOptionFusionMoves) && args[0].is_a?(::Window_PokemonOptionFusionMoves)
    fusion ? nil : original.call
  end

  # The window paints its rows itself, so the options reader never sees the Confirm word: it is kept here.
  around("Window_PokemonOptionFusionMoves", :drawItem) do |win, nxt, args|
    opts = PokeAccess.ivar(win, :@options)
    if opts.is_a?(Array) && args[0] == opts.length
      ret = nil
      word = PokeAccess::PaintCapture.shadow_sample { ret = nxt.call }.first
      PokeAccess::Options.keep_exit_label(win, args[0], word) if word
      ret
    else
      nxt.call
    end
  end

  around("FusionMovesOptionsScene", :draw_pokemon_info) do |scene, nxt, _a|
    ret = nil
    rows = PokeAccess::PaintCapture.sample { ret = nxt.call }
    PokeAccess::HoennFusionMoves.stats_painted(scene, rows)
    ret
  end
end
