# The screens' messages on the gen-6 engine: a yes/no's question said before the game puts up its answers, a command
# list handed first not read as one, a plain message as it is; and the PC's cursor mode, said as it changes.
class ScreenQuestionTest < PokeAccessTest
  test "the question of a yes/no is said before the game shows its answers" do
    forget_dialogue
    heard = heard_by_game("PokemonStorageScene", :pbShowCommands) do
      PokemonStorageScene.new.pbShowCommands("¿Quieres soltar a Chispa?", ["Sí", "No"])
    end
    assert_equal [["¿Quieres soltar a Chispa?"]], heard, "already said when the game's own method ran"
    assert_equal [["¿Quieres soltar a Chispa?", false]], SpeakCapture.log
  end

  test "choosing a box says the question, then the box the list opens on, queued, whichever box that is" do
    { 0 => "Box 1 (0/30)", 2 => "Box 3 (5/30)" }.each do |current, box|
      forget_dialogue
      SpeakCapture.clear
      choose_box(current, [])
      assert_equal [["Deposit in which Box?", false], [box, false]], SpeakCapture.log, "on box #{current + 1}"
    end
  end

  test "a move on the box list after the box it opened on cuts in, as any move" do
    forget_dialogue
    choose_box(2, [:down])
    assert_equal [["Deposit in which Box?", false], ["Box 3 (5/30)", false], ["Box 4 (30/30)", true]],
                 SpeakCapture.log
  end

  test "a plain message of the PC is said" do
    forget_dialogue
    PokemonStorageScene.new.pbDisplay("Se ha depositado a Pikachu.")
    assert_equal [["Se ha depositado a Pikachu.", false]], SpeakCapture.log
  end

  test "a command list handed first is not read as a message, and the repeat key keeps the last line" do
    forget_dialogue
    PokeAccess.say_dialogue("Se ha depositado a Chispa.")
    SpeakCapture.clear
    PokemonSummaryScene.new.pbShowCommands(["Dar objeto", "Quitar objeto", "Ver Pokédex", "Marcar", "Cancelar"])
    assert_nothing_spoken "the list is the command window's to name"
    assert_equal "Se ha depositado a Chispa.", PokeAccess.last_dialogue
  end

  test "the PC's cursor mode is the normal one with nothing set" do
    PokeAccess::StorageModes.say(World.stub_scene)
    assert_equal [[PokeAccess::I18n.t(:pc_mode_normal), true]], SpeakCapture.log
  end

  test "quick swap is named, cutting in, as it answers the key just pressed" do
    PokeAccess::StorageModes.say(World.stub_scene(:@quickswap => true))
    assert_equal [[PokeAccess::I18n.t(:pc_mode_quick), true]], SpeakCapture.log
  end

  test "multi-select is named even with quick swap still set" do
    PokeAccess::StorageModes.say(World.stub_scene(:@quickswap => true, :@multi => true))
    assert_equal [[PokeAccess::I18n.t(:pc_mode_multi), true]], SpeakCapture.log
  end

  test "the same mode again says nothing" do
    scene = World.stub_scene(:@quickswap => true)
    PokeAccess::StorageModes.say(scene)
    SpeakCapture.clear
    PokeAccess::StorageModes.say(scene)
    assert_nothing_spoken
  end

  test "coming back to the normal mode says it again" do
    scene = World.stub_scene(:@quickswap => true, :@multi => true)
    PokeAccess::StorageModes.say(scene)
    scene.instance_variable_set(:@multi, false)
    scene.instance_variable_set(:@quickswap, false)
    SpeakCapture.clear
    PokeAccess::StorageModes.say(scene)
    assert_equal [[PokeAccess::I18n.t(:pc_mode_normal), true]], SpeakCapture.log
  end

  test "a game that names its modes has the one it gives said, whatever the scene's flags" do
    PokeAccess::StorageModes.say(World.stub_scene(:@quickswap => true), :pc_mode_multi)
    assert_equal [[PokeAccess::I18n.t(:pc_mode_multi), true]], SpeakCapture.log
  end

  private

  # Drops what the dialogue reader carries over from earlier lines (its half-second copy window, a promised head or
  # tail, the repeat key's line), so the line under test is said as it is.
  def forget_dialogue
    PokeAccess.take_head
    PokeAccess.take_tail
    [:@last_dialogue, :@last_say, :@last_say_t, :@last_led].each { |iv| PokeAccess.instance_variable_set(iv, nil) }
  end

  # The PC's box chooser on box current: pbChooseBox's rows handed to the gen-6 scene's command menu
  # (sevii/0148_PScreen_Storage.rb:2764-2806), which updates its list once on the first row, puts the cursor on the
  # current box, then runs a frame per key, :down moving a row.
  def choose_box(current, keys)
    scene = PokemonStorageScene.new
    scene.commands_loop = lambda do |_message, commands, index|
      win = Window_DrawableCommand.new(commands)
      win.update
      win.index = index
      ([nil] + keys).each do |k|
        Input.update
        win.index += 1 if k == :down
        win.update
      end
      win.index
    end
    boxes = ["Box 1 (0/30)", "Box 2 (3/30)", "Box 3 (5/30)", "Box 4 (30/30)"]
    scene.pbShowCommands("Deposit in which Box?", boxes, current)
  end

  # What had been spoken each time the game's own cname#meth ran within the block: a probe hooked innermost, next to
  # the game's method, and taken off after.
  def heard_by_game(cname, meth)
    heard = []
    chain = PokeAccess::Hooks.instance_variable_get(:@chains)["#{cname}##{meth}"]
    size = chain.length
    PokeAccess::Hooks.around_hook(cname, meth) { |_s, nxt, _a| heard.push(SpeakCapture.lines.dup); nxt.call }
    yield
    heard
  ensure
    chain.slice!(size..-1) if chain && size
  end
end
