# The HGSS Dex List plugin (plugins/hgss_dexlist.rb, Eternal Emerald): each square says the number it paints (one
# lower in an offset dex) and the species, owned or only seen, shiny where the number is gold, unseen a silhouette.
class HgssDexlistTest < PokeAccessTest
  # The plugin's list sprite: its rows and the cursor.
  ListSprite = Struct.new(:dexlist, :index)

  # Its rows: owned and last seen shiny, only seen in an offset dex, never seen.
  ROWS = [{ :species => 1, :number => 1 }, { :species => 2, :number => 5, :shift => true },
          { :species => 3, :number => 9 }].freeze

  # The player as the squares ask: species 1 owned and last seen shiny, 3 never seen, the rest only seen.
  class Player
    def pokedex; self; end
    def last_form_seen(species); [0, 0, species == 1]; end
    def seen?(species); species != 3; end
    def owned?(species); species == 1; end
  end

  test "reads an owned species as caught, with the shiny mark of its gold number" do
    with_dex do
      assert_equal [entry(1, 1), t(:dex_caught), t(:pk_shiny)].join(", "), square(0)
    end
  end

  test "reads a species only seen as seen, with the number its square paints one lower in an offset dex" do
    with_dex { assert_equal [entry(4, 2), t(:dex_seen)].join(", "), square(1) }
  end

  test "reads a species never seen as its number undiscovered, which the info key keeps too" do
    unknown = PokeAccess::I18n.t(:dexlist_unknown, :num => 9)
    with_dex { assert_equal unknown, square(2) }
    assert_equal unknown, PokeAccess::Info.info_text
  end

  test "leaves the shiny mark out where the plugin paints no gold numbers, or predates that setting" do
    [false, :absent].each do |gold|
      with_dex(gold) { assert_equal [entry(1, 1), t(:dex_caught)].join(", "), square(0), "gold setting #{gold.inspect}" }
    end
  end

  test "leaves the shiny mark out for an owned species last seen in plain colours, or in a form it cannot tell" do
    [[0, 0, false], nil].each do |form|
      with_dex do
        $player.define_singleton_method(:last_form_seen) { |_species| form }
        assert_equal [entry(1, 1), t(:dex_caught)].join(", "), square(0), "last form seen #{form.inspect}"
      end
    end
  end

  test "paints no gold number for a species only seen, though last seen shiny" do
    with_dex do
      $player.define_singleton_method(:last_form_seen) { |_species| [0, 0, true] }
      assert_equal [entry(4, 2), t(:dex_seen)].join(", "), square(1)
    end
  end

  test "reads a species its data names blank as undiscovered" do
    blank = Object.new
    def blank.species_name(_species); ""; end
    with_dex { Harness.with_provider(blank, 99) { assert_equal PokeAccess::I18n.t(:dexlist_unknown, :num => 4), square(1) } }
  end

  test "reads every square as only seen when the game cannot say what the player has" do
    with_dex do
      $player = Object.new
      assert_equal [entry(1, 1), t(:dex_seen)].join(", "), square(0)
    end
  end

  test "says caught from medium and the shiny mark at full, the info key keeping the whole row" do
    rows = with_dex do
      PokeAccess::Config.verbosity = :brief
      square(0)
      kept = PokeAccess::Info.info_text
      vb_levels { square(0) } + [kept]
    end
    head = entry(1, 1)
    assert_equal [head, [head, t(:dex_caught)].join(", "), [head, t(:dex_caught), t(:pk_shiny)].join(", "),
                  [head, t(:dex_caught), t(:pk_shiny)].join(", ")], rows
  end

  test "reads no row for a cursor off the list, a cursor that is no number, or a row that is not the plugin's" do
    with_dex do
      { -1 => ROWS, 3 => ROWS, nil => ROWS, 0 => ["not a row"] }.each do |index, rows|
        assert_nil PokeAccess::HGSSDexList.text(ListSprite.new(rows, index)), "index #{index.inspect} of #{rows.inspect}"
      end
    end
  end

  test "speaks the focused square, interrupting, once as the list refreshes" do
    scene = dex_scene(ListSprite.new(ROWS, 1))
    with_dex { 2.times { PokeAccess::HGSSDexList.read(scene) } }
    assert_equal [[[entry(4, 2), t(:dex_seen)].join(", "), true]], SpeakCapture.log
  end

  test "speaks the square again when a search changes it under a still cursor" do
    sprite = ListSprite.new(ROWS, 1)
    scene = dex_scene(sprite)
    with_dex do
      PokeAccess::HGSSDexList.read(scene)
      sprite.dexlist = [ROWS[0], ROWS[2]]
      PokeAccess::HGSSDexList.read(scene)
    end
    assert_equal [[entry(4, 2), t(:dex_seen)].join(", "), PokeAccess::I18n.t(:dexlist_unknown, :num => 9)],
                 SpeakCapture.lines
  end

  test "reads nothing on a stock Pokedex, whose list sprite keeps no dex list" do
    with_dex do
      PokeAccess::HGSSDexList.read(dex_scene(Struct.new(:index).new(0)))
      PokeAccess::HGSSDexList.read(World.stub_scene(:@sprites => nil))
    end
    assert_nothing_spoken
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end

  # A square's number and its species' name as the Pokedex knows it.
  def entry(num, species)
    PokeAccess::I18n.t(:dexlist_entry, :num => num, :name => PBSpecies.getName(species))
  end

  # The row text of the square at index of the plugin's list.
  def square(index)
    PokeAccess::HGSSDexList.text(ListSprite.new(ROWS, index))
  end

  # A Pokedex scene whose "pokedex" sprite is sprite.
  def dex_scene(sprite)
    World.stub_scene(:@sprites => { "pokedex" => sprite })
  end

  # The block's value with the player's Pokedex as Player answers it and the plugin's list sprite class painting
  # shiny numbers gold or not (:absent for a version without the setting); both put back afterwards.
  def with_dex(gold = true)
    player = $player
    had_class = Object.const_defined?(:PokedexListSprite)
    Object.const_set(:PokedexListSprite, Class.new) unless had_class
    had_gold = PokedexListSprite.const_defined?(:USE_GOLD_NUMBER_FOR_SHINY, false)
    was_gold = had_gold ? PokedexListSprite::USE_GOLD_NUMBER_FOR_SHINY : nil
    PokedexListSprite.send(:remove_const, :USE_GOLD_NUMBER_FOR_SHINY) if had_gold
    PokedexListSprite.const_set(:USE_GOLD_NUMBER_FOR_SHINY, gold) unless gold == :absent
    $player = Player.new
    yield
  ensure
    $player = player
    if PokedexListSprite.const_defined?(:USE_GOLD_NUMBER_FOR_SHINY, false)
      PokedexListSprite.send(:remove_const, :USE_GOLD_NUMBER_FOR_SHINY)
    end
    PokedexListSprite.const_set(:USE_GOLD_NUMBER_FOR_SHINY, was_gold) if had_gold
    Object.send(:remove_const, :PokedexListSprite) unless had_class
  end
end
