module PokeAccess
  # Gen-6 summary reader (PokemonSummaryScene): each page is read on arrival -- memo, stats, moves,
  # ribbons -- plus the move-reorder feedback and the move-to-forget prompt. Binds only where the gen-6
  # scene class exists. Its own module (not a reopen of the agnostic Summary), so gen-6-specific content
  # does not leak into the shared namespace; the cross-engine moves_text/single_page stay in
  # core/party/summary.rb (Summary), and the modern reader is core/party/v21/summary_v21.rb.
  module SummaryGen6
    # The trainer memo: nature, where and how it was obtained, and its characteristic.
    def self.memo_text(pk)
      return nil unless pk
      parts = []
      nat = (PBNatures.getName(pk.nature) rescue nil)
      parts.push(PokeAccess::I18n.t(:sm_nature, :n => nat)) if nat && !nat.to_s.empty?
      m = met_text(pk); parts.push(m) if m
      c = characteristic_text(pk); parts.push(c) if c
      parts.empty? ? nil : "#{PokeAccess::I18n.t(:sm_memo)}. #{parts.join('. ')}."
    rescue StandardError
      nil
    end

    # How and where the pokemon was met (found, hatched, traded, fateful), with the place.
    def self.met_text(pk)
      mode = (pk.obtainMode rescue nil)
      return nil if mode.nil?
      lvl = (pk.obtainLevel rescue nil)
      how = case mode
            when 0 then PokeAccess::I18n.t(:sm_met_found, :lvl => lvl)
            when 1 then PokeAccess::I18n.t(:sm_met_egg)
            when 2 then PokeAccess::I18n.t(:sm_met_trade, :lvl => lvl)
            when 4 then PokeAccess::I18n.t(:sm_met_fateful, :lvl => lvl)
            else nil
            end
      return nil if how.nil?
      place = (pbGetMapNameFromId(pk.obtainMap) rescue nil)
      ot = (pk.obtainText rescue nil)
      place = ot if ot && ot.to_s != ""
      place = PokeAccess::I18n.t(:sm_met_far) if place.nil? || place.to_s == ""
      PokeAccess::I18n.t(:sm_met_at, :how => how, :place => place)
    rescue StandardError
      nil
    end

    # The flavour characteristic derived from the highest individual value, as the games show. Keyed
    # sm_char_0..29 by best-iv stat (0-5) times 5 plus iv mod 5, matching the engine's own table order
    # (HP, Atk, Def, Speed, SpAtk, SpDef).
    def self.characteristic_text(pk)
      iv = (pk.iv rescue nil)
      return nil unless iv.is_a?(Array) && iv.length >= 6
      best = 0
      tie = (pk.personalID rescue 0) % 6
      (0...6).each do |i|
        if iv[i] == iv[best]
          best = i if i >= tie && best < tie
        elsif iv[i] > iv[best]
          best = i
        end
      end
      PokeAccess::I18n.t("sm_char_#{best * 5 + (iv[best] % 5)}".to_sym)
    rescue StandardError
      nil
    end

    # The stats page: current/max hp, the five stats and the ability.
    def self.stats_text(pk)
      return nil unless pk
      t = PokeAccess::I18n.t(:sm_stats) + ". " + PokeAccess::I18n.t(:sum_stats, :hp => pk.hp, :tot => pk.totalhp,
            :atk => pk.attack, :def => pk.defense, :spa => pk.spatk, :spd => pk.spdef, :spe => pk.speed)
      ab = (PBAbilities.getName(pk.ability) rescue nil)
      t += " " + PokeAccess::I18n.t(:sum_ability, :a => ab) if ab && !ab.to_s.empty?
      t
    rescue StandardError
      nil
    end

    # The ribbons page: how many and their names.
    def self.ribbons_text(pk)
      return nil unless pk
      rb = (pk.ribbons rescue nil) || []
      return PokeAccess::I18n.t(:sm_ribbons_none) if rb.empty?
      names = rb.map { |r| (PBRibbons.getName(r) rescue nil) }.compact
      PokeAccess::I18n.t(:sm_ribbons, :n => rb.length) + (names.empty? ? "" : (". " + names.join(", ")))
    rescue StandardError
      nil
    end

    # Spoken name of a move slot (0-3), "vacio" if empty, or "Salir" for the exit slot 4.
    def self.slot_name(pk, i)
      return PokeAccess::I18n.t(:sm_exit) if i == 4
      return nil unless pk && i
      m = (pk.moves[i] rescue nil)
      (m && m.id && m.id.to_i != 0) ? (PBMoves.getName(m.id) rescue PokeAccess::I18n.t(:info_move)) : PokeAccess::I18n.t(:sm_empty_slot)
    end

    # Spoken summary when choosing which move to forget to learn a new one: the move being learned plus
    # the four current moves with positions.
    def self.relearn_text(pk, move_to_learn)
      t = ""
      if move_to_learn && move_to_learn.to_i != 0
        nm = (PBMoves.getName(move_to_learn) rescue nil)
        t += PokeAccess::I18n.t(:sm_learn, :move => nm) + ". " if nm && !nm.to_s.empty?
      end
      "#{t}#{PokeAccess::I18n.t(:sm_choose_forget)}. #{move_list_text(pk)}"
    rescue StandardError
      nil
    end

    # The four current moves with positions, concise (names only), as an overview. The full detail of
    # each move is read one at a time as you navigate (drawSelectedMove).
    def self.move_list_text(pk)
      return PokeAccess::I18n.t(:sm_no_moves) unless pk && pk.moves
      out = []
      4.times do |i|
        m = (pk.moves[i] rescue nil)
        out.push(PokeAccess::I18n.t(:sm_move_pos, :n => i + 1, :name => (PBMoves.getName(m.id) rescue PokeAccess::I18n.t(:info_move)))) if m && m.id && m.id.to_i != 0
      end
      out.empty? ? PokeAccess::I18n.t(:sm_no_moves) : PokeAccess::I18n.t(:sm_moves, :list => out.join(", "))
    rescue StandardError
      PokeAccess::I18n.t(:sm_no_moves)
    end

    # Clears the move-reorder tracking when a summary opens, so a fresh scene never compares against a
    # stale swap state left from a previous summary (which would speak a spurious cancel/placed line).
    def self.reset_reorder; @reorder_sw = nil; @reorder_idx = nil; end

    # Watches the summary move sprites each frame (gen-6 uses movesel/movepresel, shared across gen-6 forks):
    # announces entering the swap (picking a move up), the position while reordering, and where it lands.
    # Each move's full detail is read as you navigate (drawSelectedMove) and the four-move overview on
    # arrival comes from drawPageFour, so this never re-speaks them. No-op without those sprites.
    def self.reorder_poll(scene)
      sp = PokeAccess.ivar(scene, :@sprites)
      mp = sp && sp["movepresel"]
      ms = sp && sp["movesel"]
      return if mp.nil? || ms.nil?
      pk = PokeAccess.ivar(scene, :@pokemon)
      sw = mp.visible ? true : false
      idx = (ms.index rescue nil)
      if sw != @reorder_sw
        prev = @reorder_sw; @reorder_sw = sw; @reorder_idx = idx
        return if prev.nil?
        if sw
          PokeAccess.speak(PokeAccess::I18n.t(:sm_reorder, :name => slot_name(pk, (mp.index rescue idx))), true)
        elsif idx == 4
          PokeAccess.speak(PokeAccess::I18n.t(:sm_reorder_cancel), true)
        else
          PokeAccess.speak(PokeAccess::I18n.t(:sm_placed, :n => (idx ? idx + 1 : '?')), true)
        end
        return
      end
      if sw && idx != @reorder_idx
        @reorder_idx = idx
        if idx == 4
          PokeAccess.speak(PokeAccess::I18n.t(:sm_exit), true)
        else
          nm = slot_name(pk, idx)
          PokeAccess.speak(PokeAccess::I18n.t(:sm_position, :n => idx + 1) + (nm ? ", " + nm : ""), true)
        end
      end
    rescue StandardError
      nil
    end

    # The scene class to hook, or "" when this reader does not apply to the running engine.
    #
    # A gen-6 fork can ship the v16 class name as an empty SUBCLASS of the v17 one and instantiate only the
    # v17 name (Awakening's BES-T compatibility file does it for 23 screens). Hooking "PokemonSummaryScene"
    # then bound to a class nobody creates and this whole reader went silent -- while summary_v21, which
    # matches that same v17 name, bound instead and read a gen-6 Pokemon through the GameData API, losing
    # types, ability, item and nature. scene_class answers with the ancestral name that sees every instance.
    #
    # The era check is the other half and is not optional: on a real GameData game the v17 name exists too,
    # carrying the OTHER data API, and without this both readers would speak over each other. An empty name
    # binds nothing -- the same silent no-op an absent class already is -- so no registration needs an if.
    SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonSummaryScene", "PokemonSummary_Scene")
  end
