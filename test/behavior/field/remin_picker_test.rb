# Reminiscencia's species picker (games/reminiscencia/picker.rb): while pbCommandsCustom runs, each repaint of the
# panel beside the list (sex, base stats, moves, and the pictures: shiny star, type icons, move buttons) is said once
# in reading order and kept for the info key, and the info key yields T to the game, which opens the bag with it.

# Reminiscencia's picker, down to its loop: each frame handed in place of the command window paints, then the input
# is read; it answers the default choice.
def pbCommandsCustom(cmdwindow, _commands, _cmd_if_cancel, _ids, defaultindex = -1)
  cmdwindow.each do |paint|
    paint.call
    Input.update
  end
  defaultindex
end unless Object.private_method_defined?(:pbCommandsCustom)

# The picker's sprite, whose setSpeciesBitmap sets the species the panel's type icons belong to.
class PokemonSprite
  def setSpeciesBitmap(species, _female = false, _form = 0, _shiny = false, _shadow = false, _back = false,
                       _egg = false, _hue = nil)
    species
  end
end unless defined?(PokemonSprite)

picker = File.join(Harness::ROOT, "games", "reminiscencia", "picker.rb")
eval(Harness.source(picker), TOPLEVEL_BINDING, picker)

# The bag, whose watcher the picker asks whether the bag it opened is up: the whole file, as
# behavior/menus/remin_bag_test.rb evaluates it, unless something loaded it first.
bag = File.join(Harness::ROOT, "games", "reminiscencia", "bag.rb")
eval(Harness.source(bag), TOPLEVEL_BINDING, bag) unless PokeAccess.const_defined?(:ReminBag, false)

