# Soulstones 2's Encounter List cursor: the species each JumpUp/JumpDown lands on is said with its state and place, and
# the layer of type icons Action shows or hides is said as it flips, its types joining the species it covers.

# One type icon over a species of the list, shown or hidden.
class SS2EncTypeIcon
  attr_accessor :visible
  def initialize; @visible = false; end
end

# Soulstones 2's EncounterList_Scene, bound under the game's name: a page of species per encounter type (getEncData,
# counted, as the game's walks every species), the cursor's place in @idx, the page in @index and a type icon per
# place. pbEncounter plays its script of keys, the frame's poll before each and one as it closes, as the game's loop.
class SS2EncounterScene
  attr_accessor :script, :uncaught
  attr_reader :enc_calls

  def initialize(*pages)
    @pages = pages
    @index = 0
    @idx = 0
    @enc_calls = 0
    @script = []
    @uncaught = []
    @sprites = {}
    pages.map { |p| p.length }.max.to_i.times { |i| @sprites["type1_#{i}"] = SS2EncTypeIcon.new }
  end

  def getEncData
    @enc_calls += 1
    [@pages[@index], :Land]
  end

  def pbMoveDexSel; :moved; end

  def pbEncounter
    @script.each do |key|
      PokeAccess::Frame.run_pollers
      key.is_a?(Integer) ? move(key) : send(key)
    end
    PokeAccess::Frame.run_pollers
    :closed
  end

  # The type icon over place i.
  def icon(i); @sprites["type1_#{i}"]; end

  # JumpUp/JumpDown: the cursor put on place i (-1 for a JumpUp after Left, which puts it on the first place without a
  # redraw), then redrawn.
  def move(i)
    @idx = i
    pbMoveDexSel
  end

  # Action: every type icon flipped.
  def action
    @sprites.each_value { |s| s.visible = !s.visible }
  end

  # Right: the next page, its icons hidden, the cursor on its first species and redrawn.
  def right
    hide_types
    @index += 1
    @idx = 0
    pbMoveDexSel
  end

  # Left: the page before, its icons hidden, the cursor put back on its first species without a redraw.
  def left
    hide_types
    @index -= 1
    @idx = 0
  end

  # The redraw after a Demonic Eye battle: the icons over the species not caught hidden, the others as they were.
  def redraw
    @uncaught.each { |i| icon(i).visible = false }
  end

  # A frame with no key pressed.
  def wait; end

  def hide_types
    @sprites.each_value { |s| s.visible = false }
  end
end

