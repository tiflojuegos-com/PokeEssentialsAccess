require File.expand_path(File.join(File.dirname(__FILE__), "twins"))
# Static coupling check (F-L16-003): the architecture rule "no version depends on another" stops being
# discipline and becomes CI. It maps every second-level module/class/constant of the mod to the layer
# that DEFINES it (a core version folder gen6/v21/v22/skyflyer, core :shared, or a games/<profile>) and
# then scans every file's code (comments stripped) for cross-layer references. A name also defined in
# core is owned by core -- a profile reopening Config to set constants is USE, not a definition.
# Violations: a core version referencing another version's module; a profile referencing another
# profile's module; core :shared referencing a version's module. Deliberate exceptions live in the
# whitelist below WITH their reason -- adding a new cross-layer reference means either fixing it or
# consciously documenting it here.
Suite.define("static: no undeclared coupling between versions, profiles, or shared->version") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  versions = [:gen6, :v21, :v22, :skyflyer]

  # file => the referencing side may use the named module across layers (reason documented here).
  #
  # Empty, and worth keeping that way. Its one entry used to be v21's Move Relearner reaching into
  # SkyEggMove, a module that sat in the fork's folder only because the egg-move tutor happened to need it
  # first; nothing inside it was Sky's. Naming it after the job instead (MoveList, in the shared layer)
  # turned the crossing into an ordinary core reference and the exception disappeared. That is the shape of
  # fix to look for when something wants to be added here: a whitelist entry is usually a module wearing
  # the name of whoever called it first.
  whitelist = {}

  layer_of = lambda do |rel|
    if rel =~ %r{\Acore/}
      rel =~ %r{core/[^/]+/(gen6|v21|v22|skyflyer)/} ? $1.to_sym : :shared
    elsif rel =~ %r{\Aplugins/}
      :plugins
    elsif rel =~ %r{\Agames/([^/]+)/}
      :"game_#{$1}"
    end
  end

  files = Dir.glob(File.join(root, "core", "**", "*.rb")) + Dir.glob(File.join(root, "games", "**", "*.rb")) +
          Dir.glob(File.join(root, "plugins", "**", "*.rb"))
  files = files.map { |f| f[(root.length + 1)..-1].tr("\\", "/") }
  files = files.reject { |f| f == "core/manifest.rb" || f == "plugins/manifest.rb" || f =~ %r{games/[^/]+/manifest\.rb} }

  defs = {}
  mod_defs = {}
  files.each do |rel|
    File.read(File.join(root, rel)).each_line do |line|
      if line =~ /\A  (?:module|class) (\w+)/
        (defs[$1] ||= []) << rel
        (mod_defs[$1] ||= []) << rel
      elsif line =~ /\A  ([A-Z][A-Za-z0-9_]*) *=/
        (defs[$1] ||= []) << rel
      end
    end
  end
  # Canonical owner: prefer a core definition; games-only names keep their profile as owner.
  owner = {}
  defs.each do |name, places|
    core_def = places.find { |p| p =~ %r{\Acore/} }
    owner[name] = core_def || places.first
  end

  violations = []
  files.each do |rel|
    from = layer_of.call(rel)
    next unless from
    code = File.read(File.join(root, rel)).gsub(/#(?!\{).*/, "")
    code.scan(/\b([A-Z][A-Za-z0-9_]*)\b/).flatten.uniq.each do |id|
      deff = owner[id]
      next if deff.nil? || deff == rel
      to = layer_of.call(deff)
      next unless to
      next if whitelist[[rel, id]]
      # Declared twins are the SAME file copied into two profiles, so of course they name the same module.
      # Without this they read as one profile reaching into another, which is the opposite of what they are.
      next if twin_pair?(rel, deff)
      if versions.include?(from) && versions.include?(to) && from != to
        violations << "version cross: #{rel} (#{from}) uses #{id} defined in #{deff} (#{to})"
      elsif from.to_s.index("game_") == 0 && to.to_s.index("game_") == 0 && from != to
        violations << "profile cross: #{rel} uses #{id} defined in #{deff}"
      elsif from == :shared && versions.include?(to)
        violations << "shared->version: #{rel} uses #{id} defined in #{deff} (#{to})"
      # A plugin reader is written against a THIRD-PARTY plugin, not against a game: reaching into a
      # profile would tie it to one fangame and defeat the point of the layer. And the core must not know
      # plugins exist at all -- it is what every Essentials game has, plugins are what some of them install.
      # A profile that needs to change a plugin reader uses Hooks.override, which couples by name, not by
      # constant.
      elsif from == :plugins && (to.to_s.index("game_") == 0)
        violations << "plugin->profile: #{rel} uses #{id} defined in #{deff}"
      elsif from == :plugins && to == :plugins && deff != rel
        violations << "plugin->plugin: #{rel} uses #{id} defined in #{deff}"
      elsif to == :plugins && from != :plugins
        violations << "#{from}->plugin: #{rel} uses #{id} defined in #{deff}"
      end
    end
  end

  # A profile REDEFINING a core-owned module/class is the silent reopen the override primitive exists
  # to end: a declared replacement goes through Hooks.override (listed by the diag), never a reopen.
  # Config is the one deliberate exception -- profiles reopen it to ASSIGN tuning constants (the "USE,
  # not a definition" case above), never to replace core behaviour.
  mod_defs.each do |name, places|
    next if name == "Config"
    next unless places.any? { |p| p =~ %r{\Acore/} }
    places.each do |p|
      next unless layer_of.call(p).to_s.index("game_") == 0
      next if whitelist[[p, name]]
      violations << "profile reopens core module: #{p} redefines #{name} (use Hooks.override)"
    end
  end

  truthy "the scan saw a realistic module census", defs.length > 100
  eq "no undeclared cross-layer references", violations.sort, []
end

# The other half of the same rule, and the half that was blind: the census above only knows constants the
# MOD defines, so a fangame class named by STRING is invisible to it -- and a string is how every hook is
# attached (Hooks.after_hook("Class", ...), Engine.scene_classes, Menus.def_extractor, SceneWatcher.wire).
# core/ could therefore hook a class that exists in exactly one of the 13 games and the suite stayed green;
# it did, for "PokemonOptionPuntos_Scene" (royal only) and "Window_PokemonMart_BattlePoints" (emerald only).
# Every capitalized string literal in core/ is crossed against fangame_classes.txt, the census of names
# defined by exactly ONE surveyed dump (regenerate it with build_fangame_census.rb; the dumps live outside
# the repo, which is why the census is committed instead of scanned live). A hit means that core file is
# tied to one game: move it to games/<profile>/ (or to plugins/) or declare it below WITH its reason.
# Out of scope on purpose: names the census does not carry, which are vanilla Essentials, shared by two or
# more games, or not class names at all (the Win32 and PA3D_* symbols); and names defined by exactly TWO
# games, because whether a third-party plugin reader may live in core/ is the open doctrine question of
# PENDIENTE 6.4, not a rule this spec gets to settle.
Suite.define("static: no core/ file names a class only one fangame has") do
  root = File.expand_path("../..", File.dirname(__FILE__))

  # [file, class name] => why this one core file may name a single-game class.
  declared = {
    # royal's trainer-points Options scene (its "Puntos entrenador" plugin), listed as a third alias next
    # to the two vanilla Options names. This is the case that proved the census was blind, and it stays --
    # the move to a separate reader was considered and rejected. It is one name in an alias list, not a
    # second reader: the screen behaves identically under all three names, so splitting it would copy the
    # whole reader into a plugin file to add a string. And it costs nothing where the plugin is absent,
    # because scene_classes drops the names the running game does not define.
    ["core/menus/option_help.rb", "PokemonOptionPuntos_Scene"] => true,
  }

  census = {}
  PokeAccess::KVFile.each(File.join(File.dirname(__FILE__), "fangame_classes.txt")) { |k, v| census[k] = v }
  # Without this the whole check evaporates the day the census file is renamed, emptied or unreadable:
  # every lookup misses, nothing is reported and the suite says "ok" -- the exact failure mode of the
  # i18n parity spec that this same block had to fix.
  truthy "the fangame class census loaded", census.length > 300

  hits = []
  found = {}
  Dir.glob(File.join(root, "core", "**", "*.rb")).sort.each do |f|
    rel = f[(root.length + 1)..-1].tr("\\", "/")
    code = File.read(f).gsub(/#(?!\{).*/, "")
    code.scan(/"([A-Z][A-Za-z0-9_]*)"/).flatten.uniq.each do |name|
      next unless census[name]
      found[[rel, name]] = true
      next if declared[[rel, name]]
      hits.push("#{rel} names #{name} (only in #{census[name]})")
    end
  end
  eq "no core/ file names an undeclared single-game class", hits.sort, []
  # An exception whose reference is gone is dead paperwork that keeps widening the rule for nothing, and it
  # is how an allowlist grows until it covers more than the check does.
  stale = declared.keys.reject { |k| found[k] }
  eq "every declared exception is still a real reference", stale.map { |k| k.join(" -> ") }.sort, []
end
