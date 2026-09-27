# Infinite Fusion's fifth summary page runs the species' Pokedex entry inside its draw, then steps back to the moves
# page: the readers inside that draw speak, and the moves page is read after it, not the vanilla fifth.
Suite.define("infinite fusion: the Pokedex opened from the summary is read, and so is the page it returns to") do
  meta = (class << PokeAccess::SummaryV21; self; end)
  meta.send(:alias_method, :if_spec_speak_page, :speak_page)
  load File.expand_path("../../../games/infinitefusion_common/dex_page.rb", File.dirname(__FILE__))
  begin
    pika = Poke.build(:name => "Pika", :level => 20)
    scene = PokemonSummary_Scene.new
    scene.pbStartScene([pika], 0)
    scene.drawPage(4)
    scene.on_draw = lambda do |page|
      next unless page == 5
      scene.drawSelectedMove(nil, :THUNDERBOLT)
      scene.instance_variable_set(:@page, 4)
    end
    SpeakCapture.clear
    scene.drawPage(5)
    lines = SpeakCapture.lines
    eq "a reader inside the page's draw speaks, first", lines.first,
       PokeAccess::SummaryGameData.move_detail(pika, :THUNDERBOLT)
    eq "then the moves page it came back to, not ribbons", lines.last, PokeAccess::SummaryGameData.moves_text(pika)
    falsy "no ghost ribbons", lines.any? { |l| l == PokeAccess::SummaryGameData.ribbons_text(pika) }
  ensure
    meta.send(:alias_method, :speak_page, :if_spec_speak_page)
    meta.send(:remove_method, :if_spec_speak_page)
  end
end
