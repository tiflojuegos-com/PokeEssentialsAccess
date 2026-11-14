# Source 1.5.5 has a system FontInstaller whose restart starts the CLR wrapper.
# Register bundled fonts for this process and leave that old installer inactive.
# This preload runs before game scripts; it changes no game file or save path.
module XenoverseCompat
  def self.write_marker(message)
    File.open('accessibility/data/compat_fonts.txt', 'a') { |log| log.puts(message) }
  rescue StandardError => error
    detail = "#{message}; font log unavailable: #{error.class}: #{error.message}"
    if defined?(PokeAccess) && PokeAccess.respond_to?(:write_marker)
      PokeAccess.write_marker(detail)
    else
      warn(detail)
    end
  end

  def self.private_fonts
    @registered_fonts = 0
    api = Win32API.new('gdi32', 'AddFontResourceExA', ['p', 'i', 'i'], 'i')
    Dir.glob('Fonts/*').each do |file|
      next unless File.file?(file) && file =~ /\.(ttf|otf)\z/i
      if api.call(file + "\0", 0x10, 0) > 0
        @registered_fonts += 1
      else
        write_marker('Private font registration failed: ' + file)
      end
    end
  rescue StandardError => error
    write_marker("#{error.class}: #{error.message}")
  end

  def self.registered_fonts
    @registered_fonts || 0
  end

  def self.skip_system_installer
    mod = Object.const_defined?(:FontInstaller) ? Object.const_get(:FontInstaller) : Object.const_set(:FontInstaller, Module.new)
    meta = class << mod; self; end
    meta.send(:define_method, :singleton_method_added) do |name|
      if name == :install && !@xenoverse_compat_busy
        @xenoverse_compat_busy = true
        meta.send(:define_method, :install) { |*args| nil }
        @xenoverse_compat_busy = false
      end
    end
  end
end

XenoverseCompat.private_fonts
XenoverseCompat.skip_system_installer
