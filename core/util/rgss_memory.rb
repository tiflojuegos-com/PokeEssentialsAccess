module PokeAccess
  # Stand-ins for what old Essentials scripts read straight out of the RPG Maker XP player's memory: a Bitmap's pixel
  # buffer (Sprite_Resizer's address, Zeus81's last_row_address), the GDI and rubyscreen.dll screen captures, and
  # KleinBitmap.dll. On mkxp-z that memory is not there, and the engine aborts without an error. Each piece is replaced
  # where the game defines it, and again after an F12 reset evaluates the game's scripts anew.
  module RgssMemory
    # Bitmap methods that answer a pointer into the player's memory.
    POINTERS = [:address, :last_row_address]

    # Bitmap methods that copy the pixels out, in the player's layout: BGRA, bottom row first.
    READERS = [:getData, :get_data]

    # Bitmap methods that copy pixels in that layout back in.
    WRITERS = [:setData, :set_data]

    # What a pointer method raises instead of the engine's abort.
    class Unavailable < StandardError; end

    # A Win32API stand-in whose calls answer 0.
    class NullCall
      # Answers 0, whatever the arguments.
      def call(*args)
        0
      end

      alias_method :Call, :call
    end

    # rubyscreen.dll's TakeScreenshot: saves the screen to the path given with mkxp-z's own snapshot.
    class ScreenshotCall
      # Saves the screen to path; 1 once saved, 0 when it cannot be.
      def call(path = nil, *rest)
        RgssMemory.save_screen(path)
        1
      rescue StandardError => e
        PokeAccess.swallowed(e)
        0
      end

      alias_method :Call, :call
    end

    # Installs the stand-ins the running game needs.
    def self.apply
      if defined?(::Bitmap) && defined?(::Graphics) && hacks?(::Bitmap, ::Graphics)
        patch_bitmap(::Bitmap)
        patch_snapshot(::Graphics)
      end
      patch_screenshot(::Graphics) if defined?(::Graphics) && ansi_paths?
      patch_dlls(::Win32API) if defined?(::Win32API)
    end

    # True when the game carries the player's memory hacks: a pointer method on Bitmap, or Zeus81's GDI capture.
    def self.hacks?(bitmap, graphics)
      POINTERS.any? { |m| bitmap.method_defined?(m) } || graphics.const_defined?(:GetDIBits)
    end

    # True under Ruby 1.8, whose file calls hand the path's bytes to Windows' codepage calls: a save folder with an
    # accent exists on disk under that reading, which the engine's own UTF-8 file calls do not find.
    def self.ansi_paths?
      RUBY_VERSION < "1.9"
    end

    # Copies the pixels through mkxp-z's raw_data; the pointer methods raise Unavailable.
    def self.patch_bitmap(bitmap)
      POINTERS.each do |m|
        label = "Bitmap##{m}"
        replace(bitmap, m) do |*args|
          raise PokeAccess::RgssMemory::Unavailable, PokeAccess::I18n.t(:rgss_memory_missing, :method => label)
        end
      end
      READERS.each { |m| replace(bitmap, m) { |*args| PokeAccess::RgssMemory.pixels(self) } }
      WRITERS.each { |m| replace(bitmap, m) { |data| PokeAccess::RgssMemory.write(self, data) } }
      replace(bitmap, :get_data_ptr) do |*args, &blk|
        data = PokeAccess::RgssMemory.pixels(self)
        def data.free; end
        blk ? blk.call(data) : data
      end
    end

    # Makes Graphics.snap_to_bitmap mkxp-z's own snapshot, which every emulation of it in these games stands in for
    # (as mkxp-z's Essentials compatibility script does where it runs).
    def self.patch_snapshot(graphics)
      return unless graphics.respond_to?(:mkxp_snap_to_bitmap)
      replace((class << graphics; self; end), :snap_to_bitmap) { |*args| mkxp_snap_to_bitmap }
    end

    # Makes Graphics.screenshot, which the F8 of mkxp-z's Essentials compatibility script calls, the BMP save_screen
    # writes into the folder the game's own file calls reach.
    def self.patch_screenshot(graphics)
      return unless graphics.respond_to?(:mkxp_snap_to_bitmap)
      replace((class << graphics; self; end), :screenshot) { |path| PokeAccess::RgssMemory.save_screen(path) }
    end

    # Makes Win32API.new hand a stand-in for the DLL functions that reach into the player's memory or window. Once
    # only and never put back after a reset: no game's scripts redefine Win32API.new, and a second alias over a
    # wrapper laid on this one would make it call itself.
    def self.patch_dlls(api)
      meta = (class << api; self; end)
      return if meta.method_defined?(:new__pa_rgss_memory)
      meta.send(:alias_method, :new__pa_rgss_memory, :new)
      meta.send(:define_method, :new) do |*args|
        PokeAccess::RgssMemory.stand_in(args[0], args[1]) || new__pa_rgss_memory(*args)
      end
    end

    # The stand-in for a DLL's function, the DLL named as Win32API.new takes it (any folder, case or extension), or
    # nil for a call that may run: every KleinBitmap.dll call, and rubyscreen.dll's TakeScreenshot.
    def self.stand_in(dll, func)
      base = File.basename(dll.to_s).downcase.sub(/\.dll\z/, "")
      return NullCall.new if base == "kleinbitmap"
      return ScreenshotCall.new if base == "rubyscreen" && func.to_s == "TakeScreenshot"
      nil
    end

    # Replaces owner's meth by the block where owner defines it, and keeps it so after a reset.
    def self.replace(owner, meth, &body)
      return unless owner.method_defined?(meth)
      PokeAccess::Hooks.keep_bound(owner, meth) { |_again| owner.send(:define_method, meth, &body) }
    end

    # The bitmap's pixels in the player's layout.
    def self.pixels(bitmap)
      swap_layout(bitmap.raw_data, bitmap.width, bitmap.height)
    end

    # Puts pixels in the player's layout into the bitmap; data of any other size is ignored, as raw_data= does.
    def self.write(bitmap, data)
      w = bitmap.width
      h = bitmap.height
      return nil unless data.is_a?(String) && data.bytesize == w * h * 4
      bitmap.raw_data = swap_layout(data, w, h)
      nil
    end

    # The pixels in the other of the two layouts, mkxp-z's (RGBA, top row first) and the player's (BGRA, bottom row
    # first): rows reversed, red and blue swapped, so the same call converts either way.
    def self.swap_layout(bytes, width, height)
      src = binary(bytes)
      w4 = width * 4
      rows = (0...height).map { |y| src[(height - 1 - y) * w4, w4] }.join
      pairs = rows.unpack("n*")
      i = 0
      n = pairs.length
      while i < n
        first = pairs[i]
        second = pairs[i + 1]
        pairs[i] = (second & 0xFF00) | (first & 0xFF)
        pairs[i + 1] = (first & 0xFF00) | (second & 0xFF)
        i += 2
      end
      pairs.pack("n*")
    end

    # A copy of the string as raw bytes, so it is cut by byte on a Ruby with encodings.
    def self.binary(s)
      s.respond_to?(:force_encoding) ? s.dup.send(:force_encoding, "ASCII-8BIT") : s
    end

    # Saves mkxp-z's snapshot of the screen to path as a BMP file; failures raise. Written from Ruby, into the folder
    # the game's own file calls reach: under Ruby 1.8.7 a save folder with an accent exists on disk under its
    # ANSI-read name, which the engine's UTF-8 file calls do not find.
    def self.save_screen(path)
      shot = ::Graphics.mkxp_snap_to_bitmap
      begin
        File.open(path.to_s, "wb") { |f| f.write(bmp_file(shot)) }
      ensure
        shot.dispose
      end
      true
    end

    # The bitmap as the bytes of a 32-bit BMP file, whose pixels are laid out as the player's.
    def self.bmp_file(bitmap)
      data = pixels(bitmap)
      header = ["BM", 54 + data.bytesize, 0, 0, 54].pack("a2VvvV")
      info = [40, bitmap.width, bitmap.height, 1, 32, 0, data.bytesize, 2835, 2835, 0, 0].pack("VVVvvVVVVVV")
      header + info + data
    end
  end
end

PokeAccess::RgssMemory.apply
