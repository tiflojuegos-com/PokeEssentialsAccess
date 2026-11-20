# Pokemon Xenoverse on its own mkxp-z (snGame_n.exe): mkxp.json's preloadScript runs this file before the game's scripts
# and the mod's loader. FontInstaller.install (0118_PScreen_Load) copies the fonts into Windows' folder and offers to
# restart through system('Game'), the launcher that starts the RPG Maker XP player, where the mod does not run: it becomes
# a no-op, as in Uranium. mkxp-z reads the game's Fonts folder on its own.
module XenoverseCompat
  # Creates FontInstaller ahead of the game, so the install it defines later is replaced by a no-op at once.
  def self.skip_font_installer
    mod = Object.const_defined?(:FontInstaller) ? ::FontInstaller : Object.const_set(:FontInstaller, Module.new)
    meta = (class << mod; self; end)
    meta.send(:define_method, :singleton_method_added) do |name|
      if name == :install && !@xenoverse_compat_busy
        @xenoverse_compat_busy = true
        meta.send(:define_method, :install) { |*args| nil }
        @xenoverse_compat_busy = false
      end
    end
  end

  # Runs the neutralization; a failure is written to accessibility/compat_error.txt.
  def self.apply
    skip_font_installer
  rescue StandardError => e
    File.open("accessibility/compat_error.txt", "w") { |f| f.write("#{e.class}: #{e.message}\n") } rescue nil
  end
end

XenoverseCompat.apply
