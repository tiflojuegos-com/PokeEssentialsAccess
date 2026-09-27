module PokeAccess
  # The moveset restorer of the engine Reborn, Rejuvenation and Desolation share (MoveRestorerScene): the Pokemon's
  # stored sets in a list, and beside it a panel with the focused set's moves, both repainted by pbSetList on each
  # cursor move; a menu of its own (pbShowCommands) asks what to do with the set chosen. The list's bare name is
  # muted: each repaint says the set with its moves, the first after the question at the top.
  module MoveRestorerRV
    # The moves panel as a column of moves: left of the list, from y 80.
    PANEL = [0, 250, 80]

    # The question painted above the panel.
    def self.question(pairs)
      top = pairs.select { |r| r[3].is_a?(Numeric) && r[3] < PANEL[2] && r[2].to_i < PANEL[1] }
      top.map { |r| PokeAccess.clean(r[0]) }
    end

    # What the repaint shows: on opening the question painted at the top, then the focused set and its moves.
    # param opening true for the first repaint of the scene
    def self.text(scene, pairs, icons, opening)
      list = PokeAccess.sprite(scene, "commands")
      moves = PokeAccess::SummaryRV.slots(pairs, icons, PANEL).compact.map { |s| PokeAccess::SummaryRV.slot_line(s) }
      parts = opening ? question(pairs) : []
      parts.push(list ? PokeAccess::Menus.focused_text(list) : nil)
      parts.push(PokeAccess::I18n.t(:sm_moves, :list => moves.join(", "))) unless moves.empty?
      PokeAccess.sentences(parts.compact)
    end

    # Hooks the repaint, muting the list's own read, and the menu's question.
    def self.bind
      PokeAccess::Hooks.around_hook("MoveRestorerScene", :pbSetList, :optional => true) do |scene, nxt, _a|
        r = nil
        pairs = nil
        icons = PokeAccess::PaintCapture.icon_rows { pairs = PokeAccess::PaintCapture.sample { r = nxt.call } }
        PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
        opening = !PokeAccess.ivar(scene, :@access_restorer_open)
        scene.instance_variable_set(:@access_restorer_open, true)
        t = PokeAccess::MoveRestorerRV.text(scene, pairs, icons, opening)
        PokeAccess.speak(t, !opening) unless t.empty?
        r
      end
      PokeAccess::Hooks.before_hook("MoveRestorerScene", :pbShowCommands, :optional => true) do |_scene, args|
        PokeAccess.say_screen_message(args)
      end
    end
  end
end

PokeAccess::MoveRestorerRV.bind if PokeAccess::DataRV.engine?
