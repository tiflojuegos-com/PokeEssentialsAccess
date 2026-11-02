# The boss lives script (plugins/battle_lives.rb; Awakening, Edas, Perseida): a boss's spare life icons said with its hit
# points, the life it loses as its bar breaks, and nothing for a battler with no lives.
class BattleLivesTest < PokeAccessTest
  T = PokeAccess::I18n

  # A boss as the databox sees it, given lives by pbInitLives.
  Boss = Struct.new(:index, :name, :level, :hp, :totalhp, :gender, :status, :pokemon, :lives)
  # A battler of a game without the script.
  Plain = Struct.new(:index, :name, :level, :hp, :totalhp, :gender, :status, :pokemon)

  # The scene, whose bar breaks as a boss loses a life.
  class BreakScene
    def pbBreakBar(_battler); :flashed; end
  end

  HOOK = Harness.source(File.join(Harness::ROOT, "plugins", "battle_lives.rb"))
                .scan(/^PokeAccess::Hooks\.before_hook\("PokeBattle_Scene".*?^end\n/m).first

  # Binds the plugin's hook to the scene above, under the game's name for the time it takes.
  def self.bind_hook
    was = Object.const_defined?(:PokeBattle_Scene) ? Object.const_get(:PokeBattle_Scene) : nil
    Object.send(:remove_const, :PokeBattle_Scene) if was
    Object.const_set(:PokeBattle_Scene, BreakScene)
    eval(HOOK, TOPLEVEL_BINDING, "plugins/battle_lives.rb")
  ensure
    Object.send(:remove_const, :PokeBattle_Scene)
    Object.const_set(:PokeBattle_Scene, was) if was
  end
  bind_hook

  test "the hit points say the icons past the current bar, none on its last life or with no lives set" do
    { 3 => T.t(:blv_lives, :n => 2), 2 => T.t(:blv_lives, :n => 1), 1 => nil, nil => nil }.each do |lives, extra|
      hp = PokeAccess::Battle.shown_hp(boss(lives), true)
      plain = PokeAccess::Battle.hp_phrase(50, 100, true)
      assert_equal extra ? "#{plain}, #{extra}" : plain, hp, "with #{lives.inspect} lives"
    end
  end

  test "a battler of a game with no lives keeps its hit points" do
    foe = Plain.new(1, "Zorua", 30, 50, 100, 0, 0, true)
    assert_equal PokeAccess::Battle.hp_phrase(50, 100, false), PokeAccess::Battle.shown_hp(foe, false)
  end

  test "the bar breaking says the life lost and the icons left, queued, and the scene's own break runs" do
    assert_equal :flashed, BreakScene.new.pbBreakBar(boss(2))
    assert_equal [[T.t(:blv_life_lost, :name => "Zorua", :rest => T.t(:blv_lives_left, :n => 1)), false]], SpeakCapture.log
  end

  test "the last life is said as the last" do
    BreakScene.new.pbBreakBar(boss(1))
    assert_equal [[T.t(:blv_life_lost, :name => "Zorua", :rest => T.t(:blv_lives_last)), false]], SpeakCapture.log
  end

  private

  def boss(lives)
    Boss.new(1, "Zorua", 30, 50, 100, 0, 0, true, lives)
  end
end
