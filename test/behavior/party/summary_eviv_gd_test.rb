# Enhanced Pokemon UI's second face of the stats page (@statToggle): each stat's effort and individual values, their
# totals, the effort points left under the limit and Hidden Power's type, said while it is up.
class SummaryEvivGdTest < PokeAccessTest
  T = PokeAccess::I18n
  SGD = PokeAccess::SummaryGameData
  # A main stat as GameData::Stat.each_main yields it.
  Stat = Struct.new(:id, :name)
  STATS = [Stat.new(:HP, "PS"), Stat.new(:ATTACK, "Ataque"), Stat.new(:SPEED, "Velocidad")].freeze
  # Each stat's effort and individual values on the Pokemon the tests show.
  EV = { :HP => 4, :ATTACK => 252, :SPEED => 252 }.freeze
  IV = { :HP => 31, :ATTACK => 20, :SPEED => 31 }.freeze

  test "with the toggle up, the stats page says each stat's values, their totals, the points left and Hidden Power's type" do
    with_stats do
      with_ev_limit(510) do
        with_hidden_power(:FIRE) { assert_equal face(points_left, hidden_power), SGD.page_text(scene(:page_skills, true), 3) }
      end
    end
  end

  test "the classic numbering's page three turns the same face" do
    with_stats do
      with_ev_limit(510) do
        with_hidden_power(:FIRE) { assert_equal face(points_left, hidden_power), SGD.page_text(scene(nil, true), 3) }
      end
    end
  end

  test "with the toggle down the stats page says the stats" do
    want = "#{T.t(:sm_stats)}. #{T.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26,
                                               :spe => 35)} #{T.t(:sum_ability, :a => 'Ability1')}"
    assert_equal want, SGD.page_text(scene(:page_skills, false), 3)
  end

  test "with no effort limit in the game, says no points left" do
    with_stats do
      with_hidden_power(:FIRE) { assert_equal face(hidden_power), SGD.page_text(scene(:page_skills, true), 3) }
    end
  end

  test "with no Hidden Power to ask, ends on the points left" do
    with_stats do
      with_ev_limit(510) { assert_equal face(points_left), SGD.page_text(scene(:page_skills, true), 3) }
    end
  end

  test "a Pokemon whose values cannot be read leaves the face unsaid" do
    with_stats do
      pk = Poke.build(:name => "Chispa", :ev => nil, :iv => IV.dup)
      assert_nil SGD.page_text(World.stub_scene(:@pokemon => pk, :@page_id => :page_skills, :@statToggle => true), 3)
    end
  end

  private

  # A stats page showing the test's Pokemon under a page id (nil for the classic numbering), toggled or not.
  def scene(page_id, toggled)
    pk = Poke.build(:name => "Chispa", :ev => EV.dup, :iv => IV.dup)
    World.stub_scene(:@pokemon => pk, :@page_id => page_id, :@statToggle => toggled)
  end

  # The face for the test's Pokemon: the heading, each stat's row and the totals, then the given closing parts.
  def face(*tail)
    rows = [T.t(:sm_eviv_row, :stat => "PS", :ev => 4, :iv => 31), T.t(:sm_eviv_row, :stat => "Ataque", :ev => 252, :iv => 20),
            T.t(:sm_eviv_row, :stat => "Velocidad", :ev => 252, :iv => 31), T.t(:sm_eviv_total, :ev => 508, :iv => 82)]
    ([T.t(:sm_stats)] + rows + tail).join(". ")
  end

  # The points left of the test's Pokemon under a limit of 510.
  def points_left
    T.t(:sm_ev_left, :n => 2, :max => 510)
  end

  # Hidden Power's fire type as the face says it.
  def hidden_power
    T.t(:sm_hidden_power, :t => "TypeFIRE")
  end

  # Runs the block with GameData::Stat.each_main walking STATS, the stub's own (or none) put back after.
  def with_stats
    meta = GameData::Stat.singleton_class
    had = meta.method_defined?(:each_main) ? GameData::Stat.method(:each_main) : nil
    GameData::Stat.define_singleton_method(:each_main) { |&b| STATS.each(&b) }
    yield
  ensure
    had ? GameData::Stat.define_singleton_method(:each_main, had) : meta.send(:remove_method, :each_main)
  end

  # Runs the block with Pokemon::EV_LIMIT set to limit, the Pokemon class made for it when the engine has none.
  def with_ev_limit(limit)
    made = !Object.const_defined?(:Pokemon)
    Object.const_set(:Pokemon, Class.new) if made
    was = ::Pokemon.const_defined?(:EV_LIMIT, false) ? ::Pokemon::EV_LIMIT : nil
    ::Pokemon.send(:remove_const, :EV_LIMIT) if was
    ::Pokemon.const_set(:EV_LIMIT, limit)
    yield
  ensure
    ::Pokemon.send(:remove_const, :EV_LIMIT) if ::Pokemon.const_defined?(:EV_LIMIT, false)
    ::Pokemon.const_set(:EV_LIMIT, was) if was
    Object.send(:remove_const, :Pokemon) if made
  end

  # Runs the block with pbHiddenPower answering type, the engine's own function (or none) put back after.
  def with_hidden_power(type)
    had = Object.private_method_defined?(:pbHiddenPower) || Object.method_defined?(:pbHiddenPower)
    Object.send(:alias_method, :pa_spec_hidden_power, :pbHiddenPower) if had
    Object.send(:define_method, :pbHiddenPower) { |_pk| [type, 60] }
    yield
  ensure
    Object.send(:remove_method, :pbHiddenPower)
    if had
      Object.send(:alias_method, :pbHiddenPower, :pa_spec_hidden_power)
      Object.send(:remove_method, :pa_spec_hidden_power)
    end
  end
end
