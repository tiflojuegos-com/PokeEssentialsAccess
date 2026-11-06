require File.expand_path("if_speech_bubbles_gd_test", File.dirname(__FILE__))

# Extend the upstream real dialogue/bubble fixtures without rerunning inherited copies of their tests.
class IfSpeechBubblesGdTest
  test "speaker position is a profile-defined General choice with the existing behavior enabled" do
    setting = PokeAccess::Config.settings.find { |row| row.key == :if_speaker_location }
    refute_nil setting
    assert_equal true, setting.default
    assert_equal :general, setting.group
    assert_equal :flag, setting.kind
  end

  test "disabled position leaves untagged dialogue and route guidance intact" do
    cfg = PokeAccess::Config
    plan = PokeAccess::Routes::Plan.new(:walk, [8, 8, 4], nil, nil)
    route = PokeAccess::Routes::Text.line(plan)
    cfg.if_speaker_location = false
    in_room { bubble(2, 14, "Studio dialogue") }
    assert_equal ["Studio dialogue"], SpeakCapture.lines
    assert_equal route, PokeAccess::Routes::Text.line(plan)
  end

  test "disabled position retains a user tag without coordinates" do
    PokeAccess::Config.if_speaker_location = false
    in_room { bubble(1, 15, "Studio tagged dialogue") }
    assert_equal ["hermana: Studio tagged dialogue"], SpeakCapture.lines
  end

  test "re-enabling position reports the speaker's current place after movement" do
    in_room do
      PokeAccess::Config.if_speaker_location = false
      bubble(2, 14, "Studio first")
      PokeAccess::Config.if_speaker_location = true
      World.event(:id => 14, :x => 20, :y => 18, :name => "fake kid")
      bubble(2, 14, "Studio second")
    end
    assert_equal ["Studio first", "#{from(t(:moved_right, :n => 2))}: Studio second"], SpeakCapture.lines
  end

  test "both speaker-position choices survive a real settings write and reload" do
    Dir.mktmpdir do |folder|
      previous = PokeAccess::Settings::FILE
      PokeAccess::Settings.send(:remove_const, :FILE)
      path = File.join(folder, "settings.ini")
      PokeAccess::Settings.const_set(:FILE, path)
      begin
        [false, true].each do |value|
          PokeAccess::Config.if_speaker_location = value
          assert_equal true, PokeAccess::Settings.write
          assert_includes File.read(path), "if_speaker_location=#{value}\n"
          PokeAccess::Config.if_speaker_location = !value
          PokeAccess::Settings.apply
          assert_equal value, PokeAccess::Config.if_speaker_location
        end
      ensure
        PokeAccess::Settings.send(:remove_const, :FILE)
        PokeAccess::Settings.const_set(:FILE, previous)
      end
    end
  end
end
