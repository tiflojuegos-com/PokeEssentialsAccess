# BerryPots (plugins/berry_pots.rb, ItemBerryPots_Scene): the focused pot by number with its plant as core's Berry says
# a field plant (stage, berry, soil), or empty; the can with the one in use; the exit with its help line.
class BerryPotsTest < PokeAccessTest
  # A pot's BerryPlantData as the screen keeps it.
  Plant = Struct.new(:growth_stage, :berry_id, :moisture_stage, :new_mechanics) do
    def planted?
      growth_stage.to_i > 0
    end
  end

  test "a planted pot is its number, then its stage, berry and soil" do
    scene = pots(0, [Plant.new(3, :ORANBERRY, 1, true), Plant.new(0, nil, 0, true)])
    expected = "#{t(:bpots_pot, :n => 1, :total => 2)}, " \
               "#{PokeAccess::Berry.state_parts(Plant.new(3, :ORANBERRY, 1, true)).join(', ')}"
    assert_equal expected, PokeAccess::BerryPots.text(scene, 0)
  end

  test "an empty pot says so" do
    scene = pots(1, [Plant.new(3, :ORANBERRY, 1, true), Plant.new(0, nil, 0, true)])
    assert_equal "#{t(:bpots_pot, :n => 2, :total => 2)}, #{t(:bpots_empty)}", PokeAccess::BerryPots.text(scene, 1)
  end

  test "the exit is its help line, and the opening read is queued, each move after it interrupting" do
    scene = pots(-2, [Plant.new(0, nil, 0, true)], "Quit the Berry Pots.")
    PokeAccess::BerryPots.focus(scene)
    scene.instance_variable_set(:@index, 0)
    PokeAccess::BerryPots.focus(scene)
    PokeAccess::BerryPots.focus(scene)
    assert_equal [["Quit the Berry Pots.", false], ["#{t(:bpots_pot, :n => 1, :total => 1)}, #{t(:bpots_empty)}", true]],
                 SpeakCapture.log
  end

  test "after acting on a pot, the pot is said again as it now stands, queued" do
    plants = [Plant.new(0, nil, 0, true)]
    scene = pots(0, plants)
    PokeAccess::BerryPots.focus(scene)
    SpeakCapture.clear
    plants[0] = Plant.new(1, :ORANBERRY, 2, true)
    PokeAccess::BerryPots.acted(scene)
    assert_equal [[PokeAccess::BerryPots.text(scene, 0), false]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A pots screen with its cursor on idx, the given plants and a help window showing help.
  def pots(idx, plants, help = "")
    window = Struct.new(:text).new(help)
    World.stub_scene(:@index => idx, :@berry_plant => plants, :@sprites => { "helpwindow" => window })
  end
end
