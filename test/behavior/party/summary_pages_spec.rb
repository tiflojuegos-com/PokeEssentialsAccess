# Turning the summary's pages: only the first page waits, a redraw of the page on screen is quiet, and another
# member's page is read, named first, even when it reads the same.

Suite.define("summary gen-6: the first page waits, a turn interrupts, a redraw of the same page is quiet") do
  pika = Poke.build(:name => "Pika", :level => 20)
  scene = PokemonSummaryScene.new
  SpeakCapture.clear
  scene.pbStartScene([pika], 0)
  scene.drawPage(4)
  scene.drawPage(4)
  scene.drawPage(1)
  eq "the data sheet, the moves, the data sheet again", SpeakCapture.lines,
     [PokeAccess::Info.summary_text(pika), PokeAccess::Summary.moves_text(pika), PokeAccess::Info.summary_text(pika)]
  eq "only the opening waits behind what was being said", SpeakCapture.log.map { |l| l[1] }, [false, true, true]
end

Suite.define("summary gen-6: another member's page is read even when it reads the same, and says whose it is") do
  t = PokeAccess::I18n
  pika = Poke.build(:name => "Pika", :level => 20)
  eevee = Poke.build(:name => "Eevee", :level => 5, :gender => 1)
  scene = PokemonSummaryScene.new
  scene.pbStartScene([pika, eevee], 0)
  scene.drawPage(4)
  SpeakCapture.clear
  scene.pokemon = eevee
  scene.drawPage(4)
  eq "the same moves on another member: named first, as the header shows it", SpeakCapture.lines,
     ["#{t.t(:sum_whose, :name => "Eevee \xE2\x99\x80", :level => 5)}. #{PokeAccess::Summary.moves_text(eevee)}"]
  match "and the info key reads the member on screen", PokeAccess::Info.info_text.to_s, /Eevee/

  SpeakCapture.clear
  scene.pokemon = pika
  scene.drawPage(1)
  eq "a page that starts with the Pokemon is not named twice", SpeakCapture.lines,
     [PokeAccess::Info.summary_text(pika)]
end

Suite.define("summary: a page something covered is read again when it closes, as a turn") do
  pika = Poke.build(:name => "Pika", :level => 20)
  scene = PokemonSummaryScene.new
  scene.pbStartScene([pika], 0)
  scene.drawPage(3)
  SpeakCapture.clear
  PokeAccess::Summary.forget_page(scene)
  scene.drawPage(3)
  eq "the same page, read once more", SpeakCapture.lines.length, 1
  eq "interrupting, since the screen was already open", SpeakCapture.log[0][1], true
end

# The move cursor and the ribbon grid are loops the summary runs inside itself, and each ends on a redraw of
# the page it covered: entering one forgets the page, so the redraw on the way out is read.
Suite.define("summary: coming back from the move cursor or the ribbon grid reads the page again") do
  pika = Poke.build(:name => "Pika", :level => 20)
  scene = PokemonSummaryScene.new
  scene.pbStartScene([pika], 0)
  scene.drawPage(4)
  [:pbMoveSelection, :pbRibbonSelection].each do |loop_name|
    SpeakCapture.clear
    scene.send(loop_name)
    scene.drawPage(4)
    eq "back from #{loop_name}, the page again", SpeakCapture.lines.length, 1
  end
end

Suite.define("summary: the moves at the summary move reading's level, the type from medium") do
  t = PokeAccess::I18n
  mv = Struct.new(:id, :name, :pp, :totalpp, :type)
  pk = Poke.build(:name => "Pika", :moves => [mv.new(33, "Placaje", 30, 35, :NORMAL), mv.new(84, "Impactrueno", 20, 30, :ELECTRIC)])
  moves = []
  PokeAccess::Summary.each_real_move(pk) { |nm, pp, tot, ty| moves.push([nm, pp, tot, ty]) }
  brief = moves.map { |nm, pp, tot, _ty| [nm, t.t(:mv_pp, :pp => pp, :tot => tot)].join(". ") }
  rows = vb_levels { PokeAccess::Summary.moves_text(pk) }
  eq "brief: each move with its PP", rows[0], t.t(:sm_moves, :list => brief.join(", "))
  truthy "medium: with its type, as full says it", rows[1] == rows[2] && rows[1] != rows[0]
end
