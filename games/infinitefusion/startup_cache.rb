module PokeAccess
  module InfiniteFusionStartupCache
    MAX_AGE = 24 * 60 * 60

    # The game downloads this large optional dictionary before showing its menu.
    # Reuse only a recent, nonempty, valid dictionary; never replace its downloader.
    def self.fresh?(path, now = Time.now)
      return false unless path.is_a?(String) && File.file?(path) && File.size(path) > 0
      age = now.to_f - File.mtime(path).to_f
      return false if age < 0 || age >= MAX_AGE
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

PokeAccess::Game.define("infinitefusion") do
  kernel("updateCustomDexFile", :around) do |_args, original|
    path = PokeAccess::InfiniteFusionStartupCache.path
    PokeAccess::InfiniteFusionStartupCache.fresh?(path) ? path : original.call
  end
end
