# Sevii's Pokeblock kit screens (games/sevii/pokeblocks.rb), over a stand-in shaped as its PokeBlock (Contests #4
# PokéBlocks): the case's color grid, its level screens and the party to feed, and the condition screen. Their loop is
# left out: a test runs each frame's call (first_choice, second_choice_*, check_party_pokemon) and presses an arrow
# for the next one, which moves the cursor at its end, as the game reads the keys.

# A party member: what the condition screen paints of it and the contest stats its bars draw.
class PokeBlockMember
  attr_accessor :name, :species, :nature, :level, :gender, :cool, :beauty, :cute, :smart, :tough, :sheen

  def initialize(name, species, stats = {})
    @name = name
    @species = species
    @nature = stats[:nature] || 0
    @level = stats[:level] || 25
    @gender = stats[:gender]
    @cool = stats[:cool] || 0
    @beauty = stats[:beauty] || 0
    @cute = 0
    @smart = 0
    @tough = 0
    @sheen = stats[:sheen] || 0
  end

  def isMale?; @gender == 0; end
  def isFemale?; @gender == 1; end
end

# The trainer the screens take the party from.
PokeBlockTrainer = Struct.new(:name, :party)

# The kit's scene: @process the case's phase, @firstchoice the grid's color, @secondnormal and @secondgold the level
# screens' choice, @position the party's slot, and the grid's flavor squares in @sprites.
class PokeBlock
  RANDOM = %w[spicy2 dry2 sweet2 bitter2 sour2]
  OWN = %w[spicy1 dry1 sweet1 bitter1 sour1]
  # The squares first_choice lights for each color: the RANDOM box's for gold, black, gray and white.
  SQUARES = [RANDOM, RANDOM, RANDOM, RANDOM, %w[spicy1], %w[dry1], %w[sweet1], %w[bitter1], %w[sour1],
             %w[dry1 spicy1], %w[dry1 sweet1], %w[bitter1 sweet1], %w[bitter1 sour1], %w[sour1 spicy1]]
  TITLES = ["GOLD", "BLACK", "GRAY", "WHITE", "RED", "BLUE", "PINK", "GREEN", "YELLOW", "PURPLE", "INDIGO", "BROWN",
            "LITE BLUE", "OLIVE"]
  # COLOR_SAVOUR: the game variable counting each color's blocks of each level (gold's of each column and level).
  SAVOUR = [[401, 402, 403, 404], [405], [406, 407], [408, 409], [410, 411], [412, 413], [414, 415], [416, 417],
            [418, 419], [420, 421], [422, 423], [424, 425], [426, 427], [428, 429]]
  SPECIES = { 1 => "BULBASAUR", 25 => "PIKACHU" }
  NATURES = { 0 => "HARDY", 3 => "ADAMANT" }
  Square = Struct.new(:visible)

  # Where the next frame's arrow takes the cursor, and whether it presses C: each taken once, at the frame's end.
  attr_writer :arrow, :confirm

  def initialize
    @sprites = {}
    @process = 0
    @firstchoice = 0
    @secondnormal = 0
    @secondgold = 0
    @position = 0
  end

  def pbStart_item; draw_scene_item; end
  def pbStart_pokemon; draw_scene_pokemon; end

  def draw_scene_item
    (RANDOM + OWN).each { |k| @sprites[k] = Square.new(false) }
  end

  # Lights the squares of the color it begins on, then moves the cursor, or takes the color with C, hiding them.
  def first_choice
    (RANDOM + OWN).each { |k| @sprites[k].visible = SQUARES[@firstchoice].include?(k) }
    @firstchoice = take_arrow(@firstchoice)
    return unless take_confirm
    (RANDOM + OWN).each { |k| @sprites[k].visible = false }
    @process = 1
  end

  def draw_title
    pbDrawTextPositions(nil, [[_INTL("{1}", TITLES[@firstchoice]), 326, 8, 2, nil, nil]])
  end

  def draw_quantity
    j = @firstchoice == 0 ? @secondgold : (@firstchoice == 1 ? 0 : @secondnormal)
    pbDrawTextPositions(nil, [[_INTL("{1}", $game_variables[SAVOUR[@firstchoice][j]]), 494, 314, 1, nil, nil]])
  end

  # An arrow moves the level and repaints its quantity.
  def second_choice_normal
    to = take_arrow(@secondnormal)
    return if to == @secondnormal
    @secondnormal = to
    draw_quantity
  end

  # An arrow moves gold's cell and repaints its quantity.
  def second_choice_gold
    to = take_arrow(@secondgold)
    return if to == @secondgold
    @secondgold = to
    draw_quantity
  end

  def draw_scene_pokemon
    @sprites["scene_pokemon"] = Square.new(false)
  end

  # Paints the member under the cursor, then moves the cursor.
  def check_party_pokemon
    information_pokemon
    @position = take_arrow(@position)
  end

  def disappear_scene
    @sprites["scene_pokemon"].visible = false
  end

  # The nature under its label, then the species, name, level and sex sign on the top panel; nothing on CANCEL.
  def information_pokemon
    return if @position == $Trainer.party.size
    pk = $Trainer.party[@position]
    pbDrawTextPositions(nil, [[_INTL("{1}", NATURES[pk.nature]), 3, 317, 0, nil, nil]])
    rows = [[_INTL("{1}", pk.name), 205, 39, 0, nil, nil], [_INTL("{1}", SPECIES[pk.species]), 205, 7, 0, nil, nil],
            [_INTL("Level: {1}", pk.level), 205, 71, 0, nil, nil]]
    rows.push([_INTL("♂"), 315, 71, 0, nil, nil]) if pk.isMale?
    rows.push([_INTL("♀"), 315, 71, 0, nil, nil]) if pk.isFemale?
    pbDrawTextPositions(nil, rows)
  end

  # Feeds the chosen block to the member under the cursor: refused at full sheen, else its coolness and then its sheen
  # rise around the game's message, and the count drops and is repainted.
  def increase_condition
    pk = $Trainer.party[@position]
    if pk.sheen >= 255
      Kernel.pbMessage(_INTL("{1} can't eat any more PokéBlocks.", pk.name))
    else
      pk.cool += 10
      Kernel.pbMessage(_INTL("{1} happily ate a {2} PokéBlock!", pk.name, "Red"))
      pk.sheen += 8.5
      $game_variables[SAVOUR[@firstchoice][@secondnormal]] -= 1
      draw_quantity
    end
    @process = 7
  end

  def pbEndScene
    @sprites = {}
  end

  private

  def take_arrow(current)
    to = @arrow.nil? ? current : @arrow
    @arrow = nil
    to
  end

  def take_confirm
    pressed = @confirm ? true : false
    @confirm = nil
    pressed
  end
