module PokeAccess
  # Gen-6 summary reader (PokemonSummaryScene): each page on arrival, the move details and the move-to-forget
  # prompt. The shared helpers are in Summary (summary.rb); the modern reader is v21/summary_v21.rb.
  module SummaryGen6
    # Whether the move or ribbon cursor is up, so the info key answers for that detail and not the Pokemon; a
    # profile may override it.
    def self.detail_focused?(scene)
      %w[movesel ribbonsel].any? { |k| (PokeAccess.sprite(scene, k).visible rescue false) ? true : false }
    end

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

    # The characteristic from the highest IV, keyed sm_char_<stat * 5 + iv % 5> with the stats in the engine's
    # order (HP, Atk, Def, Speed, SpAtk, SpDef).
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

    # The stats page: current/max hp, the five stats, the nature's effect its label colours show, and the
    # ability, with the description where the page writes it under it.
    # param painted the strings the page painted, or nil when it was not captured
    def self.stats_text(pk, painted = nil)
      return nil unless pk
      t = PokeAccess::I18n.t(:sm_stats) + ". " + PokeAccess::I18n.t(:sum_stats, :hp => pk.hp, :tot => pk.totalhp,
            :atk => pk.attack, :def => pk.defense, :spa => pk.spatk, :spd => pk.spdef, :spe => pk.speed)
      extra = (stats_extras(pk) rescue [])
      t += " " + extra.join(" ") unless extra.nil? || extra.empty?
      nat = PokeAccess::Summary.nature_effect_line(pk)
      t += " " + nat if nat
      ab = PokeAccess::Summary.ability_line(pk, painted)
      ab ? "#{t} #{ab}" : t
    rescue StandardError
      nil
    end

    # Sentences a game's stats page writes or draws beside the stats, which its profile adds; none on the stock page.
    def self.stats_extras(_pk); []; end

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

    # The move-to-forget prompt: the move being learned, then the current moves (move_list_text).
    def self.relearn_text(pk, move_to_learn)
      t = ""
      if PokeAccess::MoveInfo.real_id?(move_to_learn)
        nm = (PokeAccess::Data.move_name(move_to_learn) rescue nil)
        t += PokeAccess::I18n.t(:sm_learn, :move => nm) + ". " if nm && !nm.to_s.empty?
      end
      "#{t}#{PokeAccess::I18n.t(:sm_choose_forget)}. #{move_list_text(pk)}"
    rescue StandardError
      nil
    end

    # The current moves by name, each with its position while positions are said; drawSelectedMove reads one
    # in full.
    def self.move_list_text(pk)
      return PokeAccess::I18n.t(:sm_no_moves) unless pk && pk.moves
      out = []
      4.times do |i|
        m = (pk.moves[i] rescue nil)
        id = m ? PokeAccess::MoveInfo.id_of(m) : nil
        next unless PokeAccess::MoveInfo.real_id?(id)
        nm = (PokeAccess::Data.move_name(id) rescue nil) || PokeAccess::I18n.t(:info_move)
        out.push(PokeAccess::Verbosity.keep?(:positions, :medium) ? PokeAccess::I18n.t(:sm_move_pos, :n => i + 1, :name => nm) : nm)
      end
      out.empty? ? PokeAccess::I18n.t(:sm_no_moves) : PokeAccess::I18n.t(:sm_moves, :list => out.join(", "))
    rescue StandardError
      PokeAccess::I18n.t(:sm_no_moves)
    end

    # The scene class to hook, or "" (binding nothing) off a gen-6 engine; where both aliases exist, the ancestral
    # one, since a gen-6 fork may build only the v17 name (Engine.era_scene).
    SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonSummaryScene", "PokemonSummary_Scene")

    # The Pokemon a page redraw is about: the first argument, else the scene's @pokemon (Awakening passes none).
    def self.subject(scene, args)
      args[0] || PokeAccess.ivar(scene, :@pokemon)
    end

    # A move-detail redraw as [pokemon, move id], from (pokemon, moveToLearn, moveid[, flag]) or Awakening's
    # (moveToLearn, moveid), whose Pokemon comes from the scene.
    def self.selected_move(scene, args)
      return [PokeAccess.ivar(scene, :@pokemon), args[1]] if args.length < 3
      [args[0], args[2]]
    end
  end
end

