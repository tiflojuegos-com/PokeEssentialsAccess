# Colour-code door puzzle (ColorCodeDoor, 053_PIF_Hoenn/Gameplay/Puzzles/ColorCodeDoor.rb). Six cells in a
# 2x3 grid plus a confirm button; each cell shows one of four colours as a picture and there is no text
# anywhere, so the puzzle is unsolvable without sight. The cursor (@cursor_index, 0..5 over the cells and
# COLS*ROWS for confirm) and the current combination (@current_code, one letter per cell) are plain ivars,
# and handle_input runs on every keypress, so reading there covers both moving and recolouring a cell.
module PokeAccess
  module IF2ColorDoor
    COLOR_KEYS = { "R" => :if2_col_red, "B" => :if2_col_blue, "G" => :if2_col_green, "Y" => :if2_col_yellow }

    # The spoken name of a colour letter, or the letter itself if the game adds one we do not know.
    def self.color_name(ch)
      k = COLOR_KEYS[ch.to_s]
      k ? PokeAccess::I18n.t(k) : ch.to_s
    end

    # Speaks the focused cell (row/column plus its colour) or the confirm button, once per change.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@cursor_index)
      code = PokeAccess.ivar(scene, :@current_code)
      return unless idx.is_a?(Integer) && code.is_a?(Array)
      rows = (ColorCodeDoor::ROWS rescue 3)
      confirm = (ColorCodeDoor::CONFIRM_INDEX rescue code.length)
      key = [idx, code.join]
      PokeAccess::Cursor.announce(scene, :if2_door, key, true) do
        if idx >= confirm
          PokeAccess::I18n.t(:if2_door_confirm, :code => code.map { |c| color_name(c) }.join(", "))
        else
          PokeAccess::I18n.t(:if2_door_cell, :row => (idx % rows) + 1, :col => (idx / rows) + 1,
                             :color => color_name(code[idx]))
        end
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("ColorCodeDoor", :handle_input) { |s, _r, _a| PokeAccess::IF2ColorDoor.focus(s) }
end
