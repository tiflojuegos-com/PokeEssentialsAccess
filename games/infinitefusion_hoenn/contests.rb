# Hoenn's edited copy of the TDW Pokemon Contests plugin (the summary's contest face is chosen by map, not by the
# plugin's switch): the summary's contest pages, the talent round's narration and move choice, the hearts, the
# applause, the crowd's votes and the results, which the screens show only as icons and bars.
module PokeAccess
  module IF2Contests
    # The condition labels the contest page paints through the game's _INTL, in drawing order.
    CONDITION_LABELS = %w[Cool Beauty Cute Smart Tough]
    CONDITION_MAX = 255
    APPLAUSE_MAX = 5
    INTRO_POINTS_PER_HEART = 40

    # Whether a summary scene is showing its contest face.
    def self.contest_page?(scene)
      PokeAccess.ivar(scene, :@contestpage) ? true : false
    end

    # The summary's third page on its contest face: each painted condition label with its value, flagged where the
    # page draws the max icon.
    def self.conditions_text(pk)
      values = [pk.cool, pk.beauty, pk.cute, pk.smart, pk.tough]
      rows = CONDITION_LABELS.zip(values).map do |label, v|
        word = "#{_INTL(label)} #{v.to_i}"
        v.to_i >= CONDITION_MAX ? "#{word} #{PokeAccess::I18n.t(:cnd_max)}" : word
      end
      PokeAccess::I18n.t(:pbk_conditions, :list => rows.join(", "))
    rescue StandardError
      nil
    end

    # The contest category a move's icon shows, by the game's own name; nil for a move no contest takes.
    def self.category_name(data)
      return nil unless (data.contest_can_be_used? rescue false)
      (::GameData::ContestType.get(data.contest_type).name rescue nil)
    end

    # The appeal and jamming hearts a move's detail draws, [appeal, jam]; both 0 for a move no contest takes.
    def self.hearts_of(data)
      return [0, 0] unless (data.contest_can_be_used? rescue false)
      [(data.contest_hearts rescue 0).to_i, (data.contest_jam rescue 0).to_i]
    end

    # What a move's contest-type icon gives, from medium: its category, or, for a move no contest takes (whose icon
    # reads "???"), the contest description the game gives it, which says so.
    def self.category_part(data)
      cat = category_name(data)
      [cat ? PokeAccess::I18n.t(:if2_ct_category, :t => cat) : description(data), :medium]
    end

    # A move's contest parts from its category on, at the levels a move reading gives power and accuracy.
    def self.detail_parts(data)
      appeal, jam = hearts_of(data)
      [category_part(data), [PokeAccess::I18n.t(:if2_ct_appeal, :n => appeal), :full],
       [PokeAccess::I18n.t(:if2_ct_jam, :n => jam), :full]]
    end

    # The contest description a move's detail paints.
    def self.description(data)
      PokeAccess.clean((data.contest_description rescue "").to_s)
    end

    # The contest description in full, unless the category part has said it already.
    def self.description_part(data)
      category_name(data) ? [description(data), :full] : nil
    end

    # The summary's fourth page on its contest face: each move with its contest category (or the line saying no
    # contest takes it) and its pp.
    def self.moves_text(pk)
      out = []
      (pk.moves rescue []).each do |m|
        id = m ? PokeAccess::MoveInfo.id_of(m) : nil
        next unless PokeAccess::MoveInfo.real_id?(id)
        data = (::GameData::Move.get(id) rescue nil)
        parts = [[(m.name rescue id.to_s).to_s, :brief]]
        parts.push(category_part(data)) if data
        pp = (m.pp rescue nil)
        tot = PokeAccess.attr_of(m, :total_pp, :totalpp)
        parts.push([PokeAccess::I18n.t(:mv_pp, :pp => pp, :tot => tot), :brief]) if pp && tot
        out.push(PokeAccess::Verbosity.line(:summary_move, parts, ". "))
      end
      out.empty? ? PokeAccess::I18n.t(:sm_no_moves) : PokeAccess::I18n.t(:sm_moves, :list => out.join(", "))
    rescue StandardError
      nil
    end

    # The focused move on the contest face of the moves page: name, category, hearts, pp and contest description,
    # at the summary move reading's level; the info key keeps it whole.
    def self.summary_move(move)
      id = PokeAccess::MoveInfo.id_of(move)
      data = (::GameData::Move.get(id) rescue nil)
      return nil unless data
      parts = [[(move.name rescue data.name).to_s, :brief]].concat(detail_parts(data))
      pp = (move.pp rescue nil)
      tot = PokeAccess.attr_of(move, :total_pp, :totalpp)
      parts.push([PokeAccess::I18n.t(:mv_pp, :pp => pp, :tot => tot), :brief]) if pp && tot
      desc = description_part(data)
      parts.push(desc) if desc
      PokeAccess::Verbosity.info_line(:summary_move, parts, ". ")
    rescue StandardError
      nil
    end

    # What the talent round's move button says beyond its name, from its colour: a combo (purple) over a repeat of
    # the last move (grey), as the button is drawn.
    def self.flag(pk, data)
      return PokeAccess::I18n.t(:if2_ct_combo) if (pk.checkContestCombos(data) rescue false)
      last = (pk.c_lastmove rescue nil)
      return nil unless last
      (last.name rescue nil) == data.name ? PokeAccess::I18n.t(:if2_ct_repeat) : nil
    end

    # The talent round's focused move: its place, its button's mark, then category, hearts and description at the
    # battle move reading's level; the info key keeps it whole.
    def self.choice_line(pk, data, idx, count)
      parts = [[PokeAccess::Verbosity.list_entry(data.name.to_s, idx + 1, count), :brief]]
      mark = flag(pk, data)
      parts.push([mark, :brief]) if mark
      parts.concat(detail_parts(data))
      desc = description_part(data)
      parts.push(desc) if desc
      PokeAccess::Verbosity.info_line(:battle_move, parts, ". ")
    end

    # Speaks the talent round's focused move once per change; the first of a round is queued after the round's
    # question.
    def self.choice(scene, data)
      pk = (PokeAccess.ivar(scene, :@contest).playerPokemon rescue nil)
      idx = PokeAccess.ivar(scene, :@selection)
      return unless pk && data && idx.is_a?(Integer)
      count = (pk.numMoves rescue nil) || (pk.moves.compact.length rescue 1)
      PokeAccess::Cursor.announce(scene, :if2_ct_move, idx, true, false) { choice_line(pk, data, idx, count) }
    rescue StandardError
      nil
    end

    # A contestant's hearts this round, said when a heart change moved them.
    def self.hearts(pkmn, before)
      now = (pkmn.c_round_hearts rescue nil)
      return if now.nil? || now == before
      PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_hearts, :name => PokeAccess.clean(pkmn.name.to_s), :n => now.to_i),
                       false)
    rescue StandardError
      nil
    end

    # The applause meter's level, said when it changes.
    def self.applause(scene)
      e = (PokeAccess.ivar(scene, :@contest).crowdEnergy rescue nil)
      return unless e.is_a?(Integer)
      PokeAccess::Cursor.announce(scene, :if2_ct_applause, e, false) do
        PokeAccess::I18n.t(:if2_ct_applause, :n => e, :max => APPLAUSE_MAX)
      end
    end

    # The round's contestants in the order the panel lists them.
    def self.roster(scene)
      order = (PokeAccess.ivar(scene, :@contest).roundOrder rescue nil)
      order.is_a?(Array) ? order.compact : []
    end

    # The round's running order, said as the round opens.
    def self.order(scene)
      names = roster(scene).map { |p| PokeAccess.clean(p.name.to_s) }
      PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_order, :list => names.join(", ")), false) unless names.empty?
    rescue StandardError
      nil
    end

    # Every contestant's heart total once the round's meters settle, in the panel's order.
    def self.totals(scene)
      list = roster(scene).map { |p| "#{PokeAccess.clean(p.name.to_s)} #{(p.c_total_hearts rescue 0).to_i}" }
      PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_totals, :list => list.join(", ")), false) unless list.empty?
    rescue StandardError
      nil
    end

    # The hearts the crowd showed a contestant in the introduction round: the votes it scored, capped by the
    # crowd there is to show them.
    def self.crowd(contest, pokemon)
      hearts = (pokemon.c_intro_score rescue 0).to_i / INTRO_POINTS_PER_HEART
      crowd = PokeAccess.ivar(contest, :@crowdNPCs)
      hearts = [hearts, crowd.length].min if crowd.is_a?(Array)
      PokeAccess.speak(PokeAccess::I18n.t(:if2_ct_crowd, :name => PokeAccess.clean(pokemon.name.to_s), :n => hearts),
                       false)
    rescue StandardError
      nil
    end

    # The results screen's four rows, top to bottom: the three rivals, then the player.
    def self.entrants(scene)
      c = PokeAccess.ivar(scene, :@contest)
      [c.pokemonOne, c.pokemonTwo, c.pokemonThree, c.playerPokemon].compact
    rescue StandardError
      []
    end

    # A round's bars as each contestant's score, in the rows' order; kind :intro or :talent.
    def self.scores(scene, kind)
      list = entrants(scene).map do |p|
        n = (kind == :intro ? p.c_intro_score : p.c_total_hearts).to_i
        PokeAccess::I18n.t(:if2_ct_score, :name => PokeAccess.clean(p.name.to_s), :n => n)
      end
      PokeAccess.speak(list.join(", "), false) unless list.empty?
    rescue StandardError
      nil
    end

    # The places the result icons mark, first to last, each with its total; a tie the game's own tie-break leaves
    # (whose icons it stacks on the upper row) is ranked by row, upper first.
    def self.places(scene)
      rows = []
      entrants(scene).each_with_index { |p, i| rows.push([p, i, (p.c_total_score rescue 0).to_i]) }
      ranked = rows.sort_by { |r| [-r[2], r[1]] }
      list = []
      ranked.each_with_index do |r, pos|
        list.push(PokeAccess::I18n.t(:if2_ct_place, :pos => pos + 1, :name => PokeAccess.clean(r[0].name.to_s),
                                     :n => r[2]))
      end
      PokeAccess.speak(list.join(". "), false) unless list.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  override("PokeAccess::SummaryGameData", :legacy_page_text) do |_mod, original, args|
    pk, page, _memo, _painted, scene = args
    if PokeAccess::IF2Contests.contest_page?(scene) && page == 3
      PokeAccess::IF2Contests.conditions_text(pk)
    elsif PokeAccess::IF2Contests.contest_page?(scene) && page == 4
      PokeAccess::IF2Contests.moves_text(pk)
    else
      original.call
    end
  end

  override("PokeAccess::SummaryV21", :speak_move) do |_mod, original, args|
    scene, move = args
    if move && PokeAccess::IF2Contests.contest_page?(scene)
      PokeAccess.speak(PokeAccess::IF2Contests.summary_move(move), true)
    else
      original.call
    end
  end
