# Tectonic's Party Showcase: the team's page read as painted once per state, each member with its icons and colours;
# and Soulstones 2's footer, whose colour says whether the difficulty was raised or lowered since the game began.

# The stand-in's constructor paints and runs one frame of the pollers in place of the real one's loop, where the
# opening read comes from. With a party it paints each member through renderShowcaseInfo, and the footer through
# writeBottomText, as the real one does.
class PokemonPartyShowcase_Scene
  attr_accessor :footer
  def initialize(party, _snapshot = false, _name = nil)
    @party = party
    @footer = "Chapter 4"
    paint
    PokeAccess::Frame.run_pollers
  end
  def updateShowcaseInfo(_update = false); paint; end
  def paint
    if @party.empty?
      pbDrawTextPositions(nil, [["Chispa", 0, 0], ["Nv. 25", 0, 20]])
    else
      @party.each_with_index { |pk, i| renderShowcaseInfo(i, pk) }
    end
    writeBottomText
  end
  def renderShowcaseInfo(index, pokemon, _refresh = true)
    y = index * 100
    drawTextEx(nil, 20, y, 200, 1, "#{pokemon.name} Lv. #{pokemon.level}")
    sign = { 0 => "\xE2\x99\x82", 1 => "\xE2\x99\x80" }[pokemon.gender]
    drawTextEx(nil, 202, y, 80, 1, sign) if sign
    drawTextEx(nil, 78, y + 22, 200, 1, "Placaje")
    drawTextEx(nil, 10, y + 92, 200, 1, "Espesura")
    drawTextEx(nil, 224, y + 16, 80, 1, "252")
  end
  def writeBottomText
    drawFormattedTextEx(nil, 0, 40, 200, @footer)
  end
end

