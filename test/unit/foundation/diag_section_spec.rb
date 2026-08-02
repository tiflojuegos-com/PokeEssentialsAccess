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
