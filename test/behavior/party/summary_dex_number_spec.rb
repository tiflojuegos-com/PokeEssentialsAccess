# Page one's Pokedex number, read as painted: the value on the Dex label's row or, where the label is part of the
# background, the topmost value on the right half; question marks as unknown.
Suite.define("summary: page one's Pokedex number is read as the page paints it") do
  s = PokeAccess::Summary
  z = [["DATOS", 26, 16], ["Pika", 46, 62], ["100", 46, 92], ["N\xC2\xB0 Dex", 238, 80], ["025", 435, 80],
       ["Especie", 238, 112], ["Pikachu", 435, 112]]
  eq "the value on the Dex label's row, not the level beside the name", s.painted_dex_number(z.map { |r| [r[0], :positions, r[1], r[2]] }), "025"
  modern = [["No. Dex", 238, 86], ["Especie", 238, 118], ["Pikachu", 435, 118], ["Puntos Exp.", 238, 246],
            ["250", 488, 278], ["012", 435, 86]]
  eq "pushed after the other labels, still on its row; experience below is not it",
     s.painted_dex_number(modern.map { |r| [r[0], :positions, r[1], r[2]] }), "012"
  awakening = [["Nombre", 238, 112], ["Pikachu", 435, 112], ["Tipo", 238, 144], ["007", 435, 80]]
  eq "no label: the topmost value on the right half", s.painted_dex_number(awakening.map { |r| [r[0], :positions, r[1], r[2]] }), "007"
  unknown = [["No. Dex", 238, 86], ["???", 435, 86]]
  eq "outside every dex, the marks are said as unknown", s.painted_dex_number(unknown.map { |r| [r[0], :positions, r[1], r[2]] }),
     PokeAccess::I18n.t(:pdx_unknown_short)
  eq "a page that paints none says none", s.painted_dex_number([]), nil
end

Suite.define("summary gen-6: the data sheet says the number page one paints") do
  pika = Poke.build(:name => "Pika", :level => 20)
  scene = PokemonSummaryScene.new
  scene.instance_variable_set(:@page_one_paint, [["N\xC2\xB0 Dex", 238, 80], ["025", 435, 80]])
  SpeakCapture.clear
  scene.pbStartScene([pika], 0)
  spoke "the sheet carries the number", /#{Regexp.escape(PokeAccess::I18n.t(:sum_dex, :n => "025"))}/
end
