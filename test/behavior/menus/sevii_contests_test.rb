# Sevii's contests (games/sevii/contests.rb) on a stand-in of its edited copy of the contests script, PokeContestScene:
# the move menu, the round and its running order, the hearts, the applause, the crowd's votes, the oblivious mark and
# the results, which the stage shows only as pictures, icons and bars.

# The contest moves the game compiles, each named as PBContestMoves.getName names it, after the battle move of its own
# number: two share the name of battle move 33, and the menu shows the first of them.
module PBContestMoves
  NAMES = { 2 => "Mov33", 5 => "Mov45", 8 => "Mov33" }
  def self.maxValue; 9; end
  def self.getName(id); NAMES[id] || ""; end
end

# A contest move's data as contestmoves.dat keeps it: its category's row on the strip, its appeal and jamming hearts.
class PBContestMoveData
  DATA = { 2 => [4, 4, 0], 5 => [2, 1, 3], 8 => [0, 2, 2] }
  attr_reader :contestType, :hearts, :jam
  def initialize(id); @contestType, @hearts, @jam = DATA[id] || [0, 0, 0]; end
end

module MessageTypes
  ContestMoveDescriptions = 26 unless const_defined?(:ContestMoveDescriptions)
end

class Some_methods_contest; end

# The scene, reduced to what the profile hooks: the move menu's opening and cursor, the side panel's repaint, the heart
# meters, the crowd's turn, the presentation's votes, the oblivious marks and the results' labels.
class PokeContestScene < Some_methods_contest
  OBLIVIOUS = %w[obliviousone oblivioustwo obliviousthree obliviousfour]
  HEARTS = [:@pkmn1hearts, :@pkmn2hearts, :@pkmn3hearts, :@pkmn4hearts]

  def initialize(entrants)
    @pkmn1, @pkmn2, @pkmn3, @pkmn4 = entrants
    @pokeorder = entrants.dup
    @round = 1
    @applause = 0
    @crowdexcitment = true
    HEARTS.each { |v| instance_variable_set(v, 0) }
    @Oblivious = [false, false, false, false]
    @sprites = {}
  end

  def choose_move; @selection = 0; end
  def set_name_move; end
  def pbDrawText; end

  # Adds @currenthearts to the performer's hearts.
  def pbDisplayAddingPositiveHearts
    add_hearts(@currentpoke, @currenthearts)
  end

  # Takes @jam hearts from target.
  def pbDecreaseHearts(target, _position, _selfjam = nil)
    add_hearts(target, -@jam.to_i)
  end

  # The crowd's turn as the game plays it: a move of the contest's category takes the meter up one with a heart, and
  # five more as it fills, after which it empties; any other takes it down one with a heart lost. A move that set the
  # level itself ("notnil") leaves it.
  def pbCrowd(move = nil)
    return unless move.nil?
    if @moveType == @contestType
      @applause += 1
      @currenthearts = 1
      pbDisplayAddingPositiveHearts
    elsif @applause > 0
      @applause -= 1
      @jam = 1
      pbDecreaseHearts(@currentpoke, 1, "notnil")
    end
    return unless @crowdexcitment && @applause == 5
    @currenthearts = 5
    pbDisplayAddingPositiveHearts
    @applause = 0
  end

  # The crowd's hearts for poke: character_show_heart with the count @shown gives its name, no call for none.
  def show_heart_vote(poke, _number)
    n = (@shown || {})[poke.name].to_i
    character_show_heart(n, 7, 8, 9, 10, 11, 12) if n > 0
  end

  def character_show_heart(_number, *_ids); end

  # Puts up or takes down each place's oblivious mark as its flag says.
  def pbObliviousGraphic
    OBLIVIOUS.each_with_index { |k, i| @sprites[k] = @Oblivious[i] ? (@sprites[k] || Object.new) : nil }
  end

  # Paints the results' three labels on its text strip, with a line of another bitmap between them.
  def pbResultsScene
    strip = @sprites["textbitmap"].bitmap
    pbDrawTextPositions(strip, [["The preliminary results!", 170, 309, 0]])
    pbDrawTextPositions(Object.new, [["Elsewhere", 0, 0, 0]])
    pbDrawTextPositions(strip, [["Round 2 results!", 170, 309, 0]])
    pbDrawTextPositions(strip, [[_INTL("{1} is the winner!", @order_winner[0].name), 170, 309, 0]])
  end

  private

  # Adds n to pkmn's hearts this round.
  def add_hearts(pkmn, n)
    v = HEARTS[[@pkmn1, @pkmn2, @pkmn3, @pkmn4].index(pkmn)]
    instance_variable_set(v, instance_variable_get(v) + n)
  end
