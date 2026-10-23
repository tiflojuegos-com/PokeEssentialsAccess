# Rejuvenation's Game Boy Color trainer card (games/rejuvenation/trainer_card_gbc.rb): the front's name, ID, money and
# badges, the Virtual League team under the back's arrow, and the summary's three pages, read from what each face paints.

# The card as the game draws it: the front paints the card and one icon per badge; the back paints CANCEL and its
# title, then puts its arrow on the first member; a change of the summary's page or member redraws its header.
class PokemonTrainerCardSceneGBC
  def initialize(team, badges)
    @trainerParty = team
    @badges = badges
    @name = "Ethan"
    @playerGender = "\xE2\x99\x82"
    @index = 0
    @summaryPage = 0
  end

  def pbDrawTrainerCardFront
    icons = [["Graphics/Pictures/Trainer Card/johto//card", 0, 0, 0, 0, 512, 384]]
    @badges.times { |i| icons.push(["Graphics/Pictures/Trainer Card/johto//badges", 130 + 64 * i, 222, 32 * i, 0, 32, 32]) }
    pbDrawImagePositions(nil, icons)
  end

  def pbDrawTrainerCardBack
    pbDrawTextPositions(nil, [["CANCEL", 114, 260, :left], ["VIRTUAL LEAGUE", 256, 296, :center]])
    @index = 0
    changeIndexParty(0)
  end

  def changeIndexParty(increment)
    loop do
      @index += increment
      @index = 0 if @index > 6
      @index = 6 if @index < 0
      break if @index == 6 || @trainerParty[@index]
    end
  end

  # The summary shows member i at page (0 info, 1 moves, 2 stats), as C, the arrows and left or right leave it.
  def openSummary(i, page)
    @index = i
    @summaryPage = page
    drawSummaryHeader
  end

  def drawSummaryHeader; nil; end
end

