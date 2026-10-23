# The names the locator gives map events where the game's data is GameData (core/nav/locator_naming.rb): a trainer by
# the class its battle starts as, a Pokemon by the species its sprite's symbol names.
class LocatorNamingGdTest < PokeAccessTest
  Loc = PokeAccess::Locator

  test "a trainer named for its sight is said by the class TrainerBattle.start fights as, and beaten after it" do
    battle = [TestCmd.new(111, [12, "TrainerBattle.start(:AQUAGRUNT_M, \"Matt\")"])]
    pages = [TestPage.new(:trigger => 0, :sprite => "trainer_AQUAGRUNT_M", :list => battle),
             TestPage.new(:trigger => 0, :sprite => "trainer_AQUAGRUNT_M",
                          :condition => { :self_switch_valid => true, :self_switch_ch => "A" })]
    fresh = TestGameEvent.new(:id => 2, :name => "Trainer(3)", :pages => pages, :active_page => pages[0])
    beaten = TestGameEvent.new(:id => 3, :name => "Trainer(3)", :pages => pages, :active_page => pages[1])
    assert_equal ["Recluta Aqua", PokeAccess::I18n.t(:loc_trainer_beaten, :name => "Recluta Aqua")],
                 [Loc.target_name(fresh), Loc.target_name(beaten)]
  end

  test "a Pokemon drawn with its species' sprite is said by the species the game keeps under that symbol" do
    with_species(:GEODUDE_1, :MILTANK) do
      said = ["GEODUDE_1", "MILTANK", "NPC_GUARD"].each_with_index.map do |g, i|
        page = TestPage.new(:trigger => 0, :sprite => g, :list => [TestCmd.new(101, ["..."])])
        Loc.target_name(TestGameEvent.new(:id => 10 + i, :pages => [page]))
      end
      assert_equal ["SpeciesGEODUDE_1", "SpeciesMILTANK", "NPC_GUARD"], said
    end
  end

  private

  # Runs the block with GameData::Species answering try_get for the species ids given, and nil for any other.
  def with_species(*ids)
    sp = GameData::Species
    sp.define_singleton_method(:try_get) { |i| ids.include?(i) ? sp.get(i) : nil }
    yield
  ensure
    sp.singleton_class.send(:remove_method, :try_get)
  end
end
