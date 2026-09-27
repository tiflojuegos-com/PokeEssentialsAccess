# Settings.apply, which the harness never runs: the real read/apply/write cycle on a scratch ini (FILE repointed),
# stamped with the current VERSION so that its language is not migrated to :auto.
Suite.define("settings: apply reads a player ini over the defaults, clamped and typed") do
  dir = File.join(File.dirname(__FILE__), "tmp_settings")
  Dir.mkdir(dir) unless File.directory?(dir)
  file = File.join(dir, "settings.ini")
  old_file = PokeAccess::Settings::FILE
  begin
    PokeAccess::Settings.send(:remove_const, :FILE)
    PokeAccess::Settings.const_set(:FILE, file)

    File.open(file, "w") do |f|
      f.write("settings_version=#{PokeAccess::Settings::VERSION}\n")
      f.write("audio3d_volume=250\n")
      f.write("guide_distance=abc\n")
      f.write("auto_guide=true\n")
      f.write("language=en\n")
      f.write("sound_nav=basic\n")
      f.write("bind_saltar=65\n")
      f.write("key_next=88\n")
      f.write("key_bogus=99\n")
    end
    PokeAccess::Settings.apply

    eq "a numeric above its bound is clamped to the max", PokeAccess::Config.audio3d_volume, 100
    eq "a non-numeric value clamps to the kind's minimum", PokeAccess::Config.guide_distance, 1
    eq "a flag line flips its flag", PokeAccess::Config.auto_guide, true
    eq "a symbol setting is applied as a symbol", PokeAccess::Config.language, :en
    eq "and so is the nav mode", PokeAccess::Config.sound_nav, :basic
    eq "a bind_ line lands in the rebinds", (PokeAccess::Config.rebinds || {})[:saltar], 65
    eq "a key_ line overrides a mod hotkey the mod has", PokeAccess::Config.keys[:next], 88
    falsy "and an unknown action name cannot invent one", PokeAccess::Config.keys.has_key?(:bogus)

    rewritten = File.read(file)
    missing = PokeAccess::Settings.schema_keys.reject { |k| rewritten =~ /^#{Regexp.escape(k)}=/ }
    eq "apply rewrote the ini with every schema key", missing, []
    truthy "and stamped the layout version", rewritten =~ /^settings_version=#{PokeAccess::Settings::VERSION}$/

    PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup
    PokeAccess::Config.rebinds = {}
    File.open(file, "w") do |f|
      f.write("settings_version=#{PokeAccess::Settings::VERSION}\n")
      f.write("bind_l=36\n")
      f.write("key_hp=35\n")
    end
    PokeAccess::Settings.apply
    eq "a default key a saved binding already uses gives way to it (Home was the L button's)",
       [PokeAccess::Config.keys[:hist_prev], PokeAccess::Config.rebinds[:l]], [nil, 36]
    eq "and to a mod key the player moved there (End was the HP key's)",
       [PokeAccess::Config.keys[:hist_next], PokeAccess::Config.keys[:hp]], [nil, 35]
    eq "the other defaults stay", PokeAccess::Config.keys[:next], PokeAccess::Config::KEY_DEFAULTS[:next]
    PokeAccess::Config.rebinds = {}

    File.delete(file)
    PokeAccess::Settings.apply
    truthy "a missing ini is created", File.file?(file)
  ensure
    PokeAccess::Settings.send(:remove_const, :FILE)
    PokeAccess::Settings.const_set(:FILE, old_file)
    PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup
    (File.delete(file) rescue nil)
    (Dir.rmdir(dir) rescue nil)
  end
end
