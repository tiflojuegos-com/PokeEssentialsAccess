# World Frontier's battle records: the recorder of each Battle Frontier facility (BattleHistoryScene, Guardar combates),
# a list of rivals beside a panel with the focused battle's place, both teams' icons, result and date, whose menus and
# replays the core reads; and the battle's turn log (BattleTurnLog::UI, Historial Combate), opened with the special key
# from the battle info's selection, which pages turns of event rows.
module PokeAccess
  module WfBattleHistory
    # A saved team, from its [species, gender, form, shiny] rows, as its icons show it.
    def self.team_line(label, rows)
      names = (rows || []).map { |r| PokeAccess::WfSpecies.name(r[0], r[2]) }
      names.empty? ? nil : "#{label}: #{names.join(', ')}"
    end

    # The focused battle's row: the rival as the list writes it, the result and its place in the list, then the place
    # and the date the panel paints, then both teams; the info key holds it whole.
    def self.row(record, idx, total)
      head = PokeAccess::Verbosity.list_entry("#{record.formatted_opponent}, #{record.outcome_text}", idx + 1, total)
      parts = [[head, :brief], [record.location_label.to_s, :medium], [record.formatted_date.to_s, :medium],
               [team_line(BattleHistoryConfig.text_player_team, record.player_party), :full],
               [team_line(BattleHistoryConfig.text_opponent_team, record.opponent_party), :full]]
      PokeAccess::Verbosity.info_line(:wf_battle_record, parts, ". ")
    end

    # After each repaint: the title as the list opens, then the focused battle (or the empty list's message) when it
    # moves or the list under it changes, and the sort key after the first one while hints are said.
    def self.refresh(scene)
      opening = PokeAccess::Cursor.changed?(scene, :wf_history_open, true)
      battles = PokeAccess.ivar(scene, :@battles)
      idx = PokeAccess.ivar(scene, :@index).to_i
      record = battles.is_a?(Array) ? battles[idx] : nil
      key = record ? [idx, record.object_id] : :empty
      said = PokeAccess::Cursor.announce(scene, :wf_history, key, true, false) do
        line = record ? row(record, idx, battles.length) : BattleHistoryConfig.text_no_battles
        opening ? PokeAccess.sentences([BattleHistoryConfig::TITLE_TEXT, line]) : line
      end
      PokeAccess::WfHint.say(BattleHistoryConfig.text_sort_hint) if said && opening && record
    end
  end

  module WfTurnLog
    # An event's row as painted: its pill and line, then the pills and lines under it, the HP change as both values.
    def self.event_text(ev)
      parts = [[ev.category, ev.message].map { |t| t.to_s }.reject { |t| t.empty? }.join(", ")]
      (ev.extras || []).each do |extra|
        parts.push(extra[:category].to_s) if extra[:category]
        parts.push(extra[:hp_change] ? hp_text(ev) : extra[:message].to_s)
      end
      PokeAccess.sentences(parts)
    end

    # An HP change as its row paints it: exact for the player's side, a percentage for the rival's.
    def self.hp_text(ev)
      s = BattleTurnLog::Settings
      own = ev.player_side?
      total = own ? ev.hp_total : nil
      from = s.hp_from_text(own ? ev.hp_from_raw : ev.hp_from, own, total)
      to = s.hp_to_text(own ? ev.hp_to_raw : ev.hp_to, own, total)
      PokeAccess::I18n.t(:wf_log_hp, :from => from, :to => to)
    end

    # The events of the turn on the page.
    def self.events(ui)
      evs = (ui.send(:events) rescue nil)
      evs.is_a?(Array) ? evs : []
    end

    # The turn on the page: its title and its events, or the empty log's message.
    def self.page(ui, turn)
      evs = events(ui)
      lines = evs.empty? ? [BattleTurnLog::Settings.empty_text] : evs.map { |ev| event_text(ev) }
      PokeAccess.sentences([BattleTurnLog::Settings.title(turn)] + lines)
    end

    # The index of the event at the top of the scrolled list: the first whose row still shows.
    def self.top_event(ui)
      scroll = PokeAccess.ivar(ui, :@scroll).to_i
      rows = (ui.send(:layout_rows) rescue nil)
      return 0 unless rows.is_a?(Array)
      rows.index { |row| row[:y] + row[:height] > scroll } || 0
    end

    # After each repaint: the whole turn as the log opens or pages to another turn, the battle's current turn and the
    # back key after it on opening; a scroll says the event that reached the top.
    def self.refresh(ui)
      turn = (ui.send(:current_turn) rescue nil)
      return unless turn
      opening = PokeAccess::Cursor.pending?(ui, :wf_turn)
      if PokeAccess::Cursor.changed?(ui, :wf_turn, turn)
        text = page(ui, turn)
        PokeAccess::Info.set_info(:text, PokeAccess.clean(text))
        PokeAccess::Cursor.store(ui, :wf_turn_top, top_event(ui))
        if opening
          text = PokeAccess::WfHint.after(PokeAccess.sentences([text, now_line(ui)]), BattleTurnLog::Settings.back_text)
        end
        PokeAccess.speak_clean(text, !opening)
        return
      end
      evs = events(ui)
      i = top_event(ui)
      PokeAccess::Cursor.announce(ui, :wf_turn_top, i) { evs[i] ? event_text(evs[i]) : nil }
    end

    # The footer's turn the battle is on.
    def self.now_line(ui)
      log = PokeAccess.ivar(ui, :@log)
      (BattleTurnLog::Settings.current_turn_text(log.current_turn_index) rescue nil)
    end

    # The battle info's selection paints the log's key on a pill (where World Frontier's log opens from it): said
    # after its first battler while hints are said.
    def self.selection_hint(scene)
      return unless scene.respond_to?(:pbOpenBattleTurnLog) && PokeAccess.ivar(scene, :@enhancedUIToggle) == :battler
      return if (scene.pbInSafari? rescue false)
      PokeAccess::WfHint.say((BattleTurnLog::Settings.hint_text rescue nil))
    end
  end
end

PokeAccess::Verbosity.define_reading(:wf_battle_record, :vb_wf_battle_record, :vbh_wf_battle_record, :game)

PokeAccess::Game.define("worldfrontier") do
  after("BattleHistoryScene", :pbRefresh) { |scene, _r, _a| PokeAccess::WfBattleHistory.refresh(scene) }
  # Back from a replay the list repaints: its battle is said again, queued.
  before("BattleHistoryScene", :pbResumeAfterPlayback) { |scene, _a| PokeAccess::Cursor.reset(scene, :wf_history) }
  after("BattleTurnLog::UI", :refresh) { |ui, _r, _a| PokeAccess::WfTurnLog.refresh(ui) }
  # A before hook: the selection runs its modal loop inside, whose readers must not be guarded.
  before("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
    PokeAccess::WfTurnLog.selection_hint(scene)
  end
end
