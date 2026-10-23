# The rewritten entry's data page names the section it draws: the one pbDrawDataNotes is passed, else the page's own
# cursor, as the page itself decides; each of its ten sections by its own name. Gamedata pass.
class DexSectionGdTest < PokeAccessTest
  SECTIONS = { :encounter => :pdx_sec_encounter, :general => :pdx_sec_general, :stats => :pdx_sec_stats,
               :family => :pdx_sec_family, :habitat => :pdx_sec_habitat, :shape => :pdx_sec_shape,
               :egg => :pdx_sec_egg, :item => :pdx_sec_item, :ability => :pdx_sec_ability,
               :moves => :pdx_sec_moves }

  test "the section passed to the draw is the one named, else the cursor's" do
    { nil => :general, :stats => :stats }.each do |passed, drawn|
      scene = PokemonPokedexInfo_Scene.new
      scene.cursor = :general
      SpeakCapture.clear
      passed ? scene.pbDrawDataNotes(passed) : scene.pbDrawDataNotes
      assert_equal [["#{PokeAccess::I18n.t(SECTIONS[drawn])}. Texto de #{drawn}.", true]], SpeakCapture.log,
                   "passed #{passed.inspect}"
    end
  end

  test "each of the ten sections the page draws is said by its own name" do
    SECTIONS.each do |section, key|
      SpeakCapture.clear
      PokemonPokedexInfo_Scene.new.pbDrawDataNotes(section)
      assert_equal ["#{PokeAccess::I18n.t(key)}. Texto de #{section}."], SpeakCapture.lines, section.inspect
    end
  end
end
