# Rejuvenation's quick summary (games/rejuvenation/quick_summary.rb): Z on a party member opens a panel of formatted
# rows, said as painted with its type icons worded, each move as the summary says moves and the gauge under the last
# label in the game's own words; cutting in as it opens, queued behind the member's line when a cursor move redraws it,
# and kept whole on the info key until it closes, when the key goes back to the member. The stand-in holds
# PokemonScreen_Scene's name only while the file is evaluated, so the hooks bind to it and the other tests keep the stub
# party scene.
Harness.load_common("rv_common")

unless defined?(PokeAccess::RejuvInspect)
  inspect_path = File.join(Harness::ROOT, "games", "rejuvenation", "inspect.rb")
  inspect_source = Harness.source(inspect_path)
  inspect_module = inspect_source[0, inspect_source.index("\n", inspect_source.index(/^end\s*$/)) + 1]
  eval(inspect_module, TOPLEVEL_BINDING, inspect_path)
end

# The party scene as Rejuvenation paints the panel (Party.rb:1038-1121): a drawFormattedTextEx row each, its colour
# tags and icons in the text, the gauge a bar; @qsviewport stands for the panel while it is open.
class RejuvQuickSummaryScene
  BLUE = "<c3=7FC0F8,1F3870>"
  GRAY = "<c3=A0A0A0,505050>"
  Slot = Struct.new(:pokemon)

  def initialize(party)
    @activecmd = 0
    @sprites = {}
    party.each_with_index { |pk, i| @sprites["pokemon#{i}"] = Slot.new(pk) }
  end

  # Moves the cursor to a member, as pbChoosePokemon does before redrawing an open panel.
  def select(i); @activecmd = i; end

  def showQuickSummary
    disposeQuickSummary
    rows(@sprites["pokemon#{@activecmd}"].pokemon).each_with_index do |text, i|
      drawFormattedTextEx(nil, 12, 8 + 32 * i, 280, text, nil, nil, 32)
    end
    @qsviewport = :panel
    :shown
  end

  def disposeQuickSummary; @qsviewport = nil; end
  def showingQuickSummary?; !@qsviewport.nil?; end

  # The panel's rows for a member, coloured and aligned as the game's map! leaves them.
  def rows(pk)
    texts = ["Type: " + pk.types.map { |t| "<icon=type#{t}>" }.join(" "), "Item: " + (pk.item || GRAY + "None"),
             "Ability: " + pk.ability, "Moves:"]
    4.times do |i|
      m = pk.moves[i]
      texts.push(m ? "<icon=minitype#{m[1]}> #{m[0]} <r>#{GRAY}#{m[2]}/#{m[3]}" : GRAY + " --")
    end
    texts += ["Nature: " + pk.nature, "EVs: 510 / 510", BLUE + (pk.shadow ? "Heart" : "EXP") + ": "]
    texts.each_with_index.map do |t, i|
      (4..7).include?(i) || i == texts.length - 1 ? t : BLUE + t.gsub(": ", ":</c3> <r>")
    end
  end
end

quick_summary = File.join(Harness::ROOT, "games", "rejuvenation", "quick_summary.rb")
party_stub = Object.const_defined?(:PokemonScreen_Scene) ? Object.send(:remove_const, :PokemonScreen_Scene) : nil
Object.const_set(:PokemonScreen_Scene, RejuvQuickSummaryScene)
profiles = PokeAccess::Game.profiles.dup
begin
  eval(Harness.source(quick_summary), TOPLEVEL_BINDING, quick_summary)
ensure
  Object.send(:remove_const, :PokemonScreen_Scene)
  Object.const_set(:PokemonScreen_Scene, party_stub) if party_stub
  PokeAccess::Game.profiles.replace(profiles)
end

