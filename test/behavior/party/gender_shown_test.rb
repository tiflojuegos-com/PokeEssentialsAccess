# The sex is said where the screen draws its sign: none for a genderless Pokemon, nothing but "egg" for an egg (info
# key included), and a battler's displayed sex, which under Illusion is not its own.
class GenderShownTest < PokeAccessTest
  T = PokeAccess::I18n
  MALE = " ♂"
  FEMALE = " ♀"

  # A battler as the databox sees it: its own gender, and the gender of the Pokemon it is shown as.
  SexBattler = Struct.new(:name, :level, :hp, :totalhp, :status, :pokemon, :gender, :displayGender)

  # A battler of an engine whose databox knows no displayed sex: only its own gender.
  PlainSexBattler = Struct.new(:name, :level, :hp, :totalhp, :status, :pokemon, :gender)

  test "says each member with the sex sign its panel draws, none for a genderless one" do
    { 0 => MALE, 1 => FEMALE, 2 => "", nil => "" }.each do |gender, sign|
      assert_equal T.t(:pty_member, :name => "Bulba, Especie1", :sex => sign, :level => 5, :hp => 20, :tot => 20),
                   PokeAccess::Party.party_line([bulba(gender)], 0), "gender #{gender.inspect}"
    end
  end

  test "says the sign only at full verbosity" do
    assert_equal [T.t(:pty_member_nolv, :name => "Bulba", :sex => "", :hp => 20, :tot => 20),
                  T.t(:pty_member, :name => "Bulba", :sex => "", :level => 5, :hp => 20, :tot => 20),
                  T.t(:pty_member, :name => "Bulba, Especie1", :sex => MALE, :level => 5, :hp => 20, :tot => 20)],
                 vb_levels { PokeAccess::Party.party_line([bulba(0)], 0) }
  end

  test "says an egg as nothing but an egg, whatever its sex" do
    assert_equal T.t(:pty_egg), PokeAccess::Party.party_line([egg], 0)
  end

  test "leaves the info key on an egg with nothing but egg" do
    PokeAccess::Party.party_line([egg], 0)
    assert_equal T.t(:pty_egg), PokeAccess::Info.info_text
  end

  test "gives the info key the sex sign as a sentence of its own, none for a genderless one" do
    glance = T.t(:pk_glance, :name => "Bulba", :level => 5, :hp => 20, :tot => 20)
    { 0 => "#{glance}#{MALE}.", 1 => "#{glance}#{FEMALE}.", 2 => glance }.each do |gender, want|
      assert_equal want, PokeAccess::Info.pokemon_info(bulba(gender)), "gender #{gender}"
    end
  end

  test "says in battle the sex the databox draws, which under Illusion is not the battler's own" do
    assert_equal T.t(:bt_state, :name => "Zoroark#{FEMALE}", :level => 30, :hp => T.t(:bt_hp_pct, :n => 50)),
                 PokeAccess::Battle.battler_state(shown_as("Zoroark", 0, 1), true)
  end

  test "says a genderless battler with no sign" do
    assert_equal T.t(:bt_state, :name => "Magnet", :level => 30, :hp => T.t(:bt_hp_pct, :n => 50)),
                 PokeAccess::Battle.battler_state(shown_as("Magnet", 2, 2), true)
  end

  test "says a battler whose engine shows no other sex with its own" do
    assert_equal T.t(:bt_state, :name => "Zoroark#{MALE}", :level => 30, :hp => T.t(:bt_hp_pct, :n => 50)),
                 PokeAccess::Battle.battler_state(PlainSexBattler.new("Zoroark", 30, 50, 100, 0, true, 0), true)
  end

  private

  # A level-30 battler at half its 100 HP, of the given engine gender, shown as the given one.
  def shown_as(name, gender, shown)
    SexBattler.new(name, 30, 50, 100, 0, true, gender, shown)
  end

  # Bulba at level 5 with full HP, of the given engine gender (0 male, 1 female, 2 genderless).
  def bulba(gender)
    Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => gender)
  end

  # A female egg.
  def egg
    pk = Poke.build(:name => "Huevo", :gender => 1)
    def pk.egg?; true; end
    pk
  end
end
