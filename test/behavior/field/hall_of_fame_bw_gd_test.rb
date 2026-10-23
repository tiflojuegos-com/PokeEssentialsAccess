# The "Hall de la Fama BW" plugin's entry ceremony (plugins/hall_of_fame_bw.rb) over the gamedata stubs: the gen-5
# member card and finale composed from what their bars paint, the gen-4 text windows read as they are shown, and
# Royal's copy (games/royal/hall_of_fame.rb), whose species bar shows the types and no sex.
class HallOfFameBwGdTest < PokeAccessTest
  Hof = PokeAccess::HallOfFameBW

  test "the gen-5 card says nickname, species with the sex sign its bar paints and level, queued" do
    HallDeLaFama.new.gen5_pokemon_info(chispa(1), 0)
    assert_equal [["Chispa, Pikachu ♀, #{level(60)}", false]], SpeakCapture.log
  end

  test "a member without a nickname is not named twice" do
    plain = Poke.build(:name => "Pikachu", :species => 25, :level => 5)
    def plain.speciesName; "Pikachu"; end
    assert_equal "Pikachu ♂, #{level(5)}", Hof.card(plain)
  end

  test "a genderless member's species bar has no sign" do
    [2, nil].each do |gender|
      assert_equal "Chispa, Pikachu, #{level(60)}", Hof.card(chispa(gender)), "gender #{gender.inspect}"
    end
  end

  test "the species is the data's name where the Pokemon gives none" do
    pk = Poke.build(:name => "Chispa", :species => 25, :level => 60)
    assert_equal "Chispa, Species25 ♂, #{level(60)}", Hof.card(pk)
  end

  test "no member has no card" do
    HallDeLaFama.new.gen5_pokemon_info(nil, 0)
    assert_nil Hof.card(nil)
    assert_nothing_spoken
  end

  test "the finale says the champion line with the plugin's region, then the player and the play time, queued" do
    HallDeLaFama.new.create_gen5_final_windows
    assert_equal [["#{champion('KANTO')} #{PokeAccess::I18n.t(:hofbw_finale, :name => 'Tester', :time => '3:07')}",
                   false]], SpeakCapture.log
  end

  test "a finale with no region, no player or no play time says what it has" do
    scene = HallDeLaFama.new
    finale = PokeAccess::I18n.t(:hofbw_finale, :name => "Tester", :time => "3:07")
    assert_equal "#{PokeAccess::I18n.t(:hofbw_champion_any)} #{finale}", with_region(nil) { Hof.finale(scene) },
                 "no region"
    assert_equal champion("KANTO"), with_player(nil) { Hof.finale(scene) }, "no player"
    def scene.get_play_time_formatted; raise "sin reloj"; end
    assert_equal "#{champion('KANTO')} Tester", Hof.finale(scene), "no play time"
  end

  test "a ceremony text window built hidden says nothing, one built shown is read as dialogue" do
    scene = HallDeLaFama.new
    scene.create_text_window("<ac>Salon de la Fama</ac>")
    scene.create_text_window("Pokedex: 151", true)
    assert_equal [["Pokedex: 151", false]], SpeakCapture.log
  end

  test "a hidden window is read when it is shown, and not again for being shown again later" do
    title = HallDeLaFama.new.create_text_window("<ac>Salon de la Fama</ac>")
    title.visible = true
    with_dialogue_guard_lapsed { title.visible = true }
    assert_equal ["Salon de la Fama"], SpeakCapture.lines
  end

  test "a shown window rewritten is read again, a hidden one waits until it is shown" do
    scene = HallDeLaFama.new
    stats = scene.create_text_window("Pokedex: 151", true)
    title = scene.create_text_window("Salon de la Fama")
    SpeakCapture.clear
    stats.text = "Pokedex: 152"
    title.text = "Otro"
    assert_equal ["Pokedex: 152"], SpeakCapture.lines, "the shown one, rewritten"
    SpeakCapture.clear
    title.visible = true
    assert_equal ["Otro"], SpeakCapture.lines, "the hidden one, once shown"
  end

  test "a blank window says nothing when shown" do
    HallDeLaFama.new.create_text_window("   ", true)
    assert_nothing_spoken
  end

  test "Royal's card says the types its species bar shows, and no sex" do
    pk = chispa(1)
    def pk.types; [:GRASS, :POISON]; end
    card = with_royal { Hof.card(pk) }
    assert_equal "Chispa, Pikachu, #{PokeAccess::I18n.t(:mv_type, :t => 'TypeGRASS/TypePOISON')}, #{level(60)}", card
  end

  test "Royal's card for a member with no types says the species alone" do
    assert_equal "Chispa, Pikachu, #{level(60)}", with_royal { Hof.card(chispa(1)) }
  end

  private

  # Chispa, a level 60 Pikachu of the given gender (1 female, 2 genderless), its species named as the plugin names it.
  def chispa(gender)
    pk = Poke.build(:name => "Chispa", :species => 25, :level => 60, :gender => gender)
    def pk.speciesName; "Pikachu"; end
    pk
  end

  def level(n); PokeAccess::I18n.t(:hofbw_level, :n => n); end
  def champion(region); PokeAccess::I18n.t(:hofbw_champion, :region => region); end

  # The block's value with Royal's profile file evaluated over the plugin; the plugin's own readers put back after.
  def with_royal
    sex = Hof.method(:sex_suffix)
    bar = Hof.method(:species_bar)
    path = File.join(Harness::ROOT, "games", "royal", "hall_of_fame.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    yield
  ensure
    Hof.define_singleton_method(:sex_suffix, sex)
    Hof.define_singleton_method(:species_bar, bar)
  end

  # The block's value with the plugin's region constant set to region, or not defined for nil; whatever was there put
  # back after.
  def with_region(region)
    had = Object.const_defined?(:HallDeLaFama_REGION)
    was = had ? Object.const_get(:HallDeLaFama_REGION) : nil
    Object.send(:remove_const, :HallDeLaFama_REGION) if had
    Object.const_set(:HallDeLaFama_REGION, region) if region
    yield
  ensure
    Object.send(:remove_const, :HallDeLaFama_REGION) if Object.const_defined?(:HallDeLaFama_REGION)
    Object.const_set(:HallDeLaFama_REGION, was) if had
  end

  # Runs the block as if the dialogue's repeat guard had lapsed, its last line said five seconds ago, so only the
  # reader can keep a line from being said again; the guard's time put back after.
  def with_dialogue_guard_lapsed
    was = PokeAccess.instance_variable_get(:@last_say_t)
    PokeAccess.instance_variable_set(:@last_say_t, PokeAccess.clock - 5)
    yield
  ensure
    PokeAccess.instance_variable_set(:@last_say_t, was)
  end

  # The block's value with player as $player, the stubs' own put back after.
  def with_player(player)
    was = $player
    $player = player
    yield
  ensure
    $player = was
  end
end
