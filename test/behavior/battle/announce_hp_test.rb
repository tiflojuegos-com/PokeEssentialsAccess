# Battle.announce_hp_change and its pbHPChanged entry: an HP change, queued, as a loss or a gain with what is left
# (in HP on the player's side; on the foe's, whose box paints only its bar, both as floored percentages, a change they
# do not show as less than 1 percent); no change, or nothing to read, says nothing. And the HP key (Battle.announce_hp): out of battle the party, each member's name,
# HP and state slot; in the Safari Zone the Safari Balls on the player's side and the wild Pokemon once on the foe's.
class AnnounceHpTest < PokeAccessTest
  # A battler as the HP change reads it; the index tells its side.
  Battler = Struct.new(:name, :hp, :totalhp, :index)

  # A battler with no index to read.
  Unplaced = Struct.new(:name, :hp, :totalhp)

  # A battler as the HP key reads it: the Pokemon it holds, its name, level and HP.
  Fighter = Struct.new(:pokemon, :name, :level, :hp, :totalhp)

  # The gen-6 Safari Zone's battle: four fake battlers over its one wild Pokemon, and the balls it counts.
  class SafariG6
    attr_reader :battlers, :ballcount
    def initialize(wild, balls); @battlers = [wild, wild.dup, wild.dup, wild.dup]; @ballcount = balls; end
  end

  # The Safari Zone's battle from v18 on: two fake battlers, and ballCount.
  class SafariModern
    attr_reader :battlers, :ballCount
    def initialize(wild, balls); @battlers = [wild, wild.dup]; @ballCount = balls; end
  end

  # The Bug Contest's battle, which counts its balls too while the player fights with a Pokemon of their own.
  class Contest
    attr_reader :battlers, :ballcount
    def initialize(mine, wild, balls); @battlers = [mine, wild, nil, nil]; @ballcount = balls; end
  end

  test "a loss on the player's side says the HP lost and the exact HP left" do
    PokeAccess::Battle.announce_hp_change(Battler.new("Bulba", 20, 44, 0), 30)
    assert_equal [[change("Bulba", :bt_lose, 10, t(:bt_hp_exact, :hp => 20, :tot => 44)), false]], SpeakCapture.log
  end

  test "a gain on the foe's side says the share of its bar gained and the percentage left" do
    PokeAccess::Battle.announce_hp_change(Battler.new("Rattata", 50, 100, 1), 20)
    assert_equal [[share("Rattata", :bt_gain, 30, t(:bt_hp_pct, :n => 50)), false]], SpeakCapture.log
  end

  test "each side follows the parity of the index" do
    { 2 => change("Pidgey", :bt_lose, 15, t(:bt_hp_exact, :hp => 30, :tot => 60)),
      3 => share("Pidgey", :bt_lose, 25, t(:bt_hp_pct, :n => 50)) }.each do |index, said|
      SpeakCapture.clear
      PokeAccess::Battle.announce_hp_change(Battler.new("Pidgey", 30, 60, index), 45)
      assert_equal [[said, false]], SpeakCapture.log, "at index #{index}"
    end
  end

  test "the foe's change is the difference of its floored percentages, whole at full HP" do
    cases = { [2, 3, 3] => [:bt_lose, 34, 66], [1, 1, 0] => [:bt_gain, 100, 100],
              [66, 100, 67] => [:bt_lose, 1, 66], [39, 47, 47] => [:bt_lose, 18, 82] }
    cases.each do |(hp, tot, old), (verb, n, pct)|
      SpeakCapture.clear
      PokeAccess::Battle.announce_hp_change(Battler.new("Pidgey", hp, tot, 1), old)
      assert_equal [[share("Pidgey", verb, n, t(:bt_hp_pct, :n => pct)), false]], SpeakCapture.log, "#{hp} of #{tot}"
    end
  end

  test "a foe's change that leaves its floored percentage as it was is less than 1 percent, lost or gained" do
    cases = { [298, 300, 299] => [:bt_lose, 99], [298, 300, 297] => [:bt_gain, 99], [0, 0, 5] => [:bt_lose, 0] }
    cases.each do |(hp, tot, old), (verb, pct)|
      SpeakCapture.clear
      PokeAccess::Battle.announce_hp_change(Battler.new("Onix", hp, tot, 1), old)
      assert_equal [[sliver("Onix", verb, t(:bt_hp_pct, :n => pct)), false]], SpeakCapture.log, "#{old} to #{hp} of #{tot}"
    end
  end

  test "never says the HP a foe lost, from which its total would follow" do
    PokeAccess::Battle.announce_hp_change(Battler.new("Pidgey", 19, 47, 1), 26)
    refute_match(/\b7\b/, SpeakCapture.lines.join(" "))
  end

  test "a battler whose index cannot be read is said as the player's" do
    PokeAccess::Battle.announce_hp_change(Unplaced.new("Char", 10, 40), 40)
    assert_equal [[change("Char", :bt_lose, 30, t(:bt_hp_exact, :hp => 10, :tot => 40)), false]], SpeakCapture.log
  end

  test "an unchanged HP says nothing" do
    PokeAccess::Battle.announce_hp_change(Battler.new("Char", 40, 40, 0), 40)
    assert_nothing_spoken
  end

  test "says nothing without a battler or its previous HP" do
    PokeAccess::Battle.announce_hp_change(nil, 40)
    PokeAccess::Battle.announce_hp_change(Battler.new("Char", 40, 40, 0), nil)
    assert_nothing_spoken
  end

  test "says nothing for a battler whose HP cannot be read" do
    PokeAccess::Battle.announce_hp_change(Battler.new("Char", nil, 40, 0), 40)
    assert_nothing_spoken
  end

  test "pbHPChanged's battler and old HP say that change" do
    PokeAccess::Battle.hp_changed(Battler.new("Bulba", 20, 44, 0), 30)
    assert_equal [[change("Bulba", :bt_lose, 10, t(:bt_hp_exact, :hp => 20, :tot => 44)), false]], SpeakCapture.log
  end

  test "the Reborn engine's list of battler and old HP pairs says each change in order" do
    pairs = [[Battler.new("Bulba", 20, 44, 0), 30], :not_a_pair, [Battler.new("Rattata", 75, 100, 1), 50]]
    PokeAccess::Battle.hp_changed(pairs, true)
    assert_equal [[change("Bulba", :bt_lose, 10, t(:bt_hp_exact, :hp => 20, :tot => 44)), false],
                  [share("Rattata", :bt_gain, 25, t(:bt_hp_pct, :n => 75)), false]], SpeakCapture.log
  end

  test "in the Safari Zone the player's side says the Safari Balls the battle counts, in each era's battle" do
    { :PokeBattle_SafariZone => SafariG6, :SafariBattle => SafariModern }.each do |name, klass|
      SpeakCapture.clear
      with_const(name, klass) do
        PokeAccess::Battle.set_battle(klass.new(rattata, 7))
        PokeAccess::Battle.announce_hp(false)
      end
      assert_equal [[t(:safari_balls, :n => 7), true]], SpeakCapture.log, name.to_s
    end
  end

  test "in the Safari Zone the foe's side says the wild Pokemon once, as a percentage" do
    { :PokeBattle_SafariZone => SafariG6, :SafariBattle => SafariModern }.each do |name, klass|
      SpeakCapture.clear
      with_const(name, klass) do
        PokeAccess::Battle.set_battle(klass.new(rattata, 7))
        PokeAccess::Battle.announce_hp(true)
      end
      said = t(:bt_state, :name => "Rattata", :level => 22, :hp => t(:bt_hp_pct, :n => 100))
      assert_equal [[said, true]], SpeakCapture.log, name.to_s
    end
  end

  test "the Bug Contest, which counts its balls too, says the player's own Pokemon" do
    PokeAccess::Battle.set_battle(Contest.new(Fighter.new(Poke.build, "Bulba", 12, 30, 35), rattata, 20))
    PokeAccess::Battle.announce_hp(false)
    said = t(:bt_state, :name => "Bulba", :level => 12, :hp => t(:bt_hp_exact, :hp => 30, :tot => 35))
    assert_equal [[said, true]], SpeakCapture.log
  end

  test "the info key's foe line names the Safari Zone's wild Pokemon once" do
    with_const(:PokeBattle_SafariZone, SafariG6) do
      PokeAccess::Battle.set_battle(SafariG6.new(rattata, 3))
      line = PokeAccess::Battle.foe_info.to_s
      assert_equal 1, line.scan(t(:bt_foe, :name => "Rattata", :level => 22)).length, line
    end
  end

  test "the HP key out of battle says each party member's name and HP, and the ailment only of one that has it" do
    team = [Poke.build(:name => "Pikachu", :hp => 35, :totalhp => 40),
            Poke.build(:name => "Charmander", :hp => 20, :totalhp => 39, :status => 2)]
    with_party(team) { PokeAccess::Battle.announce_hp(false) }
    said = [member("Pikachu", 35, 40), "#{member("Charmander", 20, 39)}, #{t(:st_poison)}"].join(". ")
    assert_equal [[said, true]], SpeakCapture.log
  end

  test "the HP key out of battle says a fainted member as the party screen does, in place of its ailment" do
    with_party([Poke.build(:name => "Bulba", :hp => 0, :totalhp => 44, :status => 2)]) do
      PokeAccess::Battle.announce_hp(true)
    end
    assert_equal [["#{member("Bulba", 0, 44)}, #{t(:pk_fainted)}", true]], SpeakCapture.log
  end

  test "the HP key out of battle says an egg as an egg, and a party with no one in it as having no Pokemon" do
    egg = Poke.build(:name => "Huevo")
    egg.define_singleton_method(:egg?) { true }
    { [egg, nil] => t(:pty_egg), [] => t(:pty_none), nil => t(:pty_none) }.each do |team, said|
      SpeakCapture.clear
      with_party(team) { PokeAccess::Battle.announce_hp(false) }
      assert_equal [[said, true]], SpeakCapture.log, team.inspect
    end
  end

  test "the HP key in a battle that has stored no battle yet says nothing" do
    PokeAccess::Battle.battle_started
    begin
      with_party([Poke.build(:name => "Pikachu")]) { PokeAccess::Battle.announce_hp(false) }
    ensure
      PokeAccess::Battle.battle_ended
    end
    assert_nothing_spoken
  end

  private

  # The HP change line for name, as the reader words it.
  def change(name, verb, amount, rest)
    t(:bt_hp_change, :name => name, :verb => t(verb), :n => amount, :rest => rest)
  end

  # The HP change line for a foe, its share of the bar in place of the HP.
  def share(name, verb, percent, rest)
    t(:bt_hp_change_pct, :name => name, :verb => t(verb), :n => percent, :rest => rest)
  end

  # The HP change line for a foe whose bar's percentage did not move: less than 1 percent of it.
  def sliver(name, verb, rest)
    t(:bt_hp_change_under_pct, :name => name, :verb => t(verb), :rest => rest)
  end

  # The Safari Zone's wild Rattata as a battler: level 22, at full HP, with no types or marks to read.
  def rattata
    Fighter.new(Poke.build, "Rattata", 22, 51, 51)
  end

  # Runs the block with klass bearing a game's class name, put back after.
  def with_const(name, klass)
    had = Object.const_defined?(name) ? Object.send(:remove_const, name) : nil
    Object.const_set(name, klass)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name)
    Object.const_set(name, had) if had
  end

  # A party member's name and HP, as the party screen words them without the level.
  def member(name, hp, tot)
    t(:pty_member_nolv, :name => name, :sex => "", :hp => hp, :tot => tot)
  end

  # Runs the block with the player's party as these members (nil for a player without one), put back after.
  def with_party(members)
    saved = $Trainer
    $Trainer = Struct.new(:party).new(members)
    yield
  ensure
    $Trainer = saved
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