end

sevii_contests = File.join(Harness::ROOT, "games", "sevii", "contests.rb")
eval(Harness.source(sevii_contests), TOPLEVEL_BINDING, sevii_contests)

class SeviiContestsTest < PokeAccessTest
  # A move as a Pokemon knows it.
  Move = Struct.new(:id)
  # The results screen's text strip.
  Strip = Struct.new(:bitmap)
  NAMES = %w[Pikachu Ledyba Aron Totodile]

  # A contestant: its name and the moves it knows.
  class Entrant
    attr_reader :name, :moves
    def initialize(name, moves = []); @name = name; @moves = moves; end
    def numMoves; @moves.length; end
  end

  test "the move menu opens with its round, its prompt and the focused move, queued" do
    stage.choose_move
    assert_equal [[round(1), false], ["Please select a move.", false], [first_line, false]], SpeakCapture.log
  end

  test "the panel shows the first contest move named as the focused one" do
    PokeAccess::Config.verbosity = :medium
    stage.choose_move
    assert_equal "#{t(:list_entry, :name => 'Mov33', :n => 1, :tot => 2)}. #{category(:cnd_tough)}", SpeakCapture.last
  end

  test "each move the cursor reaches says its place, category, hearts, jamming and description, interrupting" do
    s = stage
    s.choose_move
    SpeakCapture.clear
    s.instance_variable_set(:@selection, 1)
    s.set_name_move
    s.set_name_move
    line = "#{t(:list_entry, :name => 'Mov45', :n => 2, :tot => 2)}. #{category(:cnd_cute)}. " \
           "#{t(:if2_ct_appeal, :n => 1)}. #{t(:if2_ct_jam, :n => 3)}. msg5"
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "the move used last is said as its grey name marks it, a repeat" do
    PokeAccess::Config.verbosity = :brief
    s = stage
    s.instance_variable_set(:@pkmn1lastmove, "Mov45")
    s.choose_move
    s.instance_variable_set(:@selection, 1)
    s.set_name_move
    assert_equal [round(1), "Please select a move.", "Mov33", "Mov45. #{t(:if2_ct_repeat)}"], SpeakCapture.lines
  end

  test "a move no contest move is named after says its name and place alone" do
    s = stage([Move.new(77)])
    s.choose_move
    assert_equal t(:list_entry, :name => "Mov77", :n => 1, :tot => 1), SpeakCapture.last
  end

  test "each round's menu says its number and reads its first move again" do
    s = stage
    s.choose_move
    SpeakCapture.clear
    s.instance_variable_set(:@round, 2)
    s.choose_move
    assert_equal [round(2), "Please select a move.", first_line], SpeakCapture.lines
  end

  test "with the menu open the info key says the move whole, then the round, the running order and the player's place" do
    PokeAccess::Config.verbosity = :brief
    s = stage
    s.instance_variable_set(:@pokeorder, order_of(s, [1, 2, 0, 3]))
    s.choose_move
    whole = first_line.sub(t(:list_entry, :name => "Mov33", :n => 1, :tot => 2), "Mov33")
    assert_equal "#{whole}. #{round(1)}. #{order('Ledyba, Aron, Pikachu, Totodile', 3)}", PokeAccess::Info.info_text
    assert_equal whole, PokeAccess::Info.row_text
  end

  test "hearts the performer gains are said as its count this round, queued" do
    s = stage
    s.instance_variable_set(:@currentpoke, entrant(s, 1))
    s.instance_variable_set(:@currenthearts, 3)
    s.pbDisplayAddingPositiveHearts
    assert_equal [[hearts("Ledyba", 3), false]], SpeakCapture.log
  end

  test "a jammed contestant's hearts are said after the loss, below zero too" do
    s = stage
    s.instance_variable_set(:@jam, 2)
    s.pbDecreaseHearts(entrant(s, 2), 3)
    assert_equal [hearts("Aron", -2)], SpeakCapture.lines
  end

  test "a heart change that moves nothing says nothing" do
    s = stage
    s.instance_variable_set(:@jam, 0)
    s.pbDecreaseHearts(entrant(s, 2), 3)
    assert_nothing_spoken
  end

  test "the running order is said with the player's place when a repaint changes it, queued" do
    s = stage
    s.pbDrawText
    s.pbDrawText
    s.instance_variable_set(:@pokeorder, order_of(s, [1, 2, 0, 3]))
    s.pbDrawText
    assert_equal [[order("Pikachu, Ledyba, Aron, Totodile", 1), false], [order("Ledyba, Aron, Pikachu, Totodile", 3), false]],
                 SpeakCapture.log
  end

  test "the repaint after the fifth round says no order, as no round follows" do
    s = stage
    s.instance_variable_set(:@round, 6)
    s.pbDrawText
    assert_nothing_spoken
  end

  test "the crowd's turn says the applause level its heart change leaves, queued" do
    crowd_stage(2, true).pbCrowd
    assert_equal [[hearts("Ledyba", 1), false], [applause(3), false]], SpeakCapture.log
  end

  test "a meter that fills is said full, then empty as it resets" do
    crowd_stage(4, true).pbCrowd
    assert_equal [hearts("Ledyba", 1), applause(5), hearts("Ledyba", 6), applause(0)], SpeakCapture.lines
  end

  test "a move outside the contest's category takes the meter down with the heart it costs" do
    crowd_stage(2, false).pbCrowd
    assert_equal [hearts("Ledyba", -1), applause(1)], SpeakCapture.lines
  end

  test "a meter the crowd no longer empties is said as five past five, its last picture" do
    s = crowd_stage(4, true)
    s.instance_variable_set(:@crowdexcitment, false)
    s.pbCrowd
    s.pbCrowd
    assert_equal [hearts("Ledyba", 1), applause(5), hearts("Ledyba", 2)], SpeakCapture.lines
  end

  test "the full meter a move sets without a word is said" do
    crowd_stage(5, true).pbCrowd("notnil")
    assert_equal [[applause(5), false]], SpeakCapture.log
  end

  test "a heart change outside the crowd's turn says no applause" do
    s = crowd_stage(2, true)
    s.instance_variable_set(:@currenthearts, 2)
    s.pbDisplayAddingPositiveHearts
    assert_equal [hearts("Ledyba", 2)], SpeakCapture.lines
  end

  test "each presented contestant's hearts from the crowd are said, none where it shows none, queued" do
    s = stage
    s.instance_variable_set(:@shown, "Ledyba" => 4)
    s.show_heart_vote(entrant(s, 1), 1)
    s.show_heart_vote(entrant(s, 2), 1)
    assert_equal [[t(:if2_ct_crowd, :name => "Ledyba", :n => 4), false], [t(:if2_ct_crowd, :name => "Aron", :n => 0), false]],
                 SpeakCapture.log
  end

  test "the oblivious mark is said once, for the contestant at the place it appears" do
    s = stage
    s.pbObliviousGraphic
    s.instance_variable_get(:@Oblivious)[1] = true
    s.pbObliviousGraphic
    s.pbObliviousGraphic
    s.instance_variable_get(:@Oblivious)[1] = false
    s.pbObliviousGraphic
    assert_equal [[t(:sv_ct_oblivious, :name => "Ledyba"), false]], SpeakCapture.log
  end

  test "the results say each label as painted, the first two followed by the bars row by row, the player's first" do
    results_stage.pbResultsScene
    assert_equal [["The preliminary results!", false], [bars([30, 25, 40, 10]), false], ["Round 2 results!", false],
                  [bars([60, 45, 80, 15]), false], ["Aron is the winner!", false]], SpeakCapture.log
  end

  test "the results' strip painted outside the results screen says nothing" do
    s = results_stage
    pbDrawTextPositions(s.instance_variable_get(:@sprites)["textbitmap"].bitmap, [["The preliminary results!", 0, 0, 0]])
    assert_nothing_spoken
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A contest where Pikachu, the player's, knows moves (battle moves 33 and 45 by default) against three rivals that
  # know none, listed in that order.
  def stage(moves = [Move.new(33), Move.new(45)])
    PokeContestScene.new(NAMES.each_with_index.map { |n, i| Entrant.new(n, i == 0 ? moves : []) })
  end

  # The scene's contestant at index i (Pikachu, Ledyba, Aron, Totodile).
  def entrant(scene, i)
    scene.instance_variable_get(:"@pkmn#{i + 1}")
  end

  # The contestants of scene in the order the indices give.
  def order_of(scene, indices)
    indices.map { |i| entrant(scene, i) }
  end

  # Ledyba's turn before the crowd, the meter at level, its move of the contest's category or not.
  def crowd_stage(level, matches)
    s = stage
    s.instance_variable_set(:@currentpoke, entrant(s, 1))
    s.instance_variable_set(:@applause, level)
    s.instance_variable_set(:@contestType, "Cool")
    s.instance_variable_set(:@moveType, matches ? "Cool" : "Cute")
    s
  end

  # A contest at its results: the preliminary and final scores of each row, Aron the winner.
  def results_stage
    s = stage
    [30, 25, 40, 10].each_with_index { |v, i| s.instance_variable_set(:"@prelim#{i + 1}", v) }
    s.instance_variable_set(:@winner, [60, 45, 80, 15])
    s.instance_variable_set(:@order_winner, order_of(s, [2, 1, 0, 3]))
    s.instance_variable_get(:@sprites)["textbitmap"] = Strip.new(Object.new)
    s
  end

  # The full reading of Pikachu's first move, Mov33, as contest move 2 shows it: tough, four hearts, no jamming.
  def first_line
    "#{t(:list_entry, :name => 'Mov33', :n => 1, :tot => 2)}. #{category(:cnd_tough)}. #{t(:if2_ct_appeal, :n => 4)}. " \
      "#{t(:if2_ct_jam, :n => 0)}. msg2"
  end

  # A move's category part.
  def category(key)
    t(:if2_ct_category, :t => t(key))
  end

  # The round line of round n.
  def round(n)
    t(:sv_ct_round, :n => n, :tot => 5)
  end

  # The running order line: the names top to bottom, then the player's place.
  def order(list, place)
    "#{t(:if2_ct_order, :list => list)}. #{t(:sv_ct_place, :n => place)}"
  end

  # A contestant's hearts line.
  def hearts(name, n)
    t(:if2_ct_hearts, :name => name, :n => n)
  end

  # The applause line at level n.
  def applause(n)
    t(:if2_ct_applause, :n => n, :max => 5)
  end

  # The results rows' scores, Pikachu, Ledyba, Aron and Totodile in turn.
  def bars(values)
    NAMES.zip(values).map { |n, v| t(:if2_ct_score, :name => n, :n => v) }.join(", ")
  end
end