end

# The talent round: every narration line goes through the plugin's own message box, which the dialogue reader
# never sees; the round opens with its running order, and each round's move choice starts afresh.
PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("pbMessageDisplayContest", :before) do |args, _r|
    t = args[1]
    PokeAccess.say_dialogue(t) if t.is_a?(String) && !t.empty?
  end

  before("PokemonContestTalent_Scene", :pbStartRound) { |s, _a| PokeAccess::IF2Contests.order(s) }
  before("PokemonContestTalent_Scene", :pbChooseMove) { |s, _a| PokeAccess::Cursor.reset(s, :if2_ct_move) }
  after("PokemonContestTalent_Scene", :pbMoveShowDetails) { |s, _r, a| PokeAccess::IF2Contests.choice(s, a[0]) }
end

# The icons and bars: a contestant's hearts as each change lands, the applause level, the round's totals once the
# meters settle, the crowd's votes in the introduction, and the results' bars and places. The meters slide in a loop
# of their own that ends by itself, and the totals are final only once it returns, so it runs as a container.
PokeAccess::Game.define("infinitefusion_hoenn") do
  around("PokemonContestTalent_Scene", :pbApplyHeartsChange) do |_s, nxt, args|
    before = (args[0].c_round_hearts rescue nil)
    r = nxt.call
    PokeAccess::IF2Contests.hearts(args[0], before)
    r
  end
  after("PokemonContestTalent_Scene", :updateApplauseMeter) { |s, _r, _a| PokeAccess::IF2Contests.applause(s) }
  after("PokemonContestTalent_Scene", :pbDrawContestantHeartMeters, :hook_container => true) do |s, _r, _a|
    PokeAccess::IF2Contests.totals(s)
  end
  after("PokemonContest", :showCrowdHearts) { |c, _r, a| PokeAccess::IF2Contests.crowd(c, a[0]) }
  after("PokemonContestResults_Scene", :pbShowIntroRoundBars) { |s, _r, _a| PokeAccess::IF2Contests.scores(s, :intro) }
  after("PokemonContestResults_Scene", :pbShowTalentRoundBars) { |s, _r, _a| PokeAccess::IF2Contests.scores(s, :talent) }
  after("PokemonContestResults_Scene", :pbShowPlaces) { |s, _r, _a| PokeAccess::IF2Contests.places(s) }
end
