# Grueling Gold loads Essentials Deluxe after the Deluxe Battle Kit, so Deluxe's fight menu replaces the kit's and the kit's
# pbToggleSpecialActions, for which core leaves the mechanic button alone, never runs: plugins/essentials_deluxe.rb says the
# button there, once. In a process of its own, as the guard is read when the mod loads.
class GruelingGoldFightMenuTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    module Battle
      def pbToggleSpecialActions(_idx, _cmd); nil; end
    end
    class Battle::Scene
      def pbUpdateNameWindow(*); nil; end
      def pbFightMenu_BattleMechanic(_data, _cw); :mega; end
    end
  RUBY

  PLAY = <<-'RUBY'
    menu = Battle::Scene::FightMenu.new
    probe(:pressed) do
      said do
        menu.setIndexAndMode(0, 1)
        menu.mode = 2
        menu.mode = 1
      end
    end
  RUBY

  profile "gruelinggold", WORLD, PLAY, "gamedata"

  test "with the kit installed too, the button is said on each press, and once" do
    assert_equal [[t(:bt_mega_ready), false], [t(:bt_mega_on), true], [t(:bt_mega_off), true]], played(:pressed)
  end
end
