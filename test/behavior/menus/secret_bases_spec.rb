# Secret base decorating. The two copies of the plugin ask the same question -- can this tile take the
# piece? -- through methods of different ARITY: the fork added the tile's position within the piece as a
# fourth argument. Calling with the wrong one raises on every frame, and "it fits" is precisely the part a
# blind player has no other way to learn, so it would vanish without a symptom.
# The harness loads every plugin reader, so this spec does not pull it in itself: a require on a file
# already brought in with eval loads it a SECOND time and reassigns its constants.

class FakeDecoration
  attr_reader :tile_size
  def initialize(w, h); @tile_size = [w, h]; end
end

class FakeBaseSceneWide
  attr_reader :calls
  def initialize(blocked); @blocked = blocked; @calls = []; end
  def can_place_here?(data, x, y, pos)
    @calls.push([x, y, pos])
    !@blocked.include?([x, y])
  end
end

class FakeBaseSceneNarrow
  attr_reader :calls
  def initialize(blocked); @blocked = blocked; @calls = []; end
  def can_place_here?(data, x, y)
    @calls.push([x, y])
    !@blocked.include?([x, y])
  end
end

Suite.define("secret bases: the fit check is called the way THIS copy of the plugin declares it") do
  sb = PokeAccess::SecretBases
  piece = FakeDecoration.new(2, 2)

  wide = FakeBaseSceneWide.new([])
  eq "a piece that fits, on the four-argument copy", sb.fits?(wide, piece, 5, 5), true
  eq "every tile of the footprint was asked about", wide.calls.length, 4
  eq "and the position within the piece was passed along", wide.calls.map { |c| c[2] }, [0, 1, 2, 3]
  eq "over the same coordinates the plugin itself walks",
     wide.calls.map { |c| [c[0], c[1]] }, [[5, 5], [4, 5], [5, 4], [4, 4]]

  narrow = FakeBaseSceneNarrow.new([])
  eq "the same piece on the three-argument copy", sb.fits?(narrow, piece, 5, 5), true
  eq "asked the same four times", narrow.calls, [[5, 5], [4, 5], [5, 4], [4, 4]]

  eq "one blocked tile blocks the whole piece", sb.fits?(FakeBaseSceneNarrow.new([[4, 4]]), piece, 5, 5), false
  eq "a scene with no such method at all decides nothing", sb.fits?(Object.new, piece, 5, 5), nil
  eq "and neither does a decoration with no size", sb.fits?(narrow, Object.new, 5, 5), nil
end
