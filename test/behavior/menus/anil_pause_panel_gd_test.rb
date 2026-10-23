# Anil's icons on Marin's pause menu (games/anil/pause_menu.rb), gamedata pass: the infinite repel's state, day or
# night and the one-capture rule's used encounter become lines of the panel the menu paints, each where its icon stands.

# Marin's pause menu as Anil builds it: a shortcut line per slot down the left (fly, then the repel), the level cap at
# the bottom, and down the right the sun or moon and, while the one-capture rule holds, the used encounter's Poke Ball,
# each icon a step below the last. Its text sits TEXT_Y_OFFSET below its slot, 24 where the menu defines no constant.
# It goes by its own name and stands in as DP_PauseMenu only while the profile binds to it or a test asks for it, so no
# other test of the process finds Marin's menu.
class AnilPauseMenuStub
  def initialize(encounter_used); @used = encounter_used; end

  def draw_fly_shortcut
    pbDrawTextPositions(nil, [["[S] Volar", 64, next_shortcut_y + text_offset]])
  end

  def draw_repel_shortcut(refresh = false)
    @repel_y_pos = next_shortcut_y unless refresh
    pbDrawTextPositions(nil, [["[W] Rep. Inf.", 64, @repel_y_pos + text_offset]])
    :repel_drawn
  end

  def draw_sun_moon_icon
    next_right_icon_y
    :sun_drawn
  end

  def draw_captured_icon
    return :not_drawn unless @used
    next_right_icon_y
    :captured_drawn
  end

  def build
    draw_fly_shortcut
    draw_repel_shortcut
    pbDrawTextPositions(nil, [["Nivel máx. actual: 25", 24, 339]])
    draw_sun_moon_icon
    draw_captured_icon
  end

  private

  def next_shortcut_y
    @shortcut_y ||= 4
    @shortcut_y += 70
    @shortcut_y - 70
  end

  def next_right_icon_y
    @current_right_icon_y ||= 4
    @current_right_icon_y += 60
    @current_right_icon_y - 60
  end

  def text_offset
    self.class.const_defined?(:TEXT_Y_OFFSET, false) ? self.class::TEXT_Y_OFFSET : 24
  end
end

Object.const_set(:DP_PauseMenu, AnilPauseMenuStub)
begin
  path = File.join(Harness::ROOT, "games", "anil", "pause_menu.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  Object.send(:remove_const, :DP_PauseMenu)
end

class AnilPausePanelGdTest < PokeAccessTest
  LEVEL_CAP = "Nivel máx. actual: 25"

  test "notes the sun, the used encounter and the repel's state as lines where their icons stand" do
    lines = with_state(true, false) { panel(AnilPauseMenuStub.new(true)) }
    assert_equal [t(:anil_sun), "[S] Volar", t(:anil_map_encounter_used), "[W] Rep. Inf.", t(:anil_repel_on),
                  LEVEL_CAP], lines
  end

  test "notes no encounter line where the one-capture rule drew no Poke Ball" do
    lines = with_state(true, false) { panel(AnilPauseMenuStub.new(false)) }
    assert_equal [t(:anil_sun), "[S] Volar", "[W] Rep. Inf.", t(:anil_repel_on), LEVEL_CAP], lines
  end

  test "names day or night by the game's clock, day where the game has none" do
    { true => :anil_moon, false => :anil_sun, :absent => :anil_sun }.each do |night, key|
      lines = with_state(true, night) { panel(AnilPauseMenuStub.new(false)) }
      assert_equal t(key), lines.first, "night #{night.inspect}"
    end
  end

  test "says the infinite repel on or off under its shortcut, off where the save keeps no flag" do
    { true => :anil_repel_on, false => :anil_repel_off, :absent => :anil_repel_off }.each do |repel, key|
      lines = with_state(repel, false) { panel(AnilPauseMenuStub.new(false)) }
      assert_equal ["[W] Rep. Inf.", t(key)], lines[2, 2], "repel #{repel.inspect}"
    end
  end

  test "places the repel's state under its shortcut by the offset the menu defines" do
    lines = with_state(false, false) { as_the_menu(:TEXT_Y_OFFSET => 30) { panel(AnilPauseMenuStub.new(false)) } }
    assert_equal ["[W] Rep. Inf.", t(:anil_repel_off)], lines[2, 2]
  end

  test "notes nothing into another screen's capture when W redraws the repel after the panel was said" do
    with_state(true, false) do
      menu = AnilPauseMenuStub.new(false)
      panel(menu)
      PokeAccess::PaintCapture.arm(:other_screen)
      menu.draw_repel_shortcut(true)
      assert_equal ["[W] Rep. Inf."], PokeAccess::PaintCapture.take(:other_screen)
    end
  end

  test "keeps each drawing's own return" do
    with_state(true, false) do
      menu = AnilPauseMenuStub.new(true)
      PokeAccess::PaintCapture.arm(:dp_panel)
      returns = [menu.draw_repel_shortcut, menu.draw_sun_moon_icon, menu.draw_captured_icon,
                 AnilPauseMenuStub.new(false).draw_captured_icon]
      PokeAccess::PaintCapture.take_pairs(:dp_panel)
      assert_equal [:repel_drawn, :sun_drawn, :captured_drawn, :not_drawn], returns
    end
  end

  test "notes nothing for a repel line the menu has not placed" do
    PokeAccess::PaintCapture.arm(:dp_panel)
    PokeAccess::AnilPauseMenu.repel(AnilPauseMenuStub.new(false))
    assert_equal [], PokeAccess::PaintCapture.take_pairs(:dp_panel)
  end

  private

  # The mod's line for key in the running language.
  def t(key)
    PokeAccess::I18n.t(key)
  end

  # The panel's lines as the menu's reader lays them out, for a menu built while its panel capture is armed.
  def panel(menu)
    PokeAccess::PaintCapture.arm(:dp_panel)
    menu.build
    PokeAccess::PausePanel.lines(PokeAccess::PaintCapture.take_pairs(:dp_panel))
  end

  # Runs the block with the save's infinite repel flag and the clock's night as given; :absent leaves the game
  # without the flag, or without a clock.
  def with_state(repel, night)
    meta = $PokemonGlobal.singleton_class
    had_clock = Object.const_defined?(:PBDayNight)
    clock = had_clock ? PBDayNight : nil
    meta.send(:define_method, :infRepel) { repel } unless repel == :absent
    Object.send(:remove_const, :PBDayNight) if had_clock
    unless night == :absent
      Object.const_set(:PBDayNight, Module.new)
      PBDayNight.define_singleton_method(:isNight?) { |*_a| night }
    end
    yield
  ensure
    meta.send(:remove_method, :infRepel) if meta.instance_methods(false).include?(:infRepel)
    Object.send(:remove_const, :PBDayNight) if Object.const_defined?(:PBDayNight)
    Object.const_set(:PBDayNight, clock) if had_clock
  end

  # Runs the block with the stand-in as DP_PauseMenu, its layout constants set as given.
  def as_the_menu(constants)
    Object.const_set(:DP_PauseMenu, AnilPauseMenuStub)
    constants.each { |name, value| AnilPauseMenuStub.const_set(name, value) }
    yield
  ensure
    constants.each_key do |name|
      AnilPauseMenuStub.send(:remove_const, name) if AnilPauseMenuStub.const_defined?(name, false)
    end
    Object.send(:remove_const, :DP_PauseMenu) if Object.const_defined?(:DP_PauseMenu)
  end
end
