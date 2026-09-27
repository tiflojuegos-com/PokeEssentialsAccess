module PokeAccess
  # Insurgence's H-Mode7 maps (a MapInfos name with [HM7]: the soaring maps and a few story scenes) are drawn by
  # MGC_Hmode7.dll, which writes into the original player's bitmaps and cannot run under mkxp-z, so every map stays
  # flat. The soaring HUD's place name, which the game works out only in H-Mode7 (Scene_Map#update,
  # 021_Scene_Map.rb), is said here as the player flies over each place.
  module InsurgenceSoaring
    # The soaring maps (Torren, Holon) and the game's function listing their places as [map id, x0, y0, x1, y1, ...]
    # (179_ChallengeChampionship.rb).
    AREAS = { 676 => :getSoarAreas, 749 => :getSoarAreasHolon }

    # The map id of the place over (x, y), found as Scene_Map#update finds it (the first box holding the point strictly
    # inside its edges), or 0 over none.
    def self.area_at(areas, x, y)
      (areas || []).each { |a| return a[0].to_i if x > a[1] && x < a[3] && y > a[2] && y < a[4] }
      0
    end

    # The places of a soaring map, asked of the game once per map, or nil on any other map.
    def self.areas(map_id)
      fn = AREAS[map_id]
      return nil if fn.nil?
      @areas ||= {}
      @areas[map_id] ||= Kernel.send(fn)
    rescue StandardError
      nil
    end

    # Per frame on a soaring map: the name of the place under the player when it changes, queued the first time so it
    # follows the map's own name; nothing over open sky, where the HUD is blank.
    def self.poll
      mid = ($game_map.map_id rescue nil)
      list = areas(mid)
      return reset if list.nil?
      area = area_at(list, $game_player.x, $game_player.y)
      arrived = @last.nil?
      return if @last == [mid, area]
      @last = [mid, area]
      return if area <= 0
      name = PokeAccess::Locator.map_name(area)
      PokeAccess.speak(name, !arrived, :nav) unless name.nil? || name.empty?
    rescue StandardError
      nil
    end

    # Forgets the place last said, so the next soaring map names where the player is.
    def self.reset
      @last = nil
    end
  end
end

PokeAccess::Game.define("insurgence") do
  poll_each_frame { PokeAccess::InsurgenceSoaring.poll }
end
