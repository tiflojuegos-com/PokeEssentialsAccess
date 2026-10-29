module PokeAccess
  # Dark Horizon's new game (pbStartNewGame): the difficulty panel (EasyHardModeWindow, Easy or Hard Mode switched with
  # left and right), the Randomizer and Nuzlocke panels (a question on accept), then the introduction's pages
  # (GameIntroduction) and the TV report's (TV_Window, also shown by map events). Every panel and page is painted
  # with pbDrawTextPositions and said as painted.
  module DHNewGame
    # The bullet the panels paint before each rule.
    BULLET = /\A\s*[■•]\s*/

    # A panel's painted rows as one text: its title, then each rule without its bullet.
    def self.panel_text(rows)
      PokeAccess.sentences(PokeAccess::PaintCapture.laid_out(rows).map { |t| PokeAccess.clean(t.to_s.sub(BULLET, "")) })
    end

    # Runs a panel's paint, the block, and says what it painted (say_panel); answers the paint's value.
    def self.panel(scene, key, hint)
      ret = nil
      rows = PokeAccess::PaintCapture.sample { ret = yield }
      say_panel(scene, key, hint, rows)
      ret
    end

    # Says a panel's rows when key changed: the first time queued, with how to answer (the i18n key hint) while hints
    # are said, later cutting in; the info key keeps the panel.
    def self.say_panel(scene, key, hint, rows)
      first = PokeAccess::Cursor.pending?(scene, :dh_panel)
      PokeAccess::Cursor.announce(scene, :dh_panel, key, true, false) do
        t = panel_text(rows)
        PokeAccess::Info.set_info(:text, t, t) unless t.empty?
        first ? PokeAccess::DarkHorizon.hinted(t, PokeAccess::I18n.t(hint, :key => PokeAccess::KeyHints.key(:c, "C"))) : t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs a page's paint, the block, and says the page it painted (say_page); answers the paint's value.
    def self.page(scene)
      ret = nil
      rows = PokeAccess::PaintCapture.sample { ret = yield }
      say_page(scene, rows)
      ret
    end

    # Says a page when it turned: its lines run together, as the game breaks its sentences across them; the first page
    # queued and each next one, turned by the player, cutting in. The info key keeps the page.
    def self.say_page(scene, rows)
      t = PokeAccess.clean(PokeAccess::PaintCapture.laid_out(rows).join(" "))
      return if t.empty?
      first = PokeAccess::Cursor.pending?(scene, :dh_page)
      key = [PokeAccess.ivar(scene, :@introPhaseCnt), PokeAccess.ivar(scene, :@txtCnt)]
      return unless PokeAccess::Cursor.changed?(scene, :dh_page, key)
      PokeAccess::Info.set_info(:text, t, t)
      PokeAccess.speak(t, !first, :dialogue)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  # pbUpdateText repaints the panel every frame; it changes with the mode left and right switch.
  around("EasyHardModeWindow", :pbUpdateText) do |scene, nxt, _a|
    mode = PokeAccess.ivar(scene, :@modeSelected) ? :hard : :easy
    PokeAccess::DHNewGame.panel(scene, mode, :dh_mode_switch_hint) { nxt.call }
  end

  # The Randomizer and Nuzlocke panels never change; pbUpdateSprites repaints them every frame of their loop.
  %w[RandomizerWindow NuzlockeWindow].each do |cname|
    around(cname, :pbUpdateSprites) do |scene, nxt, _a|
      PokeAccess::DHNewGame.panel(scene, cname, :dh_mode_ask_hint) { nxt.call }
    end
  end

  # pbTextUpdate paints the next page and counts it.
  %w[GameIntroduction TV_Window].each do |cname|
    around(cname, :pbTextUpdate) do |scene, nxt, _a|
      PokeAccess::DHNewGame.page(scene) { nxt.call }
    end
  end

  # A panel or page, on the info key and as last said, goes with its screen.
  %w[EasyHardModeWindow RandomizerWindow NuzlockeWindow].each do |cname|
    before(cname, :pbEndScene) do |scene, _a|
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(scene, :dh_panel)
    end
  end
  %w[GameIntroduction TV_Window].each do |cname|
    before(cname, :pbEndScene) do |scene, _a|
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(scene, :dh_page)
    end
  end
end
