# Kanto's title draws between reading a key in the style's wait and reading it
# again in the scene.
class InfiniteFusionStartupGdTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    def continueKeyPressed?
      $start_key
    end

    class GenOneStyle
      def update(key_during_wait)
        $start_key = key_during_wait
        @skip = continueKeyPressed?
      end
    end

    class Scene_Intro
      def update(key_during_wait, key_after_wait, fail_after_wait = false)
        GenOneStyle.new.update(key_during_wait)
        $start_key = key_after_wait
        raise ArgumentError, "title aborted" if fail_after_wait
        [continueKeyPressed?, continueKeyPressed?]
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    probe(:title) do
      scene = Scene_Intro.new
      swallowed = scene.update(true, false)
      plain = scene.update(false, false)
      ordinary = scene.update(false, true)
      GenOneStyle.new.update(true)
      $start_key = false
      outside = continueKeyPressed?
      begin
        scene.update(true, false, true)
      rescue ArgumentError
        after_error = continueKeyPressed?
      end
      [swallowed, plain, ordinary.first, outside, after_error, scene.update(false, false)]
    end
  RUBY

  profile "infinitefusion", WORLD, PLAY, "gamedata"

  test "Kanto's original style confirmation is delivered once inside its title scene" do
    assert_equal [], played(:load_errors)
    assert_equal [[true, false], [false, false], true, false, false, [false, false]], played(:title)
  end
end
