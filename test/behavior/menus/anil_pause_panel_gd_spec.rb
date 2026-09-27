# Anil's icons on Marin's pause menu (games/anil/pause_menu.rb): the infinite repel's state, day or night and the
# one-capture rule's used encounter become lines of the panel the menu paints. Gamedata pass; the profile file is
# loaded once over a stubbed menu that paints and places as the game's does.
class AnilPauseMenuStub
  def initialize(encounter_used); @used = encounter_used; end

  def draw_repel_shortcut(refresh = false)
    @repel_y_pos = 214 unless refresh
    pbDrawTextPositions(nil, [["[W] Rep. Inf.", 64, @repel_y_pos + 24]])
    :repel_drawn
  end

  def draw_sun_moon_icon
    @current_right_icon_y ||= 4
    @current_right_icon_y += 60
    :sun_drawn
  end

  def draw_captured_icon
    return :not_drawn unless @used
    @current_right_icon_y ||= 4
    @current_right_icon_y += 60
    :captured_drawn
  end

  def build
    draw_repel_shortcut
    pbDrawTextPositions(nil, [["Nivel máx. actual: 25", 24, 339]])
    draw_sun_moon_icon
    draw_captured_icon
  end
end

module AnilPausePanelSpec
  # Runs the block with the profile's hooks on the stubbed menu, the repel as given and the night as given.
  def self.with(repel_on, night)
    saved = Object.const_defined?(:DP_PauseMenu) ? DP_PauseMenu : nil
    had_dn = Object.const_defined?(:PBDayNight)
    Object.send(:remove_const, :DP_PauseMenu) if saved
    Object.const_set(:DP_PauseMenu, AnilPauseMenuStub)
    unless $pa_anil_pause_loaded
      load File.expand_path("../../../games/anil/pause_menu.rb", File.dirname(__FILE__))
      $pa_anil_pause_loaded = true
    end
    (class << $PokemonGlobal; self; end).send(:define_method, :infRepel) { repel_on }
    Object.const_set(:PBDayNight, Module.new) unless had_dn
    (class << PBDayNight; self; end).send(:define_method, :isNight?) { |*_a| night }
    yield
  ensure
    (class << $PokemonGlobal; self; end).send(:remove_method, :infRepel) rescue nil
    Object.send(:remove_const, :PBDayNight) if !had_dn && Object.const_defined?(:PBDayNight)
    Object.send(:remove_const, :DP_PauseMenu)
    Object.const_set(:DP_PauseMenu, saved) if saved
  end

  # The panel's lines as the menu's reader lays them out after building a menu.
  def self.panel(menu)
    PokeAccess::PaintCapture.arm(:dp_panel)
    menu.build
    PokeAccess::PausePanel.lines(PokeAccess::PaintCapture.take_pairs(:dp_panel))
  end
end

Suite.define("anil pause menu: the repel's state, day or night and the used encounter join the panel") do
  t = PokeAccess::I18n
  AnilPausePanelSpec.with(true, false) do
    eq "the sun at the top of the right column, the used encounter under it, the repel's state under its shortcut",
       AnilPausePanelSpec.panel(AnilPauseMenuStub.new(true)),
       [t.t(:anil_sun), t.t(:anil_map_encounter_used), "[W] Rep. Inf.", t.t(:anil_repel_on), "Nivel máx. actual: 25"]
  end
  AnilPausePanelSpec.with(false, true) do
    eq "the moon at night, the repel off, and no encounter line where the rule drew no Poke Ball",
       AnilPausePanelSpec.panel(AnilPauseMenuStub.new(false)),
       [t.t(:anil_moon), "[W] Rep. Inf.", t.t(:anil_repel_off), "Nivel máx. actual: 25"]
  end
end

Suite.define("anil pause menu: pressing W redraws the repel after the panel was said, which notes nothing") do
  AnilPausePanelSpec.with(true, false) do
    menu = AnilPauseMenuStub.new(false)
    AnilPausePanelSpec.panel(menu)
    PokeAccess::PaintCapture.arm(:other_screen)
    eq "the redraw keeps its own return", menu.draw_repel_shortcut(true), :repel_drawn
    eq "and adds no line to a capture that is not the menu's", PokeAccess::PaintCapture.take(:other_screen),
       ["[W] Rep. Inf."]
  end
end
