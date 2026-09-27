# Hoenn's BetterRegionMap screens: the weather map (the PokeNav's map and weather apps, the TV's weather channel),
# which paints each square's weather as HUD text; the player's secret base, whose square paints "Secret Base" over
# its point of interest; and the quest map (QuestMap), which paints its own line and opens a side panel of quests.
module PokeAccess
  module IF2RegionMap
    @hud = nil

    # Runs a repaint of the square's line with the HUD reader hushed, keeping for the square read that follows what
    # it painted: [square, painted rows, HUD lines]. A repaint inside one already kept runs as it is.
    def self.capture(scene)
      return yield if @hud
      begin
        @hud = []
        ret = nil
        rows = PokeAccess::PaintCapture.sample { PokeAccess::HudText.hushed { ret = yield } }
        scene.instance_variable_set(:@access_if2_square, [PokeAccess::TownMap.cursor(scene), rows, @hud])
        ret
      ensure
        @hud = nil
      end
    end

    # A HUD line painted while a repaint is kept.
    def self.note_hud(text)
      t = PokeAccess.clean(text.to_s)
      @hud.push(t) if @hud && !t.empty?
    end

    # The point of interest the line painted: on the bottom line, beside the place's name; "" where it painted none.
    def self.painted_poi(loc, rows)
      placed = rows.select { |r| r[3].is_a?(Numeric) }
      return "" if loc.nil? || placed.empty?
      bottom = placed.map { |r| r[3] }.max
      name = PokeAccess.clean(loc[2].to_s)
      texts = placed.select { |r| r[3] == bottom }.map { |r| PokeAccess.clean(r[0].to_s) }
      texts.reject { |t| t.empty? || t == name }.last.to_s
    end

    # A square's parts with what the screen painted on it when it last repainted this square: its own point of
    # interest in place of town_map.dat's, then the weather map's weather and, from medium, its figure.
    # param reader the plugin's map reader, whose location lookup gave the parts
    def self.painted_parts(reader, scene, x, y, parts)
      cap = PokeAccess.ivar(scene, :@access_if2_square)
      return parts unless cap.is_a?(Array) && cap[0] == [x, y]
      loc = reader.location(scene, x, y)
      data_poi = loc ? PokeAccess.clean(loc[3].to_s) : ""
      out = parts.reject { |p| !data_poi.empty? && p == [data_poi, :medium] }
      poi = painted_poi(loc, cap[1])
      out.insert(1, [poi, :medium]) unless poi.empty?
      weather, figure = cap[2]
      out.push([weather, :brief]) if weather
      out.push([figure, :medium]) if figure
      out
    end
  end

  module IF2QuestMap
    def self.quest_map?(scene)
      defined?(::QuestMap) && scene.is_a?(::QuestMap) ? true : false
    end

    # The quests the map files at a square.
    def self.quests_at(scene, x, y)
      q = PokeAccess.ivar(scene, :@quests)
      list = q.is_a?(Hash) ? q[[x, y]] : nil
      list.is_a?(Array) ? list : []
    end

    # The quest map's square as it paints it: its place (or its coordinates), through the screen's own lookup, and
    # the quests in progress there.
    def self.square_parts(scene, x, y)
      loc = (scene.find_location_at_position(x, y) rescue nil)
      name = loc ? PokeAccess.clean(loc[2].to_s) : ""
      parts = [[name.empty? ? PokeAccess::I18n.t(:brm_square, :x => x, :y => y) : name, :brief]]
      n = quests_at(scene, x, y).length
      parts.push([PokeAccess.clean(count_text(n)), :brief]) if n > 0
      parts
    end

    # The quest count in the map's own words.
    def self.count_text(n)
      n > 1 ? _INTL("{1} quests in progress", n) : _INTL("{1} quest in progress", n)
    end

    # The map's title and, while key hints are said, its hint for the quest list.
    def self.title
      PokeAccess::Verbosity.with_hint(PokeAccess.clean(_INTL("Quest Log")), PokeAccess.clean(_INTL("L/R : LIST")))
    end

    # Speaks the square the map's own line was repainted for, once the map is up, on the plugin's dedup slot, so a
    # repaint that the plugin also reads is said once; then its quest panel, or, on a square without quests, forgets
    # the last panel so that coming back reads it again.
    def self.read(scene)
      return unless quest_map?(scene) && PokeAccess::TownMap.open_scene.equal?(scene)
      xy = PokeAccess::TownMap.cursor(scene)
      return unless xy
      t = PokeAccess::Cursor.on_change(scene, :better_map, xy) do
        PokeAccess::Verbosity.info_line(:map_square, square_parts(scene, xy[0], xy[1]))
      end
      PokeAccess::RegionMap.speak_marked(t, true) unless t.nil? || t.empty?
      return PokeAccess::Cursor.reset(scene, :if2_qm_popup) if quests_at(scene, xy[0], xy[1]).empty?
      popup(scene)
    rescue StandardError
      nil
    end

    # The passive side panel of the square's quests, once per place and quests while the map is up (the map rebuilds
    # it for the same quests as the cursor settles, in another order): its header, then each quest with, from medium,
    # the kind its name's colour marks. Reading a square without quests forgets it (see read).
    def self.popup(scene)
      return unless quest_map?(scene) && PokeAccess::TownMap.open_scene.equal?(scene)
      panel = PokeAccess.ivar(scene, :@popup)
      quests = PokeAccess.ivar(panel, :@quests)
      return unless panel && quests.is_a?(Array) && !quests.empty?
      ids = quests.map { |q| ((q.id rescue nil) || (q.name rescue nil)).to_s }.sort
      PokeAccess::Cursor.announce(scene, :if2_qm_popup, [PokeAccess.ivar(panel, :@location_name).to_s, ids], false) do
        rows = quests.map do |q|
          parts = [[PokeAccess.clean((q.name rescue "").to_s), :brief], PokeAccess::IF2Quests.kind_part(q)].compact
          PokeAccess::Verbosity.line(:quest, parts)
        end
        PokeAccess.sentences([_INTL("{1} Quests", PokeAccess.ivar(panel, :@location_name).to_s)] + rows)
      end
    rescue StandardError
      nil
    end
  end
