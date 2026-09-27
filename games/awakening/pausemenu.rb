module PokeAccess
  # Awakening's Fates pause menu (JessFatesMenu, a blocking loop inside initialize): a strip of FatesMenuPanels,
  # each read by its @nombre on cambio(true), the initially focused one (@pnl.src_rect.y == 37) as it is created.
  module AwakeningPause
    # Reads a panel that has just become focused via cambio(true).
    def self.panel_changed(panel, focused)
      say_panel(panel) if focused == true
    end

    # Reads a new panel if it is the initially focused one (sprite row 37), then the menu's top bar.
    def self.panel_created(panel)
      hl = (panel.instance_variable_get(:@pnl).src_rect.y rescue 0)
      return unless hl == 37
      say_panel(panel)
      PokeAccess::PausePanel.say(bar_lines(@menu)) if @menu
    rescue StandardError
      nil
    end

    # Speaks a panel's name, and remembers it so the return below has something to repeat. The save panel
    # is drawn dimmed where the game forbids saving ($Fates_save), and says so.
    def self.say_panel(panel)
      nm = PokeAccess.ivar(panel, :@nombre)
      return if nm.nil? || nm.to_s.empty?
      @last = nm.to_s
      @last = "#{@last}, #{PokeAccess::I18n.t(:opt_unavailable)}" if PokeAccess.ivar(panel, :@index) == SAVE && $Fates_save == false
      PokeAccess.speak_clean(@last, true)
    rescue StandardError
      nil
    end

    SAVE = 5

    # The day-time picture's frame (dianoche) by its x in the strip.
    DAYTIME = { 0 => :awk_night, 64 => :awk_day, 128 => :awk_morning, 192 => :awk_evening }

    # The shortcut icons along the bottom, each with the letter it carries; hidden until the story opens it.
    SHORTCUTS = [["0", :awk_key_quests], ["1", :awk_key_class], ["2", :awk_key_gacha]]

    # The top bar (counters, map, name and money as written, the day-time picture) and, with hints on, the
    # shortcuts; no clock (see PausePanel).
    def self.bar_lines(menu)
      lines = [:@act, :@map, :@nom, :@dinero].map { |iv| (PokeAccess.ivar(menu, iv).vtxt rescue nil) }
      day = DAYTIME[(PokeAccess.ivar(menu, :@dia).src_rect.x rescue nil)]
      lines.push(PokeAccess::I18n.t(day)) if day
      lines.concat(shortcut_lines(menu)) if PokeAccess::Verbosity.hints?
      lines.compact
    end

    # The shortcut icons shown, each as its key and what it opens (the third opens the talismans once switch 650
    # is on; F's achievements one is always there).
    def self.shortcut_lines(menu)
      icons = PokeAccess.ivar(menu, :@icons) || {}
      out = []
      SHORTCUTS.each do |slot, key|
        next unless (icons[slot].visible rescue false)
        key = :awk_key_talisman if key == :awk_key_gacha && ($game_switches[650] rescue false)
        out.push(PokeAccess::I18n.t(key))
      end
      out.push(PokeAccess::I18n.t(:awk_key_achievements))
    end

    @depth = 0
    @last = nil
    @menu = nil

    # Enters the menu (nested opens counted), holding the JessFatesMenu being built for its bar.
    def self.open!(menu = nil)
      @depth += 1
      @menu = menu if menu
    end

    def self.close!
      @depth -= 1 if @depth > 0
      return unless @depth == 0
      @last = nil
      @menu = nil
    end

    # Repeats the focused panel on returning from a submenu (cambio does not fire again); three submenus are
    # called without pbFadeOutIn, so they are declared to MenuReturn by name below.
    def self.returned
      PokeAccess.speak_clean(@last, true) if @depth > 0 && @last
    rescue StandardError
      nil
    end

    # The menu disposed while its constructor still runs (saving, a field move...): nothing left to repeat.
    def self.gone!
      @last = nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("FatesMenuPanels", :initialize) do |panel, _r, _a|
    PokeAccess::AwakeningPause.panel_created(panel)
  end
  after("FatesMenuPanels", :cambio) do |panel, _r, args|
    PokeAccess::AwakeningPause.panel_changed(panel, args[0])
  end
  # JessFatesMenu runs its whole screen from the constructor, so that is what is held.
  around("JessFatesMenu", :initialize, :optional => true) do |menu, nxt, _a|
    PokeAccess::AwakeningPause.open!(menu)
    PokeAccess::MenuReturn.reset_nesting
    begin; nxt.call; ensure; PokeAccess::AwakeningPause.close!; end
  end
  ["pbQuestlog", "pbEquipScreen", "openGacha"].each { |fn| PokeAccess::MenuReturn.bare_fn(fn) }
  before("JessFatesMenu", :dispose, :optional => true) { |_m, _a| PokeAccess::AwakeningPause.gone! }
end

PokeAccess::MenuReturn.on_return { PokeAccess::AwakeningPause.returned }
