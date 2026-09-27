# Infinite Fusion Hoenn's contests (its edited TDW Pokemon Contests copy), gamedata pass: the summary's contest face,
# the talent round's narration and move choice, the hearts, the applause, the crowd's votes and the results. The
# stand-ins come before the profile file loads: a hook on a missing class binds nothing.
module GameData
  class ContestType
    NAMES = { :COOL => "Cool", :BEAUTY => "Beauty", :CUTE => "Cute", :SMART => "Smart", :TOUGH => "Tough" }
    def self.get(id); NAMES[id] ? new(id) : raise("no contest type #{id}"); end
    def initialize(id); @id = id; end
    def name; NAMES[@id]; end
  end

  class Move
    CONTEST = {
      :TACKLE => [:TOUGH, 4, 0, "A basic appeal."],
      :GROWL => [:CUTE, 1, 3, "Badly startles the Pokemon in front."]
    }
    def contest_can_be_used?; CONTEST.has_key?(@id); end
    def contest_type; (CONTEST[@id] || [:NONE])[0]; end
    def contest_hearts; (CONTEST[@id] || [])[1]; end
    def contest_jam; (CONTEST[@id] || [])[2]; end
    def contest_description; CONTEST[@id] ? CONTEST[@id][3] : "Cannot be used in a contest."; end
  end
end

def pbMessageDisplayContest(_msgwindow, message, _letterbyletter = true, _command_proc = nil); message; end

class PokemonContestTalent_Scene
  attr_accessor :shown
  def initialize(contest); @contest = contest; end
  def pbStartRound; :round; end
  def pbChooseMove
    @shown = []
    [0, 1].each do |i|
      @selection = i
      pbMoveShowDetails(IfhContestRig.data(@contest.playerPokemon.moves[i]))
    end
  end
  def pbMoveShowDetails(move); @shown.push(move); end
  def pbApplyHeartsChange(pkmn)
    pkmn.c_round_hearts += pkmn.c_pending_hearts
    pkmn.c_pending_hearts = 0
  end
  def updateApplauseMeter; :meter; end
  def pbDrawContestantHeartMeters
    @contest.roundOrder.each { |p| p.c_total_hearts += p.c_round_hearts }
  end
end

class PokemonContest
  def initialize(crowd); @crowdNPCs = crowd; end
  def showCrowdHearts(pokemon, _map); pokemon.c_intro_score = pokemon.votes * 40; end
end

class PokemonContestResults_Scene
  def initialize(contest); @contest = contest; end
  def pbShowIntroRoundBars; :intro; end
  def pbShowTalentRoundBars; :talent; end
  def pbShowPlaces; :places; end
end

load File.expand_path("../../../games/infinitefusion_hoenn/contests.rb", File.dirname(__FILE__))

