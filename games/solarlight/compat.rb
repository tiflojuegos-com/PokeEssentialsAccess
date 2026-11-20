# Pokemon Solar Light & Lunar Dark on mkxp-z: mkxp.json's preloadScript runs this file before the game's scripts and
# the mod's loader. Its title screen calls FontInstaller.install (0159_PScreen_Load.rb), which finds the game's fonts
# missing from Windows' font folder, says so in two messages, tries to copy them there and asks to restart, on every
# boot; mkxp-z already draws with the game's Fonts folder, so the install becomes a no-op.
module SolarLightCompat
  # Creates FontInstaller ahead of the game, so the install it defines later is replaced by a no-op at once.
  def self.skip_font_installer
    mod = Object.const_defined?(:FontInstaller) ? ::FontInstaller : Object.const_set(:FontInstaller, Module.new)
    meta = (class << mod; self; end)
    meta.send(:define_method, :singleton_method_added) do |name|
      if name == :install && !@solar_compat_busy
        @solar_compat_busy = true
        meta.send(:define_method, :install) { |*args| nil }
        @solar_compat_busy = false
      end
    end
  end

  # Runs the neutralization; a failure is written to accessibility/compat_error.txt.
  def self.apply
    skip_font_installer
  rescue StandardError => e
    Dir.mkdir("accessibility") unless File.directory?("accessibility")
    File.open("accessibility/compat_error.txt", "w") do |f|
      f.puts("#{e.class}: #{e.message}")
      (e.backtrace || [])[0, 5].each { |l| f.puts(l) }
    end
  end
end

SolarLightCompat.apply
