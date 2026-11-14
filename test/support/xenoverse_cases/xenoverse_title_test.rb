require_relative '../xenoverse_standalone'

class XenoverseStyle
  attr_accessor :disposed
  def disposed?; !!@disposed; end
end
class Scene_Intro
  attr_accessor :screen
  attr_reader :updates
  def update
    @updates = (@updates || 0) + 1
    :original_title_loop
  end
end
load File.join(Harness::ROOT, 'games/xenoverse/title.rb')

class XenoverseTitleTest < PokeAccessTest
  def setup
    super
    PokeAccess::Config.language = :en
  end

  def test_ready_title_reads_shared_prompt_and_preserves_original_loop
    scene = Scene_Intro.new
    scene.screen = XenoverseStyle.new
    assert_equal :original_title_loop, scene.update
    assert_equal 1, scene.updates
    assert_equal [PokeAccess::TitleScreen.prompt], SpeakCapture.lines
  end

  def test_other_missing_and_disposed_screens_stay_silent
    scene = Scene_Intro.new
    disposed = XenoverseStyle.new
    disposed.disposed = true
    [nil, Object.new, disposed].each do |screen|
      scene.screen = screen
      scene.update
    end
    assert_nothing_spoken
    assert_equal 3, scene.updates
  end

  def test_title_uses_existing_localized_prompt
    scene = Scene_Intro.new
    scene.screen = XenoverseStyle.new
    [:en, :pl, :es, :fr, :de, :pt].each do |language|
      PokeAccess::Config.language = language
      SpeakCapture.clear
      scene.update
      assert_equal [PokeAccess::TitleScreen.prompt], SpeakCapture.lines
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
