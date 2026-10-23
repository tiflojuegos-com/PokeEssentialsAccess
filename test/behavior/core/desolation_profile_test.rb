require "rbconfig"
require "tempfile"

# The Desolation profile loaded whole in a process of its own, over data and classes shaped as Desolation's (the
# overrides of the engine it shares would reach every other test here): it binds, and says what its screens paint.
class DesolationProfileTest < PokeAccessTest
  # The Desolation-shaped data and classes, declared before the profile loads so its hooks and its data provider find
  # them: a plain Hash species table with each form's types in formData, a Pokedex of species rows, symbol balls,
  # items, abilities and natures, PBExp and no getItemDescription.
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    module DesoWorld
      Mon = Struct.new(:name, :Type1, :Type2, :kind, :dexentry, :forms, :formData, :dexnum)
      Named = Struct.new(:name, :desc)
      Nature = Struct.new(:name, :incStat, :decStat)
      MapData = Struct.new(:MapPosition)
      Cache = Struct.new(:pkmn, :moves, :abil, :items, :types, :natures, :mapdata, :town_map, :FEData, :trainertypes)
      Move = Struct.new(:move, :type, :pp, :totalpp)
      Dex = Struct.new(:dexList)
      Trainer = Struct.new(:name, :pokedex, :seen, :owned)

      # A species row of the game's Pokedex, the form last seen by name.
      def self.row(seen, owned, form)
        { :seen? => seen, :owned? => owned, :lastSeen => { :gender => "Male", :form => form, :shiny => false } }
      end
    end

    $cache = DesoWorld::Cache.new(
      { :BULBASAUR => DesoWorld::Mon.new("Bulbasaur", :GRASS, :POISON, "Seed", "A strange seed.", {}, {}, 1),
        :IVYSAUR => DesoWorld::Mon.new("Ivysaur", :GRASS, :POISON, "Seed", "Its bulb grows.", {}, {}, 2),
        :VENUSAUR => DesoWorld::Mon.new("Venusaur", :GRASS, :POISON, "Seed", "A flower blooms.", {}, {}, 3),
        :SANDSHREW => DesoWorld::Mon.new("Sandshrew", :GROUND, nil, "Mouse", "It burrows.", { 0 => "Normal", 1 => "Alolan" },
                                         { "Alolan" => { :Type1 => :ICE, :Type2 => :STEEL } }, 27) },
      { :TACKLE => DesoWorld::Named.new("Tackle", "A full-body charge.") },
      { :OVERGROW => DesoWorld::Named.new("Overgrow", "Powers up Grass-type moves in a pinch.") },
      { :POKEBALL => DesoWorld::Named.new("Poke Ball", "A device for catching."),
        :ULTRABALL => DesoWorld::Named.new("Ultra Ball", "A high-performance Ball."),
        :LEFTOVERS => DesoWorld::Named.new("Leftovers", "Restores HP every turn.") },
      { :NORMAL => DesoWorld::Named.new("Normal"), :FIRE => DesoWorld::Named.new("Fire"),
        :GRASS => DesoWorld::Named.new("Grass"), :POISON => DesoWorld::Named.new("Poison"),
        :GROUND => DesoWorld::Named.new("Ground"), :ICE => DesoWorld::Named.new("Ice"),
        :STEEL => DesoWorld::Named.new("Steel"), :DRAGON => DesoWorld::Named.new("Dragon"),
        :QMARKS => DesoWorld::Named.new("???") },
      { :ADAMANT => DesoWorld::Nature.new("Adamant", 1, 3), :HARDY => DesoWorld::Nature.new("Hardy", nil, nil) },
      [nil, DesoWorld::MapData.new([0, 7, 17])],
      [[nil, "mapRegion0.png", [[7, 17, "Keneph Beach", "", nil, nil, nil, nil],
                                [12, 14, "Redcliff Town", "", nil, nil, nil, nil],
                                [12, 12, "Route 1", "", nil, nil, nil, nil]]]],
      {}, {})

    def getMonName(mon); $cache.pkmn[mon].name; end
    def getItemName(item); $cache.items[item].name; end
    def getMoveName(move); $cache.moves[move].name; end
    def getMoveDesc(move); $cache.moves[move].desc; end
    def getNatureName(nature); $cache.natures[nature].name; end
    def getTypeName(type); $cache.types[type].name; end
    def getAbilityName(abil); $cache.abil[abil].name; end
    def getAbilityDesc(abil); $cache.abil[abil].desc; end
    def pbBallTypeToBall(balltype); { 0 => :POKEBALL, 3 => :ULTRABALL }[balltype] || :POKEBALL; end
    def pbSelectPasswordToBeToggled(_passwords, _operations_left)
      ["[Exit]", "[Add password]", "> fullivs", "    litemode"].map { |r| PokeAccess::Menus.checkbox_row(r) }
    end

    Object.send(:remove_const, :PBExperience) if defined?(PBExperience)
    module PBExp
      MAXLEVEL = 150
      def self.startExperience(level, _growth); level = MAXLEVEL if level > MAXLEVEL; level * level * 10; end
    end

    class PokemonSummaryScene
      def drawPageFour(pk = nil)
        (@pokemon = pk) if pk
        pbDrawTextPositions(nil, [["EV & IV", 26, 16], [@pokemon.name, 46, 62], ["Ability", 224, 284],
                                  [getAbilityName(@pokemon.ability), 362, 284]])
        drawTextEx(nil, 224, 316, 282, 2, getAbilityDesc(@pokemon.ability))
      end
    end

    class PokemonPokedexScene
      def pbChangeToDexEntry(species)
        d = $cache.pkmn[species]
        textpos = [[format("%03d  %s", d.dexnum, getMonName(species)), 244, 40], ["HT", 318, 158], ["WT", 318, 190]]
        if $Trainer.pokedex.dexList[species][:owned?]
          drawTextEx(nil, 42, 240, 428, 4, d.dexentry)
          textpos.push(["#{d.kind} Pokemon", 244, 74], ["0.7 m", 466, 158], ["6.9 kg", 478, 190])
        else
          textpos.push(["????? Pokemon", 244, 74], ["????.? m", 466, 158], ["????.? kg", 478, 190])
        end
        pbDrawTextPositions(nil, textpos)
      end
    end

    class PokedexFormScene
      def pbStartScene(species)
        @species = species; @gender = "Male"; @form = "Normal"; @shiny = false
        pbUpdate
        true
      end

      def pbUpdate
        pbDrawTextPositions(nil, [[getMonName(@species), 256, 298, 2], ["#{@form}         Gender: #{@gender}", 256, 330, 2]])
      end

      def pbChooseForm
        @gender = "Female"
        pbUpdate
      end
    end

    class Scene_EncounterRate
      attr_reader :heard
      def main; @heard = SpeakCapture.log.dup; :main_done; end
    end

    class QuestLog_Scene
      def pbStartScene(_commands); @sprites = {}; end
      def pbSetCommands(_commands, _index); end
      def pbScene; -1; end
    end
    class QuestInfo_Scene; def pbUpdate; end; end
    class AdvancedPokedexScene
      def pbStartScene(_species); true; end
      def displayPage; end
    end

    class DesoPoke < TestPoke
      attr_accessor :ballused, :exp, :growthrate, :ot, :publicID, :type1, :type2
    end
  RUBY

  # The play, run after the load: each probe prints its outcome as "PROBE name base64(Marshal)", or what it raised.
  # The probes run inside a method, as the profile's files are evaluated at the top level, where a local would be the
  # one their hook blocks assign.
  PLAY = <<-'RUBY'
    def probe(name)
      value = begin
                yield
              rescue StandardError, ScriptError => e
                { :probe_raised => "#{e.class}: #{e.message}" }
              end
      puts "PROBE #{name} #{[Marshal.dump(value)].pack('m0')}"
    end

    # Bulby, the Pokemon the summary probes read: an Ultra Ball, Leftovers, an Adamant nature and one move.
    def bulby
      pk = DesoPoke.build(:name => "Bulby", :species => :BULBASAUR, :ability => :OVERGROW, :item => :LEFTOVERS,
                          :nature => :ADAMANT, :moves => [DesoWorld::Move.new(:TACKLE, :NORMAL, 30, 35)],
                          :ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26])
      pk.ballused = :ULTRABALL; pk.exp = 6500; pk.growthrate = :Medium; pk.ot = "Red"; pk.publicID = 12345
      pk.type1 = :GRASS; pk.type2 = :POISON
      pk
    end

    # What one summary page says, drawn first on a summary of Bulby.
    def summary_page(page)
      pk = bulby
      scene = PokemonSummaryScene.new(pk)
      SpeakCapture.clear
      scene.send(page, pk)
      SpeakCapture.log.dup
    end

    # The player's Pokedex: Bulbasaur caught, Ivysaur seen, Venusaur unseen, an Alolan Sandshrew caught.
    def dex_trainer
      $Trainer = DesoWorld::Trainer.new("Ayoub", DesoWorld::Dex.new({
        :BULBASAUR => DesoWorld.row(true, true, "Normal"), :IVYSAUR => DesoWorld.row(true, false, ""),
        :VENUSAUR => DesoWorld.row(false, false, ""), :SANDSHREW => DesoWorld.row(true, true, "Alolan") }), nil, nil)
    end

    # What the Pokedex entry of a species says as it opens.
    def dex_entry(species)
      dex_trainer
      SpeakCapture.clear
      PokemonPokedexScene.new.pbChangeToDexEntry(species)
      SpeakCapture.log.dup
    end

    def desolation_play
      probe(:load_errors) { ERRS }
      probe(:provider) { PokeAccess::Data.active.to_s }
      probe(:missing_hooks) { PokeAccess::Hooks.missing - CORE_MISSING }
      probe(:overrides) { PokeAccess::Hooks.overrides.dup }
      probe(:field_weathers) { (4..8).map { |i| PokeAccess::Battle.overworld_weather_name(i) } }

      probe(:page_one) { summary_page(:drawPageOne) }
      probe(:page_three) { summary_page(:drawPageThree) }
      probe(:page_four) { summary_page(:drawPageFour) }
      probe(:page_five) { summary_page(:drawPageFive) }
      probe(:exp_at_cap) do
        top = DesoPoke.build(:level => 150)
        top.exp = 150 * 150 * 10
        top.growthrate = :Medium
        PokeAccess::Summary.exp_to_next(top)
      end
      probe(:glance) { PokeAccess::Info.pokemon_info(bulby) }

      probe(:dex_rows) do
        dex_trainer
        [[1, :BULBASAUR, "Bulbasaur"], [2, :IVYSAUR, "Ivysaur"], [3, :VENUSAUR, "Venusaur"]].map do |n, sp, name|
          PokeAccess::Menus.dex_row(n, sp, name)
        end
      end
      probe(:entry_caught) { dex_entry(:BULBASAUR) }
      probe(:entry_form) { dex_entry(:SANDSHREW) }
      probe(:entry_seen) { dex_entry(:IVYSAUR) }
      probe(:species_types) { PokeAccess::Data.species_types(:SANDSHREW) }
      probe(:species_entry) { PokeAccess::Data.species_entry(:BULBASAUR) }
      probe(:item_description) { PokeAccess::Data.item_description(:LEFTOVERS) }
      probe(:data_errors) { PokeAccess::Data.errors.dup }

      probe(:form_page) do
        forms = PokedexFormScene.new
        SpeakCapture.clear
        forms.pbStartScene(:BULBASAUR)
        opened = SpeakCapture.log.dup
        SpeakCapture.clear
        forms.pbChooseForm
        [opened, SpeakCapture.log.dup]
      end

      probe(:nest) do
        nest = PokemonNestMapScene.new
        nest.lit = [[7, 17], [12, 14]]
        SpeakCapture.clear
        nest.pbStartScene(:BULBASAUR, -1)
        SpeakCapture.log.dup
      end

      probe(:field_icons) do
        ["<icon=fieldGrass> attacks <icon=fieldUp> x1.5", "Mimicry <icon=fieldChange> <icon=typeQMARK>",
         "<icon=typeFIRE> <icon=fieldplus> <icon=typeDRAGON>", "<icon=fieldPoisonStatus> <icon=fieldPoison>"].map do |note|
          PokeAccess::FieldNotesRV.worded(note)
        end
      end

      probe(:password_rows) { pbSelectPasswordToBeToggled({}, 3) }
      probe(:row_outside_passwords) { PokeAccess::Menus.checkbox_row("> fullivs") }

      probe(:jinx_scent) do
        SpeakCapture.clear
        jinx = Scene_EncounterRate.new
        [jinx.main, jinx.heard]
      end
    end
    desolation_play
  RUBY

  # The process's share of tools/coverage.rb's measure: the mod's line and branch coverage written beside the test
  # processes' own, as test_helper.rb writes it.
  COVERAGE = <<-'RUBY'
    if ENV["PA_COVERAGE"]
      require "coverage"
      require "json"
      Coverage.setup(:lines => true, :branches => true, :eval => true)
      Coverage.resume
      at_exit do
        root = File.expand_path(Dir.pwd).tr("\\", "/") + "/"
        out = {}
        Coverage.result.each do |path, cov|
          rel = path.tr("\\", "/").sub(root, "")
          next unless rel =~ %r{\A(core|games|plugins|loader)/}
          branches = {}
          (cov[:branches] || {}).each { |cond, targets| targets.each { |t, n| branches["#{cond.inspect}|#{t.inspect}"] = n } }
          out[rel] = { "lines" => cov[:lines], "branches" => branches }
        end
        File.write("#{ENV['PA_COVERAGE']}_desolation.json", JSON.generate(out))
      end
    end
  RUBY

  test "loads whole, its files and those of the engine it shares" do
    assert_equal [], played(:load_errors)
  end

  test "serves its data through the provider of the engine it shares" do
    assert_equal "PokeAccess::DataRV", played(:provider)
  end

  test "binds every hook it declares" do
    assert_equal [], played(:missing_hooks)
  end

  test "lists the shared engine's overrides of the summary pages and the checkbox rows under their tags" do
    want = ["PokeAccess::Summary.speak_page (rv_summary)", "PokeAccess::Menus.checkbox_row (rv_passwords)"]
    assert_equal [], want - played(:overrides)
  end

  test "names the overworld weathers by the numbers its events give them, over the stock gen-6 ones" do
    want = [:w_sandstorm, :w_sun, :w_wind, :w_heavy_rain, :w_blizzard].map { |key| t(key) }
    assert_equal want, played(:field_weathers)
  end

  test "the summary's first page names the species, its types, nature and ability the engine keeps as symbols" do
    one = spoken(:page_one)
    [t(:sum_species, :s => "Bulbasaur"), t(:sum_type, :t => "Grass Poison"), t(:sum_nature, :n => "Adamant"),
     t(:sum_ability, :a => "Overgrow")].each { |fact| assert_includes one, fact }
  end

  test "the summary's first page names the ball its header draws" do
    assert_includes spoken(:page_one), t(:sum_ball, :b => "Ultra Ball")
  end

  test "the summary's first page names the held item" do
    assert_includes spoken(:page_one), t(:sum_item, :i => "Leftovers")
  end

  test "the summary's first page says what the next level needs, from the engine's PBExp" do
    assert_includes spoken(:page_one), t(:sum_exp_next, :n => 26 * 26 * 10 - 6500)
  end

  test "has nothing left to say of the next level at the level cap" do
    assert_nil played(:exp_at_cap)
  end

  test "the skills page says what the nature raises and lowers" do
    assert_includes spoken(:page_three), t(:sm_nature_effect, :up => t(:st_atk), :down => t(:st_spatk))
  end

  test "the skills page names the ability with its description, never its id" do
    three = spoken(:page_three)
    assert_includes three, t(:sum_ability_desc, :a => "Overgrow", :d => "Powers up Grass-type moves in a pinch.")
    refute_includes three, "OVERGROW"
  end

  test "the fourth page is the EV and IV page: each stat in the painted order, the nature, the ability as painted" do
    rows = [[:st_hp, 4, 31], [:st_atk, 252, 30], [:st_def, 0, 29], [:st_spatk, 6, 28], [:st_spdef, 0, 27],
            [:st_speed, 248, 26]].map { |key, ev, iv| t(:sm_eviv_row, :stat => t(key), :ev => ev, :iv => iv) }
    nature = t(:sm_nature_effect, :up => t(:st_atk), :down => t(:st_spatk))
    ability = t(:sum_ability_desc, :a => "Overgrow", :d => "Powers up Grass-type moves in a pinch.")
    assert_equal [["#{t(:rv_sum_eviv)}. #{rows.join('. ')}. #{nature} #{ability}", false]], played(:page_four)
  end

  test "the fifth page is the moves page, with no ribbons page after it" do
    move = "Tackle. #{t(:mv_type, :t => 'Normal')}. #{t(:mv_pp, :pp => 30, :tot => 35)}"
    assert_equal [[t(:sm_moves, :list => move), false]], played(:page_five)
  end

  test "the party glance names the held item" do
    glance = played(:glance)
    assert_includes glance, " #{t(:pk_holds, :item => 'Leftovers')}."
    refute_includes glance, "LEFTOVERS"
  end

  test "a Pokedex list row says whether its species is caught, seen or unknown" do
    want = ["1, Bulbasaur, #{t(:dex_caught)}", "2, Ivysaur, #{t(:dex_seen)}", "3, #{t(:dex_unknown)}"]
    assert_equal want, played(:dex_rows)
  end

  test "a caught species' entry says it is caught and its types, among what the page paints" do
    want = "001 Bulbasaur, #{t(:dex_caught)}, Seed Pokemon, #{t(:pdx_type, :t => 'Grass Poison')}, HT, 0.7 m, WT, " \
           "6.9 kg, A strange seed."
    assert_equal [[want, true]], played(:entry_caught)
  end

  test "an entry showing a form says that form's own types" do
    want = "027 Sandshrew, #{t(:dex_caught)}, Mouse Pokemon, #{t(:pdx_type, :t => 'Ice Steel')}, HT, 0.7 m, WT, " \
           "6.9 kg, It burrows."
    assert_equal [[want, true]], played(:entry_form)
  end

  test "an entry of a species only seen says neither caught nor its types" do
    unknown = t(:pdx_unknown_short)
    assert_equal [["002 Ivysaur, #{unknown} Pokemon, HT, #{unknown}, WT, #{unknown}", true]], played(:entry_seen)
  end

  test "answers a species' types from its base form" do
    assert_equal ["Ground"], played(:species_types)
  end

  test "answers a species' Pokedex entry from its base form" do
    assert_equal ["Bulbasaur", "Seed", "A strange seed."], played(:species_entry)
  end

  test "answers an item's description from its data, the game having no getItemDescription" do
    assert_equal "Restores HP every turn.", played(:item_description)
  end

  test "its data provider raises nothing while the screens read it" do
    assert_equal [], played(:data_errors)
  end

  test "the Pokedex form page says what it paints as it opens and again after a choice" do
    opened, chosen = played(:form_page)
    assert_equal [["Bulbasaur, Normal, Gender: Male", true]], opened, "as it opens"
    assert_equal [["Bulbasaur, Normal, Gender: Female", true]], chosen, "after the chooser"
  end

  test "the nest page names the places it lights by the game's place names" do
    assert_includes spoken(:nest), t(:pdx_places, :list => "placeKeneph Beach, placeRedcliff Town")
  end

  test "words a field note's icons: a type's, the unknown type's, a name in another case, a status apart from its type" do
    want = ["#{t(:pdx_type, :t => 'Grass')} attacks #{t(:rv_icon_up)} x1.5",
            "Mimicry #{t(:rv_icon_change)} #{t(:rv_icon_unknown_type)}",
            "#{t(:pdx_type, :t => 'Fire')} #{t(:rv_icon_plus)} #{t(:pdx_type, :t => 'Dragon')}",
            "#{t(:st_poison)} #{t(:pdx_type, :t => 'Poison')}"]
    assert_equal want, played(:field_icons)
  end

  test "says each row of the passwords list with its state, the other rows as painted" do
    assert_equal ["[Exit]", "[Add password]", "fullivs, #{t(:val_on)}", "litemode, #{t(:val_off)}"], played(:password_rows)
  end

  test "keeps a row's marks outside the passwords list" do
    assert_equal "> fullivs", played(:row_outside_passwords)
  end

  test "Jinx Scent says what its picture writes as it opens, before the app runs" do
    assert_equal [:main_done, [[t(:deso_jinx_rate), true]]], played(:jinx_scent)
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A probe's outcome in the profile's process; fails the test when the probe raised or was never reached.
  def played(name)
    found = self.class.outcomes
    flunk "the profile's process never reached #{name}: #{self.class.output[0, 400]}" unless found.key?(name.to_s)
    value = found[name.to_s]
    flunk "#{name} raised in the profile's process: #{value[:probe_raised]}" if value.is_a?(Hash) && value.key?(:probe_raised)
    value
  end

  # The texts a probe's speech log holds, joined.
  def spoken(name)
    played(name).map { |text, _interrupt| text }.join(" ")
  end

  class << self
    # Every probe's outcome by name, the profile's process run once per test process.
    def outcomes
      @outcomes ||= run_profile
    end

    # What the profile's process printed, for a failure's message.
    def output
      outcomes
      @output
    end

    private

    # Runs the world, the load (the core's hooks that do not bind in the stubs noted apart) and the play in a gen-6
    # process, from a file: a script this long does not reach the child whole through a Windows command line.
    def run_profile
      support = File.join(Harness::ROOT, "test", "support")
      script = "#{COVERAGE}\nrequire #{File.join(support, 'harness').inspect}\n" \
               "require #{File.join(support, 'poke_builder').inspect}\n#{WORLD}\n" \
               "Harness.load_dir('core')\nCORE_MISSING = PokeAccess::Hooks.missing.dup\n" \
               "Harness.load_dir('games/desolation')\nERRS = Harness.errors\n" \
               "require #{File.join(support, 'speak_capture').inspect}\n" \
               "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{PLAY}"
      file = Tempfile.new(["pa_desolation", ".rb"])
      begin
        file.write(script)
        file.close
        @output = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, file.path], :err => [:child, :out],
                           :chdir => Harness::ROOT) { |io| io.read }.to_s
      ensure
        file.unlink
      end
      @output.scan(/^PROBE (\S+) (\S*)\r?$/).map { |name, data| [name, Marshal.load(data.unpack1("m0"))] }.to_h
    end
  end
end
