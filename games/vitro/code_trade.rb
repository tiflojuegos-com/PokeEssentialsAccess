# Vitro's trades by code (0388_CodeTrade_BaseUI to 0392_CodeTrade_LogUI, from the event pbTradeMenu): the offer and receive screens
# paint a title, the Pokemon, the code and a menu that MenuHandlers fills under @selected; the manual entry a grid of twelve boxes
# and two commands; the log two lists of trades turned with left and right, and a page for each. Each code is long and random: it is
# left to the info key, and the screen's own option copies it. Everything else they say goes through the game's messages.
module PokeAccess
  module VitroTrade
    # The title and the Pokemon as refreshOverlay paints them.
    def self.panel(scene)
      PokeAccess.sentences([PokeAccess.clean(scene.pbScreenTitle.to_s), PokeAccess.clean(scene.pbPokemonInfoText.to_s)])
    end

    # The held item's icon beside the Pokemon, in words.
    def self.held_item(scene)
      mon = scene.pbDisplayedPokemon
      mon && mon.item > 0 ? PokeAccess::I18n.t(:sum_item, :i => PBItems.getName(mon.item)) : nil
    end

    # The info key: the panel, the item, the code as painted and the option under the cursor.
    def self.publish(scene, row)
      code = scene.pbCodeLines.map { |l| PokeAccess.clean(l.to_s) }.join(" ")
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([panel(scene), held_item(scene), code, row]), row)
    end

    # The panel when a repaint changed it, queued, and the info key with what it now shows.
    def self.painted(scene)
      text = panel(scene)
      PokeAccess::Cursor.announce(scene, :vitro_trade_panel, text, false) { text }
      publish(scene, PokeAccess.ivar(scene, :@access_trade_row))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The option under the cursor as [key, line].
    def self.focus(scene)
      options = scene.pbMenuOptions
      sel = PokeAccess.ivar(scene, :@selected)
      return nil unless sel.is_a?(Integer) && options[sel]
      name = PokeAccess.clean(options[sel][2].to_s)
      [[sel, name], lambda { option_line(scene, name, sel, options.length) }]
    end

    def self.option_line(scene, name, sel, total)
      row = PokeAccess::Verbosity.list_entry(name, sel + 1, total)
      scene.instance_variable_set(:@access_trade_row, row)
      publish(scene, row)
      row
    end

    # The manual entry's focus as [key, line]: a command or a box with what it holds.
    def self.entry_focus(scene)
      box = PokeAccess.ivar(scene, :@boxWindow)
      return nil unless box
      if PokeAccess.ivar(scene, :@focus) == :commands
        idx = PokeAccess.ivar_i(scene, :@cmdIndex)
        return [[:command, idx], lambda { command_line(scene, box, idx) }]
      end
      i = box.cursorIndex
      text = box.boxes[i].to_s
      [[:box, i, text], lambda { box_line(scene, box, i, text) }]
    end

    def self.command_line(scene, box, idx)
      list = ::TradeCodeManualEntry::COMMANDS
      row = PokeAccess::Verbosity.list_entry(PokeAccess.clean(list[idx].to_s), idx + 1, list.length)
      publish_code(box, row)
      row
    end

    def self.box_line(scene, box, i, text)
      word = text.empty? ? PokeAccess::I18n.t(:row_empty) : text
      row = PokeAccess::I18n.t(:vitro_trade_box, :n => i + 1, :tot => box.boxes.length, :text => word)
      publish_code(box, row)
      row
    end

    # The info key in the manual entry: the row, then the whole code it has so far, under the game's word for it.
    def self.publish_code(box, row)
      code = box.getFullCode.to_s
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([row, code.empty? ? nil : "#{_INTL('Código:')} #{code}"]), row)
    end

    READER = PokeAccess::SceneWatcher.reader("TradeUI_Base", :mainLoop, :vitro_trade, :optional => true) do |scene|
      PokeAccess::VitroTrade.focus(scene)
    end
    ENTRY = PokeAccess::SceneWatcher.reader("TradeCodeManualEntry", :pbStart, :vitro_trade_entry, :optional => true) do |scene|
      PokeAccess::VitroTrade.entry_focus(scene)
    end
  end

  module VitroTradeLog
    # The title as the list paints it.
    def self.title(scene)
      tab = PokeAccess.ivar_i(scene, :@current_tab)
      _INTL("{1} Intercambio", (PokeAccess.ivar(scene, :@trade_text) || [])[tab])
    end

    # A row as Window_TradeLog#drawItem paints it: this build has no GameData, so its species is the "???" of its rescue.
    def self.row(win, i)
      entry = (PokeAccess.ivar(win, :@entries) || [])[i]
      unless entry
        empty = PokeAccess::I18n.t(:row_empty)
        PokeAccess::Info.set_info(:text, empty, empty)
        return empty
      end
      species = (GameData::Species.get(entry["species"]).name rescue "???")
      word = entry["type"] == "offer" ? "OFRECIDO" : "RECIBIDO"
      text = _INTL("{1} Nv.{2} - {3}", species, entry["level"] || "?", entry["ot"] || "???")
      line = PokeAccess::DexEntry.unknown_marks(PokeAccess.clean("#{word}: #{text}"))
      PokeAccess::Info.set_info(:text, line, line)
      PokeAccess::Verbosity.list_entry(line, i + 1, PokeAccess.ivar(win, :@entries).length)
    end

    # A page's lines with the trade's code and session ID left out, which run from the code's heading to the date.
    def self.without_code(lines)
      code = false
      lines.reject do |line|
        code = true if line == _INTL("Código:")
        code = false if line.index(_INTL("Fecha: {1}", "")) == 0
        code
      end
    end

    # Each frame while a trade's page is up: what it painted, said once, its lines joined, the code left to the info key,
    # which keeps it all.
    def self.page_poll
      return unless PokeAccess::PaintCapture.pending?(:vitro_trade_page)
      rows = PokeAccess::PaintCapture.take(:vitro_trade_page) || []
      lines = PokeAccess::KeyHints.gate(rows.map { |r| PokeAccess.clean(r) })
      PokeAccess::Info.set_info(:text, PokeAccess.sentences(lines))
      PokeAccess.speak(PokeAccess.sentences(without_code(lines)), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The list's row is said again, as it comes back or shows another list.
    def self.reread(scene)
      win = PokeAccess.sprite(scene, "itemlist")
      PokeAccess::Cursor.reset(win, :cmd_focus) if win
    end
  end
end

PokeAccess::Game.define("vitro") do
  after("TradeUI_Base", :refreshOverlay, :optional => true) { |scene, _r, _a| PokeAccess::VitroTrade.painted(scene) }
  clear_info_on("TradeUI_Base", :disposeUI)
  on_paint("TradeCodeManualEntry", :createUI, :optional => true) do |_scene, pairs, _a|
    line = pairs.find { |row| row[1] == :positions }
    PokeAccess.speak_clean(line[0], false) if line
  end

  screen_reader("Window_TradeLog") { |win, i| PokeAccess::VitroTradeLog.row(win, i) }
  before("TradeLog_Scene", :pbStartScene, :optional => true) do |_scene, _a|
    title = _INTL("{1} Intercambio", _INTL("Mis ofertas"))
    PokeAccess.speak(PokeAccess::Verbosity.with_hint(title, PokeAccess::I18n.t(:vitro_tradelog_keys)), false)
  end
  after("TradeLog_Scene", :swapTab, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess.speak(PokeAccess::VitroTradeLog.title(scene), true)
    PokeAccess::VitroTradeLog.reread(scene)
  end
  before("TradeLog_Scene", :pbShowTradeDetails, :optional => true) { |_scene, _a| PokeAccess::PaintCapture.arm(:vitro_trade_page) }
  after("TradeLog_Scene", :pbShowTradeDetails, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::PaintCapture.take(:vitro_trade_page)
    PokeAccess::Info.clear_text
    PokeAccess::VitroTradeLog.reread(scene)
  end
  poll_each_frame { PokeAccess::VitroTradeLog.page_poll }
  clear_info_on("TradeLog_Scene", :pbEndScene)
end

PokeAccess::MenuReturn.bare_fn("pbFakeSummary")
PokeAccess::MenuReturn.on_return { PokeAccess::Cursor.reset(PokeAccess::VitroTrade::READER, :vitro_trade) }
