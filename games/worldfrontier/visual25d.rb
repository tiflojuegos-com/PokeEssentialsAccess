# World Frontier's 2.5D view ([ROYAL] Visual 2.5D HD, [006] Atmosphere.rb): when Q or the options start the fade
# between views, a label slides in at the bottom left, "Modo 2.5D" or "Modo 2D", painted once per change of mode.
# Said as painted, queued.
PokeAccess::Game.define("worldfrontier") do
  around("Visual25D::Atmosphere", :paint_mode_label_text) do |_atmo, nxt, _a|
    ret = nil
    painted = PokeAccess::PaintCapture.shadow_sample { ret = nxt.call }
    PokeAccess.speak_clean(painted.join(" "), false) unless painted.empty?
    ret
  end
end
