# World Frontier's "Datos" (pbTarjetasMenu, from the pause menu): a hub of two panels, the player's card and its
# statistics, all painted on overlays. The hub says its title and the focused panel; the card says what it paints in
# its logical order; the statistics say the rows each scroll brings into view.
module PokeAccess
  module WfCards
    # The hub's panels by @index, as painted.
    def self.panel(idx)
      idx == 0 ? _INTL("MIS DATOS") : _INTL("ÁLBUM")
    end

    # After each repaint of the hub: the title as it opens and the focused panel when it changes, the keys after it
    # while hints are said.
    def self.hub(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return unless idx.is_a?(Integer)
      opening = PokeAccess::Cursor.pending?(scene, :wf_hub_open)
      PokeAccess::Cursor.store(scene, :wf_hub_open, true)
      return unless PokeAccess::Cursor.changed?(scene, :wf_hub, idx)
      line = PokeAccess::Verbosity.list_entry(panel(idx), idx + 1, 2)
      if opening
        keys = [:USE, :BACK].map { |k| (scene.key_name(k) rescue "?") }
        hint = _INTL("Izq./Der.: Elegir        [{1}]: Entrar        [{2}]: Salir", *keys)
        line = PokeAccess::WfHint.after(PokeAccess.sentences([_INTL("DATOS DEL JUEGO"), line]), hint)
      end
      PokeAccess.speak_clean(line, !opening)
    end

    # The card's text as painted (rows of [text, source, x, y] in paint order: the title, each label and its value,
    # the footer), its labels paired with their values.
    def self.card_text(rows)
      texts = rows.map { |r| r[0].to_s }
      return nil if texts.length < 2
      pairs = []
      body = texts[1..-2]
      (0...(body.length / 2)).each { |i| pairs.push("#{body[2 * i]}: #{body[2 * i + 1]}") }
      PokeAccess.sentences([texts[0]] + pairs)
    end

    # The card's repaint: the whole card the first time, its title when it shows again after the statistics; the keys
    # after it while hints are said; the info key holds the card.
    def self.card(scene, rows)
      text = card_text(rows)
      return unless text
      PokeAccess::Info.set_info(:text, PokeAccess.clean(text))
      first = PokeAccess::Cursor.pending?(scene, :wf_card)
      PokeAccess::Cursor.store(scene, :wf_card, true)
      line = first ? PokeAccess::WfHint.after(text, rows[-1][0].to_s) : rows[0][0].to_s
      PokeAccess.speak_clean(line, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A statistics row as painted, label and value.
    def self.stat_row(lines, i)
      row = lines[i]
      row.is_a?(Array) ? "#{row[0]}: #{row[1]}" : nil
    end

    # After each repaint of the statistics: the title and the rows in view as they open, then the row a scroll brings
    # in (the new bottom row going down, the new top row going up, the whole view when it wraps around).
    def self.stats(scene)
      lines = PokeAccess.ivar(scene, :@lines)
      scroll = PokeAccess.ivar(scene, :@scroll)
      lay = PokeAccess.ivar(scene, :@layout)
      return unless lines.is_a?(Array) && scroll.is_a?(Integer) && lay.is_a?(Hash)
      visible = lay[:visible].to_i
      PokeAccess::Info.set_info(:text, PokeAccess.clean(PokeAccess.sentences((0...lines.length).map { |i| stat_row(lines, i) })))
      before = PokeAccess::Cursor.current(scene, :wf_stats)
      return unless PokeAccess::Cursor.changed?(scene, :wf_stats, scroll)
      view = (scroll...[scroll + visible, lines.length].min).map { |i| stat_row(lines, i) }
      if before.nil?
        hint = _INTL("Arriba/Abajo: Desplazar        [{1}]: Volver", (scene.key_name(:BACK) rescue "X"))
        PokeAccess.speak_clean(PokeAccess::WfHint.after(PokeAccess.sentences([_INTL("ESTADÍSTICAS")] + view), hint), false)
      elsif scroll == before + 1
        i = scroll + visible - 1
        PokeAccess.speak_clean(PokeAccess::Verbosity.list_entry(stat_row(lines, i), i + 1, lines.length), true) if lines[i]
      elsif scroll == before - 1
        PokeAccess.speak_clean(PokeAccess::Verbosity.list_entry(stat_row(lines, scroll), scroll + 1, lines.length), true)
      else
        PokeAccess.speak_clean(PokeAccess.sentences(view), true)
      end
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("TarjetasHub_Scene", :refresh) { |scene, _r, _a| PokeAccess::WfCards.hub(scene) }
  # Back from a panel the hub repaints: the focused panel is said again.
  after("TarjetasHub_Scene", :show_after_child) { |scene, _r, _a| PokeAccess::Cursor.reset(scene, :wf_hub) }
  around("TarjetasPlayerCard_Scene", :refresh) do |scene, nxt, _a|
    ret = nil
    rows = PokeAccess::PaintCapture.sample { ret = nxt.call }
    PokeAccess::WfCards.card(scene, rows)
    ret
  end
  after("TarjetasPlayerStats_Scene", :refresh) { |scene, _r, _a| PokeAccess::WfCards.stats(scene) }
end
