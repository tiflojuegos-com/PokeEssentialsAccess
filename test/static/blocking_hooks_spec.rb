# The "hooked the loop" check: no after-style hook may be bound to a method that IS the screen's own
# blocking loop.
#
# An after hook runs when its method returns. In Essentials it is completely normal for the method that runs
# a screen -- often called main or pbUpdate, sometimes initialize itself -- to be the loop that keeps running
# until the player leaves. Bound there, a reader is correct in every respect and still useless: it speaks on
# the way out, and the screen is silent for exactly as long as somebody is in it. It looks like a working
# reader in the source and like a dead one in play, which is why it survived three separate reviews.
#
# The answer is always the same shape: hold the scene with around and read from the per-frame poll, or hook
# before if one read at the start is enough.
#
# The facts come from a committed census (test/static/loop_census.txt, written by build_reader_census.rb)
# because the dumps live outside the repo and are absent on CI.
require File.expand_path("reader_sites", File.dirname(__FILE__))

Suite.define("static: no after hook is bound to a method that blocks until the player leaves") do
  census_path = File.join(ReaderSites::ROOT, "test", "static", "loop_census.txt")
  truthy "the blocking-loop census is committed", File.file?(census_path)

  # A site no dump defines is recorded as NO-DUMP rather than as an empty list. It is not an offender -- there
  # is nothing to accuse it of -- but it is not a pass either, and the count below is what keeps the two
  # apart. Left as an empty list, a sixth of the file read as evidence of safety it never carried.
  census = {}
  no_dump = []
  File.read(census_path).each_line do |line|
    next if line =~ /\A\s*#/ || line.strip.empty?
    # " = " and not "=": a hook on a setter is keyed Class#selected=, and splitting on the first "=" cut the
    # key in half so the site could never be found again.
    site, profiles = line.split(" = ", 2)
    next unless profiles
    key = site.strip
    if profiles.strip == "NO-DUMP"
      census[key] = []
      no_dump.push(key)
    else
      census[key] = profiles.split(",").map { |p| p.strip }.reject { |p| p.empty? }
    end
  end

  declarations = ReaderSites.declarations
  missing_from_census = []
  offenders = []

  ReaderSites.after_hooks_by_file.each do |path, sites|
    targets = ReaderSites.profiles_for(path, declarations)
    sites.each do |site|
      blocks_in = census[site]
      if blocks_in.nil?
        missing_from_census.push("#{path}: #{site}")
        next
      end
      hit = (targets == :all) ? blocks_in : (targets & blocks_in)
      offenders.push("#{path}: #{site} blocks in #{hit.join('/')}") unless hit.empty?
    end
  end

  eq "the census covers every after hook (else: ruby test/static/build_reader_census.rb)",
     missing_from_census.sort, []
  eq "and none of them is the screen's own loop", offenders.sort, []

  # Two ceilings on what the check cannot see. Neither is a bug on its own; both are ways for a real one to
  # hide, so they are held to a number instead of being left to drift. Raise a ceiling only after looking at
  # what the new entry is -- for a v22 class, adding the vanilla tree to the census is the real answer.
  #
  # The no-dump ceiling was 30 against 5 real, which is not a ratchet, it is a rubber band. It also turned
  # out that 5 was itself wrong: the generator filed a def under the last class NAME it had seen, so a
  # nested class stole the rest of its file, a top-level def belonged to nobody, an attr_accessor pair was
  # invisible and an inherited method was never looked for. Fixing all four left THREE rows, and every one
  # of them is a real answer -- two hooks whose method no surveyed game puts on that class (correctly gated
  # behind Engine.has?, for a hybrid shape none of the thirteen has yet) and one alias the fork never
  # defined. The ceiling now sits just above that, so the next unverifiable hook has to be looked at.
  unresolved = ReaderSites.unresolved_after_sites.values.flatten.length
  truthy "no new after hook with a computed class or method (was #{unresolved}, ceiling 40)", unresolved <= 40
  # By NAME, not by count. A ceiling with slack is a hole the width of the slack: a typo'd class produces a
  # NO-DUMP row, and regenerating the census -- which the failure message above tells you to do -- moved it
  # into a free slot and the suite went green again. Naming the three means a fourth has to be justified
  # here, in writing, before it can pass.
  #
  # The three: setIndexAndMode is defined only on Battle::Scene::MenuBase, never on the two Display classes
  # the gen-6 games use (that hook is gated behind Engine.has? and installs nowhere; it is defensive code
  # for a hybrid shape none of the thirteen has), and royal's Puntos scene defines pbChangeSelection but not
  # updateDescription, which is why both names are bound :optional.
  KNOWN_NO_DUMP = ["CommandMenuDisplay#setIndexAndMode",
                   "FightMenuDisplay#setIndexAndMode",
                   "PokemonOptionPuntos_Scene#updateDescription"]
  eq "no new after hook that no dump can corroborate", no_dump.sort, KNOWN_NO_DUMP.sort
end
