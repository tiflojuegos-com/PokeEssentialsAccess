# Clipboard's pure UTF-8 halves (codepoints_of, utf8) round-trip every width, 1 to 4 bytes; malformed input does not
# raise.
Suite.define("clipboard: codepoints_of and utf8 round-trip every UTF-8 width") do
  cases = {
    "ascii"  => [104, 111, 108, 97],
    "accent" => [0xE1, 0xF1],
    "cjk"    => [0x76F8, 0x68D2],
    "emoji"  => [0x1F600]
  }
  cases.each do |label, cps|
    bytes = PokeAccess::Clipboard.utf8(cps)
    eq "#{label}: utf8 -> codepoints_of returns the original codepoints",
       PokeAccess::Clipboard.codepoints_of(bytes), cps
  end

  mixed = [72, 0xF3, 0x1F600, 33]
  eq "a mixed-width string round-trips in order",
     PokeAccess::Clipboard.codepoints_of(PokeAccess::Clipboard.utf8(mixed)), mixed

  malformed = [0xC3].pack("C*")
  out = (begin; PokeAccess::Clipboard.codepoints_of(malformed); rescue StandardError; :raised; end)
  truthy "a truncated multibyte sequence degrades without raising", out.is_a?(Array)
end
