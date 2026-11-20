# The Temple of Mutios (map 257): a grid of 90 tiles (x 66 to 74, y 16 to 25), 52 of them "Correct" and 38 "inCorrect",
# which look the same. A correct tile vanishes and adds one to variable 42; a wrong one is forgiven while variable 41 is
# below 3 and sends the player out of the grid after that. The 52nd opens the way (self switch A of event 74). The
# boulders are pushed by the core's routes. The clues of the picross are pictures of digits made of events beside the grid:
# the rows' on its east side (events at x 75 to 77, first block nearest the grid) and the columns' below it (events at y 26
# to 29), read here off the events' graphics and said in the info key, with the row and column the player stands on. A
# button A press on a tile flags it, which the game does for the player. Each clue is named by its digit, and the free
# camera says a grid tile's row and column, flagged or gone as it shows.
module PokeAccess
  module UraniumMutios
    # The grid's box of tiles, as [x0, x1, y0, y1].
    def self.grid; [66, 74, 16, 25]; end

    # Whether the player stands within a few tiles of the grid.
    def self.near?
      x0, x1, y0, y1 = grid
      $game_player.x.between?(x0 - 8, x1 + 8) && $game_player.y.between?(y0 - 8, y1 + 8)
    end

    # Whether the player has come near the grid this session, which opens the rule's phase for good.
    def self.approached?
      @approached = true if near?
      @approached ? true : false
    end

    # Forgets that the player came near the grid.
    def self.forget; @approached = false; end

    # The rule of the grid, with the keys as the player has them: C works a tile, and held with the game's A (Z, as its
    # own sign says) flags it.
    def self.rule
      keys = PokeAccess::KeyHints
      PokeAccess::I18n.t(:ura_pp_picross_rule, :act => keys.key(:c, "C"), :flag => keys.key(:a, "Z"))
    end

    def self.sheet; { 2 => [nil, 1, 2, 3], 4 => [4, 5, 6, 7], 6 => [8, 9, nil, nil] }; end

    # The digit an event's graphic shows from the picross' sheet of digits, or nil.
    def self.digit(ev)
      page = PokeAccess.ivar(ev, :@page)
      graphic = page && page.graphic
      return nil unless graphic && graphic.character_name == "bingo"
      (sheet[graphic.direction] || [])[graphic.pattern]
    end

    # The digits the events beside the grid show, as [rows, columns]: each a hash from the row's or column's tile to its
    # digits, nearest the grid first.
    def self.clues
      x0, x1, y0, y1 = grid
      rows = {}
      cols = {}
      ($game_map.events || {}).each_value do |ev|
        value = digit(ev)
        next unless value
        if ev.x > x1 && ev.y.between?(y0, y1)
          (rows[ev.y] ||= []).push([ev.x, value])
        elsif ev.y > y1 && ev.x.between?(x0, x1)
          (cols[ev.x] ||= []).push([ev.y, value])
        end
      end
      [rows, cols]
    end

    # One line of clues: its number and the digits in order, or none.
    def self.line(key, number, entries)
      digits = (entries || []).sort.map { |entry| entry[1] }
      PokeAccess::I18n.t(key, :n => number, :clues => digits.join(", "))
    end

    # The clues of every row, top to bottom, and of every column, left to right.
    def self.clue_lines
      x0, x1, y0, y1 = grid
      rows, cols = clues
      row_lines = (y0..y1).map { |y| line(:ura_pp_picross_row, y - y0 + 1, rows[y]) }
      col_lines = (x0..x1).map { |x| line(:ura_pp_picross_col, x - x0 + 1, cols[x]) }
      [PokeAccess::I18n.t(:ura_pp_picross_rows, :list => row_lines.join("; ")),
       PokeAccess::I18n.t(:ura_pp_picross_cols, :list => col_lines.join("; "))]
    end

    # Whether (x, y) is a tile of the grid.
    def self.on_grid?(x, y)
      x0, x1, y0, y1 = grid
      x.between?(x0, x1) && y.between?(y0, y1)
    end

    # The row and column of a tile, by default the one the player stands on, or nil outside the grid.
    def self.place(x = $game_player.x, y = $game_player.y)
      return nil unless on_grid?(x, y)
      x0, _x1, y0, _y1 = grid
      PokeAccess::I18n.t(:ura_pp_picross_place, :row => y - y0 + 1, :col => x - x0 + 1)
    end

    # What the free camera says of a grid tile: its row and column, then flagged, or gone once a correct one is worked.
    def self.cell_lines(x, y)
      cell = $game_map.events.values.find { |ev| ev.x == x && ev.y == y && ev.name.to_s =~ /\A(?:in)?Correct\z/ }
      state = if cell && !drawn?(cell) then :mg_tile_clear
              elsif cell && $game_self_switches[[257, cell.id, "A"]] then :mg_marked
              end
      [place(x, y), state ? PokeAccess::I18n.t(state) : nil]
    end

    # A clue's name: the digit it shows, with its row or column; nil for any other event.
    def self.clue_label(ev)
      value = digit(ev)
      return nil unless value
      x0, x1, y0, y1 = grid
      return [:ura_pp_picross_row, { :n => ev.y - y0 + 1, :clues => value }] if ev.x > x1 && ev.y.between?(y0, y1)
      return [:ura_pp_picross_col, { :n => ev.x - x0 + 1, :clues => value }] if ev.y > y1 && ev.x.between?(x0, x1)
      nil
    end

    # The info key's line: where the player stands on the grid, then the clues.
    def self.info
      PokeAccess.sentences([place] + clue_lines)
    end

    # Whether a tile still shows: the acolyte's hint takes the picture off six correct tiles, already counted, and leaves
    # their events, which would count again if used.
    def self.drawn?(ev)
      ev.tile_id.to_i > 0 || ev.character_name.to_s != ""
    end

    # Whether the 52 correct tiles are done and the way is open.
    def self.solved?
      $game_self_switches[[257, 74, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("uranium") do
  mutios = PokeAccess::UraniumMutios
  mechanic(:state, 257) do
    auto
    name(/\ACorrect\z/, :ura_pp_picross_cell, :assist => true, :when => lambda { |ev| PokeAccess::UraniumMutios.drawn?(ev) })
    name(/\Abingo\z/, lambda { |ev| mutios.clue_label(ev) }, :when => false)
    hide(/\AinCorrect\z/)
    count :ura_pp_picross_done, :var => 42, :of => 52
    phase lambda { PokeAccess::UraniumMutios.approached? && !PokeAccess::UraniumMutios.solved? },
          :title => lambda { PokeAccess::UraniumMutios.rule }
    active { PokeAccess::UraniumMutios.near? }
    info { PokeAccess::UraniumMutios.info }
    solved(nil) { PokeAccess::UraniumMutios.solved? }
  end
  camera_tile(:maps => [257], :tiles => lambda { |x, y| mutios.on_grid?(x, y) }) { |x, y| mutios.cell_lines(x, y) }
end
