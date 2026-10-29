# ZUD's Max Raid Den (plugins/zud_raid_dens.rb): the entry screen read once its paint lands (title, the boss's
# silhouette, types, stars and marks, the field, the party taken in, the battle's limits and the keys), the party again
# after the party screen, and the rewards screen; text painted elsewhere is never taken for the den's.

# The den's two screens, down to their paint and the first frame of their loops: each paints its rows on a fresh
# overlay as the plugin does, then runs a frame. The harness loaded the plugin before this class existed, so its two
# hooks on it are evaluated again over this one.
class MaxRaidScene
  attr_accessor :entry_rows, :limits, :reward_rows

  def pbMaxRaidEntry(_stored)
    @overlay = Object.new
    pbDrawTextPositions(@overlay, @entry_rows)
    drawTextEx(@overlay, 287, 274, 220, 2, @limits, nil, nil) if @limits
    pbDrawTextPositions(Object.new, [["Elsewhere", 300, 100, 0, nil, nil]])
    PokeAccess::ZudRaidDens.poll
    pbRaidRewardsScreen(nil) if @reward_rows
    :den_left
  end

  def pbRaidRewardsScreen(_pkmn)
    @overlay = Object.new
    pbDrawTextPositions(@overlay, @reward_rows)
    PokeAccess::ZudRaidDens.poll
    :rewards_closed
  end
