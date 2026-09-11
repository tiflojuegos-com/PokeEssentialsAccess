# The team photo camera (plugins/party_picture.rb): each arrow is one pbScrollMap call inside
# PartyPicture#main, and the reader says where the camera stands from where it started. The stub keeps the
# plugin's loop, the bump at the edge included.
Suite.define("team photo: each camera step says the offset from the start, and the centre when back") do
  i = PokeAccess::I18n
  up1 = i.t(:photo_cam_up, :n => 1)
  up2 = i.t(:photo_cam_up, :n => 2)
  right1 = i.t(:photo_cam_right, :n => 1)
  $game_map.display_x = 0
  $game_map.display_y = 0
  SpeakCapture.clear
  $pa_photo_keys = [8, 8, 8, 6, 2, 2, 4]
  begin
    PartyPicture.new.main
  ensure
    $pa_photo_keys = nil
  end
  eq "one line per step, and the third press up is the edge's bump, which says nothing",
     SpeakCapture.lines, [up1, up2, "#{up2}, #{right1}", "#{up1}, #{right1}", right1, i.t(:photo_cam_center)]

  SpeakCapture.clear
  pbScrollMap(8, 1)
  silent "a cutscene scrolling the map after the photo is not the camera"
end

Suite.define("team photo: the offset reads the vertical part first and names each side") do
  tp = PokeAccess::TeamPhoto
  i = PokeAccess::I18n
  eq "down and left", tp.offset_text(-3, -2), "#{i.t(:photo_cam_down, :n => 2)}, #{i.t(:photo_cam_left, :n => 3)}"
  eq "the start is the centre", tp.offset_text(0, 0), i.t(:photo_cam_center)
end

Suite.define("team photo: a step a snapping map stops short says the map's edge, and the camera is told to the half tile") do
  i = PokeAccess::I18n
  half = lambda { |f| PokeAccess::Pokedex.fmt_float(f) }
  right = lambda { |n| i.t(:photo_cam_right, :n => n) }
  left = lambda { |n| i.t(:photo_cam_left, :n => n) }
  edge = i.t(:photo_cam_edge)
  $game_map.display_x = 0
  $game_map.display_y = 0
  $pa_display_bounds = [-100000, 192, -100000, 100000]
  SpeakCapture.clear
  $pa_photo_keys = [6, 6, 6, 6, 4, 4]
  begin
    PartyPicture.new.main
  ensure
    $pa_photo_keys = nil
    $pa_display_bounds = nil
  end
  stuck = "#{right.call(half.call(1.5))}, #{edge}"
  eq "four steps right on a map that lets the camera travel a tile and a half, then two back",
     SpeakCapture.lines, [right.call(1), stuck, stuck, stuck, right.call(half.call(0.5)), left.call(half.call(0.5))]
end