class ReminPickerTest < PokeAccessTest
  # The bitmaps the panel paints on (its overlay and the narrow move column) and one of the bag's.
  OVERLAY = Object.new
  NARROW = Object.new
  BAG = Object.new
  # The heights of the six stat rows under the panel's header.
  STAT_ROWS = [57, 92, 125, 159, 194, 227]
  # Two repaints as the game paints them: sex sign, moves, and each stat with its value and bonus.
  FIRST = ["♂", ["Placaje", "Gruñido", "Látigo", "Ascuas"],
           [["PS", " 45", "---"], ["Ataque", "49", "+10%"], ["Defensa", "49", "0%"], ["At. Esp.", "65", "0%"],
            ["Def. Esp.", "65", "0%"], ["Velocidad", "45", "-5%"]]]
  SECOND = ["♀", ["Burbuja", "Placaje"],
            [["PS", " 44", "---"], ["Ataque", "48", "0%"], ["Defensa", "65", "+5%"], ["At. Esp.", "50", "0%"],
             ["Def. Esp.", "64", "0%"], ["Velocidad", "43", "0%"]]]
  # The first repaint as said, and the second's stats.
  FIRST_LINE = "♂, PS 45, Ataque 49 +10%, Defensa 49 0%, At. Esp. 65 0%, Def. Esp. 65 0%, Velocidad 45 -5%, " \
               "Placaje, Gruñido, Látigo, Ascuas"
  SECOND_STATS = "PS 44, Ataque 48 0%, Defensa 65 +5%, At. Esp. 50 0%, Def. Esp. 64 0%, Velocidad 43 0%"
  # The shiny star and the two move buttons, each a 46-pixel band of the strip: Water (11) and Normal (0).
  STAR = ["Graphics/Pictures/shiny", 420, 186, 0, 0, -1, -1]
  BUTTONS = [["Graphics/Pictures/battleFightButtonsSummary", 408, 248, 2, 11 * 46, 192, 46],
             ["Graphics/Pictures/battleFightButtonsSummary", 408, 290, 2, 0, 192, 46]]

  test "says each repaint once, queued, in reading order, with the keys under the panel after the first" do
    pick(lambda { paint_panel(*FIRST) }, lambda {}, lambda { paint_panel(*SECOND) })
    assert_equal [[FIRST_LINE, false], [keys_line, false], ["♀, #{SECOND_STATS}, Burbuja, Placaje", false]],
                 SpeakCapture.log
  end

  test "answers what the picker answers" do
    assert_equal 2, pick(lambda { paint_panel(*FIRST) })
  end

  test "keeps the last repaint for the info key" do
    pick(lambda { paint_panel(*FIRST) }, lambda { paint_panel(*SECOND) })
    assert_equal "♀, #{SECOND_STATS}, Burbuja, Placaje", PokeAccess::Info.info_text
  end

  test "what it says of a repaint follows the verbosity, while the info key keeps the whole panel" do
    said_at = { :full => [[FIRST_LINE, false], [keys_line, false]], :medium => [[keys_line, false]], :brief => [] }
    said_at.each do |level, said|
      PokeAccess::Config.verbosity = level
      PokeAccess::Info.set_info(nil, nil)
      SpeakCapture.clear
      pick(lambda { paint_panel(*FIRST) })
      assert_equal said, SpeakCapture.log, "at #{level}"
      assert_equal FIRST_LINE, PokeAccess::Info.info_text, "the info key at #{level}"
    end
  end

  test "at medium a repaint says the types the panel shows of the species, and nothing else of it" do
    PokeAccess::Config.verbosity = :medium
    pick(lambda do
      PokemonSprite.new.setSpeciesBitmap(25, false, 0)
      paint_panel(*SECOND)
    end)
    assert_equal [[types_line("Tipo13"), false], [keys_line, false]], SpeakCapture.log
  end

  test "once it knows the panel's bitmaps, what is painted on any other is not read" do
    pick(lambda { paint_panel(*FIRST) }, lambda { pbDrawTextPositions(BAG, [["Baya Aranja", 10, 10, 0, nil, nil]]) })
    assert_equal [[FIRST_LINE, false], [keys_line, false]], SpeakCapture.log
  end

  test "rows and pictures that are not lists are passed over" do
    pick(lambda do
      paint_panel(*SECOND)
      pbDrawTextPositions(OVERLAY, [:ruido])
      pbDrawTextPositions(OVERLAY, nil)
      pbDrawImagePositions(nil, [:ruido])
      pbDrawImagePositions(nil, nil)
    end)
    assert_equal ["♀, #{SECOND_STATS}, Burbuja, Placaje", false], SpeakCapture.log.first
  end

  test "a sprite set outside the picker gives the panel no types" do
    PokemonSprite.new.setSpeciesBitmap(25, false, 0)
    pick(lambda { paint_panel(*SECOND) })
    assert_equal ["♀, #{SECOND_STATS}, Burbuja, Placaje", false], SpeakCapture.log.first
  end

  test "outside the picker a repaint is not read and the info key is not claimed" do
    paint_panel(*FIRST)
    Input.update
    assert_nothing_spoken
    assert_equal false, PokeAccess::Keys.yielded?(:info)
  end

  test "after the picker returns its repaints are not read" do
    pick(lambda { paint_panel(*FIRST) })
    SpeakCapture.clear
    paint_panel(*SECOND)
    Input.update
    assert_nothing_spoken
  end

  test "orders the panel by height, then by column, whatever the order it was painted in" do
    rows = [[OVERLAY, "Bonus", 305, 22], [OVERLAY, "Stat", 82, 22], [OVERLAY, "+10%", 305, 57], [OVERLAY, "PS", 82, 57],
            [OVERLAY, " 45", 240, 57], [NARROW, "Ascuas", 502, 296], [NARROW, "Placaje", 502, 254],
            [OVERLAY, "♀", 574, 186]]
    assert_equal "♀, PS 45 +10%, Placaje, Ascuas", PokeAccess::ReminPicker.text(rows)
    assert_equal "PS 45 +10%, Placaje, Ascuas", PokeAccess::ReminPicker.text(rows[0, 7]), "with no sex sign painted"
  end

  test "leads with the shiny star and the species' types, and says each move with its button's type" do
    pick(lambda do
      PokemonSprite.new.setSpeciesBitmap(25, true, 0, true)
      pbDrawImagePositions(nil, [STAR])
      paint_panel(*SECOND)
      pbDrawImagePositions(nil, BUTTONS)
    end)
    line = "♀, #{PokeAccess::I18n.t(:pk_shiny)}, #{types_line("Tipo13")}, #{SECOND_STATS}, " \
           "#{typed_move("Burbuja", "Tipo11")}, #{typed_move("Placaje", "Tipo0")}"
    assert_equal [line, false], SpeakCapture.log.first
  end

  test "says only the base form's types, both when it has two, a sprite set with no form showing the base one" do
    pikachu = "♀, #{types_line("Tipo13")}, #{SECOND_STATS}, Burbuja, Placaje"
    plain = "♀, #{SECOND_STATS}, Burbuja, Placaje"
    { [25, false, 0] => pikachu, [25] => pikachu, [25, false, 1] => plain,
      [7, false, 0] => "♀, #{types_line("Tipo1 Tipo2")}, #{SECOND_STATS}, Burbuja, Placaje" }.each do |sprite, line|
      SpeakCapture.clear
      pick(lambda do
        PokemonSprite.new.setSpeciesBitmap(*sprite)
        paint_panel(*SECOND)
      end)
      assert_equal [line, false], SpeakCapture.log.first, "for the sprite set as #{sprite.inspect}"
    end
  end

  test "a move the hard mode hides is said by its button's type" do
    pick(lambda do
      paint_panel("♀", ["???", "???"], SECOND[2])
      pbDrawImagePositions(nil, BUTTONS)
    end)
    hidden = PokeAccess::I18n.t(:rem_move_hidden)
    assert_equal ["♀, #{SECOND_STATS}, #{typed_move(hidden, "Tipo11")}, #{typed_move(hidden, "Tipo0")}", false],
                 SpeakCapture.log.first
  end

  test "pictures drawn in a frame with no text are not carried to the next repaint" do
    pick(lambda { pbDrawImagePositions(nil, [STAR]) }, lambda { paint_panel(*SECOND) })
    assert_equal ["♀, #{SECOND_STATS}, Burbuja, Placaje", false], SpeakCapture.log.first
  end

  test "a move button types the row painted from its top down to twelve pixels below it" do
    button = [["Graphics/Pictures/battleFightButtonsSummary", 100, 11 * 46]]
    typed = typed_move("Burbuja", "Tipo11")
    { 100 => typed, 112 => typed, 113 => "Burbuja", 99 => "Burbuja" }.each do |y, line|
      rows = [[OVERLAY, "Stat", 82, 22], [NARROW, "Burbuja", 502, y]]
      assert_equal line, PokeAccess::ReminPicker.text(rows, button), "for a row painted at #{y}"
    end
  end

  test "while the picker runs, the info key yields to the key the game's T answers to" do
    { [{}, 0x54] => true, [{ :fast_travel => 0x37 }, 0x54] => false, [{}, 0x49] => false,
      [{ :fast_travel => 0x49 }, 0x49] => true }.each do |(rebinds, info), yields|
      Reset.reset_keys
      PokeAccess::Config.rebinds = rebinds
      PokeAccess::Config.keys[:info] = info
      claimed = PokeAccess::ReminPicker.watch do
        PokeAccess::ReminPicker.flush
        PokeAccess::Keys.yielded?(:info)
      end
      assert_equal yields, claimed, "with the game's T rebound as #{rebinds.inspect} and the info key on #{info}"
    end
  end

  test "while the bag it opened is up, T stays the info key" do
    claimed = PokeAccess::ReminPicker.watch do
      begin
        PokeAccess::ReminBag.watch(Object.new)
        PokeAccess::ReminPicker.flush
        PokeAccess::Keys.yielded?(:info)
      ensure
        PokeAccess::ReminBag.unwatch
      end
    end
    assert_equal false, claimed
  end

  private

  # Runs the picker over frames, each a block that paints; answers what it answers (2, the default choice here).
  def pick(*frames)
    pbCommandsCustom(frames, ["Charmander", "Squirtle", "Bulbasaur"], -1, [4, 7, 1], 2)
  end

  # Paints one repaint of the panel as the game does: the sex sign, the moves on their narrow bitmap, then the stats
  # table under its header row.
  def paint_panel(sex, moves, stats)
    pbDrawTextPositions(OVERLAY, sex ? [[sex, 574, 186, false, nil, nil]] : [])
    pbDrawTextPositions(NARROW, moves.each_with_index.map { |m, i| [m, 502, 254 + 42 * i, 2, nil, nil] })
    rows = [["Stat", 82, 22, 0, nil, nil], ["Bonus", 305, 22, 1, nil, nil]]
    stats.each_with_index do |(label, value, bonus), i|
      rows.push([label, 82, STAT_ROWS[i], 0, nil, nil], [value, 240, STAT_ROWS[i], 1, nil, nil],
                [bonus, 305, STAT_ROWS[i], 1, nil, nil])
    end
    pbDrawTextPositions(OVERLAY, rows)
  end

  # The keys the picker paints under its panel, as the player has them by default.
  def keys_line
    PokeAccess::I18n.t(:rem_picker_keys, :bag => "T", :back => "X")
  end

  # The types the panel's icons show, as said: names as the gen-6 stub gives them (type n is "Tipon"; Pikachu, 25, is
  # of type 13 alone, any other species of types 1 and 2).
  def types_line(names)
    PokeAccess::I18n.t(:bt_type, :t => names)
  end

  # A move as said with the type its button's band shows, named as the stub names it.
  def typed_move(move, type)
    PokeAccess::I18n.t(:rem_move_typed, :move => move, :t => type)
  end
end
