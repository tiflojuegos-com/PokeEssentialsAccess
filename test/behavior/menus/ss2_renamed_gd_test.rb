# Soulstones 2's renamed vanilla screens (games/soulstones2/renamed_screens.rb): the move relearner MoveRemember_Scene,
# read by core's move-list reader, and the trial's team picker Original_PokemonParty_Scene: help, messages, opening.

# The profile is bound twice, as two builds load it: first over the screens bare of every method it hooks, then over
# the stand-ins below (binding the bare ones last would reset the coverage the stand-ins' run records).
class MoveRemember_Scene; end
class Original_PokemonParty_Scene; end
eval(Harness.source(File.join(Harness::ROOT, "games/soulstones2/renamed_screens.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "games/soulstones2/renamed_screens.rb"))

# The relearner as the game builds it: the moves' names in a command window, then the focused move drawn by
# pbDrawMoveList, which its opening calls too; its questions and messages in its own window.
class MoveRemember_Scene
  def pbStartScene(pokemon, moves)
    @pokemon = pokemon
    @moves = moves
    @sprites = { "commands" => Window_CommandPokemon.new(moves.map { |m| GameData::Move.get(m).name }) }
    pbDrawMoveList
    :started
  end

  def pbDrawMoveList; :drawn; end
  def pbDisplay(msg, _brief = false); msg; end
  def pbConfirm(msg); msg; end
  def commands; @sprites["commands"]; end
end

# The trial's team picker: its opening sets the rule as the help line, then lays out the members and marks the first;
# its messages go through its own pbDisplay, pbDisplayConfirm and pbShowCommands.
class Original_PokemonParty_Scene
  def pbStartScene(party, starthelptext, _annotations = nil, _multiselect = false, _can_access_storage = false)
    @party = party
    @sprites = {}
    pbSetHelpText(starthelptext)
    party.each_with_index { |pk, i| @sprites["pokemon#{i}"] = PokemonPartyPanel.new(pk, i) }
    @sprites["pokemon0"].selected = true
    :started
  end

  def pbSetHelpText(text); text; end
  def pbDisplay(text); text; end
  def pbDisplayConfirm(text); text; end
  def pbShowCommands(helptext, _commands, _index = 0); helptext; end
  def panel(i); @sprites["pokemon#{i}"]; end
end

eval(Harness.source(File.join(Harness::ROOT, "games/soulstones2/renamed_screens.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "games/soulstones2/renamed_screens.rb"))

class Ss2RenamedGdTest < PokeAccessTest
  test "opening the relearner says its first move's detail, interrupting, and the opening keeps its own return" do
    opened = MoveRemember_Scene.new.pbStartScene(Poke.build(:name => "Chispa"), [1, 2])
    assert_equal [[detail(1), true]], SpeakCapture.log, "the first move"
    assert_equal :started, opened, "the opening's own return"
  end

  test "each redraw of the relearner's list says the move the cursor moved to" do
    scene = MoveRemember_Scene.new
    scene.pbStartScene(Poke.build(:name => "Chispa"), [1, 2])
    scene.commands.index = 1
    SpeakCapture.clear
    drawn = scene.pbDrawMoveList
    assert_equal [[detail(2), true]], SpeakCapture.log, "the second move"
    assert_equal :drawn, drawn, "the redraw's own return"
  end

  test "once open, the relearner's list is left to its own reader by the generic command reader" do
    scene = MoveRemember_Scene.new
    scene.pbStartScene(Poke.build(:name => "Chispa"), [1, 2])
    SpeakCapture.clear
    scene.commands.update
    assert_equal [], SpeakCapture.log
  end

  test "a question or a message either screen writes in its own window is said, queued" do
    relearner = MoveRemember_Scene.new
    party = Original_PokemonParty_Scene.new
    [[relearner, :pbConfirm, ["Teach Thunderbolt?"]], [relearner, :pbDisplay, ["Chispa learned Thunderbolt!"]],
     [party, :pbDisplay, ["No two Pokemon can have the same species."]],
     [party, :pbDisplayConfirm, ["Enter the trial with this team?"]],
     [party, :pbShowCommands, ["Do what with Chispa?", ["Summary", "Cancel"]]]].each do |scene, meth, args|
      SpeakCapture.clear
      scene.send(meth, *args)
      assert_equal [[args[0], false]], SpeakCapture.log, "#{scene.class}##{meth}"
    end
  end

  test "the trial's party says a new help line, queued, and the same one once" do
    scene = Original_PokemonParty_Scene.new
    scene.pbSetHelpText("Choose 3 Pokemon.")
    scene.pbSetHelpText("Choose 3 Pokemon.")
    assert_equal [["Choose 3 Pokemon.", false]], SpeakCapture.log
  end

  test "the trial's party opens with its rule, then its first member as core reads one, both queued" do
    first = Poke.build(:name => "Chispa")
    scene = Original_PokemonParty_Scene.new
    opened = scene.pbStartScene([first, Poke.build(:name => "Brasa")], "Choose 2 Pokemon.")
    assert_equal [["Choose 2 Pokemon.", false], [PokeAccess::UIV21.party_member(first), false]], SpeakCapture.log
    assert_equal :started, opened, "the opening's own return"
  end

  test "after the trial's party opens, a member the cursor moves to interrupts" do
    second = Poke.build(:name => "Brasa")
    scene = Original_PokemonParty_Scene.new
    scene.pbStartScene([Poke.build(:name => "Chispa"), second], "Choose 1 Pokemon.")
    SpeakCapture.clear
    scene.panel(0).selected = false
    scene.panel(1).selected = true
    assert_equal [[PokeAccess::UIV21.party_member(second), true]], SpeakCapture.log
  end

  test "bound on a build whose renamed screens lack the hooked methods, it files none as a missing hook" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\A(MoveRemember_Scene|Original_PokemonParty_Scene)#/)
  end

  private

  # The detail core's move-list reader says for the gamedata stub's move id at full verbosity: its name, type,
  # category, power, accuracy and description.
  def detail(id)
    ["Move#{id}", PokeAccess::I18n.t(:mv_type, :t => "TypeTYPE1"), PokeAccess::I18n.t(:cat_physical),
     PokeAccess::I18n.t(:mv_power, :p => 40), PokeAccess::I18n.t(:mv_acc, :a => 100), "desc#{id}"].join(". ")
  end
end
