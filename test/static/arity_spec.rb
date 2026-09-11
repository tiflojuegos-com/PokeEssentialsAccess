# Every args[N] a hook body reads is an argument some game really passes, and means the same thing in every
# class that body serves.
#
# A hook binds by NAME. The reader then indexes args[0], args[1], args[2] -- and if the game's method takes
# fewer parameters than that, the hook still binds perfectly and the reader quietly gets nil, or worse, gets
# a DIFFERENT value that happens to sit in that position. Nothing raises, nothing is logged, and the screen
# says something wrong or nothing at all.
#
# Three bugs of exactly that shape were fixed in one release, and not one of them failed a test, because in
# each case the stub had been written to match the reader rather than the game:
#
#   - Enhanced UI 1.1.2 keeps every method name of the current release and changes the arities, so the
#     reader took an index for a list of effects.
#   - Fire Ash's team viewer declares writePokemonData(pokemon) where the vanilla one takes
#     (pokemon, hallNumber), so args[1] was nil and every redraw queued instead of interrupting.
#   - A window handed plain strings was read as if it held tuples.
#
# A fourth had the right COUNT and the wrong meaning: pbShowCommands takes (message, commands) on the PC and
# the bag and (commands, index) on the summary, and one body bound to twenty scenes read the command list
# as the message. Loops of that kind were invisible to the old scan, which only knew the literal form.
#
# So the question is asked of the GAMES, through test/static/arity_census.txt: what is the smallest number
# of arguments any surveyed game passes this method, and what does each game call the parameter? Reading
# past the count, or one name across two meanings, is either a bug or a deliberate choice, and a deliberate
# one belongs in the allow tables below with its reason.
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

  # Each entry: reading past the shortest signature is DELIBERATE, and this says what makes it safe.
  ALLOW = {
    # The hall-of-fame family: the vanilla panel takes (pokemon, hallNumber = -1) and Fire Ash's team viewer
    # takes (pokemon) alone. args[1] is READ AS ABSENT there on purpose -- that is what tells the PC viewer
    # from the entry animation -- and viewer? falls back to asking the class for its animation.
    "HallOfFameScene#writePokemonData" => "nil means the entry animation, which is the point",
    "HallOfFame_Scene#writePokemonData" => "nil means the entry animation, which is the point",
    # Enhanced UI: the current release takes (battler, effects, idxEffect) and (battler, specialAction, cw),
    # the 1.1.2 one that Soulstones 2 ships takes (battler) and (battler, index). This reader is written for
    # the current release and the manifest keeps it out of the older one -- its probe is
    # Battle::Scene#pbGetFinalModifiers, which 1.1.2 does not have -- and that game is served by
    # games/soulstones2/enhanced_ui.rb instead. The census sees both, which is why the pair shows up here.
    # If the probe is ever loosened, these two lines are the record of what breaks.
    "Battle::Scene#pbUpdateBattlerInfo" => "1.1.2 is served by the profile; the probe keeps this one out",
    "Battle::Scene#pbUpdateMoveInfoWindow" => "1.1.2 is served by the profile; the probe keeps this one out"
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

  # The check has to be able to FAIL, and the census is what makes it able to: a pair that no game defines
  # cannot be checked at all, so a census that stopped resolving them would turn this green by emptiness.
  truthy "the census resolved most of the pairs it was asked about (#{census.length})", census.length > 350
end

# One body, several classes, one args[N]: the games must call that parameter the same thing in every class
# the body serves. The names come from the census signatures, folded through a short synonym table so that
# msg, message, text and helptext count as one meaning and commands as another.
Suite.define("static: a body shared by several classes reads the same thing from each of them") do
  census = arity_census_rows
  # Names folded before they are compared: case and underscores go (moveToLearn is move_to_learn), and the
  # words games use for a message are one meaning.
  SAME_MEANING = { "msg" => "message", "message" => "message", "text" => "message", "helptext" => "message",
                   "question" => "message", "string" => "message", "str" => "message", "txt" => "message",
                   "value" => "value", "v" => "value", "val" => "value" }
  fold = lambda { |name| key = name.downcase.delete("_"); SAME_MEANING[key] || key }

  # Keyed by file, method and position: a body that reads two meanings ON PURPOSE, and what makes it safe.
  MEANING_ALLOW = {
    # The message net binds pbShowCommands on twenty scenes; the summary's action menu and the frontier swap
    # screen hand the command list first and no message. The body reads a String and nothing else, so the
    # list is left to the command window that names it.
    "screen_messages.rb pbShowCommands[0]" => "the body reads a String only; a command list is the command window's",
    # The gen-6 ribbon hook binds through era_scene, which the scan expands to both spellings; the paged
    # (filter, index, page, maxpage) shape is the Improved Mementos plugin on a MODERN game, read by
    # ribbons_v21 through focused_id. The one gen-6 game with the cursor passes the id.
    "summary_g6.rb drawSelectedRibbon[0]" => "era_scene binds the gen-6 scene only, whose redraw takes the id",
    # The modern move-detail hook, also bound through era_scene: on the eight modern games the redraw is
    # (move_to_learn, selected_move) and args[1] is the move id. The gen-6 shapes the scan folds in --
    # (pokemon, moveToLearn, moveid) and Awakening's (moveToLearn, moveid) -- are read by summary_g6's
    # selected_move, which takes the LAST argument for exactly that reason.
    "summary_v21.rb drawSelectedMove[1]" => "era_scene binds the modern scene only, where args[1] is the move id"
  }

  # One registration line, one method name, every class it binds: the comparison is per method, since a
  # double loop binds several methods from one line and each has its own parameter list.
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
