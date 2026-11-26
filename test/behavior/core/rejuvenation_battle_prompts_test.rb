# Rejuvenation 14's lines its own reader says and the mod's readers had left out, with its whole profile loaded: whose
# turn the commands are for in a double battle, the Ball's target said again on each throw, Ctrl's team preview hinted
# as an Inspect opens, and the trainer card's level cap. In a process of its own, since a class under the battle scene's name would stand
# in the way of the other tests' stand-ins.
class RejuvenationBattlePromptsTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    # The engine's data cache, by which rv_common knows its engine.
    class RvCache
      def pkmn; {}; end
      def moves; {}; end
      def abil; {}; end
    end
    $cache = RvCache.new

    # The game's reader, which the relay follows.
    def tts(text, _interrupt = false, lowercase: nil); text; end

    LEVELCAPS = [18, 25, 30, 35, 40, 45, 50, 55, 60]

    Battler = Struct.new(:name, :pokemon)
    Battle = Struct.new(:doublebattle, :battlers)

    # The scene up to its menus: the command menu's opening, and the Ball's target, which B leaves at -1 without
    # deselecting (Battle_Scene.rb:4989-5019).
    class PokeBattle_Scene
      def initialize(battle); @battle = battle; end
      def pbCommandMenuEx(_index, _texts, _mode = 0); 0; end
      def pbUpdateSelected(index); index; end
      def pbChooseBallTarget(_index)
        pbUpdateSelected(1)
        -1
      end
    end

    # The Inspect report: its start, and the report it shows (Battle_Inspect.rb:144, 449).
    def pbShowInspect(_msgwindow, _rows); nil; end
    def pbShowBattleStats(_chosenindex, _currentindex = nil, _returning = false); pbShowInspect(nil, []); end
  RUBY

  PLAY = <<-'RUBY'
    def team; [Battler.new("Pikachu", 1), Battler.new("Gyarados", 1), Battler.new("Eevee", 1), Battler.new("Onix", 1)]; end
    def prompts; ["What will\nEevee do?", "Fight", "Bag", "Pokémon", "Run"]; end

    probe(:doubles) { said { PokeBattle_Scene.new(Battle.new(true, team)).pbCommandMenuEx(2, prompts) } }
    probe(:singles) { said { PokeBattle_Scene.new(Battle.new(false, team)).pbCommandMenuEx(0, prompts) } }
    probe(:balls) do
      scene = PokeBattle_Scene.new(Battle.new(true, team))
      said { 2.times { scene.pbChooseBallTarget(0) } }
    end
    probe(:card) { said { PokemonTrainerCardScene.new(0).pbDrawTrainerCardFront }.last }
    probe(:inspect_open) { said { pbShowBattleStats(0) } }
    probe(:inspect_next) { said { pbShowBattleStats(2, 0) } }
    probe(:inspect_back) { said { pbShowBattleStats(0, nil, true) } }
  RUBY

  profile "rejuvenation", WORLD, PLAY

  test "a double battle's command menu says whose turn it is, as painted, queued ahead of the command" do
    assert_equal [["What will Eevee do?", false]], played(:doubles)
  end

  test "a single battle's command menu leaves the turn's line out" do
    assert_equal [], played(:singles)
  end

  test "each Ball thrown in doubles says its first target, also after one left with B" do
    line = ["Gyarados, #{t(:bt_target_foe)}", true]
    assert_equal [line, line], played(:balls)
  end

  test "the trainer card's front ends with the level cap the badges held set" do
    assert_equal [t(:rv_level_cap, :n => 18), false], played(:card)
  end

  test "Ctrl's team preview is hinted only as an Inspect opens" do
    assert_equal [[t(:rj_inspect_preview, :key => "Ctrl"), false]], played(:inspect_open)
    assert_equal [], played(:inspect_next), "the partner's report, reached from another"
    assert_equal [], played(:inspect_back), "a report come back to"
  end
end
