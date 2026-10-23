# The encounter list (Encounter List UI) says each species of the focused type as its icon shows it: named with its
# form where the form is not the first or the list shows the species in several, in the Pokedex state its icon paints
# (the Pokedex's where no icon says one), at the Pokedex reading's levels; the info key keeps the whole type.
# Gamedata pass.
class EncounterFormsGdTest < PokeAccessTest
  # The encounter screen as the reader finds it: getEncData (private in some builds) answers [species, type].
  Scene = Struct.new(:table) do
    private

    def getEncData; table; end
  end

  # The engine's data of a species in one of its forms.
  SpeciesForm = Struct.new(:name, :species, :form, :form_name)

  # An encounter icon: the species it draws, its colour overlay and its tone.
  Icon = Struct.new(:species, :color, :tone)
  Color = Struct.new(:red, :green, :blue, :alpha)
  Tone = Struct.new(:red, :green, :blue, :gray)
  CLEAR = Color.new(0, 0, 0, 0)
  FLAT = Tone.new(0, 0, 0, 0)
  BLACK = Color.new(0, 0, 0, 255)
  GREY = Tone.new(0, 0, 0, 255)

  # The species of the forms tested here, by id: [name, species, form, form name].
  FORMS = { :FLABEBE => ["Flabébé", :FLABEBE, 0, "Forma Flor Roja"],
            :FLABEBE_1 => ["Flabébé", :FLABEBE, 1, "Forma Flor Amarilla"],
            :ZIGZAGOON_1 => ["Zigzagoon", :ZIGZAGOON, 1, "Forma Galar"],
            :EXEGGCUTE_1 => ["Exeggcute", :EXEGGCUTE, 1, ""],
            :PIKACHU => ["Pikachu", :PIKACHU, 0, ""],
            :EEVEE => ["Eevee", :EEVEE, 0, ""],
            :MEW => ["Mew", :MEW, 0, ""],
            :PUMPKABOO => ["Pumpkaboo", :PUMPKABOO, 0, "Tamaño Pequeño"],
            :VULPIX_1 => ["Vulpix", :VULPIX, 1, "Vulpix de Alola"] }

  test "a species in a form above its first is named with the form, unless the form is unnamed or names it" do
    with_species do
      { :ZIGZAGOON_1 => form("Zigzagoon", "Forma Galar"), :VULPIX_1 => "Vulpix de Alola",
        :EXEGGCUTE_1 => "Exeggcute", :PUMPKABOO => "Pumpkaboo" }.each do |sp, want|
        assert_equal want, PokeAccess::EncounterList.species_label(sp), sp.inspect
      end
    end
  end

  test "a species said alone has its form, and its state from medium or when said whole" do
    with_species do
      said = vb_levels { PokeAccess::EncounterList.entry_text(:ZIGZAGOON_1) }
      galar = form("Zigzagoon", "Forma Galar")
      assert_equal [galar, phrase(galar, :dex_caught), phrase(galar, :dex_caught)], said
      assert_equal phrase("Pumpkaboo", :dex_caught), PokeAccess::EncounterList.entry_text(:PUMPKABOO), "its first form"
      PokeAccess::Config.verbosity = :brief
      assert_equal phrase(galar, :dex_caught), PokeAccess::EncounterList.entry_text(:ZIGZAGOON_1, true)
    end
  end

  test "every form of a species the list shows in several is named with its form, the first included" do
    with_species do
      read(Scene.new([[:FLABEBE, :FLABEBE_1, :PIKACHU, :PUMPKABOO], :Land]))
      assert_equal whole("Land", [[form("Flabébé", "Forma Flor Roja"), :dex_caught],
                                  [form("Flabébé", "Forma Flor Amarilla"), :dex_caught], ["Pikachu", :dex_caught],
                                  ["Pumpkaboo", :dex_caught]]),
                   PokeAccess::Info.info_text
    end
  end

  test "an icon paints the state: the ? placeholder or a black shadow unknown, grey seen, coloured caught" do
    ui = PokeAccess::EncounterListUI
    { "the ? placeholder" => [Icon.new(0, CLEAR, FLAT), :dex_unknown],
      "a black shadow" => [Icon.new(25, BLACK, FLAT), :dex_unknown],
      "a black shadow barely laid" => [Icon.new(25, Color.new(0, 0, 0, 1), FLAT), :dex_unknown],
      "a dark but not black overlay" => [Icon.new(25, Color.new(0, 0, 8, 255), FLAT), :dex_caught],
      "a grey icon" => [Icon.new(25, CLEAR, GREY), :dex_seen],
      "a coloured icon" => [Icon.new(25, CLEAR, FLAT), :dex_caught] }.each do |what, (icon, want)|
      assert_equal want, ui.icon_state(icon), what
    end
  end

  test "no icon, or one that cannot be read, paints no state" do
    assert_nil PokeAccess::EncounterListUI.icon_state(nil)
    assert_nil PokeAccess::EncounterListUI.icon_state(Icon.new(25, Object.new, FLAT))
  end

  test "the list says each species in the state its icon paints, its name with the state it says" do
    with_species do
      scene = Scene.new([[:PIKACHU, :EEVEE, :MEW], :Land])
      icons = { "icon_0" => Icon.new(25, CLEAR, GREY), "icon_1" => Icon.new(0, CLEAR, FLAT) }
      scene.instance_variable_set(:@sprites, icons)
      read(scene)
      assert_equal whole("Land", [["Pikachu", :dex_seen], ["Eevee", :dex_unknown], ["Mew", :dex_caught]]),
                   PokeAccess::Info.info_text
    end
  end

  test "with no icon to say it, the Pokedex decides whether a species is caught, seen or unknown" do
    with_species do
      with_pokedex([:PIKACHU], [:PIKACHU, :EEVEE]) { read(Scene.new([[:PIKACHU, :EEVEE, :MEW], :Land])) }
      assert_equal whole("Land", [["Pikachu", :dex_caught], ["Eevee", :dex_seen], ["Mew", :dex_unknown]]),
                   PokeAccess::Info.info_text
    end
  end

  test "brief says the names, medium their states and full the count too, while the info key keeps it whole" do
    with_species do
      scene = Scene.new([[:PIKACHU, :EEVEE], :Land])
      said = with_pokedex([:PIKACHU], [:PIKACHU, :EEVEE]) { vb_levels { read(scene) } }
      assert_equal ["Land: Pikachu, Eevee", "Land: #{phrase('Pikachu', :dex_caught)}, #{phrase('Eevee', :dex_seen)}",
                    "#{type_head('Land', 2)}: #{phrase('Pikachu', :dex_caught)}, #{phrase('Eevee', :dex_seen)}"],
                   said
      PokeAccess::Config.verbosity = :brief
      with_pokedex([:PIKACHU], [:PIKACHU, :EEVEE]) { read(scene) }
      assert_equal whole("Land", [["Pikachu", :dex_caught], ["Eevee", :dex_seen]]), PokeAccess::Info.info_text
    end
  end

  test "a type with no species says its name and that it has none, at any level" do
    assert_equal [type_head("Land", 0)] * 3, vb_levels { read(Scene.new([[], :Land])) }
  end

  test "the info key says every species of a type, past fifteen too" do
    with_species do
      read(Scene.new([[:PIKACHU] * 15, :Land]))
      assert_equal "#{type_head('Land', 15)}: #{([phrase('Pikachu', :dex_caught)] * 15).join(', ')}",
                   PokeAccess::Info.info_text, "fifteen, all said"
      read(Scene.new([[:PIKACHU] * 17, :Land]))
      assert_equal "#{type_head('Land', 17)}: #{([phrase('Pikachu', :dex_caught)] * 17).join(', ')}",
                   PokeAccess::Info.info_text, "seventeen, all said"
    end
  end

  test "a type is named by the plugin's own names first, then the engine's, then its id" do
    scene = Scene.new([[], :Land])
    assert_equal type_head("Land", 0), read(scene), "with neither"
    with_const(GameData, :EncounterType, encounter_types("Hierba alta")) do
      assert_equal type_head("Hierba alta", 0), read(scene), "the engine's"
      with_const(Object, :USER_DEFINED_NAMES, { :Water => "Agua" }) do
        assert_equal type_head("Hierba alta", 0), read(scene), "the engine's, for a type the plugin does not name"
      end
      with_const(Object, :USER_DEFINED_NAMES, { :Land => "Pradera" }) do
        assert_equal type_head("Pradera", 0), read(scene), "the plugin's, kept at the top level"
        with_const(Object, :EncounterListSettings, Module.new) do
          EncounterListSettings.const_set(:USER_DEFINED_NAMES, { :Land => "Campo" })
          assert_equal type_head("Campo", 0), read(scene), "the plugin's, kept in its settings, before the top level"
        end
      end
    end
  end

  test "a type is said as the cursor moves onto it, interrupting, and not again while it stays" do
    with_species do
      scene = Scene.new([[:PIKACHU], :Land])
      scene.instance_variable_set(:@index, 0)
      2.times { PokeAccess::EncounterListUI.read_present(scene) }
      scene.instance_variable_set(:@index, 1)
      scene.table = [[:EEVEE], :Water]
      PokeAccess::EncounterListUI.read_present(scene)
      assert_equal [["#{type_head('Land', 1)}: #{phrase('Pikachu', :dex_caught)}", true],
                    ["#{type_head('Water', 1)}: #{phrase('Eevee', :dex_caught)}", true]],
                   SpeakCapture.log
    end
  end

  test "a screen whose encounter data cannot be read says nothing" do
    assert_nil read(Scene.new(nil))
  end

  private

  def form(name, form)
    PokeAccess::I18n.t(:enc_form, :name => name, :form => form)
  end

  def type_head(type, n)
    PokeAccess::I18n.t(:enc_type, :type => type, :n => n)
  end

  # A species as the list says it in a state: the unknown word alone, else its name and its state.
  def phrase(name, state)
    state == :dex_unknown ? PokeAccess::I18n.t(:dex_unknown) : "#{name} #{PokeAccess::I18n.t(state)}"
  end

  # A type said whole, as the info key keeps it: its name and count, then each [name, state].
  def whole(type, entries)
    "#{type_head(type, entries.length)}: #{entries.map { |n, s| phrase(n, s) }.join(', ')}"
  end

  # The list's text for scene, as it says it now.
  def read(scene)
    PokeAccess::EncounterListUI.text_for(scene)
  end

  # Runs the block with the engine answering FORMS for those species, its own data for any other.
  def with_species
    meta = GameData::Species.singleton_class
    meta.send(:alias_method, :encounter_forms_get, :get)
    meta.send(:define_method, :get) do |id|
      FORMS[id] ? SpeciesForm.new(*FORMS[id]) : encounter_forms_get(id)
    end
    yield
  ensure
    meta.send(:alias_method, :get, :encounter_forms_get)
    meta.send(:remove_method, :encounter_forms_get)
  end

  # The block's value with the player's Pokedex owning the owned species and having seen the seen ones.
  def with_pokedex(owned, seen)
    dex = Object.new
    dex.define_singleton_method(:owned?) { |sp| owned.include?(sp) }
    dex.define_singleton_method(:seen?) { |sp| seen.include?(sp) }
    $player.define_singleton_method(:pokedex) { dex }
    yield
  ensure
    $player.singleton_class.send(:remove_method, :pokedex)
  end

  # The engine's encounter types, every one named name.
  def encounter_types(name)
    types = Module.new
    types.define_singleton_method(:get) { |_key| Struct.new(:real_name).new(name) }
    types
  end

  # The block's value with owner's constant name set to value, taken out afterwards.
  def with_const(owner, name, value)
    owner.const_set(name, value)
    yield
  ensure
    owner.send(:remove_const, name)
  end
end
