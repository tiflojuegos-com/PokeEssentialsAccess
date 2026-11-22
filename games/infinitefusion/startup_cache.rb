module PokeAccess
  module InfiniteFusionStartupCache
    # The game downloads this large optional dictionary before showing its menu.
    # A valid local copy lets the player open the menu without a download.
    def self.valid?(path)
      return false unless path.is_a?(String) && File.file?(path) && File.size(path) > 0
      data = HTTPLite::JSON.parse(File.read(path))
      data.is_a?(Array) && !data.empty? && data.all? do |entry|
        entry.is_a?(Hash) && entry["sprite"].is_a?(String) && entry["entry"].is_a?(String)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    def self.path
      return nil unless defined?(::Settings) && ::Settings.const_defined?(:CUSTOM_DEX_ENTRIES_PATH)
      ::Settings::CUSTOM_DEX_ENTRIES_PATH
    end
  end
end

PokeAccess::Config.define(:if_cached_dex_startup, true, :flag, :general,
                          :lbl_if_cached_dex_startup, :help_if_cached_dex_startup)

PokeAccess::Game.define("infinitefusion") do
  kernel("updateCustomDexFile", :around) do |_args, original|
    if PokeAccess::Config.if_cached_dex_startup
      path = PokeAccess::InfiniteFusionStartupCache.path
      next path if PokeAccess::InfiniteFusionStartupCache.valid?(path)
    end
    original.call
  end
end
