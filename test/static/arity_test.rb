# Every args[N] a hook body reads is an argument each surveyed game passes (test/static/arity_census.txt), and means
# the same in every class that body serves; the deliberate exceptions sit in the allow tables with their reason, each
# one excusing something the scan still finds.
require File.expand_path("reader_sites", File.dirname(__FILE__))

class ArityTest < PokeAccessTest
  CENSUS = File.join(File.dirname(__FILE__), "arity_census.txt")
  # A read past the shortest signature on purpose, and what makes it safe.
  ALLOW = {
    # Uranium's load screen draws its other-saves list with (index) on entry and (index, selected) after a move
    # (0137:468 and 0137:493); an absent selected is row 0, where the list opens.
    "PokemonLoadScene#pbDrawSaveCommands" => "selected is optional; absent, the list opens on row 0",
    # Enhanced UI 1.1.2 (Soulstones 2) takes (battler) and (battler, index) and is served by its profile; the
    # manifest's probe, Battle::Scene#pbGetFinalModifiers, keeps this reader out of it.
    "Battle::Scene#pbUpdateBattlerInfo" => "1.1.2 is served by the profile; the probe keeps this one out",
    "Battle::Scene#pbUpdateMoveInfoWindow" => "1.1.2 is served by the profile; the probe keeps this one out",
    # Reminiscencia's party menu alone takes a fourth argument, showheart; its reader asks args[3] only there.
    "PokemonScreen_Scene#pbShowCommands" => "Reminiscencia's showheart; a shorter call is its default, true",
    # Insurgence's naming screen takes (helptext, minlength, maxlength, initialText), with no subject or Pokemon: both
    # read nil there, which the caption takes as naming no Pokemon, and that screen paints no sign.
    "PokemonEntryScene2#pbStartScene" => "Insurgence's four-argument screen; nil subject and Pokemon mean no sign"
  }.freeze
  # Folded before comparing argument names: case and underscores go, and each synonym maps to its meaning.
  SAME_MEANING = { "msg" => "message", "message" => "message", "text" => "message", "helptext" => "message",
                   "question" => "message", "string" => "message", "str" => "message", "txt" => "message",
                   "value" => "value", "v" => "value", "val" => "value" }.freeze
  # "file method[position]" of a shared body that reads two meanings on purpose, and what makes it safe.
  MEANING_ALLOW = {
    # era_scene binds this hook to the gen-6 scene only, though the scan expands both spellings; the paged shape
    # (filter, index, page, maxpage) is Improved Mementos on a modern game, read by ribbons_v21.
    "summary_g6.rb drawSelectedRibbon[0]" => "era_scene binds the gen-6 scene only, whose redraw takes the id",
    # Also bound through era_scene: the modern redraw is (move_to_learn, selected_move); the gen-6 shapes the scan
    # folds in are read by summary_g6's selected_move, which takes the argument after moveToLearn.
    "summary_v21.rb drawSelectedMove[1]" => "era_scene binds the modern scene only, where args[1] is the move id",
    # The gen-6 battle reader binds PokeBattle_Scene only (era_scene), whose copies name these parameters two ways.
    "battle_g6.rb pbHPChanged[0]" => "the battler, which some gen-6 copies name pkmn",
    # The Reborn engine's (mons, anim): args[0] is then a list of [battler, old hp] pairs, and Battle.hp_changed reads
    # args[1] as the old hp only where args[0] is a battler, never the animation flag.
    "battle_g6.rb pbHPChanged[1]" => "the old hp beside a battler; hp_changed never reads the Reborn engine's flag",
    "battle_g6.rb pbSelectBattler[0]" => "the target index, named index or idxbattler",
    "battle_g6.rb pbChooseTarget[0]" => "the battler choosing a target, named index or idxbattler"
  }.freeze
  # The census and the registrations of the tree, read once per run: neither changes during one.
  SCANS = {}

  test "reads no argument past what some game passes" do
    assert_operator census.length, :>, 350, "the census resolved most of the pairs it was asked about"
    assert_operator registrations.length, :>, 450, "the registration scan resolved the loops as well as the literals"
    assert_equal [], reads_past(registrations, census), "every argument a hook reads is one the games really pass"
  end

  test "reads one meaning per argument position in a body shared by several classes" do
    assert_equal [], double_meanings(registrations, census), "every shared body reads one meaning per position"
  end

  test "every allowed read past a signature is one the scan still finds" do
    found = past_reads(registrations, census).map { |key, _message| key }
    assert_equal [], ALLOW.keys.reject { |k| found.include?(k) }.sort
  end

  test "every allowed double meaning is one the scan still finds" do
    found = meaning_conflicts(registrations, census).map { |key, _message| key }
    assert_equal [], MEANING_ALLOW.keys.reject { |k| found.include?(k) }.sort
  end

  test "reports a read past the shortest signature, with its site" do
    regs = ReaderSites.registrations("core/planted.rb" => <<-RUBY)
    PokeAccess::Hooks.after_hook("PlantedScene", :pbShow) do |s, r, args|
      x = args[2]
    end
    RUBY
    rows = { "PlantedScene#pbShow" => census_row("2,3,0,4;a,b|a,b,c") }
    assert_equal ["core/planted.rb:1: PlantedScene#pbShow reads args[2] but some game passes only 2"],
                 reads_past(regs, rows)
  end

  test "spares a read every signature covers, an open signature, a pair no game defines and an allowed one" do
    regs = ReaderSites.registrations("core/planted.rb" => <<-RUBY)
    PokeAccess::Hooks.after_hook("PlantedWithin", :pbShow) do |s, r, args|
      x = args[1]
    end
    PokeAccess::Hooks.after_hook("PlantedOpen", :pbShow) do |s, r, args|
      x = args[5]
    end
    PokeAccess::Hooks.after_hook("PlantedUncensused", :pbShow) do |s, r, args|
      x = args[9]
    end
    PokeAccess::Hooks.after_hook("PokemonLoadScene", :pbDrawSaveCommands) do |s, r, args|
      x = args[1]
    end
    RUBY
    rows = { "PlantedWithin#pbShow" => census_row("2,2,0,3;a,b"), "PlantedOpen#pbShow" => census_row("1,1,1,2;*args"),
             "PokemonLoadScene#pbDrawSaveCommands" => census_row("1,2,0,7;savefiles|savefiles,selected") }
    assert_equal ["PokemonLoadScene#pbDrawSaveCommands"], past_reads(regs, rows).map { |key, _message| key },
                 "only the allowed pair reads past a signature"
    assert_equal [], reads_past(regs, rows)
  end

  test "reports a shared body whose argument names two meanings in the classes it serves" do
    regs = ReaderSites.registrations("core/planted.rb" => <<-RUBY)
    ["PlantedA", "PlantedB"].each do |c|
      PokeAccess::Hooks.before_hook(c, :pbShow) do |s, args|
        say(args[0])
      end
    end
    RUBY
    rows = { "PlantedA#pbShow" => census_row("2,2,0,1;msg,cmds"),
             "PlantedB#pbShow" => census_row("2,2,0,1;commands,msg") }
    assert_equal ["core/planted.rb:2 pbShow: args[0] is commands (PlantedB#pbShow) vs message (PlantedA#pbShow)"],
                 double_meanings(regs, rows)
  end

  test "folds case, underscores and synonyms, skips splat and block parameters and spares an allowed double meaning" do
    shared = <<-RUBY
    ["PlantedA", "PlantedB", "PlantedC"].each do |c|
      PokeAccess::Hooks.before_hook(c, :pbSelectBattler) do |s, args|
        say(args[0])
      end
    end
    RUBY
    folded = { "PlantedA#pbSelectBattler" => census_row("1,1,0,1;help_Text"),
               "PlantedB#pbSelectBattler" => census_row("1,1,0,1;msg"),
               "PlantedC#pbSelectBattler" => census_row("0,0,1,2;*args|&block") }
    assert_equal [], double_meanings(ReaderSites.registrations("core/planted.rb" => shared), folded)
    apart = { "PlantedA#pbSelectBattler" => census_row("1,1,0,1;index"),
              "PlantedB#pbSelectBattler" => census_row("1,1,0,1;idxBattler") }
    allowed = ReaderSites.registrations("core/battle/gen6/battle_g6.rb" => shared)
    assert_equal ["battle_g6.rb pbSelectBattler[0]"], meaning_conflicts(allowed, apart).map { |key, _message| key }
    assert_equal [], double_meanings(allowed, apart), "the allowed position is not reported"
  end

  private

  # One census value, "<min>,<max>,<open>,<games>;<signature>|<signature>...", as a row.
  def census_row(value)
    counts, sigs = value.split(";", 2)
    mn, mx, open, games = counts.split(",")
    { :min => mn.to_i, :max => mx.to_i, :open => open.to_i == 1, :games => games.to_i,
      :sigs => sigs.to_s.split("|") }
  end

  # The committed census as { "Class#method" => row }, read once.
  def census
    SCANS[:census] ||= begin
      rows = {}
      PokeAccess::KVFile.each(CENSUS) { |k, v| rows[k] = census_row(v) }
      rows
    end
  end

  # The mod's hook registrations, scanned once: the tree does not change during a run.
  def registrations
    SCANS[:registrations] ||= ReaderSites.registrations
  end

  # The argument positions a hook body reads.
  def reads(body)
    body.scan(/\bargs\[(\d+)\]/).map { |g| g[0].to_i }
  end

  # [Class#method, "site: Class#method reads args[N] but some game passes only M"] for each body reading past a
  # closed signature some game defines.
  def past_reads(regs, rows)
    out = []
    regs.each do |r|
      key = "#{r[:cname]}##{r[:meth]}"
      row = rows[key]
      next if row.nil? || row[:open]
      worst = reads(r[:body]).max
      next if worst.nil? || worst < row[:min]
      out.push([key, "#{r[:site]}: #{key} reads args[#{worst}] but some game passes only #{row[:min]}"])
    end
    out.uniq
  end

  # The past reads ALLOW does not excuse.
  def reads_past(regs, rows)
    past_reads(regs, rows).reject { |key, _message| ALLOW.key?(key) }.map { |_key, message| message }.sort
  end

  # An argument name as compared: lowercased, underscores gone, a synonym as its meaning.
  def fold(name)
    key = name.downcase.delete("_")
    SAME_MEANING[key] || key
  end

  # ["file method[N]", "site method: args[N] is a (classes) vs b (classes)"] for each position a body shared by
  # several classes reads under names of two meanings.
  def meaning_conflicts(regs, rows)
    by_site = {}
    regs.each { |r| (by_site["#{r[:site]} #{r[:meth]}"] ||= []).push(r) }
    out = []
    by_site.each do |group, list|
      keys = list.map { |r| "#{r[:cname]}##{r[:meth]}" }.uniq
      next if keys.length < 2
      reads(list.first[:body]).uniq.each do |n|
        meanings = {}
        keys.each do |key|
          (rows[key] ? rows[key][:sigs] : []).each do |sig|
            name = sig.split(",")[n]
            (meanings[fold(name)] ||= []).push(key) unless name.nil? || name =~ /\A[*&]/
          end
        end
        next if meanings.length < 2
        detail = meanings.keys.sort.map { |m| "#{m} (#{meanings[m].uniq.sort.join(', ')})" }.join(" vs ")
        key = "#{File.basename(list.first[:path])} #{list.first[:meth]}[#{n}]"
        out.push([key, "#{group}: args[#{n}] is #{detail}"])
      end
    end
    out
  end

  # The double meanings MEANING_ALLOW does not excuse.
  def double_meanings(regs, rows)
    kept = meaning_conflicts(regs, rows).reject { |key, _message| MEANING_ALLOW.key?(key) }
    kept.map { |_key, message| message }.sort
  end
end
