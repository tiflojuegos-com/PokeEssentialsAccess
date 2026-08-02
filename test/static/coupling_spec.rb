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
  whitelist = {
    # v21's MoveRelearner_Scene exposes the same shape as Sky's egg-move tutor, so it reuses
    # SkyEggMove.detail at runtime (documented in the file header). The one conscious version cross.
    ["core/menus/v21/move_relearner_v21.rb", "SkyEggMove"] => true
  }

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
