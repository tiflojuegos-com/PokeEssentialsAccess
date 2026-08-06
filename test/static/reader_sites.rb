# Finds the two things a reader asserts about a game it cannot see from a spec: the instance variables it
# reads off game objects, and the methods it binds an AFTER hook to. Shared by build_reader_census.rb
# (which asks the dumps whether those hold) and by the specs that check the answers -- one extractor, so
# the generator and the checks can never disagree about what was asked.
#
# The whole point is the failure mode this catches: a class that exists, a method that exists, a hook that
# binds -- and an ivar named something else in that game. The read answers nil forever, no exception, no
# trace, and the screen is simply silent. Nothing else in the suite can see it, because a stub in a spec
# has whatever ivars the spec gave it.
#
# Reading off ANOTHER object is the discriminator, and it is exact: the mod's own state is written as a
# plain @foo inside its own modules, while a read from the game always goes through PokeAccess.ivar or
# instance_variable_get with the name as a SYMBOL. Only the symbol form is collected.
module ReaderSites
  ROOT = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  LAYERS = ["core", "games", "plugins"]

  # A dump folder is named after the game; a few do not match the profile that reads them.
  PROFILE_OF = { "africanvs" => "africanus", "z218" => "pokemon_z" }

  # Reads through PokeAccess.ivar and its typed siblings (ivar_i and any future one -- the first argument is
  # the object, so the symbol comes after a comma) and through instance_variable_get (the symbol is the only
  # argument). Both may wrap across lines. Matching only the bare "ivar(" left every ivar_i read out of the
  # census, and with it five names that nothing else reads.
  READ_FORMS = [
    /PokeAccess\.ivar\w*\(.{0,160}?:@([A-Za-z_]\w*)/m,
    /\.instance_variable_get\(\s*:@([A-Za-z_]\w*)/m
  ]
  WRITE_FORM = /\.instance_variable_set\(\s*:@([A-Za-z_]\w*)/m

  # Ivars the mod puts on somebody else's object and then reads back. They are ours, so no game has to have
  # them, and requiring one would be requiring the game to predict our bookkeeping.
  def self.mod_owned(sources)
    owned = {}
    sources.each_value { |body| body.scan(WRITE_FORM) { owned[$1] = true } }
    owned
  end

  # { relative path => file body } for every Ruby file in the layers that hook game code.
  def self.sources
    out = {}
    LAYERS.each do |layer|
      Dir.glob(File.join(ROOT, layer, "**", "*.rb")).sort.each do |path|
        out[path[ROOT.length + 1..-1].tr("\\", "/")] = File.read(path)
      end
    end
    out
  end

  # { relative path => [ivar name, ...] }, mod-owned names removed.
  def self.ivars_by_file(sources = nil)
    sources ||= self.sources
    owned = mod_owned(sources)
    out = {}
    sources.each do |path, body|
      stripped = body.gsub(/^\s*#.*$/, "")
      names = {}
      READ_FORMS.each { |re| stripped.scan(re) { names[$1] = true unless owned[$1] } }
      out[path] = names.keys.sort unless names.empty?
    end
    out
  end

  # Which profiles a file's readers can run in. core/ and the generic profile run everywhere; a game profile
  # runs in its own game; a plugin reader runs wherever a profile declares it.
  def self.profiles_for(path, declarations)
    return :all if path.start_with?("core/")
    if path =~ %r{\Agames/([^/]+)/}
      return ($1 == "generic") ? :all : [$1]
    end
    return (declarations[$1] || :all) if path =~ %r{\Aplugins/([^/]+)\.rb\z}
    :all
  end

  # { plugin name => [profile, ...] } from the profile manifests. A plugin only reachable through the
  # generic profile's :auto has no named profile, and answers :all -- it may run in any game.
  #
  # eval reads the mod's OWN manifests, which are Ruby literals committed in this repo -- the same way the
  # loader reads them, because RGSS has no JSON parser to use instead. No external input reaches it.
  def self.declarations
    out = {}
    Dir.glob(File.join(ROOT, "games", "*", "manifest.rb")).sort.each do |mf|
      value = eval(File.read(mf))
      next unless value.is_a?(Hash) && value[:plugins].is_a?(Array)
      profile = File.basename(File.dirname(mf))
      value[:plugins].each { |n| (out[n.to_s] ||= []).push(profile) }
    end
    out
  end

  # An after-style hook: it runs only once its method RETURNS. Bound to a method that is the screen's own
  # blocking loop, it therefore fires when the player leaves, and the screen is silent for as long as it is
  # open. before, around and :timing => :before are all fine, so only the after forms are collected.
  # The trailing =? is not decoration: without it a hook on a SETTER was recorded as Class#selected while
  # every dump defines selected=, so the lookup could never match and six sites -- every setter hook in the
  # mod -- sat permanently unverifiable while printing exactly like a verified one.
  HOOK_FORMS = [
    /after_hook\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!]*=?)(.*)/,
    /^\s*after\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!]*=?)(.*)/,
    /read_on_open\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!]*=?)(.*)/
  ]

  # An after-style registration whose CLASS or METHOD is computed -- a loop variable, a constant, an
  # Engine.era_scene call, an interpolated name. There is no honest way to resolve those from the text, and
  # the forms above simply did not match them, so a fifth of the mod's after hooks were absent from the
  # census and looked exactly like sites that had been checked and found clean. They are counted instead, and
  # the spec holds the count to a committed number so a new one cannot slip in unnoticed.
  ANY_AFTER = /(?:Hooks\.after_hook|^\s*after|read_on_open)\(/
  RESOLVED_AFTER = /(?:after_hook|^\s*after|read_on_open)\(\s*"[A-Za-z_:][\w:]*"\s*,\s*:\w[\w?!]*=?/

  # { relative path => [[Class, method], ...] } for hooks that only run after their method returns.
  def self.after_hooks_by_file(sources = nil)
    sources ||= self.sources
    out = {}
    sources.each do |path, body|
      sites = {}
      excused = false
      body.each_line do |line|
        # Comment lines are not stripped up front: the marker below is written in the comment ABOVE the hook,
        # where the reason belongs, so the run of comments leading up to a line is part of its context.
        if line =~ /\A\s*#/
          excused = true if line.include?("blocks-on-purpose")
          next
        end
        if line.strip.empty?
          excused = false
          next
        end
        HOOK_FORMS.each_with_index do |re, i|
          m = re.match(line)
          next unless m
          rest = m[3].to_s
          # read_on_open with :timing => :before is the documented answer for an opener that blocks, so it
          # is not one of these.
          next if i == 2 && rest.include?(":before")
          # A container hook does not read: it exists to drive the hooks inside the call, and its own body
          # only stores. Firing late costs nothing, because nothing was going to be spoken from it.
          next if rest.include?(":hook_container")
          # "The point IS to read afterwards", for a screen whose answer only exists once the animation has
          # finished -- a payout total, say. Written at the hook so the reason travels with it.
          next if excused || rest.include?("blocks-on-purpose")
          sites["#{m[1]}##{m[2]}"] = true
        end
        excused = false
      end
      out[path] = sites.keys.sort unless sites.empty?
    end
    out
  end

  # { relative path => [line, ...] } for after-style registrations the forms above cannot resolve. The DSL
  # definitions in core/foundation/game.rb are the declarations of after/read_on_open themselves, not uses.
  def self.unresolved_after_sites(sources = nil)
    sources ||= self.sources
    out = {}
    sources.each do |path, body|
      next if path == "core/foundation/game.rb"
      lines = []
      body.each_line do |line|
        next if line =~ /\A\s*#/
        next unless line =~ ANY_AFTER
        next if line =~ RESOLVED_AFTER
        next if line.include?(":hook_container")
        lines.push(line.strip)
      end
      out[path] = lines unless lines.empty?
    end
    out
  end
end
