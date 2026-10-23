# The older Pokedex search (gen-6), a grouped list of filters whose message box shows the focused row's help: each row
# said with its help, read by this reader alone, and a filter's sub-list whose help is watched while it is open.
class Window_ComplexCommandPokemon < Window_DrawableCommand
  # The group and the row a flat index falls on, as the game computes it: [group, -1] for a group's heading.
  def indexToCommand(index)
    curindex = 0
    i = 0
    while i < @commands.length
      return [i / 2, -1] if index == curindex
      curindex += 1
      return [i / 2, index - curindex] if index - curindex < @commands[i + 1].length
      curindex += @commands[i + 1].length
      i += 2
    end
    [-1, -1]
  end

  def getText(array, index)
    cmd = indexToCommand(index)
    return "" if cmd[0] == -1
    return array[cmd[0] * 2] if cmd[1] < 0
    array[cmd[0] * 2 + 1][cmd[1]]
  end
end

class DexSearchHelpTest < PokeAccessTest
  # The search list as pbRefreshDexSearch fills it, and the help its message box shows for each row.
  ROWS = ["Búsqueda", ["Nombre: ----", "Color: ----", "Tipo 1: ----", "Iniciar Búsqueda"]]
  HELPS = ["Búsqueda según los parámetros seleccionados.",
           ["Listar por primera letra del nombre.\r\nSolamente los vistos.", "Listar por color del cuerpo.",
            "Listar por tipo.\r\nSolamente atrapados.", "Ejecutar búsqueda."]]
  # A list whose rows show no help.
  NO_HELPS = ["", ["", "", "", ""]]
  # Two options' help in a filter's sub-list.
  ORDER_HELP = "Los Pokémon se listan según su número."
  WEIGHT_HELP = "Los Pokémon capturados se listan del más pesado al más ligero."

  test "the focused row is said with the help its message box shows" do
    redraw(search_scene(3))
    assert_equal [["Búsqueda, Tipo 1: ----. Listar por tipo. Solamente atrapados.", true]], SpeakCapture.log
  end

  test "below full verbosity the row is said alone, and the info key keeps its help" do
    PokeAccess::Config.verbosity = :medium
    redraw(search_scene(3))
    assert_equal [["Búsqueda, Tipo 1: ----", true]], SpeakCapture.log
    assert_equal "Listar por tipo. Solamente atrapados.", PokeAccess::Info.info_text
  end

  test "a row with no help is said alone, and the info key is left as it was" do
    PokeAccess::Info.set_info(:text, "Pokédex")
    redraw(search_scene(3), NO_HELPS)
    assert_equal [["Búsqueda, Tipo 1: ----", true]], SpeakCapture.log
    assert_equal "Pokédex", PokeAccess::Info.info_text
  end

  test "the search's first row follows its title and its group's heading, a row entering another group that one's" do
    list = Window_ComplexCommandPokemon.new(ROWS + ["Ordenar", ["Orden: Numérico", "Iniciar orden"]])
    title = Struct.new(:text).new("<ac>Modo búsqueda</ac>")
    scene = World.stub_scene(:@sprites => { "searchlist" => list, "searchtitle" => title })
    [1, 2, 6, 7, 4].each do |i|
      list.index = i
      PokeAccess::DexSearch.refresh(scene, [[0, 0, 0, 0, 0, 0]])
    end
    assert_equal ["Modo búsqueda. Búsqueda, Nombre: ----", "Color: ----", "Ordenar, Orden: Numérico",
                  "Iniciar orden", "Búsqueda, Iniciar Búsqueda"], SpeakCapture.lines
  end

  test "a filter's sub-list says the value it opens on, even the one the sub-list was last left on" do
    aux = Window_DrawableCommand.new(["Ninguno", "Fuego"])
    aux.index = 1
    aux.update
    PokeAccess::DexSearch.sub_list_opened(World.stub_scene(:@sprites => { "auxlist" => aux }))
    aux.update
    assert_equal ["Fuego", "Fuego"], SpeakCapture.lines
  end

  test "a screen with no list, a list with no rows or a cursor past them says nothing" do
    empty = Window_ComplexCommandPokemon.new(nil)
    past = Window_ComplexCommandPokemon.new(ROWS)
    past.index = 9
    [{}, { "searchlist" => empty }, { "searchlist" => past }].each do |sprites|
      PokeAccess::DexSearch.refresh(World.stub_scene(:@sprites => sprites), [[0, 0, 0, 0, 0, 0]])
    end
    assert_nothing_spoken
  end

  test "a list with no message box says its row alone" do
    list = Window_ComplexCommandPokemon.new(ROWS)
    list.index = 3
    PokeAccess::DexSearch.refresh(World.stub_scene(:@sprites => { "searchlist" => list }), [[0, 0, 0, 0, 0, 0]])
    assert_equal [["Búsqueda, Tipo 1: ----", true]], SpeakCapture.log
  end

  test "the list is read by this reader alone, each row once" do
    scene = search_scene(1)
    win = PokeAccess.sprite(scene, "searchlist")
    redraw(scene)
    win.update
    redraw(scene)
    win.index = 2
    win.update
    redraw(scene)
    assert_equal ["Búsqueda, Nombre: ----. Listar por primera letra del nombre. Solamente los vistos.",
                  "Color: ----. Listar por color del cuerpo."],
                 SpeakCapture.lines
  end

  test "a sub-list's help is said from its second frame, queued behind the option the list says" do
    sub_list(search_scene(1), ORDER_HELP) do
      PokeAccess::DexSearch.aux_poll
      assert_nothing_spoken "the first frame is the option's"
      PokeAccess::DexSearch.aux_poll
      assert_equal [[ORDER_HELP, false]], SpeakCapture.log
    end
  end

  test "a sub-list's help is not said again while it stays, and a new one is" do
    scene = search_scene(1)
    sub_list(scene, ORDER_HELP) do
      3.times { PokeAccess::DexSearch.aux_poll }
      PokeAccess.sprite(scene, "messagebox").text = WEIGHT_HELP
      PokeAccess::DexSearch.aux_poll
    end
    assert_equal [ORDER_HELP, WEIGHT_HELP], SpeakCapture.lines
  end

  test "below full verbosity a sub-list's help is not said, and the info key keeps it" do
    PokeAccess::Config.verbosity = :medium
    sub_list(search_scene(1), ORDER_HELP) { 2.times { PokeAccess::DexSearch.aux_poll } }
    assert_nothing_spoken
    assert_equal ORDER_HELP, PokeAccess::Info.info_text
  end

  test "a sub-list with no help says nothing" do
    sub_list(search_scene(1), "") { 2.times { PokeAccess::DexSearch.aux_poll } }
    assert_nothing_spoken
  end

  test "a sub-list opened again says its help again" do
    scene = search_scene(1)
    2.times { sub_list(scene, ORDER_HELP) { 2.times { PokeAccess::DexSearch.aux_poll } } }
    assert_equal [ORDER_HELP, ORDER_HELP], SpeakCapture.lines
  end

  test "once the sub-list closes its help is no longer watched" do
    scene = search_scene(1)
    sub_list(scene, ORDER_HELP) { 2.times { PokeAccess::DexSearch.aux_poll } }
    SpeakCapture.clear
    PokeAccess.sprite(scene, "messagebox").text = WEIGHT_HELP
    2.times { PokeAccess::DexSearch.aux_poll }
    assert_nothing_spoken
  end

  private

  # A search screen with its list on row index and an empty message box.
  def search_scene(index)
    list = Window_ComplexCommandPokemon.new(ROWS)
    list.index = index
    World.stub_scene(:@sprites => { "searchlist" => list, "messagebox" => Struct.new(:text).new("") })
  end

  # The list's redraw as pbRefreshDexSearch(params) runs it: the focused row's help into the message box, then the
  # mod's hook.
  def redraw(scene, helps = HELPS)
    list = PokeAccess.sprite(scene, "searchlist")
    PokeAccess.sprite(scene, "messagebox").text = list.getText(helps, list.index)
    PokeAccess::DexSearch.refresh(scene, [[0, 0, 0, 0, 0, 0]])
  end

  # Runs the block while a filter's sub-list is open over scene, its message box showing help; closed afterwards.
  def sub_list(scene, help)
    PokeAccess.sprite(scene, "messagebox").text = help
    PokeAccess::DexSearch.aux_open(scene)
    yield
  ensure
    PokeAccess::DexSearch.aux_close
  end
end
