# The optional Pokédex download runs before the load menu.
class InfiniteFusionStartupCacheGdTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    require "json"
    module HTTPLite
      JSON = ::JSON
    end

    def updateCustomDexFile
      $downloads += 1
      raise IOError, "download failed" if $download_error
      :downloaded
    end
  RUBY

  PLAY = <<-'RUBY'
    Dir.mktmpdir("pa_kanto_dex") do |directory|
      Settings.const_set(:CUSTOM_DEX_ENTRIES_PATH, File.join(directory, "dex.json"))
      path = Settings::CUSTOM_DEX_ENTRIES_PATH
      config = PokeAccess::Config
      bytes = '[{"sprite":"1.1.png","entry":"Sample"}]'
      $downloads = 0

      probe(:reuse) do
        File.binwrite(path, bytes)
        old = Time.now - 90 * 24 * 60 * 60
        File.utime(old, old, path)
        mtime = File.mtime(path)
        result = updateCustomDexFile
        [config.if_cached_dex_startup, result == path, $downloads, File.binread(path) == bytes, File.mtime(path) == mtime]
      end

      probe(:refresh) do
        config.if_cached_dex_startup = false
        [updateCustomDexFile, $downloads]
      end

      probe(:fallback) do
        config.if_cached_dex_startup = true
        $downloads = 0
        File.binwrite(path, "not JSON")
        malformed = updateCustomDexFile
        File.binwrite(path, "[]")
        empty = updateCustomDexFile
        File.binwrite(path, '[{"sprite":null,"entry":"Sample"}]')
        bad_entry = updateCustomDexFile
        File.delete(path)
        missing = updateCustomDexFile
        $download_error = true
        error = begin
          updateCustomDexFile
        rescue IOError => e
          e.message
        end
        [malformed, empty, bad_entry, missing, error, $downloads]
      end
    end
  RUBY

  profile "infinitefusion", WORLD, PLAY, "gamedata"

  test "the menu reuses an older valid dictionary by default and keeps its timestamp" do
    assert_equal [true, true, 0, true, true], played(:reuse)
  end

  test "switching cache reuse off runs the original download even with a usable file" do
    assert_equal [:downloaded, 1], played(:refresh)
  end

  test "missing or invalid files use the original download and preserve its errors" do
    assert_equal [:downloaded, :downloaded, :downloaded, :downloaded, "download failed", 5], played(:fallback)
  end
end
