module PokeAccess
  # Sevii's Elite Battle System in its Next Generation style, whose classes replace the display classes the gen-6 core
  # reads: the command buttons (NextGenCommandWindow), the move buttons with the Mega Evolution button
  # (NextGenFightWindow) and the marks a databox paints (NextGenDataBox). The prompt with its party balls and the
  # question boxes are plugins/ebs_ui.rb's.
  module SeviiBattle
    # The switch that keeps the Mega Evolution button down whatever the battler could do.
    MEGA_HIDDEN_SWITCH = 168

    # Runs a refreshCommands keeping the four labels it paints, in button order, and resets the command cursor.
    def self.paint_commands(cw)
      @labels = []
      ret = yield
      cw.instance_variable_set(:@access_sv_cmds, @labels) unless @labels.empty?
      PokeAccess::Cursor.reset(cw, :sv_cmd)
      PokeAccess::Info.set_info(:battle_foe, nil)
      ret
    ensure
      @labels = nil
    end

    # Keeps a text pbDrawOutlineText paints while a refreshCommands runs: one button's label.
    def self.painted(text)
      @labels.push(PokeAccess.clean(text.to_s)) if @labels
    end

    # Marks the move buttons as set up for a battler: the next update reads the focused move afresh, queued, and the
    # Mega Evolution button starts off, as pbFightMenu's own flag does.
    def self.fight_opened(cw)
      PokeAccess::Cursor.reset(cw, :fight_move)
      cw.instance_variable_set(:@access_sv_open, true)
      cw.instance_variable_set(:@access_sv_mega, false)
    end

    # Reads the focused move on change; on opening, queued and followed by the Mega Evolution button when it is up.
    def self.fight_update(cw)
      opening = PokeAccess.ivar(cw, :@access_sv_open)
      cw.instance_variable_set(:@access_sv_open, false) if opening
      PokeAccess::Battle.read_fight_move(cw, !opening)
      PokeAccess.speak(PokeAccess::Battle.ready_text(:mega), false) if opening && mega_up?(cw)
    end

    # True while the Mega Evolution button is up for a battler that can mega evolve, which pbFightMenu raises only
    # with the hiding switch off.
    def self.mega_up?(cw)
      b = PokeAccess.ivar(cw, :@battler)
      battle = PokeAccess.ivar(cw, :@battle)
      return false unless PokeAccess.ivar(cw, :@showMega) && b && battle
      return false if $game_switches && $game_switches[MEGA_HIDDEN_SWITCH]
      battle.pbCanMegaEvolve?(b.index) ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The Mega Evolution button pressed, which flips pbFightMenu's flag; the button's frame does not follow it (hide
    # leaves the frame as it was), so the state is kept here.
    def self.mega_toggled(cw)
      on = !PokeAccess.ivar(cw, :@access_sv_mega)
      cw.instance_variable_set(:@access_sv_mega, on)
      PokeAccess.speak(PokeAccess::I18n.t(on ? :bt_mega_on : :bt_mega_off), true)
    end

    # Runs a databox's refresh and keeps on its battler the marks it painted.
    def self.box_marks(box)
      ret = yield
      note_box(box)
      ret
    end

    # Keeps a refreshed databox's marks on its battler; a box not yet set up paints none.
    def self.note_box(box)
      return if box.disposed?
      PokeAccess::Battle.note_marks(box, mark_icons(box))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The marks refresh paints, in its order, by the names the core's icon marks know: the name in gold for a shiny
    # (the disguise's under Illusion), the ball beside a wild foe whose species is caught, and the Mega symbol or the
    # Primal box.
    def self.mark_icons(box)
      b = box.battler
      shown = box.getBattler(b)
      pk = shown.respond_to?(:pokemon) ? shown.pokemon : shown
      scene = PokeAccess.ivar(box, :@scene)
      icons = []
      icons.push("shiny") if pk && pk.isShiny?
      icons.push("battleBoxOwned") if b.index.odd? && b.owned && !scene.battle.opponent
      if b.isMega?
        icons.push("battleMegaEvoBox")
      elsif b.respond_to?(:isPrimal?) && b.isPrimal?
        icons.push("battlePrimalBox")
      end
      icons
    end
  end
end

PokeAccess::Game.define("sevii") do
  around("NextGenCommandWindow", :refreshCommands) { |cw, nxt, _a| PokeAccess::SeviiBattle.paint_commands(cw) { nxt.call } }
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::SeviiBattle.painted(args[5]) }
  focus_reader("NextGenCommandWindow", :items => :@access_sv_cmds, :slot => :sv_cmd) { |label| label }
  after("NextGenFightWindow", :battler=) { |cw, _r, _a| PokeAccess::SeviiBattle.fight_opened(cw) }
  after("NextGenFightWindow", :update) { |cw, _r, _a| PokeAccess::SeviiBattle.fight_update(cw) }
  after("NextGenFightWindow", :megaButtonTrigger) { |cw, _r, _a| PokeAccess::SeviiBattle.mega_toggled(cw) }
  around("NextGenDataBox", :refresh) { |box, nxt, _a| PokeAccess::SeviiBattle.box_marks(box) { nxt.call } }
end
