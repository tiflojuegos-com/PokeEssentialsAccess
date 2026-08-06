# register_diag_section: the extension point that lets a PROFILE contribute a section to the
# diagnostic dump (the reason the core carries no game-specific diag anymore). The registered block
# must run inside diag_build, join DIAG_ALL and its debug-menu group, and fail as a guarded ERR line
# without losing the rest of the dump.
Suite.define("diag: profile-registered sections run, group, and fail guarded") do
  k = PokeAccess::Keys
  k.register_diag_section(:spec_section, :perf) { |o| o.push("spec_section: alive") }
  k.register_diag_section(:spec_broken, :perf) { |_o| raise "boom" }
  begin
    truthy "the section joins DIAG_ALL", k::DIAG_ALL.include?(:spec_section)
    truthy "the section joins its debug-menu group", k::DIAG_SECTIONS[:perf].include?(:spec_section)

    out = k.diag_build([:spec_section, :spec_broken])
    truthy "the block's lines are in the dump", out.include?("spec_section: alive")
    truthy "a raising section becomes a guarded ERR line", out =~ /spec_broken: ERR RuntimeError/
    truthy "the raise did not lose the sections around it", out.include?("spec_section: alive")

    k.register_diag_section(:spec_section, :perf) { |o| o.push("v2") }
    eq "re-registering does not duplicate the section in DIAG_ALL",
       k::DIAG_ALL.select { |s| s == :spec_section }.length, 1
    truthy "re-registering replaces the block", k.diag_build([:spec_section]).include?("v2")
  ensure
    k::DIAG_ALL.delete(:spec_section); k::DIAG_ALL.delete(:spec_broken)
    k::DIAG_SECTIONS[:perf].delete(:spec_section); k::DIAG_SECTIONS[:perf].delete(:spec_broken)
    extras = k.instance_variable_get(:@extra_diags)
    extras.delete(:spec_section); extras.delete(:spec_broken) if extras
  end
end

# The caps list on the engine line. It used to be five hand-written pushes, so a capability registered later
# was simply absent from every recording until somebody remembered this file -- the same forget-and-it-is-
# silent failure the capability registry exists to avoid. Now it walks CAPABILITIES, which is what the spec
# pins: not the exact contents (they change), but that the list COMES FROM the registry.
Suite.define("diag: the caps line is built from the capability registry, not a hand list") do
  d = PokeAccess::Keys
  caps = PokeAccess::Engine::CAPABILITIES

  caps[:spec_cap_present] = lambda { true }
  begin
    truthy "a capability registered now appears without touching the diagnostic",
           d.visible_caps(PokeAccess::Engine).include?("spec_cap_present")
  ensure
    caps.delete(:spec_cap_present)
  end

  caps[:spec_cap_absent] = lambda { false }
  begin
    falsy "and one that answers false is left out",
          d.visible_caps(PokeAccess::Engine).include?("spec_cap_absent")
  ensure
    caps.delete(:spec_cap_absent)
  end

  # kind= and fork= already state these on the very same line; repeating them is noise in a report a blind
  # player has to read aloud.
  shown = d.visible_caps(PokeAccess::Engine)
  eq "the ones the engine line already states are not repeated",
     shown.select { |c| ["gamedata", "gen6", "sky_fork"].include?(c) }, []
end
