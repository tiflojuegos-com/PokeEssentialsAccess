require "rbconfig"
require "tempfile"

# The Reborn profile and the engine's readers (games/rv_common) over a Reborn-shaped $cache and screens, in a process of
# their own: summary pages, credits, final battle box, Inspect report, ticket, Dex certificate and Theme Teams pick.
class RebornProfileTest < PokeAccessTest
  # The Reborn-shaped world, declared before the toolkit loads so its data provider registers and its hooks find them.
  WORLD = <<-'RUBY'
    module RebornWorld
      Nature = Struct.new(:name, :incStat, :decStat)
      Ability = Struct.new(:name, :fullName, :desc, :fullDesc)
      Move = Struct.new(:name, :type, :category, :basedamage, :accuracy, :maxpp, :desc)
      Named = Struct.new(:name)
      Cache = Struct.new(:pkmn, :moves, :abil, :natures, :types, :items)
      PartyMove = Struct.new(:move, :pp, :totalpp, :type)
      Mon = Struct.new(:name, :level, :ability, :nature, :ev, :iv, :moves, :zmoves, :hp, :totalhp, :attack, :defense,
                       :spatk, :spdef, :speed, :item)
      SHORT = "Powers up Fire-type moves if hit by one..."
      FULL = "Powers up Fire-type moves if the Pokemon is hit by a Fire-type move, and makes it immune to them."
    end
    $cache = RebornWorld::Cache.new({},
      { :EMBER => RebornWorld::Move.new("Ember", :FIRE, :special, 40, 100, 25, "A small flame."),
        :TACKLE => RebornWorld::Move.new("Tackle", :NORMAL, :physical, 40, 100, 35, "A full-body charge."),
        :INFERNOOVERDRIVE => RebornWorld::Move.new("Inferno Overdrive", :FIRE, :special, 1, 0, 1, "A Z-Move.") },
      { :FLASHFIRE => RebornWorld::Ability.new("Flash Fire", "Flash Fire", RebornWorld::SHORT, RebornWorld::FULL) },
      { :LONELY => RebornWorld::Nature.new("Lonely", 1, 2) },
      { :FIRE => RebornWorld::Named.new("Fire"), :NORMAL => RebornWorld::Named.new("Normal") }, {})
    def getMoveName(m); $cache.moves[m] ? $cache.moves[m].name : ""; end
    def getMoveDesc(m); $cache.moves[m] ? $cache.moves[m].desc : ""; end
    def getTypeName(t); $cache.types[t] ? $cache.types[t].name : ""; end
    def getAbilityName(a, short = false); $cache.abil[a] ? $cache.abil[a].fullName : ""; end
    def getAbilityDesc(a); $cache.abil[a] ? $cache.abil[a].fullDesc : ""; end
    def getNatureName(n); $cache.natures[n] ? $cache.natures[n].name : ""; end
    def getItemName(i); i == :CHARCOAL ? "Charcoal" : ""; end
    def getMonName(s, f = 0); s.to_s; end

    def tts(text, _interrupt = false); text; end
    def pbTicketText(n); pbDrawTextPositions(nil, [[["Ame", "Female", "8R750"][n], 100, 198, 0, nil, nil]]); end
    def pbDexCert
      return pbDrawTextPositions(nil, []) if $reb_blank_cert
      pbDrawTextPositions(nil, [["45:10", 344, 290, 0, nil, nil], ["Ame", 320, 38, 0, nil, nil]])
    end
    def canCheckFieldApp?(notes); notes != []; end
    def canCheckPulseDex?(notes); !notes.nil? && notes != []; end
    def pbShowInspect(_msgwindow, _commands, _cancel); :inspected; end
    def pbShowBattleStats; :stats; end
    RebornWorld::Box = Struct.new(:text)

    RebornWorld::Arrow = Struct.new(:gone) do
      def dispose; self.gone = true; end
      def disposed?; gone ? true : false; end
    end
    RebornWorld::PICK_KEYS = []

    # The Theme Teams pick as the game writes it: its names, pick and arrow in locals, a frame loop that moves the
    # pick by the keys RebornWorld::PICK_KEYS lists (the left key's step through -1, as the game's), and no text.
    def pbShowThemeTeams(partnerPickin, total_trainers_needed = 1, randomized = false)
      sprites = {}
      sprites["index"] = 0
      trainernames = []
      trainernames.push("Julia") if $game_switches[1307]
      trainernames.push("Shelly") if $game_switches[1309]
      trainernames.push("Cain") if $game_switches[1330]
      return false if trainernames.length < total_trainers_needed
      sprites["arrow"] = RebornWorld::Arrow.new(false)
      RebornWorld::PICK_KEYS.each do |key|
        Graphics.update
        Input.update
        if key == :left
          sprites["index"] -= 1
          sprites["index"] = trainernames.length - 1 if sprites["index"] < 0
        elsif key == :right
          sprites["index"] += 1
          sprites["index"] = 0 if sprites["index"] > trainernames.length - 1
        elsif key == :cancel
          sprites["arrow"].dispose
          $game_variables[29] = 0
          return false
        elsif key == :pick
          sprites["arrow"].dispose
          $game_variables[28] = trainernames[sprites["index"]]
          break
        end
      end
      true
    end

    class Scene_Credits
      CREDIT = ["Core Development", "<L> congratulations!"].join($/)
      CREDIT1 = "Story"
      CREDIT2 = "Art"
      CREDIT3 = ["Special Thanks", "<L><left> omg, wow", "<A><right> Thanks to everyone", "<T> Terra's line",
                 "<H> Shade's line", "Supporters<s>Patrons"].join($/)
      CREDIT4 = "Music"
      CREDIT5 = "Testers"
    end

    class PokemonSummaryScene
      def drawPageThree(pk = nil)
        (@pokemon = pk) if pk
        pbDrawTextPositions(nil, [["SKILLS", 26, 16], ["Ability", 224, 284], ["Flash Fire", 362, 284]])
        drawTextEx(nil, 224, 316, 282, 2, RebornWorld::SHORT)
      end

      def drawPageFour(pk = nil)
        (@pokemon = pk) if pk
        pbDrawTextPositions(nil, [["EV & IV", 26, 16], ["HP", 292, 76], [" 12/ 31", 462, 76], ["Ability", 224, 284],
                                  ["Flash Fire", 362, 284]])
        drawTextEx(nil, 224, 316, 282, 2, RebornWorld::SHORT)
      end

      def drawAbilPage(pk)
        @pokemon = pk
        pbDrawTextPositions(nil, [["ABILITY", 26, 16], [pk.name, 46, 62]])
        memo = ["<c3=F8F8F8,686868>Ability:<c3=404040,B0B0B0>", "<c3=404040,B0B0B0>Flash Fire",
                "<c3=F8F8F8,686868>Description:", "<c3=404040,B0B0B0>" + RebornWorld::FULL].join($/)
        drawFormattedTextEx(nil, 232, 78, 272, memo)
      end

      def paint_moves_column
        pbDrawImagePositions(nil, [["Graphics/Icons/typeFIRE", 248, 100, 0, 0, 64, 28],
                                   ["Graphics/Icons/typeNORMAL", 248, 164, 0, 0, 64, 28]])
        drawTextEx(nil, 316, 95, 174, 2, "Inferno Overdrive")
        pbDrawTextPositions(nil, [["Tackle", 316, 162], ["PP", 342, 194], ["20/35", 460, 194], ["-", 316, 226],
                                  ["--", 442, 258]])
      end

      def drawZMovePage(pk)
        @pokemon = pk
        pbDrawTextPositions(nil, [["MOVES", 26, 16], [pk.name, 46, 62]])
        paint_moves_column
        pbDrawImagePositions(nil, [["Graphics/Pictures/Summary/summary5movebtn", 324, 60, 0, 0, -1, -1]])
      end

      # The detail of the Z-move under the cursor; RebornWorld::FIGURES holds the power and accuracy it paints.
      def drawSelectedZeeMove(pk, _base, _z)
        @pokemon = pk
        pbDrawTextPositions(nil, [["MOVES", 26, 16], ["CATEGORY", 20, 122], ["POWER", 20, 154], ["ACCURACY", 20, 186]])
        paint_moves_column
        power, accuracy = RebornWorld::FIGURES
        pbDrawTextPositions(nil, [[power, 216, 154], [accuracy, 216, 186]])
        pbDrawImagePositions(nil, [["Graphics/Pictures/category", 166, 124, 0, 28, 64, 28]])
        drawTextEx(nil, 4, 218, 238, 5, "Dives into flames to strike.")
      end
    end
    RebornWorld::FIGURES = ["175", "---"]
  RUBY

  # The scenes, each a method of RebornScenes whose plain-data value is reported under its name; each starts from the
  # mod's state reset and an empty speech log.
  SCENES = <<-'RUBY'
    # What the scenes share: the speech taken as it was said, and the screens worked as the game works them.
    module Stage
      # The [text, interrupt] pairs spoken since the last call; the log starts afresh.
      def self.heard
        out = SpeakCapture.log.map { |text, interrupt| [text, interrupt] }
        SpeakCapture.clear
        out
      end

      # A Vulpix holding a symbol item, with two moves and one Z-move; zmoves replaces its Z-moves.
      def self.vulpix(zmoves = [RebornWorld::PartyMove.new(:INFERNOOVERDRIVE, 1, 1, :FIRE), nil])
        moves = [RebornWorld::PartyMove.new(:EMBER, 20, 25, :FIRE), RebornWorld::PartyMove.new(:TACKLE, 35, 35, :NORMAL)]
        RebornWorld::Mon.new("Vulpix", 20, :FLASHFIRE, :LONELY, [12, 0, 0, 0, 0, 4], [31, 20, 10, 5, 0, 1], moves, zmoves,
                             40, 40, 20, 18, 30, 25, 33, :CHARCOAL)
      end

      # What a summary page read: the scene drawn fresh, the page's method called with the Pokemon.
      def self.page(meth, pk = vulpix)
        PokemonSummaryScene.new(pk).send(meth, pk)
        heard
      end

      # The Z-move detail painted with the given power and accuracy figures.
      def self.zmove_detail(figures)
        RebornWorld::FIGURES.replace(figures)
        pk = vulpix
        PokemonSummaryScene.new(pk).drawSelectedZeeMove(pk, :EMBER, :INFERNOOVERDRIVE)
        { :heard => heard, :info => PokeAccess::Info.info_text }
      ensure
        RebornWorld::FIGURES.replace(["175", "---"])
      end

      # The credits roll read with variable 747 at roll, Anna smiling or not and switch 1941 as given.
      def self.credits(roll, anna, switch)
        $game_variables[747] = roll
        $game_switches[:Anna_Smiles] = anna
        $game_switches[1941] = switch
        PokeAccess::Credits.lines(Scene_Credits.new)
      end

      # An Inspect report: the predicates asked before the report starts, then those asked while it runs, as
      # [field notes, PULSE Dex] answers (nil: not asked).
      def self.inspect(before, during)
        ask(before)
        pbShowBattleStats
        ask(during)
        heard
        pbShowInspect(RebornWorld::Box.new("Inspecting Lapras:"), ["Type: Water"], 1)
        { :heard => heard, :info => PokeAccess::Info.info_text }
      end

      # The button predicates asked with notes that make each answer as given (nil: not asked).
      def self.ask(answers)
        field, pulse = answers
        canCheckFieldApp?(field ? [:ELECTERRAIN] : []) unless field.nil?
        canCheckPulseDex?(pulse ? [:MAGNEZONE] : []) unless pulse.nil?
      end

      # The Theme Teams pick run over keys, with the trainers on offer: what it said, what it returned and the trainer
      # picked, and what the next frame said after it ended.
      def self.theme_teams(keys, needed = 1)
        [1307, 1309, 1330].each { |s| $game_switches[s] = true }
        RebornWorld::PICK_KEYS.replace(keys)
        result = pbShowThemeTeams(false, needed)
        said = heard
        Input.update
        { :heard => said, :result => result, :picked => $game_variables[28], :after => heard }
      ensure
        RebornWorld::PICK_KEYS.clear
      end
    end

    module RebornScenes
      def self.load
        { :errors => ERRS }
      end

      def self.held_item
        pk = Stage.vulpix
        { :fact => PokeAccess::Summary.item_fact(pk), :glance => PokeAccess::Info.pokemon_info(pk) }
      end

      def self.skills_page
        { :heard => Stage.page(:drawPageThree) }
      end

      def self.eviv_page
        { :heard => Stage.page(:drawPageFour) }
      end

      def self.moves_page
        pk = Stage.vulpix
        { :heard => Stage.page(:drawPageFive, pk) }
      end

      def self.moves_page_without_zmoves
        pk = Stage.vulpix([nil, nil])
        { :heard => Stage.page(:drawPageFive, pk) }
      end

      def self.moves_page_brief
        PokeAccess::Config.verbosity = :brief
        pk = Stage.vulpix
        { :heard => Stage.page(:drawPageFive, pk) }
      end

      def self.ability_page
        { :heard => Stage.page(:drawAbilPage) }
      end

      def self.zmoves_page
        { :heard => Stage.page(:drawZMovePage) }
      end

      def self.zmove_detail
        Stage.zmove_detail(["175", "---"])
      end

      def self.zmove_detail_figures
        Stage.zmove_detail(["???", "90"])
      end

      def self.credits
        { :rolls => (0..5).map { |roll| Stage.credits(roll, false, false) }, :anna => Stage.credits(3, true, false),
          :switch => Stage.credits(3, false, true) }
      end

      def self.final_battle_levels
        battler = Struct.new(:index, :level)
        boxes = [0, 1, 2, 3].map { |i| battler.new(i, 100) }
        $game_switches[:Level_999] = true
        on = boxes.map { |b| PokeAccess::Battle.shown_level(b) }
        $game_switches[:Level_999] = false
        { :on => on, :off => boxes.map { |b| PokeAccess::Battle.shown_level(b) } }
      end

      def self.inspect_field_notes
        Stage.inspect([nil, nil], [true, false])
      end

      def self.inspect_pulse_dex
        Stage.inspect([nil, nil], [false, true])
      end

      def self.inspect_both
        Stage.inspect([nil, nil], [true, true])
      end

      def self.inspect_stale
        Stage.inspect([true, true], [nil, nil])
      end

      def self.inspect_again
        Stage.inspect([nil, nil], [true, false])
        pbShowInspect(RebornWorld::Box.new("Inspecting Lapras:"), ["Type: Water"], 1)
        { :heard => Stage.heard, :info => PokeAccess::Info.info_text }
      end

      def self.inspect_brief
        PokeAccess::Config.verbosity = :brief
        Stage.inspect([nil, nil], [true, false])
      end

      def self.inspect_remapped
        PokeAccess::Config.rebinds = { :y => 0x46 }
        Stage.inspect([nil, nil], [true, false])
      end

      def self.ticket_field
        pbTicketText(2)
        { :heard => Stage.heard }
      end

      def self.ticket_read_out
        ["Train: 8R750", "Seat: 5D", "Destination: Grandview Station", "Adult: One"].each { |line| tts(line) }
        { :heard => Stage.heard }
      end

      def self.dex_certificate
        pbDexCert
        { :heard => Stage.heard }
      end

      def self.blank_dex_certificate
        $reb_blank_cert = true
        pbDexCert
        { :heard => Stage.heard }
      ensure
        $reb_blank_cert = nil
      end

      def self.theme_teams
        Stage.theme_teams([nil, :left, :left, :right, :pick])
      end

      def self.theme_teams_short
        Stage.theme_teams([nil, :pick], 4)
      end

      def self.theme_teams_cancel
        Stage.theme_teams([nil, :right, :cancel])
      end

      def self.theme_teams_twice
        Stage.theme_teams([nil, :left, :pick])
        Stage.theme_teams([nil, :right, :pick])
      end
    end

    RebornScenes.singleton_methods(false).sort.each do |name|
      Reset.before_test
      outcome = begin
        [:ok, RebornScenes.send(name)]
      rescue StandardError, ScriptError, SystemStackError => e
        [:error, "#{e.class}: #{e.message} at #{(e.backtrace || []).first(3).join(' < ')}"]
      end
      puts "REPORT #{name} #{[Marshal.dump(outcome)].pack('m0')}"
    end
    nets = { :raw_codes => SpeakCapture.raw_offenders.map { |_test, text| text }, :arity => ArityNet.offenders }
    puts "REPORT nets #{[Marshal.dump([:ok, nets])].pack('m0')}"
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
        File.write("#{ENV['PA_COVERAGE']}_reborn_profile.json", JSON.generate(out))
      end
    end
  RUBY

  # The ability descriptions the world paints: the stats pages' short one and the ability page's full one.
  SHORT = "Powers up Fire-type moves if hit by one..."
  FULL = "Powers up Fire-type moves if the Pokemon is hit by a Fire-type move, and makes it immune to them."

  test "loads whole, with no load error" do
    assert_equal [], observed(:load)[:errors]
  end

  test "no text of these screens reaches speech with raw control codes" do
    assert_equal [], observed(:nets)[:raw_codes]
  end

  test "no one-parameter block of the mod is handed several values on these screens" do
    assert_equal [], observed(:nets)[:arity]
  end

  test "a held item kept as a symbol is named on the summary, not spelled as its id" do
    assert_equal t(:sum_item, :i => "Charcoal"), observed(:held_item)[:fact]
  end

  test "a held item kept as a symbol is named at a glance of the party" do
    glance = "#{t(:pk_glance, :name => 'Vulpix', :level => 20, :hp => 40, :tot => 40)} #{t(:pk_holds, :item => 'Charcoal')}."
    assert_equal glance, observed(:held_item)[:glance]
  end

  test "the skills page says the stats, the stats the nature's colours mark and the description painted under the ability" do
    stats = t(:sum_stats, :hp => 40, :tot => 40, :atk => 20, :def => 18, :spa => 30, :spd => 25, :spe => 33)
    assert_equal [["#{t(:sm_stats)}. #{stats} #{nature_effect} #{short_ability}", false]], observed(:skills_page)[:heard]
  end

  test "the fourth page is the EV & IV page: each stat's EV and IV in the painted order, the nature and the ability" do
    rows = [[:st_hp, 12, 31], [:st_atk, 0, 20], [:st_def, 0, 10], [:st_spatk, 0, 5], [:st_spdef, 0, 0], [:st_speed, 4, 1]]
    rows = rows.map { |stat, ev, iv| t(:sm_eviv_row, :stat => t(stat), :ev => ev, :iv => iv) }
    page = "#{t(:rv_sum_eviv)}. #{rows.join('. ')}. #{nature_effect} #{short_ability}"
    assert_equal [[page, false]], observed(:eviv_page)[:heard]
  end

  test "the fifth page is the moves, then the key to the Z-moves its button offers" do
    page = "#{moves_line(true)}. #{t(:rv_sum_to_zmoves, :key => 'A')}"
    assert_equal [[page, false]], observed(:moves_page)[:heard]
  end

  test "a Pokemon with no Z-move gets no Z-moves key on its moves page" do
    assert_equal [[moves_line(true), false]], observed(:moves_page_without_zmoves)[:heard]
  end

  test "the moves page leaves the Z-moves key out while key hints are not said" do
    assert_equal [[moves_line(false), false]], observed(:moves_page_brief)[:heard]
  end

  test "the ability page reads its box, each label with its line" do
    assert_equal [["Ability: Flash Fire. Description: #{FULL}", false]], observed(:ability_page)[:heard]
  end

  test "the Z-moves page reads each slot as painted, the empty one left out, then the key back to the moves" do
    slots = ["Inferno Overdrive. #{t(:mv_type, :t => 'Fire')}",
             "Tackle. #{t(:mv_type, :t => 'Normal')}. #{t(:mv_pp, :pp => 20, :tot => 35)}"]
    page = "#{t(:rv_sum_zmoves, :list => slots.join(', '))}. #{t(:rv_sum_to_moves, :key => 'A')}"
    assert_equal [[page, false]], observed(:zmoves_page)[:heard]
  end

  test "the Z-move detail says its name, type, category, power, accuracy and description as painted, cutting in" do
    assert_equal [[zmove_detail(t(:mv_power, :p => 175), t(:mv_acc, :a => t(:mv_acc_perfect))), true]],
                 observed(:zmove_detail)[:heard]
  end

  test "the Z-move detail words a varying power and an accuracy painted as a figure" do
    assert_equal [[zmove_detail(t(:mv_power, :p => t(:mv_power_var)), t(:mv_acc, :a => 90)), true]],
                 observed(:zmove_detail_figures)[:heard]
  end

  test "the info key keeps the Z-move detail" do
    assert_equal zmove_detail(t(:mv_power, :p => 175), t(:mv_acc, :a => t(:mv_acc_perfect))), observed(:zmove_detail)[:info]
  end

  test "the credits read the roll variable 747 picks, Anna's and Shade's lines left out while she has not smiled" do
    want = [["Core Development", "congratulations!"], ["Story"], ["Art"],
            ["Special Thanks", "omg, wow", "Terra's line", "Supporters, Patrons"], ["Music"], ["Testers"]]
    assert_equal want, observed(:credits)[:rolls]
  end

  test "once Anna smiles the credits leave out Lin's and Terra's lines instead" do
    assert_equal ["Special Thanks", "Thanks to everyone", "Shade's line", "Supporters, Patrons"], observed(:credits)[:anna]
  end

  test "with switch 1941 on the credits keep Anna's and Shade's lines before she smiles" do
    want = ["Special Thanks", "omg, wow", "Thanks to everyone", "Terra's line", "Shade's line", "Supporters, Patrons"]
    assert_equal want, observed(:credits)[:switch]
  end

  test "in the final battle a foe's box says the 999 it paints, the player's side its own level" do
    assert_equal [100, 999, 100, 999], observed(:final_battle_levels)[:on]
  end

  test "in any other battle every box says the real level" do
    assert_equal [100, 100, 100, 100], observed(:final_battle_levels)[:off]
  end

  test "the Inspect report says, queued, the field notes button it paints" do
    assert_equal [[field_notes, false]], observed(:inspect_field_notes)[:heard]
  end

  test "the info key says the Inspect report whole, the message first, then the buttons painted" do
    assert_equal "Inspecting Lapras: Type: Water. #{field_notes}", observed(:inspect_field_notes)[:info]
  end

  test "the Inspect report says the PULSE Dex button when only that one is painted" do
    assert_equal [[pulse_dex, false]], observed(:inspect_pulse_dex)[:heard]
  end

  test "the Inspect report says both buttons in the order they sit" do
    assert_equal [["#{field_notes}. #{pulse_dex}", false]], observed(:inspect_both)[:heard]
  end

  test "the info key keeps both of the Inspect report's buttons, in the order they sit" do
    assert_equal "Inspecting Lapras: Type: Water. #{field_notes}. #{pulse_dex}", observed(:inspect_both)[:info]
  end

  test "answers given before the Inspect report started paint no button in it" do
    seen = observed(:inspect_stale)
    assert_equal [], seen[:heard]
    assert_equal "Inspecting Lapras: Type: Water", seen[:info]
  end

  test "a second Inspect report with no new answers paints no button" do
    seen = observed(:inspect_again)
    assert_equal [], seen[:heard]
    assert_equal "Inspecting Lapras: Type: Water", seen[:info]
  end

  test "the Inspect report's buttons are not said while key hints are not, but the info key keeps them" do
    seen = observed(:inspect_brief)
    assert_equal [], seen[:heard]
    assert_equal "Inspecting Lapras: Type: Water. #{field_notes}", seen[:info]
  end

  test "the Inspect report's hint names the key the player moved the field notes button to" do
    assert_equal [[t(:rv_inspect_field_notes, :key => "F"), false]], observed(:inspect_remapped)[:heard]
  end

  test "each field of the intro's ticket is said, queued, as it is written" do
    assert_equal [["8R750", false]], observed(:ticket_field)[:heard]
  end

  test "the ticket the game's reader reads out is said whole, its first line cutting in, the rest queued" do
    want = [["Train: 8R750", true], ["Seat: 5D", false], ["Destination: Grandview Station", false], ["Adult: One", false]]
    assert_equal want, observed(:ticket_read_out)[:heard]
  end

  test "the Pokedex certificate says, queued, what is written on it, top to bottom" do
    assert_equal [[t(:reb_dex_cert, :rows => "Ame, 45:10"), false]], observed(:dex_certificate)[:heard]
  end

  test "a Pokedex certificate with nothing written on it says nothing" do
    assert_equal [], observed(:blank_dex_certificate)[:heard]
  end

  test "the Theme Teams pick says the trainer under its arrow as it is drawn, queued, and after each move, cutting in" do
    want = [[entry("Julia", 1), false], [entry("Cain", 3), true], [entry("Shelly", 2), true], [entry("Cain", 3), true]]
    assert_equal want, observed(:theme_teams)[:heard]
  end

  test "the Theme Teams pick runs as it would" do
    seen = observed(:theme_teams)
    assert_equal true, seen[:result]
    assert_equal "Cain", seen[:picked]
  end

  test "once the Theme Teams pick is over the frame poll says nothing" do
    assert_equal [], observed(:theme_teams)[:after]
  end

  test "a Theme Teams pick short of trainers ends before any arrow, silent" do
    seen = observed(:theme_teams_short)
    assert_equal false, seen[:result]
    assert_equal [], seen[:heard]
  end

  test "a cancelled Theme Teams pick is read up to the cancel, and the frame poll says nothing after it" do
    seen = observed(:theme_teams_cancel)
    assert_equal [[entry("Julia", 1), false], [entry("Shelly", 2), true]], seen[:heard]
    assert_equal [], seen[:after]
  end

  test "a cancelled Theme Teams pick returns as the game's does" do
    assert_equal false, observed(:theme_teams_cancel)[:result]
  end

  test "a second Theme Teams pick starts afresh, its first line queued" do
    assert_equal [[entry("Julia", 1), false], [entry("Shelly", 2), true]], observed(:theme_teams_twice)[:heard]
  end

  # The scenes' outcomes from one run of the profile's process, shared by the class's tests: { name => [status,
  # value] }, and the raw output under :raw.
  def self.reports
    @reports ||= begin
      out = profile_output
      found = { :raw => out }
      out.scan(/^REPORT (\w+) (\S+)$/) { |name, data| found[name.to_sym] = Marshal.load(data.unpack1("m0")) }
      found
    end
  end

  # The output of a gen-6 process that measures its coverage when asked, declares the world, loads the toolkit with
  # the profile and plays the scenes, run from a file (a script this long does not reach the child whole through a
  # Windows command line) in the mod's folder, where the lang files are.
  def self.profile_output
    needs = %w[speak_capture reset arity_net].map { |f| "require #{File.join(Harness::ROOT, 'test', 'support', f).inspect}" }
    script = [COVERAGE, "require #{File.join(Harness::ROOT, 'test', 'support', 'harness').inspect}", WORLD,
              "ERRS = Harness.load_all('reborn')", needs, "SpeakCapture.install", SCENES].flatten.join("\n")
    file = Tempfile.new(["pa_reborn_profile", ".rb"])
    begin
      file.write(script)
      file.close
      IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, file.path], :err => [:child, :out], :chdir => Harness::ROOT) do |io|
        io.read
      end.to_s
    ensure
      file.unlink
    end
  end
  private_class_method :profile_output

  private

  # What the scene of that name observed; a scene that raised, or never ran, fails the test.
  def observed(name)
    reports = self.class.reports
    status, value = reports.fetch(name) { flunk "the profile's process reported no #{name}: #{reports[:raw][0, 800]}" }
    flunk "#{name} raised in the profile's process: #{value}" unless status == :ok
    value
  end

  # The Spanish text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The line for the stats Vulpix's Lonely nature raises and lowers.
  def nature_effect
    t(:sm_nature_effect, :up => t(:st_atk), :down => t(:st_def))
  end

  # Flash Fire with the short description the stats pages paint under it.
  def short_ability
    t(:sum_ability_desc, :a => "Flash Fire", :d => SHORT)
  end

  # Vulpix's moves line, with each move's type where the reading says types.
  def moves_line(types)
    moves = [["Ember", "Fire", 20, 25], ["Tackle", "Normal", 35, 35]].map do |name, type, pp, tot|
      [name, (t(:mv_type, :t => type) if types), t(:mv_pp, :pp => pp, :tot => tot)].compact.join(". ")
    end
    t(:sm_moves, :list => moves.join(", "))
  end

  # The Z-move detail line with the power and accuracy as worded.
  def zmove_detail(power, accuracy)
    ["Inferno Overdrive", t(:mv_type, :t => "Fire"), t(:cat_special), power, accuracy, "Dives into flames to strike."].join(". ")
  end

  # A trainer of the three the Theme Teams pick offers, said with its place among them.
  def entry(name, n)
    t(:list_entry, :name => name, :n => n, :tot => 3)
  end

  # The hints of the Inspect report's two buttons.
  def field_notes; t(:rv_inspect_field_notes, :key => "S"); end
  def pulse_dex; t(:rv_inspect_pulse_dex, :key => "D"); end
end