module IfhContestRig
  Move = Struct.new(:id, :name, :pp, :total_pp)

  # A move's data as the talent round hands it over (a GameData::Move with the contest fields), named as the move; one
  # no contest takes has no contest fields and the game's line saying so.
  class ContestData
    attr_reader :name, :contest_type, :contest_hearts, :contest_jam, :contest_description
    def initialize(name, row)
      @name = name
      @contest_type, @contest_hearts, @contest_jam, @contest_description = row || [nil, nil, nil, NO_CONTEST]
    end
    def contest_can_be_used?; !@contest_type.nil?; end
  end
  NO_CONTEST = "Cannot be used in a contest."

  def self.data(move)
    ContestData.new(move.name, GameData::Move::CONTEST[move.id])
  end
  Entrant = Struct.new(:name, :moves, :c_lastmove, :combo, :c_round_hearts, :c_pending_hearts, :c_total_hearts,
                       :c_intro_score, :c_total_score, :votes, :cool, :beauty, :cute, :smart, :tough)
  Contest = Struct.new(:playerPokemon, :roundOrder, :crowdEnergy, :pokemonOne, :pokemonTwo, :pokemonThree)

  # An entrant with a Tackle and a Growl, every counter at zero.
  def self.entrant(name)
    e = Entrant.new(name, [Move.new(:TACKLE, "Tackle", 30, 35), Move.new(:GROWL, "Growl", 40, 40)], nil, false,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    def e.numMoves; moves.length; end
    def e.checkContestCombos(_move); combo; end
    e
  end
end

Suite.define("ifh contests: the lobby's summary reads the conditions and the contest moves the page paints") do
  t = PokeAccess::I18n
  pk = IfhContestRig.entrant("Zigzagoon")
  pk.cool = 120
  pk.tough = 255
  scene = PokemonSummary_Scene.new(pk)
  scene.instance_variable_set(:@contestpage, true)
  want = t.t(:pbk_conditions, :list => "Cool 120, Beauty 0, Cute 0, Smart 0, Tough 255 #{t.t(:cnd_max)}")
  eq "page three is the five conditions, the full one flagged as the max icon does",
     PokeAccess::SummaryGameData.page_text(scene, 3), want
  tackle = ["Tackle", t.t(:if2_ct_category, :t => "Tough"), t.t(:mv_pp, :pp => 30, :tot => 35)].join(". ")
  growl = ["Growl", t.t(:if2_ct_category, :t => "Cute"), t.t(:mv_pp, :pp => 40, :tot => 40)].join(". ")
  eq "page four is each move with its contest category and its pp",
     PokeAccess::SummaryGameData.page_text(scene, 4), t.t(:sm_moves, :list => "#{tackle}, #{growl}")
  scene.instance_variable_set(:@contestpage, false)
  falsy "and off the contest face page three is the stats again",
        PokeAccess::SummaryGameData.page_text(scene, 3).to_s.include?("Cool")
end

Suite.define("ifh contests: the summary's contest face reads a move's category, hearts and contest description") do
  t = PokeAccess::I18n
  pk = IfhContestRig.entrant("Zigzagoon")
  scene = PokemonSummary_Scene.new(pk)
  scene.instance_variable_set(:@contestpage, true)
  rows = vb_levels do
    SpeakCapture.clear
    scene.drawSelectedMove(nil, pk.moves[1])
    SpeakCapture.last
  end
  eq "brief: the name and its pp", rows[0], "Growl. #{t.t(:mv_pp, :pp => 40, :tot => 40)}"
  eq "medium: its contest category too", rows[1],
     "Growl. #{t.t(:if2_ct_category, :t => 'Cute')}. #{t.t(:mv_pp, :pp => 40, :tot => 40)}"
  eq "full: the appeal and jamming hearts and the contest description", rows[2],
     ["Growl", t.t(:if2_ct_category, :t => "Cute"), t.t(:if2_ct_appeal, :n => 1), t.t(:if2_ct_jam, :n => 3),
      t.t(:mv_pp, :pp => 40, :tot => 40), "Badly startles the Pokemon in front."].join(". ")
  scene.instance_variable_set(:@contestpage, false)
  SpeakCapture.clear
  scene.drawSelectedMove(nil, pk.moves[1])
  falsy "off the contest face the battle detail is back", SpeakCapture.last.to_s.include?("Badly startles")
end

Suite.define("ifh contests: the plugin's own message box is read as dialogue") do
  SpeakCapture.clear
  pbMessageDisplayContest(nil, "\\l[3]\\c[1]Appeal move no. 2!\\n\\c[0]Which move will you use?")
  spoke "the round's question, its codes cleaned", /\AAppeal move no\. 2! Which move will you use\?\z/
end

Suite.define("ifh contests: the move choice reads each move once, the round's first queued, and marks its button") do
  t = PokeAccess::I18n
  pk = IfhContestRig.entrant("Zigzagoon")
  scene = PokemonContestTalent_Scene.new(IfhContestRig::Contest.new(pk, [pk], 0))
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    scene.pbChooseMove
    eq "brief: each focused move by name", SpeakCapture.lines, ["Tackle", "Growl"]
    eq "the first after the round's question, the next one interrupting", SpeakCapture.log.map { |l| l[1] },
       [false, true]
    pk.c_lastmove = pk.moves[0]
    SpeakCapture.clear
    scene.pbChooseMove
    eq "a new round reads its first move again, with the repeat the grey button warns of", SpeakCapture.lines[0],
       "Tackle. #{t.t(:if2_ct_repeat)}"
    pk.combo = true
    SpeakCapture.clear
    scene.pbChooseMove
    eq "and a combo, which the purple button shows over the repeat", SpeakCapture.lines[0],
       "Tackle. #{t.t(:if2_ct_combo)}"
  ensure
    PokeAccess::Config.verbosity = :full
  end
  pk.combo = false
  pk.c_lastmove = nil
  SpeakCapture.clear
  scene.pbChooseMove
  eq "full: the category, the hearts and the contest description", SpeakCapture.lines[1],
     [t.t(:list_entry, :name => "Growl", :n => 2, :tot => 2), t.t(:if2_ct_category, :t => "Cute"),
      t.t(:if2_ct_appeal, :n => 1), t.t(:if2_ct_jam, :n => 3), "Badly startles the Pokemon in front."].join(". ")
end

Suite.define("ifh contests: a move no contest takes says so from medium, where its icon reads ???") do
  t = PokeAccess::I18n
  pk = IfhContestRig.entrant("Magikarp")
  pk.moves = [IfhContestRig::Move.new(:SPLASH, "Splash", 40, 40), IfhContestRig::Move.new(:TACKLE, "Tackle", 30, 35)]
  scene = PokemonSummary_Scene.new(pk)
  scene.instance_variable_set(:@contestpage, true)
  pp40 = t.t(:mv_pp, :pp => 40, :tot => 40)
  PokeAccess::Config.verbosity = :medium
  begin
    match "the moves page, the game's line in place of a category", PokeAccess::SummaryGameData.page_text(scene, 4),
          /\A#{Regexp.escape(t.t(:sm_moves, :list => "Splash. #{IfhContestRig::NO_CONTEST} #{pp40}, Tackle"))}/
    SpeakCapture.clear
    scene.drawSelectedMove(nil, pk.moves[0])
    eq "the detail, likewise", SpeakCapture.last, "Splash. #{IfhContestRig::NO_CONTEST} #{pp40}"
    talent = PokemonContestTalent_Scene.new(IfhContestRig::Contest.new(pk, [pk], 0))
    SpeakCapture.clear
    talent.pbChooseMove
    eq "and the talent round's choice", SpeakCapture.lines[0],
       "#{t.t(:list_entry, :name => 'Splash', :n => 1, :tot => 2)}. #{IfhContestRig::NO_CONTEST}"
  ensure
    PokeAccess::Config.verbosity = :full
  end
  SpeakCapture.clear
  scene.drawSelectedMove(nil, pk.moves[0])
  eq "in full said once, with no hearts to draw", SpeakCapture.last,
     PokeAccess.sentences(["Splash", IfhContestRig::NO_CONTEST, t.t(:if2_ct_appeal, :n => 0), t.t(:if2_ct_jam, :n => 0), pp40])
end

Suite.define("ifh contests: hearts, applause, order and totals, which the panel shows only as icons") do
  t = PokeAccess::I18n
  a = IfhContestRig.entrant("Zigzagoon")
  b = IfhContestRig.entrant("Wurmple")
  contest = IfhContestRig::Contest.new(a, [b, a], 0)
  scene = PokemonContestTalent_Scene.new(contest)
  SpeakCapture.clear
  scene.pbStartRound
  eq "the round opens with its running order", SpeakCapture.last, t.t(:if2_ct_order, :list => "Wurmple, Zigzagoon")
  a.c_pending_hearts = 3
  SpeakCapture.clear
  scene.pbApplyHeartsChange(a)
  eq "hearts landing say the round's count", SpeakCapture.lines, [t.t(:if2_ct_hearts, :name => "Zigzagoon", :n => 3)]
  eq "queued after the line that caused them", SpeakCapture.log[0][1], false
  SpeakCapture.clear
  scene.pbApplyHeartsChange(a)
  silent "no change, nothing said"
  b.c_pending_hearts = -2
  scene.pbApplyHeartsChange(b)
  eq "a jam says the loss", SpeakCapture.last, t.t(:if2_ct_hearts, :name => "Wurmple", :n => -2)
  contest.crowdEnergy = 2
  SpeakCapture.clear
  scene.updateApplauseMeter
  scene.updateApplauseMeter
  eq "the applause level, once per change", SpeakCapture.lines, [t.t(:if2_ct_applause, :n => 2, :max => 5)]
  SpeakCapture.clear
  scene.pbDrawContestantHeartMeters
  eq "the round's totals once the meters settle", SpeakCapture.last,
     t.t(:if2_ct_totals, :list => "Wurmple -2, Zigzagoon 3")
end

Suite.define("ifh contests: the crowd's hearts in the introduction and the results' bars and places") do
  t = PokeAccess::I18n
  a = IfhContestRig.entrant("Zigzagoon")
  a.votes = 5
  SpeakCapture.clear
  PokemonContest.new([1, 2, 3]).showCrowdHearts(a, 1)
  eq "the hearts the crowd shows, capped by its size", SpeakCapture.last,
     t.t(:if2_ct_crowd, :name => "Zigzagoon", :n => 3)
  one = IfhContestRig.entrant("Wurmple")
  two = IfhContestRig.entrant("Taillow")
  three = IfhContestRig.entrant("Ralts")
  [[one, 80, 120], [two, 160, 40], [three, 40, 40], [a, 120, 120]].each do |p, intro, talent|
    p.c_intro_score = intro
    p.c_total_hearts = talent
    p.c_total_score = intro + talent
  end
  scene = PokemonContestResults_Scene.new(IfhContestRig::Contest.new(a, nil, 0, one, two, three))
  SpeakCapture.clear
  scene.pbShowIntroRoundBars
  eq "the introduction's bars, row by row", SpeakCapture.last,
     [t.t(:if2_ct_score, :name => "Wurmple", :n => 80), t.t(:if2_ct_score, :name => "Taillow", :n => 160),
      t.t(:if2_ct_score, :name => "Ralts", :n => 40), t.t(:if2_ct_score, :name => "Zigzagoon", :n => 120)].join(", ")
  scene.pbShowTalentRoundBars
  match "then the talent round's", SpeakCapture.last, /\A#{Regexp.escape(t.t(:if2_ct_score, :name => 'Wurmple', :n => 120))}/
  scene.pbShowPlaces
  eq "and the places, first to last, a tie to the upper row", SpeakCapture.last,
     [t.t(:if2_ct_place, :pos => 1, :name => "Zigzagoon", :n => 240), t.t(:if2_ct_place, :pos => 2, :name => "Wurmple", :n => 200),
      t.t(:if2_ct_place, :pos => 3, :name => "Taillow", :n => 200), t.t(:if2_ct_place, :pos => 4, :name => "Ralts", :n => 80)].join(". ")
end
