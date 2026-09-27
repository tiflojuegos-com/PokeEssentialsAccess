module PokeAccess
  # On-disk layout inside the game's accessibility folder. Loaded first so other modules can use it.
  # The loader scripts (boot.rb, preload_access.rb) stay at the root and use literal paths.
  module Paths
    ROOT   = "accessibility"
    CORE   = "accessibility/core"
    GAME   = "accessibility/game"
    SOUNDS = "accessibility/sounds"
    LIB    = "accessibility/lib"
    LANG   = "accessibility/lang"

    # The writable folder for runtime files, chosen once: accessibility/data (or POKEACCESS_DATA_DIR, which the
    # test harness sets), else mkxp-z's per-game data directory.
    DATA = begin
      override = (ENV["POKEACCESS_DATA_DIR"] rescue nil)
      candidates = (override && !override.to_s.empty?) ? [override] : ["accessibility/data"]
      base = (System.data_directory rescue nil)
      candidates << "#{base}/accessibility" if base && !base.to_s.empty?
      pick = candidates.detect do |d|
        begin
          Dir.mkdir(d) unless (File.directory?(d) rescue false)
          probe = "#{d}/.wtest"
          File.open(probe, "w") { |f| f.write("1") }
          (File.delete(probe) rescue nil)
          true
        rescue StandardError
          false
        end
      end
      pick || "accessibility/data"
    end
  end
end
