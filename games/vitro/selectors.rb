# Vitro's selectors of the new game: AdvSelector and its SandboxSelector (0328, 0331, common event 26) and LockeSelector and RandomConfig
# (0329, 0330, map 1), which paint all their rows once as they are built, title above and each option with its description below,
# and move @selected over them. The last two tick options with a sprite whose src_rect shows the mark; any of their code may tick
# or clear one, so its state is read, not the toggle. Their questions go through the game's messages.
module PokeAccess
  module VitroSelectors
    # Above this line a row is the title (Y_TOP in all four).
    OPTIONS_TOP = 48
    # Where the check sprite's src_rect stands when ticked.
    TICKED_X = 20

    # The rows the build painted, as [label, description] on the scene; its title said as the screen comes up.
    def self.built(scene, pairs)
      rows = pairs.select { |r| r[3].is_a?(Numeric) }
      labels = rows.select { |r| r[1] == :positions && r[3] >= OPTIONS_TOP }.sort_by { |r| r[3] }
      notes = rows.select { |r| r[1] == :formatted }
      list = []
      labels.each_with_index do |r, i|
        below = labels[i + 1]
        note = notes.find { |n| n[3] > r[3] && (below.nil? || n[3] < below[3]) }
        list.push([PokeAccess.clean(r[0]), note ? PokeAccess.clean(note[0]) : nil])
      end
      scene.instance_variable_set(:@access_rows, list)
      title = rows.find { |r| r[1] == :positions && r[3] < OPTIONS_TOP }
      text = title ? PokeAccess.clean(title[0]) : nil
      scene.instance_variable_set(:@access_title, text)
      PokeAccess.speak(text, false) if text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # An option's tick: true or false, nil for one with no check.
    def self.tick(scene, i)
      check = PokeAccess.sprite(scene, "ch#{i}")
      check ? check.src_rect.x == TICKED_X : nil
    end

    # The option under the cursor as [key, line], given the watcher that said the last one: a change of its tick says just the
    # new state.
    def self.focus(scene, holder)
      rows = PokeAccess.ivar(scene, :@access_rows)
      sel = PokeAccess.ivar(scene, :@selected)
      return nil unless rows.is_a?(Array) && sel.is_a?(Integer) && rows[sel]
      on = tick(scene, sel)
      prev = PokeAccess::Cursor.current(holder, :vitro_selector)
      same = prev.is_a?(Array) && prev[0] == sel
      [[sel, on], lambda { line(scene, rows, sel, on, same) }]
    end

    def self.line(scene, rows, sel, on, same)
      word = on.nil? ? nil : PokeAccess::I18n.t(on ? :mk_on : :mk_off)
      entry = [PokeAccess::Verbosity.list_entry(rows[sel][0], sel + 1, rows.length), word].compact.join(", ")
      whole = PokeAccess.sentences([entry, rows[sel][1]])
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([PokeAccess.ivar(scene, :@access_title), whole]), entry)
      return word if same
      PokeAccess::Verbosity.descriptions? ? whole : entry
    end

    READERS = {}
    %w[AdvSelector SandboxSelector LockeSelector RandomConfig].each do |cname|
      READERS[cname] = PokeAccess::SceneWatcher.reader(cname, :show, :vitro_selector, :optional => true) do |scene|
        PokeAccess::VitroSelectors.focus(scene, READERS[cname])
      end
    end

    # Back from a question: the option is said again.
    def self.returned
      READERS.each_value { |reader| PokeAccess::Cursor.reset(reader, :vitro_selector) }
    end
  end
end

PokeAccess::Game.define("vitro") do
  %w[AdvSelector SandboxSelector LockeSelector RandomConfig].each do |cname|
    on_paint(cname, :initialize, :optional => true) do |scene, pairs, _a|
      PokeAccess::VitroSelectors.built(scene, pairs)
    end
    # A fade holds the last two whole: their questions count from their loop.
    before(cname, :show, :optional => true) { |_scene, _a| PokeAccess::MenuReturn.reset_nesting }
    after(cname, :show, :optional => true, :hook_container => true) { |_scene, _r, _a| PokeAccess::Info.clear_text }
  end
end

PokeAccess::MenuReturn.on_return { PokeAccess::VitroSelectors.returned }
