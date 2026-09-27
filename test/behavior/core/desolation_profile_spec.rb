require "rbconfig"
require "tempfile"

# The Desolation profile loaded whole in a process of its own, over a $cache and classes shaped as Desolation's: a plain
# Hash species table with each form's types in formData, a Pokedex of species rows, symbol balls, items, abilities and
# natures, PBExp and no getItemDescription. The core readers of the engine it shares with Reborn and Rejuvenation bind
# there (their overrides would reach every other suite here), and each says what the game paints.
module DesolationProfileSpec
  # The Desolation-shaped data and classes, declared before the toolkit loads so its hooks and its data provider find
  # them.
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
      def main; @heard = SpeakCapture.lines.dup; :main_done; end
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

  # The checks, run after the load inside a method of their own: the toolkit's files are evaluated at the top level,
  # so a local there would be the one their hook blocks assign. Each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    def desolation_checks
    t = PokeAccess::I18n
    check "loads whole", ERRS.empty?, ERRS.first(3)
    check "the engine's provider serves", PokeAccess::Data.active == PokeAccess::DataRV, PokeAccess::Data.active
    mine = %w[PokemonSummaryScene#drawPageFour Scene_EncounterRate#main QuestLog_Scene#pbScene]
    check "every hook of the fixes binds", (PokeAccess::Hooks.missing & mine).empty?, PokeAccess::Hooks.missing & mine
    want = ["PokeAccess::Summary.speak_page (rv_summary)", "PokeAccess::Menus.checkbox_row (rv_passwords)"]
    check "the engine's overrides are declared", (want - PokeAccess::Hooks.overrides).empty?, PokeAccess::Hooks.overrides

    pk = DesoPoke.build(:name => "Bulby", :species => :BULBASAUR, :ability => :OVERGROW, :item => :LEFTOVERS,
                        :nature => :ADAMANT, :moves => [DesoWorld::Move.new(:TACKLE, :NORMAL, 30, 35)],
                        :ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26])
    pk.ballused = :ULTRABALL; pk.exp = 6500; pk.growthrate = :Medium; pk.ot = "Red"; pk.publicID = 12345
    pk.type1 = :GRASS; pk.type2 = :POISON
    sc = PokemonSummaryScene.new(pk)

    SpeakCapture.clear
    sc.drawPageOne(pk)
    one = SpeakCapture.last.to_s
    check "page 1 names the ball the header draws", one.include?(t.t(:sum_ball, :b => "Ultra Ball")), one
    check "and what the next level needs, from PBExp", one.include?(t.t(:sum_exp_next, :n => 26 * 26 * 10 - 6500)), one
    check "and the held item by its name, not its id", one.include?(t.t(:sum_item, :i => "Leftovers")), one
    top = DesoPoke.build(:level => 150)
    top.exp = 150 * 150 * 10; top.growthrate = :Medium
    check "nothing is left to say at the top level", PokeAccess::Summary.exp_to_next(top).nil?, PokeAccess::Summary.exp_to_next(top)

    nature = t.t(:sm_nature_effect, :up => t.t(:st_atk), :down => t.t(:st_spatk))
    ability = t.t(:sum_ability_desc, :a => "Overgrow", :d => "Powers up Grass-type moves in a pinch.")
    SpeakCapture.clear
    sc.drawPageThree(pk)
    three = SpeakCapture.last.to_s
    check "the skills page says what the nature raises and lowers", three.include?(nature), three
    check "and names the ability, not its id", three.include?("Overgrow") && !three.include?("OVERGROW"), three

    SpeakCapture.clear
    sc.drawPageFour(pk)
    rows = [[:st_hp, 4, 31], [:st_atk, 252, 30], [:st_def, 0, 29], [:st_spatk, 6, 28], [:st_spdef, 0, 27], [:st_speed, 248, 26]]
    eviv = t.t(:rv_sum_eviv) + ". " + rows.map { |k, e, i| t.t(:sm_eviv_row, :stat => t.t(k), :ev => e, :iv => i) }.join(". ") +
           ". " + nature + " " + ability
    check "page 4 is the EV & IV page: each stat in the painted order, the nature, the ability and its painted text",
          SpeakCapture.last == eviv, SpeakCapture.lines
    SpeakCapture.clear
    sc.drawPageFive(pk)
    five = SpeakCapture.last.to_s
    check "page 5 is the moves page", five == PokeAccess::Summary.moves_text(pk) && five.include?("Tackle"), five
    check "and says no ribbons", !five.include?(t.t(:sm_ribbons_none)), five
    glance = PokeAccess::Info.pokemon_info(pk).to_s
    check "the party glance names the held item", glance.include?("Leftovers") && !glance.include?("LEFTOVERS"), glance

    $Trainer = DesoWorld::Trainer.new("Ayoub", DesoWorld::Dex.new({
      :BULBASAUR => DesoWorld.row(true, true, "Normal"), :IVYSAUR => DesoWorld.row(true, false, ""),
      :VENUSAUR => DesoWorld.row(false, false, ""), :SANDSHREW => DesoWorld.row(true, true, "Alolan") }), nil, nil)
    row = lambda { |n, name, state| PokeAccess::Verbosity.info_line(:dex_entry, [[n, :brief], [name, :brief], [t.t(state), :medium]]) }
    check "a caught species' list row names it, caught", PokeAccess::Menus.dex_row(1, :BULBASAUR, "Bulbasaur") == row.call("1", "Bulbasaur", :dex_caught),
          PokeAccess::Menus.dex_row(1, :BULBASAUR, "Bulbasaur")
    check "a seen one, seen", PokeAccess::Menus.dex_row(2, :IVYSAUR, "Ivysaur") == row.call("2", "Ivysaur", :dex_seen),
          PokeAccess::Menus.dex_row(2, :IVYSAUR, "Ivysaur")
    check "and only an unseen one is unknown", PokeAccess::Menus.dex_row(3, :VENUSAUR, "Venusaur") == "3, #{t.t(:dex_unknown)}",
          PokeAccess::Menus.dex_row(3, :VENUSAUR, "Venusaur")

    dex = PokemonPokedexScene.new
    SpeakCapture.clear
    dex.pbChangeToDexEntry(:BULBASAUR)
    entry = SpeakCapture.last.to_s
    check "a caught species' entry says so", entry.include?(t.t(:dex_caught)), entry
    check "with its types", entry.include?(t.t(:pdx_type, :t => "Grass Poison")), entry
    SpeakCapture.clear
    dex.pbChangeToDexEntry(:SANDSHREW)
    check "a form's own types where its entry shows that form", SpeakCapture.last.to_s.include?(t.t(:pdx_type, :t => "Ice Steel")),
          SpeakCapture.last
    SpeakCapture.clear
    dex.pbChangeToDexEntry(:IVYSAUR)
    check "a species only seen is neither caught nor typed", !SpeakCapture.last.to_s.include?(t.t(:dex_caught)) &&
          !SpeakCapture.last.to_s.include?("Grass"), SpeakCapture.last
    check "the species table answers the base form's types", PokeAccess::Data.species_types(:SANDSHREW) == ["Ground"],
          PokeAccess::Data.species_types(:SANDSHREW)
    check "and its entry", PokeAccess::Data.species_entry(:BULBASAUR) == ["Bulbasaur", "Seed", "A strange seed."],
          PokeAccess::Data.species_entry(:BULBASAUR)
    check "an item's description comes from its data", PokeAccess::Data.item_description(:LEFTOVERS) == "Restores HP every turn.",
          PokeAccess::Data.item_description(:LEFTOVERS)
    check "and the provider raised nothing", PokeAccess::Data.errors.empty?, PokeAccess::Data.errors

    SpeakCapture.clear
    forms = PokedexFormScene.new
    forms.pbStartScene(:BULBASAUR)
    check "the form page opens saying what it paints", SpeakCapture.lines == ["Bulbasaur, Normal, Gender: Male"], SpeakCapture.lines
    SpeakCapture.clear
    forms.pbChooseForm
    check "and again after a choice", SpeakCapture.lines == ["Bulbasaur, Normal, Gender: Female"], SpeakCapture.lines

    nest = PokemonNestMapScene.new
    nest.lit = [[7, 17], [12, 14]]
    SpeakCapture.clear
    nest.pbStartScene(:BULBASAUR, -1)
    places = [PokeAccess::DexEntry.place_name("Keneph Beach"), PokeAccess::DexEntry.place_name("Redcliff Town")]
    check "the nest page says the places it lights", SpeakCapture.last.to_s.include?(t.t(:pdx_places, :list => places.join(", "))),
          SpeakCapture.lines

    w = PokeAccess::FieldNotesRV
    check "a field icon that paints a type is that type", w.worded("<icon=fieldGrass> attacks <icon=fieldUp> x1.5") ==
          "#{t.t(:pdx_type, :t => 'Grass')} attacks #{t.t(:rv_icon_up)} x1.5", w.worded("<icon=fieldGrass> attacks <icon=fieldUp> x1.5")
    check "the question-mark type is the unknown type", w.worded("Mimicry <icon=fieldChange> <icon=typeQMARK>") ==
          "Mimicry #{t.t(:rv_icon_change)} #{t.t(:rv_icon_unknown_type)}", w.worded("Mimicry <icon=fieldChange> <icon=typeQMARK>")
    check "an icon named in another case is still known", w.worded("<icon=typeFIRE> <icon=fieldplus> <icon=typeDRAGON>") ==
          "#{t.t(:pdx_type, :t => 'Fire')} #{t.t(:rv_icon_plus)} #{t.t(:pdx_type, :t => 'Dragon')}",
          w.worded("<icon=typeFIRE> <icon=fieldplus> <icon=typeDRAGON>")
    check "the poison status icon stays the status", w.worded("<icon=fieldPoisonStatus> <icon=fieldPoison>") ==
          "#{t.t(:st_poison)} #{t.t(:pdx_type, :t => 'Poison')}", w.worded("<icon=fieldPoisonStatus> <icon=fieldPoison>")

    on = t.t(:val_on)
    off = t.t(:val_off)
    check "each password is said with its state", pbSelectPasswordToBeToggled({}, 3) ==
          ["[Exit]", "[Add password]", "fullivs, #{on}", "litemode, #{off}"], pbSelectPasswordToBeToggled({}, 3)
    check "and outside the list a row keeps its marks", PokeAccess::Menus.checkbox_row("> fullivs") == "> fullivs", nil

    SpeakCapture.clear
    jinx = Scene_EncounterRate.new
    jinx.main
    check "Jinx Scent says what its picture writes as it opens", jinx.heard == [t.t(:deso_jinx_rate)], jinx.heard
    end
    desolation_checks
  RUBY

  # Runs the world, the load and the checks in a gen-6 process, from a file (a script this long does not reach the
  # child whole through a Windows command line): [[label, ok, detail], ...], or the raw output.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n" \
             "require #{File.join(support, 'poke_builder').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('desolation')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    file = Tempfile.new(["pa_desolation", ".rb"])
    begin
      file.write(script)
      file.close
      env = { "PA_ENGINE" => "gen6" }
      out = IO.popen([env, RbConfig.ruby, file.path], :err => [:child, :out], :chdir => Harness::ROOT) { |io| io.read }
    ensure
      file.unlink
    end
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  end
end

Suite.define("desolation profile: loaded whole over Desolation-shaped data, the engine's readers say what it paints") do
  rows = DesolationProfileSpec.run
  if rows.is_a?(String)
    truthy "the profile process ran its checks: #{rows[0, 300]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 35
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