end
dens_path = File.join(Harness::ROOT, "plugins", "zud_raid_dens.rb")
dens_source = Harness.source(dens_path)
dens_source.scan(/^PokeAccess::Hooks\.around_hook\("MaxRaidScene".*?^end\r?\n/m) do
  hook = Regexp.last_match
  eval(hook[0], TOPLEVEL_BINDING, dens_path, dens_source[0, hook.begin(0)].count("\n") + 1)
end

class ZudRaidDensGdTest < PokeAccessTest
  Member = Struct.new(:name, :egg, :fainted) do
    def egg?; egg; end
    def fainted?; fainted; end
  end
  Trainer = Struct.new(:party)
  LABELS = [["MAX RAID DEN", 25, 21], ["Leave Den", 403, 143], ["Enter Den", 403, 206], ["Set Party", 111, 284]]
  LIMITS = "Battle ends in 10 turns, or after 4 knock outs."

  def setup
    super
    @trainer = $Trainer
    $Trainer = Trainer.new([Member.new("Pikachu"), Member.new("Egg", true), Member.new("Onix", false, true),
                            Member.new("Bulbasaur"), Member.new("Charmander"), Member.new("Squirtle")])
  end

  def teardown
    $Trainer = @trainer
    super
  end

  test "the entry screen is said once, queued, as its loop starts: boss, field, party, limits and keys" do
    scene = den(:@rank => 3, :@gmax => true, :@hardmode => true, :@weather => :Sun, :@terrain => :Electric,
                :@environ => :Cave)
    scene.entry_rows = LABELS + [["FIELD", 450, 8]]
    assert_equal :den_left, scene.pbMaxRaidEntry(1001)
    line = [ "MAX RAID DEN", t(:zden_boss), t(:zud_raid_types, :list => "TypeTYPE1"), t(:zden_stars, :n => 3),
             t(:dmax_factor), t(:zden_hard),
             "FIELD: #{[t(:w_sun), t(:bt_electric), t(:zden_env_cavern)].join(', ')}",
             t(:zden_party, :list => "Pikachu, Bulbasaur, Charmander"), LIMITS,
             hint("Enter Den", :c, t(:key_enter)), hint("Leave Den", :b, t(:key_escape)), hint("Set Party", :a, "Z")]
    assert_equal [[PokeAccess.sentences(line), false]], SpeakCapture.log
  end

  test "a den with no field shows no header; a legendary raid's sixth rank lines up five stars; no keys at brief" do
    scene = den(:@rank => 6, :@loot => :NUGGET, :@size => 1)
    scene.entry_rows = LABELS
    PokeAccess::Config.verbosity = :brief
    scene.pbMaxRaidEntry(1001)
    line = ["MAX RAID DEN", t(:zden_boss), t(:zud_raid_types, :list => "TypeTYPE1"), t(:zden_stars, :n => 5),
            t(:zden_loot), t(:zden_party, :list => "Pikachu"), LIMITS]
    assert_equal [[PokeAccess.sentences(line), false]], SpeakCapture.log
  ensure
    PokeAccess::Config.verbosity = :full
  end

  test "the party is said again when the party screen closes over the den, and not once the den is left" do
    scene = den
    scene.entry_rows = LABELS
    PokeAccess::ZudRaidDens.entry(scene) do
      SpeakCapture.clear
      $Trainer.party.reverse!
      PokeAccess::ZudRaidDens.party_back
    end
    assert_equal [[t(:zden_party, :list => "Squirtle, Charmander, Bulbasaur"), false]], SpeakCapture.log
    SpeakCapture.clear
    PokeAccess::ZudRaidDens.party_back
    assert_nothing_spoken
  end

  test "the rewards of a caught raid Pokemon: result, sex and level, ability, the bonus marks and the exit key" do
    scene = den(:@bonuses => [4, 2])
    scene.entry_rows = LABELS
    scene.reward_rows = [["\xE2\x99\x82", 20, 76], ["You caught Pikachu!", 270, 20], ["Exit", 393, 284],
                         ["Lvl. 50", 38, 77], ["Ability: Static", 20, 283], ["BONUS", 8, 8]]
    scene.pbMaxRaidEntry(1001)
    line = ["You caught Pikachu!", "\xE2\x99\x82 Lvl. 50", "Ability: Static",
            "BONUS: #{t(:zden_bonus_capture)}, #{t(:zden_bonus_timer)}", hint("Exit", :b, t(:key_escape))]
    assert_equal PokeAccess.sentences(line), SpeakCapture.log.last[0]
    assert_equal 2, SpeakCapture.log.length, "the entry screen, then the rewards"
  end

  test "a lost raid's rewards say its question marks as unknown and that none was earned" do
    scene = den
    scene.entry_rows = LABELS
    scene.reward_rows = [["No Rewards Earned.", 296, 168], ["You lost to Pikachu!", 270, 20], ["Exit", 393, 284],
                         ["Lvl. ???", 38, 77], ["Ability: ???", 20, 283]]
    scene.pbMaxRaidEntry(1001)
    unknown = t(:pdx_unknown_short)
    line = ["You lost to Pikachu!", "Lvl. #{unknown}", "Ability: #{unknown}", "No Rewards Earned.",
            hint("Exit", :b, t(:key_escape))]
    assert_equal PokeAccess.sentences(line), SpeakCapture.log.last[0]
  end

  test "nothing is said for paint outside a den, nor twice for one screen" do
    pbDrawTextPositions(Object.new, [["MAX RAID DEN", 25, 21, 0, nil, nil]])
    PokeAccess::ZudRaidDens.poll
    assert_nothing_spoken
    scene = den
    scene.entry_rows = LABELS
    PokeAccess::ZudRaidDens.entry(scene) do
      scene.instance_variable_set(:@overlay, Object.new)
      pbDrawTextPositions(scene.instance_variable_get(:@overlay), LABELS)
      2.times { PokeAccess::ZudRaidDens.poll }
    end
    assert_equal 1, SpeakCapture.log.length
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A key hint as the den says it: the caption painted beside a button picture and the key the button is on.
  def hint(caption, button, name)
    t(:hint_label_key, :label => caption, :key => PokeAccess::KeyHints.key(button, name))
  end

  # A den showing a three-star boss and taking three Pokemon in, with ivars overriding those.
  def den(ivars = {})
    scene = MaxRaidScene.new
    { :@size => 3, :@rank => 1, :@bosspoke => :PIKACHU, :@bossform => 0, :@limits => LIMITS }.merge(ivars).each do |k, v|
      k == :@limits ? scene.limits = v : scene.instance_variable_set(k, v)
    end
    scene
  end
end
