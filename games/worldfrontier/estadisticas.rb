# World Frontier's Pokemon editor (WF Estadisticas, pbStatEditorParty at the Pokemon Centers): a hub of panels (stats,
# moves, nature, ability) and buttons over a copy of the Pokemon, the stat points editor, and the nature, ability, move
# and learnable move pickers, which loop with their cursor in a local variable. A frame per open picker follows that
# cursor from what the game draws for it (the move or ability detail) or, where it draws none, from the keys it read
# when its cursor sound plays; the move editor's slot marked for a swap, from the keys its other sounds play for.
module PokeAccess
  module WfEditor
    STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    VALUES = { :HP => :totalhp, :ATTACK => :attack, :DEFENSE => :defense, :SPECIAL_ATTACK => :spatk,
               :SPECIAL_DEFENSE => :spdef, :SPEED => :speed }
    @frames = []

    # A key's name as the editor's footers paint it.
    def self.key(sym)
      (KeybindingReader.key_name(sym) rescue "?").to_s
    end

    # What a nature raises and lowers, or the game's word for a neutral one.
    def self.effect(nature)
      changes = (nature.stat_changes rescue nil) || []
      up = changes.find { |c| c[1] > 0 }
      down = changes.find { |c| c[1] < 0 }
      return _INTL("Neutra") unless up && down
      PokeAccess::I18n.t(:wf_nat_effect, :up => PokeAccess::Data.stat_name(up[0]),
                                         :down => PokeAccess::Data.stat_name(down[0]))
    end

    # A value with the mark the hub paints in yellow where the copy differs from the Pokemon.
    def self.changed(text, flag)
      flag ? "#{text}, #{PokeAccess::I18n.t(:wf_ed_changed)}" : text
    end

    # A move's type as its icon shows it for the Pokemon.
    def self.type_name(move, pk)
      PokeAccess::Data.type_name((move.display_type(pk) rescue move.type))
    end

    # A move of the Pokemon as the hub's list paints it: name, type and PP, or the empty slot.
    def self.move_row(pk, mv)
      return _INTL("- vacío -") unless mv
      data = GameData::Move.get(mv.id)
      tot = (mv.total_pp rescue nil) || (data.total_pp rescue nil)
      PokeAccess::MoveInfo.line(data.name, type_name(mv, pk), nil, nil, :pp => tot, :total_pp => tot)
    end

    # A move's detail as the editor's side panel paints it, at a reading's level (nil: whole), after the name given:
    # type, category, power (the most friendship gives, for the moves whose power rests on it), accuracy, PP and
    # description.
    def self.detail(data, pk, name, reading)
      power = data.power
      happy = defined?(::WFHappinessMoves) && (::WFHappinessMoves.happiness_move?(data.function_code) rescue false)
      power = ::WFHappinessMoves::MAX_POWER if happy
      tot = (data.total_pp rescue nil)
      PokeAccess::MoveInfo.leveled(reading, name, type_name(data, pk), power, data.accuracy,
                                   :cat => PokeAccess::MoveInfo.category_word(data.category), :pp => tot,
                                   :total_pp => tot, :desc => data.description)
    end

    # The hub's panel or button: its title and what it shows, each value marked where the copy changed it.
    def self.section_text(scene, section)
      work = scene.working
      orig = scene.original
      case section
      when :stats
        rows = STATS.map do |s|
          ev = work.ev[s].to_i
          row = PokeAccess::I18n.t(:wf_ed_stat, :stat => PokeAccess::Data.stat_name(s), :total => work.send(VALUES[s]),
                                                :n => ev)
          changed(row, ev != orig.ev[s].to_i)
        end
        PokeAccess.sentences([_INTL("Estadísticas")] + rows)
      when :moves
        rows = (0...4).map do |i|
          mv = work.moves[i]
          om = orig.moves[i]
          changed(move_row(work, mv), (mv && om) ? mv.id != om.id : mv != om)
        end
        PokeAccess.sentences([_INTL("Movimientos")] + rows)
      when :nature
        nature = work.nature_for_stats
        moved = work.nature_for_stats_id != orig.nature_for_stats_id || work.nature_id != orig.nature_id
        text = nature ? "#{nature.name}, #{effect(nature)}" : "?"
        PokeAccess.sentences([_INTL("Naturaleza"), changed(text, moved)])
      when :ability
        moved = work.ability_index != orig.ability_index || work.ability_id != orig.ability_id
        text = work.ability ? work.ability.name : "?"
        PokeAccess.sentences([_INTL("Habilidad"), changed(text, moved)])
      when :confirm then _INTL("Confirmar cambios")
      when :reset then _INTL("Reiniciar cambios")
      when :exit then _INTL("Salir sin cambiar")
      end
    end

    # After each repaint of the hub: its title as it opens, then the focused panel or button when it moves or what it
    # shows changes, and the sets key after the first; the info key holds the focused one.
    def self.hub(scene)
      section = scene.current_section
      text = section_text(scene, section)
      return unless text
      PokeAccess::Info.set_info(:text, PokeAccess.clean(text))
      opening = PokeAccess::Cursor.changed?(scene, :wf_editor_open, true)
      said = PokeAccess::Cursor.announce(scene, :wf_editor, [section, text], true, false) do
        opening ? PokeAccess.sentences([_INTL("EDITAR A {1}", scene.working.name.upcase), text]) : text
      end
      PokeAccess::WfHint.say(_INTL("[{1}]: Sets", key(:ACTION))) if said && opening
    end

    # The stat editor's focused row as painted: the stat, its value with the points, what the points add to it, and
    # the points it holds of the most one stat takes.
    def self.stat_row(scene, idx, work)
      sid = STATS[idx]
      zero = {}
      STATS.each { |s| zero[s] = 0 }
      value = scene.pbPreviewStats(work)[sid].to_i
      diff = value - scene.pbPreviewStats(zero)[sid].to_i
      parts = ["#{PokeAccess::Data.stat_name(sid)} #{value}"]
      parts.push(sprintf("+%d", diff)) if diff > 0
      parts.push(PokeAccess::I18n.t(:wf_ed_points, :n => work[sid].to_i, :max => WFEstadisticas::MAX_POINTS_PER_STAT))
      parts.join(", ")
    end

    # The points spent of the total and those left, as the footer paints them.
    def self.points(work)
      used = STATS.inject(0) { |sum, s| sum + work[s].to_i }
      total = WFEstadisticas::MAX_TOTAL_POINTS
      [PokeAccess::I18n.t(:wf_ed_points, :n => used, :max => total), _INTL("Disponibles: {1}", total - used)]
    end

    # After each repaint of the stat editor: its title, the Pokemon, its nature and the points as it opens, the row
    # when the cursor moves, and the row with the points left when its value changes.
    def self.stat_editor(scene)
      idx = PokeAccess.ivar(scene, :@cursor)
      work = PokeAccess.ivar(scene, :@working)
      return unless idx.is_a?(Integer) && work.is_a?(Hash) && STATS[idx]
      prev = PokeAccess::Cursor.current(scene, :wf_stat)
      return unless PokeAccess::Cursor.changed?(scene, :wf_stat, [idx, STATS.map { |s| work[s].to_i }])
      row = stat_row(scene, idx, work)
      PokeAccess::Info.set_info(:text, PokeAccess.clean(row))
      if prev.nil?
        pk = PokeAccess.ivar(scene, :@pkmn)
        nature = (pk.nature_for_stats rescue nil)
        head = [_INTL("EDITOR DE ESTADÍSTICAS"), (pk.name rescue nil),
                _INTL("Naturaleza: {1}", nature ? nature.name : "")]
        head.push(effect(nature)) if nature
        PokeAccess.speak_clean(PokeAccess.sentences(head + [row] + points(work)), false)
        PokeAccess::WfHint.say(_INTL("[{1}]: Confirmar    [{2}]: Mínimo    [{3}]: Máximo    [{4}]: Cancelar",
                                     key(:USE), key(:JUMPUP), key(:JUMPDOWN), key(:BACK)))
      elsif prev[0] != idx
        PokeAccess.speak_clean(row, true)
      else
        PokeAccess.speak_clean(PokeAccess.sentences([row, points(work)[1]]), true)
      end
    end

    # The open pickers, innermost last, as [kind, state] pairs.
    def self.top
      @frames.last
    end

    # Runs a picker's loop (the block) with its frame on top; the picker underneath says its focus again after.
    def self.within(kind, state)
      @frames.push([kind, state])
      yield
    ensure
      @frames.pop
      under = @frames.last
      PokeAccess::Cursor.reset(under[1], :wf_pick) if under
    end

    # Runs a reader step from inside the game's own call, its failures kept from the game.
    def self.guard
      yield
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The nature picker's cell as its grid paints it: the nature, and what it raises and lowers.
    def self.nature_cell(st)
      axis = WFEstadisticas::NATURE_AXIS
      up = axis[st[:row]]
      down = axis[st[:col]]
      n = up == down ? st[:neutral][up] : st[:by_cell][[up, down]]
      n ? "#{n.name}, #{effect(n)}" : nil
    end

    # The nature picker (the block), its frame on the cell of the current nature: said with the title and keys.
    def self.nature(current)
      st = guard do
        by_cell, neutral = WFEstadisticas._build_nature_lookup
        row, col = WFEstadisticas._locate_nature_cell(current, by_cell, neutral)
        { :by_cell => by_cell, :neutral => neutral, :row => row, :col => col }
      end
      return yield unless st
      within(:nature, st) do
        guard do
          PokeAccess.speak_clean(PokeAccess.sentences([_INTL("EDITOR DE NATURALEZA"), nature_cell(st)]), false)
          PokeAccess::WfHint.say(_INTL("[{1}]: Elegir    [{2}]: Atrás", key(:USE), key(:BACK)))
        end
        yield
      end
    end

    # The nature grid moved: the cell the keys the game read lead to, said.
    def self.nature_step(st)
      n = WFEstadisticas::NATURE_AXIS.length
      if Input.repeat?(Input::UP) then st[:row] = (st[:row] - 1) % n
      elsif Input.repeat?(Input::DOWN) then st[:row] = (st[:row] + 1) % n
      elsif Input.repeat?(Input::LEFT) then st[:col] = (st[:col] - 1) % n
      elsif Input.repeat?(Input::RIGHT) then st[:col] = (st[:col] + 1) % n
      else return
      end
      cell = nature_cell(st)
      PokeAccess.speak_clean(cell, true) if cell
    end

    # The ability picker (the block), its frame holding the options the game lists.
    def self.ability(pkmn)
      options = guard { WFEstadisticas._build_ability_options(pkmn) }
      return yield unless options.is_a?(Array) && !options.empty?
      within(:ability, { :options => options }) { yield }
    end

    # The ability panel drew a description: its option is the focused one, said with its place, and the description
    # while descriptions are said; the title and keys first as the picker opens.
    def self.description_drawn(text)
      kind, st = top
      return unless kind == :ability
      opts = st[:options]
      i = opts.index { |o| (GameData::Ability.get(o[2]).description rescue nil).to_s == text.to_s }
      return unless i
      line = PokeAccess::Verbosity.list_entry(opts[i][0], i + 1, opts.length)
      PokeAccess::Info.set_info(:text, PokeAccess.clean(PokeAccess.sentences([opts[i][0], text])))
      line = PokeAccess.sentences([line, text]) if PokeAccess::Verbosity.descriptions?
      first = !st[:opened]
      st[:opened] = true
      line = PokeAccess.sentences([_INTL("EDITOR DE HABILIDAD"), line]) if first
      said = PokeAccess::Cursor.announce(st, :wf_pick, i, true, false) { line }
      PokeAccess::WfHint.say(_INTL("[{1}]: Elegir    [{2}]: Atrás", key(:USE), key(:BACK))) if said && first
    end

    # The move editor (the block) over a Pokemon's moves, its cursor on the first slot, no slot marked, and the depth of
    # messages it opens at.
    def self.moves(pkmn)
      within(:moves, { :pkmn => pkmn, :cursor => 0, :depth => PokeAccess.message_depth }) { yield }
    end

    # The move editor's cursor moved: the slot the keys the game read lead to.
    def self.moves_step(st)
      if Input.trigger?(Input::UP) then st[:cursor] = (st[:cursor] - 1) % 4
      elsif Input.trigger?(Input::DOWN) then st[:cursor] = (st[:cursor] + 1) % 4
      end
    end

    # A decision, cancel or buzzer sound of the move editor's own loop, not of a message it shows: its slot marked for
    # a swap, a local of that loop, followed from the key the game read (Z, C and A are v21's SPECIAL, USE and ACTION).
    # D marks the focused slot, and D or C on it again unmarks it, both said; a swap, a deletion or the refusal to
    # forget a move ends the mark silently, the slot then read again.
    def self.moves_sound(st, sound)
      return if PokeAccess.message_depth > st[:depth].to_i
      if st[:marked].nil?
        return unless sound == :decision && Input.trigger?(Input::Z)
        st[:marked] = st[:cursor]
        PokeAccess.speak(PokeAccess::I18n.t(:wf_move_marked), true)
      elsif sound == :cancel
        return unless Input.trigger?(Input::Z) || Input.trigger?(Input::C)
        st[:marked] = nil
        PokeAccess.speak(PokeAccess::I18n.t(:wf_move_unmarked), true)
      elsif sound == :decision || (sound == :buzzer && !st[:pkmn].moves.compact.empty?)
        st[:marked] = nil
      end
    end

    # A move editor slot: its place, then the move as the list and the side panel paint it ([P] on a move the
    # Pokemon cannot forget), or the empty slot; the slot framed as marked for a swap says so after its place.
    def self.slot_line(pk, i, reading, marked = false)
      mv = pk.moves[i]
      mark = marked ? PokeAccess::I18n.t(:wf_move_marked) : nil
      return [PokeAccess::Verbosity.list_entry(_INTL("- vacío -"), i + 1, 4), mark].compact.join(", ") unless mv
      data = GameData::Move.get(mv.id)
      name = (WFEstadisticas.move_is_protected?(pk, mv.id) rescue false) ? "[P] #{data.name}" : data.name
      name = PokeAccess::Verbosity.list_entry(name, i + 1, 4) if reading
      detail(data, pk, [name, mark].compact.join(", "), reading)
    end

    # Each frame of the move editor: the focused slot when the cursor moves or its moves change, the first with the
    # title, the Pokemon and the keys.
    def self.moves_poll(st)
      pk = st[:pkmn]
      i = st[:cursor]
      key = [i, pk.moves.map { |m| m ? m.id : nil }]
      first = !st[:opened]
      said = PokeAccess::Cursor.announce(st, :wf_pick, key, true, false) do
        st[:opened] = true
        PokeAccess::Info.set_info(:text, PokeAccess.clean(slot_line(pk, i, nil)))
        line = slot_line(pk, i, :summary_move, st[:marked] == i)
        first ? PokeAccess.sentences([_INTL("EDITOR DE MOVIMIENTOS"), pk.name, line]) : line
      end
      return unless said && first
      keys = _INTL("[{1}]: Cambiar        [{2}]: Posición        [{3}]: Eliminar        [{4}]: Salir",
                   key(:USE), key(:SPECIAL), key(:ACTION), key(:BACK))
      PokeAccess::WfHint.say(keys)
    end

    # The learnable move list (the block) for a Pokemon.
    def self.learn(pkmn)
      within(:learn, { :pkmn => pkmn }) { yield }
    end

    # The side panel drew a move's data: kept for the next frame, once the list's counter is painted too.
    def self.detail_drawn(move, pk)
      kind, st = top
      return unless kind == :learn
      st[:move] = move
      st[:pk] = pk
      PokeAccess::PaintCapture.arm(:wf_learn)
    end

    # The frame after a learnable move was drawn: the move with its place from the painted counter, the first with
    # the title and keys.
    def self.learn_poll(st)
      data = st[:move]
      return unless data
      st[:move] = nil
      count = (PokeAccess::PaintCapture.take(:wf_learn) || []).map { |t| t.to_s }.find { |t| t =~ /\A\d+ \/ \d+\z/ }
      n, tot = count ? count.split(" / ").map { |x| x.to_i } : [nil, nil]
      name = n ? PokeAccess::Verbosity.list_entry(data.name, n, tot) : data.name
      PokeAccess::Info.set_info(:text, PokeAccess.clean(detail(data, st[:pk], data.name, nil)))
      first = !st[:opened]
      st[:opened] = true
      line = detail(data, st[:pk], name, :learn_move)
      line = PokeAccess.sentences([_INTL("APRENDER MOVIMIENTO"), line]) if first
      said = PokeAccess::Cursor.announce(st, :wf_pick, [data.id, n], true, false) { line }
      return unless said && first
      PokeAccess::WfHint.say(_INTL("[{1}]: Elegir   [{2}]: Atrás   [{3}]: Buscar   [{4}]: Filtro",
                                   key(:USE), key(:BACK), key(:SPECIAL), key(:ACTION)))
    end

    # The cursor sound of a picker that mirrors its keys.
    def self.cursor_moved
      kind, st = top
      nature_step(st) if kind == :nature
      moves_step(st) if kind == :moves
    end

    # A decision, cancel or buzzer sound (:decision, :cancel, :buzzer), for the picker on top.
    def self.sound_played(sound)
      kind, st = top
      moves_sound(st, sound) if kind == :moves
    end

    # Each frame, for the picker on top.
    def self.poll
      kind, st = top
      moves_poll(st) if kind == :moves
      learn_poll(st) if kind == :learn
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("PokemonEditor_Scene", :pbRefresh) { |scene, _r, _a| PokeAccess::WfEditor.hub(scene) }
  # Back from a sub-screen the hub repaints: its focus is said again, queued.
  before("PokemonEditor_Scene", :pbShow) { |scene, _a| PokeAccess::Cursor.reset(scene, :wf_editor) }
  after("PokemonStatEditor_Scene", :pbRefresh) { |scene, _r, _a| PokeAccess::WfEditor.stat_editor(scene) }
  override("WFEstadisticas", :pbChooseNature) do |_mod, original, args|
    PokeAccess::WfEditor.nature(args[0]) { original.call }
  end
  override("WFEstadisticas", :pbChooseAbility) do |_mod, original, args|
    PokeAccess::WfEditor.ability(args[0]) { original.call }
  end
  override("WFEstadisticas", :pbEditMoves) do |_mod, original, args|
    PokeAccess::WfEditor.moves(args[0]) { original.call }
  end
  override("WFEstadisticas", :pbChooseLearnableMove) do |_mod, original, args|
    PokeAccess::WfEditor.learn(args[0]) { original.call }
  end
  override("WFEstadisticas", :_draw_move_detail_panel) do |_mod, original, args|
    ret = original.call
    PokeAccess::WfEditor.guard { PokeAccess::WfEditor.detail_drawn(args[3], args[4]) }
    ret
  end
  override("WFEstadisticas", :_draw_centered_wrapped) do |_mod, original, args|
    ret = original.call
    PokeAccess::WfEditor.guard { PokeAccess::WfEditor.description_drawn(args[1]) }
    ret
  end
  kernel("pbPlayCursorSE") { |_args, _r| PokeAccess::WfEditor.guard { PokeAccess::WfEditor.cursor_moved } }
  kernel("pbPlayDecisionSE") { |_args, _r| PokeAccess::WfEditor.guard { PokeAccess::WfEditor.sound_played(:decision) } }
  kernel("pbPlayCancelSE") { |_args, _r| PokeAccess::WfEditor.guard { PokeAccess::WfEditor.sound_played(:cancel) } }
  kernel("pbPlayBuzzerSE") { |_args, _r| PokeAccess::WfEditor.guard { PokeAccess::WfEditor.sound_played(:buzzer) } }
  poll_each_frame { PokeAccess::WfEditor.guard { PokeAccess::WfEditor.poll } }
end
