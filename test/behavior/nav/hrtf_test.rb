require "tmpdir"

class HrtfTest < PokeAccessTest
  Cfg = PokeAccess::Config
  Pa3d = PokeAccess::Sound::Pa3d

  test "headphone output defaults on and all output labels are translated" do
    row = Cfg.setting(:audio3d_output)
    assert_equal [:binaural, :output, :audio], [row.default, row.kind, row.group]
    [:en, :pl, :es, :fr, :de, :pt].each do |language|
      Cfg.language = language
      [:lbl_pos_output, :help_pos_output, :output_binaural, :output_stereo].each do |key|
        refute_equal key.to_s, PokeAccess::I18n.t(key)
        refute_equal "", PokeAccess::I18n.t(key)
      end
    end
  end

  test "boot applies a saved stereo choice before any source plays" do
    Cfg.audio3d_output = :stereo
    with_sound_engine(false) do |dll|
      assert_equal true, Pa3d.boot
      assert_equal [[2]], dll.args(:output)
      assert_equal [], dll.played
      Pa3d.output(:stereo)
      assert_equal [[2]], dll.args(:output), "the cached choice is not resent"
      Pa3d.output(:binaural)
      assert_equal [[2], [0]], dll.args(:output)
      assert_equal [], dll.args(:set), "changing output does not restart sources"
    end
  end

  test "an older DLL without the optional output export still plays sound" do
    with_sound_engine(true, 44100, [:output]) do |dll|
      assert_equal true, Pa3d.ready?
      Pa3d.output(:stereo)
      assert_equal [], dll.args(:output)
      assert_equal false, Cfg.visible?(Cfg.setting(:audio3d_output))
      Pa3d.start(:npc, 6, 5, 70)
      assert_equal [[:npc, 6, 5, 70]], dll.played
    end
  end

  test "every output persists without changing navigation sound mode" do
    with_settings_file do |_path|
      [:binaural, :stereo, :mono, :quad, :surround51, :surround71].each do |value|
        Cfg.audio3d_output = value
        Cfg.sound_nav = :full
        assert_equal true, PokeAccess::Settings.write
        Cfg.audio3d_output = :binaural
        PokeAccess::Settings.apply
        assert_equal [value, :full], [Cfg.audio3d_output, Cfg.sound_nav]
      end
    end
  end

  test "legacy HRTF choices migrate and a new explicit output wins" do
    with_settings_file do |path|
      {"true" => :binaural, "false" => :stereo}.each do |legacy, expected|
        File.binwrite(path, "audio3d_hrtf=#{legacy}\nsound_nav=full\n")
        Cfg.audio3d_output = :mono
        PokeAccess::Settings.apply
        assert_equal [expected, :full], [Cfg.audio3d_output, Cfg.sound_nav]
        assert_includes File.read(path), "audio3d_output=#{expected}"
        refute_includes File.read(path), "audio3d_hrtf="
      end
      File.binwrite(path, "audio3d_hrtf=false\naudio3d_output=mono\n")
      PokeAccess::Settings.apply
      assert_equal :mono, Cfg.audio3d_output
    end
  end

  test "output choice is shown only with its native export and sound enabled" do
    with_sound_engine do
      Cfg.sound_nav = :full
      row = Cfg.setting(:audio3d_output)
      assert_equal true, Cfg.visible?(row)
      Cfg.sound_nav = :off
      assert_equal false, Cfg.visible?(row)
    end
  end

  def with_settings_file
    Dir.mktmpdir do |folder|
      previous = PokeAccess::Settings::FILE
      PokeAccess::Settings.send(:remove_const, :FILE)
      PokeAccess::Settings.const_set(:FILE, File.join(folder, "settings.ini"))
      begin
        yield PokeAccess::Settings::FILE
      ensure
        PokeAccess::Settings.send(:remove_const, :FILE)
        PokeAccess::Settings.const_set(:FILE, previous)
      end
    end
  end
end