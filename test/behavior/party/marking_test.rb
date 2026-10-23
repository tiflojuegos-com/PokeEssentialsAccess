# The gen-6 PC's marking screen: a command list, one row per mark painted dark when set and pale when not
# (getMarkingCommands, z218/144_PScreen_Storage.rb:2583), then OK and Cancel; only the colour tag tells them apart.
class MarkingTest < PokeAccessTest
  SIGNS = ["\xE2\x97\x8F", "\xE2\x96\xA0", "\xE2\x96\xB2", "\xE2\x99\xA5"]

  test "says the title, then each row's sign and whether it is set, and the row again at once as the button changes it" do
    mark(0b0010, [:use, :down, :use, :down, :down, :down])
    assert_equal [["Marcar tu Pokemon.", false], [row(0, :mk_off), false], [row(0, :mk_on), true], [row(1, :mk_on), true],
                  [row(1, :mk_off), true], [row(2, :mk_off), true], [row(3, :mk_off), true], ["Aceptar", true]],
                 SpeakCapture.log
  end

  test "reads rows with the same colour tags as plain rows once the screen has closed" do
    mark(0, [])
    win = Window_AdvancedCommandPokemon.new(["<c=505050>Rojo", "<c=D0C8B8>Gris"])
    SpeakCapture.clear
    win.update
    win.index = 1
    win.update
    assert_equal [["Rojo", false], ["Gris", true]], SpeakCapture.log
  end

  private

  # A mark's row as read: its sign as painted, then its state.
  def row(i, state)
    "#{SIGNS[i]}, #{PokeAccess::I18n.t(state)}"
  end

  # The rows as the game builds them from the marks' bits.
  def rows_for(markings)
    rows = (0...4).map do |i|
      tag = (markings & (1 << i)) == 0 ? "<c=D0C8B8>" : "<c=505050>"
      "#{tag}<ac><fn=Arial>#{SIGNS[i]}"
    end
    rows + ["Aceptar", "Salir"]
  end

  # Marks a held Pokemon whose marks are these bits on the PC, a frame per key; the speech starts empty.
  def mark(markings, keys)
    held = Poke.build(:name => "Pika")
    held.define_singleton_method(:markings) { markings }
    scene = PokemonStorageScene.new
    scene.marking_loop = marking_loop(keys)
    SpeakCapture.clear
    scene.pbMark([0, 0], held)
  end

  # The loop (z218/144_PScreen_Storage.rb:2595-2655), run in the scene: the title set in its window, the list built
  # and updated once before the loop, then a frame per key; the button on a mark flips its bit and rebuilds the rows
  # before the list's update, as the game's loop does, with nothing said in between.
  def marking_loop(keys)
    rows = method(:rows_for)
    lambda do |_selected, heldpoke|
      drawTextEx(nil, 0, 0, 332, 1, "Marcar tu Pokemon.")
      markings = heldpoke.markings
      win = Window_AdvancedCommandPokemon.new(rows.call(markings))
      win.update
      keys.each do |k|
        Input.update
        if k == :down
          win.index += 1
        elsif k == :use && win.index < 4
          markings ^= (1 << win.index)
          win.commands = rows.call(markings)
        end
        win.update
      end
      markings
    end
  end
end
