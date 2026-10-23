# Sevii's party panel and PC (games/sevii/party.rb) over the gen-6 readers: the HP bar said as a share, since the
# panel writes no figures, the ball each panel draws, and the PC's buttons drawn into its picture.
class SeviiPartyTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "party.rb")
  OVERRIDDEN = [:panel_hp_figures?, :panel_marks, :pc_buttons]
  T = PokeAccess::I18n
  Party = PokeAccess::Party
  MALE = " \xE2\x99\x82"

  class << self
    # The profile's methods by name: its file is evaluated once per process, and core's methods and the registries
    # it adds to are put back at once.
    def sevii_methods
      @sevii_methods ||= begin
        core = OVERRIDDEN.map { |m| Party.method(m) }
        saved = [PokeAccess::Game.profiles.dup, PokeAccess::Hooks.overrides.dup,
                 PokeAccess::Hooks.instance_variable_get(:@bound).dup]
        eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
        mine = {}
        OVERRIDDEN.each_with_index do |m, i|
          mine[m] = Party.method(m)
          Party.define_singleton_method(m, core[i])
        end
        PokeAccess::Game.instance_variable_set(:@profiles, saved[0])
        PokeAccess::Game.instance_variable_set(:@profile_name, nil)
        PokeAccess::Hooks.overrides.replace(saved[1])
        PokeAccess::Hooks.instance_variable_set(:@bound, saved[2])
        mine
      end
    end
  end

  test "a party member says its HP bar as a share of the total, as the panel writes no figures" do
    with_sevii do
      Party.announce_party(party_scene([member(30, 35)]), [member(30, 35)], 0, -1)
      assert_equal [head + ", " + T.t(:bt_hp_pct, :n => 85)], SpeakCapture.lines
    end
  end

  test "a sliver of HP left is at least 1 percent, and with none left only the fainted slot is said" do
    with_sevii do
      assert_equal [head + ", " + T.t(:bt_hp_pct, :n => 1), head + ", " + T.t(:pk_fainted)],
                   [Party.party_line([member(1, 300)], 0), Party.party_line([member(0, 35)], 0)]
    end
  end

  test "the info key keeps the HP figures the summary paints, while Ctrl+T says the row as the panel shows it" do
    with_sevii do
      pk = member(30, 35)
      Party.party_line([pk], 0)
      assert_equal [PokeAccess::Info.pokemon_info(pk), head + ", " + T.t(:bt_hp_pct, :n => 85)],
                   [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
    end
  end

  test "an annotated panel says its annotation in place of the bar" do
    with_sevii do
      assert_equal head + ", APTO", Party.party_line([member(30, 35)], 0, "APTO")
    end
  end

  test "each panel says the ball its member was caught in, from the full level" do
    with_sevii do
      pk = member(35, 35)
      pk.define_singleton_method(:ballused) { 3 }
      GameFunctions.with(:pbBallTypeToBall => lambda { |t| 300 + t }) do
        said = vb_levels { Party.party_line([pk], 0) }
        full = head + ", " + T.t(:bt_hp_pct, :n => 100) + ", Item303"
        assert_equal [T.t(:pty_head_nolv, :name => "Bulba", :sex => "") + ", " + T.t(:bt_hp_pct, :n => 100),
                      T.t(:pty_head, :name => "Bulba", :sex => "", :level => 12) + ", " + T.t(:bt_hp_pct, :n => 100),
                      full], said
      end
    end
  end

  test "the PC's party and return buttons, drawn into its picture, say the party and the word for going back" do
    with_sevii do
      scene = pc
      Party.announce_pc(scene, -2, nil, [])
      Party.announce_pc(scene, -3, nil, [])
      assert_equal [T.t(:pc_team), T.t(:back)], SpeakCapture.lines
    end
  end

  test "a PC that writes its buttons keeps the painted words" do
    with_sevii do
      assert_equal ["Equipo: 3", "Salir"],
                   Party.pc_buttons([["Salir", :positions, 586, 390], ["Equipo: 3", :positions, 292, 390]])
    end
  end

  private

  # Runs the block with Sevii's overrides in force, core's put back after.
  def with_sevii
    core = OVERRIDDEN.map { |m| Party.method(m) }
    self.class.sevii_methods.each { |m, um| Party.define_singleton_method(m, um) }
    yield
  ensure
    OVERRIDDEN.each_with_index { |m, i| Party.define_singleton_method(m, core[i]) } if core
  end

  # A male level-12 Bulba with hp of total HP left.
  def member(hp, total)
    Poke.build(:name => "Bulba", :level => 12, :hp => hp, :totalhp => total, :gender => 0)
  end

  # The member's name, sex sign and level, as the panel writes them, the species its icon shows after the nickname.
  def head
    T.t(:pty_head, :name => "Bulba, Especie1", :sex => MALE, :level => 12)
  end

  # The gen-6 party screen over party, with no panels.
  def party_scene(party)
    scene = PokemonScreen_Scene.new(party)
    scene.sprites = {}
    scene
  end

  # The gen-6 PC over an empty storage, nothing in hand.
  def pc
    scene = PokemonStorageScene.new
    scene.instance_variable_set(:@screen, Struct.new(:held) { def pbHeldPokemon; held; end }.new(nil))
    scene.instance_variable_set(:@storage, Struct.new(:currentBox) { def [](*_a); nil; end }.new(0))
    scene
  end
end
