# The Habilidades sheet (plugins/summary_habilidades.rb) of Armonia and Pokemon Z, fed with each game's own paint
# calls (0134_PScreen_Summary.rb and 134_PScreen_Summary.rb, Habilidades): paint order but for the ability's value,
# the sex sign and the ability's description, painted away from what they belong to. And the C key the stats page's
# picture draws for the sheet, said with that page.
module SummaryHabilidadesSpec
  MALE = PokeAccess::Party::SIGNS[0]
  DESC = "Potencia los ataques de tipo Planta en un apuro."

  # Armonia's rows as take_pairs gives them: the header under the ability's label painted before its value, the
  # stats in two columns, the sign pushed last and the description by drawTextEx after them all.
  def self.armonia
    [["INFORMACIÓN", :positions, 26, 16], ["Bulbasaur", :positions, 46, 62], ["5", :positions, 46, 92],
     ["Habilidad:", :positions, 200, 0], ["EV / IV / Poder Oculto ", :positions, 200, 225],
     ["Espesura", :positions, 320, 0], ["  HP  ", :positions, 228, 260], ["1/31", :positions, 350, 260],
     ["ATAQ.", :positions, 200, 285], ["2/30", :positions, 350, 285], ["DEFE.", :positions, 200, 310],
     ["3/29", :positions, 350, 310], ["AT.E.", :positions, 360, 260], ["4/28", :positions, 500, 260],
     ["DE.E.", :positions, 360, 285], ["5/27", :positions, 500, 285], ["VELO.", :positions, 360, 310],
     ["6/26", :positions, 500, 310], ["Felicidad", :positions, 20, 345], ["70", :positions, 150, 345],
     ["Poder Oculto", :positions, 210, 345], ["Planta", :positions, 450, 345], [MALE, :positions, 160, 62],
     [DESC, :dtex, 200, 30]]
  end

  # Pokemon Z's: the same calls moved, with the happiness label a line above its value, on the Defense row.
  def self.pokemon_z
    [["INFORMACIÓN", :positions, 26, 16], ["Bulbasaur", :positions, 46, 62], ["5", :positions, 46, 92],
     ["Habilidad:", :positions, 200, 2], ["EV / IV", :positions, 200, 227], ["Espesura", :positions, 310, 2],
     ["  HP  ", :positions, 228, 260], ["1/31", :positions, 350, 260], ["ATAQ.", :positions, 200, 290],
     ["2/30", :positions, 350, 290], ["DEFE.", :positions, 200, 320], ["3/29", :positions, 350, 320],
     ["AT.E.", :positions, 360, 260], ["4/28", :positions, 500, 260], ["DE.E.", :positions, 360, 290],
     ["5/27", :positions, 500, 290], ["VELO.", :positions, 360, 320], ["6/26", :positions, 500, 320],
     ["Felicidad", :positions, 22, 320], ["70", :positions, 55, 352], ["Poder Oculto", :positions, 195, 353],
     ["Planta", :positions, 435, 353], [MALE, :positions, 160, 62], [DESC, :dtex, 200, 32]]
  end

  # What both should say: the ability with its value and description, the header right before the figures.
  def self.expected(header)
    ["INFORMACIÓN", "Bulbasaur #{MALE}", "5", "Habilidad: Espesura", DESC, header, "HP", "1/31", "ATAQ.", "2/30",
     "DEFE.", "3/29", "AT.E.", "4/28", "DE.E.", "5/27", "VELO.", "6/26", "Felicidad", "70", "Poder Oculto", "Planta"]
  end
end

Suite.define("summary habilidades: the sheet in paint order, with each value, sign and paragraph where it belongs") do
  sh = PokeAccess::SummaryHabilidades
  eq "armonia: the ability with its value and description, and the header before the figures",
     sh.ordered(SummaryHabilidadesSpec.armonia), SummaryHabilidadesSpec.expected("EV / IV / Poder Oculto")
  eq "pokemon z: the same, and its happiness label still before its value a line below",
     sh.ordered(SummaryHabilidadesSpec.pokemon_z), SummaryHabilidadesSpec.expected("EV / IV")
  eq "rows with no position keep their place", sh.ordered([["A:", :formatted, nil, nil], ["B", :positions, 5, 5]]),
     ["A:", "B"]
  PokeAccess::PaintCapture.arm(:sum_habilidades)
  SummaryHabilidadesSpec.armonia.each do |text, source, x, y|
    source == :dtex ? PokeAccess::PaintCapture.note(text, :dtex, x, y) : PokeAccess::PaintCapture.note_positions([[text, x, y]])
  end
  SpeakCapture.clear
  sh.poll
  eq "the frame poll says the sheet once it is painted, queued", SpeakCapture.log,
     [[SummaryHabilidadesSpec.expected("EV / IV / Poder Oculto").join(", "), false]]
end

Suite.define("summary habilidades: the stats page says the C key its picture draws, from medium") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Bulbasaur")
  scene = Object.new
  def scene.Habilidades(_pokemon); nil; end
  stock = Object.new
  key = t.t(:sumh_key)
  rows = vb_levels do
    scene.instance_variable_set(:@access_page_key, nil)
    SpeakCapture.clear
    PokeAccess::Summary.speak_page(scene, pk, 3, "Estadísticas.")
    SpeakCapture.last
  end
  eq "brief: the page alone", rows[0], "Estadísticas."
  eq "medium and full: then the key, once", rows[1..2], ["Estadísticas. #{key}"] * 2
  SpeakCapture.clear
  PokeAccess::Summary.speak_page(scene, pk, 2, "Recuerdos.")
  eq "another page says no key", SpeakCapture.lines, ["Recuerdos."]
  SpeakCapture.clear
  PokeAccess::Summary.speak_page(stock, pk, 3, "Estadísticas.")
  eq "nor does a summary without the sheet", SpeakCapture.lines, ["Estadísticas."]
end
