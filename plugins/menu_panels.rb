module PokeAccess
  # PokéLiberty's simple panel menus (MenuPanel1#Panel1 and MenuPanel2#Panel2, a template a game copies into more
  # panels): boards of icons with a caption each, "???" while locked, repainted every frame of the panel's own loop;
  # each panel is read once as it opens, in the order the script writes it; down and up switch panels.
  module MenuPanels
    TAG = :menu_panel

    @open = 0

    # Runs one panel's loop with its first frame's paint captured; the capture goes with the panel, said or not.
    def self.showing
      @open += 1
      PokeAccess::PaintCapture.arm(TAG)
      yield
    ensure
      @open -= 1
      PokeAccess::PaintCapture.take(TAG) if PokeAccess::PaintCapture.armed?(TAG)
    end

    # Says a panel's first painted frame once it lands, while a panel's loop runs: its title, its counter and each
    # caption, a "???" said as unknown (a screen reader drops question marks); with key hints on, how to switch panels.
    def self.poll
      return unless @open > 0 && PokeAccess::PaintCapture.pending?(TAG)
      rows = (PokeAccess::PaintCapture.take(TAG) || []).map { |r| PokeAccess::DexEntry.unknown_marks(r) }
      t = PokeAccess::PaintCapture.text(rows, false)
      return if t.empty?
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(t, PokeAccess::I18n.t(:mpanel_hint)), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# Each panel method is a whole panel with its loop; a switch opens the other one from inside it.
PokeAccess::Hooks.around_hook("MenuPanel1", :Panel1, :optional => true) do |_s, nxt, _a|
  PokeAccess::MenuPanels.showing { nxt.call }
end
PokeAccess::Hooks.around_hook("MenuPanel2", :Panel2, :optional => true) do |_s, nxt, _a|
  PokeAccess::MenuPanels.showing { nxt.call }
end

PokeAccess::Frame.each_pulse { PokeAccess::MenuPanels.poll }