end

class SeviiPokeblocksTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "pokeblocks.rb")

  def setup
    super
    @trainer = $Trainer
  end

  def teardown
    $Trainer = @trainer
    super
  end

  test "the case says its name and keys as it opens, cutting in, then the grid's first color, queued" do
    open_case
    assert_equal [[case_line, true], ["GOLD, #{t(:sv_pb_random)}", false]], SpeakCapture.log
  end

  test "each color the grid's cursor reaches is said with the flavors its squares mark, cutting in" do
    s = open_case
    SpeakCapture.clear
    grid_to(s, 4)
    grid_to(s, 9)
    grid_to(s, 3)
    assert_equal [["RED, #{flavors(:bdx_fl_spicy)}", true], ["PURPLE, #{flavors(:bdx_fl_spicy, :bdx_fl_dry)}", true],
                  ["WHITE, #{t(:sv_pb_random)}", true]], SpeakCapture.log
  end

  test "a move is said on the frame that shows the new color, not on the one whose arrow moved the cursor" do
    s = open_case
    SpeakCapture.clear
    s.arrow = 11
    s.first_choice
    assert_nothing_spoken
    s.first_choice
    s.first_choice
    assert_equal [["BROWN, #{flavors(:bdx_fl_sweet, :bdx_fl_bitter)}", true]], SpeakCapture.log
  end

  test "a color taken on the frame right after the arrow, its squares hidden, is not said without its flavors" do
    s = open_case
    SpeakCapture.clear
    s.arrow = 4
    s.first_choice
    s.confirm = true
    s.first_choice
    assert_nothing_spoken
  end

  test "a color's level screen opens with its name, level and quantity, cutting in, and says each level reached" do
    $game_variables[410] = 3
    s = open_case
    grid_to(s, 4)
    SpeakCapture.clear
    take_color(s)
    s.arrow = 1
    s.second_choice_normal
    s.arrow = 0
    s.second_choice_normal
    assert_equal [["RED, #{level(1)}, #{quantity(3)}", true], ["#{level(2)}, #{quantity(0)}", true],
                  ["#{level(1)}, #{quantity(3)}", true]], SpeakCapture.log
  end

  test "gold's level screen names the count of flavors of each cell's column, then its level" do
    [2, 0, 5, 1].each_with_index { |n, i| $game_variables[401 + i] = n }
    s = open_case
    SpeakCapture.clear
    take_color(s)
    [1, 3, 2].each do |cell|
      s.arrow = cell
      s.second_choice_gold
    end
    want = ["GOLD, #{gold(1, 1)}, #{quantity(2)}", "#{gold(1, 2)}, #{quantity(0)}", "#{gold(2, 2)}, #{quantity(1)}",
            "#{gold(2, 1)}, #{quantity(5)}"]
    assert_equal want, SpeakCapture.lines
  end

  test "black's screen, which has no level, says the color and its quantity" do
    $game_variables[405] = 4
    s = open_case
    grid_to(s, 1)
    SpeakCapture.clear
    take_color(s)
    assert_equal [["BLACK, #{quantity(4)}", true]], SpeakCapture.log
  end

  test "back on the grid from a level screen, its color is said again" do
    s = open_case
    grid_to(s, 4)
    take_color(s)
    SpeakCapture.clear
    s.instance_variable_set(:@process, 0)
    s.first_choice
    assert_equal [["RED, #{flavors(:bdx_fl_spicy)}", true]], SpeakCapture.log
  end

  test "the party to feed opens with the screen's name and keys, cutting in, then the member and its condition" do
    s = red_case
    SpeakCapture.clear
    to_party(s)
    assert_equal [["#{t(:sv_pb_condition)}. #{t(:sv_pb_feed_keys, keys)}", true], [pika_line, false]], SpeakCapture.log
  end

  test "each member the cursor reaches is said with its condition, cutting in, and past the party its cancel" do
    s = red_case
    to_party(s)
    SpeakCapture.clear
    party_to(s, 1)
    party_to(s, 2)
    assert_equal [[bulba_line, true], [t(:pc_cancel), true]], SpeakCapture.log
  end

  test "feeding says the bars it raised as they stand now, queued, and nothing of the quantity it repaints" do
    s = red_case
    to_party(s)
    SpeakCapture.clear
    feed_block(s)
    s.check_party_pokemon
    rose = "#{t(:cnd_cool)} 20, #{t(:cnd_sheen)} 17"
    assert_equal [[t(:pbk_rose, :list => rose), false]], SpeakCapture.log
  end

  test "after a feeding, Ctrl+T says the member with its bars as fed, though its line is not said again" do
    s = red_case
    to_party(s)
    refute_includes PokeAccess::Info.row_text, "#{t(:cnd_cool)} 20"
    feed_block(s)
    s.check_party_pokemon
    assert_includes PokeAccess::Info.row_text, "#{t(:cnd_cool)} 20"
  end

  test "a sheen fed past its full bar, which the game leaves uncapped, is said full" do
    s = red_case(250)
    to_party(s)
    SpeakCapture.clear
    feed_block(s)
    rose = "#{t(:cnd_cool)} 20, #{t(:cnd_sheen)} 255 #{t(:cnd_max)}"
    assert_equal [[t(:pbk_rose, :list => rose), false]], SpeakCapture.log
  end

  test "a block the member cannot eat any more raises nothing and says nothing" do
    s = red_case(255)
    to_party(s)
    SpeakCapture.clear
    feed_block(s)
    assert_nothing_spoken
  end

  test "leaving the party says the color's level screen again, with the quantity left" do
    s = red_case
    to_party(s)
    feed_block(s)
    SpeakCapture.clear
    s.disappear_scene
    assert_equal [["RED, #{level(1)}, #{quantity(2)}", true]], SpeakCapture.log
  end

  test "the condition screen opens with its name and its key, cutting in, then the first member, queued" do
    party(pika, bulba)
    s = condition_screen
    assert_equal [["#{t(:sv_pb_condition)}. #{t(:sv_pb_condition_keys, keys)}", true], [pika_line, false]],
                 SpeakCapture.log
    party_to(s, 1)
    assert_equal [bulba_line, true], SpeakCapture.log.last
  end

  test "at brief the case leaves out its keys and flavors, and a member keeps its name and its bars" do
    PokeAccess::Config.verbosity = :brief
    s = red_case
    to_party(s)
    pika_bars = bars(10, 0, 0, 0, 0, 8)
    assert_equal [[t(:sv_pb_case), true], ["GOLD", false], ["RED", true], ["RED, #{level(1)}, #{quantity(3)}", true],
                  [t(:sv_pb_condition), true], ["Pika, #{pika_bars}", false]], SpeakCapture.log
  end

  test "the info key keeps the grid's color whole until the case closes" do
    PokeAccess::Config.verbosity = :brief
    s = open_case
    grid_to(s, 4)
    assert_equal ["RED", "RED, #{flavors(:bdx_fl_spicy)}"], [SpeakCapture.last, PokeAccess::Info.info_text]
    s.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "Ctrl+T says the member's line whole whatever the verbosity" do
    PokeAccess::Config.verbosity = :brief
    s = red_case
    to_party(s)
    assert_equal pika_line, PokeAccess::Info.row_text
  end

  test "an empty party's condition screen says only its cancel" do
    party
    condition_screen
    assert_equal [["#{t(:sv_pb_condition)}. #{t(:sv_pb_condition_keys, keys)}", true], [t(:pc_cancel), false]],
                 SpeakCapture.log
  end

  test "a scene with nothing drawn and no trainer raises nothing: a color alone, the cancel, no feeding" do
    self.class.bind
    $Trainer = nil
    bare = Object.new
    reader = PokeAccess::SeviiPokeblocks
    reader.grid(bare, 4)
    [99, -1, nil].each { |idx| reader.grid(bare, idx) }
    reader.member(bare, [])
    assert_equal :fed, reader.feed(bare) { :fed }
    assert_equal [["RED", false], [t(:pc_cancel), true]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The keys the hints name by default.
  def keys
    { :ok => t(:key_enter), :back => t(:key_escape) }
  end

  def case_line
    "#{t(:sv_pb_case)}. #{t(:sv_pb_case_keys, keys)}"
  end

  def flavors(*names)
    t(:pbk_flavors, :list => names.map { |k| t(k) }.join(", "))
  end

  def level(n)
    t(:dbk_level, :n => n)
  end

  def quantity(n)
    t(:sv_pb_quantity, :n => n)
  end

  # Gold's cell in the column of count flavors, at level n.
  def gold(count, n)
    "#{t(:sv_pb_flavor_count, :n => count)}, #{level(n)}"
  end

  # The six bars as the condition list says them, top to bottom; 255 marked full.
  def bars(*values)
    words = [:cnd_cool, :cnd_beauty, :cnd_cute, :cnd_smart, :cnd_tough, :cnd_sheen].zip(values).map do |k, v|
      v >= 255 ? "#{t(k)} #{v} #{t(:cnd_max)}" : "#{t(k)} #{v}"
    end
    t(:pbk_conditions, :list => words.join(", "))
  end

  # A nicknamed Pikachu: male, Adamant, cool 10 and sheen 8.5 unless told.
  def pika(sheen = 8.5)
    PokeBlockMember.new("Pika", 25, :nature => 3, :level => 30, :gender => 0, :cool => 10, :sheen => sheen)
  end

  # A Bulbasaur under its species' own name: female, Hardy, its beauty full.
  def bulba
    PokeBlockMember.new("Especie1", 1, :nature => 0, :level => 12, :gender => 1, :beauty => 255)
  end

  def pika_line
    "Pika ♂, PIKACHU, Level: 30, #{t(:sm_nature, :n => 'ADAMANT')}, #{bars(10, 0, 0, 0, 0, 8)}, #{list_place(1, 2)}"
  end

  def bulba_line
    "Especie1 ♀, Level: 12, #{t(:sm_nature, :n => 'HARDY')}, #{bars(0, 255, 0, 0, 0, 0)}, #{list_place(2, 2)}"
  end

  def party(*members)
    $Trainer = PokeBlockTrainer.new("Ayoub", members)
  end

  # The case opened on its grid, its first frame run.
  def open_case
    self.class.bind
    s = PokeBlock.new
    s.pbStart_item
    s.first_choice
    s
  end

  # The pokemon condition screen opened, its first frame run.
  def condition_screen
    self.class.bind
    s = PokeBlock.new
    s.pbStart_pokemon
    s.check_party_pokemon
    s
  end

  # The case on red's first level, three blocks of it, Pika (sheen as given) and Bulbasaur in the party.
  def red_case(sheen = 8.5)
    party(pika(sheen), bulba)
    $game_variables[410] = 3
    s = open_case
    grid_to(s, 4)
    take_color(s)
    s
  end

  # Moves the grid's cursor to idx and runs the frame that shows it.
  def grid_to(s, idx)
    s.arrow = idx
    s.first_choice
    s.first_choice
  end

  # C on the grid, then the frame that draws the color's name and quantity and opens its level screen.
  def take_color(s)
    s.confirm = true
    s.first_choice
    s.draw_title
    s.draw_quantity
    fc = s.instance_variable_get(:@firstchoice)
    s.instance_variable_set(:@process, fc == 0 ? 3 : (fc == 1 ? 4 : 2))
  end

  # C on a level screen with a block and a party: the frame that draws the party, then its first one.
  def to_party(s)
    s.instance_variable_set(:@process, 6)
    s.draw_scene_pokemon
    s.instance_variable_set(:@process, 7)
    s.check_party_pokemon
  end

  # Moves the party's cursor to idx and runs the frame that paints it.
  def party_to(s, idx)
    s.arrow = idx
    s.check_party_pokemon
    s.check_party_pokemon
  end

  # C on a member: the frame that feeds it, back to the party after.
  def feed_block(s)
    s.instance_variable_set(:@process, 8)
    s.increase_condition
  end

  # Evaluates pokeblocks.rb once, the profile list put back as it was.
  def self.bind
    return if @bound
    @bound = true
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