end

# Every registration below binds through SummaryGen6::SCENE (see its comment): the right alias on a gen-6
# engine, and nothing at all on a GameData one.

# Clear the move-reorder tracking when the summary opens, so reopening another pokemon's summary never
# fires a stale cancel/placed line from a reorder left mid-way in the previous one.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryGen6::SCENE, :pbStartScene) do |_s, _a|
  PokeAccess::SummaryGen6.reset_reorder
end

# Summary info page: full data sheet read on open. Skipped where the summary is a single redrawn page
# (Summary.single_page): that profile's own handler reads it to avoid repeating on every redraw.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageOne) do |_s, _r, args|
  PokeAccess.speak(PokeAccess::Info.summary_text(args[0]), false) unless PokeAccess::Summary.single_page
end

# Summary trainer-memo page (nature, met info, characteristic).
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageTwo) do |_s, _r, args|
  PokeAccess.speak(PokeAccess::SummaryGen6.memo_text(args[0]), false)
end

# Summary stats page (the five stats and ability).
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageThree) do |_s, _r, args|
  PokeAccess.speak(PokeAccess::SummaryGen6.stats_text(args[0]), false)
end

# Summary moves page (drawPageFour lists the four moves): read them on arrival.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageFour) do |_s, _r, args|
  PokeAccess.speak(PokeAccess::Summary.moves_text(args[0]), false)
