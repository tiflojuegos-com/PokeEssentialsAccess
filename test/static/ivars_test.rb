# Every instance variable a reader takes off a game object exists in a game that reader runs in (ivar_census.txt,
# from build_reader_census.rb); one the game names otherwise reads nil forever, silently. A plugin reader only the
# generic profile loads may take one no surveyed game has if a reference copy uses it (reference_census.txt). Each
# census line's tail past the bar is the informational class list, not profiles.
require File.expand_path("reader_sites", File.dirname(__FILE__))
require File.expand_path("reference_names", File.dirname(__FILE__))

class IvarsTest < PokeAccessTest
  CENSUS = File.join(ReaderSites::ROOT, "test", "static", "ivar_census.txt")

  # The diagnostic and the recorder read the mod's own modules by ivar, names no game has to carry.
  SELF_INTROSPECTION = ["core/input/diag.rb", "core/util/recorder.rb"]

  # Names of a plugin version no surveyed game ships, checked by hand against the source of a game that does:
  # Voltseon's Pause Menu 2.2 (Essentials 21.1), as Pokemon Decades ships it.
  UNSURVEYED = { "plugins/voltseon_pausemenu.rb" => %w[current_selection pause_menu] }

  test "the census covers every ivar the mod reads" do
    assert_equal [], real_verdict[:uncensused], "else: ruby test/static/build_census.rb"
  end

  test "no reader takes an ivar no game it runs in has" do
    verdict = real_verdict
    assert_equal [], verdict[:offenders]
    unless verdict[:partial].empty?
      puts "  note: #{verdict[:partial].length} ivar reads are present in some of their target games but not all"
      verdict[:partial].each { |p| puts "    #{p}" }
    end
  end

  test "each unsurveyed name is still in no surveyed game" do
    census = parse_census(File.read(CENSUS))
    still = UNSURVEYED.map { |path, ns| ns.reject { |n| (census[n] || []).empty? }.map { |n| "#{path}: @#{n}" } }
    assert_equal [], still.flatten, "else it leaves that list"
  end

  test "the census gives each name its profiles, not the class list past the bar" do
    text = "# format: @name = profile, profile | classes\n\n@alpha = anil, royal  |  PokemonMart_Scene\n@never = \n" \
           "@bare = z218\nno bar here\n"
    assert_equal({ "alpha" => ["anil", "royal"], "never" => [], "bare" => ["z218"] }, parse_census(text))
  end

  test "a name the census does not know is reported as missing from it" do
    got = judge({ "core/menus/a.rb" => ["ghost"] }, {}, :all)
    assert_equal({ :uncensused => ["core/menus/a.rb: @ghost"], :offenders => [], :partial => [] }, got)
  end

  test "a name no surveyed game has is an offender for a reader that runs everywhere" do
    got = judge({ "core/menus/a.rb" => ["never", "known"] }, { "never" => [], "known" => ["anil"] }, :all)
    assert_equal ["core/menus/a.rb: @never is in no surveyed game"], got[:offenders]
  end

  test "a name only other games have is an offender, naming where it is" do
    reads = { "games/anil/a.rb" => ["nowhere", "elsewhere"] }
    got = judge(reads, { "elsewhere" => ["royal", "fireash"], "nowhere" => [] }, ["anil"])
    assert_equal ["games/anil/a.rb: @elsewhere is in royal/fireash, not in anil",
                  "games/anil/a.rb: @nowhere is in no game, not in anil"], got[:offenders]
  end

  test "a name some of its target games lack passes, listed as partial" do
    got = judge({ "games/x_common/a.rb" => ["half"] }, { "half" => ["royal"] }, ["royal", "anil", "fireash"])
    want = { :uncensused => [], :offenders => [], :partial => ["games/x_common/a.rb: @half missing in anil/fireash"] }
    assert_equal want, got
  end

  test "a name every one of its target games has passes unreported" do
    got = judge({ "games/x_common/a.rb" => ["everywhere"] }, { "everywhere" => ["anil", "royal", "z218"] },
                ["royal", "anil"])
    assert_equal({ :uncensused => [], :offenders => [], :partial => [] }, got)
  end

  test "the mod's own introspection and the unsurveyed names are not checked" do
    reads = { "core/input/diag.rb" => ["ghost"], "plugins/voltseon_pausemenu.rb" => ["pause_menu", "ghost"] }
    got = judge(reads, {}, :all)
    assert_equal ["plugins/voltseon_pausemenu.rb: @ghost"], got[:uncensused]
  end

  test "a plugin only the generic profile loads may read a name only a reference copy uses" do
    reference = lambda { |n| n == "copied" }
    census = { "copied" => [], "unknown" => [] }
    got = judge({ "plugins/fl_tetra.rb" => ["copied", "unknown"] }, census, :all, reference)
    assert_equal ["plugins/fl_tetra.rb: @unknown is in no surveyed game"], got[:offenders]
    got = judge({ "games/generic/a.rb" => ["copied"] }, census, :all, reference)
    assert_equal ["games/generic/a.rb: @copied is in no surveyed game"], got[:offenders], "only a plugins/ reader"
    got = judge({ "plugins/dbk_battle.rb" => ["copied"] }, census, ["anil"], reference)
    assert_equal ["plugins/dbk_battle.rb: @copied is in no game, not in anil"], got[:offenders],
                 "only a generic-only one"
  end

  private

  # { name without @ => [profiles] } from the census text: comment and blank lines skipped, the class list past the
  # bar dropped.
  def parse_census(text)
    census = {}
    text.each_line do |line|
      next if line =~ /\A\s*#/ || line.strip.empty?
      name, rest = line.split("=", 2)
      next unless rest
      profiles = rest.split("|", 2)[0].to_s.split(",").map { |p| p.strip }
      census[name.strip.sub(/\A@/, "")] = profiles.reject { |p| p.empty? }
    end
    census
  end

  # The census's verdict on the ivar reads ({ path => [name, ...] }) as sorted lists: :uncensused, names the census
  # lacks; :offenders, names none of the reader's games has; :partial, names some of them lack. targets is the
  # reader's profiles (:all for everywhere), or a lambda answering them by path; reference answers whether a reference
  # copy uses a name.
  def judge(reads, census, targets, reference = lambda { |_n| false })
    out = { :uncensused => [], :offenders => [], :partial => [] }
    reads.each do |path, names|
      next if SELF_INTROSPECTION.include?(path)
      aims = targets.respond_to?(:call) ? targets.call(path) : targets
      generic_only = aims == :all && path =~ %r{\Aplugins/[^/]+\.rb\z}
      names.each do |n|
        next if (UNSURVEYED[path] || []).include?(n)
        have = census[n]
        next if generic_only && (have || []).empty? && reference.call(n)
        if have.nil?
          out[:uncensused].push("#{path}: @#{n}")
        elsif aims == :all
          out[:offenders].push("#{path}: @#{n} is in no surveyed game") if have.empty?
        elsif (aims & have).empty?
          where = have.empty? ? "no game" : have.join("/")
          out[:offenders].push("#{path}: @#{n} is in #{where}, not in #{aims.join('/')}")
        elsif !(aims - have).empty?
          out[:partial].push("#{path}: @#{n} missing in #{(aims - have).sort.join('/')}")
        end
      end
    end
    out.each_value { |list| list.sort! }
    out
  end

  # The verdict on the mod's real reads against the committed census.
  def real_verdict
    assert File.file?(CENSUS), "the ivar census is committed"
    declarations = ReaderSites.declarations
    judge(ReaderSites.ivars_by_file, parse_census(File.read(CENSUS)),
          lambda { |path| ReaderSites.profiles_for(path, declarations) }, lambda { |n| ReferenceNames.ivar?(n) })
  end
end
