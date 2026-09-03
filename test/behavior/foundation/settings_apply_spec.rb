# Settings.apply is the one boot step the harness never ran: boot.rb applies the player's settings.ini
# over the profile defaults, but Harness.load_all stops at the profile and Reset returns everything to
# SCHEMA -- so the whole suite always ran on factory config and a parse crash or a wrong clamp in apply
# was invisible. Driven here through the real read/apply/write cycle against a scratch ini, with FILE
# repointed for the duration.
Suite.define("settings: apply reads a player ini over the defaults, clamped and typed") do
  dir = File.join(File.dirname(__FILE__), "tmp_settings")
  Dir.mkdir(dir) unless File.directory?(dir)
  file = File.join(dir, "settings.ini")
  old_file = PokeAccess::Settings::FILE
  begin
    PokeAccess::Settings.send(:remove_const, :FILE)
    PokeAccess::Settings.const_set(:FILE, file)

    File.open(file, "w") do |f|
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

    # The ini above lacks most schema keys, so apply must have rewritten it complete: a new setting is
    # editable by hand right after updating, without opening the config menu first.
    rewritten = File.read(file)
    missing = PokeAccess::Settings.schema_keys.reject { |k| rewritten =~ /^#{Regexp.escape(k)}=/ }
    eq "apply rewrote the ini with every schema key", missing, []

    # An absent file is created with the defaults -- the first-boot path.
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
