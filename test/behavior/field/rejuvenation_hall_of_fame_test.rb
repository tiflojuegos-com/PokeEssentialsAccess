# Rejuvenation's Hall of Fame PC (games/rejuvenation/hall_of_fame.rb, over core's reader): C on a member reads the
# first page of its infobox, each C the next page of the same member, laid out as the eye reads it, its type icons
# worded and each move's type after its name; a selected member is read as the PC viewer reads, interrupting, the
# record's header once per record and the member's place after; B ends the selection, and its repaint says the header
# as a browsed record is. The page on show is kept on the info key while the member is selected. The stand-in holds
# HallOfFameScene's name only while the file is evaluated, so its hooks bind to it and the other tests keep the stub
# scene; the profile's overrides of core's reader are kept aside for these tests alone.
Harness.load_common("rv_common")

unless defined?(PokeAccess::RejuvInspect)
  inspect_path = File.join(Harness::ROOT, "games", "rejuvenation", "inspect.rb")
  inspect_source = Harness.source(inspect_path)
  inspect_module = inspect_source[0, inspect_source.index("\n", inspect_source.index(/^end\s*$/)) + 1]
  eval(inspect_module, TOPLEVEL_BINDING, inspect_path)
end

# Rejuvenation's Hall of Fame as far as the PC shows it (HallOfFame.rb:99-132, 368-477, 513-562): the record's header,
# then, with a member selected, the infobox page @infobox picks, painted where the game paints it, each move's type
# icon drawn as a picture before the page's texts.
class RejuvHallScene
  Member = Struct.new(:name, :level, :types, :item, :nature, :ability, :moves, :evs, :ivs, :species, :form, :egg) do
    def isEgg?; egg ? true : false; end
  end

  def initialize(team, number)
    @hallEntry = team
    @number = number
    @battlerIndex = 0
    @infobox = 0
    @selected = false
  end

  def pbStartSceneEntry; end

  # C with no member selected: the member under the cursor is selected.
  def select
    @selected = true
    pbUpdatePC
  end

  # B with a member selected: the selection ends, the member repainted under the header alone.
  def end_selection
    @selected = false
    pbUpdatePC
  end

  # C on a selected member: the next page.
  def turn_page
    @infobox = (@infobox + 1) % 3
    writePokemonData(@hallEntry[@battlerIndex])
  end

  # L or R: another record, the selection kept, the cursor on its member at the same place.
  def other_record(team, number)
    @hallEntry = team
    @number = number
    @battlerIndex = [@battlerIndex, team.size - 1].min
    writePokemonData(@hallEntry[@battlerIndex])
  end

  def pbUpdatePC(move = 0)
    @battlerIndex = (@battlerIndex + move) % @hallEntry.size
    writePokemonData(@hallEntry[@battlerIndex])
  end

  def writePokemonData(pokemon, hallNumber = nil)
    hallNumber ||= @number
    pbDrawTextPositions(nil, [["Hall of Fame No.  #{hallNumber}", 256, 0, :center]]) if hallNumber > -1
    drawInfobox(nil, pokemon) if @selected && !pokemon.isEgg?
    :written
  end

  def drawInfobox(overlay, pokemon)
    case @infobox
    when 0 then drawInfoboxOne(overlay, pokemon)
    when 1 then drawInfoboxTwo(overlay, pokemon)
    when 2 then drawInfoboxThree(overlay, pokemon)
    end
    :page
  end

  def drawInfoboxOne(_overlay, pk)
    drawFormattedTextEx(nil, 364, 308, 132, "<r>" + pk.types.map { |t| "<icon=type#{t}>" }.join(" "))
    pbDrawTextPositions(nil, [["#{pk.name} (Lv. #{pk.level}, ♂)", 20, 308, :left], [pk.item, 20, 340, :left],
                              [pk.nature, 256, 340, :center], [pk.ability, 492, 340, :right]])
  end

  def drawInfoboxTwo(overlay, pk)
    rows = [["Moves:", 20, 324, :left]]
    pk.moves.each_with_index do |m, i|
      x = i.even? ? 132 : 332
      y = i < 2 ? 308 : 340
      rows.push([m[0], x, y, :left])
      drawMoveTypeIcon(overlay, m[1], x, y)
    end
    pbDrawTextPositions(nil, rows)
  end

  def drawMoveTypeIcon(_overlay, _movetype, _xpos, _ypos); end

  def drawInfoboxThree(_overlay, pk)
    pbDrawTextPositions(nil, [["EV: #{pk.evs}", 256, 308, :center], ["IV: #{pk.ivs}", 256, 340, :center]])
  end
end

PokeAccess::HallOfFame.bind("RejuvHallScene")

