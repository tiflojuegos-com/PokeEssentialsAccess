# Pokemon Z's speed key (games/pokemon_z/turbo.rb) through Input.update: a speed change made inside it off the free
# map, as in a battle, is said by the profile; on the free map the core says it, once; an update that moves nothing
# says nothing.
require File.expand_path("turbo_cases", File.dirname(__FILE__))

class ZTurboTest < PokeAccessTest
  test "says a press of the speed key in a battle, where the core stays silent" do
    with_speed_key do
      PokeAccess::Battle.battle_started
      update
      assert_equal [[speed_text(2), true]], update(1)
    end
  end

  test "says a press of the speed key on another scene" do
    with_speed_key do
      $scene = Object.new
      update
      assert_equal [[speed_text(3), true]], update(2)
    end
  end

  test "leaves a press on the free map to the core, which says it once" do
    with_speed_key do
      update
      assert_equal [[speed_text(2), true]], update(1)
    end
  end

  test "says nothing for an update that moves nothing" do
    with_speed_key do
      PokeAccess::Battle.battle_started
      update
      assert_equal [], update
    end
  end

  test "says nothing for an update that leaves no speed index" do
    with_speed_key do
      PokeAccess::Battle.battle_started
      update
      assert_equal [], update(nil)
    end
  end

  test "keeps the value of the update it wraps, quiet or said" do
    with_speed_key do
      assert_equal :updated, Input.update, "a quiet update on the free map"
      PokeAccess::Battle.battle_started
      @steps.push(1)
      SpeakCapture.clear
      assert_equal [:updated, [[speed_text(2), true]]], [Input.update, SpeakCapture.log], "a press said in a battle"
    end
  end

  private

  # The speed line for multiplier n, as said in Spanish.
  def speed_text(n)
    PokeAccess::I18n.t(:turbo_speed, :n => n)
  end

  # Runs one Input.update whose innermost original first sets $GameSpeed to step (none for :none) and returns what was
  # said during it, as [text, interrupt] pairs.
  def update(step = :none)
    @steps.push(step) unless step == :none
    SpeakCapture.clear
    Input.update
    SpeakCapture.log.dup
  end

  # Runs the block on the free map with Z's stage table (TurboNuevo's [1, 2, 3]), the speed index at 0, the speed
  # poller's memory as at boot and the innermost Input.update standing in for TurboNuevo: it takes the next queued step
  # into $GameSpeed and answers :updated. The update, the scene, the speed, the battle flag and the poller's memory are
  # put back, and the table removed.
  def with_speed_key
    saved = [$scene, $GameSpeed]
    inner = Input.method(:update__access_orig)
    steps = @steps = []
    Input.define_singleton_method(:update__access_orig) do |*_a|
      $GameSpeed = steps.shift unless steps.empty?
      :updated
    end
    TurboCases.stages([1, 2, 3])
    $scene = Scene_Map.new
    $GameSpeed = 0
    TurboCases.reset
    yield
  ensure
    Input.define_singleton_method(:update__access_orig, inner)
    PokeAccess::Battle.battle_ended
    $scene, $GameSpeed = saved
    TurboCases.stages(nil)
    TurboCases.reset
  end
end