class RejuvenationCardTest < PokeAccessTest
  MALE = "\xE2\x99\x82"
  FEMALE = "\xE2\x99\x80"
  # A move as the moves page paints it.
  Move = Struct.new(:move, :pp, :maxpp)
  # A Virtual League member, with what the back's row and the summary's pages paint of it.
  Mon = Struct.new(:species, :name, :level, :hp, :totalhp, :item, :gender, :dexnum, :type1, :type2, :exp, :growthrate,
                   :moves, :attack, :defense, :spatk, :spdef, :speed, :publicID)
  # The virtual player: the card paints the low half of its ID, as the game's publicID gives it.
  Trainer = Struct.new(:id, :money) do
    def publicID(id); id % 65536; end
  end
  PLAYER = Trainer.new(65536 + 777, 3000)
  PIKACHU = Mon.new(:PIKACHU, "Sparky", 20, 50, 55, :LIGHTBALL, :M, 25, :ELECTRIC, nil, 8000, :medium,
                    [Move.new(:THUNDERSHOCK, 30, 30), Move.new(:GROWL, 40, 40)], 40, 30, 45, 40, 60, 345)
  TOTODILE = Mon.new(:TOTODILE, "Toto", 18, 60, 60, nil, :F, 158, :WATER, nil, 5832, :medium, [Move.new(:SCRATCH, 35, 35)],
                     38, 44, 30, 35, 33, 54321)
  TEAM = [PIKACHU, TOTODILE]
  # The game's name helpers, whose names the card paints in capitals.
  NAMES = { :getMonName => lambda { |s| s.to_s.capitalize }, :getTypeName => lambda { |ty| ty.to_s.capitalize },
            :getItemName => lambda { |i| i.to_s.capitalize }, :getMoveName => lambda { |m| m.to_s.capitalize } }
  # The game's experience table, where a level starts at its cube.
  EXP_TABLE = Module.new { def self.startExperience(level, _rate); level ** 3; end }

  # Evaluates the profile file once, as boot does, leaving the list of profiles as it was.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "rejuvenation", "trainer_card_gbc.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "the front on opening says the name, the ID, the money and the badges it drew, queued" do
    with_card do |card|
      card.pbDrawTrainerCardFront
      assert_equal [[front(t(:tc_money, :n => 3000), t(:tr_badges, :n => 2)), false]], SpeakCapture.log
    end
  end

  test "turned back to the front, it cuts in" do
    with_card do |card|
      card.pbDrawTrainerCardFront
      SpeakCapture.clear
      card.pbDrawTrainerCardFront
      assert_equal [[front(t(:tc_money, :n => 3000), t(:tr_badges, :n => 2)), true]], SpeakCapture.log
    end
  end

  test "counts the badge icons it drew, not the card's other pictures" do
    [0, 3].each do |n|
      with_card(TEAM, :badges => n) do |card|
        SpeakCapture.clear
        card.pbDrawTrainerCardFront
        assert_equal [[front(t(:tc_money, :n => 3000), t(:tr_badges, :n => n)), false]], SpeakCapture.log, "#{n} badges"
      end
    end
  end

  test "someone else's card says its money as unknown and leaves the badges out" do
    with_card do |card|
      $game_switches[:NotPlayerCharacter] = true
      card.pbDrawTrainerCardFront
      assert_equal [[front(t(:tc_money, :n => t(:dex_unknown))), false]], SpeakCapture.log
    end
  end

  test "with no switches to read, the card counts as the player's" do
    had = $game_switches
    $game_switches = nil
    with_card do |card|
      card.pbDrawTrainerCardFront
      assert_equal [[front(t(:tc_money, :n => 3000), t(:tr_badges, :n => 2)), false]], SpeakCapture.log
    end
  ensure
    $game_switches = had
  end

  test "a player whose ID and money cannot be read leaves both out" do
    with_card(TEAM, :trainer => Object.new) do |card|
      card.pbDrawTrainerCardFront
      assert_equal [[PokeAccess.sentences([t(:tc_name, :name => "Ethan"), t(:tr_badges, :n => 2)]), false]], SpeakCapture.log
    end
  end

  test "turned, the back says its title and the member its arrow starts on, once, cutting in" do
    with_card do |card|
      card.pbDrawTrainerCardBack
      sparky = "#{member('PIKACHU', 20, 50, 55)}, #{t(:pty_item)}"
      assert_equal [[PokeAccess.sentences(["VIRTUAL LEAGUE", sparky]), true]], SpeakCapture.log
    end
  end

  test "down, the back says the next member, one holding no item without the mark" do
    with_card do |card|
      card.pbDrawTrainerCardBack
      SpeakCapture.clear
      card.changeIndexParty(1)
      assert_equal [[member("TOTODILE", 18, 60, 60), true]], SpeakCapture.log
    end
  end

  test "past the team, the arrow says CANCEL as the back painted it" do
    with_card do |card|
      card.pbDrawTrainerCardBack
      card.changeIndexParty(1)
      SpeakCapture.clear
      card.changeIndexParty(1)
      assert_equal [["CANCEL", true]], SpeakCapture.log
    end
  end

  test "with no CANCEL painted, past the team the arrow says the word for exit" do
    with_card do |card|
      card.changeIndexParty(1)
      SpeakCapture.clear
      card.changeIndexParty(1)
      assert_equal [[t(:sm_exit), true]], SpeakCapture.log
    end
  end

  test "C on a member says its header, then the info page, cutting in" do
    with_card do |card|
      card.openSummary(0, 0)
      info = [t(:dbk_hp, :hp => 50, :tot => 55), t(:sum_type, :t => "ELECTRIC"), t(:sum_exp, :n => 8000),
              t(:sum_exp_next, :n => 1261)]
      assert_equal [[PokeAccess.sentences(sparky_header + info), true]], SpeakCapture.log,
                   "level 21 starts at 9261, 1261 past its 8000 points"
    end
  end

  test "the moves page is said alone while the member stays: the item, then each move with its PP" do
    with_card do |card|
      card.openSummary(0, 0)
      SpeakCapture.clear
      card.openSummary(0, 1)
      assert_equal [[PokeAccess.sentences(sparky_moves), true]], SpeakCapture.log
    end
  end

  test "the stats page says the one special, the higher of the two, the ID as painted and the trainer" do
    with_card do |card|
      { 0 => [40, 30, 45, 60, "345"], 1 => [38, 44, 35, 33, "54321"] }.each do |i, (atk, df, special, speed, id)|
        card.openSummary(i, 0)
        SpeakCapture.clear
        card.openSummary(i, 2)
        stats = "#{t(:st_atk)} #{atk}, #{t(:st_def)} #{df}, #{t(:rj_gsc_special)} #{special}, #{t(:st_speed)} #{speed}"
        line = PokeAccess.sentences([stats, t(:sum_id, :id => id), t(:sum_ot, :name => "Ethan #{MALE}")])
        assert_equal [[line, true]], SpeakCapture.log, "member #{i}"
      end
    end
  end

  test "another member brings its header back, a female one with her sign" do
    with_card do |card|
      card.openSummary(0, 1)
      SpeakCapture.clear
      card.openSummary(1, 1)
      head = [t(:pty_head, :name => "Toto", :sex => " #{FEMALE}", :level => 18), t(:sum_species, :s => "TOTODILE"),
              t(:sum_dex, :n => 158)]
      moves = [t(:sum_item, :i => t(:sum_none)), t(:sm_moves, :list => "SCRATCH, #{t(:mv_pp, :pp => 35, :tot => 35)}")]
      assert_equal [[PokeAccess.sentences(head + moves), true]], SpeakCapture.log
    end
  end

  test "drawing either face makes the summary say its member's header again" do
    [:pbDrawTrainerCardFront, :pbDrawTrainerCardBack].each do |face|
      with_card do |card|
        card.openSummary(0, 1)
        card.send(face)
        SpeakCapture.clear
        card.openSummary(0, 1)
        assert_equal [[PokeAccess.sentences(sparky_header + sparky_moves), true]], SpeakCapture.log, "after #{face}"
      end
    end
  end

  test "a genderless member's header carries no sign" do
    with_card([sparky_with(:gender => nil)]) do |card|
      card.openSummary(0, 1)
      head = [t(:pty_head, :name => "Sparky", :sex => "", :level => 20)] + sparky_header[1..-1]
      assert_equal [[PokeAccess.sentences(head + sparky_moves), true]], SpeakCapture.log
    end
  end

  test "the moves page of a member holding nothing and knowing no move says none of either" do
    with_card([sparky_with(:item => nil, :moves => [])]) do |card|
      card.openSummary(0, 0)
      SpeakCapture.clear
      card.openSummary(0, 1)
      assert_equal [[PokeAccess.sentences([t(:sum_item, :i => t(:sum_none)), t(:sm_no_moves)]), true]], SpeakCapture.log
    end
  end

  test "the info page names both types of a two-typed member" do
    with_card([sparky_with(:type2 => :FLYING)]) do |card|
      card.openSummary(0, 0)
      info = [t(:dbk_hp, :hp => 50, :tot => 55), t(:sum_type, :t => "ELECTRIC, FLYING"), t(:sum_exp, :n => 8000),
              t(:sum_exp_next, :n => 1261)]
      assert_equal [[PokeAccess.sentences(sparky_header + info), true]], SpeakCapture.log
    end
  end

  test "with no experience table, the info page leaves out what is left to the next level" do
    with_card(TEAM, :exp => nil) do |card|
      card.openSummary(0, 0)
      info = [t(:dbk_hp, :hp => 50, :tot => 55), t(:sum_type, :t => "ELECTRIC"), t(:sum_exp, :n => 8000)]
      assert_equal [[PokeAccess.sentences(sparky_header + info), true]], SpeakCapture.log
    end
  end

  test "with no member under the arrow, the summary says nothing" do
    with_card do |card|
      card.openSummary(6, 0)
      assert_nothing_spoken
    end
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The front's line: the name and the ID, then the rest given.
  def front(*rest)
    PokeAccess.sentences([t(:tc_name, :name => "Ethan"), t(:tc_id, :id => "00777")] + rest)
  end

  # A member's row on the back, without the item mark.
  def member(name, level, hp, tot)
    t(:pty_member, :name => name, :sex => "", :level => level, :hp => hp, :tot => tot)
  end

  # Sparky's summary header: nickname with sign and level, species, dex number.
  def sparky_header
    [t(:pty_head, :name => "Sparky", :sex => " #{MALE}", :level => 20), t(:sum_species, :s => "PIKACHU"),
     t(:sum_dex, :n => 25)]
  end

  # Sparky's moves page.
  def sparky_moves
    moves = "THUNDERSHOCK, #{t(:mv_pp, :pp => 30, :tot => 30)}, GROWL, #{t(:mv_pp, :pp => 40, :tot => 40)}"
    [t(:sum_item, :i => "LIGHTBALL"), t(:sm_moves, :list => moves)]
  end

  # Sparky with the given fields changed.
  def sparky_with(fields)
    mon = PIKACHU.dup
    fields.each { |k, v| mon[k] = v }
    mon
  end

  # Runs the block on a card over team, with the game's name helpers, the player and the experience table in place
  # (opts :badges the front draws, 2 by default; :trainer; :exp, nil for no table), putting back what was there.
  def with_card(team = TEAM, opts = {})
    GameFunctions.with(NAMES) do
      with_trainer(opts.fetch(:trainer, PLAYER)) do
        with_exp_table(opts.fetch(:exp, EXP_TABLE)) { yield PokemonTrainerCardSceneGBC.new(team, opts.fetch(:badges, 2)) }
      end
    end
  end

  # Runs the block with $Trainer being trainer.
  def with_trainer(trainer)
    had = $Trainer
    $Trainer = trainer
    yield
  ensure
    $Trainer = had
  end

  # Runs the block with PBExp being table, or with none for nil, putting back whatever was there.
  def with_exp_table(table)
    had = Object.const_defined?(:PBExp) ? Object.send(:remove_const, :PBExp) : nil
    Object.const_set(:PBExp, table) if table
    yield
  ensure
    Object.send(:remove_const, :PBExp) if Object.const_defined?(:PBExp)
    Object.const_set(:PBExp, had) if had
  end
end
