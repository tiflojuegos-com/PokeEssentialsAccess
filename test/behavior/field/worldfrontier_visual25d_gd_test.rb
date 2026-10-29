# World Frontier's 2.5D mode label (games/worldfrontier/visual25d.rb): the label the fade between views paints, "Modo
# 2.5D" or "Modo 2D", is said as painted, queued, once per paint; a frame that paints nothing new says nothing.

# The overlay as far as the label goes: it paints the label of the mode it fades to, only when that mode is not the one
# it painted last, as Visual25D::Atmosphere#paint_mode_label_text does. It holds Visual25D's name only while the
# reader's file is evaluated.
module WfVisual25DStandIn
  class Atmosphere
    attr_writer :to_25d
    def initialize; @to_25d = true; @mode_label_key = nil; end
    def paint_mode_label_text
      key = @to_25d ? :d25 : :d2
      return if key == @mode_label_key
      @mode_label_key = key
      pbDrawShadowText(nil, 0, 0, 160, 28, (key == :d25) ? "Modo 2.5D" : "Modo 2D", nil, nil, 0)
      :painted
    end
  end
end

visual_made = !Object.const_defined?(:Visual25D)
Object.const_set(:Visual25D, WfVisual25DStandIn) if visual_made
begin
  visual = File.join(Harness::ROOT, "games", "worldfrontier", "visual25d.rb")
  eval(Harness.source(visual), TOPLEVEL_BINDING, visual)
ensure
  Object.send(:remove_const, :Visual25D) if visual_made
end

class WorldfrontierVisual25dGdTest < PokeAccessTest
  test "says the label each change of mode paints, queued, and nothing for a frame that paints none" do
    atmo = WfVisual25DStandIn::Atmosphere.new
    atmo.paint_mode_label_text
    atmo.paint_mode_label_text
    atmo.to_25d = false
    atmo.paint_mode_label_text
    atmo.paint_mode_label_text
    assert_equal [["Modo 2.5D", false], ["Modo 2D", false]], SpeakCapture.log
  end

  test "the label's paint answers as the game's does, the label said" do
    atmo = WfVisual25DStandIn::Atmosphere.new
    assert_equal [:painted, nil], [atmo.paint_mode_label_text, atmo.paint_mode_label_text]
    assert_equal [["Modo 2.5D", false]], SpeakCapture.log
  end
end
