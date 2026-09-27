module PokeAccess
  # Insurgence's DexNav (Scene_DexNav): mouse-only picture buttons over a command list kept off screen. The list is
  # claimed, each focus said as its button, and confirm clicks that button through InsurgenceMouse.
  module InsurgenceDexNav
    # Each command's index ivar and the centre of the rectangle update_command tests for its button.
    BUTTONS = [[:@cmdOverworld, [231, 290]], [:@cmdMap, [378, 290]], [:@cmdOnline, [430, 290]],
               [:@cmdMemoryChamber, [482, 290]]]

    # The focused button's name: the scan button's painted caption, an icon by the game's own name for its command.
    def self.label(scene, win, i)
      return PokeAccess::I18n.t(:ins_dexnav_scan) if i == PokeAccess.ivar(scene, :@cmdOverworld)
      PokeAccess::Menus.generic_focus(win, i)
    end

    # The centre of the button a command index stands for, or nil.
    def self.spot(scene, i)
      row = BUTTONS.find { |iv, _xy| PokeAccess.ivar(scene, iv) == i }
      row ? row[1] : nil
    end

    # Before a frame of update_command: says a new focus and, on confirm, arms a click on its button; true when armed.
    def self.frame(scene)
      win = PokeAccess.sprite(scene, "command_window")
      return false unless win
      i = win.index
      PokeAccess::Cursor.announce(scene, :ins_dexnav, i) { label(scene, win, i) }
      return false unless Input.trigger?(Input::C)
      xy = spot(scene, i)
      PokeAccess::InsurgenceMouse.click_at(xy)
      !xy.nil?
    rescue StandardError
      false
    end
  end
end

# The list is claimed before the frame's window update reads it; after a click, what the button opened has run inside
# update_command, and the focus is said again on the way back.
PokeAccess::Game.define("insurgence") do
  before("Scene_DexNav", :update) { |s, _a| PokeAccess.dedicate(PokeAccess.sprite(s, "command_window")) }
  around("Scene_DexNav", :update_command) do |s, nxt, _a|
    clicked = PokeAccess::InsurgenceDexNav.frame(s)
    begin
      nxt.call
    ensure
      PokeAccess::InsurgenceMouse.clear
      PokeAccess::Cursor.reset(s, :ins_dexnav) if clicked
    end
  end
end
