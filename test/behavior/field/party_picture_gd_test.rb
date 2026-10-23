# The team photo camera (plugins/party_picture.rb): each pbScrollMap step inside PartyPicture#main says the camera's
# offset from where it started, in tiles to the nearest half, and the map's edge when a step stops short.
class PartyPictureGdTest < PokeAccessTest
  Photo = PokeAccess::TeamPhoto
  # Where the map's display stands as the photo starts, in display units (128 a tile).
  START_X = 512
  START_Y = 384

  test "each camera step says the offset from the start, interrupting, and the centre when back" do
    take_photo([8, 8, 8, 6, 2, 2, 4])
    assert_equal [[up(1), true], [up(2), true], ["#{up(2)}, #{right(1)}", true], ["#{up(1)}, #{right(1)}", true],
                  [right(1), true], [t(:photo_cam_center), true]],
                 SpeakCapture.log,
                 "the third press up is the plugin's bump, which does not scroll"
  end

  test "a step the map's edge stops short says the edge, and the offset to the half tile" do
    take_photo([6, 6, 6, 6, 4, 4], [-100000, START_X + 192, -100000, 100000])
    stuck = "#{right('1,5')}, #{t(:photo_cam_edge)}"
    assert_equal [right(1), stuck, stuck, stuck, right("0,5"), left("0,5")],
                 SpeakCapture.lines,
                 "four steps right on a map that lets the camera travel a tile and a half, then two back"
  end

  test "a step that travels three quarters of a tile is not the edge" do
    take_photo([2, 2], [-100000, 100000, -100000, START_Y + 96])
    assert_equal [t(:photo_cam_down, :n => "1"), "#{t(:photo_cam_down, :n => '1')}, #{t(:photo_cam_edge)}"],
                 SpeakCapture.lines
  end

  test "a scroll of the map after the photo is not the camera" do
    take_photo([8])
    SpeakCapture.clear
    pbScrollMap(8, 1)
    assert_nothing_spoken
  end

  test "a scroll that is not one of the four arrows says nothing" do
    with_display_at(START_X, START_Y) do
      Photo.start
      begin
        [5, 0, 1].each { |dir| pbScrollMap(dir, 1) }
      ensure
        Photo.stop
      end
    end
    assert_nothing_spoken
  end

  test "names the vertical part of the offset first, then the horizontal, each by its side" do
    { [-3, -2] => "#{t(:photo_cam_down, :n => '2')}, #{left(3)}",
      [2, 1] => "#{up(1)}, #{right(2)}",
      [0, -1] => t(:photo_cam_down, :n => "1"),
      [-0.5, 0] => left("0,5"),
      [0, 0] => t(:photo_cam_center) }.each do |(x, y), said|
      assert_equal said, Photo.offset_text(x, y), "#{x} across, #{y} up"
    end
  end

  test "rounds a distance to the nearest half tile" do
    halves = { 0 => 0.0, 31 => 0.0, 32 => 0.5, 95 => 0.5, 96 => 1.0, 192 => 1.5, -96 => -1.0, -192 => -1.5 }
    halves.each do |units, tiles|
      assert_equal tiles, Photo.tiles(units), "#{units} display units"
    end
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def up(n); t(:photo_cam_up, :n => n.to_s); end
  def right(n); t(:photo_cam_right, :n => n.to_s); end
  def left(n); t(:photo_cam_left, :n => n.to_s); end

  # Takes the team photo pressing the given arrows (8 up, 2 down, 6 right, 4 left), the display starting at
  # (START_X, START_Y) and kept within bounds ([min_x, max_x, min_y, max_y], none by default); the display put back
  # after.
  def take_photo(keys, bounds = nil)
    with_display_at(START_X, START_Y) do
      $pa_photo_keys = keys
      $pa_display_bounds = bounds
      PartyPicture.new.main
    end
  ensure
    $pa_photo_keys = nil
    $pa_display_bounds = nil
  end

  # Runs the block with the map's display at (x, y), the display it had put back after.
  def with_display_at(x, y)
    was = [$game_map.display_x, $game_map.display_y]
    $game_map.display_x = x
    $game_map.display_y = y
    yield
  ensure
    $game_map.display_x, $game_map.display_y = was
  end
end