# The reader registered before the class above existed, so this repo's plugins/party_showcase.rb is evaluated again,
# and Soulstones 2's footer reader binds over it.
["plugins/party_showcase.rb", "games/soulstones2/showcase.rb"].each do |rel|
  path = File.join(Harness::ROOT, rel)
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class PartyShowcaseGdTest < PokeAccessTest
  MALE = "\xE2\x99\x82"
  FEMALE = "\xE2\x99\x80"
  # The page of the stand-in with no party, as painted.
  PAGE = "Chispa, Nv. 25, Chapter 4"

  test "the opening page is read as painted, queued, on the constructor's first frame" do
    PokemonPartyShowcase_Scene.new([])
    assert_equal [[PAGE, false]], SpeakCapture.log
  end

  test "once the constructor returns, the screen is let go and the frames after it say nothing" do
    PokemonPartyShowcase_Scene.new([])
    SpeakCapture.clear
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
    assert_nil PokeAccess::PartyShowcase.instance_variable_get(:@scene), "the frame poll keeps no closed screen"
  end

  test "a repaint of the same page says nothing" do
    scene = PokemonPartyShowcase_Scene.new([])
    SpeakCapture.clear
    scene.updateShowcaseInfo(true)
    assert_nothing_spoken
  end

  test "a repaint that changed the page is read again, queued" do
    scene = PokemonPartyShowcase_Scene.new([])
    scene.footer = "Chapter 5"
    SpeakCapture.clear
    scene.updateShowcaseInfo(true)
    assert_equal [["Chispa, Nv. 25, Chapter 5", false]], SpeakCapture.log
  end

  test "a value two members share is read for both" do
    scene = PokemonPartyShowcase_Scene.new([])
    def scene.paint
      pbDrawTextPositions(nil, [["Chispa", 0, 0], ["Nv. 25", 0, 20], ["Brasa", 0, 60], ["Nv. 25", 0, 80]])
    end
    SpeakCapture.clear
    scene.updateShowcaseInfo(true)
    assert_equal ["Chispa, Nv. 25, Brasa, Nv. 25"], SpeakCapture.lines
  end

  test "a member's shiny star, held item and ball follow its name and sign, and its nature's shading its rows" do
    PokemonPartyShowcase_Scene.new([shiny])
    icons = [t(:pk_shiny), t(:pk_holds, :item => "ItemORANBERRY"), t(:sum_ball, :b => "ItemULTRABALL")].join(", ")
    nature = t(:sm_nature_effect, :up => "StatATTACK", :down => "StatSPEED").sub(/\.\z/, "")
    assert_equal ["Chispa Lv. 25, #{MALE}, #{icons}, Placaje, Espesura, 252, #{nature}, Chapter 4"], SpeakCapture.lines
  end

  test "a member with no sign, no star, no item and a neutral nature has its ball alone, after its name" do
    PokemonPartyShowcase_Scene.new([plain])
    ball = t(:sum_ball, :b => "ItemPOKEBALL")
    assert_equal ["Brasa Lv. 30, #{ball}, Placaje, Espesura, 252, Chapter 4"], SpeakCapture.lines
  end

  test "a member whose ball and nature cannot be read has its painted rows alone" do
    PokemonPartyShowcase_Scene.new([Poke.build(:name => "Brasa", :level => 30, :gender => 2)])
    assert_equal ["Brasa Lv. 30, Placaje, Espesura, 252, Chapter 4"], SpeakCapture.lines
  end

  test "each member's icons are said with that member, in the team's order" do
    PokemonPartyShowcase_Scene.new([shiny, plain(1)])
    icons = [t(:pk_shiny), t(:pk_holds, :item => "ItemORANBERRY"), t(:sum_ball, :b => "ItemULTRABALL")].join(", ")
    nature = t(:sm_nature_effect, :up => "StatATTACK", :down => "StatSPEED").sub(/\.\z/, "")
    first = "Chispa Lv. 25, #{MALE}, #{icons}, Placaje, Espesura, 252, #{nature}"
    second = "Brasa Lv. 30, #{FEMALE}, #{t(:sum_ball, :b => "ItemPOKEBALL")}, Placaje, Espesura, 252"
    assert_equal ["#{first}, #{second}, Chapter 4"], SpeakCapture.lines
  end

  test "a page whose paint fails lets the game's error through, keeps nothing captured, and the next page is read" do
    broken = plain
    def broken.name; raise ArgumentError, "no name"; end
    assert_raises(ArgumentError) { PokemonPartyShowcase_Scene.new([broken]) }
    refute PokeAccess::PaintCapture.armed?(:showcase), "nothing is left capturing the game's paint"
    PokemonPartyShowcase_Scene.new([])
    assert_equal [[PAGE, false]], SpeakCapture.log
  end

  test "a member painted outside the page's capture is left to the game, unread" do
    scene = PokemonPartyShowcase_Scene.new([])
    SpeakCapture.clear
    assert_equal "252", scene.renderShowcaseInfo(0, plain)
    assert_nothing_spoken
  end

  test "Soulstones 2's footer says whether the difficulty was raised or lowered since the game began" do
    raised = ", #{t(:ss2_diff_raised)}"
    lowered = ", #{t(:ss2_diff_lowered)}"
    { ["Standard", 0] => "", ["Standard", 1] => raised, ["Standard", 2] => raised,
      ["Adept", 0] => lowered, ["Adept", 1] => "", ["Adept", 2] => raised,
      ["Unfair", 0] => lowered, ["Unfair", 1] => lowered, ["Unfair", 2] => "" }.each do |(start, mode), shift|
      with_difficulty(start, mode) do
        SpeakCapture.clear
        PokemonPartyShowcase_Scene.new([])
        assert_equal ["#{PAGE}#{shift}"], SpeakCapture.lines, "begun on #{start}, now mode #{mode}"
      end
    end
  end

  private

  # The mod's line for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A shiny male holding an Oran Berry, in an Ultra Ball, whose nature raises Attack and lowers Speed.
  def shiny
    nature = Object.new
    def nature.stat_changes; [[:ATTACK, 10], [:SPEED, -10]]; end
    pk = Poke.build(:name => "Chispa", :level => 25, :shiny => true, :item => :ORANBERRY)
    pk.instance_variable_set(:@nat, nature)
    def pk.poke_ball; :ULTRABALL; end
    def pk.nature_for_stats; @nat; end
    pk
  end

  # A Pokemon of gender (none by default) holding nothing, in a Poke Ball, whose nature changes no stat.
  def plain(gender = 2)
    nature = Object.new
    def nature.stat_changes; []; end
    pk = Poke.build(:name => "Brasa", :level => 30, :gender => gender)
    pk.instance_variable_set(:@nat, nature)
    def pk.poke_ball; :POKEBALL; end
    def pk.nature_for_stats; @nat; end
    pk
  end

  # Runs the block with the game begun on start ($game_variables[985]) and played now on mode, the player's
  # difficulty_mode taken back after.
  def with_difficulty(start, mode)
    $game_variables[985] = start
    $player.instance_variable_set(:@ss2_mode, mode)
    def $player.difficulty_mode; @ss2_mode; end
    yield
  ensure
    singleton = $player.singleton_class
    singleton.send(:remove_method, :difficulty_mode) if singleton.method_defined?(:difficulty_mode, false)
    $player.send(:remove_instance_variable, :@ss2_mode) if $player.instance_variable_defined?(:@ss2_mode)
  end
end
