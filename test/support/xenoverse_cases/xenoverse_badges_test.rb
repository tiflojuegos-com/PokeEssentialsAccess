require_relative '../xenoverse_standalone'

FANCY_BADGE_NAMES = ['Actual first badge', 'Actual second badge'] unless defined?(FANCY_BADGE_NAMES)
class PokemonTrainerCardScene
  ViewSprite = Struct.new(:visible, :opacity) do
    def disposed?; false; end
  end
  def pbTrainerCard
    @index, @retro = 0, false
    @sprites = {'medals' => ViewSprite.new(false, 255), 'sfade' => ViewSprite.new(true, 0)}
    PokeAccess::Frame.run_pollers
    yield self if block_given?
    :original_card
  end
  def badge_view(back, index = 0, fade = 0)
    @retro, @index = back, index
    @sprites['medals'].visible = back
    @sprites['sfade'].opacity = fade
    PokeAccess::Frame.run_pollers
  end
end
load File.join(Harness::ROOT, 'games/xenoverse/badges.rb')

class XenoverseBadgesTest < PokeAccessTest
  def setup
    super
    PokeAccess::Config.language = :en
    @previous = $Trainer
    $Trainer = Struct.new(:badges).new([false, false, false, false, false, false, false, false])
    @scene = PokemonTrainerCardScene.new
  end
  def teardown
    $Trainer = @previous
    super
  end

  def test_zero_badges_does_not_name_unearned_silhouettes_or_repeat_on_arrows
    assert_equal :original_card, @scene.pbTrainerCard { |scene|
      assert_nothing_spoken
      scene.badge_view(true, 0, 255)
      assert_nothing_spoken
      scene.badge_view(true)
      assert_equal [['0 badges', false]], SpeakCapture.log
      assert_equal '0 badges', PokeAccess::Info.info_text
      scene.badge_view(true, -1)
      scene.badge_view(true, 1)
      assert_equal 1, SpeakCapture.lines.length
      scene.badge_view(false)
      assert_equal 'Trainer Card', SpeakCapture.lines.last
      assert_equal :trainer, PokeAccess::Info.instance_variable_get(:@kind)
      scene.badge_view(true)
      assert_equal '0 badges', SpeakCapture.lines.last
    }
    assert_nil PokeAccess::Info.row_text
  end

  def test_earned_badges_use_the_games_localized_names_and_actual_cursor
    $Trainer.badges[0] = $Trainer.badges[1] = true
    @scene.pbTrainerCard do |scene|
      scene.badge_view(true)
      scene.badge_view(true, 1)
      scene.badge_view(true, 0)
      assert_equal ['2 badges. Actual first badge, 1 of 2', '2 badges. Actual second badge, 2 of 2',
                    '2 badges. Actual first badge, 1 of 2'], SpeakCapture.lines
      assert_equal [false, true, true], SpeakCapture.log.map { |row| row[1] }
    end
  end

  def test_original_failure_clears_reader_and_reopening_is_read_again
    assert_raises(RuntimeError) do
      @scene.pbTrainerCard { |scene| scene.badge_view(true); raise 'Actual game failure' }
    end
    assert_nil PokeAccess::Info.row_text
    SpeakCapture.clear
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
    @scene.pbTrainerCard { |scene| scene.badge_view(true); assert_equal ['0 badges'], SpeakCapture.lines }
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
