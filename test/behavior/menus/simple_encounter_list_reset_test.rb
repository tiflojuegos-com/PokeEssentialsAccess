# Simple Encounter List (plugins/simple_encounter_list.rb): a filled list is read on the next frame by its icons and
# kept whole for the info key; an area without encounters is said, and a list still waiting dropped as caches reset.
class SimpleEncounterListResetTest < PokeAccessTest
  # An icon as the window draws it: its opacity and its tone's grey.
  Icon = Struct.new(:opacity, :tone)
  Tone = Struct.new(:gray)

  test "reads a list waiting for its icons on the next frame, once" do
    on_route do
      PokeAccess::SimpleEncounterList.filled(filled_scene([16, 19]))
      next_frame
      next_frame
    end
    unseen = PokeAccess::I18n.t(:dex_unknown)
    assert_equal [["#{type_line(2)}: #{unseen}, #{unseen}", true]], SpeakCapture.log
  end

  test "says each species as its icon shows it: a dimmed or grey icon not caught, else the Pokedex's state" do
    icons = [full, full, full, Icon.new(100, Tone.new(0)), Icon.new(255, Tone.new(255))]
    with_dex([16, 25, 27], [19]) { on_route { read([16, 19, 21, 25, 27], icons) } }
    said = [named(16, :dex_caught), named(19, :dex_seen), PokeAccess::I18n.t(:dex_unknown), named(25, :dex_not_caught),
            named(27, :dex_not_caught)]
    assert_equal [["#{type_line(5)}: #{said.join(', ')}", true]], SpeakCapture.log
  end

  test "takes an icon dimmed at all or grey at all for one not caught" do
    icons = [Icon.new(254, Tone.new(0)), Icon.new(255, Tone.new(1)), full]
    with_dex([16, 19, 21], []) { on_route { read([16, 19, 21], icons) } }
    said = [named(16, :dex_not_caught), named(19, :dex_not_caught), named(21, :dex_caught)]
    assert_equal [["#{type_line(3)}: #{said.join(', ')}", true]], SpeakCapture.log
  end

  test "reads an icon whose tone it cannot read by its opacity alone" do
    with_dex([16, 19], []) { on_route { read([16, 19], [Icon.new(255, nil), Icon.new(100, nil)]) } }
    said = [named(16, :dex_caught), named(19, :dex_not_caught)]
    assert_equal [["#{type_line(2)}: #{said.join(', ')}", true]], SpeakCapture.log
  end

  test "keeps the whole list for the info key while brief says the names alone" do
    PokeAccess::Config.verbosity = :brief
    with_dex([16], [19]) { on_route { read([16, 19], [full, full]) } }
    assert_equal [["Ruta 1: #{species(16)}, #{species(19)}", true]], SpeakCapture.log
    assert_equal "#{type_line(2)}: #{named(16, :dex_caught)}, #{named(19, :dex_seen)}", PokeAccess::Info.info_text
  end

  test "says an area without encounters on the next frame, though its window draws no icons" do
    [[7], [], nil].each do |list|
      SpeakCapture.clear
      on_route do
        PokeAccess::SimpleEncounterList.filled(World.stub_scene(:@encarray => list, :@pkmnsprite => []))
        next_frame
      end
      assert_equal [[PokeAccess::I18n.t(:enc_none, :loc => "Ruta 1"), true]], SpeakCapture.log, "for #{list.inspect}"
    end
  end

  test "drops unread a list whose window drew no icons for its species" do
    [[], nil].each do |icons|
      PokeAccess::SimpleEncounterList.filled(World.stub_scene(:@encarray => [16, 19], :@pkmnsprite => icons))
      next_frame
      next_frame
      assert_nothing_spoken "with icons #{icons.inspect}"
    end
  end

  test "forgets a list waiting to be read when the caches reset" do
    PokeAccess::SimpleEncounterList.filled(filled_scene([16, 19]))
    PokeAccess::Caches.reset_all
    next_frame
    assert_nothing_spoken
  end

  private

  # An encounter window whose species have their icons up, at full opacity and colour.
  def filled_scene(list)
    World.stub_scene(:@encarray => list, :@pkmnsprite => list.map { full })
  end

  # An icon at full opacity with no grey.
  def full
    Icon.new(255, Tone.new(0))
  end

  # Fills a window with the species and their icons and reads it on the next frame.
  def read(list, icons)
    PokeAccess::SimpleEncounterList.filled(World.stub_scene(:@encarray => list, :@pkmnsprite => icons))
    next_frame
  end

  # One frame of the mod's pollers, the next frame the game draws.
  def next_frame
    PokeAccess::Frame.run_pollers
  end

  # Runs the block with the player's Pokedex holding the caught species and the seen ones.
  def with_dex(caught, seen)
    $Trainer.define_singleton_method(:owned?) { |sp| caught.include?(sp) }
    $Trainer.define_singleton_method(:seen?) { |sp| caught.include?(sp) || seen.include?(sp) }
    yield
  ensure
    [:owned?, :seen?].each do |m|
      $Trainer.singleton_class.send(:remove_method, m) if $Trainer.singleton_methods.include?(m)
    end
  end

  # Runs the block on a map called "Ruta 1".
  def on_route
    $game_map.define_singleton_method(:name) { "Ruta 1" }
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :name) if $game_map.singleton_methods.include?(:name)
  end

  # The header of a list of n species on Ruta 1.
  def type_line(n)
    PokeAccess::I18n.t(:enc_type, :type => "Ruta 1", :n => n)
  end

  # A species' name as the engine's data gives it.
  def species(id)
    PokeAccess::Data.species_name(id)
  end

  # A species said with its state, as the list says it from medium up.
  def named(id, state)
    "#{species(id)} #{PokeAccess::I18n.t(state)}"
  end
end
