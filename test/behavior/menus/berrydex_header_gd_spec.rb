# The Berrydex list's counters (Royal, Infinite Fusion 2 Hoenn): read in reading order when they change, queued
# behind the row; the focused berry's painted name is left to the row.
Suite.define("berrydex: the list's counters are read when they change, the focused name left to the row") do
  bd = PokeAccess::BerryDex
  icon = Struct.new(:berry).new(:ORANBERRY)
  scene = World.stub_scene(:@sprites => { "berrydex" => icon })
  paint = lambda do |registered|
    PokeAccess::PaintCapture.arm(:bdx_header)
    pbDrawTextPositions(nil, [["Plantadas: ", 56, 346], ["3", 168, 346], [registered, 189, 314],
                              ["Registradas: ", 56, 314], [GameData::Item.get(:ORANBERRY).name, 132, 58],
                              ["BayaDex", 256, 10]])
    PokeAccess::PaintCapture.take_pairs(:bdx_header)
  end
  SpeakCapture.clear
  bd.list_header(scene, paint.call("12"))
  eq "title and counters, in reading order, without the focused berry's name", SpeakCapture.lines,
     ["BayaDex, Registradas: 12, Plantadas: 3"]
  eq "queued behind the row", SpeakCapture.log.last[1], false
  SpeakCapture.clear
  bd.list_header(scene, paint.call("12"))
  silent "a repaint with the same counters says nothing"
  bd.list_header(scene, paint.call("13"))
  eq "a new registration is read", SpeakCapture.lines, ["BayaDex, Registradas: 13, Plantadas: 3"]
end

# The detail page (BerrydexInfo_Scene#drawPage): the paint arrives description first and every label before every
# value; read as the page lays it out, each label beside its value.
Suite.define("berrydex: a berry's page is read as laid out, each label beside the value on its row") do
  bd = PokeAccess::BerryDex
  scene = World.stub_scene(:@berry => :CHERIBERRY, :@subpage => 0)
  PokeAccess::PaintCapture.arm(:bdx_page)
  drawTextEx(nil, 40, 278, 432, 3, "A soft berry.")
  pbDrawTextPositions(nil, [["01  Cheri Berry", 50, 36], ["Size", 64, 188], ["Firm", 64, 220], ["2.0 cm", 220, 188],
                            ["Soft", 244, 220]])
  pairs = PokeAccess::PaintCapture.take_pairs(:bdx_page)
  SpeakCapture.clear
  bd.page(scene, 1, pairs)
  head = "#{GameData::Item.get(:CHERIBERRY).name}. #{PokeAccess::I18n.t(:bdx_section, :name => PokeAccess::I18n.t(:bdx_page_info))}"
  eq "top to bottom, labels with their values", SpeakCapture.last,
     "#{head}. 01 Cheri Berry. Size 2.0 cm. Firm Soft. A soft berry."
end
