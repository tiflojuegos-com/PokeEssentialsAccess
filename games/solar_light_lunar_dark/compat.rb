# The original FontInstaller copies into Windows/Fonts and requests a restart.
# Converted mkxp-z runs without system font installation; register bundled fonts
# privately for this process, then prevent the old installer from writing there.
module SolarLightCompat
  # Font registration is optional, but a failed attempt remains diagnosable before the mod loads.
  def self.write_marker(error)
    Dir.mkdir("accessibility") unless File.directory?("accessibility")
    File.open("accessibility/compat_fonts.txt", "a") do |file|
      file.puts("#{error.class}: #{error.message}")
    end
  end

  def self.private_fonts
    api = Win32API.new("gdi32", "AddFontResourceExA", ["p", "i", "i"], "i")
    Dir.glob("Fonts/*.ttf").each { |file| api.call(file + "\0", 0x10, 0) }
  rescue StandardError => error
    write_marker(error)
  end

  def self.skip_system_installer
    mod = Object.const_defined?(:FontInstaller) ? ::FontInstaller : Object.const_set(:FontInstaller, Module.new)
    meta = class << mod; self; end
    meta.send(:define_method, :singleton_method_added) do |name|
      if name == :install && !@solar_compat_busy
        @solar_compat_busy = true
        meta.send(:define_method, :install) { |*args| nil }
        @solar_compat_busy = false
      end
    end
  end
end
SolarLightCompat.private_fonts
SolarLightCompat.skip_system_installer