end

# Every repaint of the square's line is kept, under both names the loop and the opening use; the square read the
# plugin makes right after it (its hook is outermost, as plugins load first) reads what was kept.
PokeAccess::Game.define("infinitefusion_hoenn") do
  around("BetterRegionMap", :update_text) { |s, nxt, _a| PokeAccess::IF2RegionMap.capture(s) { nxt.call } }
  around("BetterRegionMap", :update_text_at_location) { |s, nxt, _a| PokeAccess::IF2RegionMap.capture(s) { nxt.call } }
  kernel("pbDisplayText", :after) { |args, _r| PokeAccess::IF2RegionMap.note_hud(args[0]) }

  override("PokeAccess::BetterMap", :square_parts) do |reader, original, args|
    scene, x, y = args
    if PokeAccess::IF2QuestMap.quest_map?(scene)
      PokeAccess::IF2QuestMap.square_parts(scene, x, y)
    else
      PokeAccess::IF2RegionMap.painted_parts(reader, scene, x, y, original.call)
    end
  end
end

# The quest map replaces the line's repaint without calling up, so the plugin's hook never sees a move there and the
# square is read here; it opens with its title and its hint for the list, and each passive side panel is read once
# the map is up.
PokeAccess::Game.define("infinitefusion_hoenn") do
  override("PokeAccess::BetterMap", :region_name) do |_reader, original, args|
    PokeAccess::IF2QuestMap.quest_map?(args[0]) ? PokeAccess::IF2QuestMap.title : original.call
  end
  override("PokeAccess::BetterMap", :read) do |_reader, original, args|
    r = original.call
    PokeAccess::IF2QuestMap.popup(args[0])
    r
  end
  after("QuestMap", :update_text_at_location) { |s, _r, _a| PokeAccess::IF2QuestMap.read(s) }
  after("QuestMap", :show_popup) { |s, _r, _a| PokeAccess::IF2QuestMap.popup(s) }
end
