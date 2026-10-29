module PokeAccess
  # Rejuvenation's fight menus. Battle command 5 against King and Queen and the A-Gang opens the special-move menu
  # (FightMenuDisplaySpecial), whose ally moves are icons over a list and a PP window kept off screen, with their
  # details panel open (PokeBattle_Scene#pbDrawSpecialMoveDetails); A in the fight menu opens a move's details panel
  # (#pbDrawMoveDetails), its power and accuracy worked out against the foe ahead.
  module RejuvFight
    # The focused ally move, once per move: its name, type and category at the fight line's levels, and its PP where
    # it has a count (the ally moves paint "---"); handed whole to the info key.
    def self.read_special(disp)
      b = PokeAccess.ivar(disp, :@battler)
      idx = PokeAccess.ivar(disp, :@index)
      m = (b.specialmoves[idx] rescue nil)
      return unless m
      PokeAccess::Cursor.on_change(disp, :rj_special_move, [idx, PokeAccess::MoveInfo.id_of(m)]) do
        PokeAccess.speak(PokeAccess::Verbosity.info_line(:battle_move, special_parts(m), ". "), true, :menu)
        PokeAccess::Cursor.store(disp, :rj_named, named_key(b, idx))
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Battler's ally move idx as the menu's line names it, with the frame: pbFightMenuDX draws the panel that follows
    # the line in the frame the cursor moved in, and A opens it in a later one.
    def self.named_key(battler, idx)
      [(battler.index rescue nil), idx, (Graphics.frame_count rescue nil)]
    end

    # The ally move's line as core's fight line parts it: its name, the type its panel paints ("???" as unknown), its
    # category and its PP.
    def self.special_parts(m)
      ty = PokeAccess::DexEntry.unknown_marks(PokeAccess::Data.type_name(m.type))
      PokeAccess::Battle.fight_parts(m, PokeAccess.clean(m.name.to_s), ty, PokeAccess::Battle.fight_pp(m))
    end

    # Runs a panel's paint (the block) and answers [its value, whether it opened, the rows it painted]: drawn while
    # another shows, it is a redraw for the moved cursor (or the Z-Move button).
    def self.paint(scene)
      fresh = !(scene.showingMoveDetails? rescue false)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      [ret, fresh, pairs]
    end

    # The special panel the block paints for battler's ally move idx, said after the menu's line and the move handed
    # whole to the info key; the game's value kept.
    def self.special_panel(scene, battler, idx)
      ret, fresh, pairs = paint(scene) { yield }
      say_special(scene, battler, idx, fresh, pairs)
      ret
    end

    # The fight panel the block paints for move idx, said as it opens or follows the fight line; the game's value kept.
    def self.fight_panel(scene, idx)
      ret, fresh, pairs = paint(scene) { yield }
      say_fight(scene, idx, fresh, pairs)
      ret
    end

    # The special panel's power and "Used" or its charge as painted, then the description; its name only when the
    # menu's line did not just say it, in the same frame (the panel opened with A), cutting in then, queued behind the
    # line otherwise.
    def self.say_special(scene, battler, idx, fresh, pairs)
      figures, desc, _below = laid_out(pairs)
      return unless figures.length == 3
      disp = PokeAccess.sprite(scene, "fightwindowdx")
      named = disp ? PokeAccess::Cursor.current(disp, :rj_named) == named_key(battler, idx) : false
      PokeAccess::Cursor.reset(disp, :rj_named) if disp
      stats = [power(figures[1]), figures[2]].compact.join(", ")
      m = (battler.specialmoves[idx] rescue nil)
      if m
        whole = PokeAccess.sentences([PokeAccess::Verbosity.full_line(special_parts(m), ". "), stats, desc.join(" ")])
        PokeAccess::Info.set_info(:text, whole, whole)
      end
      text = PokeAccess.sentences([named ? nil : figures[0], stats, description(desc)])
      speak_panel(scene, [idx, pairs.map { |r| r[0] }], text, fresh, !named)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The fight panel's power and accuracy against the foe ahead, priority and flags, then the description; the name
    # only as it opens with A, cutting in then, since the fight line names the move or the Z-move standing in for it.
    def self.say_fight(scene, idx, fresh, pairs)
      figures, desc, below = laid_out(pairs)
      return unless figures.length == 4
      flags = below.empty? ? nil : PokeAccess::I18n.t(:dbk_flags, :list => below.join(", "))
      stats = [power(figures[1]), accuracy(figures[2]), priority(figures[3]), flags].compact.join(", ")
      text = PokeAccess.sentences([fresh ? figures[0] : nil, stats, description(desc)])
      speak_panel(scene, [idx, pairs.map { |r| r[0] }], text, fresh, fresh)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says a panel's line once per painted content: always as it opens, and on a redraw only when the rows changed
    # (the special menu repaints the last move's panel when the cursor cannot go further).
    def self.speak_panel(scene, key, text, fresh, interrupt)
      PokeAccess::Cursor.reset(scene, :rj_move_panel) if fresh
      PokeAccess.speak(text, interrupt, :menu) if PokeAccess::Cursor.changed?(scene, :rj_move_panel, key)
    end

    # A panel's painted rows as [top line, description, lower lines]: the top one left to right (the name, then the
    # figures), the description, and what sits below the top line (the fight panel's flags).
    def self.laid_out(pairs)
      lines = PokeAccess::PaintCapture.cells(pairs) { |r| r[1] == :positions }
      desc = pairs.select { |r| r[1] == :dtex }.map { |r| PokeAccess.clean(r[0].to_s) }.reject { |t| t.empty? }
      [lines.first || [], desc, (lines[1..-1] || []).flatten]
    end

    # The painted power: nothing where it has none ("---"), the word for a variable one ("???"), else the figure.
    def self.power(s)
      return nil if s == "---"
      PokeAccess::I18n.t(:mv_power, :p => (s == "???" ? PokeAccess::I18n.t(:mv_power_var) : s))
    end

    # The painted accuracy: the word for a move that never misses ("---"), else the figure.
    def self.accuracy(s)
      PokeAccess::I18n.t(:mv_acc, :a => (s == "---" ? PokeAccess::I18n.t(:mv_acc_perfect) : s))
    end

    # The painted priority, nothing at 0.
    def self.priority(s)
      s == "0" ? nil : PokeAccess::I18n.t(:mv_priority, :n => s)
    end

    # The painted description, while descriptions are said.
    def self.description(desc)
      PokeAccess::Verbosity.descriptions? ? desc.join(" ") : nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  after("FightMenuDisplaySpecial", :battler=, :optional => true) do |disp, _r, _a|
    PokeAccess::Cursor.reset(disp, :rj_special_move)
  end

  after("FightMenuDisplaySpecial", :setIndex, :optional => true) do |disp, _r, _a|
    PokeAccess::RejuvFight.read_special(disp)
  end

  around("PokeBattle_Scene", :pbDrawSpecialMoveDetails, :optional => true) do |scene, nxt, args|
    PokeAccess::RejuvFight.special_panel(scene, args[0], args[1]) { nxt.call }
  end

  around("PokeBattle_Scene", :pbDrawMoveDetails, :optional => true) do |scene, nxt, args|
    PokeAccess::RejuvFight.fight_panel(scene, args[1]) { nxt.call }
  end
end