end

# Summary ribbons page.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageFive) do |_s, _r, args|
  PokeAccess.speak(PokeAccess::SummaryGen6.ribbons_text(args[0]), false)
end

# Move detail: each move read with its data when selected.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawSelectedMove) do |_s, _r, args|
  PokeAccess.speak(PokeAccess::Info.move_by_id_info(args[0], args[2]), true)
end

# Keep the info key (T) on the Pokemon currently shown: the summary lets you switch Pokemon in place
# (up/down) without leaving, but only the party slot set the contextual Pokemon, so T kept reading the one
# you entered with. pbUpdate runs each frame with the live @pokemon, so refresh it here.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :pbUpdate) do |scene, _r, _a|
  pk = PokeAccess.ivar(scene, :@pokemon)
  PokeAccess::Info.set_info(:pokemon, pk) if pk
  PokeAccess::SummaryGen6.reorder_poll(scene)
end

# Learning a move with a full moveset: read the new move and the current four to choose which to forget
# (the screen otherwise stays silent until you navigate).
PokeAccess::Hooks.before_hook(PokeAccess::SummaryGen6::SCENE, :pbChooseMoveToForget) do |scene, args|
  PokeAccess.speak(PokeAccess::SummaryGen6.relearn_text(scene.instance_variable_get(:@pokemon), args[0]), false)
end