# Clears the move-reorder tracking on opening, so a reorder left mid-way says nothing in the next summary.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryGen6::SCENE, :pbStartScene) do |_s, _a|
  PokeAccess::Summary.reset_reorder
end

# Info page: the data sheet, or the egg page. Skipped under Summary.single_page, whose profile reads it, but the
# egg capture is still taken so it does not stay armed.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageOne) do |s, _r, args|
  pk = PokeAccess::SummaryGen6.subject(s, args)
  pairs = PokeAccess::PaintCapture.take_pairs(:summary_egg)
  unless PokeAccess::Summary.single_page
    PokeAccess::Summary.say_egg_page(s, pk, pairs)
    unless PokeAccess::Summary.egg?(pk)
      dex = PokeAccess::Summary.painted_dex_number(pairs)
      heart = PokeAccess::Summary.heart_of(pk, pairs.select { |r| r[1] == :formatted }.map { |r| r[0] })
      t = PokeAccess::Info.summary_text(pk, dex)
      t = "#{t} #{heart}" if t && heart
      t = PokeAccess::Summary.with_hints(t, pairs.map { |r| r[0] })
      PokeAccess::Summary.speak_page(s, pk, 1, t, true)
    end
  end
end

# The egg page where drawPage calls drawPageOneEgg directly (Awakening); called from inside drawPageOne, this
# hook is skipped as nested, so the page is read once.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageOneEgg, :optional => true) do |s, _r, args|
  PokeAccess::Summary.say_egg_page(s, PokeAccess::SummaryGen6.subject(s, args))
end

# The ribbon cursor of Awakening's summary (drawSelectedRibbon(ribbonid)); other gen-6 ribbon pages are static.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawSelectedRibbon, :optional => true) do |s, _r, args|
  PokeAccess.speak(PokeAccess::Summary.ribbon_cell_text(s, args[0]), true)
end

# The memo page, read as painted (a game's own ways of meeting a Pokemon included); composed by memo_text where
# nothing was painted.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryGen6::SCENE, :drawPageTwo) do |_s, _a|
  PokeAccess::PaintCapture.arm(:summary_memo6)
end
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageTwo) do |s, _r, args|
  painted = PokeAccess::PaintCapture.take(:summary_memo6, :formatted)
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 2, PokeAccess::Summary.painted_memo(painted) || PokeAccess::SummaryGen6.memo_text(pk))
end

# Summary stats page (the five stats and ability), captured so the ability's description is said only where
# the page writes it.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryGen6::SCENE, :drawPageThree) do |_s, _a|
  PokeAccess::PaintCapture.arm(:summary_stats)
end
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageThree) do |s, _r, args|
  painted = PokeAccess::PaintCapture.take(:summary_stats)
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 3, PokeAccess::Summary.with_hints(PokeAccess::SummaryGen6.stats_text(pk, painted), painted))
end

# Summary moves page (drawPageFour lists the four moves): read them on arrival.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageFour) do |s, _r, args|
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 4, PokeAccess::Summary.moves_text(pk))
end

# Summary ribbons page, absent from a four-page summary (Uranium's Black/White one).
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawPageFive, :optional => true) do |s, _r, args|
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 5, PokeAccess::SummaryGen6.ribbons_text(pk))
end

# Move detail: each move read with its data when selected.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :drawSelectedMove) do |s, _r, args|
  pk, mid = PokeAccess::SummaryGen6.selected_move(s, args)
  PokeAccess.speak(PokeAccess::Info.move_by_id_info(pk, mid, :summary_move), true)
end

# Each frame: keeps the info key on the Pokemon shown (up/down switches it in place) unless a detail is focused,
# and polls the move reorder and the ribbon cursor.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryGen6::SCENE, :pbUpdate) do |scene, _r, _a|
  pk = PokeAccess.ivar(scene, :@pokemon)
  PokeAccess::Info.set_info(:pokemon, pk) if pk && !PokeAccess::SummaryGen6.detail_focused?(scene)
  PokeAccess::Summary.reorder_poll(scene)
  PokeAccess::Summary.ribbon_poll(scene)
end

# Learning a move with a full moveset: the new move and the current four, queued.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryGen6::SCENE, :pbChooseMoveToForget) do |scene, args|
  PokeAccess.speak(PokeAccess::SummaryGen6.relearn_text(scene.instance_variable_get(:@pokemon), args[0]), false)
end
