# A volume or tone row of the audio menus auditions its family's sound on every press: through the positional engine
# when it is up (on the player, after the master volume and the family's tone), else as the flat glossary sample; a
# looping sample is stopped once its two seconds are up or another row auditions.
class ConfigPreviewTest < PokeAccessTest
  Menu = PokeAccess::ConfigMenu
  NPC_FILE = "#{PokeAccess::Paths::SOUNDS}/pa3d_npc"

  test "lists the sound switches first in the audio screen, the tones after the volumes and frequencies" do
    Reset.with_capability(:positional, true) do
      in_mode(:audio) do
        assert_equal [:audio3d_on, :audio3d_vol, :audio3d_freq, :audio3d_tone, :audio3d_walls, :audio3d_adv],
                     Menu.items.select { |i| i[:kind] == :enter }.map { |i| i[:group] }
      end
    end
  end

  test "lists every tone in the tones screen in declaration order, closed by the back row" do
    Reset.with_capability(:positional, true) do
      in_mode(:audio3d_tone) do
        tones = PokeAccess::Config.settings.select { |s| s.kind == :tone }.map { |s| [:setting, s.key] }
        assert_equal tones + [[:back, nil]], Menu.items.map { |i| [i[:kind], i[:row] && i[:row].key] }
      end
    end
  end

  test "says a tone row as its label and a bare number" do
    Reset.with_capability(:positional, true) do
      in_mode(:audio3d_tone) do
        assert_equal "#{PokeAccess::I18n.t(:lbl_tone_people)}, 50", Menu.describe(Menu.items[0])
      end
    end
  end

  test "steps a row by its kind's step and says its label and new value" do
    with_engine do
      steps = { :audio3d_tone_door => [55, :lbl_tone_doors], :audio3d_door => [95, :lbl_pos_doors] }
      steps.each do |key, (want, label)|
        SpeakCapture.clear
        adjust(key, 1)
        assert_equal want, PokeAccess::Config.send(key), "#{key} after a press"
        assert_equal [["#{PokeAccess::I18n.t(label)}, #{want}", true]], SpeakCapture.log, "said for #{key}"
      end
    end
  end

  test "holds a tone at 100 and at 0" do
    with_engine do
      { [100, 1] => 100, [0, -1] => 0 }.each do |(start, dir), want|
        PokeAccess::Config.audio3d_tone_door = start
        adjust(:audio3d_tone_door, dir)
        assert_equal want, PokeAccess::Config.audio3d_tone_door, "from #{start}, pressed #{dir}"
      end
    end
  end

  test "auditions a tone by sending the master, pitching the family's channel and playing it on the player" do
    with_engine do |dll|
      adjust(:audio3d_tone_door, 1)
      assert_equal [:listener, :master, :pitch, :occl, :set], dll.log.map { |name, _args| name },
                   "the calls, in order: the listener on the player, the master, the pitch, no muffle, the sound"
      assert_equal [80], dll.args(:master)[0], "the master volume"
      assert_equal [[:door, 107]], dll.by_sound(:pitch), "the door's channel at tone 55"
      assert_equal [[:door, 4, 6, 85]], dll.played, "the door sound on the player at the doors' volume"
    end
  end

  test "auditions tone 0 an octave down and tone 100 an octave up on the engine" do
    with_engine do |dll|
      { 5 => [-1, 50], 95 => [1, 200] }.each do |start, (dir, pitch)|
        dll.log.clear
        PokeAccess::Config.audio3d_tone_door = start
        adjust(:audio3d_tone_door, dir)
        assert_equal [[:door, pitch]], dll.by_sound(:pitch), "from tone #{start}, pressed #{dir}"
      end
    end
  end

  test "auditions a volume row's family at the value just set" do
    with_engine do |dll|
      adjust(:audio3d_door, 1)
      assert_equal [[:door, 4, 6, 95]], dll.played
    end
  end

  test "sends neither the master nor the pitch again while they stand" do
    with_engine do |dll|
      adjust(:audio3d_tone_door, 1)
      dll.log.clear
      adjust(:audio3d_door, 1)
      assert_equal [:set], dll.log.map { |name, _args| name }
    end
  end

  test "the master row sends the changed master again before playing the people's sound at their own volume" do
    with_engine do |dll|
      adjust(:audio3d_tone_door, 1)
      dll.log.clear
      adjust(:audio3d_volume, 1)
      assert_equal [:master, [90]], dll.log[0], "the new master first, the dll having heard 80"
      assert_equal [[:npc, 4, 6, 85]], dll.played, "then the people's sound at their own volume"
    end
  end

  test "plays a looping sample at its family's volume and stops it when its two seconds are up" do
    with_clock(100.0) do |set_clock|
      with_engine do |dll|
        adjust(:audio3d_tone_water, -1)
        assert_equal [[:water, 4, 6, 70]], dll.played, "the water on the player at its volume"
        set_clock.call(101.9)
        Menu.expire_preview
        assert_equal [], dll.stopped, "before its time"
        set_clock.call(102.0)
        Menu.expire_preview
        assert_equal [:water], dll.stopped, "when its time is up"
      end
    end
  end

  test "forgets a loop it stopped, leaving the channel alone once something else plays it again" do
    with_clock(100.0) do |set_clock|
      with_engine do |dll|
        adjust(:audio3d_tone_water, -1)
        set_clock.call(102.0)
        Menu.expire_preview
        PokeAccess::Sound::Pa3d.hold(:water, 5, 6, 60)
        dll.log.clear
        Menu.expire_preview
        assert_equal [], dll.stopped
      end
    end
  end

  test "stops the loop that was playing when another row auditions" do
    with_engine do |dll|
      adjust(:audio3d_tone_wind, 1)
      adjust(:audio3d_tone_npc, 1)
      assert_equal [:wind_n], dll.stopped
    end
  end

  test "leaves a one-shot sample alone when the loop time passes" do
    with_clock(100.0) do |set_clock|
      with_engine do |dll|
        adjust(:audio3d_tone_npc, 1)
        set_clock.call(103.0)
        Menu.expire_preview
        assert_equal [], dll.stopped
      end
    end
  end

  test "has nothing to audition on a frequency row" do
    with_engine do |dll|
      adjust(:audio3d_freq_door, 1)
      assert_equal [], dll.log
    end
  end

  test "auditions nothing once a family's volume is brought to zero, nor any of its tones" do
    with_engine do |dll|
      PokeAccess::Config.audio3d_door = 10
      adjust(:audio3d_door, -1)
      adjust(:audio3d_tone_door, 1)
      assert_equal 0, PokeAccess::Config.audio3d_door, "the doors' volume"
      assert_equal [], dll.log
    end
  end

  test "still auditions a family at the lowest volume above zero" do
    with_engine do |dll|
      PokeAccess::Config.audio3d_door = 1
      adjust(:audio3d_tone_door, 1)
      assert_equal [[:door, 4, 6, 1]], dll.played
    end
  end

  test "with the engine down cuts the last sample and plays the family's file flat at its volume and tone" do
    with_flat do |log|
      adjust(:audio3d_tone_npc, 1)
      assert_equal [[:se_stop, []], [:se_play, [NPC_FILE, 85, 107]]], log
    end
  end

  test "with the engine down plays a volume row at the value just set" do
    with_flat do |log|
      adjust(:audio3d_npc, -1)
      assert_equal [:se_play, [NPC_FILE, 75, 100]], log.last
    end
  end

  test "with the engine down holds the pitch at the flat channel's ceiling of 150" do
    with_flat do |log|
      PokeAccess::Config.audio3d_tone_npc = 95
      adjust(:audio3d_tone_npc, 1)
      assert_equal [:se_play, [NPC_FILE, 85, 150]], log.last
    end
  end

  private

  # Presses left (-1) or right (1) on the row of a setting.
  def adjust(key, dir)
    Menu.adjust_setting(PokeAccess::Config.setting(key), dir)
  end

  # Runs the block with the positional engine up on a shadow (yielded) and the player at (4, 6); an audition still
  # playing is stopped after.
  def with_engine
    with_sound_engine do |dll|
      begin
        $game_player.x = 4
        $game_player.y = 6
        yield dll
      ensure
        Menu.stop_preview
      end
    end
  end

  # Runs the block with the positional engine down and the flat channel's se_play and se_stop recorded (yielded) as
  # [name, args]; an audition still playing is stopped after and the channel put back.
  def with_flat
    log = []
    play = Audio.method(:se_play)
    stop = Audio.method(:se_stop)
    Audio.define_singleton_method(:se_play) { |*a| log.push([:se_play, a]); nil }
    Audio.define_singleton_method(:se_stop) { |*a| log.push([:se_stop, a]); nil }
    with_sound_engine(false) { yield log }
  ensure
    Menu.stop_preview
    Audio.define_singleton_method(:se_play, play)
    Audio.define_singleton_method(:se_stop, stop)
  end

  # Runs the block with the mod's clock stopped at start; the block is handed a setter that moves it.
  def with_clock(start)
    now = start
    original = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now }
    yield lambda { |t| now = t }
  ensure
    PokeAccess.define_singleton_method(:clock, original)
  end

  # Runs the block with the menu on a mode's screen, at its first row; the mode and row before put back.
  def in_mode(mode)
    was = [Menu.instance_variable_get(:@mode), Menu.instance_variable_get(:@index)]
    Menu.instance_variable_set(:@mode, mode)
    Menu.instance_variable_set(:@index, 0)
    yield
  ensure
    Menu.instance_variable_set(:@mode, was[0])
    Menu.instance_variable_set(:@index, was[1])
  end
end
