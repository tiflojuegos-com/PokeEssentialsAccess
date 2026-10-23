# The words said are the ones painted: the PC's buttons and key hints; a Pokemon's trainer, number, item, and a Shadow
# one's heart in place of its experience; Reminiscencia's party panel, with no level nor HP figures, and its members'
# limits box.
class PaintedWordsTest < PokeAccessTest
  REMI_PANEL = File.join(Harness::ROOT, "games", "reminiscencia", "party_panel.rb")
  REMI_OVERRIDDEN = [:panel_level?, :panel_hp_figures?]
  BOX = "Max. EV total: 510\nEscamas: 3/10"
  BOX_SAID = "Max. EV total: 510. Escamas: 3/10"
  MALE = " \xE2\x99\x82"

  class << self
    # Reminiscencia's panel methods (REMI_OVERRIDDEN) once its profile file has been evaluated (once per process),
    # else nil.
    attr_accessor :remi_methods
  end

  test "the PC's buttons are the written rows at the overlay's bottom right, left to right" do
    painted = [["Exit", :positions, 446, 334], ["Pika", :positions, 10, 14], ["Party: 3", :positions, 270, 334],
               ["Static", :positions, 86, 312]]
    assert_equal ["Party: 3", "Exit"], PokeAccess::Party.pc_buttons(painted)
  end

  test "counts as PC buttons only the rows past the bottom right corner's edges" do
    { [200, 334] => [], [201, 334] => ["Salir"], [270, 300] => [], [270, 301] => ["Salir"] }.each do |(x, y), want|
      assert_equal want, PokeAccess::Party.pc_buttons([["Salir", :positions, x, y]]), "a row at (#{x}, #{y})"
    end
  end

  test "finds no PC buttons where they are pictures" do
    { "only the panel's rows" => [["Pika", :positions, 10, 14], ["Static", :positions, 86, 312]],
      "a row painted blank" => [["<c=FF0000>", :positions, 300, 334]],
      "a row with no position" => [["Salir", :dtex, nil, nil]],
      "nothing painted" => nil }.each do |what, painted|
      assert_equal [], PokeAccess::Party.pc_buttons(painted), what
    end
  end

  test "a key hint painted between the PC's buttons is no button" do
    assert_equal ["Equipo: 3", "Salir"], PokeAccess::Party.pc_buttons(royal_row)
  end

  test "a key hint painted between the PC's buttons is said as a hint of that row" do
    assert_equal ["[W]: Buscar"], PokeAccess::Party.pc_hints(royal_row)
  end

  test "says no PC key hints while key hints are left out" do
    PokeAccess::Config.verbosity = :brief
    assert_equal [], PokeAccess::Party.pc_hints(royal_row)
  end

  test "a lent Pokemon's trainer and number are said as the page writes them" do
    lent = with(Poke.build(:name => "Pika"), :ot => "", :publicID => 12345)
    assert_equal [word(:sum_ot, :name => word(:sum_loaned)), word(:sum_id, :id => word(:pdx_unknown_short))],
                 PokeAccess::Summary.trainer_facts(lent)
  end

  test "a trainer's name and number are said, the number padded to five digits" do
    owner = Struct.new(:name, :public_id).new("Azul", 42)
    { "gen-6's ot and publicID" => with(Poke.build, :ot => "Azul", :publicID => 42),
      "the v19 owner" => with(Poke.build, :owner => owner) }.each do |what, pk|
      assert_equal [word(:sum_ot, :name => "Azul"), word(:sum_id, :id => "00042")],
                   PokeAccess::Summary.trainer_facts(pk), what
    end
  end

  test "a trainer with no number says only the name" do
    assert_equal [word(:sum_ot, :name => "Azul")], PokeAccess::Summary.trainer_facts(with(Poke.build, :ot => "Azul"))
  end

  test "an ordinary Pokemon's facts say its experience and what the next level needs" do
    rate = Object.new
    rate.define_singleton_method(:minimum_exp_for_level) { |level| level == 26 ? 5000 : 0 }
    pk = with(Poke.build(:level => 25), :exp => 4321, :growth_rate => rate)
    assert_equal [word(:sum_ot, :name => word(:sum_loaned)), word(:sum_id, :id => word(:pdx_unknown_short)),
                  word(:sum_exp, :n => 4321), word(:sum_exp_next, :n => 679)],
                 PokeAccess::Summary.trainer_facts(pk)
  end

  test "a Shadow Pokemon's facts leave its experience to the heart the page writes" do
    { "gen-6's isShadow?" => :isShadow?, "v19's shadowPokemon?" => :shadowPokemon? }.each do |what, question|
      shadow = with(Poke.build(:name => "Oscuro"), :exp => 4321, question => true)
      assert_equal [word(:sum_ot, :name => word(:sum_loaned)), word(:sum_id, :id => word(:pdx_unknown_short))],
                   PokeAccess::Summary.trainer_facts(shadow), what
    end
  end

  test "a Shadow Pokemon's heart is the paragraphs its page paints, joined" do
    shadow = with(Poke.build, :isShadow? => true)
    assert_equal "El corazón de este Pokémon está cerrado.",
                 PokeAccess::Summary.heart_of(shadow, ["El corazón", "", "  de este Pokémon <b>está</b> cerrado.  "])
  end

  test "gives no heart for an ordinary Pokemon, nor for a page that paints none" do
    { "an ordinary Pokemon" => [Poke.build, ["El corazón"]],
      "a page of blank paragraphs" => [with(Poke.build, :isShadow? => true), ["", "  "]] }.each do |what, (pk, memo)|
      assert_nil PokeAccess::Summary.heart_of(pk, memo), what
    end
  end

  test "names the held item as page one writes it, or none" do
    none = word(:sum_none)
    { "no item" => [0, none], "nil" => [nil, none], "an item object" => [Struct.new(:name).new("Baya Zreza"), "Baya Zreza"],
      "an item object with no name" => [Struct.new(:name).new(""), none],
      "a numeric id" => [50, PBItems.getName(50)] }.each do |what, (item, name)|
      assert_equal word(:sum_item, :i => name), PokeAccess::Summary.item_fact(Poke.build(:item => item)), what
    end
  end

  test "names an item kept as a symbol through the game's data, not by the symbol" do
    items = Object.new
    items.define_singleton_method(:item_name) { |id| { :ORANBERRY => "Baya Aranja" }[id] }
    said = Harness.with_provider(items) { PokeAccess::Summary.item_fact(Poke.build(:item => :ORANBERRY)) }
    assert_equal word(:sum_item, :i => "Baya Aranja"), said
  end

  test "Reminiscencia's party line leaves out the level and the HP figures its panel does not draw" do
    pk = Poke.build(:name => "Chispa", :level => 12, :hp => 30, :totalhp => 30)
    head = word(:pty_head_nolv, :name => "Chispa, Especie1", :sex => MALE)
    cases = { "a plain member" => [{}, "#{head}, #{word(:bt_hp_pct, :n => 100)}"],
              "a member under an annotation" => [{ :annotation => "APTO" }, "#{head}, APTO"] }
    cases.each do |what, (opts, want)|
      assert_equal want, with_remi_panel { PokeAccess::Party.member_line(pk, opts) }, what
    end
  end

  test "Reminiscencia's party line says a sliver of HP as 1 percent, and with none left only the fainted slot" do
    head = word(:pty_head_nolv, :name => "Chispa, Especie1", :sex => MALE)
    lines = [[1, 300], [0, 30]].map do |hp, tot|
      with_remi_panel { PokeAccess::Party.member_line(Poke.build(:name => "Chispa", :hp => hp, :totalhp => tot)) }
    end
    assert_equal ["#{head}, #{word(:bt_hp_pct, :n => 1)}", "#{head}, #{word(:pk_fainted)}"], lines
  end

  test "the info key keeps the HP figures Reminiscencia's summary paints" do
    pk = Poke.build(:name => "Chispa", :hp => 30, :totalhp => 35)
    with_remi_panel { PokeAccess::Party.party_line([pk], 0) }
    assert_equal PokeAccess::Info.pokemon_info(pk), PokeAccess::Info.info_text
  end

  test "Reminiscencia's member menu says the limits box, a sentence per line, queued" do
    with_remi_panel { menu(remi_scene, false) }
    assert_equal [[BOX_SAID, false]], SpeakCapture.log
  end

  test "Reminiscencia's menu opened again over the same limits box says nothing of it" do
    scene = remi_scene
    with_remi_panel do
      menu(scene, false)
      SpeakCapture.clear
      menu(scene, false, [nil, ["Dar", "Quitar"]])
    end
    assert_nothing_spoken
  end

  test "Reminiscencia's limits box is said again once it changes" do
    scene = remi_scene
    with_remi_panel do
      menu(scene, false)
      scene.sprites["infowindow"].text = "Max. EV total: 510\nEscamas: 2/10"
      SpeakCapture.clear
      menu(scene, false)
    end
    assert_equal [["Max. EV total: 510. Escamas: 2/10", false]], SpeakCapture.log
  end

  test "Reminiscencia's limits box is said where the menu shows it" do
    cases = { "a menu not told" => [nil, ["Datos", "Salir"]], "a menu told to show it" => [nil, ["Datos"], 0, true] }
    cases.each do |what, args|
      SpeakCapture.clear
      with_remi_panel { menu(remi_scene, false, args) }
      assert_equal [BOX_SAID], SpeakCapture.lines, what
    end
  end

  test "Reminiscencia's limits box is not said where the menu hides it" do
    with_remi_panel { menu(remi_scene, false, [nil, ["Datos"], 0, false]) }
    assert_nothing_spoken
  end

  test "Reminiscencia's limits box is not said in battle" do
    with_remi_panel { menu(remi_scene, true) }
    assert_nothing_spoken
  end

  test "Reminiscencia's menu with no limits box written says nothing of it" do
    { "no box" => PokemonScreen_Scene.new, "an empty box" => remi_scene("") }.each do |what, scene|
      with_remi_panel { menu(scene, false) }
      assert_nothing_spoken what
    end
  end

  private

  # The text of i18n key with args.
  def word(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # pk with each name answering its value, the era's accessors a test needs.
  def with(pk, answers)
    answers.each { |name, v| pk.define_singleton_method(name) { v } }
    pk
  end

  # Royal's row under the box: the party button, a key hint, the exit button.
  def royal_row
    [["Equipo: 3", :positions, 292, 390], ["[W]: Buscar", :positions, 436, 390], ["Salir", :positions, 586, 390]]
  end

  # Runs the block with Reminiscencia's party panel profile in force. Its file is evaluated once per process, its
  # limits-box hook staying bound (it speaks only where a scene paints the box); its panel overrides are put back to
  # the core's after the block.
  def with_remi_panel
    party = PokeAccess::Party
    core = REMI_OVERRIDDEN.map { |m| party.method(m) }
    unless PaintedWordsTest.remi_methods
      eval(Harness.source(REMI_PANEL), TOPLEVEL_BINDING, REMI_PANEL)
      PaintedWordsTest.remi_methods = REMI_OVERRIDDEN.map { |m| party.method(m) }
    end
    REMI_OVERRIDDEN.each_with_index { |m, i| party.define_singleton_method(m, PaintedWordsTest.remi_methods[i]) }
    yield
  ensure
    REMI_OVERRIDDEN.each_with_index { |m, i| party.define_singleton_method(m, core[i]) } if core
  end

  # A gen-6 party scene painting a member's limits box.
  def remi_scene(text = BOX)
    scene = PokemonScreen_Scene.new
    scene.sprites["infowindow"] = Struct.new(:text).new(text)
    scene
  end

  # A member's command menu opened on scene, with the game's battle flag set as given (restored after).
  def menu(scene, in_battle, args = [nil, ["Datos", "Salir"]])
    was = $insideBattle
    $insideBattle = in_battle
    scene.pbShowCommands(*args)
  ensure
    $insideBattle = was
  end
end
