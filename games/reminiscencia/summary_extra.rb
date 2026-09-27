module PokeAccess
  # Reminiscencia's one-page summary, redrawn by drawPageOne on every key: the full status on open and on switching
  # Pokemon, a move on 1-4 (@infomove/@chosenmove), the ability on T (@infohab); single_page mutes the core's.
  module RemiSummary
    # PBStats order is HP=0, ATTACK=1, DEFENSE=2, SPEED=3, SPATK=4, SPDEF=5; the screen lists them as
    # STAT_ORDER (PS, Ataque, Defensa, At. Esp., Def. Esp., Velocidad).
    STAT_KEYS  = [:st_hp, :st_atk, :st_def, :st_speed, :st_spatk, :st_spdef]
    STAT_ORDER = [0, 1, 2, 4, 5, 3]
    # Scene bonus ivar per PBStats index (the per-species stat bonus, shown as a %); HP is left out, as the screen
    # shows "---" there although the scene carries @bonusHP.
    BONUS_IVARS = { 1 => :@bonusATK, 2 => :@bonusDEF,
                    3 => :@bonusSPD, 4 => :@bonusSPATK, 5 => :@bonusSPDEF }

    # The spoken text for the scene's current state, or nil when nothing relevant changed.
    def self.text(scene)
      pk = PokeAccess.ivar(scene, :@pokemon)
      return nil unless pk
      info_move = (scene.instance_variable_get(:@infomove) rescue false) ? true : false
      info_hab  = (scene.instance_variable_get(:@infohab) rescue false) ? true : false
      cm = (scene.instance_variable_get(:@chosenmove) rescue 0)
      key = [pk.object_id, info_move, info_hab, info_move ? cm : nil]
      return nil unless PokeAccess::Cursor.changed?(scene, :sumkey, key)
      return focused_move(pk, cm) if info_move
      return ability_text(pk) if info_hab
      estado(scene, pk)
    rescue StandardError
      nil
    end

    # Hidden Power's move number here; the sheet shows its type and power worked out of the IVs (pbHiddenPower),
    # not the move data's Normal and variable power.
    HIDDEN_POWER = 333

    # Hidden Power's type name and power for this Pokemon, as the sheet shows them, or nil.
    def self.hidden_power(pk)
      hp = pbHiddenPower(pk.iv)
      [PBTypes.getName(hp[0]), hp[1]]
    rescue StandardError
      nil
    end

    # The focused move's detail (1-4), Hidden Power's with the sheet's type and power, or a note for an empty slot;
    # the info key keeps it whole.
    def self.focused_move(pk, cm)
      m = (pk.moves[cm] rescue nil)
      return PokeAccess::I18n.t(:rem_sum_no_move) unless m && m.id && m.id.to_i != 0
      hp = m.id == HIDDEN_POWER ? hidden_power(pk) : nil
      return PokeAccess::Info.move_by_id_info(pk, m.id, :summary_move) unless hp
      d = PBMoveData.new(m.id)
      args = [PBMoves.getName(m.id), hp[0], hp[1], d.accuracy,
              { :cat => PokeAccess::MoveInfo.category_word(d.category), :pp => m.pp, :total_pp => m.totalpp,
                :desc => (pbGetMessage(MessageTypes::MoveDescriptions, m.id) rescue "") }]
      PokeAccess::Info.set_info(:text, PokeAccess::MoveInfo.line(*args))
      PokeAccess::MoveInfo.leveled(:summary_move, *args)
    end

    # The four moves as the sheet lists them: name, the type its button is coloured with, and PP.
    def self.moves_text(pk)
      out = []
      (pk.moves || []).each do |m|
        next unless m && m.id && m.id.to_i != 0
        hp = m.id == HIDDEN_POWER ? hidden_power(pk) : nil
        ty = hp ? hp[0] : (PokeAccess::Data.move_type_name(m.id) rescue nil)
        t = PBMoves.getName(m.id).to_s
        t += ". " + PokeAccess::I18n.t(:mv_type, :t => ty) if ty && !ty.to_s.empty?
        t += ". " + PokeAccess::I18n.t(:mv_pp, :pp => m.pp, :tot => m.totalpp) if m.totalpp.to_i > 0
        out.push(t)
      end
      out.empty? ? PokeAccess::I18n.t(:sm_no_moves) : PokeAccess::I18n.t(:sm_moves, :list => out.join(", "))
    rescue StandardError
      PokeAccess::Summary.moves_text(pk)
    end

    # The ability name and, while key hints are said, the key that reads its description: Z, the physical key of the
    # engine's A button (the A key does something else).
    def self.ability_text(pk)
      ab = (PBAbilities.getName(pk.ability) rescue nil)
      return PokeAccess::I18n.t(:rem_sum_no_ability) if ab.nil? || ab.to_s.empty?
      line = PokeAccess::I18n.t(:rem_sum_ability, :a => ab)
      return line unless PokeAccess::Verbosity.hints?
      "#{line} #{PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:rem_sum_ability_hint), nil, true)}"
    end

    # The full status sheet as painted: name, sex, species, types, nature and its stats, condition, the six stats
    # with IVs, EVs and bonus, ability, item, moves and, with key hints, its keys.
    def self.estado(scene, pk)
      t = PokeAccess::I18n
      sp = PokeAccess::Summary.egg?(pk) ? nil : (PBSpecies.getName(pk.species) rescue nil)
      ty = (PokeAccess::Data.pokemon_types(pk) rescue [])
      head = t.t(:pty_head_nolv, :name => (pk.name rescue "?"), :sex => PokeAccess::Party.sign_phrase(pk))
      head += ", #{sp}" if sp && !sp.to_s.empty?
      head += ", #{t.t(:mv_type, :t => ty.join(' '))}" unless ty.empty?
      head += ", #{PokeAccess::Party.shiny_word(pk)}" if PokeAccess::Party.shiny?(pk)
      parts = [head]
      nat = (PBNatures.getName(pk.nature) rescue nil)
      parts.push(t.t(:sm_nature, :n => nat)) if nat && !nat.to_s.empty?
      parts.push(PokeAccess::Summary.nature_effect_line(pk))
      parts.push(status_phrase(pk))
      sv = (stat_values(pk) rescue nil)
      parts.push(stat_line(t.t(:rem_sum_stats), sv)) if sv
      iv = (pk.iv rescue nil)
      parts.push(stat_line(t.t(:rem_sum_rating), iv_stars(iv).map { |n| t.t(:list_pos, :i => n, :n => 3) })) if iv.is_a?(Array)
      ev = (pk.ev rescue nil)
      parts.push(stat_line(t.t(:rem_sum_evs), ev)) if ev.is_a?(Array)
      bon = bonus_values(scene)
      parts.push(stat_line(t.t(:rem_sum_bonus), bon, "%")) if bon
      ab = (PBAbilities.getName(pk.ability) rescue nil)
      parts.push(t.t(:sum_ability, :a => ab)) if ab && !ab.to_s.empty?
      it = ((pk.item rescue 0) != 0) ? (PBItems.getName(pk.item) rescue nil) : nil
      parts.push(t.t(:sum_item, :i => it)) if it && !it.to_s.empty?
      parts.push(moves_text(pk))
      parts.push(keys_line) if PokeAccess::Verbosity.hints?
      PokeAccess.sentences(parts)
    end

    # The keys the sheet paints beside its moves, ability and footer (1 to 4, T, the arrows, X), each as the player
    # has it now: the game's own raw keys are rebindable extras.
    def self.keys_line
      kh = PokeAccess::KeyHints
      moves = (1..4).map { |n| kh.key("key_#{n}".to_sym, n.to_s) }.join(", ")
      PokeAccess::I18n.t(:rem_sum_keys, :moves => moves, :ability => kh.key(:fast_travel, "T"),
                                        :back => kh.key(:b, "X"))
    end

    # The 0-to-3 star rating the IV column paints, by the screen's own thresholds (the exact IVs are not shown).
    def self.iv_stars(iv)
      iv.map { |v| n = v.to_i; n >= 21 ? 3 : (n >= 11 ? 2 : (n >= 1 ? 1 : 0)) }
    end

    # A "title. label value, ..." line in the screen's row order, skipping stats with no value (the bonus's HP).
    # param suffix appended to each value (e.g. "%")
    def self.stat_line(title, vals, suffix = "")
      stats = STAT_ORDER.map { |i| vals[i].nil? ? nil : "#{PokeAccess::I18n.t(STAT_KEYS[i])} #{vals[i]}#{suffix}" }
      "#{title}. #{stats.compact.join(', ')}"
    end

    # The current value of each stat, by PBStats index (HP shown as current of max).
    def self.stat_values(pk)
      { 0 => PokeAccess::I18n.t(:list_pos, :i => pk.hp, :n => pk.totalhp), 1 => pk.attack, 2 => pk.defense,
        3 => pk.speed, 4 => pk.spatk, 5 => pk.spdef }
    end

    # The per-species stat bonus the screen shows, by PBStats index, or nil when all zero/absent.
    def self.bonus_values(scene)
      h = {}
      BONUS_IVARS.each do |stat, ivar|
        h[stat] = (scene.instance_variable_get(ivar) rescue nil).to_i
      end
      h.values.any? { |v| v != 0 } ? h : nil
    rescue StandardError
      nil
    end

    # The condition status: fainted, or sleep/poison/burn/paralysis/freeze via the shared table.
    def self.status_phrase(pk)
      return PokeAccess::I18n.t(:pk_fainted) if (pk.hp rescue 1).to_i == 0
      st = (pk.status rescue 0)
      return nil if st.nil? || st == 0
      sn = (PokeAccess::Config.status_names[st] rescue nil)
      sn ? PokeAccess::I18n.t(sn) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Summary.single_page = true

# Reads the summary state on each redraw (deduped inside RemiSummary.text).
PokeAccess::Game.define("reminiscencia") do
  after("PokemonSummaryScene", :drawPageOne) do |scene, _r, _a|
    t = PokeAccess::RemiSummary.text(scene)
    PokeAccess.speak(t, true)
  end

  # A move focused with 1-4 (@infomove) counts as a focused detail, so the core leaves the move in the info key.
  override("PokeAccess::SummaryGen6", :detail_focused?) do |_mod, original, args|
    original.call || ((args[0].instance_variable_get(:@infomove) rescue false) ? true : false)
  end
end
