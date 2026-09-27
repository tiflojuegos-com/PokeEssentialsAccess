require "rbconfig"

# The Reborn profile loaded whole in a process of its own, over a $cache and screens shaped as Reborn's: the engine's
# readers (games/rv_common) bind only where such a $cache answers, and the profile's overrides would reach every
# other suite here. The summary puts each reading on the page drawn (EV & IV fourth, the moves fifth, no ribbons) and reads its
# ability page, its Z-moves page and each Z-move's detail as painted; the credits read the roll that runs, the final
# battle's box its level, the Inspect report its buttons, the intro's ticket and the Pokedex certificate what they
# write, and the Theme Teams pick the trainer under its arrow, from the pick's own locals.
module RebornProfileSpec
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
    def pbDexCert; pbDrawTextPositions(nil, [["45:10", 344, 290, 0, nil, nil], ["Ame", 320, 38, 0, nil, nil]]); end
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
      CREDIT3 = ["Special Thanks", "<L><left> omg, wow", "<A><right> Thanks to everyone", "Supporters<s>Patrons"].join($/)
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
        pbDrawTextPositions(nil, [["Tackle", 316, 162], ["PP", 342, 194], ["35/35", 460, 194], ["-", 316, 226],
                                  ["--", 442, 258]])
      end

      def drawZMovePage(pk)
        @pokemon = pk
        pbDrawTextPositions(nil, [["MOVES", 26, 16], [pk.name, 46, 62]])
        paint_moves_column
        pbDrawImagePositions(nil, [["Graphics/Pictures/Summary/summary5movebtn", 324, 60, 0, 0, -1, -1]])
      end

      def drawSelectedZeeMove(pk, _base, _z)
        @pokemon = pk
        pbDrawTextPositions(nil, [["MOVES", 26, 16], ["CATEGORY", 20, 122], ["POWER", 20, 154], ["ACCURACY", 20, 186]])
        paint_moves_column
        pbDrawTextPositions(nil, [["175", 216, 154], ["---", 216, 186]])
        pbDrawImagePositions(nil, [["Graphics/Pictures/category", 166, 124, 0, 28, 64, 28]])
        drawTextEx(nil, 4, 218, 238, 5, "Dives into flames to strike.")
      end
    end
  RUBY

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    t = PokeAccess::I18n
    check "loads whole", ERRS.empty?, ERRS.first(3)
    check "the engine's data provider serves", PokeAccess::Data.active == PokeAccess::DataRV, PokeAccess::Data.active
    mine = %w[PokemonSummaryScene#drawAbilPage PokemonSummaryScene#drawZMovePage PokemonSummaryScene#drawSelectedZeeMove]
    check "every summary hook of the engine binds", (PokeAccess::Hooks.missing & mine).empty?, PokeAccess::Hooks.missing
    check "its page override is declared", PokeAccess::Hooks.overrides.include?("PokeAccess::Summary.speak_page (rv_summary)"),
          PokeAccess::Hooks.overrides

    pk = RebornWorld::Mon.new("Vulpix", 20, :FLASHFIRE, :LONELY, [12, 0, 0, 0, 0, 4], [31, 20, 10, 5, 0, 1],
                              [RebornWorld::PartyMove.new(:EMBER, 20, 25, :FIRE), RebornWorld::PartyMove.new(:TACKLE, 35, 35, :NORMAL)],
                              [RebornWorld::PartyMove.new(:INFERNOOVERDRIVE, 1, 1, :FIRE), nil], 40, 40, 20, 18, 30, 25, 33,
                              :CHARCOAL)
    sc = PokemonSummaryScene.new(pk)
    check "a held item kept as a symbol is named, not spelled as its id",
          PokeAccess::Summary.item_fact(pk) == t.t(:sum_item, :i => "Charcoal"), PokeAccess::Summary.item_fact(pk)
    glance = PokeAccess::Info.pokemon_info(pk).to_s
    check "and so is it at a glance of the party", glance.include?(t.t(:pk_holds, :item => "Charcoal")), glance
    effect = t.t(:sm_nature_effect, :up => t.t(:st_atk), :down => t.t(:st_def))
    SpeakCapture.clear
    sc.drawPageThree(pk)
    skills = SpeakCapture.last.to_s
    check "the skills page says which stats the nature's colours mark", skills.include?(effect), skills
    check "and the short description it paints under the ability",
          skills.include?(t.t(:sum_ability_desc, :a => "Flash Fire", :d => RebornWorld::SHORT)), skills

    sc.drawPageFour(pk)
    eviv = SpeakCapture.last.to_s
    check "the fourth page is the EV & IV page, not the moves", eviv.index(t.t(:rv_sum_eviv)) == 0 &&
          !eviv.include?(t.t(:sm_moves, :list => "")), eviv
    check "each stat's EV and IV, Speed last", eviv.include?(t.t(:sm_eviv_row, :stat => t.t(:st_hp), :ev => 12, :iv => 31)) &&
          eviv.include?(t.t(:sm_eviv_row, :stat => t.t(:st_speed), :ev => 4, :iv => 1)), eviv
    check "with the nature's effect and the ability as painted", eviv.include?(effect) && eviv.include?(RebornWorld::SHORT), eviv

    sc.drawPageFive(pk)
    moves = SpeakCapture.last.to_s
    check "the fifth page is the moves, not the ribbons", moves.index(PokeAccess::Summary.moves_text(pk)) == 0 &&
          !moves.include?(t.t(:sm_ribbons_none)), moves
    check "and the key to the Z-moves its button offers", moves.include?(t.t(:rv_sum_to_zmoves, :key => "A")), moves

    sc.drawAbilPage(pk)
    check "the ability page reads its box, each label with its line", SpeakCapture.last ==
          "Ability: Flash Fire. Description: #{RebornWorld::FULL}", SpeakCapture.last

    sc.drawZMovePage(pk)
    zpage = SpeakCapture.last.to_s
    check "the Z-moves page reads each slot as painted, the Z-move with its type",
          zpage.index(t.t(:rv_sum_zmoves, :list => "Inferno Overdrive. #{t.t(:mv_type, :t => 'Fire')}")) == 0, zpage
    tackle = ["Tackle", t.t(:mv_type, :t => "Normal"), t.t(:mv_pp, :pp => 35, :tot => 35)].join(". ")
    check "a slot with no Z-move keeps its move and PP", zpage.include?(tackle), zpage
    check "the empty slot is left out, and the key back is said", !zpage.include?(" -") &&
          zpage.include?(t.t(:rv_sum_to_moves, :key => "A")), zpage

    SpeakCapture.clear
    sc.drawSelectedZeeMove(pk, :EMBER, :INFERNOOVERDRIVE)
    det = SpeakCapture.last.to_s
    check "the Z-move detail: its name and type as painted", det.index("Inferno Overdrive. #{t.t(:mv_type, :t => 'Fire')}") == 0, det
    check "the category its icon shows", det.include?(t.t(:cat_special)), det
    check "the power and accuracy painted, dashes as never misses",
          det.include?(t.t(:mv_power, :p => "175")) && det.include?(t.t(:mv_acc, :a => t.t(:mv_acc_perfect))), det
    check "and its description", det.include?("Dives into flames to strike."), det

    $game_variables[747] = 3
    roll = PokeAccess::Credits.lines(Scene_Credits.new)
    check "the credits read the roll the ending picked", roll.first == "Special Thanks" && !roll.include?("Core Development"), roll
    check "without Anna's lines while she has not smiled, a two-column line joined",
          roll == ["Special Thanks", "omg, wow", "Supporters, Patrons"], roll
    $game_switches[:Anna_Smiles] = true
    roll = PokeAccess::Credits.lines(Scene_Credits.new)
    check "and without Lin's once she has", roll == ["Special Thanks", "Thanks to everyone", "Supporters, Patrons"], roll
    $game_variables[747] = 0
    check "the first roll is the plain CREDIT", PokeAccess::Credits.lines(Scene_Credits.new).first == "Core Development",
          PokeAccess::Credits.lines(Scene_Credits.new)

    foe = Struct.new(:index, :level).new(1, 100)
    mine = Struct.new(:index, :level).new(0, 100)
    $game_switches[:Level_999] = true
    levels = [PokeAccess::Battle.shown_level(foe), PokeAccess::Battle.shown_level(mine)]
    check "in the final battle a foe's box says the 999 it paints, the player's its own level", levels == [999, 100], levels
    $game_switches[:Level_999] = false
    check "and any other battle the real level", PokeAccess::Battle.shown_level(foe) == 100, PokeAccess::Battle.shown_level(foe)

    pbShowBattleStats
    canCheckFieldApp?([:ELECTERRAIN])
    canCheckPulseDex?([])
    SpeakCapture.clear
    pbShowInspect(RebornWorld::Box.new("Inspecting Lapras:"), ["Type: Water"], 1)
    notes = t.t(:rv_inspect_field_notes, :key => "S")
    check "the Inspect report says the field notes button it paints, not the PULSE Dex one", SpeakCapture.lines == [notes],
          SpeakCapture.lines
    check "and the info key keeps it after the report", PokeAccess::Info.info_text == "Inspecting Lapras: Type: Water. #{notes}",
          PokeAccess::Info.info_text
    pbShowBattleStats
    canCheckFieldApp?([])
    canCheckPulseDex?([:MAGNEZONE])
    SpeakCapture.clear
    pbShowInspect(RebornWorld::Box.new("Inspecting Lapras:"), ["Type: Water"], 1)
    check "a report with only the PULSE Dex button says that one", SpeakCapture.lines == [t.t(:rv_inspect_pulse_dex, :key => "D")],
          SpeakCapture.lines
    canCheckFieldApp?([:ELECTERRAIN])
    pbShowBattleStats
    SpeakCapture.clear
    pbShowInspect(RebornWorld::Box.new("Inspecting Lapras:"), ["Type: Water"], 1)
    check "an answer given before the report started paints no button in the next one", SpeakCapture.lines == [],
          SpeakCapture.lines

    SpeakCapture.clear
    pbTicketText(2)
    check "each field of the intro's ticket is said as it is written", SpeakCapture.lines == ["8R750"], SpeakCapture.lines
    SpeakCapture.clear
    ticket = ["Train: 8R750", "Seat: 5D", "Destination: Grandview Station", "Adult: One"]
    ticket.each { |line| tts(line) }
    check "the ticket its event then reads out through tts is said whole", SpeakCapture.lines == ticket, SpeakCapture.lines
    check "its first line cutting in, the rest queued", SpeakCapture.log.map { |l| l[1] } == [true, false, false, false],
          SpeakCapture.log
    SpeakCapture.clear
    pbDexCert
    check "the Pokedex certificate says what is written on it, top to bottom",
          SpeakCapture.lines == [t.t(:reb_dex_cert, :rows => "Ame, 45:10")], SpeakCapture.lines

    [1307, 1309, 1330].each { |s| $game_switches[s] = true }
    RebornWorld::PICK_KEYS.replace([nil, :left, :left, :right, :pick])
    SpeakCapture.clear
    picked = pbShowThemeTeams(false, 1)
    v = PokeAccess::Verbosity
    heard = [v.list_entry("Julia", 1, 3), v.list_entry("Cain", 3, 3), v.list_entry("Shelly", 2, 3), v.list_entry("Cain", 3, 3)]
    check "the Theme Teams pick says the trainer under its arrow as it is drawn and after each move", SpeakCapture.lines == heard,
          SpeakCapture.lines
    check "the first queued, each move cutting in", SpeakCapture.log.map { |l| l[1] } == [false, true, true, true], SpeakCapture.log
    check "and the pick runs as it would", picked == true && $game_variables[28] == "Cain", [picked, $game_variables[28]]
    SpeakCapture.clear
    Input.update
    check "once the pick is over the frame poll says nothing", SpeakCapture.lines.empty?, SpeakCapture.lines
    check "a pick short of trainers ends before any arrow, silent", pbShowThemeTeams(false, 4) == false &&
          SpeakCapture.lines.empty?, SpeakCapture.lines
  RUBY

  # Runs the world, the load and the checks in a gen-6 process: [[label, ok, detail], ...], or the raw output.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('reborn')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  end
end

Suite.define("reborn profile: loaded over a Reborn-shaped $cache, the engine's screens and its own read what they draw") do
  rows = RebornProfileSpec.run
  if rows.is_a?(String)
    truthy "the profile process ran its checks: #{rows[0, 300]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 39
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
