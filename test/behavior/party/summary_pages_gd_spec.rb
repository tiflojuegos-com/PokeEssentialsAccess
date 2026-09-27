# Turning the modern summary's pages: the first page waits, a turn interrupts, a redraw of the same page is quiet,
# and another member's page is read, named first, even when it reads the same.

Suite.define("summary (modern): pages turn with an interruption, members are named, redraws stay quiet") do
  t = PokeAccess::I18n
  pika = Poke.build(:name => "Pika", :level => 20)
  eevee = Poke.build(:name => "Eevee", :level => 5, :gender => 1)
  ribbons = PokeAccess::SummaryGameData.ribbons_text(pika)
  scene = PokemonSummary_Scene.new
  SpeakCapture.clear
  scene.pbStartScene([pika, eevee], 0)
  scene.drawPage(5)
  scene.drawPage(5)
  eq "the data sheet on opening, then the ribbons once for all their redraws", SpeakCapture.lines,
     [PokeAccess::SummaryGameData.info_text(pika).strip, ribbons]
  eq "the opening waits, the turn interrupts", SpeakCapture.log.map { |l| l[1] }, [false, true]

  SpeakCapture.clear
  scene.pokemon = eevee
  scene.drawPage(5)
  eq "the same ribbons on another member are read, named first", SpeakCapture.lines,
     ["#{t.t(:sum_whose, :name => "Eevee \xE2\x99\x80", :level => 5)}. #{PokeAccess::SummaryGameData.ribbons_text(eevee)}"]
  match "and the info key reads the member on screen", PokeAccess::Info.info_text.to_s, /Eevee/
end
