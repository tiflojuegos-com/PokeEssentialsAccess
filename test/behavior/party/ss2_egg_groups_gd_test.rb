# Soulstones 2's memo page egg groups (games/soulstones2/egg_groups.rb), as Enhanced UI's pbDisplayEggGroups picks
# them: Undiscovered for one that cannot breed, Unknown for a genderless Pokemon but Ditto, else its groups once each.
class Ss2EggGroupsGdTest < PokeAccessTest
  T = PokeAccess::I18n
  Memo = PokeAccess::SummaryGameData

  test "the stock memo page draws no egg groups" do
    assert_equal [], Memo.memo_extras(mon([:Monster]))
  end

  test "two groups are said as the two icons the page draws" do
    with_profile { assert_equal [groups("GroupMonster, GroupDragon")], Memo.memo_extras(mon([:Monster, :Dragon])) }
  end

  test "the same group twice is one icon" do
    with_profile { assert_equal [groups("GroupField")], Memo.memo_extras(mon([:Field, :Field])) }
  end

  test "a genderless Pokemon gets the Unknown icon, and Ditto its own group" do
    with_profile do
      assert_equal [groups(T.t(:egg_group_unknown))], Memo.memo_extras(mon([:Mineral], :genderless? => true))
      ditto = mon([:Ditto], :genderless? => true, :isSpecies? => lambda { |s| s == :DITTO })
      assert_equal [groups("GroupDitto")], Memo.memo_extras(ditto)
    end
  end

  test "one that cannot breed shows Undiscovered: an egg, a Shadow or celestial Pokemon, or one with Battle Bond" do
    with_profile do
      [{ :egg? => true }, { :shadowPokemon? => true }, { :celestial? => true },
       { :hasAbility? => lambda { |a| a == :BATTLEBOND } }].each do |answers|
        assert_equal [groups("GroupUndiscovered")], Memo.memo_extras(mon([:Water1], answers)), answers.keys.inspect
      end
    end
  end

  test "a genderless one that cannot breed still shows Undiscovered" do
    with_profile do
      assert_equal [groups("GroupUndiscovered")],
                   Memo.memo_extras(mon([:Mineral], :genderless? => true, :shadowPokemon? => true))
    end
  end

  test "a species with no egg groups to show adds nothing to the page" do
    with_profile do
      broken = Poke.build(:name => "Missingno")
      broken.define_singleton_method(:species_data) { raise "no species data" }
      [mon([]), broken].each { |pk| assert_equal [], Memo.memo_extras(pk), pk.name }
    end
  end

  test "with no egg group data, each group is said by its own name" do
    with_profile(lambda { |_g| raise NameError, "no egg group data" }) do
      assert_equal [groups("Field, Fairy")], Memo.memo_extras(mon([:Field, :Fairy]))
    end
  end

  test "the memo page ends with the egg groups, after the memo" do
    pk = mon([:Monster])
    with_profile do
      assert_equal "#{T.t(:sm_memo)}. #{groups('GroupMonster')}", Memo.memo_page_text(pk, nil)
    end
  end

  test "the Hidden Power type the game's plugin draws on the page stays, ahead of the egg groups" do
    with_profile do
      assert_equal [T.t(:sm_hidden_power, :t => "TypeFIRE"), groups("GroupMonster")],
                   Memo.memo_extras(mon([:Monster], :hptype => :FIRE))
    end
  end

  private

  # A Pokemon whose species has the given egg groups, answering only the questions given (method => value, or a
  # lambda for one that takes an argument), as a game version without the others would.
  def mon(egg_groups, answers = {})
    pk = Poke.build(:name => "Charmander")
    pk.define_singleton_method(:species_data) { Struct.new(:egg_groups).new(egg_groups) }
    answers.each do |m, v|
      v.is_a?(Proc) ? pk.define_singleton_method(m, &v) : pk.define_singleton_method(m) { v }
    end
    pk
  end

  # The page's egg groups sentence over the names it lists.
  def groups(names)
    T.t(:sum_egg_groups, :g => names)
  end

  # Runs the block with the profile's override in and the egg group data naming each group with namer (by default
  # "Group" and its symbol), then takes both back out.
  def with_profile(namer = lambda { |g| Struct.new(:name).new("Group#{g}") })
    override = profile_override
    meta = (class << Memo; self; end)
    meta.send(:alias_method, :ss2_spec_memo_extras, :memo_extras)
    begin
      Memo.define_singleton_method(:memo_extras, override)
      with_egg_group_data(namer) { yield }
    ensure
      meta.send(:alias_method, :memo_extras, :ss2_spec_memo_extras)
      meta.send(:remove_method, :ss2_spec_memo_extras)
    end
  end

  # The profile's memo_extras: its file evaluated once per process, the override it installs kept aside and the
  # stock page put back.
  def profile_override
    kept = self.class.instance_variable_get(:@override)
    return kept if kept
    meta = (class << Memo; self; end)
    meta.send(:alias_method, :ss2_spec_stock, :memo_extras)
    begin
      path = File.join(Harness::ROOT, "games", "soulstones2", "egg_groups.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      self.class.instance_variable_set(:@override, Memo.method(:memo_extras))
    ensure
      meta.send(:alias_method, :memo_extras, :ss2_spec_stock)
      meta.send(:remove_method, :ss2_spec_stock)
    end
  end

  # Runs the block with GameData::EggGroup.get answering namer, restoring whatever stood there before.
  def with_egg_group_data(namer)
    made = !GameData.const_defined?(:EggGroup)
    GameData.const_set(:EggGroup, Class.new) if made
    meta = (class << GameData::EggGroup; self; end)
    had = meta.method_defined?(:get)
    meta.send(:alias_method, :ss2_spec_get, :get) if had
    GameData::EggGroup.define_singleton_method(:get, &namer)
    yield
  ensure
    if had
      meta.send(:alias_method, :get, :ss2_spec_get)
      meta.send(:remove_method, :ss2_spec_get)
    else
      meta.send(:remove_method, :get)
    end
    GameData.send(:remove_const, :EggGroup) if made
  end
end
