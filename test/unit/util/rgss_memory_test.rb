# RgssMemory, the stand-ins for the RPG Maker XP player's memory: pixels copied through raw_data in the player's
# layout (BGRA, bottom row first), pointer methods that raise instead of aborting, mkxp-z's snapshot in place of the
# game's, and the DLL calls that reach into the player answered without running.
require "tmpdir"
require "zlib"

class RgssMemoryTest < PokeAccessTest
  NATIVE = "read the player's memory"

  # A 2x2 bitmap in mkxp-z's layout: top row red then green, bottom row blue then white, alpha 10 to 40.
  RAW = [255, 0, 0, 10, 0, 255, 0, 20, 0, 0, 255, 30, 255, 255, 255, 40].pack("C*")

  # The same pixels in the player's layout.
  RGSS = [255, 0, 0, 30, 255, 255, 255, 40, 0, 0, 255, 10, 0, 255, 0, 20].pack("C*")

  def setup
    super
    @bound = PokeAccess::Hooks.instance_variable_get(:@bound)
    @kept = @bound.length
  end

  def teardown
    @bound.slice!(@kept..-1)
    super
  end

  test "converts mkxp-z's pixels to the player's layout and back" do
    assert_equal RGSS, PokeAccess::RgssMemory.swap_layout(RAW, 2, 2)
    assert_equal RAW, PokeAccess::RgssMemory.swap_layout(RGSS, 2, 2)
  end

  test "reads and writes the pixels without the player's memory" do
    bitmap_class = hacked_bitmap
    PokeAccess::RgssMemory.patch_bitmap(bitmap_class)
    bm = bitmap_class.new(2, 2)
    bm.raw = RAW
    assert_equal [RGSS, RGSS], [bm.getData, bm.get_data]
    [:setData, :set_data].each do |m|
      bm.raw = "\0" * 16
      bm.send(m, RGSS)
      assert_equal RAW, bm.raw, "through #{m}"
    end
  end

  test "ignores pixels of another size, as raw_data= does" do
    bitmap_class = hacked_bitmap
    PokeAccess::RgssMemory.patch_bitmap(bitmap_class)
    bm = bitmap_class.new(2, 2)
    bm.raw = RAW
    bm.setData("short")
    assert_equal RAW, bm.raw
  end

  test "makes the pointer methods raise a readable error" do
    bitmap_class = hacked_bitmap
    PokeAccess::RgssMemory.patch_bitmap(bitmap_class)
    [:address, :last_row_address].each do |m|
      e = assert_raises(PokeAccess::RgssMemory::Unavailable) { bitmap_class.new(2, 2).send(m) }
      assert_equal PokeAccess::I18n.t(:rgss_memory_missing, :method => "Bitmap##{m}"), e.message
    end
  end

  test "gives get_data_ptr a copy the block reads and frees" do
    bitmap_class = hacked_bitmap
    PokeAccess::RgssMemory.patch_bitmap(bitmap_class)
    bm = bitmap_class.new(2, 2)
    bm.raw = RAW
    assert_equal RGSS, bm.get_data_ptr { |data| data.free; data }
    assert_equal RGSS, bm.get_data_ptr
  end

  test "lets Zeus81's Marshal dump of a bitmap round-trip" do
    klass = hacked_bitmap
    klass.class_eval do
      def _dump(level)
        get_data_ptr { |data| Marshal.dump([width, height, Zlib::Deflate.deflate(data, 9)]) }
      end

      def self._load(dump)
        width, height, data = *Marshal.load(dump)
        data.replace(Zlib::Inflate.inflate(data))
        bitmap = new(width, height)
        bitmap.set_data(data)
        bitmap
      end
    end
    self.class.const_set(:ZeusBitmap, klass)
    PokeAccess::RgssMemory.patch_bitmap(klass)
    bm = klass.new(2, 2)
    bm.raw = RAW
    assert_equal RAW, Marshal.load(Marshal.dump(bm)).raw
  ensure
    self.class.send(:remove_const, :ZeusBitmap) if self.class.const_defined?(:ZeusBitmap)
  end

  test "puts the stand-ins back after a reset redefines the game's methods" do
    bitmap_class = hacked_bitmap
    PokeAccess::RgssMemory.patch_bitmap(bitmap_class)
    bitmap_class.class_eval { def getData; raise NATIVE; end }
    others = @bound.slice!(0, @kept)
    PokeAccess::Hooks.rebind
    bm = bitmap_class.new(2, 2)
    bm.raw = RAW
    assert_equal RGSS, bm.getData
  ensure
    @bound.unshift(*others) if others
  end

  test "tells a game with the player's memory hacks from one without" do
    plain = Module.new
    gdi = Module.new
    gdi.const_set(:GetDIBits, Object.new)
    assert PokeAccess::RgssMemory.hacks?(hacked_bitmap, plain)
    assert PokeAccess::RgssMemory.hacks?(Class.new, gdi)
    refute PokeAccess::RgssMemory.hacks?(Class.new { def get_data; end }, plain)
  end

  test "makes the game's snapshot mkxp-z's own" do
    graphics = Module.new
    class << graphics
      def snap_to_bitmap; :game; end
      def mkxp_snap_to_bitmap; :native; end
    end
    PokeAccess::RgssMemory.patch_snapshot(graphics)
    assert_equal :native, graphics.snap_to_bitmap
  end

  test "makes Graphics.screenshot write the BMP from Ruby" do
    graphics = Module.new
    class << graphics
      def screenshot(path); raise NATIVE; end
      def mkxp_snap_to_bitmap; :native; end
    end
    PokeAccess::RgssMemory.patch_screenshot(graphics)
    shot = hacked_bitmap.new(2, 2)
    shot.raw = RAW
    Dir.mktmpdir do |dir|
      path = File.join(dir, "capture000.bmp")
      with_snapshot(shot) { graphics.screenshot(path) }
      assert_equal RGSS, File.open(path, "rb") { |f| f.read }[54..-1]
    end
  end

  test "leaves the captures alone on an engine without its own snapshot" do
    graphics = Module.new
    class << graphics
      def snap_to_bitmap; :game; end
      def screenshot(path); :native; end
    end
    PokeAccess::RgssMemory.patch_snapshot(graphics)
    PokeAccess::RgssMemory.patch_screenshot(graphics)
    assert_equal [:game, :native], [graphics.snap_to_bitmap, graphics.screenshot("x.bmp")]
  end

  test "answers KleinBitmap.dll and rubyscreen.dll's screenshot without loading them" do
    api = Class.new do
      attr_reader :args
      def initialize(*args); @args = args; end
    end
    PokeAccess::RgssMemory.patch_dlls(api)
    klein = api.new("KleinBitmap.dll", "to_negative", "l", "")
    assert_kind_of PokeAccess::RgssMemory::NullCall, klein
    PokeAccess::RgssMemory.patch_dlls(api)
    assert_equal [0, 0], [klein.call(5), klein.Call(5)]
    assert_kind_of PokeAccess::RgssMemory::ScreenshotCall, api.new("./RubyScreen.dll", "TakeScreenshot", "%w(p)", "i")
    assert_equal ["rubyscreen.dll", "SwapRgb", "pi", ""], api.new("rubyscreen.dll", "SwapRgb", "pi", "").args
    assert_equal ["user32", "GetDC", "i", "i"], api.new("user32", "GetDC", "i", "i").args
  end

  test "saves the screenshot as a BMP of mkxp-z's snapshot" do
    shot = hacked_bitmap.new(2, 2)
    shot.raw = RAW
    Dir.mktmpdir do |dir|
      path = File.join(dir, "capture000.bmp")
      with_snapshot(shot) { assert_equal 1, PokeAccess::RgssMemory::ScreenshotCall.new.call(path) }
      bytes = File.open(path, "rb") { |f| f.read }
      assert_equal ["BM", 70, 54], [bytes[0, 2], bytes[2, 4].unpack("V")[0], bytes[10, 4].unpack("V")[0]]
      assert_equal [40, 2, 2, 1, 32], bytes[14, 16].unpack("VVVvv")
      assert_equal RGSS, bytes[54..-1]
    end
    assert shot.disposed
  end

  test "answers 0 for a screenshot it cannot write" do
    shot = hacked_bitmap.new(2, 2)
    Dir.mktmpdir do |dir|
      missing = File.join(dir, "missing", "c.bmp")
      with_snapshot(shot) { assert_equal 0, PokeAccess::RgssMemory::ScreenshotCall.new.call(missing) }
    end
    assert shot.disposed
  end

  test "answers 0 for a screenshot on an engine without a snapshot" do
    assert_equal 0, PokeAccess::RgssMemory::ScreenshotCall.new.call("capture000.bmp")
  end

  private

  # A Bitmap class carrying both hacks (Sprite_Resizer's and Zeus81's), each of which fails if it runs.
  def hacked_bitmap
    Class.new do
      attr_reader :width, :height
      attr_accessor :raw

      def initialize(width, height)
        @width = width
        @height = height
        @raw = "\0" * (width * height * 4)
      end

      attr_reader :disposed

      def raw_data; @raw.dup; end
      def raw_data=(data); @raw = data; end
      def dispose; @disposed = true; end

      [:address, :last_row_address, :getData, :get_data, :get_data_ptr].each do |m|
        define_method(m) { |*args| raise NATIVE }
      end
      [:setData, :set_data].each { |m| define_method(m) { |data| raise NATIVE } }
    end
  end

  # Runs the block with a mkxp_snap_to_bitmap on Graphics that hands shot.
  def with_snapshot(shot)
    meta = (class << ::Graphics; self; end)
    meta.send(:define_method, :mkxp_snap_to_bitmap) { shot }
    yield
  ensure
    meta.send(:remove_method, :mkxp_snap_to_bitmap) if meta && meta.method_defined?(:mkxp_snap_to_bitmap)
  end
end
