require 'json'
require 'tmpdir'

module HTTPLite
  module JSON
    def self.parse(text); ::JSON.parse(text); end
  end
end

load File.join(Harness::ROOT, "games/infinitefusion/startup_cache.rb")

class InfiniteFusionStartupCacheGdTest < PokeAccessTest
  def with_singleton(object, name, body)
    previous = object.singleton_methods.include?(name) ? object.method(name) : nil
    object.define_singleton_method(name, &body)
    yield
  ensure
    previous ? object.define_singleton_method(name, previous) : object.singleton_class.send(:remove_method, name)
  end

  Cache = PokeAccess::InfiniteFusionStartupCache

  def with_file(text, age)
    Dir.mktmpdir('if-dex-cache-') do |directory|
      path = File.join(directory, 'dex.json')
      File.binwrite(path, text)
      now = Time.now
      File.utime(now - age, now - age, path)
      yield path, now
    end
  end

  def with_game_dictionary_path(path)
    existed = Object.const_defined?(:Settings, false)
    settings = existed ? Object.const_get(:Settings) : Object.const_set(:Settings, Module.new)
    had_path = settings.const_defined?(:CUSTOM_DEX_ENTRIES_PATH, false)
    previous = settings.const_get(:CUSTOM_DEX_ENTRIES_PATH) if had_path
    settings.send(:remove_const, :CUSTOM_DEX_ENTRIES_PATH) if had_path
    settings.const_set(:CUSTOM_DEX_ENTRIES_PATH, path)
    yield
  ensure
    settings.send(:remove_const, :CUSTOM_DEX_ENTRIES_PATH)
    settings.const_set(:CUSTOM_DEX_ENTRIES_PATH, previous) if had_path
    Object.send(:remove_const, :Settings) unless existed
  end

  def test_recent_valid_dictionary_is_reused_without_changing_it
    with_file('[{"sprite":"1.1.png","entry":"Bulbasaur","author":"Author"}]', 60) do |path, now|
      before = File.binread(path)
      assert_equal true, Cache.fresh?(path, now)
      assert_equal before, File.binread(path)
    end
  end

  def test_missing_empty_malformed_and_wrong_shape_files_use_the_original_downloader
    [nil, '', 'missing-file.json'].each { |path| assert_equal false, Cache.fresh?(path) }
    ['', 'not JSON', '{}', '[]', 'null', '"dictionary"', '[1]', '[{}]', '[{"sprite":1,"entry":"text"}]'].each do |text|
      with_file(text, 60) { |path, now| assert_equal false, Cache.fresh?(path, now) }
    end
  end

  def test_expired_and_future_timestamps_are_not_treated_as_fresh
    [Cache::MAX_AGE, Cache::MAX_AGE + 10, -60].each do |age|
      with_file('[{"sprite":"1.1.png","entry":"text"}]', age) { |path, now| assert_equal false, Cache.fresh?(path, now) }
    end
    with_file('[{"sprite":"1.1.png","entry":"text"}]', Cache::MAX_AGE - 10) do |path, now|
      assert_equal true, Cache.fresh?(path, now)
    end
  end

  def test_production_kernel_hook_skips_only_fresh_data_and_preserves_original_results_and_errors
    calls = 0
    fail_download = false
    with_file('[{"sprite":"1.1.png","entry":"text"}]', 60) do |path, now|
      downloader = lambda do
        calls += 1
        raise IOError, 'Download failed' if fail_download
        :downloaded
      end
      GameFunctions.with(:updateCustomDexFile => downloader) do
        verbose = $VERBOSE
        begin
          $VERBOSE = nil
          load File.join(Harness::ROOT, "games/infinitefusion/startup_cache.rb")
        ensure
          $VERBOSE = verbose
        end
        with_game_dictionary_path(path) do
          receiver = Object.new
          assert_equal path, Cache.path
          assert_equal path, receiver.send(:updateCustomDexFile)
          assert_equal 0, calls
          File.utime(now - Cache::MAX_AGE - 10, now - Cache::MAX_AGE - 10, path)
          assert_equal :downloaded, receiver.send(:updateCustomDexFile)
          assert_equal 1, calls
          fail_download = true
          assert_raises(IOError) { receiver.send(:updateCustomDexFile) }
          assert_equal 2, calls
        end
      end
    end
  end
end
