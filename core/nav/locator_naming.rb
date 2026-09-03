module PokeAccess
  # Locator part 1 of 4: identifying and naming map events (what a target is and what to call it). The
  # spoken name prefers a user tag, then resolves exits, trainers, pickup items, and people vs objects.
  module Locator
    # Hazard sprites a game registers (a puzzle beam/laser/spike): a matched event reads with its own
    # label, files under objects, and gets a "zap" cue. Each entry is [regexp on character_name, label key].
    HAZARDS = []

    # Registers a hazard sprite pattern and its spoken-name key.
    def self.register_hazard(re, label_key)
      HAZARDS.push([re, label_key])
    end

    # The spoken-name key of the hazard an event is, or nil if it is not a registered hazard.
    def self.hazard_label(ev)
      return nil if HAZARDS.empty?
      cn = (ev.character_name.to_s rescue "")
      return nil if cn.empty?
      hit = HAZARDS.find { |re, _k| cn =~ re }
      hit ? hit[1] : nil
    rescue StandardError
      nil
    end

    # True if the event is a registered hazard.
    def self.hazard?(ev)
      !hazard_label(ev).nil?
    end

    # Base-Essentials field-move obstacles and pickups, by event NAME (the engine matches these too):
    # modern names them cuttree/smashrock/strengthboulder, gen-6 the bare Tree/Rock/Boulder, so each
    # regex matches both. Each is [regexp on event.name, key].
    FIELDMOVES = [[/cut\s*tree|\Atree\z/i, :loc_cut_tree],
                  [/rock\s*smash|smash\s*rock|\Arock\z/i, :loc_rock_smash],
                  [/strength\s*boulder|\Aboulder\z/i, :loc_strength_boulder],
                  [/headbutt\s*tree/i, :loc_headbutt_tree],
                  [/hidden\s*item/i, :loc_hidden_item], [/berry\s*plant/i, :loc_berry_plant]]

    # The field-move obstacle/pickup key for an event, or nil (matched on the engine's own name marker).
    # An event that TALKS is not a hidden field-move obstacle, however well its name matches. The bare-name
    # alternatives -- \Arock\z, \Atree\z, \Aboulder\z -- exist because gen-6 names them that way, but they
    # also match a character called "Rock", and then an NPC with dialogue is announced as a breakable rock
    # and the player never talks to them again.
    def self.fieldmove_label(ev)
      n = (ev.name.to_s rescue "")
      return nil if n.empty?
      hit = FIELDMOVES.find { |re, _k| n =~ re }
      return nil if hit && (shows_text?(ev) rescue false)
      hit ? hit[1] : nil
    rescue StandardError
      nil
    end

    # Sprite-name patterns marking a teleporter / warp pad. Detection is by name (not just "has a sprite"),
    # because doors carry sprites too and must not sound as teleporters. Games add their own.
    TELEPORTERS = [/ascensor|portal|telepor|teleport|warp|ultraumbral/i]

    # Registers an extra teleporter sprite pattern.
    def self.register_teleporter(re); TELEPORTERS.push(re); end

    # True if an event is a teleporter / warp pad: its sprite reads as a warp and it transfers the player.
    def self.teleporter_event?(ev)
      cn = (ev.character_name.to_s rescue "")
      return false if cn.empty?
      return false unless TELEPORTERS.any? { |re| cn =~ re }
      !transfer_command_dest(ev).nil? || !transfer_script_dest(ev).nil?
    rescue StandardError
      false
    end

    # Per-event VERDICT cache for the page-scanning classifiers (transfer/sign/examinable/shows_text).
    # Invalidation lives INSIDE the key, [event id, identity of the live @list, kind]: a switch that flips
    # the event to another page makes the engine assign that page's list to @list, so the identity changes
    # and the stale verdict is never looked up again (flipping back revives the old key). @trigger and
    # character_name change in the same refresh, so one identity covers every input the classifiers read.
    # The store is also dropped where the locator already invalidates -- end of a running event, map change
    # -- so variable-driven type-1 transfers refresh and keys never pile up. Values are wrapped in a
    # one-element array so nil and false cache as real hits.
    @verdicts = {}

    # The cached verdict for (event, kind), computing it from the block on the first miss.
    def self.verdict(ev, kind)
      key = [ev.id, (PokeAccess.ivar(ev, :@list).__id__ rescue 0), kind]
      hit = @verdicts[key]
      return hit[0] if hit
      v = yield
      @verdicts[key] = [v]
      v
    rescue StandardError
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

    # Command lists to scan for a TRANSFER, honouring the transfer_active_page_only setting. When on, only
    # the event's ACTIVE page (@list, the page the engine currently runs) is scanned, so a character whose
    # inactive cutscene page contains a map change is not mistaken for an exit (e.g. an NPC that warps you
    # out only under a condition). When off, every page is scanned (catches a conditional warp tile whose
    # active page differs). Falls back to all pages if the active list is unavailable.
    def self.transfer_command_lists(ev)
      if (PokeAccess::Config.transfer_active_page_only rescue true)
        live = PokeAccess.ivar(ev, :@list)
        return [live] if live.is_a?(Array)
      end
      event_command_lists(ev)
    end

    # Yields every script-call string (the parameters[0] of a SCRIPT_CODES command) in an event's command
    # lists. The shared spine of the script-scanning predicates below, which only differ in the regex they
    # match. Returns the first non-nil/true value the block yields, or nil -- so callers read as a find.
    def self.script_call_find(ev, lists = nil)
      (lists || event_command_lists(ev)).each do |list|
        list.each do |c|
          code = (c.code rescue 0)
          next unless SCRIPT_CODES.include?(code)
          r = yield((c.parameters[0] rescue "").to_s)
          return r if r
        end
      end
      nil
    rescue StandardError
      nil
    end

    # Script calls that mean "this event transfers the player", each capturing the destination map id. The
    # two Essentials shapes ship here; a game whose doors call a function of its OWN (Reminiscencia's
    # dungeon entrances are a bare `getToDungeon(319)`, with no editor Transfer command anywhere) declares
    # its pattern from its profile, because that function name is the game's and not the engine's. Without
    # it such a door is not an exit, not a pathfinder target and, having no sprite either, not even a sonar
    # ping: one verdict feeds all three.
    TRANSFER_SCRIPTS = [/\bpbTransfer\w*\(\s*(\d+)/, /player_new_map_id\s*=\s*(\d+)/]

    # Registers an extra script-transfer pattern. It must capture the destination map id, which is what
    # names the exit ("exit to <map>").
    def self.register_transfer_script(re); TRANSFER_SCRIPTS.push(re); end

    # The destination map id of a SCRIPT-based transfer (pbTransfer / player_new_map_id=, plus whatever the
    # profile registered), or nil. Many fangame doors transfer by script, not the editor's command 201, so
    # 201-only detection would miss them.
    def self.transfer_script_dest(ev)
      verdict(ev, :tscript) { transfer_script_dest_uncached(ev) }
    end

    # The uncached script-transfer scan (see transfer_script_dest).
    def self.transfer_script_dest_uncached(ev)
      script_call_find(ev, transfer_command_lists(ev)) do |s|
        m = nil
        TRANSFER_SCRIPTS.each { |re| m ||= re.match(s) }
        m ? m[1].to_i : nil
      end
    rescue StandardError
      nil
    end

    # The destination map id of an editor Transfer Player command (201), or nil. Type 1 ("with variables")
    # stores in pars[1] the VARIABLE holding the map id (resolved live); type 0 stores the literal id.
    def self.transfer_command_dest(ev)
      xy = transfer_command_dest_xy(ev)
      xy ? xy[0] : nil
    rescue StandardError
      nil
    end

    # The destination [map, x, y] of an editor Transfer Player command (201), or nil. Type 1 ("with
    # variables") resolves the variables holding map/x/y live; type 0 stores literals in pars[1..3]. The
    # coordinates let clustering tell a wide doorway (tiles landing on one spot) from two distinct doors
    # that merely share a destination map. The cache kind carries the transfer_active_page_only setting
    # (and the config menu clears all verdicts on every setting write), so a toggle never serves a
    # verdict computed under the other semantics.
    def self.transfer_command_dest_xy(ev)
      kind = (PokeAccess::Config.transfer_active_page_only rescue true) ? :txy_active : :txy_all
      verdict(ev, kind) { transfer_command_dest_xy_uncached(ev) }
    end

    # The uncached 201-command scan (see transfer_command_dest_xy).
    def self.transfer_command_dest_xy_uncached(ev)
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
    rescue StandardError
      nil
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
    rescue StandardError
      false
    end

    # True if an event is a sign: examined with the action button, shows text, has no character sprite,
    # and does not transfer (so a sign named "salida" is not miscategorised as an exit).
    def self.sign_event?(ev)
      verdict(ev, :sign) { sign_event_uncached?(ev) }
    end

    # The uncached sign test (see sign_event?).
    def self.sign_event_uncached?(ev)
      return false unless ev.character_name.to_s.empty?
      return false unless examinable?(ev)
      return false unless transfer_command_dest(ev).nil? && transfer_script_dest(ev).nil?
      shows_text?(ev)
    rescue StandardError
      false
    end

    # True when an event is a map transfer (door/exit): by name, command 201, or a script transfer.
    # Signs and autorun/parallel events are excluded; an action-button NPC that warps is a person unless
    # its name says exit; touch-triggered warp tiles (sprite or not) stay exits.
    def self.transfer_event?(ev)
      verdict(ev, :transfer) { transfer_event_uncached?(ev) }
    end

    # The uncached transfer test (see transfer_event?).
    def self.transfer_event_uncached?(ev)
      return false if sign_event?(ev)
      trig = PokeAccess.ivar_i(ev, :@trigger)
      return false if trig == 3 || trig == 4
      name = ev.name.to_s
      char = ev.character_name.to_s
      return true if "#{name} #{char}" =~ EXIT_NAME_RE
      return false unless !transfer_command_dest(ev).nil? || !transfer_script_dest(ev).nil?
      char.empty? || trig == 1 || trig == 2
    rescue StandardError
      false
    end

    # Event-command codes a push tile may legitimately carry besides the move route: empty, comments, the
    # animated move-command rows (509), and a play-SE (250). Anything else means it is not a bare push tile.
    PUSH_TRIVIAL = [0, 108, 408, 509, 250]
    # Set-Move-Route command code, and the move-command codes that step a character (down/left/right/up).
    MOVEROUTE_CODE = 209

    # True if an event is a "push"/conveyor tile: an invisible, touch-triggered tile whose only real command
    # is a Set Move Route applied to the PLAYER (target -1) that steps them along, with no text, warp or
    # branch. These shove the player around silently (Pokeball-factory puzzles), so they get their own cue.
    # Matches the data shape, not a name, so it is engine- and game-agnostic.
    def self.push_tile?(ev)
      ($game_map && ($game_map.map_id rescue nil)) == @push_map or refresh_push_cache
      @push_ids.include?(ev.id)
    rescue StandardError
      false
    end

    # Rebuilds the per-map set of push-tile event ids (scanning event pages is costly, so it is cached and
    # only rebuilt on a map change).
    def self.refresh_push_cache
      @push_map = ($game_map.map_id rescue nil)
      @push_ids = {}
      ($game_map.events.each_value { |ev| @push_ids[ev.id] = true if ev && push_tile_uncached?(ev) } rescue nil)
      true
    end

    # The uncached push-tile test for one event (see push_tile?).
    def self.push_tile_uncached?(ev)
      (ev.instance_variable_get(:@event).pages rescue []).each do |pg|
        next unless pg && (pg.trigger == 1)
        next unless (pg.graphic.character_name.to_s.empty? rescue false)
        list = (pg.list || [])
        sub = list.map { |c| (c.code rescue 0) }.reject { |cd| PUSH_TRIVIAL.include?(cd) }
        next unless sub.uniq == [MOVEROUTE_CODE]
        return true if list.any? { |c| push_moveroute?(c) }
      end
      false
    rescue StandardError
      false
    end

    # True if an event is a two-state toggle (a puzzle lever, a lightable candle...): exactly two
    # action-triggered pages with the SAME non-empty sprite but a DIFFERENT pattern (the drawn position
    # changes), the second gated by a switch/self-switch, and no map transfer. Matches the data shape, not a
    # name, so it is engine- and game-agnostic (verified to hit puzzle levers/candles across the games and
    # nothing else). Cached per map like push tiles, since scanning pages each frame is costly.
    def self.lever?(ev)
      ($game_map && ($game_map.map_id rescue nil)) == @lever_map or refresh_lever_cache
      @lever_ids.include?(ev.id)
    rescue StandardError
      false
    end

    # Rebuilds the per-map set of lever event ids (see lever?).
    def self.refresh_lever_cache
      @lever_map = ($game_map.map_id rescue nil)
      @lever_ids = {}
      ($game_map.events.each_value { |ev| @lever_ids[ev.id] = true if ev && lever_uncached?(ev) } rescue nil)
      true
    end

    # The uncached two-state-toggle test for one event (see lever?). A trainer with two same-sprite pose
    # pages gated by a self-switch (the post-battle page) has the same shape as a lever, so events that fight
    # (a pbTrainerBattle/pbWildBattle/etc. script call) are excluded -- and in target_name the lever check
    # runs only AFTER the Trainer()/PC/exit checks, so a battler is never read as a lever.
    def self.lever_uncached?(ev)
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
    rescue StandardError
      false
    end

    # A command that rules an event out of being a lever: a map transfer, or a script that starts a battle
    # (a trainer's post-battle page mimics the lever's two-pose shape, so a battle call disqualifies it).
    def self.lever_disqualifier?(c)
      code = (c.code rescue 0)
      return true if code == TRANSFER_CODE
      return false unless SCRIPT_CODES.include?(code)
      (c.parameters[0] rescue "").to_s =~ /pb\w*Battle|TrainerBattle|WildBattle/ ? true : false
    rescue StandardError
      false
    end

    # The spoken state of a two-state toggle: "moved"/"on" when its gated (second) page is the active one,
    # else "not moved"/"off". Read from the live active page (@page, which RMXP resolves from the current
    # switches), comparing its pattern to the base page's, so it reflects the real in-game state.
    def self.lever_state_suffix(ev)
      pages = (ev.instance_variable_get(:@event).pages rescue nil)
      active = PokeAccess.ivar(ev, :@page)
      return "" unless pages.is_a?(Array) && active
      base_pat = (pages[0].graphic.pattern rescue nil)
      cur_pat = (active.graphic.pattern rescue nil)
      moved = (cur_pat != base_pat)
      ", " + PokeAccess::I18n.t(moved ? :loc_lever_on : :loc_lever_off)
    rescue StandardError
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
    rescue StandardError
      false
    end

    # True if an event belongs to the community "Eye/Lens of Truth" plugin: such events carry the marker
    # "#EOT" in their name (HIDE = revealed only with the lens). The marker is the plugin's own convention,
    # shared across games, so this is name-based and engine-agnostic; the spoken cue stays generic (the
    # item that reveals them is named differently per game).
    def self.lens_tile?(ev)
      (ev.name.to_s rescue "") =~ /#EOT/ ? true : false
    rescue StandardError
      false
    end

    # The destination map name of a transfer event (command or script), or nil.
    def self.transfer_dest_name(ev)
      d = transfer_command_dest(ev) || transfer_script_dest(ev)
      d ? map_name(d) : nil
    rescue StandardError
      nil
    end

    # A cardinal label key (:dir_n .. :dir_so) for a point (x,y) relative to the current map's centre, or
    # nil if it sits dead centre. Used to orient internal warps and teleports ("passage to the east"); the
    # threshold is a fraction of the map so a point only counts as N/S/E/W when clearly off-centre.
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
    rescue StandardError
      nil
    end

    # The spoken name for an internal warp (one whose destination is the current map): "passage to the
    # <dir>" when the destination coordinates are known, else a bare "passage". Distinguishes these from
    # real exits to other maps (which keep "exit to <map>"), since "exit to <this very map>" tells the player
    # nothing.
    def self.passage_name(ev)
      xy = (transfer_command_dest_xy(ev) rescue nil)
      dir = (xy ? cardinal_of(xy[1], xy[2]) : nil)
      return PokeAccess::I18n.t(:loc_passage_dir, :dir => PokeAccess::I18n.t(dir)) if dir
      PokeAccess::I18n.t(:loc_passage)
    rescue StandardError
      PokeAccess::I18n.t(:loc_passage)
    end

    # A map name from its id, caching MapInfos -- including caching the FAILURE. Without the empty-hash
    # fallback the guard below stays true and the whole Marshal is re-attempted on every call (each map
    # change, each exit name, each diag line, each recorder sample) while no map is ever named and nothing
    # is written anywhere.
    def self.map_name(mapid)
      ov = (PokeAccess::MapNames.get(mapid) rescue nil)
      return ov if ov && !ov.to_s.empty?
      if @mapinfos.nil?
        @mapinfos = load_mapinfos
        if @mapinfos.nil?
          PokeAccess.log_once("mapinfos", "Data/MapInfos no cargable")
          @mapinfos = {}
        end
      end
      return nil unless @mapinfos && @mapinfos[mapid]
      (@mapinfos[mapid].name rescue nil)
    end

    # MapInfos through whichever loader the engine ships. Gen-6 exposes the generic pbLoadRxData; v19+
    # replaced it with pbLoadMapInfos, which caches into $game_temp. Both return the same id => RPG::MapInfo
    # hash. Six of the thirteen games carry only the second one, and map_name memoises its failure, so asking
    # for the wrong loader left those games with no zone, exit or coordinate name for the whole session.
    def self.load_mapinfos
      return (pbLoadMapInfos rescue nil) if respond_to?(:pbLoadMapInfos, true)
      (pbLoadRxData("Data/MapInfos") rescue nil)
    end

    # Builds the spoken name for an event (person/object/exit/generic); a user tag wins over the auto name.
    #
    # A synthetic target is passed straight through: the five places that build a SurfaceTarget hand it a
    # finished, already-localized name, and classifying it again can only lose information. A connection
    # exit is named "salida a Ruta 3", which EXIT_NAME_RE matches, and a Struct carries no command list to
    # find a destination in, so it would fall through to a bare "salida".
    def self.target_name(ev)
      return ev.name.to_s if ev.is_a?(SurfaceTarget)
      tag = (PokeAccess::Tags.get($game_map.map_id, ev.id) rescue nil)
      return tag if tag && !tag.to_s.empty?
      w = wild_pokemon_name(ev)
      return w if w
      hz = hazard_label(ev)
      return PokeAccess::I18n.t(hz) if hz
      return PokeAccess::I18n.t(:loc_lens) if lens_tile?(ev)
      fm = fieldmove_label(ev)
      return PokeAccess::I18n.t(fm) + PokeAccess::Berry.state_suffix(ev) if fm == :loc_berry_plant
      return PokeAccess::I18n.t(fm) if fm
      n = ev.name.to_s.sub(/\/.*$/, "").gsub(EDITOR_NOTE_RE, " ").strip.gsub(/\s{2,}/, " ")
      return PokeAccess::I18n.t(:loc_trainer) if n =~ /^Trainer\(/i
      return PokeAccess::I18n.t(:loc_pc) if pc_event?(ev)
      if transfer_event?(ev)
        dmap = (transfer_command_dest(ev) || transfer_script_dest(ev) rescue nil)
        return passage_name(ev) if dmap && dmap == ($game_map.map_id rescue nil)
        d = transfer_dest_name(ev)
        return PokeAccess::I18n.t(:loc_exit_to, :map => d) if d
        return n unless n.empty? || n =~ EXIT_NAME_RE
        return PokeAccess::I18n.t(:loc_exit)
      end
      return PokeAccess::I18n.t(:loc_lever) + lever_state_suffix(ev) if lever?(ev)
      return n unless n.empty? || n =~ /^(EV\d+|size\()/i
      return PokeAccess::I18n.t(:loc_sign) if sign_event?(ev)
      if (PokeAccess::Config.name_items rescue true)
        it = item_name(ev)
        return PokeAccess::I18n.t(:loc_object_named, :name => it) if it
      end
      g = ev.character_name.to_s
      return PokeAccess::I18n.t(:loc_object) if g.empty? || g =~ /^\d+$/ || g =~ /objeto/i
      g
    end

    # The species name of a visible overworld encounter (the VOE plugin's Game_PokeEvent), so it is read as
    # "Pidgey salvaje" instead of its EV### name; nil for any other event. Gated by class existence.
    def self.wild_pokemon_name(ev)
      return nil unless defined?(Game_PokeEvent) && ev.is_a?(Game_PokeEvent)
      pk = (ev.pokemon rescue nil)
      return nil unless pk
      nm = (pk.name rescue nil); nm = (pk.speciesName rescue nil) if nm.nil? || nm.to_s.empty?
      (nm && !nm.to_s.empty?) ? PokeAccess::I18n.t(:loc_wild, :name => nm) : nil
    rescue StandardError
      nil
    end

    # The display name of the pickup item an event gives (a ground poke ball or "store item" cup), parsed
    # from its script, or nil -- so generic item events announce what they contain instead of "objeto".
    def self.item_name(ev)
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      list.each do |c|
        code = (c.code rescue 0)
        next unless SCRIPT_CODES.include?(code)
        s = (c.parameters[0] rescue "").to_s
        next unless s =~ /pb(?:ItemBall|StoreItem)\(\s*(?:PBItems::)?:?([A-Z0-9_]+)/i
        sym = $1.upcase
        _id, nm = PokeAccess::Data.item_id(sym)
        return nm if nm && !nm.to_s.empty?
        return sym.downcase.capitalize
      end
      nil
    rescue StandardError
      nil
    end

    # True if the event hands over an item ball (pbItemBall / pbEventItem style script): an object pickup,
    # not a person, whatever its (often custom) ball sprite. pbReceiveItem is intentionally NOT matched --
    # gift NPCs use it after dialogue, so matching it would mislabel them as objects.
    def self.item_ball?(ev)
      !!script_call_find(ev) { |s| s =~ /pbItemBall|pbEventItem/ }
    rescue StandardError
      false
    end

    # Classifies a graphic event: a named person sprite is :people, any other graphic (tile or
    # numbered/object sprite) is :objects; hazards and item balls are forced to :objects.
    def self.event_category(ev)
      return :objects if hazard?(ev) || item_ball?(ev)
      g = (ev.character_name.to_s rescue "")
      (g.empty? || g =~ /^\d+$/ || g =~ /objeto/i) ? :objects : :people
    end

    # True if the event shows a character sprite or a map tile (a placed object).
    def self.has_graphic?(ev)
      return true unless ev.character_name.to_s.empty?
      (ev.tile_id rescue 0).to_i > 0
    end

    # True if an event runs the Essentials PC script, so the locator labels it "PC" by fingerprint
    # rather than its (often EV###) name.
    def self.pc_event?(ev)
      !!script_call_find(ev) { |s| s =~ /pbPokeCenterPC|pbPokemonPC|pbTrainerPC|PokemonPC/ }
    rescue StandardError
      false
    end

    # True if an event is a counter service desk used from the front (nurse, PC, mart clerk): it sits
    # behind an impassable counter yet must stay audible across it, so it bypasses the line-of-sight cut
    # that hides ordinary objects behind a wall. Detected by sprite (nurse) or script fingerprint.
    def self.service_desk?(ev)
      cn = (ev.character_name.to_s rescue "")
      return true if cn =~ /enfermera|nurse/i
      !!script_call_find(ev) do |s|
        s =~ /pbSetPokemonCenter|pbHealAll|pbNurseHeal|pbHealParty|pbPokeCenterPC|pbPokemonPC|pbTrainerPC|PokemonPC|pbPokemonMart/
      end
    rescue StandardError
      false
    end

    # Essentials event-command codes for an inline script call (355) and its continuation line (655).
    SCRIPT_CODES = [355, 655]
    # RPG Maker XP event-command code for a Transfer Player command (a door/warp).
    TRANSFER_CODE = 201
    # RPG Maker XP event-command codes for Show Text (101) and Show Choices (102).
    TEXT_CODES = [101, 102]
    # RPG Maker XP event-command codes that grant or change goods: Change Items (125/126), Change Gold (127),
    # Change Weapons (128) and Change Party Member (117) -- the marks of a hidden item / reward event.
    GOODS_CODES = [125, 126, 127, 128, 117]
    # Event name/sprite patterns that mark a door/exit (matched on the event's name and charset).
    # With word boundaries: as a substring, "door" matches inside "outdoor" and "puerta" inside
    # "puertaventana", and any piece of scenery is announced as an exit to somewhere it does not lead.
    EXIT_NAME_RE = /\b(door|puerta|salida|exit)\b/i

    # Annotations the map editor leaves stuck to the event name that are no part of it: size(3,1) for a
    # multi-tile object, .sl and forced_z=N for the layer it is drawn on. Left in, they are pronounced as
    # they are -- "vending machine size(3,1)" -- because the guard that already existed only stripped them
    # when they were the whole name.
    EDITOR_NOTE_RE = /\s*(?:size\s*\(\s*\d+\s*,\s*\d+\s*\)|\.sl\b|\bforced_z\s*=\s*-?\d+)/i
    # Action-button command codes that mean an event does something: text/choices, script, or item/money.
    # Built on a duped array with concat, never `+`: a fangame script patch redefines Array#+ as an in-place
    # mutator (seen in the wild), so the literal `+` would corrupt TEXT_CODES and alias this constant to it.
    EXAMINE_CODES = TEXT_CODES.dup.concat(SCRIPT_CODES).concat(GOODS_CODES)

    # True if the event is examined with the action button (trigger 0) and then does something: a sign
    # (show text/choices) or an invisible interactable whose action is a script or item/money change
    # (the rare-candy cups, hidden items). Pure setup triggers (only switches/variables) are skipped.
    def self.examinable?(ev)
      verdict(ev, :exam) { examinable_uncached?(ev) }
    end

    # The uncached examinable test (see examinable?).
    def self.examinable_uncached?(ev)
      return false unless PokeAccess.ivar(ev, :@trigger) == 0
      list = PokeAccess.ivar(ev, :@list)
      return false unless list.is_a?(Array)
      list.any? { |c| EXAMINE_CODES.include?((c.code rescue 0)) }
    end

    # True if the player can do something with this event: a transfer, an action-button event that
    # shows text / runs a script / gives an item, or a touch event with such content. Autorun/parallel
    # and graphic-only events with no response are not interactable.
    def self.interactable?(ev)
      return true if transfer_event?(ev) || examinable?(ev)
      trig = PokeAccess.ivar_i(ev, :@trigger)
      return false unless trig == 1 || trig == 2
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| EXAMINE_CODES.include?((c.code rescue 0)) }
    rescue StandardError
      true
    end
  end
end

# Verdicts also die with the map: event ids repeat across maps, so a map change must not let map A's
# event 12 answer for map B's (the shared reset point every per-map cache registers on).
PokeAccess::Caches.register(:verdicts) { PokeAccess::Locator.clear_verdicts }
