# Every args[N] a hook body reads is an argument each surveyed game passes (test/static/arity_census.txt), and means
# the same thing in every class that body serves; deliberate exceptions go in the allow tables with their reason.
require File.expand_path("reader_sites", File.dirname(__FILE__))

# The committed census as { "Class#method" => row }, signatures included.
def arity_census_rows
  rows = {}
  PokeAccess::KVFile.each(File.join(File.dirname(__FILE__), "arity_census.txt")) do |k, v|
    counts, sigs = v.split(";", 2)
    mn, mx, open, games = counts.split(",")
    rows[k] = { :min => mn.to_i, :max => mx.to_i, :open => open.to_i == 1, :games => games.to_i,
                :sigs => sigs.to_s.split("|") }
  end
  rows
end

Suite.define("static: no hook reads an argument the game does not pass") do
  census = arity_census_rows
  truthy "the arity census loaded (#{census.length})", census.length > 150

  # Each entry: a read past the shortest signature on purpose, and what makes it safe.
  ALLOW = {
    # The hall of fame: vanilla takes (pokemon, hallNumber = -1), Fire Ash's team viewer (pokemon) alone, where
    # viewer? reads the absent args[1] on purpose and asks the class for its animation.
    # Uranium's load screen draws its other-saves list with (index) on entry and (index, selected) after a move
    # (0137:468 and 0137:493); an absent selected is row 0, where the list opens.
    "PokemonLoadScene#pbDrawSaveCommands" => "selected is optional; absent, the list opens on row 0",
    "HallOfFameScene#writePokemonData" => "nil means the entry animation, which is the point",
    "HallOfFame_Scene#writePokemonData" => "nil means the entry animation, which is the point",
    # Enhanced UI 1.1.2 (Soulstones 2) takes (battler) and (battler, index) and is served by its profile; the
    # manifest's probe, Battle::Scene#pbGetFinalModifiers, keeps this reader out of it.
    "Battle::Scene#pbUpdateBattlerInfo" => "1.1.2 is served by the profile; the probe keeps this one out",
    "Battle::Scene#pbUpdateMoveInfoWindow" => "1.1.2 is served by the profile; the probe keeps this one out",
    # Reminiscencia's party menu alone takes a fourth argument, showheart; its reader asks args[3] only there.
    "PokemonScreen_Scene#pbShowCommands" => "Reminiscencia's showheart; a shorter call is its default, true",
    # Insurgence's naming screens take (helptext, minlength, maxlength, initialText), with no subject or Pokemon: both
    # read nil there, which the caption and the sign filter take as naming no Pokemon, and that screen paints no sign.
    "PokemonEntryScene#pbStartScene" => "Insurgence's four-argument screen; nil subject and Pokemon mean no sign",
    "PokemonEntryScene2#pbStartScene" => "Insurgence's four-argument screen; nil subject and Pokemon mean no sign"
  }

  regs = ReaderSites.registrations
  truthy "the registration scan resolved the loops as well as the literals (#{regs.length})", regs.length > 450

  offenders = []
  regs.each do |r|
    key = "#{r[:cname]}##{r[:meth]}"
    row = census[key]
    next if row.nil? || row[:open]
    used = r[:body].scan(/\bargs\[(\d+)\]/).map { |g| g[0].to_i }
    worst = used.max
    next if worst.nil? || worst < row[:min]
    next if ALLOW.has_key?(key)
    offenders.push("#{r[:site]}: #{key} reads args[#{worst}] but some game passes only #{row[:min]}")
  end

  eq "every argument a hook reads is one the games really pass", offenders.uniq.sort, []

  truthy "the census resolved most of the pairs it was asked about (#{census.length})", census.length > 350
end

# A body shared by several classes: the census signatures must name each args[N] it reads the same way in all of
# them, after folding case, underscores and message synonyms.
Suite.define("static: a body shared by several classes reads the same thing from each of them") do
  census = arity_census_rows
  # Folded before comparing: case and underscores go, and each synonym maps to its meaning.
  SAME_MEANING = { "msg" => "message", "message" => "message", "text" => "message", "helptext" => "message",
                   "question" => "message", "string" => "message", "str" => "message", "txt" => "message",
                   "value" => "value", "v" => "value", "val" => "value" }
  fold = lambda { |name| key = name.downcase.delete("_"); SAME_MEANING[key] || key }

  # Keyed by file, method and position: a body that reads two meanings on purpose, and what makes it safe.
  MEANING_ALLOW = {
    # The message net's pbShowCommands: where the command list comes first (the summary's action menu, the frontier
    # swap screen), the body reads a String only and leaves the list to the command window.
    "screen_messages.rb pbShowCommands[0]" => "the body reads a String only; a command list is the command window's",
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
  }

  by_method = {}
  ReaderSites.registrations.each { |r| (by_method["#{r[:site]} #{r[:meth]}"] ||= []).push(r) }
  offenders = []
  by_method.each do |group, list|
    keys = list.map { |r| "#{r[:cname]}##{r[:meth]}" }.uniq
    next if keys.length < 2
    used = list.first[:body].scan(/\bargs\[(\d+)\]/).map { |g| g[0].to_i }.uniq
    used.each do |n|
      meanings = {}
      keys.each do |key|
        row = census[key]
        next if row.nil?
        row[:sigs].each do |sig|
          name = sig.split(",")[n]
          next if name.nil? || name =~ /\A[*&]/
          (meanings[fold.call(name)] ||= []).push(key)
        end
      end
      next if meanings.length < 2
      next if MEANING_ALLOW.has_key?("#{File.basename(list.first[:path])} #{list.first[:meth]}[#{n}]")
      detail = meanings.keys.sort.map { |m| "#{m} (#{meanings[m].uniq.sort.join(', ')})" }.join(" vs ")
      offenders.push("#{group}: args[#{n}] is #{detail}")
    end
  end

  eq "every shared body reads one meaning per argument position", offenders.sort, []
end
