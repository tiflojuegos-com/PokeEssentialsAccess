# The title a list screen paints in its corner (core/menus/screen_title.rb): the jukebox in both builds and the HM
# Catalogue, over stand-ins whose header is a text window. Said once per screen, queued, ahead of the first row.

# A header as the screens make it: a text window, here only its text.
TitleHeader = Struct.new(:text)

# Gen6's jukebox loops over update; v19's and the HM Catalogue's screens update their sprites in pbUpdate. Each is
# built here with the title it paints, or none.
class Scene_Jukebox
  def initialize(title = nil); @sprites = title ? { "header" => TitleHeader.new(title) } : {}; end
  def update; :updated; end
end
class PokemonJukebox_Scene
  def initialize(title = nil); @sprites = title ? { "header" => TitleHeader.new(title) } : {}; end
  def pbUpdate; :updated; end
end
class HM_Scene
  def initialize(title = nil); @sprites = title ? { "header" => TitleHeader.new(title) } : {}; end
  def pbUpdate; :updated; end
end

# The hooks, which core's and the plugins' own load made before these screens existed.
eval(Harness.source(File.join(Harness::ROOT, "core", "menus", "screen_title.rb")), TOPLEVEL_BINDING, "screen_title.rb")
hm = File.join(Harness::ROOT, "plugins", "hm_catalogue.rb")
eval(Harness.source(hm)[/^PokeAccess::Hooks\.before_hook\("HM_Scene".*?^end$/m], TOPLEVEL_BINDING, hm)

class ScreenTitleTest < PokeAccessTest
  SCREENS = { Scene_Jukebox => :update, PokemonJukebox_Scene => :pbUpdate, HM_Scene => :pbUpdate }

  test "each screen says its title on its first frame, queued, and keeps the game's own result" do
    SCREENS.each do |klass, meth|
      SpeakCapture.clear
      assert_equal :updated, klass.new("Jukebox").send(meth), "for #{klass}"
      assert_equal [["Jukebox", false]], SpeakCapture.log, "for #{klass}"
    end
  end

  test "the title is said once however many frames the screen runs" do
    SCREENS.each do |klass, meth|
      SpeakCapture.clear
      scene = klass.new("HM Catalogue")
      3.times { scene.send(meth) }
      assert_equal [["HM Catalogue", false]], SpeakCapture.log, "for #{klass}"
    end
  end

  test "a new visit says the title again" do
    2.times { Scene_Jukebox.new("Radio").update }
    assert_equal [["Radio", false], ["Radio", false]], SpeakCapture.log
  end

  test "a screen that paints no title says nothing" do
    SCREENS.each { |klass, meth| 2.times { klass.new.send(meth) } }
    assert_nothing_spoken
  end
end
