module PokeAccess
  # Writes text to the Windows clipboard, for content awkward to speak (e.g. a braille message read on
  # a display). Prefers mkxp-z's own clipboard setter, falls back to the Win32 API. Input is unicode
  # codepoints so the source stays ASCII (Ruby 1.8.7 on the gen-6 games).
  module Clipboard
    GMEM_MOVEABLE = 0x0002
    CF_UNICODETEXT = 13
    @api = begin
      { :open  => Win32API.new("user32", "OpenClipboard", ["l"], "i"),
        :empty => Win32API.new("user32", "EmptyClipboard", [], "i"),
        :set   => Win32API.new("user32", "SetClipboardData", ["i", "l"], "l"),
        :close => Win32API.new("user32", "CloseClipboard", [], "i"),
        :alloc => Win32API.new("kernel32", "GlobalAlloc", ["i", "i"], "l"),
        :free  => Win32API.new("kernel32", "GlobalFree", ["l"], "l"),
        :lock  => Win32API.new("kernel32", "GlobalLock", ["l"], "l"),
        :unlock => Win32API.new("kernel32", "GlobalUnlock", ["l"], "i"),
        :copy  => Win32API.new("kernel32", "RtlMoveMemory", ["l", "p", "i"], "v") }
    rescue StandardError
      nil
    end

    # Copies a UTF-8 string to the clipboard; true on success. Decodes the bytes to codepoints by hand so it
    # works the same on Ruby 1.8.7 (gen-6), where String#unpack("U*") depends on $KCODE.
    def self.set_text(str)
      set_codepoints(codepoints_of(str.to_s))
    rescue StandardError
      false
    end

    # Decodes a UTF-8 byte string into an array of unicode codepoints (1.8.7-safe; the inverse of utf8).
    def self.codepoints_of(str)
      bytes = str.unpack("C*")
      cps = []
      i = 0
      while i < bytes.length
        b = bytes[i]
        if b < 0x80
          cps.push(b); i += 1
        elsif b < 0xE0 && bytes[i + 1]
          cps.push(((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F)); i += 2
        elsif b < 0xF0 && bytes[i + 1] && bytes[i + 2]
          cps.push(((b & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F)); i += 3
        elsif bytes[i + 1] && bytes[i + 2] && bytes[i + 3]
          cps.push(((b & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F)); i += 4
        else
          cps.push(b); i += 1
        end
      end
      cps
    end

    # Copies a unicode string (given as codepoints) to the clipboard; true on success.
    def self.set_codepoints(cps)
      if Input.respond_to?(:clipboard=)
        begin
          Input.clipboard = utf8(cps)
          return true
        rescue StandardError
          nil
        end
      end
      win32(cps)
    rescue StandardError
      false
    end

    # Builds a UTF-8 byte string from codepoints, packed so the bytes match on 1.8.7 and newer Ruby.
    def self.utf8(cps)
      bytes = []
      cps.each do |c|
        if c < 0x80
          bytes.push(c)
        elsif c < 0x800
          bytes.push(0xC0 | (c >> 6), 0x80 | (c & 0x3F))
        elsif c < 0x10000
          bytes.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F))
        else
          bytes.push(0xF0 | (c >> 18), 0x80 | ((c >> 12) & 0x3F), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F))
        end
      end
      bytes.pack("C*")
    end

    # Win32 clipboard fallback: writes the codepoints as UTF-16LE through CF_UNICODETEXT. Codepoints above
    # the BMP (> U+FFFF, e.g. emoji) are split into a surrogate pair, as UTF-16 requires. Ownership of the
    # GlobalAlloc handle passes to the system only when SetClipboardData succeeds; every earlier failure
    # (lock, open, a rejected set) frees it here, per the Win32 contract -- who allocates frees on failure.
    def self.win32(cps)
      return false unless @api
      arr = []
      cps.each do |c|
        if c > 0xFFFF
          v = c - 0x10000
          hi = 0xD800 | (v >> 10); lo = 0xDC00 | (v & 0x3FF)
          arr.push(hi & 0xFF, (hi >> 8) & 0xFF, lo & 0xFF, (lo >> 8) & 0xFF)
        else
          arr.push(c & 0xFF, (c >> 8) & 0xFF)
        end
      end
      arr.push(0, 0)
      bytes = arr.pack("C*")
      h = @api[:alloc].call(GMEM_MOVEABLE, bytes.size)
      return false if h == 0
      ptr = @api[:lock].call(h)
      if ptr == 0
        @api[:free].call(h)
        return false
      end
      @api[:copy].call(ptr, bytes, bytes.size)
      @api[:unlock].call(h)
      if @api[:open].call(0) == 0
        @api[:free].call(h)
        return false
      end
      @api[:empty].call
      if @api[:set].call(CF_UNICODETEXT, h) == 0
        @api[:free].call(h)
        @api[:close].call
        return false
      end
      @api[:close].call
      true
    rescue StandardError
      false
    end
  end
end
