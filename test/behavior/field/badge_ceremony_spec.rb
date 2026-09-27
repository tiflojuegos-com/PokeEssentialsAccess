# Fancy Badges' ceremony (plugins/fancy_badges.rb): the badge's name, painted under the spinning badge, is said from
# the game's own table, the script copies' FANCY_BADGE_NAMES or the v20+ plugin's FancyBadges::NAMES. The game's
# function exists only inside the suite, which removes it and its wrapper afterwards.
Suite.define("fancy badges: the ceremony says the badge's name from the table the game paints it from") do
  hooks = PokeAccess::Hooks
  path = File.join(Harness::ROOT, "plugins", "fancy_badges.rb")
  begin
    hooks.fn_bodies.delete("renderBadgeAnimation|before")
    Object.send(:define_method, :renderBadgeAnimation) { |*a| a[0] }
    Object.send(:private, :renderBadgeAnimation)
    eval(File.read(path), TOPLEVEL_BINDING, path)
    Object.const_set(:FANCY_BADGE_NAMES, ["Medalla Corriente", "Medalla Doma", "Medalla Ferro", "Medalla Presa",
                                          "Medalla Évoca"])
    SpeakCapture.clear
    eq "the ceremony still runs as the game's", renderBadgeAnimation(4), 4
    eq "and says its badge as the script copy's table paints it", SpeakCapture.lines, ["Medalla Évoca"]
    eq "queued behind whatever came before", SpeakCapture.log.last[1], false
    Object.send(:remove_const, :FANCY_BADGE_NAMES)
    Object.const_set(:FancyBadges, Module.new)
    FancyBadges.const_set(:NAMES, ["Medalla Planta", "Medalla Agua"])
    SpeakCapture.clear
    renderBadgeAnimation(1)
    eq "or as the v20+ plugin's table does", SpeakCapture.lines, ["Medalla Agua"]
    Object.send(:remove_const, :FancyBadges)
    SpeakCapture.clear
    renderBadgeAnimation(0)
    silent "and a game with neither table says nothing"
  ensure
    Object.send(:remove_const, :FANCY_BADGE_NAMES) if Object.const_defined?(:FANCY_BADGE_NAMES)
    Object.send(:remove_const, :FancyBadges) if Object.const_defined?(:FancyBadges)
    [:renderBadgeAnimation, :renderBadgeAnimation__pa].each do |m|
      Object.send(:remove_method, m) if Object.private_method_defined?(m) || Object.method_defined?(m)
    end
    hooks.fn_bodies.delete("renderBadgeAnimation|before")
  end
end
