# Infinite Fusion Hoenn's contests (games/infinitefusion_hoenn/contests.rb): the summary's contest face, the talent
# round's narration, moves, hearts and applause, the crowd's votes and the results, shown only as icons and bars.

# The game's contest data: each contest type by its name, and Hoenn's contest fields on a move (its type, appeal and
# jamming hearts and contest description); a move no contest takes has none but a line saying so, and the type its
# data names when the game's flag is what keeps it out.
module GameData
  class ContestType
    NAMES = { :COOL => "Cool", :BEAUTY => "Beauty", :CUTE => "Cute", :SMART => "Smart", :TOUGH => "Tough" }
    def self.get(id); NAMES[id] ? new(id) : raise("no contest type #{id}"); end
    def initialize(id); @id = id; end
    def name; NAMES[@id]; end
  end

  class Move
    NO_CONTEST = "Cannot be used in a contest."
    CONTEST = { :TACKLE => [:TOUGH, 4, 0, "A basic appeal."],
                :GROWL => [:CUTE, 1, 3, "Badly startles the Pokemon in front."] }
    FLAGGED_OUT = { :TRANSFORM => :COOL }
    def contest_can_be_used?; CONTEST.has_key?(@id); end
    def contest_type; CONTEST[@id] ? CONTEST[@id][0] : (FLAGGED_OUT[@id] || :NONE); end
    def contest_hearts; (CONTEST[@id] || [])[1]; end
    def contest_jam; (CONTEST[@id] || [])[2]; end
    def contest_description; CONTEST[@id] ? CONTEST[@id][3] : NO_CONTEST; end
  end
end

# The plugin's own message box, which the talent round narrates through.
def pbMessageDisplayContest(_msgwindow, message, _letterbyletter = true, _command_proc = nil); message; end

# The talent round, reduced to what the profile hooks: the round's opening, the move choice (each move focused in turn,
# its data shown), the hearts landing, the applause meter and the heart meters settling each total the plugin keeps.
class PokemonContestTalent_Scene
  # The data the move choice shows: the move's contest fields as GameData::Move keeps them, under its name.
  class MoveData
    attr_reader :name, :contest_type, :contest_hearts, :contest_jam, :contest_description
    def initialize(move)
      @name = move.name
      @contest_type, @contest_hearts, @contest_jam, @contest_description =
        GameData::Move::CONTEST[move.id] || [nil, nil, nil, GameData::Move::NO_CONTEST]
    end
    def contest_can_be_used?; !@contest_type.nil?; end
  end

  def initialize(contest); @contest = contest; end
  def pbStartRound; :round; end

  def pbChooseMove
    @contest.playerPokemon.moves.each_with_index do |move, i|
      @selection = i
      pbMoveShowDetails(MoveData.new(move))
    end
  end

  def pbMoveShowDetails(_data); end

  def pbApplyHeartsChange(pkmn)
    pkmn.c_round_hearts += pkmn.c_pending_hearts
    pkmn.c_pending_hearts = 0
  end

  def updateApplauseMeter; :meter; end

  def pbDrawContestantHeartMeters
    @contest.roundOrder.each { |p| p.c_total_hearts += p.c_round_hearts if p.respond_to?(:c_total_hearts) }
  end
end

# The contest itself, reduced to the introduction's crowd hearts for a contestant.
class PokemonContest
  def initialize(crowd); @crowdNPCs = crowd; end
  def showCrowdHearts(pokemon, _map); pokemon.c_intro_score = pokemon.votes * 40; end
end

# The results screen, reduced to its bars and places.
class PokemonContestResults_Scene
  def initialize(contest); @contest = contest; end
  def pbShowIntroRoundBars; :intro; end
  def pbShowTalentRoundBars; :talent; end
  def pbShowPlaces; :places; end
end

