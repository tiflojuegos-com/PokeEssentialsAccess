# The v22 summary's egg page (:egg_memo): where the egg came from and how close it is to hatching, as draw_egg_memo
# paints them, never the nature or the species.
Suite.define("summary v22: the egg page says where the egg came from and how close it is, and no more") do
  egg = Poke.build(:name => "Egg")
  def egg.egg?; true; end
  def egg.obtain_text; "Viridian City"; end
  def egg.steps_to_hatch; 500; end
  vis = UI::PokemonSummaryVisuals.new([egg], 0)

  SpeakCapture.clear
  vis.go_to_next_page(:egg_memo)
  spoke "where it came from", /#{Regexp.escape(PokeAccess::I18n.t(:sm_met_egg))}: Viridian City/
  spoke "and how close it is to hatching", /#{Regexp.escape(PokeAccess::I18n.t(:hatch_soon))}/
  falsy "with no word of a nature", SpeakCapture.lines.join(" ") =~ /#{Regexp.escape(PokeAccess::I18n.t(:sm_nature, :n => ""))}/

  SpeakCapture.clear
  vis.refresh
  silent "a redraw of the same page says nothing"

  eq "with no place on record, the builder still gives the hatch state",
     PokeAccess::SummaryGameData.egg_memo_text(Poke.build(:name => "Egg2")),
     PokeAccess::Util.join_parts([PokeAccess::I18n.t(:sm_met_egg), PokeAccess::Incubator.hatch_state(Poke.build)])
end
