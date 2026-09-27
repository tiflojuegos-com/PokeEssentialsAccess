module PokeAccess
  # Marin's Diamond/Pearl Pause Menu (DP_PauseMenu; Pokemon Z's "Menu Mejorado"), a sprite menu: its update runs
  # each frame with the cursor in @option and the entries, each [label, ...], in @options.
  module DPMenu
    # Speaks the focused entry on cursor change (deduped per menu instance) through Menus.button_label, sets the info
    # key's trainer answer, and says the panel once.
    def self.read(menu)
      PokeAccess::Info.set_info(:trainer, nil)
      list = PokeAccess.ivar(menu, :@options)
      idx  = PokeAccess.ivar(menu, :@option)
      return unless list.is_a?(Array) && idx && list[idx]
      PokeAccess::Cursor.announce(menu, :dpmenu, idx) do
        PokeAccess::Menus.button_label(list[idx][0])
      end
      panel(list)
    rescue StandardError
      nil
    end

    # The panel the menu painted while it was built (level cap, money, shortcut keys...), said through PausePanel.
    def self.panel(list)
      return unless PokeAccess::PaintCapture.pending?(:dp_panel)
      labels = list.map { |o| o.is_a?(Array) ? o[0] : o }
      PokeAccess::PausePanel.say(PokeAccess::PausePanel.lines(PokeAccess::PaintCapture.take_pairs(:dp_panel), labels))
    end

    @menu = nil

    def self.watch(menu); @menu = menu; end
    def self.unwatch; @menu = nil; end

    # Back from a submenu (MenuReturn), while the menu's loop is held: resets the dedup, so the next update says the
    # focused entry again.
    def self.returned
      PokeAccess::Cursor.reset(@menu, :dpmenu) if @menu
    rescue StandardError
      nil
    end
  end
end

# The menu paints its panel while being built, before main: armed here, taken on the first update.
PokeAccess::Hooks.before_hook("DP_PauseMenu", :initialize, :optional => true) { |_m, _a| PokeAccess::PaintCapture.arm(:dp_panel) }
PokeAccess::Hooks.after_hook("DP_PauseMenu", :update, :optional => true) { |menu, _r, _a| PokeAccess::DPMenu.read(menu) }

PokeAccess::Hooks.around_hook("DP_PauseMenu", :main, :optional => true) do |menu, nxt, _a|
  PokeAccess::DPMenu.watch(menu)
  PokeAccess::MenuReturn.reset_nesting
  begin; nxt.call; ensure; PokeAccess::DPMenu.unwatch; end
end

PokeAccess::MenuReturn.on_return { PokeAccess::DPMenu.returned }

# Pokemon Z's DexNav list (EncounterListUI) opens inside the menu loop without any return seam.
PokeAccess::MenuReturn.bare("EncounterListUI", :initialize, :optional => true)
