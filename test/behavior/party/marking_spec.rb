# The gen-6 PC's marking screen: a command list, one row per mark painted dark when set and pale when not
# (getMarkingCommands, z218/144_PScreen_Storage.rb:2583), then OK and Cancel; only the colour tag tells them apart.

MARKING6_SIGNS = ["\xE2\x97\x8F", "\xE2\x96\xA0", "\xE2\x96\xB2", "\xE2\x99\xA5"]

# The rows as the game builds them from the marks' bits.
def marking6_rows(markings)
  rows = (0...4).map do |i|
    tag = (markings & (1 << i)) == 0 ? "<c=D0C8B8>" : "<c=505050>"
    "#{tag}<ac><fn=Arial>#{MARKING6_SIGNS[i]}"
  end
  rows + ["Aceptar", "Salir"]
end

# The loop (z218/144_PScreen_Storage.rb:2595-2655): the title set in its window, the list built and updated
# once before the loop, then a frame per key -- the button on a mark flips its bit and rebuilds the rows.
def marking6_loop(keys)
  lambda do |_selected, heldpoke|
    drawTextEx(nil, 0, 0, 332, 1, "Marcar tu Pokemon.")
    markings = heldpoke.markings
    win = Window_AdvancedCommandPokemon.new(marking6_rows(markings))
    win.update
    keys.each do |k|
      Input.update
      if k == :down
        win.index += 1
      elsif k == :use && win.index < 4
        markings ^= (1 << win.index)
        win.commands = marking6_rows(markings)
      end
      win.update
    end
    markings
  end
end

Suite.define("marking gen-6: each row says its sign and whether it is set, and says it again when it changes") do
  t = PokeAccess::I18n
  held = Poke.build(:name => "Pika")
  held.define_singleton_method(:markings) { 0b0010 }
  scene = PokemonStorageScene.new
  scene.marking_loop = marking6_loop([:use, :down, :use, :down, :down, :down])
  SpeakCapture.clear
  scene.pbMark([0, 0], held)
  eq "the title first, then the rows with their state, the buttons as the list names them",
     SpeakCapture.lines,
     ["Marcar tu Pokemon.", "#{MARKING6_SIGNS[0]}, #{t.t(:mk_off)}", "#{MARKING6_SIGNS[0]}, #{t.t(:mk_on)}",
      "#{MARKING6_SIGNS[1]}, #{t.t(:mk_on)}", "#{MARKING6_SIGNS[1]}, #{t.t(:mk_off)}",
      "#{MARKING6_SIGNS[2]}, #{t.t(:mk_off)}", "#{MARKING6_SIGNS[3]}, #{t.t(:mk_off)}", "Aceptar"]
end

Suite.define("marking gen-6: the same tags anywhere else are no marks") do
  win = Window_AdvancedCommandPokemon.new(["<c=505050>Rojo", "<c=D0C8B8>Gris"])
  SpeakCapture.clear
  win.update
  eq "a list of the class outside the screen reads as it always did", SpeakCapture.lines, ["Rojo"]
end
