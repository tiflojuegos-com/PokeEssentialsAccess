# Page one's trainer lines as gen 6 asks them (ot, publicID, PBExperience): trainer, padded ID, experience and what the
# next level needs, 0 at the table's top level (MAXLEVEL, set by level caps); with no table, from the engine's data.
class SummaryExpNextTest < PokeAccessTest
  T = PokeAccess::I18n
  # A gen-6 Pokemon as the trainer lines ask it.
  Pk = Struct.new(:level, :exp, :growthrate, :ot, :publicID)
  # The same, a Shadow Pokemon under the modern question or under gen-6's.
  ModernShadow = Struct.new(:level, :exp, :growthrate, :ot, :publicID) { def shadowPokemon?; true; end }
  OldShadow = Struct.new(:level, :exp, :growthrate, :ot, :publicID) { def isShadow?; true; end }
  # An engine's data that knows how much experience a Pokemon still needs (the Reborn engine's).
  ExpData = Struct.new(:left) { def exp_left(_pk); left; end }

  test "below the top level, says what the next level still needs" do
    with_table(25) { assert_equal 25 ** 3 - (24 ** 3 + 10), PokeAccess::Summary.exp_to_next(Pk.new(24, 24 ** 3 + 10, 0)) }
  end

  test "at the top level, says 0 left" do
    with_table(25) { assert_equal 0, PokeAccess::Summary.exp_to_next(Pk.new(25, 25 ** 3, 0)) }
  end

  test "with no experience table, the engine's data says what is left" do
    without_table do
      Harness.with_provider(ExpData.new(42)) { assert_equal 42, PokeAccess::Summary.exp_to_next(Pk.new(24, 100, 0)) }
    end
  end

  test "with no table and no data that knows, has nothing to say" do
    without_table { assert_nil PokeAccess::Summary.exp_to_next(Pk.new(24, 100, 0)) }
  end

  test "page one's trainer lines: the original trainer, the ID, the experience and what the next level needs" do
    with_table(25) do
      assert_equal [T.t(:sum_ot, :name => "Red"), T.t(:sum_id, :id => "12345"), T.t(:sum_exp, :n => 25 ** 3),
                    T.t(:sum_exp_next, :n => 0)], PokeAccess::Summary.trainer_facts(Pk.new(25, 25 ** 3, 0, "Red", 12345))
    end
  end

  test "pads the ID to five digits, as the page prints it" do
    with_table(25) do
      assert_equal T.t(:sum_id, :id => "01234"), PokeAccess::Summary.trainer_facts(Pk.new(25, 25 ** 3, 0, "Red", 1234))[1]
    end
  end

  test "a trainer with no ID has no ID line" do
    with_table(25) do
      assert_equal [T.t(:sum_ot, :name => "Red"), T.t(:sum_exp, :n => 25 ** 3), T.t(:sum_exp_next, :n => 0)],
                   PokeAccess::Summary.trainer_facts(Pk.new(25, 25 ** 3, 0, "Red", nil))
    end
  end

  test "a Pokemon with no original trainer is on loan, its ID unknown" do
    with_table(25) do
      [nil, ""].each do |ot|
        assert_equal [T.t(:sum_ot, :name => T.t(:sum_loaned)), T.t(:sum_id, :id => T.t(:pdx_unknown_short))],
                     PokeAccess::Summary.trainer_facts(Pk.new(25, 25 ** 3, 0, ot, 12345)).first(2), "a trainer #{ot.inspect}"
      end
    end
  end

  test "a Shadow Pokemon's lines stop before the experience, under either engine's question" do
    with_table(25) do
      [ModernShadow, OldShadow].each do |kind|
        assert_equal [T.t(:sum_ot, :name => "Red"), T.t(:sum_id, :id => "12345")],
                     PokeAccess::Summary.trainer_facts(kind.new(25, 25 ** 3, 0, "Red", 12345)), kind.name
      end
    end
  end

  private

  # Runs the block with a PBExperience table of cubes that holds every level past top at top, the engine's own table
  # (or none) put back after.
  def with_table(top)
    was = Object.const_defined?(:PBExperience) ? Object.send(:remove_const, :PBExperience) : nil
    tbl = Module.new
    tbl.const_set(:MAXLEVEL, top)
    tbl.define_singleton_method(:pbGetStartExperience) { |level, _growth| [level, tbl::MAXLEVEL].min ** 3 }
    Object.const_set(:PBExperience, tbl)
    yield
  ensure
    Object.send(:remove_const, :PBExperience) if Object.const_defined?(:PBExperience)
    Object.const_set(:PBExperience, was) if was
  end

  # Runs the block with no PBExperience table, the engine's own put back after.
  def without_table
    was = Object.const_defined?(:PBExperience) ? Object.send(:remove_const, :PBExperience) : nil
    yield
  ensure
    Object.const_set(:PBExperience, was) if was
  end
end
