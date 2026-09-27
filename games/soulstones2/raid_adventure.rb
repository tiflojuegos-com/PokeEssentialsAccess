# Soulstones 2's raid adventures (its edited DBK Raid Battles), none of them a window: each menu box as it is
# selected, the overlay's words as they change, and on the lair map the crossroads' paths, the free view's
# tile and the corner counters.
module PokeAccess
  module SS2Adventure
    DIR_KEYS = [:dir_up, :dir_down, :dir_left, :dir_right]
    # The grid step of each direction, in the game's numbering (0 north, 1 south, 2 west, 3 east).
    STEPS = [[0, -1], [0, 1], [-1, 0], [1, 0]]
    # The tiles that turn the party rather than stop it, and where to.
    TURNS = { :TurnNorth => 0, :TurnSouth => 1, :TurnWest => 2, :TurnEast => 3 }
    PASSAGES = [:Pathway, :StartPoint]
    BOSS_RANK = 6
    # How far a path is followed before giving up on naming where it ends.
    PATH_LIMIT = 64
    # The height of one icon in the strips a battle tile is cut from: Tera types are 32, plain types 28.
    TERA_ICON_ROW = 32
    TYPE_ICON_ROW = 28
    # The map modes that open the free view, each with a key legend of its own.
    VIEW_MODES = [:viewing, :teleporting]
    # The keys a menu walks its boxes with: a box selected while none of them is down was selected by the game.
    NAV_KEYS = [:UP, :DOWN, :LEFT, :RIGHT, :JUMPUP, :JUMPDOWN]
    # Where the column of Pokemon boxes starts (the rental box's SLOT_BASE_X); left of it is the menu's panel.
    BOX_COLUMN_X = 166
    # The height of the bottom bar that carries a menu's key hints.
    HINT_BAR = 32

    # A stand-in the map's cursor reacts to, so the cursor's darkness test can be asked about a tile it would
    # never name itself: a hidden trap, which this copy of the plugin still draws.
    LitProbe = Struct.new(:coords)
    class LitProbe
      def cursor_react?; true; end
      def isTile?(*_ids); false; end
    end

    @scene = nil
    @hold = false
    @opening = false
    @pending = nil
    @refilled = nil
    @extra = nil
    @route = nil
    @route_dir = nil

    # Watches a menu scene's overlay from its start; its first box, selected before the heading and instruction
    # are painted, is held and said after them.
    def self.enter(scene)
      @scene = scene
      @hold = false
      @opening = true
      @pending = nil
      @extra = nil
      @buttons = nil
    end

    # The menu is gone, and what the info key kept of its boxes with it.
    def self.leave
      @scene = nil
      @hold = false
      @opening = false
      @pending = nil
      @extra = nil
      PokeAccess::Info.clear_text
    end

    # The step is over: what the opening held back is said, and a box selected from here on answers a key.
    def self.step
      flush
      @opening = false
      @hold = false
    end

    def self.flush
      t = @pending
      @pending = nil
      PokeAccess.speak(t, false) if t
    end

    # Runs a menu that shows Pokemon in boxes nobody selects (an exchange's offer, the record's party): they are
    # read with its first instruction, and its overlay is read whole.
    def self.showing(kind)
      @extra = kind
      PokeAccess::Cursor.reset(@scene, :ss2_adv_overlay) if @scene
      yield
    ensure
      @extra = nil
    end

    # Speaks the overlay's new words when a paint changes them, without its key hints while hints are left out;
    # queued, and a box selected in the same step queues behind them.
    def self.overlay_paint(bitmap, rows)
      s = @scene
      return unless s && rows.is_a?(Array)
      ov = PokeAccess.sprite(s, "overlay")
      return unless ov && bitmap.equal?((ov.bitmap rescue nil))
      rows = rows.reject { |r| hint_row?(r) } unless PokeAccess::Verbosity.hints?
      boxes = shown_boxes(s, @extra)
      @extra = nil
      words = boxes.empty? ? rows.map { |r| PokeAccess.clean((r[0] rescue nil).to_s) } : laid_out(rows, boxes)
      words = words.reject { |w| w.to_s.empty? }
      had = PokeAccess::Cursor.current(s, :ss2_adv_overlay)
      return if words.empty? || !PokeAccess::Cursor.changed?(s, :ss2_adv_overlay, words)
      fresh = words - (had.is_a?(Array) ? had : [])
      return if fresh.empty?
      @hold = true
      PokeAccess.speak(fresh.join(", "), false)
      flush
    end

    # The Pokemon in a menu's unselected rental boxes, each with where its box stands; only the exchange's offer
    # shows its training icon.
    def self.shown_boxes(scene, kind)
      boxes = case kind
              when :offer then [[PokeAccess.sprite(scene, "pokemon"), true]]
              when :record then ["rental_0", "rental_1", "rental_2"].map { |k| [PokeAccess.sprite(scene, k), false] }
              else []
              end
      boxes.select { |b, _t| b }.map { |b, training| [rental_text(b, training), b.x.to_i, b.y.to_i] }.reject { |e| e[0].nil? }
    end

    # The words of such a menu in screen order, not paint order: its panel top to bottom, then the box column,
    # then the bottom bar's key hints.
    def self.laid_out(rows, boxes)
      bar = bar_top
      items = rows.map { |r| [PokeAccess.clean((r[0] rescue nil).to_s), (r[1] rescue 0).to_i, (r[2] rescue 0).to_i] } + boxes
      hints, rest = items.partition { |i| i[2] >= bar }
      panel, column = rest.partition { |i| i[1] < BOX_COLUMN_X }
      (panel.sort_by { |i| [i[2], i[1]] } + column.sort_by { |i| [i[2], i[1]] } + hints.sort_by { |i| i[1] }).map { |i| i[0] }
    end

    # Where the bottom bar with a menu's key hints starts.
    def self.bar_top
      (Graphics.height rescue 384) - HINT_BAR
    end

    # Remembers where the last paint of the overlay put its key-button icons, as [x, y].
    def self.note_buttons(bitmap, rows)
      s = @scene
      return unless s && rows.is_a?(Array)
      ov = PokeAccess.sprite(s, "overlay")
      return unless ov && bitmap.equal?((ov.bitmap rescue nil))
      @buttons = rows.select { |r| r.is_a?(Array) && r[0].to_s =~ /buttons\z/ }.map { |r| [r[1].to_i, r[2].to_i] }
    end

    # True for a key hint: a row in the bottom bar, or the label painted just right of a key-button icon.
    def self.hint_row?(r)
      x = (r[1] rescue 0).to_i
      y = (r[2] rescue 0).to_i
      return true if y >= bar_top
      (@buttons || []).any? { |bx, by| x >= bx + 32 && x <= bx + 48 && y >= by && y <= by + 32 }
    end

    # Marks a selected box whose contents were replaced (a page of spoils turned under it), so it is read again.
    def self.refilled(box)
      @refilled = box if PokeAccess.ivar(box, :@selected)
    end

    # Runs a box's selected= and answers whether that made it the selected box, or re-selected a box whose
    # contents just changed.
    def self.became_selected?(box, value)
      was = PokeAccess.ivar(box, :@selected) ? true : false
      yield
      fresh = value && box.equal?(@refilled)
      @refilled = nil if box.equal?(@refilled)
      (value && !was) || fresh
    end

    # Reads a box as it becomes the selected one, interrupting unless the instruction changed in the same step;
    # one the game selects by itself is held until the step paints its instruction.
    # param queued true for a box the game selects on its own, one after another
    def self.say_box(text, queued = false)
      return if text.nil? || text.to_s.strip.empty?
      if @opening || (@scene && !queued && !@hold && !key_moved?)
        @pending = text
        return
      end
      PokeAccess.speak(text, !(queued || @hold))
    end

    # Whether one of the keys a menu walks its boxes with is down this frame.
    def self.key_moved?
      NAV_KEYS.any? { |k| Input.const_defined?(k) && Input.repeat?(Input.const_get(k)) }
    rescue StandardError
      true
    end

    # A Pokemon's name as its box writes it, with the sex sign beside it.
    def self.name_part(pk)
      [PokeAccess.clean(pk.name.to_s), PokeAccess::Party.gender_glyph(pk)].compact.join(" ")
    end

    # The icon a box adds for the adventure's style: the Tera type, or the Gigantamax factor.
    def self.style_parts(pk, style)
      case style
      when :Tera
        t = PokeAccess::Data.type_name((pk.tera_type rescue nil))
        t ? [PokeAccess::I18n.t(:ss2_adv_tera, :t => t)] : []
      when :Max
        (pk.gmax_factor? rescue false) ? [PokeAccess::I18n.t(:ss2_adv_gmax)] : []
      else
        []
      end
    end

    # What a box's training icon stands for, as the box picks it: the first stat with effort if it is at the raid
    # limit, else balanced; no icon without effort.
    def self.training_parts(pk)
      limit = (::Pokemon::RAID_EV_STAT_LIMIT rescue nil)
      mark = nil
      GameData::Stat.each_main_battle do |st|
        ev = (pk.ev[st.id] rescue 0).to_i
        next if ev == 0 || mark
        mark = (limit && ev == limit) ? st.name : :balanced
      end
      return [] unless mark
      [mark == :balanced ? PokeAccess::I18n.t(:ss2_adv_training_balanced) : PokeAccess::I18n.t(:ss2_adv_training, :s => mark)]
    rescue StandardError
      []
    end

    # What a box's item icon shows: the Z-crystal itself in an Ultra lair, elsewhere only that something is held.
    def self.item_parts(pk, style)
      return [] unless (pk.hasItem? rescue false)
      return [PokeAccess::I18n.t(:dbk_item, :i => pk.item.name)] if style == :Ultra
      [PokeAccess::I18n.t(:ss2_adv_holds)]
    rescue StandardError
      []
    end

    # The name a box writes, with the sex sign beside it where the reading's full level reaches.
    def self.shown_name(pk, reading)
      PokeAccess::Verbosity.keep?(reading, :full) ? name_part(pk) : PokeAccess.clean(pk.name.to_s)
    end

    # A rental's parts after its name, as [text, level] of the choose-a-Pokemon reading: types from medium; the
    # ability, moves and icons (item, style mark, training) in full.
    # param training whether the training icon is on screen
    def self.rental_parts(pk, style, training)
      parts = []
      types = PokeAccess::Data.pokemon_types(pk)
      parts.push([PokeAccess::I18n.t(:mv_type, :t => types.join("/")), :medium]) unless types.empty?
      ab = (pk.ability.name rescue nil)
      parts.push([PokeAccess::I18n.t(:dbk_ability, :a => ab), :full]) if ab
      moves = ((pk.moves || []).map { |m| m.name } rescue [])
      parts.push([PokeAccess::I18n.t(:sm_moves, :list => moves.join(", ")), :full]) unless moves.empty?
      icons = item_parts(pk, style).concat(style_parts(pk, style))
      icons.concat(training_parts(pk)) if training
      icons.each { |p| parts.push([p, :full]) }
      parts
    end

    # A rental box whole, the name with its sex sign first: as a menu shows it beside its instruction, in a panel
    # nobody selects (the exchange's offer, the record's party).
    # param training whether the training icon is on screen
    def self.rental_text(box, training = true)
      pk = PokeAccess.ivar(box, :@pokemon)
      return nil unless pk
      PokeAccess::Verbosity.full_line([name_part(pk)].concat(rental_parts(pk, PokeAccess.ivar(box, :@style), training)))
    end

    # A rental box as the menu selects it, at the choose-a-Pokemon reading's level; the info key says the Pokemon, and
    # Ctrl+T the box whole.
    def self.rental_row(box)
      pk = PokeAccess.ivar(box, :@pokemon)
      return nil unless pk
      rest = rental_parts(pk, PokeAccess.ivar(box, :@style), true)
      PokeAccess::Info.set_info(:pokemon, pk, rental_text(box, true))
      PokeAccess::Verbosity.line(:pokemon_choice, [[shown_name(pk, :pokemon_choice), :brief]].concat(rest))
    end

    # A party box as the menu selects it; the info key says the Pokemon, and Ctrl+T the box whole.
    def self.party_text(box)
      pk = PokeAccess.ivar(box, :@pokemon)
      return nil unless pk
      style = PokeAccess.ivar(box, :@style)
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { party_row(pk, style) })
      party_row(pk, style)
    end

    # A party box's row at the party reading's level: the name, the share of hit points its bar fills (or fainted)
    # and the status always; the sex sign, the item and the style and training icons in full.
    def self.party_row(pk, style)
      parts = [[shown_name(pk, :party), :brief]]
      if (pk.fainted? rescue false)
        parts.push([PokeAccess::I18n.t(:pk_fainted), :brief])
      else
        parts.push([PokeAccess::Battle.hp_phrase(pk.hp, pk.totalhp, true), :brief])
        st = (pk.status rescue :NONE)
        sn = (GameData::Status.get(st).name rescue nil) if st && st != :NONE
        parts.push([sn, :brief]) if sn
      end
      item_parts(pk, style).concat(style_parts(pk, style)).concat(training_parts(pk)).each { |p| parts.push([p, :full]) }
      PokeAccess::Verbosity.line(:party, parts)
    end

    # A captured Pokemon to keep, as the menu selects it; the info key says the Pokemon, and Ctrl+T the box whole.
    def self.reward_text(box)
      pk = PokeAccess.ivar(box, :@pokemon)
      return nil unless pk
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { reward_row(pk) })
      reward_row(pk)
    end

    # A captured Pokemon's row: name, and at the choose-a-Pokemon reading's full level the sex sign and shiny mark.
    def self.reward_row(pk)
      parts = [[shown_name(pk, :pokemon_choice), :brief]]
      parts.push([PokeAccess::I18n.t(:pk_shiny), :full]) if PokeAccess::Party.shiny?(pk)
      PokeAccess::Verbosity.line(:pokemon_choice, parts)
    end

    # An item square: the item, with a machine's move as the name box writes it, and the count the square paints.
    # The info key says the item; Ctrl+T the square and the menu's description window.
    def self.item_text(box)
      item = PokeAccess.ivar(box, :@item)
      return nil unless item
      name = item.name.to_s
      mv = ((item.is_machine? ? GameData::Move.get(item.move).name : nil) rescue nil)
      name = "#{name} #{mv}" if mv
      qty = PokeAccess.ivar(box, :@quantity).to_i
      t = qty > 0 ? "#{name}, x#{qty}" : name
      PokeAccess::Info.set_info(:item, (item.id rescue item), t)
      t
    end

    # A move to teach as every move reader says it, category and full PP included, at the learn-a-move reading's
    # level; the info key says the move, Ctrl+T the whole line and the description window.
    def self.move_text(box)
      mv = PokeAccess.ivar(box, :@move)
      return nil unless mv
      type = PokeAccess::Data.type_name((mv.type rescue nil))
      pp = (mv.total_pp rescue nil)
      args = [mv.name, type, (mv.base_damage rescue nil), (mv.accuracy rescue nil),
              { :cat => PokeAccess::MoveInfo.category_word((mv.category rescue nil)), :pp => pp, :total_pp => pp }]
      PokeAccess::Info.set_info(:move, mv, PokeAccess::MoveInfo.line(*args))
      PokeAccess::MoveInfo.leveled(:learn_move, *args)
    end

    # Reads a box from its own paint (a stat or Tera type to pick, Dynamax levels going up), the sex sign beside
    # the name and a painted "old -> new" said as a change.
    # param queued true for the Dynamax boxes, which the menu walks through by itself
    def self.painted_box(box, value, queued = false)
      PokeAccess::PaintCapture.arm(:ss2_adv_box)
      took = became_selected?(box, value) { yield }
      rows = PokeAccess::PaintCapture.take(:ss2_adv_box) || []
      say_box(painted_text(rows), queued) if took
    end

    def self.painted_text(rows)
      signs = rows.select { |r| PokeAccess::Party::SIGNS.include?(r.to_s.strip) }
      rest = (rows - signs).map { |r| change_words(r.to_s) }
      PokeAccess.clean(([rest.first] + signs + rest[1..-1].to_a).compact.join(", "))
    end

    def self.change_words(row)
      row =~ /\A\s*(\d+)\s*->\s*(\d+)\s*\z/ ? PokeAccess::I18n.t(:ss2_adv_change, :from => $1, :to => $2) : row
    end

    # ---- the lair map

    # Wraps one route choice: while it runs, the lit arrow is polled.
    def self.routing(scene)
      @route = scene
      yield
    ensure
      @route = nil
    end

    # A crossroads drawn: the game's own line, every path with where it leads, the lit arrow and, while hints are
    # said, the key legend, queued.
    def self.route_arrows(scene, dir, dirs)
      PokeAccess::PaintCapture.arm(:ss2_adv_route)
      yield
    ensure
      rows = PokeAccess::PaintCapture.take(:ss2_adv_route) || []
      paths = (dirs || []).map { |d| path_text(scene, d) }
      lit = DIR_KEYS[dir.to_i] ? PokeAccess::I18n.t(:ss2_adv_lit, :dir => PokeAccess::I18n.t(DIR_KEYS[dir.to_i])) : nil
      legend = PokeAccess::Verbosity.hints? ? PokeAccess::PaintCapture.text(rows[1..-1].to_a) : nil
      @route_dir = dir
      line = ([PokeAccess.clean(rows.first.to_s)] + paths + [lit, legend]).reject { |x| x.to_s.empty? }
      PokeAccess.speak(line.join(". "), false)
    end

    # The free map view's key legend, queued as the view opens while hints are said (the viewing legend's two
    # painted columns paired up), the last tile forgotten; another mode clears the info key's tile.
    def self.controls(scene, mode)
      unless VIEW_MODES.include?(mode)
        PokeAccess::Info.clear_text
        return yield
      end
      PokeAccess::Cursor.reset(scene, :ss2_adv_cursor)
      PokeAccess::PaintCapture.arm(:ss2_adv_controls)
      r = yield
      rows = PokeAccess::PaintCapture.take(:ss2_adv_controls) || []
      t = PokeAccess::Verbosity.hints? ? PokeAccess::PaintCapture.text(mode == :viewing ? paired(rows) : rows) : ""
      unless t.empty?
        @hold = true
        PokeAccess.speak(t, false)
      end
      r
    end

    def self.paired(rows)
      return rows if rows.length.odd?
      half = rows.length / 2
      (0...half).map { |i| "#{rows[i]} #{rows[half + i]}" }
    end

    # Says the path the lit arrow points down when the player turns it to another.
    def self.poll_route
      s = @route
      return unless s
      d = lit_dir(s)
      return if d.nil? || d == @route_dir
      @route_dir = d
      PokeAccess.speak(path_text(s, d), true)
    end

    # The direction whose arrow the choice loop has coloured.
    def self.lit_dir(scene)
      arrows = scene.ui_sprites
      (0..3).find { |i| ((arrows["route_arrow_#{i}"].color.alpha rescue 0).to_i > 0) }
    rescue StandardError
      nil
    end

    # One path: its direction and, when the map shows it, what it leads to.
    def self.path_text(scene, d)
      dir = PokeAccess::I18n.t(DIR_KEYS[d])
      what = destination(scene, d)
      what ? PokeAccess::I18n.t(:ss2_adv_path, :dir => dir, :what => what) : dir
    end

    # What a path shows on the way: the lit traps on it, then the first tile that does something, as the map's
    # cursor names it (none if the path bends back, runs past PATH_LIMIT or ends in the dark).
    def self.destination(scene, d)
      stop, traps = walk(scene, d)
      words = traps.map { |t| tile_name(scene, t) }
      words.push(tile_name(scene, stop)) if stop && named?(scene, stop)
      return nil if words.empty?
      words.inject { |a, b| PokeAccess::I18n.t(:ss2_adv_then, :a => a, :b => b) }
    rescue StandardError
      nil
    end

    # Walks a path as the party does, turned by turn tiles and over fought battles and hidden traps, up to the
    # first tile that does something, or nil where it would bounce back.
    # return [the tile it stops at or nil, the lit traps passed on the way]
    def self.walk(scene, d)
      x, y = scene.player_tile.coords
      traps = []
      PATH_LIMIT.times do
        x += STEPS[d][0]
        y += STEPS[d][1]
        t = tile_at(scene, x, y)
        return [nil, traps] unless t
        if t.interactable? && t.hidden?
          traps.push(t) if named?(scene, LitProbe.new(t.coords))
        elsif t.interactable? && !t.isTile?(*PASSAGES) && !fought?(scene, t)
          turn = TURNS[t.tile_id]
          return [t, traps] unless turn
          d = turn if tile_at(scene, x + STEPS[turn][0], y + STEPS[turn][1])
        end
        return [nil, traps] unless tile_at(scene, x + STEPS[d][0], y + STEPS[d][1])
      end
      [nil, traps]
    end

    def self.tile_at(scene, x, y)
      scene.pbTileExists?(x, y) ? scene.map_sprites["tile_#{x}_#{y}"] : nil
    end

    def self.fought?(scene, t)
      t.isTile?(:Battle) && ((scene.raid_battles[t.battle_id][:battled] rescue false) ? true : false)
    end

    # Whether the map's cursor would name this tile: the game's own test, darkness included, asked with the
    # cursor set on it for the one call and put back.
    def self.named?(scene, t)
      saved = scene.instance_variable_get(:@cursor_tile)
      scene.instance_variable_set(:@cursor_tile, t)
      begin
        scene.pbCursorReact? ? true : false
      ensure
        scene.instance_variable_set(:@cursor_tile, saved)
      end
    end

    # A tile's name with what the cursor adds to it -- a warp's destination, a switch's position -- and for
    # a battle what its tile shows: the rank (or the boss), and what the map draws over the silhouette.
    def self.tile_name(scene, t)
      name = PokeAccess.clean((t.tile.name rescue "").to_s)
      parts = [name]
      xy = (t.warp_point rescue nil) if t.isTile?(:Warp)
      if xy
        parts = [PokeAccess::I18n.t(:ss2_adv_warp, :name => name, :x => xy[0], :y => xy[1])]
      elsif t.isTile?(:Switch)
        parts.push(PokeAccess::I18n.t((t.switch_on? rescue false) ? :val_on : :val_off))
      elsif t.isTile?(:Battle)
        raid = (scene.raid_battles[t.battle_id] rescue nil)
        rank = (raid[:rank] rescue nil)
        if rank
          parts.push(rank == BOSS_RANK ? PokeAccess::I18n.t(:ss2_adv_boss) : PokeAccess::I18n.t(:ss2_raid_rank, :n => rank))
        end
        parts.push(battle_mark(scene, t.battle_id, raid))
      end
      parts.compact.reject { |p| p.to_s.empty? }.join(", ")
    end

    # What a battle tile draws over the silhouette: one of the Pokemon's types, or its Tera type, read off
    # the icon frame the map cut; in an Ultra lair, the Z-crystal it holds.
    def self.battle_mark(scene, id, raid)
      icon = (scene.map_sprites["pkmntype_#{id}"] rescue nil)
      return nil unless icon
      style = (PokeAccess.ivar(scene, :@adventure).style rescue nil)
      return (GameData::Item.get(raid[:pokemon].item_id).name rescue nil) if style == :Ultra
      pos = (icon.src_rect.y / (style == :Tera ? TERA_ICON_ROW : TYPE_ICON_ROW) rescue nil)
      return nil unless pos.is_a?(Integer)
      type = nil
      GameData::Type.each { |ty| type ||= ty if ty.icon_position == pos }
      return nil unless type
      style == :Tera ? PokeAccess::I18n.t(:ss2_adv_tera, :t => type.name) : PokeAccess::I18n.t(:mv_type, :t => type.name)
    rescue StandardError
      nil
    end

    # The free map view's panel for the tile under the cursor, when the tile or its words change: name and
    # unvisited tint always, coordinates from medium (or when alone), description in full; the info key keeps all.
    def self.cursor(scene)
      PokeAccess::PaintCapture.arm(:ss2_adv_cursor)
      yield
    ensure
      rows = PokeAccess::PaintCapture.take_by_source(:ss2_adv_cursor) || {}
      tile = scene.instance_variable_get(:@cursor_tile)
      named = (rows[:positions] || []).map { |r| PokeAccess.clean(r.to_s) }
      unless named.empty?
        parts = [[named[0], named.length > 1 ? :medium : :brief]]
        named[1..-1].each { |n| parts.push([n, :brief]) }
        parts.push([PokeAccess::I18n.t(:ss2_adv_unvisited), :brief]) if (tile.color.alpha rescue 0).to_i > 0
        (rows[:dtex] || []).each { |d| parts.push([PokeAccess.clean(d.to_s), :full]) }
        t = PokeAccess::Verbosity.info_line(:map_square, parts)
        PokeAccess.speak(t, !@hold) if !t.empty? && PokeAccess::Cursor.changed?(scene, :ss2_adv_cursor, [(tile.coords rescue nil), t])
      end
    end

    # The lair's title card as the map opens (the adventure's and the lair's names), queued behind the counters.
    # param show pbMapIntro's own argument, false when the floor is entered without the card
    def self.title(scene, show)
      return if show == false || !(scene.ui_sprites["title"] rescue nil)
      a = PokeAccess.ivar(scene, :@adventure)
      names = [(GameData::RaidType.get(a.style).lair_name rescue nil), (a.map.name rescue nil)]
      t = names.compact.map { |n| PokeAccess.clean(n.to_s) }.reject { |n| n.empty? }.join(", ")
      PokeAccess.speak(t, false) unless t.empty?
    end

    # ---- the corner counters

    # The hearts -- how many knockouts the party can still take -- as the map draws them: on opening, and
    # whenever a battle or an event changes them. Queued behind whatever changed them.
    def self.hearts(scene)
      a = PokeAccess.ivar(scene, :@adventure)
      return unless a
      say_counter(scene, :ss2_adv_hearts, PokeAccess::I18n.t(:ss2_adv_hearts, :n => a.hearts, :max => a.max_hearts))
    rescue StandardError
      nil
    end

    # The key count, which the map shows only while there is one: said when it changes, including to none
    # (the icon going away), but not for the empty counter a lair starts with.
    def self.keys(scene)
      a = PokeAccess.ivar(scene, :@adventure)
      return unless a
      n = a.keys.to_i
      return if n == 0 && PokeAccess::Cursor.current(scene, :ss2_adv_keys).nil?
      say_counter(scene, :ss2_adv_keys, PokeAccess::I18n.t(:ss2_adv_keys, :n => n))
    rescue StandardError
      nil
    end

    # The Endless floor, as the window in the corner writes it.
    def self.floor(scene)
      f = PokeAccess.clean((scene.ui_sprites["floor"].text rescue "").to_s)
      say_counter(scene, :ss2_adv_floor, PokeAccess::I18n.t(:ss2_adv_floor, :f => f)) unless f.empty?
    rescue StandardError
      nil
    end

    def self.say_counter(scene, slot, text)
      PokeAccess.speak(text, false) if PokeAccess::Cursor.changed?(scene, slot, text)
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  after("AdventureMenuScene", :pbStartScene, :hook_container => true) { |s, _r, _a| PokeAccess::SS2Adventure.enter(s) }
  after("AdventureMenuScene", :pbEndScene, :hook_container => true) { |_s, _r, _a| PokeAccess::SS2Adventure.leave }
  before("AdventureMenuScene", :pbUpdate) { |_s, _a| PokeAccess::SS2Adventure.step }
  around("AdventureMenuScene", :pbExchangeMenu) { |_s, nxt, _a| PokeAccess::SS2Adventure.showing(:offer) { nxt.call } }
  around("AdventureMenuScene", :pbRecordMenu) { |_s, nxt, _a| PokeAccess::SS2Adventure.showing(:record) { nxt.call } }
  kernel("pbDrawImagePositions") { |args, _r| PokeAccess::SS2Adventure.note_buttons(args[0], args[1]) }
  kernel("pbDrawTextPositions") { |args, _r| PokeAccess::SS2Adventure.overlay_paint(args[0], args[1]) }
  info_window "AdventureMenuScene", "window", :ss2_adv_window, :optional => true, :reading => [:descriptions, :full]

  { "AdventurePartyDatabox" => :party_text, "AdventureRentalDatabox" => :rental_row,
    "AdventureRewardbox" => :reward_text, "AdventureItembox" => :item_text,
    "AdventureMovebox" => :move_text }.each do |cname, reader|
    around(cname, :selected=) do |box, nxt, args|
      adv = PokeAccess::SS2Adventure
      adv.say_box(adv.send(reader, box)) if adv.became_selected?(box, args[0]) { nxt.call }
    end
  end

  # The Dynamax menu walks its boxes by itself, one level-up after another, so those are queued.
  { "AdventureAttributebox" => false, "AdventureDynamaxbox" => true }.each do |cname, queued|
    around(cname, :selected=) do |box, nxt, args|
      PokeAccess::SS2Adventure.painted_box(box, args[0], queued) { nxt.call }
    end
  end

  after("AdventureItembox", :setItemValues) { |box, _r, _a| PokeAccess::SS2Adventure.refilled(box) }

  around("AdventureMapScene", :pbSelectRoute) { |s, nxt, _a| PokeAccess::SS2Adventure.routing(s) { nxt.call } }
  around("AdventureMapScene", :pbUpdateRouteArrows) do |s, nxt, args|
    PokeAccess::SS2Adventure.route_arrows(s, args[0], args[1]) { nxt.call }
  end
  around("AdventureMapScene", :pbUpdateControls) { |s, nxt, args| PokeAccess::SS2Adventure.controls(s, args[0]) { nxt.call } }
  around("AdventureMapScene", :pbUpdateCursor) { |s, nxt, _a| PokeAccess::SS2Adventure.cursor(s) { nxt.call } }
  before("AdventureMapScene", :pbUpdate) { |_s, _a| PokeAccess::SS2Adventure.step }
  before("AdventureMapScene", :pbMapIntro) { |s, args| PokeAccess::SS2Adventure.title(s, args[0]) }
  after("AdventureMapScene", :pbUpdateHearts) { |s, _r, _a| PokeAccess::SS2Adventure.hearts(s) }
  after("AdventureMapScene", :pbUpdateKeys) { |s, _r, _a| PokeAccess::SS2Adventure.keys(s) }
  after("AdventureMapScene", :pbUpdateFloor) { |s, _r, _a| PokeAccess::SS2Adventure.floor(s) }
  poll_each_frame { PokeAccess::SS2Adventure.poll_route }
end

PokeAccess::Verbosity.define_reading(:pokemon_choice, :vb_pokemon_choice, :vbh_pokemon_choice)
PokeAccess::Verbosity.define_reading(:map_square, :vb_map_square, :vbh_map_square)
