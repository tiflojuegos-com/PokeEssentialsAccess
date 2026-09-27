# Reminiscencia's species picker panel, over stand-ins for the game's functions defined before the profile loads: it
# is read once per repaint in reading order, only from the panel's bitmaps, and not after the picker returns.
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

# The picker's sprite, whose setSpeciesBitmap names the species the panel's type icons belong to.
class PokemonSprite
  def setSpeciesBitmap(species, _female = false, _form = 0, _shiny = false, _shadow = false, _back = false, _egg = false, _hue = nil)
    species
  end
end unless defined?(PokemonSprite)

require File.expand_path("../../../games/reminiscencia/picker", File.dirname(__FILE__))

Suite.define("reminiscencia picker: the panel is spoken once per repaint, in reading order, and only the panel") do
  male = "\xE2\x99\x82"
  female = "\xE2\x99\x80"
  SpeakCapture.clear
  ret = pbCommandsCustom(nil, ["Charmander", "Squirtle", "Bulbasaur"], -1, [4, 7, 1], 0)
  eq "the picker's own answer comes back through the wrap", ret, 2
  lines = SpeakCapture.lines.map { |l| l.to_s }
  eq "two repaints, two lines, the keys after the first, and the bag's paint is not one", lines.length, 3
  eq "sex first, then stats top to bottom with value and bonus, headers and the HP dash dropped, then the moves",
     lines[0], "#{male}, PS 45, Ataque 49 +10%, Defensa 49 0%, At. Esp. 65 0%, Def. Esp. 65 0%, Velocidad 45 -5%, Placaje, Gruñido, Látigo, Ascuas"
  eq "the keys the picker paints, once", lines[1], PokeAccess::ReminPicker.keys_line
  eq "the second repaint reads the new Pokémon, with its two moves",
     lines[2], "#{female}, PS 44, Ataque 48 0%, Defensa 65 +5%, At. Esp. 50 0%, Def. Esp. 64 0%, Velocidad 43 0%, Burbuja, Placaje"

  SpeakCapture.clear
  PickerFixture.paint(*PickerFixture::FIRST)
  PokeAccess::ReminPicker.flush
  eq "after the picker returned its paints are nobody's business", SpeakCapture.lines, []
end

Suite.define("reminiscencia picker: the reading order is the panel's, not the paint order") do
  rows = [[:o, "Bonus", 305, 22], [:o, "Stat", 82, 22], [:o, "+10%", 305, 57], [:o, "PS", 82, 57], [:o, " 45", 240, 57],
          [:n, "Ascuas", 502, 296], [:n, "Placaje", 502, 254], [:o, "\xE2\x99\x80", 574, 186]]
  eq "sex, then lines by height and cells by column", PokeAccess::ReminPicker.text(rows),
     "\xE2\x99\x80, PS 45 +10%, Placaje, Ascuas"
  eq "no sex row is simply no sex", PokeAccess::ReminPicker.text(rows[0, 7]), "PS 45 +10%, Placaje, Ascuas"
end

# What the panel shows as pictures: the types of the species on the sprite (its icons), the shiny star, and each
# move's button coloured by its type, the band of the strip; a move the hard mode hides as "???" by its type alone.
Suite.define("reminiscencia picker: the type icons, the shiny star and each move's colour") do
  rp = PokeAccess::ReminPicker
  t = PokeAccess::I18n
  female = PokeAccess::Party::SIGNS[1]
  buttons = [["Graphics/Pictures/battleFightButtonsSummary", 408, 248, 2, 11 * 46, 192, 46],
             ["Graphics/Pictures/battleFightButtonsSummary", 408, 290, 2, 0, 192, 46]]
  line = nil
  rp.watch do
    PokemonSprite.new.setSpeciesBitmap(7, true, 0, true)
    pbDrawImagePositions(nil, [["Graphics/Pictures/shiny", 420, 186, 0, 0, -1, -1]])
    PickerFixture.paint(*PickerFixture::SECOND)
    pbDrawImagePositions(nil, buttons)
    rp.flush
    line = PokeAccess::Info.info_text.to_s
  end
  types = t.t(:bt_type, :t => PokeAccess::Data.species_types(7).join(" "))
  truthy "sex, star and types lead", line.start_with?("#{female}, #{PokeAccess::Party.shiny_word(nil)}, #{types}, PS 44")
  moves = [t.t(:rem_move_typed, :move => "Burbuja", :t => PokeAccess::Data.type_name(11)),
           t.t(:rem_move_typed, :move => "Placaje", :t => PokeAccess::Data.type_name(0))]
  truthy "each move with its button's type", line.end_with?(moves.join(", "))
  rp.watch do
    PokemonSprite.new.setSpeciesBitmap(7, true, 1, false)
    PickerFixture.paint(female, ["???", "???"], PickerFixture::SECOND[2])
    pbDrawImagePositions(nil, buttons)
    rp.flush
    line = PokeAccess::Info.info_text.to_s
  end
  falsy "an alternate form's types are not guessed from the species", line.include?(types)
  falsy "no star on a plain one", line.include?(PokeAccess::Party.shiny_word(nil))
  truthy "a hidden move is said by its type", line.include?(t.t(:rem_move_typed, :move => t.t(:rem_move_hidden),
                                                                :t => PokeAccess::Data.type_name(11)))
end

# In the picker T opens the bag (pbCommandsCustom reads 0x54 raw): the info key, T by default, yields to it while the
# picker is up, and keeps working when either of them was moved.
Suite.define("reminiscencia picker: the info key yields while it is the game's T") do
  rp = PokeAccess::ReminPicker
  k = PokeAccess::Keys
  rp.watch do
    rp.flush
    truthy "T on both: the game's bag wins", k.yielded?(:info)
  end
  k.instance_variable_set(:@yielded, {})
  PokeAccess::Config.rebinds = { :fast_travel => 0x37 }
  rp.watch do
    rp.flush
    falsy "the game's T moved away: T is the info key's", k.yielded?(:info)
  end
  PokeAccess::Config.rebinds = {}
  require File.expand_path("../../../games/reminiscencia/bag", File.dirname(__FILE__))
  k.instance_variable_set(:@yielded, {})
  rp.watch do
    PokeAccess::ReminBag.watch(Object.new)
    rp.flush
    falsy "the bag T opened from the picker keeps T as the info key", k.yielded?(:info)
    PokeAccess::ReminBag.unwatch
  end
  k.instance_variable_set(:@yielded, {})
  rp.flush
  falsy "and nothing is claimed once the picker returns", k.yielded?(:info)
end
