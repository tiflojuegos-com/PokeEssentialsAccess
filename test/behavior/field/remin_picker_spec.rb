# Reminiscencia's species picker panel: sex, moves and base stats with the run's bonus, painted with
# pbDrawTextPositions onto two overlay bitmaps on every cursor move. What is pinned: the panel is spoken once
# per repaint in reading order (sex, then each line top to bottom and left to right, headers and the HP
# dash dropped), bitmaps other than the panel's (the bag opened on T) stay out, and nothing is collected
# once the picker has returned.
#
# The picker function and the paint function are the game's; both are stood in for here before the module
# loads, and the fixture paints the way the game does, calling the reader's per-frame flush where the game
# would run a frame.
def pbDrawTextPositions(bitmap, textpos); textpos; end unless Object.private_method_defined?(:pbDrawTextPositions)

module PickerFixture
  OVERLAY = Object.new
  NARROW = Object.new
  BAG = Object.new

  # One repaint of the panel, the three pbDrawTextPositions calls in the game's order and layout.
  def self.paint(sex, moves, stats)
    pbDrawTextPositions(OVERLAY, sex ? [[sex, 574, 186, false, nil, nil]] : [])
    pbDrawTextPositions(NARROW, moves.each_with_index.map { |m, i| [m, 502, 254 + 42 * i, 2, nil, nil] })
    rows = [["Stat", 82, 22, 0, nil, nil], ["Bonus", 305, 22, 1, nil, nil]]
    stats.each_with_index do |(label, value, bonus), i|
      y = [57, 92, 125, 159, 194, 227][i]
      rows.push([label, 82, y, 0, nil, nil], [value, 240, y, 1, nil, nil], [bonus, 305, y, 1, nil, nil])
    end
    pbDrawTextPositions(OVERLAY, rows)
  end

  FIRST = ["\xE2\x99\x82", ["Placaje", "Gruñido", "Látigo", "Ascuas"],
           [["PS", " 45", "---"], ["Ataque", "49", "+10%"], ["Defensa", "49", "0%"], ["At. Esp.", "65", "0%"],
            ["Def. Esp.", "65", "0%"], ["Velocidad", "45", "-5%"]]]
  SECOND = ["\xE2\x99\x80", ["Burbuja", "Placaje"],
            [["PS", " 44", "---"], ["Ataque", "48", "0%"], ["Defensa", "65", "+5%"], ["At. Esp.", "50", "0%"],
             ["Def. Esp.", "64", "0%"], ["Velocidad", "43", "0%"]]]
end

def pbCommandsCustom(cmdwindow, commands, cmdIfCancel, ids, defaultindex = -1)
  PickerFixture.paint(*PickerFixture::FIRST)
  PokeAccess::ReminPicker.flush
  PickerFixture.paint(*PickerFixture::SECOND)
  PokeAccess::ReminPicker.flush
  pbDrawTextPositions(PickerFixture::BAG, [["Baya Aranja", 10, 10, 0, nil, nil], ["Cura la quemadura", 10, 40, 0, nil, nil]])
  PokeAccess::ReminPicker.flush
  2
end unless Object.private_method_defined?(:pbCommandsCustom)

require File.expand_path("../../../games/reminiscencia/picker", File.dirname(__FILE__))

Suite.define("reminiscencia picker: the panel is spoken once per repaint, in reading order, and only the panel") do
  male = PokeAccess::I18n.t(:pk_male)
  female = PokeAccess::I18n.t(:pk_female)
  SpeakCapture.clear
  ret = pbCommandsCustom(nil, ["Charmander", "Squirtle", "Bulbasaur"], -1, [4, 7, 1], 0)
  eq "the picker's own answer comes back through the wrap", ret, 2
  lines = SpeakCapture.lines.map { |l| l.to_s }
  eq "two repaints, two lines, and the bag's paint is not a third", lines.length, 2
  eq "sex first, then stats top to bottom with value and bonus, headers and the HP dash dropped, then the moves",
     lines[0], "#{male}, PS 45, Ataque 49 +10%, Defensa 49 0%, At. Esp. 65 0%, Def. Esp. 65 0%, Velocidad 45 -5%, Placaje, Gruñido, Látigo, Ascuas"
  eq "the second repaint reads the new Pokémon, with its two moves",
     lines[1], "#{female}, PS 44, Ataque 48 0%, Defensa 65 +5%, At. Esp. 50 0%, Def. Esp. 64 0%, Velocidad 43 0%, Burbuja, Placaje"

  SpeakCapture.clear
  PickerFixture.paint(*PickerFixture::FIRST)
  PokeAccess::ReminPicker.flush
  eq "after the picker returned its paints are nobody's business", SpeakCapture.lines, []
end

Suite.define("reminiscencia picker: the reading order is the panel's, not the paint order") do
  rows = [[:o, "Bonus", 305, 22], [:o, "Stat", 82, 22], [:o, "+10%", 305, 57], [:o, "PS", 82, 57], [:o, " 45", 240, 57],
          [:n, "Ascuas", 502, 296], [:n, "Placaje", 502, 254], [:o, "\xE2\x99\x80", 574, 186]]
  eq "sex, then lines by height and cells by column", PokeAccess::ReminPicker.text(rows),
     "#{PokeAccess::I18n.t(:pk_female)}, PS 45 +10%, Placaje, Ascuas"
  eq "no sex row is simply no sex", PokeAccess::ReminPicker.text(rows[0, 7]), "PS 45 +10%, Placaje, Ascuas"
end
