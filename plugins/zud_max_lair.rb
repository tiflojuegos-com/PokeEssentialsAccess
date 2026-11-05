module PokeAccess
  # ZUD's Max Lair map (LairMapScene), in its release for Essentials 19 and in the one for 20, which names its sprites and
  # tile questions otherwise (the *_v20 methods and WAYS' sprites). At each Selection tile: the hearts, keys and floor the corner shows, the paths
  # the arrows offer and, for the lit one, what the map draws along it up to the next stop; in the map view, the tile
  # under the cursor. The tiles are pictures, named here; the route is traced over the tiles as the scene moves the
  # player icon: a step of a tile at a time, turned by arrow tiles and carried by warps.
  module ZudLairMap
    TILE = 32
    # The four ways in the scene's own numbering (up, down, left, right): its arrow sprite and its step.
    WAYS = [[:@arrow0, :dir_up, 0, -TILE], [:@arrow1, :dir_down, 0, TILE], [:@arrow2, :dir_left, -TILE, 0],
            [:@arrow3, :dir_right, TILE, 0]]
    # The opposite of each way, for a Flip tile.
    FLIP = [1, 0, 3, 2]
    # The event tiles' people and pickups, in pbEventTiles' numbering.
    EVENTS = [:zlair_ev_scientist, :zlair_ev_backpacker, :zlair_ev_blackbelt, :zlair_ev_ace, :zlair_ev_channeler,
              :zlair_ev_nurse, :zlair_ev_mystery, :zlair_ev_berries, :zlair_ev_key, :zlair_ev_chest]
    # The lit arrow's colour alpha (the others are cleared to 0).
    LIT = 200
    # Tiles a trace walks before it gives up on a path that loops or runs off the drawn ones.
    STEPS = 96
    # How near the cursor's centre a tile has to be for the map view to select it, as pbCursorReact measures.
    REACH = 20
    # The scene's yes-or-no questions about a tile: the release for 19 asks by method, the one for 20 by a part of the
    # tile sprite's name (lair_OnTile?). Reset and Flare tiles exist only in the one for 20.
    ON_TILE = { :start => [:pbStartTile?, "Start"], :selection => [:pbRouteSelections, "Select"],
                :door => [:pbLockedDoorTile?, "Door"], :roadblock => [:pbRoadblockTile?, "Block"],
                :switch => [:pbSwitchTile?, "Switch"], :warp => [:pbWarpTile?, "Warp"],
                :reset => [nil, "Reset"], :flare => [nil, "Flare"] }
    # The tiles that end a trace: a door or a roadblock may turn the icon back, a Reset tile sends it to the Start tile.
    STOPS = [:door, :roadblock, :reset]
    # The tiles of the release for 20 that give something, numbered as EVENTS, past its NPC tiles (lair_TileType).
    PICKUPS = [["Berry", 7], ["Key", 8], ["Chest", 9]]

    @scene = nil
    @mode = nil

    # Holds the map while its scene runs (the block); what the info key held of it goes with it.
    def self.run(scene)
      @scene = scene
      @mode = nil
      yield
    ensure
      @scene = nil
      PokeAccess::Info.clear_text
    end

    # Each frame: the route choice while its arrows show, the tile under the cursor while the map view's cursor shows,
    # and the speed-up key once the player icon first moves.
    def self.poll
      s = @scene
      return unless s
      cursor = PokeAccess.ivar(s, :@cursor)
      if cursor && (cursor.visible rescue false)
        enter(:view) { view_opening }
        hover(s, cursor)
      elsif !ways(s).empty?
        route(s, enter(:route))
      else
        enter(nil)
        speed_hint(s)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Records the mode the frame is in; on a change, runs the block (an opening) and answers true.
    def self.enter(mode)
      return false if mode == @mode
      @mode = mode
      yield if block_given?
      true
    end

    # The ways the arrows offer now, in the scene's numbering.
    def self.ways(s)
      (0...WAYS.length).select do |i|
        a = arrow(s, i)
        a && (a.visible rescue false)
      end
    end

    # The arrow of way i: an instance variable in the release for 19, a sprite in the one for 20.
    def self.arrow(s, i)
      PokeAccess.ivar(s, WAYS[i][0]) || PokeAccess.sprite(s, "arrow_ui_#{i}")
    end

    # The way whose arrow is lit, or nil.
    def self.lit(s)
      ways(s).find { |i| ((arrow(s, i).color.alpha rescue 0).to_i == LIT) }
    end

    # Whether the tile at this screen spot is of the kind asked (ON_TILE).
    def self.on?(s, at, kind)
      old, part = ON_TILE[kind]
      return s.send(old, at) if old && s.respond_to?(old)
      s.respond_to?(:lair_OnTile?) ? s.lair_OnTile?(part, at) : false
    end

    # How a tile turns the icon: 0 to 3 a way, 4 at random, 5 back; nil where it does not.
    def self.turn_at(s, at)
      s.respond_to?(:pbTurnTiles) ? s.pbTurnTiles(at) : s.lair_TileType("Turn", at)
    end

    # The event or pickup on a tile, in EVENTS' numbering, or nil.
    def self.event_at(s, at)
      return s.pbEventTiles(at) if s.respond_to?(:pbEventTiles)
      npc = s.lair_TileType("NPC", at)
      return npc if npc
      pick = PICKUPS.find { |part, _n| s.lair_OnTile?(part, at) }
      pick ? pick[1] : nil
    end

    # The number of the raid on a tile, or nil.
    def self.raid_at(s, at)
      s.respond_to?(:pbPokemonTiles) ? s.pbPokemonTiles(at) : s.lair_TileType("Pokemon", at)
    end

    # The adventure's state, by the name of each release.
    def self.state
      (pbDynAdventureState rescue nil) || (pbDynamaxAdventure rescue nil)
    end

    # Where the player icon stands on the map, as an offset from the map's picture, the same however the map scrolls.
    def self.place(s, sprite = nil)
      sprite ||= PokeAccess.ivar(s, :@player)
      bg = PokeAccess.sprite(s, "background")
      [sprite.x - bg.x, sprite.y - bg.y]
    end

    # The route choice: on a new tile, the corner and every way the arrows offer with its path, the lit one first,
    # queued; back from another screen over the same tile, the lit way's path again; then each lit way's path as the
    # arrow keys change it. The info key has the corner and every way, as they stand.
    def self.route(s, entered)
      way = lit(s)
      return unless way
      here = place(s)
      if PokeAccess::Cursor.changed?(s, :zlair_here, here)
        PokeAccess::Cursor.store(s, :zlair_way, [here, way])
        publish_route(s, way)
        PokeAccess.speak(route_opening(s, way), false)
      else
        PokeAccess::Cursor.reset(s, :zlair_way) if entered
        PokeAccess::Cursor.announce(s, :zlair_way, [here, way], true, false) do
          publish_route(s, way)
          path_line(s, way)
        end
      end
    end

    # The corner and each way's path, the lit one first.
    def self.route_line(s, way)
      order = [way] + (ways(s) - [way])
      PokeAccess.sentences([corner(s)].concat(order.map { |i| path_line(s, i) }))
    end

    # Keeps the route choice for the info key.
    def self.publish_route(s, way)
      line = route_line(s, way)
      PokeAccess::Info.set_info(:text, line, line)
    end

    # The route choice as said on a new tile: its line, then the options key.
    def self.route_opening(s, way)
      options = PokeAccess::Verbosity.hints? ? hint(:zlair_options, :a, nil) : nil
      PokeAccess.sentences([route_line(s, way), options])
    end

    # The corner of the screen: the hearts left of those held, the lair keys when it shows any, the floor window.
    def self.corner(s)
      adventure = state
      hearts = (adventure.knockouts rescue PokeAccess.ivar(s, :@knockouts)).to_i
      most = PokeAccess.ivar(s, :@maxHearts) || PokeAccess.ivar(s, :@max_hearts)
      parts = [PokeAccess::I18n.t(:zlair_hearts, :n => hearts, :max => most.to_i)]
      keys = PokeAccess.sprite(s, "lairkey") || PokeAccess.sprite(s, "keycount")
      if keys && (keys.visible rescue false)
        count = (adventure.keycount rescue (PokeAccess.ivar(s, :@lairKeys) || PokeAccess.ivar(s, :@keycount)))
        parts.push(PokeAccess::I18n.t(:zlair_keys, :n => count.to_i))
      end
      floor = PokeAccess.sprite(s, "floorwindow")
      parts.push(PokeAccess.clean(floor.text.to_s)) if floor && !(floor.disposed? rescue true)
      PokeAccess.sentences(parts)
    end

    # A way and what lies along it ("up: Backpacker, raid, Fire type, Selection tile"), or the way alone when the trace
    # finds nothing to name.
    def self.path_line(s, way)
      items = trace(s, way).map { |t| tile_name(s, t) }.compact
      dir = PokeAccess::I18n.t(WAYS[way][1])
      items.empty? ? dir : "#{dir}: #{items.join(', ')}"
    end

    # The tiles a way runs over as the scene would move the icon, in order, each as [kind, detail]: event tiles, raid
    # tiles not yet battled, flares, switches, warps (followed to the next one) and flips (which turn it back), up to the
    # tile it stops on (a Selection or the Start tile, one of STOPS, a random turn). Arrow tiles turn it unsaid; hidden
    # traps, which the map does not draw, are passed over.
    def self.trace(s, way)
      x, y = place(s)
      bg = PokeAccess.sprite(s, "background")
      out = []
      seen = {}
      STEPS.times do
        x += WAYS[way][2]
        y += WAYS[way][3]
        break if seen[[x, y, way]]
        seen[[x, y, way]] = true
        at = [x + bg.x, y + bg.y]
        stop = step(s, at, out)
        break if stop == :stop
        if stop.is_a?(Array)
          x, y = stop
          next
        end
        turn = (turn_at(s, at) rescue nil)
        if turn == 4
          out.push([:random])
          break
        end
        out.push([:flip]) if turn == 5
        way = turn == 5 ? FLIP[way] : (turn || way)
        if on?(s, at, :start)
          out.push([:start])
          break
        end
        if on?(s, at, :selection)
          out.push([:selection])
          break
        end
      end
      out
    end

    # What one tile of a trace holds, pushed onto out: :stop at one of STOPS, a warp's landing place (map offset) to go
    # on from, else nil.
    def self.step(s, at, out)
      stop = STOPS.find { |kind| on?(s, at, kind) }
      if stop
        out.push([stop])
        return :stop
      end
      ev = event_at(s, at)
      out.push([:event, ev]) if ev
      i = raid_at(s, at)
      out.push([:raid, i]) if i && fresh_raid?(s, i)
      out.push([:flare]) if on?(s, at, :flare)
      out.push([:switch]) if on?(s, at, :switch)
      return nil unless on?(s, at, :warp)
      out.push([:warp])
      warp_landing(s, at)
    end

    # The map offset of the warp a Warp tile sends the icon to: the next one in the map's list, as pbWarpPlayer picks.
    def self.warp_landing(s, at)
      return warp_landing_v20(s, at) unless PokeAccess.ivar(s, :@mapWarpPoint)
      list = PokeAccess.ivar(s, :@mapWarpPoint) || []
      list.length.times do |i|
        tile = PokeAccess.sprite(s, "mapWarpPoint#{i}")
        next unless tile && [tile.x, tile.y] == at
        dest = PokeAccess.sprite(s, "mapWarpPoint#{(i + 1) % list.length}")
        return place(s, dest) if dest
      end
      nil
    end

    # The map offset lair_WarpPlayer sends the icon to: the first shown Warp tile numbered past this one, else the first.
    def self.warp_landing_v20(s, at)
      value = s.lair_TileType("Warp", at)
      tiles = (PokeAccess.ivar(s, :@sprites) || {}).select { |k, sp| k.to_s.include?("Warp") && (sp.visible rescue false) }.to_a
      pair = tiles.find { |k, _sp| k.to_s.split("_").last.to_i > value.to_i } || tiles[0]
      pair ? place(s, pair[1]) : nil
    end

    # Whether raid tile i still holds its Pokemon: the silhouette is drawn until it has been battled. The release for 20
    # keeps the tile and hides the silhouette, which is what lair_StartBattle asks before fighting.
    def self.fresh_raid?(s, i)
      pk = PokeAccess.sprite(s, "pokemon#{i}")
      return (pk.color.alpha rescue 0).to_i == 255 if pk
      shadow = PokeAccess.sprite(s, "Shadow_#{i}")
      shadow && shadow.visible ? true : false
    end

    # The type a raid tile's icon shows, from the row of the type strip it crops: a double type paints one of its two at
    # random, so only the icon tells which.
    def self.raid_type(s, i)
      icon = PokeAccess.sprite(s, "poketype#{i}") || PokeAccess.sprite(s, "Type_#{i}")
      top = (icon.src_rect.y rescue nil)
      return nil unless top
      row = top.to_i / 28
      PokeAccess::Data.type_name(type_at_row(row) || row)
    end

    # The type whose icon sits at this row of the strip, from Essentials 20 on (icon_position); nil before, where the
    # row is the type's own number.
    def self.type_at_row(row)
      return nil unless GameData::Type.respond_to?(:each)
      found = nil
      GameData::Type.each { |t| found ||= t.id if t.respond_to?(:icon_position) && t.icon_position == row }
      found
    end

    # A traced or hovered tile as spoken; the boss's raid tile, the lair's last, with the reaction the intro announced.
    def self.tile_name(s, t)
      case t[0]
      when :event then PokeAccess::I18n.t(EVENTS[t[1].to_i] || :zlair_ev_mystery)
      when :raid then raid_name(s, t[1])
      when :turn then PokeAccess::I18n.t(:zlair_t_turn, :dir => PokeAccess::I18n.t(WAYS[t[1]][1]))
      else PokeAccess::I18n.t(:"zlair_t_#{t[0]}")
      end
    end

    def self.raid_name(s, i)
      type = raid_type(s, i)
      name = type ? PokeAccess::I18n.t(:zlair_t_raid_type, :type => type) : PokeAccess::I18n.t(:zlair_t_raid)
      boss = (PokeAccess.ivar(s, :@size) || (PokeAccess.ivar(s, :@lair_pokemon) || []).length).to_i - 1
      i.to_i == boss ? "#{name}, #{PokeAccess::I18n.t(:zlair_boss)}" : name
    end

    # The map view's keys, from its picture, while key hints are said.
    def self.view_opening
      return unless PokeAccess::Verbosity.hints?
      PokeAccess.speak(PokeAccess.sentences([hint(:zlair_info, :c, :key_enter), hint(:zlair_toggle, :a, nil),
                                             hint(:zlair_return, :b, :key_escape)]), false)
    end

    # A key hint: a caption key and its button's key.
    def self.hint(caption, button, name)
      key = PokeAccess::KeyHints.key(button, name ? PokeAccess::I18n.t(name) : "Z")
      PokeAccess::I18n.t(:hint_label_key, :label => PokeAccess::I18n.t(caption), :key => key)
    end

    # The map view: the tile the cursor selects, said as it changes and kept for the info key.
    def self.hover(s, cursor)
      at = hovered(s, cursor)
      key = at ? place_of(s, at) : nil
      if at
        PokeAccess::Cursor.announce(s, :zlair_hover, key) do
          line = describe(s, at)
          PokeAccess::Info.set_info(:text, line, line) if line
          line
        end
      end
      PokeAccess::Cursor.reset(s, :zlair_hover) unless at
    end

    # The screen spot of the tile the cursor selects, as pbCursorReact picks it (the last drawn tile within reach of
    # the cursor's centre, hidden traps aside), or nil.
    def self.hovered(s, cursor)
      cx = cursor.x + 16
      cy = cursor.y + 16
      pick = nil
      return hovered_v20(s, cx, cy) unless PokeAccess.ivar(s, :@mapSprites)
      (PokeAccess.ivar(s, :@mapSprites) || []).each do |sp|
        next unless (sp.visible rescue false)
        at = [sp.x, sp.y]
        next if s.pbHiddenTrapTile?(at)
        pick = at if (cx - at[0]).abs <= REACH && (cy - at[1]).abs <= REACH
      end
      pick
    end

    # The same as lair_CursorReact picks it, over the tile sprites by name.
    def self.hovered_v20(s, cx, cy)
      map = PokeAccess.ivar(s, :@map_sprites) || []
      pick = nil
      (PokeAccess.ivar(s, :@sprites) || {}).each do |key, sp|
        next unless map.include?(sp) && (sp.visible rescue false)
        next if key.to_s =~ /background|Shadow|Type|Trap/
        pick = [sp.x, sp.y] if (cx - sp.x).abs <= REACH && (cy - sp.y).abs <= REACH
      end
      pick
    end

    def self.place_of(s, at)
      bg = PokeAccess.sprite(s, "background")
      [at[0] - bg.x, at[1] - bg.y]
    end

    # A hovered tile as its picture shows it, in the order the scene's own tile help checks; nil for bare ground.
    def self.describe(s, at)
      return tile_name(s, [:start]) if on?(s, at, :start)
      return tile_name(s, [:selection]) if on?(s, at, :selection)
      i = raid_at(s, at)
      return (fresh_raid?(s, i) ? raid_name(s, i) : tile_name(s, [:raid_done])) if i
      return tile_name(s, [:warp]) if on?(s, at, :warp)
      return tile_name(s, [:door]) if on?(s, at, :door)
      return tile_name(s, [:roadblock]) if on?(s, at, :roadblock)
      return tile_name(s, [:reset]) if on?(s, at, :reset)
      return tile_name(s, [:flare]) if on?(s, at, :flare)
      return tile_name(s, [:switch]) if on?(s, at, :switch)
      turn = turn_at(s, at)
      return tile_name(s, [turn == 4 ? :random : :flip]) if turn == 4 || turn == 5
      return tile_name(s, [:turn, turn]) if turn
      ev = event_at(s, at)
      ev ? tile_name(s, [:event, ev]) : nil
    end

    # The speed-up key, once per lair, as its sign first shows while the icon moves.
    def self.speed_hint(s)
      sign = PokeAccess.sprite(s, "speedup") || PokeAccess.sprite(s, "speedup_ui")
      return unless sign && (sign.visible rescue false) && PokeAccess::Verbosity.hints?
      return unless PokeAccess::Cursor.changed?(s, :zlair_speed, true)
      PokeAccess.speak(hint(:zlair_speed, :a, nil), false)
    end
  end

  # ZUD's Max Lair menus (MaxLairEventScene): the rental, swap, item, training, tutor and prize screens, each with its
  # cursor drawn as an arrow sprite, said entry by entry; the treasure and record screens read whole as painted.
  module ZudLairMenus
    # Where the arrow of each list sits, by entry: the rental slots, the party column, the item and training rows.
    SLOT_Y = 80
    SLOT_STEP = 114
    PARTY_Y = 95
    ROW_Y = 61
    ROW_STEP = 40
    # The header row a screen paints above its slots ("Select 2 more rental Pokemon.").
    HEADER_YS = [-6, 5]

    @scene = nil
    @mode = nil
    @list = nil
    @rows = []
    @said = true

    # Holds a menu screen while its select method runs (the block), with the list it shows when it is given one (the
    # prizes).
    def self.run(scene, mode, list = nil)
      @scene = scene
      @mode = mode
      @list = list ? list.dup : nil
      @rows = []
      @said = !(mode == :treasure || mode == :record)
      yield
    ensure
      @mode = nil
    end

    def self.mode; @mode; end

    # Each frame: the open screen's cursor, or a whole screen once its paint has landed.
    def self.poll
      s = @scene
      return unless s && @mode
      case @mode
      when :rental then rental(s)
      when :swap then party_cursor(s)
      when :items, :training then row_cursor(s)
      when :prize then prize_cursor(s)
      when :treasure, :record then whole
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The y an arrow sprite stands at while it shows, or nil.
    def self.arrow_y(s, key)
      a = PokeAccess.sprite(s, key)
      a && (a.visible rescue false) ? a.y.to_i : nil
    end

    # The rental screen: its state (the party so far and how many are left) when it changes, then the slot the arrow
    # points at.
    def self.rental(s)
      rentals = PokeAccess.ivar(s, :@rentals) || []
      party = PokeAccess.ivar(s, :@rentalparty) || []
      state = [rentals.map { |r| r.object_id }, party.length]
      if PokeAccess::Cursor.changed?(s, :zlair_rental_state, state)
        PokeAccess::Cursor.reset(s, :zlair_rental)
        PokeAccess.speak(rental_state(s, party), false)
      end
      y = arrow_y(s, "rightarrow")
      return unless y
      i = (y - SLOT_Y) / SLOT_STEP
      pk = rentals[i]
      return unless pk && i >= 0
      PokeAccess::Cursor.announce(s, :zlair_rental, [i, pk.object_id]) do
        line = pokemon_line(pk)
        publish_line(line)
        PokeAccess::Verbosity.list_entry(line, i + 1, rentals.length)
      end
    end

    # The rental screen's heading, its party so far, the header it paints and the summary key once there is a party.
    def self.rental_state(s, party)
      parts = []
      parts.push(_INTL("DYNAMAX ADVENTURE")) if party.empty?
      parts.push(heading(_INTL("Rental Party:"), party))
      parts.push(header(s))
      parts.push(summary_hint) unless party.empty?
      PokeAccess.sentences(parts)
    end

    # The row the screen paints above its slots, or nil.
    def self.header(s)
      row = (PokeAccess.ivar(s, :@textPos) || []).find { |r| r.is_a?(Array) && HEADER_YS.include?(r[2]) }
      row ? PokeAccess.clean(row[0].to_s) : nil
    end

    # A painted heading with the party it labels.
    def self.heading(label, party)
      names = party.map { |pk| PokeAccess.clean(pk.name.to_s) }
      names.empty? ? label : "#{label} #{names.join(', ')}"
    end

    # The summary key the screen's picture shows, while key hints are said.
    def self.summary_hint
      return nil unless PokeAccess::Verbosity.hints?
      PokeAccess::I18n.t(:hint_label_key, :label => _INTL("Summary"), :key => PokeAccess::KeyHints.key(:a, "Z"))
    end

    # A Pokemon as its slot shows it: name and sex sign, types, ability, held item, the Gigantamax mark, its training
    # icon and its moves.
    def self.pokemon_line(pk)
      parts = [named(pk)]
      types = PokeAccess::Data.pokemon_types(pk)
      parts.push(PokeAccess::I18n.t(:zud_raid_types, :list => types.join(", "))) unless types.empty?
      ability = PokeAccess::Data.ability_name((pk.ability_id rescue nil) || (pk.ability rescue nil))
      parts.push(PokeAccess::I18n.t(:zlair_ability, :name => ability)) if ability
      item = (pk.item rescue nil)
      item = PokeAccess::Data.item_name((item.id rescue item)) if item
      parts.push(PokeAccess::I18n.t(:zlair_holding, :item => item)) if item
      parts.push(PokeAccess::I18n.t(:dmax_factor)) if gmax_mark?(pk)
      trained = training(pk)
      parts.push(trained) if trained
      moves = (pk.moves rescue []).compact.map { |m| PokeAccess::Data.move_name(m.id) }.compact
      parts.push(PokeAccess::I18n.t(:sm_moves, :list => moves.join(", "))) unless moves.empty?
      PokeAccess.sentences(parts)
    end

    # Whether a slot paints the Gigantamax mark, asked by the name of each release.
    def self.gmax_mark?(pk)
      (pk.gmax_factor? rescue false) || (pk.gmaxFactor? rescue false) ? true : false
    end

    # The name with the sex sign the slot paints beside it.
    def self.named(pk)
      PokeAccess.clean(pk.name.to_s) + PokeAccess::Party.sign_phrase(pk)
    end

    # The training a slot's stat icon shows, as pbDrawStatIcons picks it: the stat (HP aside) given full effort, or
    # the balanced icon for an even spread; nil for none.
    def self.training(pk)
      stat = nil
      GameData::Stat.each_main do |st|
        next if st.id == :HP
        stat = st if pk.ev[st.id] == 252
        stat = :balanced if pk.ev[st.id] == 50
      end
      return nil unless stat
      return PokeAccess::I18n.t(:zlair_balanced) if stat == :balanced
      PokeAccess::I18n.t(:zlair_trained, :stat => stat.name)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The swap screen as it opens: its heading, the new Pokemon in full, the current party and the summary key.
    def self.swap_opening(pk)
      party = (($Trainer || $player).party rescue []) || []
      line = "#{PokeAccess::I18n.t(:zlair_new)}: #{pokemon_line(pk)}"
      PokeAccess.speak(PokeAccess.sentences([_INTL("Select a party member to swap."), line,
                                             heading(_INTL("Current Party:"), party), summary_hint]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The tutor screen as it opens: its heading, the party and the summary key. The release for 20 (pbGenerateTutorMove)
    # paints no such heading: its own, with the moves left, comes with the panel.
    def self.tutor_opening(s)
      party = (($Trainer || $player).party rescue []) || []
      title = s.respond_to?(:pbGenerateTutorMove) ? nil : _INTL("Select a party member to tutor.")
      PokeAccess.speak(PokeAccess.sentences([title, heading(_INTL("Current Party:"), party), summary_hint]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Keeps a line for the info key.
    def self.publish_line(line)
      PokeAccess::Info.set_info(:text, line, line)
    end

    # The party member the swap screen's left arrow points at, with its place; the first read queued after the
    # message that asks for one. The info key has the member whole.
    def self.party_cursor(s)
      y = arrow_y(s, "leftarrow")
      return unless y
      party = (($Trainer || $player).party rescue []) || []
      i = (y - PARTY_Y) / ROW_STEP
      pk = party[i]
      return unless pk && i >= 0
      PokeAccess::Cursor.announce(s, :zlair_party, [i, pk.object_id], true, false) do
        publish_line(pokemon_line(pk))
        PokeAccess::Verbosity.list_entry(PokeAccess.clean(pk.name.to_s), i + 1, party.length)
      end
    end

    # The tutor's panel for the member the arrow points at, as pbDrawTutorScreen paints it: the member, the new move
    # (its name, type and category icons, power, accuracy and PP) and the moves it knows, or that none is left to learn;
    # the header the release for 20 paints above it, with the moves left, only when that changes. The info key has it all.
    def self.tutor_panel(s, pk, move, painted)
      party = (($Trainer || $player).party rescue []) || []
      i = party.index { |p| p.equal?(pk) } || 0
      member = PokeAccess::Verbosity.list_entry(PokeAccess.clean(pk.name.to_s), i + 1, party.length)
      top = painted.find { |r| HEADER_YS.include?(r[3]) }
      title = top ? PokeAccess.clean(top[0].to_s) : nil
      rows = painted.reject { |r| HEADER_YS.include?(r[3]) }
      left = rows.select { |r| r[2].is_a?(Numeric) && r[2] < moves_x(rows) }.sort_by { |r| r[3] }
      known = rows.select { |r| r[2].is_a?(Numeric) && r[2] >= moves_x(rows) }.sort_by { |r| r[3] }
      parts = [member]
      if move
        texts = left.map { |r| PokeAccess.clean(r[0].to_s) }
        cat = PokeAccess::MoveInfo.category_word(PokeAccess::Data.move_category(move))
        head = [PokeAccess::I18n.t(:zlair_new), texts.shift, PokeAccess::Data.move_type_name(move), cat].compact
        parts.push(head.join(", "))
        parts.concat(texts)
        names = known.map { |r| PokeAccess.clean(r[0].to_s) }
        parts.push(PokeAccess::I18n.t(:sm_moves, :list => names.join(", "))) unless names.empty?
      else
        parts.concat(rows.map { |r| PokeAccess.clean(r[0].to_s) })
      end
      line = PokeAccess.sentences(parts)
      whole = PokeAccess.sentences([title, line])
      publish_line(whole)
      fresh = PokeAccess::Cursor.changed?(s, :zlair_tutor_title, title)
      PokeAccess::Cursor.announce(s, :zlair_tutor, [i, move, title], true, false) { fresh ? whole : line }
    end

    # The x the tutor's known moves are painted from: the panel's rightmost column.
    def self.moves_x(rows)
      xs = rows.map { |r| r[2] }.select { |x| x.is_a?(Numeric) }
      xs.empty? ? 0 : xs.max
    end

    # The item or training screen as it is drawn: keeps the list its rows come from (the items offered, the training
    # courses), then says its opening.
    def self.drawn(s, list)
      @list = list ? list.dup : nil
      list_opening(s)
    end

    # The item and training screens as they open: the current party (with the item each holds, or its training) and
    # the rows offered; said once per screen.
    def self.list_opening(s)
      return unless PokeAccess::Cursor.changed?(s, :zlair_list_open, @mode)
      party = (($Trainer || $player).party rescue []) || []
      members = party.map do |pk|
        extra = @mode == :items ? held(pk) : training(pk)
        [PokeAccess.clean(pk.name.to_s), extra].compact.join(", ")
      end
      parts = ["#{_INTL('Current Party:')} #{members.join('; ')}",
               PokeAccess::I18n.t(:zlair_offered, :list => (@list || []).map { |r| row_name(r) }.join(", ")),
               summary_hint]
      PokeAccess.speak(PokeAccess.sentences(parts), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The item a party member's icon shows it holding, or nil.
    def self.held(pk)
      item = (pk.item rescue nil)
      item ? PokeAccess::I18n.t(:zlair_holding, :item => PokeAccess::Data.item_name((item.id rescue item))) : nil
    end

    # A row of the list as painted: an item by name, a training course by its own name.
    def self.row_name(r)
      r.is_a?(Array) ? r[0].to_s : PokeAccess::Data.item_name(r).to_s
    end

    # The item or training row the right arrow points at, with its place, read anew for each party member's turn.
    def self.row_cursor(s)
      y = arrow_y(s, "rightarrow")
      list = @list || []
      return unless y
      i = (y - ROW_Y) / ROW_STEP
      return unless i >= 0 && i < list.length
      PokeAccess::Cursor.announce(s, :zlair_row, [header(s), i, list[i]], true, false) do
        publish_row(list[i])
        PokeAccess::Verbosity.list_entry(row_name(list[i]), i + 1, list.length)
      end
    end

    # Keeps a list row for the info key: an item with its description, a training course by its name.
    def self.publish_row(row)
      row.is_a?(Array) ? publish_line(row_name(row)) : PokeAccess::Info.set_info(:item, row, row_name(row))
    end

    # The prize the right arrow points at (it stands beside the prize's party icon): its name, a shiny one's sparkle
    # as its sprite shows it, and its place; the info key has it whole.
    def self.prize_cursor(s)
      y = arrow_y(s, "rightarrow")
      prizes = @list || []
      return unless y
      i = (0...prizes.length).find do |k|
        icon = PokeAccess.sprite(s, "partysprite#{k}")
        icon && icon.y.to_i + 5 == y
      end
      return unless i
      pk = prizes[i]
      PokeAccess::Cursor.announce(s, :zlair_prize, [i, pk.object_id], true, false) do
        publish_line(pokemon_line(pk))
        name = PokeAccess.clean(pk.name.to_s)
        name = "#{name}, #{PokeAccess::I18n.t(:pk_shiny)}" if (pk.shiny? rescue false)
        PokeAccess::Verbosity.list_entry(name, i + 1, prizes.length)
      end
    end

    # A string painted on the menu's text layer while a whole screen (treasure, record) is open.
    def self.note(bitmap, text, x, y)
      return unless @scene && (@mode == :treasure || @mode == :record)
      return unless bitmap.equal?(PokeAccess.ivar(@scene, :@changetext))
      t = text.to_s
      @rows.push([t, :positions, x, y]) unless t.strip.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The treasure or record screen, once painted, as its lines read top to bottom; labels joined to their values.
    def self.whole
      return if @said || @rows.empty?
      @said = true
      lines = PokeAccess::PaintCapture.pair_labels(PokeAccess::PaintCapture.lines(@rows))
      PokeAccess.speak(PokeAccess.sentences(lines), false) unless lines.empty?
    end
  end
end

# The map's run with its choices: the whole of pbStartMapScene in the release for 19, lair_ChooseRoute in the one for 20,
# whose intro and first move before it read nothing.
PokeAccess::Hooks.around_hook("LairMapScene", :pbStartMapScene, :optional => true) do |scene, nxt, _a|
  PokeAccess::ZudLairMap.run(scene) { nxt.call }
end
PokeAccess::Hooks.around_hook("LairMapScene", :lair_ChooseRoute, :optional => true) do |scene, nxt, _a|
  PokeAccess::ZudLairMap.run(scene) { nxt.call }
end
# The lair's name on its opening title, in the release for 20.
PokeAccess::Hooks.before_hook("LairMapScene", :lair_MapIntro, :optional => true) do |scene, _a|
  PokeAccess.speak(PokeAccess.clean(PokeAccess.ivar(scene, :@map_name).to_s), false)
end
[[:pbRentalSelect, :rental], [:pbSwapSelect, :swap], [:pbItemSelect, :items], [:pbTrainingSelect, :training],
 [:pbTutorSelect, :tutor], [:pbTreasureScreen, :treasure], [:pbEndlessRecordScreen, :record]].each do |meth, mode|
  PokeAccess::Hooks.around_hook("MaxLairEventScene", meth, :optional => true) do |scene, nxt, _a|
    PokeAccess::ZudLairMenus.run(scene, mode) { nxt.call }
  end
end
# The prizes: handed to pbPrizeSelect in the release for 19, kept by the adventure in the one for 20.
PokeAccess::Hooks.around_hook("MaxLairEventScene", :pbPrizeSelect, :optional => true) do |scene, nxt, args|
  PokeAccess::ZudLairMenus.run(scene, :prize, args[-1] || (PokeAccess::ZudLairMap.state.prizes rescue nil)) { nxt.call }
end
# The new Pokemon: handed to pbSwapSelect in the release for 19, only to pbDrawSwapScreen in the one for 20.
PokeAccess::Hooks.before_hook("MaxLairEventScene", :pbSwapSelect, :optional => true) do |_scene, args|
  PokeAccess::ZudLairMenus.swap_opening(args[-1]) unless args.empty?
end
PokeAccess::Hooks.before_hook("MaxLairEventScene", :pbDrawSwapScreen, :optional => true) do |_scene, args|
  PokeAccess::ZudLairMenus.swap_opening(args[-1]) if args[-1] && !(pbDynAdventureState rescue nil)
end
PokeAccess::Hooks.before_hook("MaxLairEventScene", :pbTutorSelect, :optional => true) do |scene, _args|
  PokeAccess::ZudLairMenus.tutor_opening(scene)
end
PokeAccess::Hooks.after_hook("MaxLairEventScene", :pbDrawItemScreen, :optional => true) do |scene, _r, args|
  PokeAccess::ZudLairMenus.drawn(scene, args[0])
end
PokeAccess::Hooks.after_hook("MaxLairEventScene", :pbDrawStatScreen, :optional => true) do |scene, _r, args|
  PokeAccess::ZudLairMenus.drawn(scene, args[0])
end
PokeAccess::Hooks.on_paint("MaxLairEventScene", :pbDrawTutorScreen, :optional => true) do |scene, rows, args|
  PokeAccess::ZudLairMenus.tutor_panel(scene, args[-2], args[-1], rows)
end
# The menus' paint, looked at only while the treasure or record screen is open.
PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "plugin_zud_lair_pbDrawTextPositions", :before) do |args, _r|
  next unless PokeAccess::ZudLairMenus.mode
  (args[1] || []).each { |r| PokeAccess::ZudLairMenus.note(args[0], r[0], r[1], r[2]) if r.is_a?(Array) }
end
PokeAccess::Frame.each_pulse do
  PokeAccess::ZudLairMap.poll
  PokeAccess::ZudLairMenus.poll
end
PokeAccess::Hooks.clear_info_on("LairMapScene", :pbEndScene)
PokeAccess::Hooks.clear_info_on("MaxLairEventScene", :pbEndScene)
