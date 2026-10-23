# The region map's per-place detail (core/nav/region_map.rb), the fourth PBS field the bar paints beside the place:
# kept for the info key, said after the place only where descriptions are said (full), and cleared where a square has
# none ("", as the real scenes answer).
class RegionMapDetailsTest < PokeAccessTest
  # A map scene whose described squares are named "Ciudad <x><y>"; any other square has no place and no detail.
  class Scene
    def initialize(details); @details = details; end
    def pbGetMapLocation(x, y); @details[[x, y]] ? "Ciudad #{x}#{y}" : ""; end
    def pbGetMapDetails(x, y); @details[[x, y]] || ""; end
  end

  # A map scene with no details method at all.
  class Bare
    def pbGetMapLocation(_x, _y); "Pueblo"; end
  end

  test "keeps the square's detail for the info key at every verbosity" do
    scene = Scene.new([3, 4] => "Laboratorio Flare")
    kept = vb_levels do
      PokeAccess::RegionMap.forget(scene)
      read(scene, 3, 4)
      PokeAccess::Info.info_text
    end
    assert_equal ["Laboratorio Flare"] * 3, kept, "brief, medium, full"
  end

  test "says the detail after the place only in full verbosity" do
    scene = Scene.new([3, 4] => "Laboratorio Flare")
    said = vb_levels do
      PokeAccess::RegionMap.forget(scene)
      SpeakCapture.clear
      read(scene, 3, 4)
      SpeakCapture.lines
    end
    assert_equal [["Ciudad 34"], ["Ciudad 34"], ["Ciudad 34, Laboratorio Flare"]], said, "brief, medium, full"
  end

  test "a square with no detail clears the one kept" do
    scene = Scene.new([3, 4] => "Laboratorio Flare")
    read(scene, 3, 4)
    read(scene, 9, 9)
    assert_nil PokeAccess::Info.info_text
  end

  test "closing the map forgets the detail kept" do
    scene = Scene.new([1, 1] => "Chateau Merlot")
    read(scene, 1, 1)
    PokeAccess::RegionMap.forget(scene)
    assert_nil PokeAccess::Info.info_text
  end

  test "a map with no details method says the place and keeps no detail" do
    read(Bare.new, 2, 2)
    assert_equal [["Pueblo"], nil], [SpeakCapture.lines, PokeAccess::Info.info_text]
  end

  test "keeps the detail without the codes the game paints it with" do
    read(Scene.new([3, 4] => "\\c[2]Laboratorio Flare"), 3, 4)
    assert_equal "Laboratorio Flare", PokeAccess::Info.info_text
  end

  private

  # Reads the square as the hook on the scene's pbGetMapLocation does.
  def read(scene, x, y)
    PokeAccess::RegionMap.announce(scene, scene.pbGetMapLocation(x, y), x, y)
  end
end