class IfhContestsGdTest < PokeAccessTest
  SUMMARY = PokeAccess::SummaryGameData.singleton_class
  SUMMARY_V21 = PokeAccess::SummaryV21.singleton_class
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "contests.rb")
  # A move as a Pokemon knows it.
  Move = Struct.new(:id, :name, :pp, :total_pp)
  # A contestant: its moves, its last move and combo, its hearts and scores, its votes and its five conditions.
  Entrant = Struct.new(:name, :moves, :c_lastmove, :combo, :c_round_hearts, :c_pending_hearts, :c_total_hearts,
                       :c_intro_score, :c_total_score, :votes, :cool, :beauty, :cute, :smart, :tough) do
    def numMoves; moves.length; end
    def checkContestCombos(_move); combo; end
  end
  # A contestant whose Pokemon has no move count of its own, nor the plugin's heart total and score.
  Bare = Struct.new(:name, :moves, :c_round_hearts)
  # A contestant the game gives no name.
  Nameless = Struct.new(:c_round_hearts, :c_pending_hearts, :c_total_hearts, :c_intro_score, :c_total_score, :votes)
  # The contest: the player's Pokemon, the round's order, the crowd's energy and the three rivals.
  Contest = Struct.new(:playerPokemon, :roundOrder, :crowdEnergy, :pokemonOne, :pokemonTwo, :pokemonThree)
  NO_CONTEST = GameData::Move::NO_CONTEST

  # A Pokemon of the summary with the five contest conditions.
  class Conditioned < TestPoke
    attr_accessor :cool, :beauty, :cute, :smart, :tough
  end

  # Evaluates the profile file once, as boot does, and answers its summary readers [legacy_page_text, speak_move]; its
  # hooks stay bound to the stand-ins above, while the core's readers are put back for the other tests of the process
  # (with_contest_face puts these in).
  def self.load_profile
    core = [SUMMARY.instance_method(:legacy_page_text), SUMMARY_V21.instance_method(:speak_move)]
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    begin
      eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
      [SUMMARY.instance_method(:legacy_page_text), SUMMARY_V21.instance_method(:speak_move)]
    ensure
      SUMMARY.send(:define_method, :legacy_page_text, core[0])
      SUMMARY_V21.send(:define_method, :speak_move, core[1])
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
    end
  end
  CORE_READERS = [SUMMARY.instance_method(:legacy_page_text), SUMMARY_V21.instance_method(:speak_move)]
  CONTEST_READERS = load_profile

  test "the contest face's third page reads the five conditions, a full one flagged as its max icon is" do
    pk = summary_pokemon
    pk.cool = 254
    pk.tough = 255
    assert_equal t(:pbk_conditions, :list => "Cool 254, Beauty 0, Cute 0, Smart 0, Tough 255 #{t(:cnd_max)}"),
                 contest_page(pk, 3)
  end

  test "a translated build's third page reads the condition labels in its own words" do
    words = { "Cool" => "Carisma", "Beauty" => "Belleza", "Cute" => "Dulzura", "Smart" => "Ingenio",
              "Tough" => "Dureza" }
    assert_equal t(:pbk_conditions, :list => "Carisma 0, Belleza 0, Dulzura 0, Ingenio 0, Dureza 0"),
                 with_intl(words) { contest_page(summary_pokemon, 3) }
  end

  test "the contest face has no third page for a Pokemon the game gives no conditions" do
    assert_nil contest_page(TestPoke.build(:name => "Zigzagoon", :level => 12), 3)
  end

  test "the contest face's fourth page reads each move with its contest category and its PP" do
    tackle = "Tackle. #{t(:if2_ct_category, :t => 'Tough')}. #{t(:mv_pp, :pp => 30, :tot => 35)}"
    growl = "Growl. #{t(:if2_ct_category, :t => 'Cute')}. #{t(:mv_pp, :pp => 40, :tot => 40)}"
    assert_equal t(:sm_moves, :list => "#{tackle}, #{growl}"), contest_page(summary_pokemon, 4)
  end

  test "the contest face's fourth page of a Pokemon with no moves says it has none" do
    pk = summary_pokemon
    pk.moves = [nil, Move.new(0, "", 0, 0)]
    assert_equal t(:sm_no_moves), contest_page(pk, 4)
  end

  test "the contest face has no fourth page for a Pokemon whose moves the game cannot list" do
    pk = summary_pokemon
    pk.moves = nil
    assert_nil contest_page(pk, 4)
  end

  test "the contest face's fourth page reads a move the game's data does not know by its name and PP alone" do
    pk = summary_pokemon
    pk.moves = [Move.new(:OLDMOVE, "Old Move", 5, 10), pk.moves[0]]
    tackle = "Tackle. #{t(:if2_ct_category, :t => 'Tough')}. #{t(:mv_pp, :pp => 30, :tot => 35)}"
    assert_equal t(:sm_moves, :list => "Old Move. #{t(:mv_pp, :pp => 5, :tot => 10)}, #{tackle}"),
                 with_unknown_move(:OLDMOVE) { contest_page(pk, 4) }
  end

  test "off the contest face, the third and fourth pages read as the core's" do
    scene = summary(summary_pokemon, false)
    core = [3, 4].map { |page| PokeAccess::SummaryGameData.page_text(scene, page) }
    assert_equal core, with_contest_face { [3, 4].map { |page| PokeAccess::SummaryGameData.page_text(scene, page) } }
  end

  test "on the contest face, the other pages read as the core's" do
    scene = summary(summary_pokemon, true)
    core = [1, 2, 5].map { |page| PokeAccess::SummaryGameData.page_text(scene, page) }
    assert_equal core, with_contest_face { [1, 2, 5].map { |page| PokeAccess::SummaryGameData.page_text(scene, page) } }
  end

  test "the contest face's move detail at the levels: name and PP, then its category, then hearts and description" do
    pk = summary_pokemon
    scene = summary(pk, true)
    rows = with_contest_face { vb_levels { detail_said(scene, pk.moves[1]) } }
    pp = t(:mv_pp, :pp => 40, :tot => 40)
    category = t(:if2_ct_category, :t => "Cute")
    assert_equal [[["Growl. #{pp}", true]], [["Growl. #{category}. #{pp}", true]],
                  [["Growl. #{category}. #{t(:if2_ct_appeal, :n => 1)}. #{t(:if2_ct_jam, :n => 3)}. #{pp}. " \
                    "Badly startles the Pokemon in front.", true]]], rows
  end

  test "the info key keeps the contest face's whole move detail at any level" do
    pk = summary_pokemon
    PokeAccess::Config.verbosity = :brief
    with_contest_face { detail_said(summary(pk, true), pk.moves[0]) }
    assert_equal "Tackle. #{t(:if2_ct_category, :t => 'Tough')}. #{t(:if2_ct_appeal, :n => 4)}. " \
                 "#{t(:if2_ct_jam, :n => 0)}. #{t(:mv_pp, :pp => 30, :tot => 35)}. A basic appeal.",
                 PokeAccess::Info.info_text
  end

  test "a move whose total PP the game does not give reads without its PP" do
    pk = summary_pokemon
    pk.moves = [Struct.new(:id, :name, :pp).new(:GROWL, "Growl", 40)]
    said = with_contest_face do
      [PokeAccess::SummaryGameData.page_text(summary(pk, true), 4), detail_said(summary(pk, true), pk.moves[0])]
    end
    category = t(:if2_ct_category, :t => "Cute")
    assert_equal [t(:sm_moves, :list => "Growl. #{category}"),
                  [["Growl. #{category}. #{t(:if2_ct_appeal, :n => 1)}. #{t(:if2_ct_jam, :n => 3)}. " \
                    "Badly startles the Pokemon in front.", true]]], said
  end

  test "the contest face's move detail says nothing of a move the game's data does not know" do
    move = Move.new(:OLDMOVE, "Old Move", 5, 10)
    said = with_unknown_move(:OLDMOVE) { with_contest_face { detail_said(summary(summary_pokemon, true), move) } }
    assert_equal [], said
  end

  test "off the contest face, the move detail is the core's" do
    pk = summary_pokemon
    scene = summary(pk, false)
    core = detail_said(scene, pk.moves[1])
    assert_equal core, with_contest_face { detail_said(scene, pk.moves[1]) }
  end

  test "a move no contest takes says the game's line in place of a category, from medium" do
    pk = splash_pokemon
    scene = summary(pk, true)
    pp = t(:mv_pp, :pp => 40, :tot => 40)
    PokeAccess::Config.verbosity = :medium
    said = with_contest_face do
      [PokeAccess::SummaryGameData.page_text(scene, 4), detail_said(scene, pk.moves[0])]
    end
    splash = "Splash. #{NO_CONTEST} #{pp}"
    tackle = "Tackle. #{t(:if2_ct_category, :t => 'Tough')}. #{t(:mv_pp, :pp => 30, :tot => 35)}"
    assert_equal [t(:sm_moves, :list => "#{splash}, #{tackle}"), [[splash, true]]], said
  end

  test "a move the game's flag keeps out of contests reads as one no contest takes, whatever type its data names" do
    pk = summary_pokemon
    pk.moves = [Move.new(:TRANSFORM, "Transform", 10, 10)]
    assert_equal t(:sm_moves, :list => "Transform. #{NO_CONTEST} #{t(:mv_pp, :pp => 10, :tot => 10)}"),
                 contest_page(pk, 4)
  end

  test "in full, a move no contest takes says the game's line once, with no hearts to draw" do
    pk = splash_pokemon
    said = with_contest_face { detail_said(summary(pk, true), pk.moves[0]) }
    assert_equal [["Splash. #{NO_CONTEST} #{t(:if2_ct_appeal, :n => 0)}. #{t(:if2_ct_jam, :n => 0)}. " \
                   "#{t(:mv_pp, :pp => 40, :tot => 40)}", true]], said
  end

  test "the plugin's message box is read as dialogue, its codes cleaned" do
    pbMessageDisplayContest(nil, "\\l[3]\\c[1]Appeal move no. 2!\\n\\c[0]Which move will you use?")
    assert_equal [["Appeal move no. 2! Which move will you use?", false]], SpeakCapture.log
  end

  test "an empty message box says nothing" do
    pbMessageDisplayContest(nil, "")
    pbMessageDisplayContest(nil, nil)
    assert_nothing_spoken
  end

  test "the round opens with its running order, queued" do
    zigzagoon = entrant("Zigzagoon")
    PokemonContestTalent_Scene.new(Contest.new(zigzagoon, [entrant("Wurmple"), zigzagoon], 0)).pbStartRound
    assert_equal [[t(:if2_ct_order, :list => "Wurmple, Zigzagoon"), false]], SpeakCapture.log
  end

  test "a round with no order says none" do
    PokemonContestTalent_Scene.new(Contest.new(entrant("Zigzagoon"), nil, 0)).pbStartRound
    assert_nothing_spoken
  end

  test "a round with nobody in it says neither its order nor its totals" do
    scene = PokemonContestTalent_Scene.new(Contest.new(entrant("Zigzagoon"), [], 0))
    scene.pbStartRound
    scene.pbDrawContestantHeartMeters
    assert_nothing_spoken
  end

  test "a move shown with no contest running says nothing" do
    scene = PokemonContestTalent_Scene.new(nil)
    scene.instance_variable_set(:@selection, 0)
    scene.pbMoveShowDetails(PokemonContestTalent_Scene::MoveData.new(Move.new(:GROWL, "Growl", 40, 40)))
    assert_nothing_spoken
  end

  test "the move choice reads each focused move once, the round's first queued after its question" do
    PokeAccess::Config.verbosity = :brief
    talent_round(entrant("Zigzagoon")).pbChooseMove
    assert_equal [["Tackle", false], ["Growl", true]], SpeakCapture.log
  end

  test "each round's choice reads its first move again" do
    PokeAccess::Config.verbosity = :brief
    scene = talent_round(entrant("Zigzagoon"))
    scene.pbChooseMove
    SpeakCapture.clear
    scene.pbChooseMove
    assert_equal [["Tackle", false], ["Growl", true]], SpeakCapture.log
  end

  test "a repeat of the last move is said as its grey button warns" do
    PokeAccess::Config.verbosity = :brief
    pk = entrant("Zigzagoon")
    pk.c_lastmove = pk.moves[0]
    talent_round(pk).pbChooseMove
    assert_equal ["Tackle. #{t(:if2_ct_repeat)}", "Growl"], SpeakCapture.lines
  end

  test "a combo is said over the repeat, as its purple button shows" do
    PokeAccess::Config.verbosity = :brief
    pk = entrant("Zigzagoon")
    pk.c_lastmove = pk.moves[0]
    pk.combo = true
    talent_round(pk).pbChooseMove
    assert_equal ["Tackle. #{t(:if2_ct_combo)}", "Growl. #{t(:if2_ct_combo)}"], SpeakCapture.lines
  end

  test "in full the choice says its place, category, hearts and contest description" do
    talent_round(entrant("Zigzagoon")).pbChooseMove
    assert_equal ["#{t(:list_entry, :name => 'Tackle', :n => 1, :tot => 2)}. #{t(:if2_ct_category, :t => 'Tough')}. " \
                  "#{t(:if2_ct_appeal, :n => 4)}. #{t(:if2_ct_jam, :n => 0)}. A basic appeal.",
                  "#{t(:list_entry, :name => 'Growl', :n => 2, :tot => 2)}. #{t(:if2_ct_category, :t => 'Cute')}. " \
                  "#{t(:if2_ct_appeal, :n => 1)}. #{t(:if2_ct_jam, :n => 3)}. Badly startles the Pokemon in front."],
                 SpeakCapture.lines
  end

  test "a contestant with no move count of its own is placed among the moves it knows, or as its only move" do
    PokeAccess::Config.verbosity = :medium
    tackle = Move.new(:TACKLE, "Tackle", 30, 35)
    known = { "two moves known" => [[tackle, Move.new(:GROWL, "Growl", 40, 40)], 2], "no moves known" => [nil, 1] }
    known.each do |label, (moves, count)|
      scene = talent_round(Bare.new("Zigzagoon", moves, 0))
      scene.instance_variable_set(:@selection, 0)
      SpeakCapture.clear
      scene.pbMoveShowDetails(PokemonContestTalent_Scene::MoveData.new(tackle))
      line = "#{t(:list_entry, :name => 'Tackle', :n => 1, :tot => count)}. #{t(:if2_ct_category, :t => 'Tough')}"
      assert_equal [line], SpeakCapture.lines, label
    end
  end

  test "the info key keeps the focused move's whole detail at any level" do
    PokeAccess::Config.verbosity = :brief
    talent_round(entrant("Zigzagoon")).pbChooseMove
    assert_equal "Growl. #{t(:if2_ct_category, :t => 'Cute')}. " \
                 "#{t(:if2_ct_appeal, :n => 1)}. #{t(:if2_ct_jam, :n => 3)}. Badly startles the Pokemon in front.",
                 PokeAccess::Info.info_text
  end

  test "in the talent round a move no contest takes says the game's line from medium" do
    PokeAccess::Config.verbosity = :medium
    talent_round(splash_pokemon).pbChooseMove
    assert_equal "#{t(:list_entry, :name => 'Splash', :n => 1, :tot => 2)}. #{NO_CONTEST}", SpeakCapture.lines[0]
  end

  test "hearts landing say the contestant's count this round, queued" do
    pk = entrant("Zigzagoon")
    pk.c_pending_hearts = 3
    talent_round(pk).pbApplyHeartsChange(pk)
    assert_equal [[t(:if2_ct_hearts, :name => "Zigzagoon", :n => 3), false]], SpeakCapture.log
  end

  test "a heart change that moves nothing says nothing" do
    pk = entrant("Zigzagoon")
    talent_round(pk).pbApplyHeartsChange(pk)
    assert_nothing_spoken
  end

  test "a jam says the hearts lost" do
    pk = entrant("Wurmple")
    pk.c_pending_hearts = -2
    talent_round(pk).pbApplyHeartsChange(pk)
    assert_equal [t(:if2_ct_hearts, :name => "Wurmple", :n => -2)], SpeakCapture.lines
  end

  test "hearts landing on a contestant the game gives no name are not said, and land all the same" do
    rival = Nameless.new(0, 2, 0, 0, 0, 0)
    assert_equal 0, talent_round(entrant("Zigzagoon")).pbApplyHeartsChange(rival), "the change's own return"
    assert_equal 2, rival.c_round_hearts, "the hearts landed"
    assert_nothing_spoken
  end

  test "the applause level is said once per change, queued" do
    contest = Contest.new(entrant("Zigzagoon"), [], 2)
    scene = PokemonContestTalent_Scene.new(contest)
    scene.updateApplauseMeter
    scene.updateApplauseMeter
    contest.crowdEnergy = 3
    scene.updateApplauseMeter
    assert_equal [[t(:if2_ct_applause, :n => 2, :max => 5), false], [t(:if2_ct_applause, :n => 3, :max => 5), false]],
                 SpeakCapture.log
  end

  test "a meter with no energy to show says nothing" do
    PokemonContestTalent_Scene.new(Contest.new(entrant("Zigzagoon"), [], nil)).updateApplauseMeter
    assert_nothing_spoken
  end

  test "the round's heart totals are said once the meters settle, in the panel's order, queued" do
    a = entrant("Zigzagoon")
    b = entrant("Wurmple")
    a.c_round_hearts = 3
    b.c_round_hearts = -2
    PokemonContestTalent_Scene.new(Contest.new(a, [b, a], 0)).pbDrawContestantHeartMeters
    assert_equal [[t(:if2_ct_totals, :list => "Wurmple -2, Zigzagoon 3"), false]], SpeakCapture.log
  end

  test "a contestant without the plugin's heart total counts none in the round's totals" do
    pk = entrant("Zigzagoon")
    pk.c_round_hearts = 3
    PokemonContestTalent_Scene.new(Contest.new(pk, [Bare.new("Wurmple", [], 2), pk], 0)).pbDrawContestantHeartMeters
    assert_equal [t(:if2_ct_totals, :list => "Wurmple 0, Zigzagoon 3")], SpeakCapture.lines
  end

  test "the crowd's hearts in the introduction, capped by the crowd there is to show them, queued" do
    [[5, [1, 2, 3], 3], [2, [1, 2, 3], 2], [5, nil, 5]].each do |votes, crowd, hearts|
      pk = entrant("Zigzagoon")
      pk.votes = votes
      SpeakCapture.clear
      PokemonContest.new(crowd).showCrowdHearts(pk, 1)
      assert_equal [[t(:if2_ct_crowd, :name => "Zigzagoon", :n => hearts), false]], SpeakCapture.log,
                   "#{votes} votes, a crowd of #{crowd.inspect}"
    end
  end

  test "the results read the introduction's bars row by row, the player's last, queued" do
    results.pbShowIntroRoundBars
    bars = [score("Wurmple", 80), score("Taillow", 160), score("Ralts", 40), score("Zigzagoon", 120)]
    assert_equal [[bars.join(", "), false]], SpeakCapture.log
  end

  test "the results read the talent round's bars row by row" do
    results.pbShowTalentRoundBars
    bars = [score("Wurmple", 120), score("Taillow", 40), score("Ralts", 40), score("Zigzagoon", 120)]
    assert_equal [bars.join(", ")], SpeakCapture.lines
  end

  test "the results read the places first to last, a tie going to the upper row, queued" do
    results.pbShowPlaces
    places = [place(1, "Zigzagoon", 240), place(2, "Wurmple", 200), place(3, "Taillow", 200), place(4, "Ralts", 80)]
    assert_equal [[places.join(". "), false]], SpeakCapture.log
  end

  test "a contestant without the plugin's total score is placed with none" do
    pk = entrant("Zigzagoon")
    pk.c_total_score = 120
    PokemonContestResults_Scene.new(Contest.new(pk, nil, 0, Bare.new("Wurmple", [], 0))).pbShowPlaces
    assert_equal [[place(1, "Zigzagoon", 120), place(2, "Wurmple", 0)].join(". ")], SpeakCapture.lines
  end

  test "a results screen with no contest says nothing" do
    scene = PokemonContestResults_Scene.new(nil)
    scene.pbShowIntroRoundBars
    scene.pbShowPlaces
    assert_nothing_spoken
  end

  test "a contestant the game gives no name silences the order, the totals, the crowd, the bars and the places" do
    rival = Nameless.new(1, 0, 0, 40, 80, 3)
    pk = entrant("Zigzagoon")
    round = PokemonContestTalent_Scene.new(Contest.new(pk, [rival, pk], 0))
    results = PokemonContestResults_Scene.new(Contest.new(pk, nil, 0, rival, entrant("Wurmple"), entrant("Ralts")))
    readers = { "order" => lambda { round.pbStartRound }, "totals" => lambda { round.pbDrawContestantHeartMeters },
                "crowd" => lambda { PokemonContest.new([1, 2, 3]).showCrowdHearts(rival, 1) },
                "bars" => lambda { results.pbShowIntroRoundBars }, "places" => lambda { results.pbShowPlaces } }
    readers.each do |reader, run|
      SpeakCapture.clear
      run.call
      assert_nothing_spoken reader
    end
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # An entrant with a Tackle and a Growl, every counter at zero.
  def entrant(name)
    Entrant.new(name, [Move.new(:TACKLE, "Tackle", 30, 35), Move.new(:GROWL, "Growl", 40, 40)], nil, false,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  end

  # A Magikarp entrant whose Splash no contest takes, then a Tackle.
  def splash_pokemon
    pk = entrant("Magikarp")
    pk.moves = [Move.new(:SPLASH, "Splash", 40, 40), Move.new(:TACKLE, "Tackle", 30, 35)]
    pk
  end

  # Zigzagoon in the summary, with a Tackle and a Growl and every condition at zero.
  def summary_pokemon
    pk = Conditioned.build(:name => "Zigzagoon", :level => 12)
    pk.moves = [Move.new(:TACKLE, "Tackle", 30, 35), Move.new(:GROWL, "Growl", 40, 40)]
    [:cool=, :beauty=, :cute=, :smart=, :tough=].each { |w| pk.send(w, 0) }
    pk
  end

  # The summary of pk, on its contest face or not.
  def summary(pk, contest_face)
    scene = PokemonSummary_Scene.new(pk)
    scene.instance_variable_set(:@contestpage, contest_face)
    scene
  end

  # What the summary of pk says of a page on its contest face.
  def contest_page(pk, page)
    with_contest_face { PokeAccess::SummaryGameData.page_text(summary(pk, true), page) }
  end

  # What the summary says as its moves page focuses move, as [text, interrupt] pairs.
  def detail_said(scene, move)
    SpeakCapture.clear
    scene.drawSelectedMove(nil, move)
    SpeakCapture.log.dup
  end

  # The talent round of a contest where pk competes alone.
  def talent_round(pk)
    PokemonContestTalent_Scene.new(Contest.new(pk, [pk], 0))
  end

  # A results bar: the contestant and its points.
  def score(name, n)
    t(:if2_ct_score, :name => name, :n => n)
  end

  # A place on the results: its rank, the contestant and its total.
  def place(pos, name, n)
    t(:if2_ct_place, :pos => pos, :name => name, :n => n)
  end

  # The results of a contest of four: three rivals then the player, each with its introduction score and its hearts.
  def results
    scores = [["Wurmple", 80, 120], ["Taillow", 160, 40], ["Ralts", 40, 40], ["Zigzagoon", 120, 120]]
    rows = scores.map do |name, intro, talent|
      pk = entrant(name)
      pk.c_intro_score = intro
      pk.c_total_hearts = talent
      pk.c_total_score = intro + talent
      pk
    end
    PokemonContestResults_Scene.new(Contest.new(rows[3], nil, 0, rows[0], rows[1], rows[2]))
  end

  # Runs the block with the profile's summary readers in place of the core's, put back afterwards.
  def with_contest_face
    SUMMARY.send(:define_method, :legacy_page_text, CONTEST_READERS[0])
    SUMMARY_V21.send(:define_method, :speak_move, CONTEST_READERS[1])
    yield
  ensure
    SUMMARY.send(:define_method, :legacy_page_text, CORE_READERS[0])
    SUMMARY_V21.send(:define_method, :speak_move, CORE_READERS[1])
  end

  # Runs the block with GameData::Move.get raising for id, as the game's data does for a move it does not know, the
  # stub's own get put back afterwards.
  def with_unknown_move(id)
    meta = GameData::Move.singleton_class
    meta.send(:alias_method, :pa_test_get, :get)
    meta.send(:define_method, :get) { |m| m == id ? raise(ArgumentError, "unknown move #{m}") : pa_test_get(m) }
    yield
  ensure
    meta.send(:alias_method, :get, :pa_test_get)
    meta.send(:remove_method, :pa_test_get)
  end
end