class RejuvenationQuickSummaryTest < PokeAccessTest
  TYPES = { :FIRE => "Fire", :FLYING => "Flying", :NORMAL => "Normal", :GHOST => "Ghost", :QMARKS => "???" }

  # A party member as the panel reads it, its gauge text depending on whether the game's reader asked for it; its name,
  # level and HP are the party's glance on the info key.
  Mon = Struct.new(:types, :item, :ability, :moves, :nature, :shadow, :name) do
    def isShadow?; shadow; end
    def level; 50; end
    def hp; 120; end
    def totalhp; 150; end
    def getEXPBarText(tts: false); tts ? "45%, Next level: 1234" : "1234"; end
    def getHeartGaugeBarTextTTS; "3 bars remaining, 60% left"; end
  end

  test "Z opens the panel: its rows as painted, types worded, moves as the summary says them, the gauge, cutting in" do
    assert_equal [[panel(charizard_moves), true]], said { |scene| scene.showQuickSummary }
  end

  test "a cursor move redraws the open panel for the new member, queued behind the member's line" do
    log = said do |scene|
      scene.showQuickSummary
      SpeakCapture.clear
      scene.select(1)
      scene.showQuickSummary
    end
    moves = "#{move('Tackle', 'Normal', 35, 35)}. #{move('Shadow Ball', 'Ghost', 15, 15)}"
    want = "Type: Normal. Item: None. Ability: Run Away. Moves: #{moves}. Nature: Adamant. EVs: 510 / 510. " \
           "EXP: 45%, Next level: 1234"
    assert_equal [[want, false]], log
  end

  test "an empty move slot is left out, and an item the member does not hold is said as the panel paints it" do
    log = said(1) { |scene| scene.showQuickSummary }
    assert_match(/Item: None\. Ability: Run Away\. Moves: Tackle\. .*Shadow Ball\. .*Nature: Adamant/, log[0][0])
    refute_match(/--/, log[0][0])
  end

  test "a shadow Pokemon's heart gauge is said in the game's words under its label" do
    log = said(2) { |scene| scene.showQuickSummary }
    assert_match(/Heart: 3 bars remaining, 60% left\z/, log[0][0])
  end

  test "a nature the panel hides behind question marks is said as unknown, and so is a move's unknown type" do
    log = said(2) { |scene| scene.showQuickSummary }
    assert_match(/Nature: #{t(:pdx_unknown_short)}\./, log[0][0])
    assert_match(/Curse\. #{t(:mv_type, :t => t(:pdx_unknown_short))}\. /, log[0][0])
  end

  test "at brief verbosity the moves leave out their types, and the info key keeps the panel whole" do
    PokeAccess::Config.verbosity = :brief
    log = said { |scene| scene.showQuickSummary }
    brief = "#{move('Flamethrower', nil, 15, 15)}. #{move('Air Slash', nil, 10, 15)}"
    assert_equal panel(brief), log[0][0]
    assert_equal panel(charizard_moves), PokeAccess::Info.info_text
  end

  test "the info key says the panel while Ctrl+T keeps the member's row the party published" do
    PokeAccess::Info.set_info(:pokemon, nil, "Charizard, nivel 50")
    said { |scene| scene.showQuickSummary }
    assert_equal [panel(charizard_moves), "Charizard, nivel 50"],
                 [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "closing the panel gives the info key back to the member, its row kept for Ctrl+T, and only once it is open" do
    PokeAccess::Info.set_info(:pokemon, nil, "Charizard, nivel 50")
    kept = said_with_scene do |scene|
      scene.showQuickSummary
      scene.disposeQuickSummary
      closed = [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
      PokeAccess::Info.set_info(:text, "Ayuda")
      scene.disposeQuickSummary
      [closed, PokeAccess::Info.pokemon_info(scene.instance_variable_get(:@sprites)["pokemon0"].pokemon),
       PokeAccess::Info.info_text]
    end
    assert_equal [[kept[1], "Charizard, nivel 50"], "Ayuda"], [kept[0], kept[2]]
    refute_nil kept[1]
  end

  test "a cursor move with the panel open keeps the new member's panel on the info key" do
    info = said_with_scene do |scene|
      scene.showQuickSummary
      scene.select(1)
      scene.showQuickSummary
      PokeAccess::Info.info_text
    end
    assert_match(/\AType: Normal\. Item: None\. Ability: Run Away\. /, info)
  end

  test "the panel opens as the game's would, and is said" do
    opened = said_with_scene { |scene| [scene.showQuickSummary, scene.showingQuickSummary?] }
    assert_equal [[:shown, true], 1], [opened, SpeakCapture.lines.length]
  end

  private

  # What was said while the block worked a party of three with the cursor on member index, the game's type names in.
  def said(index = 0)
    said_with_scene(index) { |scene| yield scene }
    SpeakCapture.log
  end

  # The block's value over a fresh party scene with the cursor on member index.
  def said_with_scene(index = 0)
    party = [Mon.new([:FIRE, :FLYING], "Charcoal", "Blaze",
                     [["Flamethrower", "FIRE", 15, 15], ["Air Slash", "FLYING", 10, 15]], "Adamant", false,
                     "Charizard"),
             Mon.new([:NORMAL], nil, "Run Away", [["Tackle", "NORMAL", 35, 35], ["Shadow Ball", "GHOST", 15, 15]],
                     "Adamant", false),
             Mon.new([:GHOST], "Charcoal", "Cursed Body",
                     [["Shadow Ball", "GHOST", 15, 15], ["Curse", "QMARKS", 10, 10]], "???", true)]
    scene = RejuvQuickSummaryScene.new(party)
    scene.select(index)
    GameFunctions.with(:getTypeName => lambda { |ty| TYPES[ty].to_s }) { yield scene }
  end

  # Charizard's two moves as the panel says them.
  def charizard_moves
    "#{move('Flamethrower', 'Fire', 15, 15)}. #{move('Air Slash', 'Flying', 10, 15)}"
  end

  # Charizard's panel with its moves said as given.
  def panel(moves)
    "Type: Fire, Flying. Item: Charcoal. Ability: Blaze. Moves: #{moves}. Nature: Adamant. EVs: 510 / 510. " \
      "EXP: 45%, Next level: 1234"
  end

  # One move as the summary's moves are said: name, its type where given, and its PP.
  def move(name, type, pp, tot)
    [name, (t(:mv_type, :t => type) if type), t(:mv_pp, :pp => pp, :tot => tot)].compact.join(". ")
  end

  # The Spanish text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end
end
