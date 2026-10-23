module PokeAccess
  # Locator part 1 of 3: identifying and naming map events (what a target is and what to call it). The
  # spoken name prefers a user tag, then resolves exits, trainers, pickup items, and people vs objects.
  module Locator
    # Hazard sprites a game registers (a puzzle beam/laser/spike): a matched event reads with its own
    # label, files under objects, and gets a "zap" cue. Each entry is [regexp on character_name, label key].
    HAZARDS = []

    # Registers a hazard sprite pattern and its spoken-name key.
    def self.register_hazard(re, label_key)
      HAZARDS.push([re, label_key])
    end

    # What profiles and plugins say of events, by kind, each rule as [value, block given the event]: :name, a name or
    # nil to leave it to the next (newest first, after the player's label and before the core's); :category, the
    # category (value) forced on the events the block accepts (the player's own still wins); :hidden, out of the
    # locator and the sonar; :mark, words said after the name in the target line.
    @rules = { :name => [], :category => [], :hidden => [], :mark => [] }

    # Registers a rule of kind (see @rules), with the category it forces for :category.
    def self.register_rule(kind, value = nil, &blk)
      @rules[kind].push([value, blk])
    end

    # The name the newest :name rule gives ev, or nil.
    def self.ruled_name(ev)
      @rules[:name].reverse_each do |_v, blk|
        n = (blk.call(ev) rescue nil)
        return n if n
      end
      nil
    end

    # The category the newest :category rule accepting ev forces, or nil.
    def self.ruled_category(ev)
      hit = @rules[:category].reverse.find { |_cat, blk| (blk.call(ev) rescue false) }
      hit && hit[0]
    end

    # True if the player hid ev (tag_hidden?) or a :hidden rule leaves it out.
    def self.hidden?(ev)
      tag_hidden?(ev) || @rules[:hidden].any? { |_v, blk| (blk.call(ev) rescue false) }
    end

    # The words said after a target's name: each :mark rule's, in the order they were registered, none twice.
    def self.name_marks(target)
      @rules[:mark].map { |_v, blk| (blk.call(target) rescue nil) }.compact.uniq
    end

    # The spoken-name key of the hazard an event is, or nil if it is not a registered hazard.
    def self.hazard_label(ev)
      return nil if HAZARDS.empty?
      cn = (ev.character_name.to_s rescue "")
      return nil if cn.empty?
      hit = HAZARDS.find { |re, _k| cn =~ re }
      hit ? hit[1] : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True if the event is a registered hazard.
    def self.hazard?(ev)
      !hazard_label(ev).nil?
    end

    # Field-move obstacles and pickups by event name, as the engine names them (cuttree when modern, the bare Tree on
    # gen-6): [regexp on event.name, key].
    FIELDMOVES = [[/cut[\s_]*tree|\Atree\z/i, :loc_cut_tree],
                  [/rock[\s_]*smash|smash[\s_]*rock|\Arock\z/i, :loc_rock_smash],
                  [/strength[\s_]*boulder|\Aboulder\z/i, :loc_strength_boulder],
                  [/headbutt[\s_]*tree/i, :loc_headbutt_tree],
                  [/hidden[\s_]*item/i, :loc_hidden_item], [/berry[\s_]*plant/i, :loc_berry_plant]]

    # The field-move labels that name their move: key => [the game's overworld function for the move, the neutral key
    # said in its place].
    MOVE_LABELS = { :loc_strength_boulder => [:pbStrength, :loc_big_rock],
                    :loc_headbutt_tree => [:pbHeadbutt, :loc_shakable_tree] }

    # The key a label is said by: one naming a move only where that move surely works the obstacle, under a game's own
    # profile (FieldMoves.named?) whose scripts define the move's overworld function; else its neutral one.
    def self.said_label(key)
      named = MOVE_LABELS[key]
      return key unless named
      fn = named[0]
      sure = PokeAccess::FieldMoves.named? && (Object.private_method_defined?(fn) || Kernel.respond_to?(fn))
      sure ? key : named[1]
    end

    # The field-move obstacle or pickup key for an event, by its name less the editor's "/noShadow/" flags, or nil;
    # never for one the engine left with no page (a felled tree, a smashed rock), nor for one that shows text unless
    # its live page clears it with a field move (a character named "Rock" matches the gen-6 bare names). A boulder
    # that rolls by itself when walked into needs no Strength: a pushable object (Routes::Effects.self_pushed?),
    # whatever it says on the way. An event with no name of its own ("EV012") is read by what its script clears it
    # with (Routes::Effects.scripted_gate_label).
    def self.fieldmove_label(ev)
      return nil if pageless?(ev)
      n = (ev.name.to_s rescue "").sub(/\/.*$/, "")
      return PokeAccess::Routes::Effects.scripted_gate_label(ev) if n.empty? || n =~ /\AEV\d+\z/i
      hit = FIELDMOVES.find { |re, _k| n =~ re }
      return :loc_pushable if hit && hit[1] == :loc_strength_boulder && PokeAccess::Routes::Effects.self_pushed?(ev)
      return nil if hit && (shows_text?(ev) rescue false) && PokeAccess::Routes::Effects.scripted_gate_label(ev).nil?
      hit ? hit[1] : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True for an event the engine left with no page: none of its pages' conditions hold, or it was erased. It shows
    # nothing and runs nothing.
    def self.pageless?(ev)
      return false unless PokeAccess.ivar(ev, :@page).nil?
      pages = (PokeAccess.ivar(ev, :@event).pages rescue nil)
      pages.is_a?(Array) && !pages.empty?
    end

    # Sprite-name patterns of a teleporter or warp pad (a profile may add its own). "hoopa" alone is the character and
    # "telepor" also names the NPC who teleports the player, so this list never decides person or object on its own.
    TELEPORTERS = [/ascensor|portal|telepor|warp|umbral|hoopa.?rings?|anillo.?hoopa|vortex/i]

    # Registers a teleporter sprite pattern (the profile DSL's teleporter).
    def self.register_teleporter(re); TELEPORTERS.push(re); end

    # True if an event is a teleporter / warp pad: its sprite reads as a warp and it transfers the player.
    def self.teleporter_event?(ev)
      cn = (ev.character_name.to_s rescue "")
      return false if cn.empty?
      return false unless TELEPORTERS.any? { |re| cn =~ re }
      !transfer_command_dest(ev).nil? || !transfer_script_dest(ev).nil?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Verdict cache of the page-scanning classifiers, keyed by [event id, identity of the live @list, kind]: a page
    # change swaps @list (and with it @trigger and the sprite). Cleared when an event ends and on a map change; values
    # are wrapped in an array so nil and false are hits.
    @verdicts = {}

    # The cached verdict for (event, kind), computing it from the block on the first miss.
    def self.verdict(ev, kind)
      key = [ev.id, (PokeAccess.ivar(ev, :@list).__id__ rescue 0), kind]
      hit = @verdicts[key]
      return hit[0] if hit
      v = yield
      @verdicts[key] = [v]
      v
    rescue StandardError => e
      PokeAccess.swallowed(e)
      yield
    end

    # Drops every cached verdict (event end, map change).
    def self.clear_verdicts
      @verdicts = {}
    end

    # All command lists of an event (its raw pages, plus the active page's live @list).
    def self.event_command_lists(ev)
      lists = []
      pages = (ev.instance_variable_get(:@event).pages rescue nil)
      (pages || []).each { |pg| l = (pg.list rescue nil); lists.push(l) if l.is_a?(Array) }
      live = PokeAccess.ivar(ev, :@list)
      lists.push(live) if live.is_a?(Array)
      lists
    end

    # Command lists to scan for a transfer: none for an event left with no page (pageless?); the active page's only
    # with transfer_active_page_only (an inactive cutscene page may warp), else, or without a live @list, every page.
    def self.transfer_command_lists(ev)
      return [] if pageless?(ev)
      if (PokeAccess::Config.transfer_active_page_only rescue true)
        live = PokeAccess.ivar(ev, :@list)
        return [live] if live.is_a?(Array)
      end
      event_command_lists(ev)
    end

    # Yields each script call of an event's command lists as one string (see script_calls); returns the first truthy
    # value the block gives, or nil.
    def self.script_call_find(ev, lists = nil)
      (lists || event_command_lists(ev)).each do |list|
        script_calls(list).each do |s|
          r = yield(s)
          return r if r
        end
      end
      nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The script calls of one command list: each 355 line with its 655 continuations joined by newlines, plus the
    # script a Conditional Branch tests (a v19+ item ball is if pbItemBall(:ITEM)).
    def self.script_calls(list)
      out = []
      list.each do |c|
        code = (c.code rescue 0)
        if code == CONDITION_CODE
          out.push((c.parameters[1] rescue "").to_s) if (c.parameters[0] rescue nil) == SCRIPT_CONDITION
          next
        end
        next unless SCRIPT_CODES.include?(code)
        text = (c.parameters[0] rescue "").to_s
        if code == 655 && !out.empty?
          out[-1] = out[-1] + "\n" + text
        else
          out.push(text)
        end
      end
      out
    end

    # Script calls that transfer the player, each capturing the destination map id; a game whose doors call its own
    # function registers it from its profile (register_transfer_script).
    TRANSFER_SCRIPTS = [/\bpbTransfer\w*\(\s*(\d+)/, /player_new_map_id\s*=\s*(\d+)/]

    # Registers an extra script-transfer pattern, which must capture the destination map id in its first group.
    def self.register_transfer_script(re); TRANSFER_SCRIPTS.push(re); end

    # The destination map id of a script transfer (TRANSFER_SCRIPTS), or nil.
    def self.transfer_script_dest(ev)
      verdict(ev, :tscript) { transfer_script_dest_uncached(ev) }
    end

    # The uncached script-transfer scan (see transfer_script_dest).
    def self.transfer_script_dest_uncached(ev)
      script_call_find(ev, transfer_command_lists(ev)) { |s| script_transfer_map(s) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The map id a script call transfers the player to, by a TRANSFER_SCRIPTS group that captured digits, or nil.
    def self.script_transfer_map(s)
      TRANSFER_SCRIPTS.each do |re|
        m = re.match(s.to_s)
        return m[1].to_i if m && m[1] && m[1].to_s =~ /\A\d+\z/
      end
      nil
    end

    # Where one script call transfers the player as [map, x, y]: coordinates from pbTransfer*(map, x, y) or
    # player_new_x/y, else nil x and y.
    def self.script_transfer_dest(s)
      map = script_transfer_map(s)
      return nil if map.nil?
      m = s.to_s.match(/\bpbTransfer\w*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
      return [map, m[2].to_i, m[3].to_i] if m && m[1].to_i == map
      x = s.to_s[/player_new_x\s*=\s*(\d+)/, 1]
      y = s.to_s[/player_new_y\s*=\s*(\d+)/, 1]
      (x && y) ? [map, x.to_i, y.to_i] : [map, nil, nil]
    end

    # The destination map id of an editor Transfer Player command (201), or nil (see transfer_command_dest_xy).
    def self.transfer_command_dest(ev)
      xy = transfer_command_dest_xy(ev)
      xy ? xy[0] : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The destination [map, x, y] of an editor Transfer Player command (201), or nil: literals for type 0, the
    # variables read live for type 1. The cache kind carries transfer_active_page_only.
    def self.transfer_command_dest_xy(ev)
      kind = (PokeAccess::Config.transfer_active_page_only rescue true) ? :txy_active : :txy_all
      verdict(ev, kind) { transfer_command_dest_xy_uncached(ev) }
    end

    # The uncached 201-command scan (see transfer_command_dest_xy): where the live page's walk transfers the player
    # (walked_transfer), else the first transfer listed.
    def self.transfer_command_dest_xy_uncached(ev)
      walked = walked_transfer(ev)
      return walked if walked
      transfer_command_lists(ev).each do |list|
        list.each do |c|
          next unless (c.code rescue 0) == TRANSFER_CODE
          pars = (c.parameters rescue nil)
          next unless pars
          if pars[0] == 1
            m = ($game_variables[pars[1]] rescue nil).to_i
            return [m, ($game_variables[pars[2]] rescue 0).to_i, ($game_variables[pars[3]] rescue 0).to_i] if m > 0
          elsif pars[1]
            return [pars[1], pars[2].to_i, pars[3].to_i]
          end
        end
      end
      nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The [map, x, y] the live page's walk (EventPages, its branches taken by live state) transfers the player to, when
    # every facing that transfers lands on the same map, or nil.
    def self.walked_transfer(ev)
      return nil unless PokeAccess.ivar(ev, :@list).is_a?(Array)
      found = [2, 4, 6, 8].map { |d| (o = PokeAccess::EventPages.outcome(ev, d)) && o.transfer }.compact
      found = found.select { |t| t[1].is_a?(Integer) && t[2].is_a?(Integer) }
      return nil if found.empty? || found.map { |t| t[0] }.uniq.length > 1
      found[0]
    end

    # True if an event shows text or choices when used (tells a sign from a door).
    def self.shows_text?(ev)
      verdict(ev, :text) { shows_text_uncached?(ev) }
    end

    # The uncached text scan (see shows_text?).
    def self.shows_text_uncached?(ev)
      event_command_lists(ev).any? do |list|
        list.any? { |c| TEXT_CODES.include?((c.code rescue 0)) }
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if an event is a sign: no sprite, examined with the action button, shows text and does not transfer; one
    # whose live page gives an item is that item until it is taken.
    def self.sign_event?(ev)
      verdict(ev, :sign) { sign_event_uncached?(ev) }
    end

    # The uncached sign test (see sign_event?).
    def self.sign_event_uncached?(ev)
      return false unless ev.character_name.to_s.empty?
      return false unless examinable?(ev)
      return false unless transfer_command_dest(ev).nil? && transfer_script_dest(ev).nil?
      return false if gives_item?(PokeAccess.ivar(ev, :@list))
      shows_text?(ev)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True when an event is a door or exit: by name, command 201 or a script transfer; never a sign or an autorun or
    # parallel event. An action-button transfer with any sprite but a doorway or a warp pad is a person, and so is a
    # touch one that transfer_person? takes for someone.
    def self.transfer_event?(ev)
      verdict(ev, :transfer) { transfer_event_uncached?(ev) }
    end

    # The uncached transfer test (see transfer_event?); the by-name rule needs no sprite or a doorway one, and some
    # command to run.
    def self.transfer_event_uncached?(ev)
      return false if sign_event?(ev)
      trig = PokeAccess.ivar_i(ev, :@trigger)
      return false if trig == 3 || trig == 4
      name = ev.name.to_s
      char = ev.character_name.to_s
      return true if "#{name} #{char}" =~ EXIT_NAME_RE && (char.empty? || doorway_sprite?(char)) && has_commands?(ev)
      return false unless !transfer_command_dest(ev).nil? || !transfer_script_dest(ev).nil?
      return true if char.empty? || doorway_sprite?(char) || teleporter_sprite?(char)
      (trig == 1 || trig == 2) && !transfer_person?(ev)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True for someone on a touch page who takes the player elsewhere: a sprite seen (sprite_seen?), neither a
    # doorway's nor a warp pad's, whose live page talks and transfers, the engine starting it by sight (event touch,
    # trigger 2) or the player walking into a character's sheet (CHARACTER_SHEET_RE); portals, holes and doors drawn
    # otherwise stay exits.
    def self.transfer_person?(ev)
      verdict(ev, :transfer_person) { transfer_person_uncached?(ev) }
    end

    # The uncached test (see transfer_person?).
    def self.transfer_person_uncached?(ev)
      trig = PokeAccess.ivar_i(ev, :@trigger)
      char = ev.character_name.to_s
      return false unless trig == 2 || (trig == 1 && char =~ CHARACTER_SHEET_RE)
      return false if char.empty? || doorway_sprite?(char) || teleporter_sprite?(char) || !live_talks?(ev)
      return false if transfer_command_dest(ev).nil? && transfer_script_dest(ev).nil?
      sprite_seen?(ev)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if the event is seen: drawn at some opacity, and the frame its sheet shows has a pixel (frame_drawn?, kept
    # per sheet and frame).
    def self.sprite_seen?(ev)
      return false if (ev.opacity rescue 255).to_i <= 0
      key = [ev.character_name.to_s, (ev.direction rescue 2).to_i, (ev.pattern rescue 0).to_i]
      @frames_drawn ||= {}
      @frames_drawn[key] = frame_drawn?(*key) unless @frames_drawn.key?(key)
      @frames_drawn[key]
    end

    # Whether a frame of a character sheet (its direction's row, its pattern's column) draws any pixel, as a sheet left
    # transparent to hide a walk-in trigger does not, read from its bottom row up, where a character stands; true where
    # the engine has no Bitmap to read it or the file fails, with mkxp-z's own errors too (engine_errors).
    def self.frame_drawn?(name, dir, pattern)
      return true unless defined?(::Bitmap) && ::Bitmap.method_defined?(:get_pixel)
      bmp = ::Bitmap.new("Graphics/Characters/#{name}")
      w = bmp.width / 4
      h = bmp.height / 4
      x0 = [[pattern, 0].max, 3].min * w
      y0 = [[(dir - 2) / 2, 0].max, 3].min * h
      (h - 1).downto(0) { |y| w.times { |x| return true if bmp.get_pixel(x0 + x, y0 + y).alpha > 0 } }
      false
    rescue StandardError, *engine_errors => e
      PokeAccess.swallowed(e)
      true
    ensure
      (bmp.dispose rescue nil) if bmp
    end

    # The error classes of mkxp-z's own that this engine defines (ENGINE_ERROR_NAMES: a sheet it cannot decode, a
    # bitmap too large to read), which derive from Exception, so a rescue of StandardError lets them through.
    def self.engine_errors
      ENGINE_ERROR_NAMES.select { |n| Object.const_defined?(n) }.map { |n| Object.const_get(n) }
    end

    # True if the event's active page runs anything besides empty rows and comments.
    def self.has_commands?(ev)
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| !NO_OP_CODES.include?((c.code rescue 0)) }
    end

    # Whether a sprite file is drawn as a doorway (EXIT_SPRITE_RE, matched as a substring).
    def self.doorway_sprite?(char)
      !char.empty? && char =~ EXIT_SPRITE_RE ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Whether a sprite file is drawn as a warp pad (TELEPORTERS). Consulted only once the event is known
    # to transfer: the vocabulary also names the NPC who teleports the player.
    def self.teleporter_sprite?(char)
      !char.empty? && TELEPORTERS.any? { |re| char =~ re }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Codes a push tile may carry besides its move route: empty, comments, move-command rows (509), play SE (250).
    PUSH_TRIVIAL = [0, 108, 408, 509, 250]
    # The Set Move Route command code.
    MOVEROUTE_CODE = 209

    # True if an event is a push or conveyor tile while its live page pushes (push_page?); the events with such a page
    # are kept per map.
    def self.push_tile?(ev)
      ($game_map && ($game_map.map_id rescue nil)) == @push_map or refresh_push_cache
      @push_ids.include?(ev.id) && push_page?(PokeAccess.ivar(ev, :@page))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Rebuilds the per-map set of push-tile event ids.
    def self.refresh_push_cache
      @push_map = ($game_map.map_id rescue nil)
      @push_ids = {}
      ($game_map.events.each_value { |ev| @push_ids[ev.id] = true if ev && push_tile_uncached?(ev) } rescue nil)
      true
    end

    # The uncached test for one event: whether any of its pages pushes (see push_tile?).
    def self.push_tile_uncached?(ev)
      (ev.instance_variable_get(:@event).pages rescue []).any? { |pg| push_page?(pg) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if an event page pushes the player: invisible, touch-triggered, its only real command a Set Move Route that
    # steps the player (-1).
    def self.push_page?(pg)
      return false unless pg && (pg.trigger == 1)
      return false unless (pg.graphic.character_name.to_s.empty? rescue false)
      list = (pg.list || [])
      sub = list.map { |c| (c.code rescue 0) }.reject { |cd| PUSH_TRIVIAL.include?(cd) }
      sub.uniq == [MOVEROUTE_CODE] && list.any? { |c| push_moveroute?(c) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The kind of each two-state toggle of the map @lever_map by event id (see toggle_kind), and its levers named as a
    # copy (see lever_copies).
    @toggles = {}
    @lever_copies = {}

    # True if an event is a lever (see toggle_kind).
    def self.lever?(ev)
      toggle_kind(ev) == :lever
    end

    # True if an event is a container: a two-state toggle whose first page gives an item (see toggle_kind).
    def self.container?(ev)
      toggle_kind(ev) == :container
    end

    # What a two-state toggle (toggle_shape?) is: :container, :lever or :rest, or nil for an event of another shape.
    # Cached per map.
    def self.toggle_kind(ev)
      ($game_map && ($game_map.map_id rescue nil)) == @lever_map or refresh_lever_cache
      @toggles[ev.id]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Rebuilds the per-map kinds of the two-state toggles and the levers named as a copy (see toggle_kind).
    def self.refresh_lever_cache
      @lever_map = ($game_map.map_id rescue nil)
      @toggles = {}
      evs = (($game_map.events.values rescue nil) || []).compact
      evs.each { |ev| k = toggle_kind_uncached(ev); @toggles[ev.id] = k if k }
      @lever_copies = lever_copies(evs.select { |ev| @toggles[ev.id] == :lever })
      true
    end

    # The uncached kind of one event (see toggle_kind): a toggle whose first page gives an item is a :container, one
    # its pages show worked by hand (lever_pages?) a :lever, any other the :rest.
    def self.toggle_kind_uncached(ev)
      return nil unless toggle_shape?(ev)
      p0, p1 = ev.instance_variable_get(:@event).pages
      return :container if gives_item?(p0.list)
      lever_pages?(ev, p0, p1) ? :lever : :rest
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True if an event has the two-state shape (a lever, a chest, a candle): two action-button pages with the same
    # sprite in a different pattern, the second gated by a switch or self switch, and no transfer or battle.
    def self.toggle_shape?(ev)
      pages = (ev.instance_variable_get(:@event).pages rescue nil)
      return false unless pages.is_a?(Array) && pages.length == 2
      p0, p1 = pages
      return false unless (p0.trigger == 0 rescue false) && (p1.trigger == 0 rescue false)
      g0 = (p0.graphic.character_name.to_s rescue ""); g1 = (p1.graphic.character_name.to_s rescue "")
      return false if g0.empty? || g0 != g1
      return false if (p0.graphic.pattern rescue -1) == (p1.graphic.pattern rescue -2)
      c1 = p1.condition
      return false unless (c1.switch1_valid rescue false) || (c1.self_switch_valid rescue false)
      return false if pages.any? { |pg| (pg.list || []).any? { |x| lever_disqualifier?(x) } }
      true
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # A command that rules out a toggle: a transfer or a battle script (a trainer's post-battle page looks like one).
    def self.lever_disqualifier?(c)
      code = (c.code rescue 0)
      return true if code == TRANSFER_CODE
      return false unless SCRIPT_CODES.include?(code)
      (c.parameters[0] rescue "").to_s =~ BATTLE_SCRIPT_RE ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Whether a toggle's pages say a lever: the first itself turns on what gates the second (turns_on_gate?), both draw
    # the same row, neither gives an item nor fights, the sheet is no doorway, and the sheet, the name or a text says
    # lever (LEVER_WORDS_RE).
    def self.lever_pages?(ev, p0, p1)
      return false unless turns_on_gate?(ev, p0.list, p1.condition)
      return false unless (p0.graphic.direction rescue 2) == (p1.graphic.direction rescue 2)
      return false if [p0, p1].any? { |pg| gives_item?(pg.list) || fights?(pg.list) }
      sheet = p0.graphic.character_name.to_s
      return false if doorway_sprite?(sheet)
      ([sheet, ev.name.to_s] + list_texts(p0.list) + list_texts(p1.list)).any? { |s| s =~ LEVER_WORDS_RE }
    end

    # Whether a command list turns on what a page condition gates: one of its switches set ON (switches_on) or its
    # self switch, set ON on the event itself (own_self_switches_on).
    def self.turns_on_gate?(ev, list, cond)
      gates = []
      gates.push(cond.switch1_id) if (cond.switch1_valid rescue false)
      gates.push(cond.switch2_id) if (cond.switch2_valid rescue false)
      return true unless (switches_on(list) & gates).empty?
      (cond.self_switch_valid rescue false) && own_self_switches_on(ev, list).include?(cond.self_switch_ch.to_s)
    end

    # The switch ids a command list sets ON: Control Switches (121) and $game_switches[N] = true in its scripts.
    def self.switches_on(list)
      ids = []
      (list || []).each do |c|
        next unless (c.code rescue 0) == SWITCH_CODE && (c.parameters[2] rescue nil) == 0
        ids.concat((c.parameters[0]..c.parameters[1]).to_a)
      end
      script_calls(list || []).each { |s| s.scan(SWITCH_ON_SCRIPT_RE) { ids.push($1.to_i) } }
      ids
    end

    # The self-switch letters a command list sets ON on its own event: Control Self Switch (123), and a script's
    # pbSetSelfSwitch on the event by its id or as itself (SELF_SWITCH_SCRIPT_RE).
    def self.own_self_switches_on(ev, list)
      out = []
      (list || []).each do |c|
        out.push(c.parameters[0].to_s) if (c.code rescue 0) == SELF_SWITCH_CODE && (c.parameters[1] rescue nil) == 0
      end
      script_calls(list || []).each do |s|
        s.scan(SELF_SWITCH_SCRIPT_RE) do
          who, ch, on = $1, $2, $3
          out.push(ch) if on == "true" && (who !~ /\A\d+\z/ || who.to_i == ev.id)
        end
      end
      out
    end

    # Whether a command list gives an item: a Change Items (126) that adds one, not one that takes it away, or a script
    # that hands one over (ITEM_GIFT_RE), a Conditional Branch's included.
    def self.gives_item?(list)
      return false unless list.is_a?(Array)
      return true if list.any? { |c| (c.code rescue 0) == ITEMS_CODE && (c.parameters[1] rescue nil) == 0 }
      script_calls(list).any? { |s| s =~ ITEM_GIFT_RE }
    end

    # Whether a command list starts a battle from a script, a Conditional Branch's included.
    def self.fights?(list)
      list.is_a?(Array) && script_calls(list).any? { |s| s =~ BATTLE_SCRIPT_RE }
    end

    # The words a command list shows: each Show Text and its lines (101, 401) and each option of Show Choices (102).
    def self.list_texts(list)
      out = []
      (list || []).each do |c|
        code = (c.code rescue 0)
        out.push((c.parameters[0] rescue "").to_s) if MESSAGE_CODES.include?(code)
        out.concat(((c.parameters[0] rescue nil) || []).map { |x| x.to_s }) if code == CHOICES_CODE
      end
      out
    end

    # The levers of a map whose name is a copy, as { id => true }: one name on several of them that set other switches
    # or draw another row (lever_signature), so it tells none apart.
    def self.lever_copies(levers)
      out = {}
      levers.group_by { |ev| own_name(ev) }.each_value do |same|
        next if same.map { |ev| lever_signature(ev) }.uniq.length < 2
        same.each { |ev| out[ev.id] = true }
      end
      out
    end

    # How a lever is drawn and what it works: its sheet, its row and the switches its first page sets ON.
    def self.lever_signature(ev)
      p0 = ev.instance_variable_get(:@event).pages[0]
      [p0.graphic.character_name.to_s, (p0.graphic.direction rescue 2), switches_on(p0.list).uniq.sort]
    end

    # A lever's line from its own name n (own_name): the name, unless a placeholder (placeholder_name?) or a copy
    # (lever_copies), else the word for a lever; then whether it is pulled (lever_state_suffix).
    def self.lever_name(ev, n)
      named = !placeholder_name?(n) && !@lever_copies[ev.id]
      (named ? n : PokeAccess::I18n.t(:loc_lever)) + lever_state_suffix(ev)
    end

    # A container's line from its own name n: the name, unless a placeholder; else the word for a chest when its sheet
    # or name says one (CHEST_WORDS_RE); else the item its live page hands over (item_name), or the word for an object.
    # Then closed or open (container_open?), an object's in the words that agree with it.
    def self.container_name(ev, n)
      open = container_open?(ev)
      state = PokeAccess::I18n.t(open ? :loc_container_open : :loc_container_closed)
      return "#{n}, #{state}" unless placeholder_name?(n)
      sheet = (ev.instance_variable_get(:@event).pages[0].graphic.character_name.to_s rescue "")
      return "#{PokeAccess::I18n.t(:loc_chest)}, #{state}" if [sheet, ev.name.to_s].any? { |s| s =~ CHEST_WORDS_RE }
      it = item_name(ev)
      state = PokeAccess::I18n.t(open ? :loc_object_open : :loc_object_closed)
      "#{it ? PokeAccess::I18n.t(:loc_object_named, :name => it) : PokeAccess::I18n.t(:loc_object)}, #{state}"
    end

    # True once a container shows another page than its first: it was opened.
    def self.container_open?(ev)
      pages = (ev.instance_variable_get(:@event).pages rescue nil)
      active = PokeAccess.ivar(ev, :@page)
      !active.nil? && pages.is_a?(Array) && !active.equal?(pages[0])
    end

    # Whether a toggle that is no lever nor container reads as a person: a character's sheet (CHARACTER_SHEET_RE), or
    # it faces another way on each page and talks on its first.
    def self.toggle_person?(ev)
      p0, p1 = ev.instance_variable_get(:@event).pages
      return true if p0.graphic.character_name.to_s =~ CHARACTER_SHEET_RE
      (p0.graphic.direction rescue 2) != (p1.graphic.direction rescue 2) && !list_texts(p0.list).empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      true
    end

    # The spoken state of a toggle: on when its live page (@page) is drawn in another pattern than its first page.
    def self.lever_state_suffix(ev)
      pages = (ev.instance_variable_get(:@event).pages rescue nil)
      active = PokeAccess.ivar(ev, :@page)
      return "" unless pages.is_a?(Array) && active
      base_pat = (pages[0].graphic.pattern rescue nil)
      cur_pat = (active.graphic.pattern rescue nil)
      moved = (cur_pat != base_pat)
      ", " + PokeAccess::I18n.t(moved ? :loc_lever_on : :loc_lever_off)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end

    # True if a command is a Set Move Route on the player (-1) that includes a step (move codes 1..4).
    def self.push_moveroute?(c)
      return false unless (c.code rescue 0) == MOVEROUTE_CODE
      pars = (c.parameters rescue [])
      return false unless pars[0] == -1
      mr = pars[1]
      moves = (mr.list.map { |m| (m.code rescue 0) } rescue [])
      moves.any? { |cd| cd >= 1 && cd <= 4 }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if an event belongs to the Eye/Lens of Truth plugin, whose events carry "#EOT" in their name.
    def self.lens_tile?(ev)
      (ev.name.to_s rescue "") =~ /#EOT/ ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The destination map name of a transfer event (command or script), or nil.
    def self.transfer_dest_name(ev)
      d = transfer_command_dest(ev) || transfer_script_dest(ev)
      d ? map_name(d) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A cardinal key (:dir_n .. :dir_so) for (x, y) from the current map's centre, or nil near it; an axis counts
    # beyond an eighth of the map (at least 2 tiles).
    def self.cardinal_of(x, y)
      return nil unless $game_map && x && y
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      return nil if w <= 0 || h <= 0
      dx = x - w / 2; dy = y - h / 2
      tx = [w / 8, 2].max; ty = [h / 8, 2].max
      ew = dx >= tx ? "e" : (dx <= -tx ? "o" : "")
      ns = dy >= ty ? "s" : (dy <= -ty ? "n" : "")
      key = "#{ns}#{ew}"
      return nil if key.empty?
      "dir_#{key}".to_sym
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The name of a warp within the current map: "passage to the <dir>" with a known destination, else "passage".
    def self.passage_name(ev)
      xy = (transfer_command_dest_xy(ev) rescue nil)
      dir = (xy ? cardinal_of(xy[1], xy[2]) : nil)
      return PokeAccess::I18n.t(:loc_passage_dir, :dir => PokeAccess::I18n.t(dir)) if dir
      PokeAccess::I18n.t(:loc_passage)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      PokeAccess::I18n.t(:loc_passage)
    end

    # A map's name: the player's rename, else the game's own (game_map_name), else the MapInfos one (loaded once,
    # failure cached too), cleaned for speech.
    def self.map_name(mapid)
      ov = (PokeAccess::MapNames.get(mapid) rescue nil)
      return ov if ov && !ov.to_s.empty?
      game = game_map_name(mapid)
      return game if game
      if @mapinfos.nil?
        @mapinfos = load_mapinfos
        if @mapinfos.nil?
          PokeAccess.log_once("mapinfos", "Data/MapInfos no cargable")
          @mapinfos = {}
        end
      end
      return nil unless @mapinfos && @mapinfos[mapid]
      nm = (@mapinfos[mapid].name rescue nil)
      nm.nil? ? nil : PokeAccess.clean(nm)
    end

    # The name the game gives a map from v19 where it says one (pbGetMapNameFromId, which its load screen and Escape
    # Rope use: the metadata's name from v21, the translation in the language chosen), cleaned and kept per map id
    # until the next map change; nil where it gives none, and on gen-6, whose function reads MapInfos as map_name does.
    def self.game_map_name(mapid)
      return nil if PokeAccess::Engine.gen6? || !respond_to?(:pbGetMapNameFromId, true)
      @game_names ||= {}
      return @game_names[mapid][0] if @game_names.key?(mapid)
      nm = (pbGetMapNameFromId(mapid) rescue nil).to_s
      @game_names[mapid] = [nm.strip.empty? ? nil : PokeAccess.clean(nm)]
      @game_names[mapid][0]
    end

    # MapInfos (id => RPG::MapInfo) through the engine's loader: those an engine's data provider keeps loaded,
    # pbLoadMapInfos from v19, pbLoadRxData on gen-6.
    def self.load_mapinfos
      kept = PokeAccess::Data.optional(:map_infos)
      return kept if kept
      return (pbLoadMapInfos rescue nil) if respond_to?(:pbLoadMapInfos, true)
      (pbLoadRxData("Data/MapInfos") rescue nil)
    end

    # An event's name as said: less the editor's flags after a slash and its notes (EDITOR_NOTE_RE), a trainer's sight
    # range and doubled spaces.
    def self.own_name(ev)
      ev.name.to_s.sub(/\/.*$/, "").gsub(EDITOR_NOTE_RE, " ").gsub(TRAINER_RANGE_RE, '\1').strip.gsub(/\s{2,}/, " ")
    end

    # True for a name a mapper leaves as none: empty, the editor's EV### or punctuation alone (a profile may add its
    # own).
    def self.placeholder_name?(name)
      n = name.to_s
      n.empty? || n =~ /\AEV\d+/i || n =~ SYMBOL_NAME_RE ? true : false
    end

    # Builds the spoken name for an event: a user tag wins, then a profile's or plugin's (ruled_name), then its own
    # (event_name), with where it takes the player for someone who does (transfer_person?); a synthetic target is
    # named as synthetic_name says.
    def self.target_name(ev)
      return synthetic_name(ev) if ev.is_a?(SurfaceTarget)
      tag = (PokeAccess::Tags.get($game_map.map_id, ev.id) rescue nil)
      return tag if tag && !tag.to_s.empty?
      ruled = ruled_name(ev)
      return ruled if ruled
      name = event_name(ev)
      transfer_person?(ev) ? taken_to(ev, name) : name
    end

    # A name and where its event takes the player ("<name>, leads to <map>"), toward a map named like this one what it
    # leads to (same_place_taken); the name alone toward a map with no name or the one the player is on.
    def self.taken_to(ev, name)
      dmap = (transfer_command_dest(ev) || transfer_script_dest(ev) rescue nil)
      return name if dmap.nil? || dmap == ($game_map.map_id rescue nil)
      d = transfer_dest_name(ev)
      return name if d.nil? || d.to_s.empty?
      "#{name}, #{same_place?(d) ? same_place_taken(dmap, d) : PokeAccess::I18n.t(:loc_takes_to, :map => d)}"
    end

    # The name an event's own data gives it: the one the map's mechanic declares for a wall (Puzzles.wall_name), a
    # wild Pokemon's, a hazard's or obstacle's, its editor name, a trainer's, a door's by where it leads, a lever's or
    # container's, a sign's, an item's, else its sprite's.
    def self.event_name(ev)
      wall = PokeAccess::Puzzles.wall_name(ev)
      return wall if wall
      w = wild_pokemon_name(ev)
      return w if w
      hz = hazard_label(ev)
      return PokeAccess::I18n.t(hz) if hz
      return PokeAccess::I18n.t(:loc_lens) if lens_tile?(ev)
      fm = fieldmove_label(ev)
      return PokeAccess::I18n.t(fm) + PokeAccess::Berry.state_suffix(ev) if fm == :loc_berry_plant
      return PokeAccess::I18n.t(said_label(fm)) if fm
      n = own_name(ev)
      n = "" if n =~ SYMBOL_NAME_RE || (n =~ ITEM_BALL_NAME_RE && item_ball?(ev))
      return trainer_name(ev) if n =~ /\ATrainer\z/i
      return PokeAccess::I18n.t(:loc_pc) if pc_event?(ev)
      if transfer_event?(ev)
        dmap = (transfer_command_dest(ev) || transfer_script_dest(ev) rescue nil)
        return passage_name(ev) if dmap && dmap == ($game_map.map_id rescue nil)
        d = transfer_dest_name(ev)
        return same_place_name(dmap, d) if d && same_place?(d)
        return PokeAccess::I18n.t(entrance?(dmap) ? :loc_entrance_to : :loc_exit_to, :map => d) if d
        return n unless n.empty? || n =~ EXIT_NAME_RE || n =~ /^EV\d+$/i
        return PokeAccess::I18n.t(:loc_exit)
      end
      kind = toggle_kind(ev)
      return lever_name(ev, n) if kind == :lever
      return container_name(ev, n) if kind == :container
      return n unless placeholder_name?(n) || n =~ /\Asize\(/i
      return sign_name(ev) if sign_event?(ev)
      g = ev.character_name.to_s
      if (PokeAccess::Config.name_items rescue true) && (g.empty? || !live_talks?(ev))
        it = item_name(ev)
        return PokeAccess::I18n.t(:loc_object_named, :name => it) if it
      end
      sp = sprite_species(g) || ((PokeAccess::Config.name_species rescue true) ? sprite_species_named(g) : nil)
      return sp if sp
      return PokeAccess::I18n.t(:loc_shopkeeper) if shop_event?(ev)
      return PokeAccess::I18n.t(:loc_object) if g.empty? || g =~ /^\d+$/ || g =~ OBJECT_SPRITE_RE || item_ball?(ev)
      sprite_trainer_class(g) || g
    end

    # True if the event's live page shows text or choices: a person who talks, not an item ball's own message.
    def self.live_talks?(ev)
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| TEXT_CODES.include?((c.code rescue 0)) }
    end

    # True when a door leads from outdoors into an interior: going in there is an entrance.
    def self.entrance?(dmap)
      here = ($game_map.map_id rescue nil)
      return false if dmap.nil? || here.nil?
      PokeAccess::MapMeta.outdoor?(here) == true && PokeAccess::MapMeta.outdoor?(dmap) == false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True when a door's destination bears the name of the map the player is on, so the name tells nothing.
    def self.same_place?(dname)
      dname.to_s.strip.downcase == map_name(($game_map.map_id rescue nil)).to_s.strip.downcase
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # What a door to a place named like this one leads to: from outdoors into an interior, the building --
    # a Pokemon Centre when the map is one -- and anywhere else another part of the same place.
    def self.same_place_name(dmap, dname)
      return PokeAccess::I18n.t(:loc_area_other, :map => dname) unless entrance?(dmap)
      PokeAccess::I18n.t(PokeAccess::MapMeta.pokecenter?(dmap) ? :loc_pokecenter : :loc_building)
    end

    # Where someone takes the player to a place named like this one, by the rule same_place_name names a door's.
    def self.same_place_taken(dmap, dname)
      return PokeAccess::I18n.t(:loc_takes_to_area_other, :map => dname) unless entrance?(dmap)
      PokeAccess::I18n.t(PokeAccess::MapMeta.pokecenter?(dmap) ? :loc_takes_to_pokecenter : :loc_takes_to_building)
    end

    # Script calls that open a shop: every mart the engine or a game defines (pbPokemonMart and its variants, the
    # battle-point and secret-base shops, a clothes or hat shop), never pbStoreItem, which is an item on the floor.
    SHOP_CALL = /\b(?:pb\w*Mart\w*|\w*[Ss]hop|tm_mart|enter_pokemart)\s*\(/

    # True if the event opens a shop: an unnamed shop attendant is called one, not by its sprite's file name.
    def self.shop_event?(ev)
      !!script_call_find(ev) { |s| s =~ SHOP_CALL }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The species an overworld sprite named by national number shows ("025", "025s" shiny), or nil; only where
    # species are keyed by number (gen-6, Infinite Fusion).
    def self.sprite_species(g)
      return nil unless g.to_s =~ /\A(\d{3})s?\z/
      n = $1.to_i
      return nil if n <= 0
      return nil unless PokeAccess::Engine.gen6? || (::GameData::Species::DATA.key?(n) rescue false)
      nm = (PokeAccess::Data.species_name(n) rescue nil)
      (nm && !nm.to_s.strip.empty?) ? nm.to_s : nil
    end

    # The trainer class a trainer charset is named after: trchar065 or trcharHIKER on gen-6, trainer_AQUAGRUNT_M from
    # v19, dropping trailing _parts until a class matches (trainer_TECHWIZARD_Caitlin); else nil.
    def self.sprite_trainer_class(g)
      return trainer_class_name($1.to_i) if g.to_s =~ /\Atrchar(\d+)\z/i
      return nil unless g.to_s =~ /\A(?:trchar|trainer_)([A-Za-z]\w*)\z/
      key = $1
      loop do
        nm = trainer_class_name(key)
        return nm if nm
        return nil unless key =~ /_[^_]*\z/
        key = key.sub(/_[^_]*\z/, "")
      end
    end

    # A trainer class's name from the game's data, or nil when it has none to give.
    def self.trainer_class_name(id)
      nm = PokeAccess::Data.trainer_type_name(id)
      (nm && !nm.to_s.strip.empty?) ? nm.to_s : nil
    end

    # A trainer battle's call in a script ("pbTrainerBattle(:HIKER", "TrainerBattle.start(PBTrainers::HIKER"), the
    # class it fights as captured.
    BATTLE_CALL_RE = /\b(?:pb\w*TrainerBattle\w*|TrainerBattle\.start\w*)\s*\(\s*(?:PBTrainers::|:)([A-Z]\w*)/

    # What a trainer named for its sight alone ("Trainer(3)") is called: with name_trainers, its class as the game
    # names it, the one its battle call fights as, else its sprite's, and beaten once trainer_beaten?; else a trainer.
    def self.trainer_name(ev)
      return PokeAccess::I18n.t(:loc_trainer) unless (PokeAccess::Config.name_trainers rescue true)
      nm = battle_class(ev) || sprite_trainer_class(ev.character_name.to_s) || PokeAccess::I18n.t(:loc_trainer)
      trainer_beaten?(ev) ? PokeAccess::I18n.t(:loc_trainer_beaten, :name => nm) : nm
    end

    # The game's name for the class the first battle call among an event's pages fights as, or nil.
    def self.battle_class(ev)
      script_call_find(ev) do |s|
        key = s =~ BATTLE_CALL_RE ? $1 : nil
        key && trainer_class_name(key)
      end
    end

    # True once a trainer's live page is the one its battle leaves: a page on a self switch with no battle call, while
    # another of its pages holds one.
    def self.trainer_beaten?(ev)
      cond = (PokeAccess.ivar(ev, :@page).condition rescue nil)
      return false unless cond && (cond.self_switch_valid rescue false)
      live = PokeAccess.ivar(ev, :@list)
      return false unless live.is_a?(Array)
      return false if script_call_find(ev, [live]) { |s| s =~ BATTLE_CALL_RE }
      !!script_call_find(ev) { |s| s =~ BATTLE_CALL_RE }
    end

    # The species constants an overworld sprite may be named after, the most specific first: its name less a folder
    # and a " (2)" copy mark, past a pkmn_, poke_ or POKEMON_ prefix or all in capitals ("pkmn_growlithe",
    # "GEODUDE_1"), then less each trailing _part (a form, a gender), each also without a number or "shiny" stuck to
    # its end ("pkmn_lapras3"); none for any other sprite.
    def self.species_constants(g)
      base = g.to_s.sub(/\A.*\//, "").sub(/\s*\(\d+\)\z/, "")
      key = if base =~ /\A(?:pkmn|poke|pokemon)_(\w+)\z/i then $1.upcase
            elsif base =~ /\A[A-Z][A-Z0-9_]*\z/ then base
            end
      out = []
      while key && key =~ /\A[A-Z]\w*\z/
        bare = key.sub(/(?:_?SHINY|\d+)\z/, "")
        out.push(key)
        out.push(bare) if bare != key && bare =~ /\A[A-Z]\w*[A-Z]\z/
        key = key =~ /_[^_]*\z/ ? key.sub(/_[^_]*\z/, "") : nil
      end
      out.uniq
    end

    # The species an overworld sprite named after its species' constant shows (species_constants), as the game
    # spells it, or nil.
    def self.sprite_species_named(g)
      species_constants(g).each do |c|
        key = species_key(c)
        next if key.nil?
        nm = PokeAccess::Data.species_name(key)
        return nm.to_s if nm && !nm.to_s.strip.empty?
      end
      nil
    end

    # The species a constant names as the game's data takes it, or nil when the game has none by that name: its
    # symbol from v19 (GameData::Species) and where the data provider keeps the species table (species_known?), its
    # number on gen-6 (PBSpecies's own constant, never one it would find on Object).
    def self.species_key(name)
      sym = name.to_sym
      if PokeAccess::Engine.gamedata?
        sp = ::GameData::Species
        return (sp.respond_to?(:try_get) ? sp.try_get(sym) : sp.exists?(sym)) ? sym : nil
      end
      return sym if PokeAccess::Data.optional(:species_known?, sym)
      return nil unless defined?(::PBSpecies) && own_const?(::PBSpecies, name)
      n = ::PBSpecies.const_get(name)
      n.is_a?(Integer) && n > 0 ? n : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether mod itself holds the constant name: const_defined? with inheritance off, as Ruby 1.8.7's one-argument
    # form always is.
    def self.own_const?(mod, name)
      mod.method(:const_defined?).arity == 1 ? mod.const_defined?(name) : mod.const_defined?(name, false)
    end

    # What a sign is by the words its text opens with (the first SIGN_REACH characters), in the game's own language:
    # [regexp, key], the first match winning. Accented letters stay out of character classes and away from \b, as
    # Ruby 1.8 matches bytes.
    SIGN_KINDS = [
      [/\A\W*(?:(?:it|this|that)(?:'s| is) |(?:the|this|that) (?:door|gate)(?:'s| is) )?(?:still )?locked\b/i, :loc_sign_locked],
      [/\b(?:door|gate)\b[^.!?]{0,40}\blocked\b|\bpuerta\b[^.!?]{0,40}\bcerrad|\bcerrad(?:o|a) con llave/i, :loc_sign_locked],
      [/\A\W*(?:est(?:á|a) )?cerrad(?:o|a)\b|\bporte\b[^.!?]{0,40}\b(?:ferm|verrouill)|verrouill(?:é|e)/i, :loc_sign_locked],
      [/ferm(?:é|e)e? (?:à|a) cl(?:é|e)/i, :loc_sign_locked],
      [/\b(?:basura|papeleras?|trash|garbage|rubbish|wastebaskets?|poubelles?|ordures)\b/i, :loc_sign_bin],
      [/\b(?:estanter(?:í|i)as?|libros|bookshel(?:f|ves)|bookcases?|shel(?:f|ves)|books|livres)\b/i, :loc_sign_shelf],
      [/(?:é|e)tag(?:è|e)res?(?![a-z])|biblioth(?:è|e)ques?(?![a-z])/i, :loc_sign_shelf],
      [/\b(?:computer|ordenador|computadora|ordinateur|pc)s?\b/i, :loc_sign_computer],
      [/\b(?:tv|televisor|television)\b|\btelevisi(?:ó|o)n|\bt(?:é|e)l(?:é|e)(?:viseur)?(?![a-z])/i, :loc_sign_tv],
      [/\b(?:ventanas?|windows?)\b|fen(?:ê|e)tres?(?![a-z])/i, :loc_sign_window]
    ]
    SIGN_REACH = 70
    # A text that opens in quotes (something written: a plaque, a poster) or with a speaker's name ("MELIA:"), which
    # is no description of the thing.
    NOT_DESCRIBED_RE = /\A(?:"|'|«|“|[A-Z][A-Z .'-]*:)/

    # What an invisible event with text is called: with name_signs, the kind its live page's text tells
    # (sign_kind_of), else a sign.
    def self.sign_name(ev)
      kind = (PokeAccess::Config.name_signs rescue true) ? sign_kind_of(live_text(ev)) : nil
      PokeAccess::I18n.t(kind || :loc_sign)
    end

    # The text the live page shows, its lines joined.
    def self.live_text(ev)
      list = PokeAccess.ivar(ev, :@list)
      return "" unless list.is_a?(Array)
      list.select { |c| MESSAGE_CODES.include?((c.code rescue 0)) }.map { |c| (c.parameters[0] rescue "").to_s }.join(" ")
    end

    # The kind of thing a sign's text tells it is (SIGN_KINDS over its opening, the game's text codes taken out), or
    # nil, as for a text that describes nothing (NOT_DESCRIBED_RE).
    def self.sign_kind_of(text)
      head = text.to_s.gsub(/\\[A-Za-z]+\[[^\]]*\]|\\[A-Za-z]+|<[^>]*>/, " ").strip[0, SIGN_REACH]
      return nil if head =~ NOT_DESCRIBED_RE
      hit = SIGN_KINDS.find { |re, _k| head =~ re }
      hit && hit[1]
    end

    # "Wild <species>" for a visible overworld encounter (the VOE plugin's Game_PokeEvent), with the shiny word
    # (Party.shiny_word) for a shiny one, which its sprite shows; else nil.
    def self.wild_pokemon_name(ev)
      return nil unless defined?(Game_PokeEvent) && ev.is_a?(Game_PokeEvent)
      pk = (ev.pokemon rescue nil)
      return nil unless pk
      nm = (pk.name rescue nil); nm = (pk.speciesName rescue nil) if nm.nil? || nm.to_s.empty?
      return nil if nm.nil? || nm.to_s.empty?
      wild = PokeAccess::I18n.t(:loc_wild, :name => nm)
      PokeAccess::Party.shiny?(pk) ? "#{wild}, #{PokeAccess::Party.shiny_word(pk)}" : wild
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The name of the item a pickup event's live page gives (PICKUP_ID_RE, or ITEM_GIFT_ID_RE with no sprite), or nil;
    # its id looked up as the game writes it, then upper-cased.
    def self.item_name(ev)
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      re = ev.character_name.to_s.empty? ? ITEM_GIFT_ID_RE : PICKUP_ID_RE
      script_calls(list).each do |s|
        next unless s =~ re
        sym = $1
        nm = [sym, sym.upcase].uniq.map { |k| (PokeAccess::Data.item_id(k)[1] rescue nil) }.find { |x| x && !x.to_s.empty? }
        return nm if nm
        return PokeAccess::Util.capitalized(sym)
      end
      nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True if the event's live page hands over an item ball (pbItemBall, pbEventItem) with no word of its own first,
    # whatever its sprite; not pbReceiveItem, nor a person who talks and then hands one over with pbItemBall.
    def self.item_ball?(ev)
      verdict(ev, :item_ball) { item_ball_uncached?(ev) }
    end

    # The uncached item ball test (see item_ball?).
    def self.item_ball_uncached?(ev)
      list = PokeAccess.ivar(ev, :@list)
      return false unless list.is_a?(Array) && !live_talks?(ev)
      !!script_call_find(ev, [list]) { |s| s =~ /pbItemBall|pbEventItem/ }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Classifies a graphic event: the category a profile or plugin forces (ruled_category); else a hazard, an item
    # ball, a field-move obstacle or pickup (fieldmove_label), a lever or a container is :objects, someone who takes
    # the player elsewhere (transfer_person?) :people, and by its sprite a tile, a numbered, object (OBJECT_SPRITE_RE)
    # or doorway one is :objects and a named person :people, but for any other toggle that does not read as a person
    # (toggle_person?).
    def self.event_category(ev)
      ruled = ruled_category(ev)
      return ruled if ruled
      kind = toggle_kind(ev)
      return :objects if hazard?(ev) || item_ball?(ev) || fieldmove_label(ev) || kind == :lever || kind == :container
      return :people if transfer_person?(ev)
      g = (ev.character_name.to_s rescue "")
      return :objects if g.empty? || g =~ /^\d+$/ || g =~ OBJECT_SPRITE_RE || doorway_sprite?(g)
      kind == :rest && !toggle_person?(ev) ? :objects : :people
    end

    # True if the event shows a character sprite or a map tile (a placed object).
    def self.has_graphic?(ev)
      return true unless ev.character_name.to_s.empty?
      (ev.tile_id rescue 0).to_i > 0
    end

    # True if an event runs the Essentials PC script.
    def self.pc_event?(ev)
      !!script_call_find(ev) { |s| s =~ /pbPokeCenterPC|pbPokemonPC|pbTrainerPC|PokemonPC/ }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if an event is a service desk used across a counter (nurse, PC, mart clerk), by sprite or script; it stays
    # audible through the line-of-sight cut.
    def self.service_desk?(ev)
      cn = (ev.character_name.to_s rescue "")
      return true if cn =~ /enfermera|nurse/i
      !!script_call_find(ev) do |s|
        s =~ /pbSetPokemonCenter|pbHealAll|pbNurseHeal|pbHealParty|pbPokeCenterPC|pbPokemonPC|pbTrainerPC|PokemonPC|pbPokemonMart/
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Essentials event-command codes for an inline script call (355) and its continuation line (655).
    SCRIPT_CODES = [355, 655]
    # RPG Maker XP's Conditional Branch command (111), and its condition type 12, which tests a Ruby script.
    CONDITION_CODE = 111
    SCRIPT_CONDITION = 12
    # RPG Maker XP event-command code for a Transfer Player command (a door/warp).
    TRANSFER_CODE = 201
    # RPG Maker XP event-command codes for Show Text (101) and Show Choices (102).
    TEXT_CODES = [101, 102]
    # RPG Maker XP event-command codes for Show Text (101) and the lines it goes on with (401).
    MESSAGE_CODES = [101, 401]
    # Commands that do nothing when run: the list terminator and comments.
    NO_OP_CODES = [0, 108, 408]
    # RPG Maker XP event-command codes of a hidden item or reward event: Change Gold (125), Items (126), Weapons
    # (127), Armor (128) and Call Common Event (117).
    GOODS_CODES = [125, 126, 127, 128, 117]
    # Door words in an event's name or sprite, bounded: as substrings they match "outdoor" or "puertaventana".
    EXIT_NAME_RE = /\b(door|puerta|salida|exit)\b/i
    # The doorway vocabulary of sprite file names, unbounded (doors3, FlechaSalida); never applied to event names.
    # "salidas" is refused, as "crisalidas" carries it.
    EXIT_SPRITE_RE = /door|puerta|salida(?!s)|exit|flecha|arrow|stair|escalera|ladder|entrada|entrance/i

    # Editor annotations stuck to an event name, stripped before speaking it: size(3,1) for a multi-tile object, .sl
    # and forced_z=N for its drawing layer, .shadowless and .noshadow for its shadow, and the notes the engines read
    # there: counter(N) and sight(N) for how far an event is talked to or sees, bush_depth(N) and glowsize(N) for how it
    # is drawn.
    EDITOR_NOTE_RE = /\s*(?:size\s*\(\s*\d+\s*,\s*\d+\s*\)|\.(?:sl|shadowless|noshadow)\b|\bforced_z\s*=\s*-?\d+|
                         \b(?:counter|sight|bush_depth|glowsize)\s*\(\s*\d+\s*\))/ix
    # A trainer's sight range in its name ("Cultist Trainer(3)"), where the word stays and the number goes.
    TRAINER_RANGE_RE = /\b(trainer)\s*\(\s*\d+\s*\)/i
    # A name of punctuation alone (an apostrophe, a dot), which is how some mappers leave an event unnamed.
    SYMBOL_NAME_RE = /\A[\x20-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]+\z/
    # The names mappers leave on a floor item ball ("Item", "ItemBall", "item.shadowless", "ball1"), which say nothing
    # the item does not.
    ITEM_BALL_NAME_RE = /\A(?:item|ball)/i
    # An object's sprite file: Spanish "objeto" anywhere, English "Object" leading, as Essentials names its boulders,
    # rocks, trees and item balls.
    OBJECT_SPRITE_RE = /objeto|\Aobject/i
    # Codes that make an action-button event do something: text, script, goods (a dup, to leave TEXT_CODES alone).
    EXAMINE_CODES = TEXT_CODES.dup.concat(SCRIPT_CODES).concat(GOODS_CODES)
    # Control Switches (121), Control Variables (122) and Control Self Switch (123): on a drawn event, a lever or
    # button the player works; on an invisible one, a setup helper.
    STATE_CODES = [121, 122, 123]
    # RPG Maker XP event-command codes for Control Switches (121) and Control Self Switch (123).
    SWITCH_CODE = 121
    SELF_SWITCH_CODE = 123
    # RPG Maker XP event-command codes for Change Items (126) and Show Choices (102).
    ITEMS_CODE = 126
    CHOICES_CODE = 102
    # A script that sets a switch ON, capturing its id.
    SWITCH_ON_SCRIPT_RE = /\$game_switches\[\s*(\d+)\s*\]\s*=\s*true/
    # A script that sets a self switch, capturing the event (its id, or itself), the letter and the value.
    SELF_SWITCH_SCRIPT_RE = /(?:pbSetSelfSwitch|setSelfSwitch)\(\s*(\d+|@event_id|event_id|get_character\(0\)\.id)\s*,
                             \s*["']([A-D])["']\s*,\s*(true|false)/x
    # A script that hands the player an item: pbReceiveItem, pbItemBall, pbStoreItem and their kin, or the bag's add.
    ITEM_GIFT_RE = /\bpb(?:ReceiveItem|ItemBall|StoreItem|EventItem|GetItem|GiveItem|AddItem)\w*\s*\(|
                    \$(?:PokemonBag|bag)\.(?:pbStoreItem|add)\s*\(/x
    # A script that hands over a floor item, capturing its id (pbItemBall, pbStoreItem); where no sprite shows who
    # gives it, pbReceiveItem too (ITEM_GIFT_ID_RE).
    PICKUP_ID_RE = /pb(?:ItemBall|StoreItem)\(\s*(?:PBItems::)?:?([A-Z0-9_]+)/i
    ITEM_GIFT_ID_RE = /pb(?:ItemBall|StoreItem|ReceiveItem)\(\s*(?:PBItems::)?:?([A-Z0-9_]+)/i
    # A script that starts a battle.
    BATTLE_SCRIPT_RE = /pb\w*Battle|TrainerBattle|WildBattle/
    # The words for a lever in a sheet, a name or a text: loc_lever in the six languages (the Polish one with any
    # letter in place of its accented z, so the pattern stays ASCII), switch, and interruptor or interrupteur.
    LEVER_WORDS_RE = /palanca|lever|levier|hebel|alavanca|d.{1,2}wignia|switch|interrupt/i
    # The words for a chest in a sheet or a name.
    CHEST_WORDS_RE = /cofre|chest/i
    # A character's sheet: a trainer's, a Pokemon's or a townsperson's.
    CHARACTER_SHEET_RE = /\A(?:trchar|trainer_|pkmn_|NPC|HGSS_)/i
    # mkxp-z's own error classes (its binding-util.cpp), defined under Exception rather than StandardError.
    ENGINE_ERROR_NAMES = %w(SDLError MKXPError PHYSFSError)

    # True if the event is used with the action button (trigger 0) and does something: text, a script, goods, an item
    # ball in a Conditional Branch, or, when drawn, a switch or variable change.
    def self.examinable?(ev)
      verdict(ev, :exam) { examinable_uncached?(ev) }
    end

    # The uncached examinable test (see examinable?).
    def self.examinable_uncached?(ev)
      return false unless PokeAccess.ivar(ev, :@trigger) == 0
      list = PokeAccess.ivar(ev, :@list)
      return false unless list.is_a?(Array)
      codes = list.map { |c| (c.code rescue 0) }
      return true if codes.any? { |c| EXAMINE_CODES.include?(c) }
      return true if script_calls(list).any? { |sc| sc =~ /pbItemBall|pbEventItem/ }
      has_graphic?(ev) && codes.any? { |c| STATE_CODES.include?(c) }
    end

    # True if the player can do something with this event: a transfer, an examinable event, a container (an open one
    # too), or a touch event with text, a script or goods.
    def self.interactable?(ev)
      return true if transfer_event?(ev) || examinable?(ev) || container?(ev)
      trig = PokeAccess.ivar_i(ev, :@trigger)
      return false unless trig == 1 || trig == 2
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| EXAMINE_CODES.include?((c.code rescue 0)) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      true
    end
  end
end

# Clears the verdicts on a map change, as event ids repeat across maps.
PokeAccess::Caches.register(:verdicts) { PokeAccess::Locator.clear_verdicts }

# And on any settings change: a verdict may depend on one (the hide mode, active-page-only transfers).
PokeAccess::Events.on(:config_changed) { |_key| PokeAccess::Locator.clear_verdicts }
