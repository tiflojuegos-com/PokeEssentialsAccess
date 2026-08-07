module PokeAccess
  # Awakening's Fates pause menu (JessFatesMenu in "Menu Inicio"): a vertical strip of sprite panels
  # (FatesMenuPanels, each with @nombre/@index) plus icon shortcuts. JessFatesMenu blocks inside its own
  # initialize, so it is never $scene; navigation is a local variable, but each panel is told its focus via
  # cambio(true/false), and the initially focused panel marks itself in its own initialize
  # (@pnl.src_rect.y == 37). So: read a panel when cambio(true) fires, and read the initially focused panel
  # when it is created. A panel's name (@nombre) is the spoken label.
  module AwakeningPause
    # Reads a panel that has just become focused via cambio(true).
    def self.panel_changed(panel, focused)
      say_panel(panel) if focused == true
    end

    # Reads a freshly created panel if it is the initially focused one (its sprite row is the highlight row).
    def self.panel_created(panel)
      hl = (panel.instance_variable_get(:@pnl).src_rect.y rescue 0)
      say_panel(panel) if hl == 37
    rescue StandardError
      nil
    end

    # Speaks a panel's name, and remembers it so the return below has something to repeat.
    def self.say_panel(panel)
      nm = PokeAccess.ivar(panel, :@nombre)
      return if nm.nil? || nm.to_s.empty?
      @last = nm.to_s
      PokeAccess.speak_clean(@last, true)
    rescue StandardError
      nil
    end

    @depth = 0
    @last = nil

    def self.open!; @depth += 1; end

    def self.close!
      @depth -= 1 if @depth > 0
      @last = nil if @depth == 0
    end

    # Coming back from a submenu. The menu opens the party, the bag, the cards and the rest from inside its
    # own loop and then carries on: cambio never fires again, so the menu returned silent with the cursor on
    # a panel the player could no longer hear.
    #
    # MOST of those options are wrapped in pbFadeOutIn, which makes the fade a return signal -- gated on the
    # menu still being up, because that fade is the engine's fade for everything. Three are not: the quest
    # book on A2 and, on D, the talisman screen and the gacha are called bare. Those are hooked by name
    # below, which is why this cannot be the fade alone.
    def self.returned
      PokeAccess.speak_clean(@last, true) if @depth > 0 && @last
    rescue StandardError
      nil
    end

    @fade = 0

    # Only the OUTERMOST fade puts the Fates menu back in front. Its children fade as well -- giving an item
    # from the bag, opening storage inside the PC -- and an inner fade ends with the CHILD on screen, so
    # announcing the menu's panel there talked over a screen that is not this one.
    def self.fade_in!; @fade += 1; end

    def self.fade_out!
      @fade = [@fade - 1, 0].max
      returned if @fade == 0
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("FatesMenuPanels", :initialize) do |panel, _r, _a|
    PokeAccess::AwakeningPause.panel_created(panel)
  end
  after("FatesMenuPanels", :cambio) do |panel, _r, args|
    PokeAccess::AwakeningPause.panel_changed(panel, args[0])
  end
  # JessFatesMenu runs its whole screen from the constructor, so that is what is held.
  around("JessFatesMenu", :initialize, :optional => true) do |_s, nxt, _a|
    PokeAccess::AwakeningPause.open!
    begin; nxt.call; ensure; PokeAccess::AwakeningPause.close!; end
  end
  kernel("pbFadeOutIn", :around) do |_args, nxt|
    PokeAccess::AwakeningPause.fade_in!
    begin; nxt.call; ensure; PokeAccess::AwakeningPause.fade_out!; end
  end
  ["pbQuestlog", "pbEquipScreen", "openGacha"].each do |fn|
    kernel(fn, :after) { |_args, _r| PokeAccess::AwakeningPause.returned }
  end
end
