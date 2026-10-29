# Better Summary's heart page (plugins/better_summary.rb), which the special button opens on a Shadow Pokemon's info
# page: its heart paragraph as painted, then the sex and the held item it writes, said in the first frame of its wait
# for a key; the page underneath is forgotten, so its redraw on closing is read.

# The heart page as Sky's base paints it: its rows through the positions batch, the heart paragraph as formatted text
# behind a color tag, then its wait for a key, one frame here (the pulse's pollers) unless a spec asks for none.
class PokemonSummary_Scene
  attr_accessor :heart_waits

  def showShadowDescription(pokemon)
    pbDrawTextPositions(nil, [["INFORMACIÓN", 18, 10], [pokemon.name, 46, 64], ["Puerta del Corazón", 262, 216],
                              ["Objeto", 18, 294]])
    drawFormattedTextEx(nil, 234, 252, 264, "<c3=404040,B0B0B0>La puerta de su corazón está fuertemente cerrada.")
    PokeAccess::Frame.run_pollers unless @heart_waits == false
    :closed
  end
end
better_summary_path = File.join(Harness::ROOT, "plugins", "better_summary.rb")
eval(Harness.source(better_summary_path), TOPLEVEL_BINDING, better_summary_path)

class BetterSummaryHeartGdTest < PokeAccessTest
  HEART = "La puerta de su corazón está fuertemente cerrada."

  test "the heart page says its heart paragraph, then the sex and item it writes, as it waits for a key" do
    pk = Poke.build(:name => "Lugia")
    assert_equal :closed, PokemonSummary_Scene.new(pk).showShadowDescription(pk), "the page's own result"
    said = PokeAccess::Util.join_parts([HEART] + PokeAccess::BetterSummary.extras(pk))
    assert_equal [[said, true]], SpeakCapture.log
    assert said.include?(PokeAccess::I18n.t(:sum_item, :i => PokeAccess::I18n.t(:bs_no_item))), "the item line"
  end

  test "the heart page is said once, however many frames it waits" do
    pk = Poke.build(:name => "Lugia")
    PokemonSummary_Scene.new(pk).showShadowDescription(pk)
    PokeAccess::Frame.run_pollers
    assert_equal 1, SpeakCapture.lines.length
  end

  test "a page that never waited leaves nothing armed for the frames after it" do
    pk = Poke.build(:name => "Lugia")
    scene = PokemonSummary_Scene.new(pk)
    scene.heart_waits = false
    scene.showShadowDescription(pk)
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
    refute PokeAccess::PaintCapture.armed?(:bsum_shadow), "the capture is dropped as the page closes"
  end

  test "the page underneath is forgotten, so its redraw on closing is read" do
    pk = Poke.build(:name => "Lugia")
    scene = PokemonSummary_Scene.new(pk)
    scene.instance_variable_set(:@access_page_key, [:page_info, pk, "line"])
    scene.showShadowDescription(pk)
    assert_equal [:page_info, nil, nil], scene.instance_variable_get(:@access_page_key)
  end
end
