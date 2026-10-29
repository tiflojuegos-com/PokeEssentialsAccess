# No after hook is bound to a method that is the screen's own blocking loop in a game its reader runs in (it would
# speak only on the way out); the facts come from loop_census.txt (build_reader_census.rb), as the dumps are not on CI.
# Nor does one keep the reentrancy guard on a per-frame driver unless it reads that window or screen itself.
require File.expand_path("reader_sites", File.dirname(__FILE__))

class BlockingHooksTest < PokeAccessTest
  CENSUS = File.join(ReaderSites::ROOT, "test", "static", "loop_census.txt")
  UNRESOLVED_CEILING = 44
  # The rows no dump can corroborate, by name so a new one needs its reason here: royal's Puntos scene defines
  # pbChangeSelection but not updateDescription, hence both bound :optional. The rest are generic-only readers whose
  # scripts only reference copies hold (_refmods), checked by hand there: moveCursor, redrawSelector and update_clock
  # place sprites and return; drawIcons runs the ring's fixed-length turn and returns.
  KNOWN_NO_DUMP = ["PokemonOptionPuntos_Scene#updateDescription", "BlocUnownScene#moveCursor", "Menu2#drawIcons",
                   "Menu2#redrawSelector", "WallClockScene#update_clock"].freeze
  # The DSL's own definitions as core/foundation/game.rb writes them: a computed class and method on each.
  GAME_DSL_AFTER = "def after(cname, meth, opts = {}, &blk); PokeAccess::Hooks.after_hook(cname, meth, opts, &blk); end"
  GAME_DSL_READ_ON_OPEN = "def read_on_open(cname, meth = :pbStartScene, opts = {}, &blk); " \
                          "PokeAccess::Hooks.read_on_open(cname, meth, opts, &blk); end"
  # The after hooks on a per-frame driver (update, pbUpdate) that keep the reentrancy guard, the declared readers'
  # (FocusReader, :update unless :on says otherwise) among them, by name so a new one needs its place here. The guard
  # drops every hook called inside the driver, so the windows it updates go unread through their own hooks. A hook
  # that only publishes takes :hook_container instead, as the load screen's pbUpdate does, whose commands went unread
  # under the guard.
  GUARDED_DRIVERS = {
    # The window's or cursor's own reader: nothing it drives speaks through a hook of its own.
    :window_reader => %w[MiningGameCursor#update NewChoiceSel#update NewCommandWindow#update NewFightWindow#update
                         NextGenCommandWindow#update NextGenFightWindow#update SlotMachineReel#update
                         SpriteWindow_Selectable#update Sprite_Timer#update Window_ControlBinding#update
                         Window_DrawableCommand#update Window_DrawableCommandBag#update Window_DrawableCommandDex#update
                         Window_InputNumberPokemon#update Window_PokemonOption_Sky#update],
    # The hook reads or polls the screen itself; the generic readers of its windows would say it again.
    :screen_reader => %w[DP_PauseMenu#update LuckSwapScene#pbUpdate NewBattleBag#update PickDifficulty#update
                         PlaceDecoration_Scene#pbUpdate PokeAccess::SummaryGen6::SCENE#pbUpdate
                         PokeAccess::SummaryV21::SCENE#pbUpdate PokedexFormScene#pbUpdate
                         PokemonChallenges_Scene#pbUpdate PokemonCharacterGridEntryScene#pbUpdate
                         PokemonEntryScene2#pbUpdate PokemonHatView#update
                         PokemonMGift_Scene#pbUpdate PokemonMenu_Scene#update PokemonPauseMenu_Scene#update
                         PokemonPokegearTheme_Scene#pbUpdate
                         PokemonPokegear_Scene#pbUpdate PokemonReadyMenu_Scene#pbUpdate PokemonSummaryScene#pbUpdate
                         PokemonSummary_Scene#pbUpdate Pokemon_Achievements_Scene#update QuestInfo_Scene#pbUpdate
                         RSESTarterChoice#pbUpdate Scene_Leaf#update SecretBaseMart_Scene#update SlotMachineScene#update
                         SpeciesTypeMatch_Scene#pbUpdate TeamPreview_Scene#update TilePuzzleScene#update
                         cname#update],
    # Reminiscencia's party screen keeps the info key for the game while it runs: its update only refreshes sprites,
    # and the party panels speak from selected=, which the selection loop calls outside it.
    :sprites_only => %w[PokemonScreen_Scene#update]
  }.freeze
  # An after-style hook on update or pbUpdate: the class as written, the method and the rest of the line.
  DRIVER_HOOK = /(?:Hooks\.after_hook|\A\s*after)\(\s*("[^"]+"|[A-Za-z_][\w:]*)\s*,\s*:(update|pbUpdate)\b(.*)/
  # A declared reader's call: the class as written; its options run to the call's closing parenthesis.
  FOCUS_DRIVER = /(?:FocusReader\.define|\bfocus_reader)\(\s*("[^"]+"|[A-Za-z_][\w:]*)/

  test "the census lists every after hook the mod binds" do
    rows, = loop_census(File.read(CENSUS))
    assert_equal [], unlisted(ReaderSites.after_hooks_by_file, rows), "else: ruby test/static/build_census.rb"
  end

  test "binds no after hook to a method that blocks in a game its reader runs in" do
    rows, = loop_census(File.read(CENSUS))
    assert_equal [], blocking(ReaderSites.after_hooks_by_file, rows, ReaderSites.declarations)
  end

  test "keeps the after hooks whose class or method is computed under the ceiling" do
    unresolved = ReaderSites.unresolved_after_sites.values.flatten.length
    assert_operator unresolved, :<=, UNRESOLVED_CEILING, "no new after hook the census cannot name"
  end

  test "the hooks no dump can corroborate are the known ones" do
    _rows, no_dump = loop_census(File.read(CENSUS))
    assert_equal KNOWN_NO_DUMP.sort, no_dump.sort
  end

  test "keeps the reentrancy guard on a per-frame driver only where the hook reads its window or its screen" do
    assert_equal GUARDED_DRIVERS.values.flatten.sort, guarded_drivers(ReaderSites.sources)
  end

  test "reports a guarded hook on update or pbUpdate, a container on its line or the next and comments aside" do
    src = "after(\"PlantedA\", :pbUpdate) { |s, _r, _a| s }\n" \
          "PokeAccess::Hooks.after_hook(\"PlantedB\", :update, :optional => true,\n" \
          "                             :hook_container => true) do |s, _r, _a|\nend\n" \
          "after(SCENE, :pbUpdate, :hook_container => true) { |s, _r, _a| s }\n" \
          "PokeAccess::Hooks.after_hook(SCENE, :update) do |s, _r, _a|\nend\n" \
          "  # after(\"PlantedC\", :pbUpdate) { |s, _r, _a| s }\n" \
          "after(\"PlantedD\", :refresh) { |s, _r, _a| s }\n"
    assert_equal ["PlantedA#pbUpdate", "SCENE#update"], guarded_drivers("core/planted.rb" => src)
  end

  test "reports a declared reader on update, its default, or on pbUpdate with no container among its options" do
    src = "focus_reader(\"PlantedE\", :items => :@x, :slot => :pe) { |l| l }\n" \
          "PokeAccess::FocusReader.define(\"PlantedF\", :on => :pbUpdate, :slot => :\"pf_\#{n}\",\n" \
          "                               :hook_container => true) { |l| l }\n" \
          "focus_reader(\"PlantedG\", :on => :refresh) { |l| l }\n" \
          "focus_reader(\"PlantedH\", :on => :pbUpdate,\n" \
          "             :key => lambda { |s, i| [i] }) do |i, s|\nend\n" \
          "  # focus_reader(\"PlantedI\") { |l| l }\n" \
          "def focus_reader(cname, opts = {}, &text); PokeAccess::FocusReader.define(cname, opts, &text); end\n"
    assert_equal ["PlantedE#update", "PlantedH#pbUpdate"], guarded_drivers("games/x/planted.rb" => src)
  end

  test "reports a hook on a blocking loop in a profile that runs its reader, and in core, which runs everywhere" do
    hooks = ReaderSites.after_hooks_by_file(
      "games/anil/planted.rb" => "after(\"PlantedScene\", :pbMain) do |s, r, a|\nend\n",
      "games/emerald/planted.rb" => "after(\"PlantedScene\", :pbMain) do |s, r, a|\nend\n",
      "core/planted.rb" => "PokeAccess::Hooks.after_hook(\"PlantedScene\", :pbMain) do |s, r, a|\nend\n"
    )
    rows, = loop_census("PlantedScene#pbMain = anil, royal\n")
    assert_equal ["core/planted.rb: PlantedScene#pbMain blocks in anil/royal",
                  "games/anil/planted.rb: PlantedScene#pbMain blocks in anil"], blocking(hooks, rows, {})
  end

  test "reads a plugin's hooks in the profiles that declare it" do
    hooks = ReaderSites.after_hooks_by_file("plugins/planted_plugin.rb" => "after(\"PlantedScene\", :pbMain) do\nend\n")
    rows, = loop_census("PlantedScene#pbMain = anil\n")
    assert_equal [], blocking(hooks, rows, "planted_plugin" => ["emerald"]), "declared where the method returns"
    assert_equal ["plugins/planted_plugin.rb: PlantedScene#pbMain blocks in anil"],
                 blocking(hooks, rows, "planted_plugin" => ["anil", "emerald"]), "declared where it blocks"
  end

  test "reports a hook the census does not list" do
    hooks = ReaderSites.after_hooks_by_file("core/planted.rb" => "after(\"PlantedA\", :pbMain) do\nend\n" \
                                                                 "after(\"PlantedB\", :pbMain) do\nend\n")
    rows, = loop_census("PlantedA#pbMain = \n")
    assert_equal ["core/planted.rb: PlantedB#pbMain"], unlisted(hooks, rows)
  end

  test "leaves out the hooks marked blocks-on-purpose, a read_on_open run before and a hook container" do
    src = <<-RUBY
    # blocks-on-purpose: the screen's own loop, read through a poll.
    after("PlantedA", :pbMain) do |s, r, a|
    end

    after("PlantedB", :pbMain, :hook_container => true) do |s, r, a|
    end
    read_on_open("PlantedC", :pbStartScene, :before) do |s|
    end
    after("PlantedD", :pbMain) do |s, r, a| # blocks-on-purpose
    end
    after("PlantedE", :pbMain) do |s, r, a|
    end
    read_on_open("PlantedF", :pbStartScene) do |s|
    end
    RUBY
    assert_equal({ "core/planted.rb" => ["PlantedE#pbMain", "PlantedF#pbStartScene"] },
                 ReaderSites.after_hooks_by_file("core/planted.rb" => src))
  end

  test "reads a census row by its spaced equals, so a setter keeps its own, and gathers the rows no dump backs" do
    text = "# GENERATED\n\nPlanted#selected= = anil, royal\nPlanted#update = NO-DUMP\nPlanted#refresh = \n"
    assert_equal [{ "Planted#selected=" => ["anil", "royal"], "Planted#update" => [], "Planted#refresh" => [] },
                  ["Planted#update"]], loop_census(text)
  end

  test "counts as computed an after hook whose class or method is not a literal, containers and comments aside" do
    src = "after(cname, :pbMain) do\nend\nafter(\"Lit\", :pbMain) do\nend\nafter(SCENE, meth) do\nend\n" \
          "after(cname, :pbMain, :hook_container => true) do\nend\n" \
          "  # PokeAccess::Hooks.after_hook(cname, :pbMain) do\n"
    assert_equal({ "core/planted.rb" => ["after(cname, :pbMain) do", "after(SCENE, meth) do"] },
                 ReaderSites.unresolved_after_sites("core/planted.rb" => src))
  end

  test "leaves out game.rb, whose definitions of after and read_on_open would count as computed hooks elsewhere" do
    dsl = [GAME_DSL_AFTER, GAME_DSL_READ_ON_OPEN].map { |line| "      #{line}\n" }.join
    assert_equal({ "core/planted.rb" => [GAME_DSL_AFTER, GAME_DSL_READ_ON_OPEN] },
                 ReaderSites.unresolved_after_sites("core/foundation/game.rb" => dsl, "core/planted.rb" => dsl))
  end

  private

  # The census text as [{ "Class#method" => [profile, ...] }, [key, ...] of the NO-DUMP rows]; a row splits on " = ",
  # not "=", since a setter's key itself ends in "=" (Class#selected=).
  def loop_census(text)
    rows = {}
    no_dump = []
    text.each_line do |line|
      next if line =~ /\A\s*#/ || line.strip.empty?
      site, profiles = line.split(" = ", 2)
      next unless profiles
      key = site.strip
      if profiles.strip == "NO-DUMP"
        rows[key] = []
        no_dump.push(key)
      else
        rows[key] = profiles.split(",").map { |p| p.strip }.reject { |p| p.empty? }
      end
    end
    [rows, no_dump]
  end

  # "Class#method", sorted and once each, for the after hooks on update or pbUpdate whose call, read on to the next
  # line when the block does not open on the first, has no :hook_container, and for the declared readers on either
  # with none in their options; comment lines and the DSL's own definition are skipped.
  def guarded_drivers(sources)
    out = []
    sources.each_value do |body|
      lines = body.lines.to_a
      lines.each_with_index do |line, i|
        next if line =~ /\A\s*#/
        m = DRIVER_HOOK.match(line)
        next unless m
        call = m[3]
        call += lines[i + 1].to_s unless call =~ /\bdo\b|\{/
        out.push("#{m[1].delete('"')}##{m[2]}") unless call.include?(":hook_container")
      end
      body.scan(FOCUS_DRIVER) do
        m = Regexp.last_match
        line = body[0, m.begin(0)].split("\n", -1).last.to_s
        next if line =~ /\A\s*(#|def\b)/
        args = call_args(body, m.end(0) - m[0].length + m[0].index("("))
        meth = args[/:on\s*=>\s*:(\w+)/, 1] || "update"
        next unless %w[update pbUpdate].include?(meth) && !args.include?(":hook_container")
        out.push("#{m[1].delete('"')}##{meth}")
      end
    end
    out.uniq.sort
  end

  # The argument list of the call whose opening parenthesis is at open, parentheses balanced across lines.
  def call_args(text, open)
    depth = 0
    (open...text.length).each do |i|
      depth += 1 if text[i, 1] == "("
      depth -= 1 if text[i, 1] == ")"
      return text[open..i] if depth == 0
    end
    text[open..-1]
  end

  # "path: Class#method" for each after hook the census does not list.
  def unlisted(hooks, rows)
    out = []
    hooks.each { |path, sites| sites.each { |site| out.push("#{path}: #{site}") unless rows.key?(site) } }
    out.sort
  end

  # "path: Class#method blocks in profiles" for each hook whose method blocks in a profile its file's readers run in.
  def blocking(hooks, rows, declarations)
    out = []
    hooks.each do |path, sites|
      targets = ReaderSites.profiles_for(path, declarations)
      sites.each do |site|
        blocks_in = rows[site] || []
        hit = targets == :all ? blocks_in : targets & blocks_in
        out.push("#{path}: #{site} blocks in #{hit.join('/')}") unless hit.empty?
      end
    end
    out.sort
  end
end
