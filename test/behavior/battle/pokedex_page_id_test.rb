# PokedexInfoV21.page_id: which page of the entry is on show, by the Modular UI's own page name where it keeps one,
# else by the number drawPage was given on the plain screen (Awakening, both Infinite Fusions).
class PokedexPageIdTest < PokeAccessTest
  PDX = PokeAccess::PokedexInfoV21

  test "the plain screen's three pages are told apart by drawPage's number" do
    { 1 => :page_info, 2 => :page_area, 3 => :page_forms }.each do |page, id|
      assert_equal id, PDX.page_id(Object.new, page), "page #{page}"
    end
  end

  test "a number past the plain three is a page of its own" do
    [4, 9].each { |page| assert_equal :page_other, PDX.page_id(Object.new, page), "page #{page}" }
  end

  test "no number, or something else in its place, names no page" do
    [nil, "2", :page_area].each { |page| assert_nil PDX.page_id(Object.new, page), "page #{page.inspect}" }
  end

  test "the Modular UI's page name wins over drawPage's number" do
    { 1 => :page_data, 2 => :page_info, 9 => :page_height, nil => :page_area }.each do |page, id|
      assert_equal id, PDX.page_id(mui_scene(id), page), "page #{page.inspect} named #{id}"
    end
  end

  private

  # A Modular UI entry scene showing the page it names id.
  def mui_scene(id)
    scene = Object.new
    scene.instance_variable_set(:@page_id, id)
    scene
  end
end
