module PokeAccess
  # ZUD's Max Lair map (LairMapScene). At each Selection tile: the hearts, keys and floor the corner shows, the paths
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

    @scene = nil
    @mode = nil

    # Holds the map while its scene runs (the block).
    def self.run(scene)
      @scene = scene
      @mode = nil
      yield
    ensure
      @scene = nil
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
        a = PokeAccess.ivar(s, WAYS[i][0])
        a && (a.visible rescue false)
      end
    end

    # The way whose arrow is lit, or nil.
    def self.lit(s)
      ways(s).find { |i| ((PokeAccess.ivar(s, WAYS[i][0]).color.alpha rescue 0).to_i == LIT) }
    end

    # Where the player icon stands on the map, as an offset from the map's picture, the same however the map scrolls.
    def self.place(s, sprite = nil)
      sprite ||= PokeAccess.ivar(s, :@player)
      bg = PokeAccess.sprite(s, "background")
      [sprite.x - bg.x, sprite.y - bg.y]
    end

    # The route choice: on a new tile, the corner and every way the arrows offer with its path, the lit one first,
    # queued; back from another screen over the same tile, the lit way's path again; then each lit way's path as the
    # arrow keys change it.
    def self.route(s, entered)
      way = lit(s)
      return unless way
      here = place(s)
      if PokeAccess::Cursor.changed?(s, :zlair_here, here)
        PokeAccess::Cursor.store(s, :zlair_way, [here, way])
        PokeAccess.speak(route_opening(s, way), false)
      else
        PokeAccess::Cursor.reset(s, :zlair_way) if entered
        PokeAccess::Cursor.announce(s, :zlair_way, [here, way], true, false) { path_line(s, way) }
      end
    end

    # The corner, each way's path (the lit one first), then the options key.
    def self.route_opening(s, way)
      order = [way] + (ways(s) - [way])
      parts = [corner(s)].concat(order.map { |i| path_line(s, i) })
      parts.push(hint(:zlair_options, :a, nil)) if PokeAccess::Verbosity.hints?
      PokeAccess.sentences(parts)
    end

    # The corner of the screen: the hearts left of those held, the lair keys when it shows any, the floor window.
    def self.corner(s)
      state = (pbDynAdventureState rescue nil)
      hearts = (state.knockouts rescue PokeAccess.ivar(s, :@knockouts)).to_i
      parts = [PokeAccess::I18n.t(:zlair_hearts, :n => hearts, :max => PokeAccess.ivar(s, :@maxHearts).to_i)]
      keys = PokeAccess.sprite(s, "lairkey")
      if keys && (keys.visible rescue false)
        parts.push(PokeAccess::I18n.t(:zlair_keys, :n => (state.keycount rescue PokeAccess.ivar(s, :@lairKeys)).to_i))
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
    # tiles not yet battled, switches, warps (followed to the next one) and flips (which turn it back), up to the tile
    # it stops on (a Selection or the Start tile, a door or a roadblock that may turn it back, a random turn). Arrow
    # tiles turn it unsaid; hidden traps, which the map does not draw, are passed over.
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
        turn = (s.pbTurnTiles(at) rescue nil)
        if turn == 4
          out.push([:random])
          break
        end
        out.push([:flip]) if turn == 5
        way = turn == 5 ? FLIP[way] : (turn || way)
        if s.pbStartTile?(at)
          out.push([:start])
          break
        end
        if s.pbRouteSelections(at)
          out.push([:selection])
          break
        end
      end
      out
    end

    # What one tile of a trace holds, pushed onto out: :stop at a door or roadblock, a warp's landing place
    # (map offset) to go on from, else nil.
    def self.step(s, at, out)
      if s.pbLockedDoorTile?(at) || s.pbRoadblockTile?(at)
        out.push([s.pbLockedDoorTile?(at) ? :door : :roadblock])
        return :stop
      end
      ev = s.pbEventTiles(at)
      out.push([:event, ev]) if ev
      i = s.pbPokemonTiles(at)
      out.push([:raid, i]) if i && fresh_raid?(s, i)
      out.push([:switch]) if s.pbSwitchTile?(at)
      return nil unless s.pbWarpTile?(at)
      out.push([:warp])
      warp_landing(s, at)
    end

    # The map offset of the warp a Warp tile sends the icon to: the next one in the map's list, as pbWarpPlayer picks.
    def self.warp_landing(s, at)
      list = PokeAccess.ivar(s, :@mapWarpPoint) || []
      list.length.times do |i|
        tile = PokeAccess.sprite(s, "mapWarpPoint#{i}")
        next unless tile && [tile.x, tile.y] == at
        dest = PokeAccess.sprite(s, "mapWarpPoint#{(i + 1) % list.length}")
        return place(s, dest) if dest
      end
      nil
    end

    # Whether raid tile i still holds its Pokemon: the silhouette is drawn until it has been battled.
    def self.fresh_raid?(s, i)
      pk = PokeAccess.sprite(s, "pokemon#{i}")
      pk ? (pk.color.alpha rescue 0).to_i == 255 : false
    end

    # The type a raid tile's icon shows, from the row of the type strip it crops.
    def self.raid_type(s, i)
      icon = PokeAccess.sprite(s, "poketype#{i}")
      row = (icon.src_rect.y rescue nil)
      row ? PokeAccess::Data.type_name(row.to_i / 28) : nil
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
      boss = PokeAccess.ivar(s, :@size).to_i - 1
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

    # The map view: the tile the cursor selects, said as it changes.
    def self.hover(s, cursor)
      at = hovered(s, cursor)
      key = at ? place_of(s, at) : nil
      PokeAccess::Cursor.announce(s, :zlair_hover, key) { describe(s, at) } if at
      PokeAccess::Cursor.reset(s, :zlair_hover) unless at
    end

    # The screen spot of the tile the cursor selects, as pbCursorReact picks it (the last drawn tile within reach of
    # the cursor's centre, hidden traps aside), or nil.
    def self.hovered(s, cursor)
      cx = cursor.x + 16
      cy = cursor.y + 16
      pick = nil
      (PokeAccess.ivar(s, :@mapSprites) || []).each do |sp|
        next unless (sp.visible rescue false)
        at = [sp.x, sp.y]
        next if s.pbHiddenTrapTile?(at)
        pick = at if (cx - at[0]).abs <= REACH && (cy - at[1]).abs <= REACH
      end
      pick
    end

    def self.place_of(s, at)
      bg = PokeAccess.sprite(s, "background")
      [at[0] - bg.x, at[1] - bg.y]
    end

    # A hovered tile as its picture shows it, in the order the scene's own tile help checks; nil for bare ground.
    def self.describe(s, at)
      return tile_name(s, [:start]) if s.pbStartTile?(at)
      return tile_name(s, [:selection]) if s.pbRouteSelections(at)
      i = s.pbPokemonTiles(at)
      return (fresh_raid?(s, i) ? raid_name(s, i) : tile_name(s, [:raid_done])) if i
      return tile_name(s, [:warp]) if s.pbWarpTile?(at)
      return tile_name(s, [:door]) if s.pbLockedDoorTile?(at)
      return tile_name(s, [:roadblock]) if s.pbRoadblockTile?(at)
      return tile_name(s, [:switch]) if s.pbSwitchTile?(at)
      turn = s.pbTurnTiles(at)
      return tile_name(s, [turn == 4 ? :random : :flip]) if turn == 4 || turn == 5
      return tile_name(s, [:turn, turn]) if turn
      ev = s.pbEventTiles(at)
      ev ? tile_name(s, [:event, ev]) : nil
    end

    # The speed-up key, once per lair, as its sign first shows while the icon moves.
    def self.speed_hint(s)
      sign = PokeAccess.sprite(s, "speedup")
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
    HEADER_Y = -6

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
        PokeAccess::Info.set_info(:text, line, line)
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
      row = (PokeAccess.ivar(s, :@textPos) || []).find { |r| r.is_a?(Array) && r[2] == HEADER_Y }
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
      parts.push(PokeAccess::I18n.t(:dmax_factor)) if (pk.gmaxFactor? rescue false)
      trained = training(pk)
      parts.push(trained) if trained
      moves = (pk.moves rescue []).compact.map { |m| PokeAccess::Data.move_name(m.id) }.compact
      parts.push(PokeAccess::I18n.t(:sm_moves, :list => moves.join(", "))) unless moves.empty?
      PokeAccess.sentences(parts)
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
      party = ($Trainer.party rescue []) || []
      line = "#{PokeAccess::I18n.t(:zlair_new)}: #{pokemon_line(pk)}"
      PokeAccess.speak(PokeAccess.sentences([_INTL("Select a party member to swap."), line,
                                             heading(_INTL("Current Party:"), party), summary_hint]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The tutor screen as it opens: its heading, the party and the summary key.
    def self.tutor_opening
      party = ($Trainer.party rescue []) || []
      PokeAccess.speak(PokeAccess.sentences([_INTL("Select a party member to tutor."),
                                             heading(_INTL("Current Party:"), party), summary_hint]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The party member the swap screen's left arrow points at, with its place; the first read queued after the
    # message that asks for one.
    def self.party_cursor(s)
      y = arrow_y(s, "leftarrow")
      return unless y
      party = ($Trainer.party rescue []) || []
      i = (y - PARTY_Y) / ROW_STEP
      pk = party[i]
      return unless pk && i >= 0
      PokeAccess::Cursor.announce(s, :zlair_party, [i, pk.object_id], true, false) do
        PokeAccess::Verbosity.list_entry(PokeAccess.clean(pk.name.to_s), i + 1, party.length)
      end
    end

    # The tutor's panel for the member the arrow points at, as pbDrawTutorScreen paints it: the member, the new move
    # (its name, type and category icons, power, accuracy and PP) and the moves it knows, or that none is left to learn.
    def self.tutor_panel(s, pk, move, rows)
      party = ($Trainer.party rescue []) || []
      i = party.index { |p| p.equal?(pk) } || 0
      member = PokeAccess::Verbosity.list_entry(PokeAccess.clean(pk.name.to_s), i + 1, party.length)
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
      PokeAccess::Cursor.announce(s, :zlair_tutor, [i, move], true, false) { line }
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
      party = ($Trainer.party rescue []) || []
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
        PokeAccess::Verbosity.list_entry(row_name(list[i]), i + 1, list.length)
      end
    end

    # The prize the right arrow points at (it stands beside the prize's party icon): its name, a shiny one's sparkle
    # as its sprite shows it, and its place.
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

PokeAccess::Hooks.around_hook("LairMapScene", :pbStartMapScene, :optional => true) do |scene, nxt, _a|
  PokeAccess::ZudLairMap.run(scene) { nxt.call }
end
[[:pbRentalSelect, :rental], [:pbSwapSelect, :swap], [:pbItemSelect, :items], [:pbTrainingSelect, :training],
 [:pbTutorSelect, :tutor], [:pbTreasureScreen, :treasure], [:pbEndlessRecordScreen, :record]].each do |meth, mode|
  PokeAccess::Hooks.around_hook("MaxLairEventScene", meth, :optional => true) do |scene, nxt, _a|
    PokeAccess::ZudLairMenus.run(scene, mode) { nxt.call }
  end
end
PokeAccess::Hooks.around_hook("MaxLairEventScene", :pbPrizeSelect, :optional => true) do |scene, nxt, args|
  PokeAccess::ZudLairMenus.run(scene, :prize, args[0]) { nxt.call }
end
PokeAccess::Hooks.before_hook("MaxLairEventScene", :pbSwapSelect, :optional => true) do |_scene, args|
  PokeAccess::ZudLairMenus.swap_opening(args[0])
end
PokeAccess::Hooks.before_hook("MaxLairEventScene", :pbTutorSelect, :optional => true) do |_scene, _args|
  PokeAccess::ZudLairMenus.tutor_opening
end
PokeAccess::Hooks.after_hook("MaxLairEventScene", :pbDrawItemScreen, :optional => true) do |scene, _r, args|
  PokeAccess::ZudLairMenus.drawn(scene, args[0])
end
PokeAccess::Hooks.after_hook("MaxLairEventScene", :pbDrawStatScreen, :optional => true) do |scene, _r, args|
  PokeAccess::ZudLairMenus.drawn(scene, args[0])
end
PokeAccess::Hooks.around_hook("MaxLairEventScene", :pbDrawTutorScreen, :optional => true) do |scene, nxt, args|
  ret = nil
  rows = PokeAccess::PaintCapture.sample { ret = nxt.call }
  begin
    PokeAccess::ZudLairMenus.tutor_panel(scene, args[0], args[1], rows)
  rescue StandardError => e
    PokeAccess.swallowed(e)
  end
  ret
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
