# The GameData era's info builders: the trainer line from $player (core/field/contextual.rb), the summary's info, stats
# and moves pages (core/party/summary_gamedata.rb) and the composed trainer card (core/menus/trainer_card.rb).
class ContextualInfoGdTest < PokeAccessTest
  Info = PokeAccess::Info
  Move = Struct.new(:id, :name, :pp, :total_pp, :type)

  test "the trainer line reads $player: name, money, badges, Pokedex tally and play time" do
    assert_equal ["Tester", money, badges, tally, playtime(1, 1)].join(". "), Info.trainer_info
  end

  test "the trainer line follows the parts and order the profile sets" do
    was = PokeAccess::Config.trainer_parts
    PokeAccess::Config.trainer_parts = [:badges, :name]
    assert_equal "#{badges}. Tester", Info.trainer_info
  ensure
    PokeAccess::Config.trainer_parts = was
  end

  test "a part that raises costs only its own fragment, and one that answers nothing is left out" do
    { "raises" => lambda { raise "sin nombre" }, "answers blank" => lambda { "" } }.each do |what, name|
      player = TestPlayer.new
      player.define_singleton_method(:name) { name.call }
      with_player(player) do
        assert_equal [money, badges, tally, playtime(1, 1)].join(". "), Info.trainer_info, "a name that #{what}"
      end
    end
  end

  test "a player with no money figure has no money part" do
    player = TestPlayer.new
    player.money = nil
    with_player(player) { assert_equal ["Tester", badges, tally, playtime(1, 1)].join(". "), Info.trainer_info }
  end

  test "the play time is said in hours and minutes" do
    stats = Object.new
    def stats.play_time; 7530; end
    was = $stats
    $stats = stats
    assert_equal ["Tester", money, badges, tally, playtime(2, 5)].join(". "), Info.trainer_info
  ensure
    $stats = was
  end

  test "no player has no trainer line" do
    with_player(nil) { assert_nil Info.trainer_info }
  end

  test "the summary's first page says name and sign, level, Pokedex number, species, types, item and trainer lines" do
    pk = gardevoir
    def pk.speciesName; "Gardevoir"; end
    def pk.types; [:PSYCHIC, :FAIRY]; end
    t = PokeAccess::I18n
    assert_equal [data_of_gardevoir, t.t(:sum_dex, :n => 282), t.t(:sum_species, :s => "Gardevoir"),
                  t.t(:sum_type, :t => "TypePSYCHIC TypeFAIRY"), *unowned_lines].join(" "),
                 PokeAccess::SummaryGameData.info_text(pk, 282)
  end

  test "the summary's first page leaves out the Pokedex number, species and types it is not given" do
    blank = gardevoir
    def blank.speciesName; ""; end
    def blank.types; []; end
    { "a Pokemon with no species name or types to ask" => gardevoir,
      "one whose species name and types answer blank" => blank }.each do |what, pk|
      assert_equal [data_of_gardevoir, *unowned_lines].join(" "), PokeAccess::SummaryGameData.info_text(pk), what
    end
  end

  test "the summary's stats page says the six stats, then the ability" do
    pk = gardevoir
    t = PokeAccess::I18n
    stats = t.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35)
    assert_equal "#{t.t(:sm_stats)}. #{stats} #{t.t(:sum_ability, :a => 'Ability1')}",
                 PokeAccess::SummaryGameData.stats_text(pk)
  end

  test "the summary's moves page lists each move with its type and PP, skipping the empty slots" do
    pk = Poke.build(:moves => [Move.new(:TACKLE, "Placaje", 30, 35, :NORMAL), nil])
    t = PokeAccess::I18n
    line = ["Placaje", t.t(:mv_type, :t => "TypeNORMAL"), t.t(:mv_pp, :pp => 30, :tot => 35)].join(". ")
    assert_equal t.t(:sm_moves, :list => line), PokeAccess::SummaryGameData.moves_text(pk)
  end

  test "the summary's moves page says there are no moves when no slot holds one" do
    { "empty slots" => [nil, nil], "no slots" => [] }.each do |what, moves|
      pk = Poke.build(:moves => moves)
      assert_equal PokeAccess::I18n.t(:sm_no_moves), PokeAccess::SummaryGameData.moves_text(pk), what
    end
  end

  test "the trainer card says its title, name, ID five digits long, money, Pokedex, badges and play time" do
    player = TestPlayer.new
    def player.public_ID; 42; end
    t = PokeAccess::I18n
    with_player(player) do
      assert_equal [t.t(:tc_title), t.t(:tc_name, :name => "Tester"), t.t(:tc_id, :id => "00042"),
                    t.t(:tc_money, :n => 1000), t.t(:tc_pokedex, :owned => 50, :seen => 80), badges,
                    playtime(1, 1)].join(". "), PokeAccess::TrainerCardData.text
    end
  end

  test "no player has no trainer card" do
    with_player(nil) { assert_nil PokeAccess::TrainerCardData.text }
  end

  private

  # Runs the block with player as $player, the stubs' own put back after.
  def with_player(player)
    was = $player
    $player = player
    yield
  ensure
    $player = was
  end

  # A level 40 male Gardevoir with the stubs' defaults: no item, no original trainer, no species name or types.
  def gardevoir
    Poke.build(:name => "Gardevoir", :level => 40)
  end

  def data_of_gardevoir; PokeAccess::I18n.t(:sum_data_of, :name => "Gardevoir ♂", :level => 40); end

  # The item and trainer lines of a Pokemon holding nothing and with no original trainer: on loan, its ID unknown.
  def unowned_lines
    t = PokeAccess::I18n
    [t.t(:sum_item, :i => t.t(:sum_none)), t.t(:sum_ot, :name => t.t(:sum_loaned)),
     t.t(:sum_id, :id => t.t(:pdx_unknown_short))]
  end

  def money; PokeAccess::I18n.t(:tr_money, :n => 1000); end
  def badges; PokeAccess::I18n.t(:tr_badges, :n => 3); end
  def tally; PokeAccess::I18n.t(:tr_pokedex, :owned => 50, :seen => 80); end
  def playtime(h, m); PokeAccess::I18n.t(:tr_playtime, :h => h, :m => m); end
end