class Ss2EncounterCursorGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "soulstones2", "encounter_cursor.rb")

  # Evaluates the profile's reader once per process with the stand-in under the game's class name, so its hooks bind
  # to the stand-in and stay there; the name and the profile list are put back after.
  def self.bind_reader
    prior = Object.const_defined?(:EncounterList_Scene) ? Object.send(:remove_const, :EncounterList_Scene) : nil
    profiles = PokeAccess::Game.profiles.dup
    Object.const_set(:EncounterList_Scene, SS2EncounterScene)
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    Object.send(:remove_const, :EncounterList_Scene) if Object.const_defined?(:EncounterList_Scene)
    Object.const_set(:EncounterList_Scene, prior) if prior
    PokeAccess::Game.profiles.replace(profiles)
  end
  bind_reader

  test "a move says the species it lands on with its state and place, interrupting" do
    list([:PIKACHU, :RATTATA]).move(1)
    assert_equal [["#{caught(:RATTATA)}, #{place(2, 2)}", true]], SpeakCapture.log
  end

  test "the move keeps the game's own return" do
    assert_equal :moved, list([:PIKACHU, :RATTATA]).move(1)
  end

  test "below medium verbosity the move says the name alone, without its state or place" do
    said = vb_levels { list([:PIKACHU, :RATTATA]).move(1); SpeakCapture.last }
    whole = "#{caught(:RATTATA)}, #{place(2, 2)}"
    assert_equal [species(:RATTATA), whole, whole], said
  end

  test "the info key keeps the species with its state at every verbosity" do
    kept = vb_levels { list([:PIKACHU, :RATTATA]).move(1); PokeAccess::Info.info_text }
    assert_equal [caught(:RATTATA)] * 3, kept
  end

  test "the same place again says nothing" do
    scene = list([:PIKACHU, :RATTATA])
    scene.move(1)
    SpeakCapture.clear
    scene.move(1)
    assert_nothing_spoken
  end

  test "the game's -1, a JumpUp after Left, is the page's last species" do
    list([:PIKACHU, :RATTATA]).move(-1)
    assert_equal [["#{caught(:RATTATA)}, #{place(2, 2)}", true]], SpeakCapture.log
  end

  test "turning the page says its first species, though the place is the one the cursor had" do
    scene = list([:PIKACHU, :RATTATA], [:PIDGEY, :ZUBAT])
    scene.move(0)
    SpeakCapture.clear
    scene.right
    assert_equal [["#{caught(:PIDGEY)}, #{place(1, 2)}", true]], SpeakCapture.log
  end

  test "a list opened after another reads its own species, not the other's page" do
    list([:PIKACHU, :RATTATA]).move(1)
    SpeakCapture.clear
    list([:PIDGEY, :ZUBAT]).move(1)
    assert_equal [["#{caught(:ZUBAT)}, #{place(2, 2)}", true]], SpeakCapture.log
  end

  test "a place with no species says nothing and leaves the info key alone" do
    failing = list([:PIKACHU])
    def failing.getEncData; raise "no encounter table"; end
    { "past the page's end" => [list([:PIKACHU]), 1], "on an empty page" => [list([]), 0],
      "on a page the game fails to give" => [failing, 0] }.each do |where, (scene, i)|
      scene.move(i)
      assert_nothing_spoken where
      assert_nil PokeAccess::Info.info_text, where
    end
  end

  test "over a species the type layer covers, the move says its types before its place" do
    scene = list([:PIKACHU, :RATTATA])
    scene.icon(1).visible = true
    scene.move(1)
    assert_equal [["#{caught(:RATTATA)}, #{stub_types}, #{place(2, 2)}", true]], SpeakCapture.log
  end

  test "the info key keeps the types the layer shows" do
    scene = list([:PIKACHU, :RATTATA])
    scene.icon(1).visible = true
    scene.move(1)
    assert_equal "#{caught(:RATTATA)}, #{stub_types}", PokeAccess::Info.info_text
  end

  test "each species is said with its own icon: one the layer leaves bare says no types" do
    scene = list([:PIKACHU, :RATTATA])
    scene.icon(0).visible = true
    scene.move(1)
    scene.move(0)
    assert_equal [["#{caught(:RATTATA)}, #{place(2, 2)}", true],
                  ["#{caught(:PIKACHU)}, #{stub_types}, #{place(1, 2)}", true]], SpeakCapture.log
  end

  test "an icon the game can no longer read counts as hidden" do
    scene = list([:PIKACHU, :RATTATA])
    disposed = scene.icon(1)
    def disposed.visible; raise "disposed sprite"; end
    scene.move(1)
    assert_equal [["#{caught(:RATTATA)}, #{place(2, 2)}", true]], SpeakCapture.log
  end

  test "over a species not caught, the layer's ?? icon is said as unknown types" do
    seen = "#{species(:RATTATA)} #{t(:dex_seen)}"
    owners = { "not caught" => lambda { |_sp| false }, "a Pokedex that fails" => lambda { |_sp| raise "no Pokedex" } }
    owners.each do |what, owned|
      SpeakCapture.clear
      with_owned(owned) do
        scene = list([:PIKACHU, :RATTATA])
        scene.icon(1).visible = true
        scene.move(1)
      end
      assert_equal [["#{seen}, #{unknown_types}, #{place(2, 2)}", true]], SpeakCapture.log, what
    end
  end

  test "with no Pokedex to read, the species and the types the layer shows over it are said as unknown" do
    without_pokedex do
      scene = list([:PIKACHU, :RATTATA])
      scene.icon(1).visible = true
      scene.move(1)
    end
    assert_equal [["#{t(:dex_unknown)}, #{unknown_types}, #{place(2, 2)}", true]], SpeakCapture.log
  end

  test "a caught species is said with every type the engine gives it, or as unknown with none" do
    { ["Planta", "Veneno"] => t(:pc_types, :t => "Planta Veneno"), [] => unknown_types }.each do |names, want|
      with_types(names) { assert_equal want, layer_types(:BULBASAUR), "types #{names.inspect}" }
    end
  end

  test "opening the list says nothing of the layer" do
    assert_equal [], loop_of([[:PIKACHU, :RATTATA]], [])
  end

  test "the list of a map with no encounters says nothing as its frames pass, asking the game once" do
    scene = list([:PIKACHU])
    asked = 0
    scene.define_singleton_method(:getEncData) { asked += 1; raise "no encounter table" }
    scene.script = [:wait, :wait]
    scene.pbEncounter
    assert_nothing_spoken
    assert_equal 1, asked, "getEncData asked over three frames"
  end

  test "Action showing the layer says so with the species the cursor is on and its types, interrupting" do
    assert_equal [["#{caught(:RATTATA)}, #{place(2, 2)}", true],
                  ["#{t(:ss2_enc_types_on)}. #{caught(:RATTATA)}, #{stub_types}", true]],
                 loop_of([[:PIKACHU, :RATTATA]], [1, :action])
  end

  test "Action hiding the layer says so, interrupting" do
    assert_equal [["#{t(:ss2_enc_types_on)}. #{caught(:PIKACHU)}, #{stub_types}", true], [t(:ss2_enc_types_off), true]],
                 loop_of([[:PIKACHU, :RATTATA]], [:action, :action])
  end

  test "a page turn that hides the layer says so queued, behind the new page's first species" do
    assert_equal [["#{t(:ss2_enc_types_on)}. #{caught(:PIKACHU)}, #{stub_types}", true],
                  ["#{caught(:PIDGEY)}, #{place(1, 2)}", true],
                  [t(:ss2_enc_types_off), false]],
                 loop_of([[:PIKACHU, :RATTATA], [:PIDGEY, :ZUBAT]], [:action, :right])
  end

  test "a page turn with the layer hidden says nothing of it, either way" do
    assert_equal [["#{caught(:PIDGEY)}, #{place(1, 2)}", true]],
                 loop_of([[:PIKACHU, :RATTATA], [:PIDGEY, :ZUBAT]], [:right, :left])
  end

  test "cursor moves say no switch of the layer, whether it covers every species or only the caught" do
    assert_equal [["#{t(:ss2_enc_types_on)}. #{caught(:PIKACHU)}, #{stub_types}", true],
                  ["#{caught(:RATTATA)}, #{stub_types}, #{place(2, 2)}", true]],
                 loop_of([[:PIKACHU, :RATTATA]], [:action, 1]), "every species covered"
    assert_equal [["#{t(:ss2_enc_types_on)}. #{caught(:PIKACHU)}, #{stub_types}", true],
                  ["#{caught(:RATTATA)}, #{place(2, 2)}", true],
                  ["#{caught(:PIKACHU)}, #{stub_types}, #{place(1, 2)}", true]],
                 loop_of([[:PIKACHU, :RATTATA]], [:action, :redraw, 1, 0], [1]), "the one not caught left bare"
  end

  test "the list's loop keeps its own return" do
    assert_equal :closed, list([:PIKACHU]).pbEncounter
  end

  test "the page's species are asked of the game once per page, not on every frame" do
    scene = list([:PIKACHU, :RATTATA], [:PIDGEY])
    scene.script = [:action, 1, :action, :right]
    scene.pbEncounter
    assert_equal 2, scene.enc_calls
  end

  test "closing the list stops watching the layer" do
    scene = list([:PIKACHU, :RATTATA])
    scene.pbEncounter
    flip_twice(scene)
    assert_nothing_spoken
  end

  test "a loop that fails stops watching the layer too, its failure going on to the game" do
    scene = list([:PIKACHU, :RATTATA])
    def scene.left; raise "lost page"; end
    scene.script = [:left]
    assert_raises(RuntimeError) { scene.pbEncounter }
    flip_twice(scene)
    assert_nothing_spoken
  end

  private

  # A list of these pages of species, the cursor on the first page's first place.
  def list(*pages)
    SS2EncounterScene.new(*pages)
  end

  # What a list of these pages says through its loop as the script's keys play; uncaught are the places the redraw
  # after a Demonic Eye battle leaves bare.
  def loop_of(pages, script, uncaught = [])
    scene = list(*pages)
    scene.script = script
    scene.uncaught = uncaught
    SpeakCapture.clear
    scene.pbEncounter
    SpeakCapture.log.dup
  end

  # Action twice on a list, the frame's poll after each.
  def flip_twice(scene)
    SpeakCapture.clear
    2.times do
      scene.action
      PokeAccess::Frame.run_pollers
    end
  end

  # The types the layer paints over a species, as said.
  def layer_types(sp)
    PokeAccess::SS2EncounterTypes.types(sp)
  end

  # The stub engine's name for a species.
  def species(sp)
    "Species#{sp}"
  end

  # A caught species as the list says it: its name and its state.
  def caught(sp)
    "#{species(sp)} #{t(:dex_caught)}"
  end

  # The stub engine's one type, as the layer says it.
  def stub_types
    t(:pc_types, :t => "TypeTYPE1")
  end

  # The ?? icon, as the layer says it.
  def unknown_types
    t(:pc_types, :t => t(:pdx_unknown_short))
  end

  def place(i, n)
    t(:list_pos, :i => i, :n => n)
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block with the Pokedex answering owned? as the lambda does, the stub's own put back after.
  def with_owned(answer)
    dex = $player.pokedex
    dex.define_singleton_method(:owned?) { |sp| answer.call(sp) }
    yield
  ensure
    dex.singleton_class.send(:remove_method, :owned?)
  end

  # Runs the block with the player's Pokedex out of the engine's reach, the stub's own put back after.
  def without_pokedex
    $player.define_singleton_method(:pokedex) { raise "no Pokedex" }
    yield
  ensure
    $player.singleton_class.send(:remove_method, :pokedex)
  end

  # Runs the block with the engine giving these type names for every species.
  def with_types(names)
    typed = Object.new
    typed.define_singleton_method(:species_types) { |_sp| names }
    Harness.with_provider(typed, 99) { yield }
  end
end