class RejuvenationHallOfFameTest < PokeAccessTest
  READERS = [:viewer?, :split_header, :say_panel]
  TYPES = { :FIRE => "Fire", :FLYING => "Flying", :WATER => "Water", :GROUND => "Ground", :QMARKS => "???" }

  class << self
    # The profile's versions of core's panel readers, kept aside by load_profile.
    attr_reader :readers
  end

  # Evaluates the profile file once, as boot does, over the stand-in. Its versions of core's readers are kept aside
  # and core's put back, with the lists of profiles and overrides, so the other tests of the process keep core's;
  # with_profile puts the profile's in for a test.
  def self.load_profile
    meta = PokeAccess::HallOfFame.singleton_class
    core = READERS.map { |m| [m, meta.instance_method(m)] }
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    stub = Object.const_defined?(:HallOfFameScene) ? Object.send(:remove_const, :HallOfFameScene) : nil
    Object.const_set(:HallOfFameScene, RejuvHallScene)
    path = File.join(Harness::ROOT, "games", "rejuvenation", "hall_of_fame.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @readers = READERS.map { |m| [m, meta.instance_method(m)] }
  ensure
    Object.send(:remove_const, :HallOfFameScene)
    Object.const_set(:HallOfFameScene, stub) if stub
    core.each { |m, um| meta.send(:define_method, m, um) }
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end
  load_profile

  test "C on a member reads its first page, cutting in, the record's header said once before and the place after" do
    log = with_profile do |scene|
      scene.pbUpdatePC
      scene.select
    end
    assert_equal [["Hall of Fame No. 5", false], ["Charizard (Lv. 50, ♂), Fire, Flying. Charcoal, Adamant, Blaze, " \
                                                  "#{place(1)}", true]], log,
                 "with no member selected, the record as core reads it, queued"
  end

  test "each C reads the next page of the same member, without the header again, each move's type after its name" do
    log = with_profile do |scene|
      scene.select
      SpeakCapture.clear
      scene.turn_page
      scene.turn_page
    end
    assert_equal [["#{charizard_moves}, #{place(1)}", true],
                  ["EV: 252 HP, 0 Atk, 0 Def, 252 SpA, 4 SpD, 0 Spe. IV: 31 HP, 31 Atk, 31 Def, 31 SpA, 31 SpD, " \
                   "31 Spe, #{place(1)}", true]], log
  end

  test "turning back to the first page reads it again" do
    log = with_profile do |scene|
      scene.select
      SpeakCapture.clear
      3.times { scene.turn_page }
    end
    assert_equal ["Charizard (Lv. 50, ♂), Fire, Flying. Charcoal, Adamant, Blaze, #{place(1)}", true], log[2]
  end

  test "a redraw of the page on show, as a form change makes, reads it again" do
    log = with_profile do |scene|
      scene.select
      scene.pbUpdatePC
    end
    assert_equal 2, log.length
    assert_equal log[0][0], log[1][0]
  end

  test "moving to another member reads that member on the page on show, a type the game hides as unknown" do
    log = with_profile do |scene|
      scene.select
      scene.turn_page
      SpeakCapture.clear
      scene.pbUpdatePC(1)
    end
    moves = "Moves: Water Gun, #{type('Water')}, Curse, #{type(t(:pdx_unknown_short))}"
    assert_equal [["#{moves}, #{place(2)}", true]], log
  end

  test "B ends the selection, its repaint saying the record's header as a browsed record is, queued" do
    log = with_profile do |scene|
      scene.pbUpdatePC
      scene.select
      SpeakCapture.clear
      scene.end_selection
    end
    assert_equal [["Hall of Fame No. 5", false]], log
  end

  test "B cuts what is being said before the header, as the game's own reader does, and C cuts nothing" do
    stops = []
    meta = PokeAccess.singleton_class
    core = meta.instance_method(:stop_speech)
    meta.send(:define_method, :stop_speech) { stops.push(:stop); true }
    begin
      with_profile do |scene|
        scene.pbUpdatePC
        scene.select
        stops.push(:selected)
        scene.end_selection
      end
    ensure
      meta.send(:define_method, :stop_speech, core)
    end
    assert_equal [:selected, :stop], stops
  end

  test "selecting again after B leaves out the header the repaint just said" do
    log = with_profile do |scene|
      scene.pbUpdatePC
      scene.select
      scene.end_selection
      SpeakCapture.clear
      scene.select
    end
    assert_equal [["Charizard (Lv. 50, ♂), Fire, Flying. Charcoal, Adamant, Blaze, #{place(1)}", true]], log
  end

  test "another record reached with a member selected says its header before the page" do
    log = with_profile do |scene|
      scene.pbUpdatePC
      scene.select
      SpeakCapture.clear
      scene.other_record([team[1]], 4)
    end
    assert_equal [["Hall of Fame No. 4. Blastoise (Lv. 40, ♂), Water. No item, #{t(:pdx_unknown_short)}, Torrent, " \
                   "#{PokeAccess::Verbosity.position(1, 1)}", true]], log
  end

  test "a nature the game hides behind question marks is said as unknown" do
    log = with_profile do |scene|
      scene.pbUpdatePC(1)
      SpeakCapture.clear
      scene.select
    end
    assert_match(/Blastoise \(Lv\. 40, ♂\), Water\. No item, #{t(:pdx_unknown_short)}, Torrent, /, log[0][0])
  end

  test "an egg, which draws no page, is said as an egg with its place" do
    log = with_profile do |scene|
      scene.select
      SpeakCapture.clear
      scene.pbUpdatePC(2)
    end
    assert_equal [["#{t(:hof_egg)}, #{place(3)}", true]], log
  end

  test "an egg selected again after its selection ended is said again, as no page is drawn for it" do
    log = with_profile do |scene|
      scene.select
      scene.pbUpdatePC(2)
      scene.end_selection
      SpeakCapture.clear
      scene.select
    end
    assert_equal [["#{t(:hof_egg)}, #{place(3)}", true]], log
  end

  test "the page on show is kept on the info key and Ctrl+T while the member is selected, an egg as an egg" do
    kept = []
    with_profile do |scene|
      scene.select
      scene.turn_page
      kept.push([PokeAccess::Info.info_text, PokeAccess::Info.row_text])
      scene.pbUpdatePC(2)
      kept.push(PokeAccess::Info.info_text)
    end
    assert_equal [[charizard_moves, nil], t(:hof_egg)], kept, "Ctrl+T, with no row, says what the key says"
  end

  test "B ending the selection takes the page off the info key, before the PC can be left" do
    info = :unread
    with_profile do |scene|
      scene.select
      scene.end_selection
      info = PokeAccess::Info.info_text
    end
    assert_nil info
  end

  test "the infobox draws as the game's would, handing the panel its page as one row" do
    with_profile do |scene|
      PokeAccess::PaintCapture.arm(:hof_test)
      drawn = scene.drawInfobox(nil, scene.instance_variable_get(:@hallEntry)[0])
      assert_equal [:page, ["Charizard (Lv. 50, ♂), Fire, Flying. Charcoal, Adamant, Blaze"]],
                   [drawn, PokeAccess::PaintCapture.take(:hof_test)]
    end
  end

  private

  # What was said while the block worked a fresh PC viewer on record 5, its team of three; the profile's readers in
  # core's place and the game's type names in.
  def with_profile
    meta = PokeAccess::HallOfFame.singleton_class
    core = READERS.map { |m| [m, meta.instance_method(m)] }
    self.class.readers.each { |m, um| meta.send(:define_method, m, um) }
    GameFunctions.with(:getTypeName => lambda { |ty| TYPES[ty].to_s }) { yield RejuvHallScene.new(team, 5) }
    SpeakCapture.log
  ensure
    core.each { |m, um| meta.send(:define_method, m, um) }
  end

  # The record's team: Charizard with its four moves, Blastoise, whose nature and a move's type the game hides, and an
  # egg.
  def team
    member = RejuvHallScene::Member
    [member.new("Charizard", 50, [:FIRE, :FLYING], "Charcoal", "Adamant", "Blaze",
                [["Flamethrower", :FIRE], ["Air Slash", :FLYING], ["Earthquake", :GROUND], ["Roost", :FLYING]],
                "252 HP | 0 Atk | 0 Def | 252 SpA | 4 SpD | 0 Spe",
                "31 HP | 31 Atk | 31 Def | 31 SpA | 31 SpD | 31 Spe", 6, 0, false),
     member.new("Blastoise", 40, [:WATER], "No item", "???", "Torrent", [["Water Gun", :WATER], ["Curse", :QMARKS]],
                "0 HP", "0 HP", 9, 0, false),
     member.new("Egg", 1, [:WATER], "No item", "Hardy", "Torrent", [["Tackle", :NORMAL]], "0 HP", "0 HP", 7, 0, true)]
  end

  # Charizard's moves page as said: each move, then its type.
  def charizard_moves
    "Moves: Flamethrower, #{type('Fire')}, Air Slash, #{type('Flying')}, Earthquake, #{type('Ground')}, Roost, " \
      "#{type('Flying')}"
  end

  # A move's type as the page says it.
  def type(word)
    t(:mv_type, :t => word)
  end

  # A member's place in the team of three, as the viewer says it.
  def place(n)
    PokeAccess::Verbosity.position(n, 3)
  end

  # The Spanish text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end
end
