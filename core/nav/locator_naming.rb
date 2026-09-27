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

    # Field-move obstacles and pickups by event name, as the engine names them (cuttree when modern, the bare Tree on
    # gen-6): [regexp on event.name, key].
    FIELDMOVES = [[/cut[\s_]*tree|\Atree\z/i, :loc_cut_tree],
                  [/rock[\s_]*smash|smash[\s_]*rock|\Arock\z/i, :loc_rock_smash],
                  [/strength[\s_]*boulder|\Aboulder\z/i, :loc_strength_boulder],
                  [/headbutt[\s_]*tree/i, :loc_headbutt_tree],
                  [/hidden[\s_]*item/i, :loc_hidden_item], [/berry[\s_]*plant/i, :loc_berry_plant]]

    # The field-move obstacle or pickup key for an event, or nil; never for one that shows text (a character named
    # "Rock" matches the gen-6 bare names).
    def self.fieldmove_label(ev)
      n = (ev.name.to_s rescue "")
      return nil if n.empty?
      hit = FIELDMOVES.find { |re, _k| n =~ re }
      return nil if hit && (shows_text?(ev) rescue false)
      hit ? hit[1] : nil
    rescue StandardError
      nil
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
    rescue StandardError
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

    # Command lists to scan for a transfer: the active page's only with transfer_active_page_only (an inactive
    # cutscene page may warp), else, or without a live @list, every page.
    def self.transfer_command_lists(ev)
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
    rescue StandardError
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
    rescue StandardError
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
    rescue StandardError
      nil
    end

    # The destination [map, x, y] of an editor Transfer Player command (201), or nil: literals for type 0, the
    # variables read live for type 1. The cache kind carries transfer_active_page_only.
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

    # True if an event is a sign: no sprite, examined with the action button, shows text and does not transfer.
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

    # True when an event is a door or exit: by name, command 201 or a script transfer; never a sign or an autorun or
    # parallel event. An action-button transfer with any sprite but a doorway or a warp pad is a person.
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
      char.empty? || trig == 1 || trig == 2 || doorway_sprite?(char) || teleporter_sprite?(char)
    rescue StandardError
      false
    end

    # True if the event's active page runs anything besides empty rows and comments.
    def self.has_commands?(ev)
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| !NO_OP_CODES.include?((c.code rescue 0)) }
    end

    # Whether a sprite file is drawn as a doorway (EXIT_SPRITE_RE, matched as a substring).
    def self.doorway_sprite?(char)
      !char.empty? && char =~ EXIT_SPRITE_RE ? true : false
    rescue StandardError
      false
    end

    # Whether a sprite file is drawn as a warp pad (TELEPORTERS). Consulted only once the event is known
    # to transfer: the vocabulary also names the NPC who teleports the player.
    def self.teleporter_sprite?(char)
      !char.empty? && TELEPORTERS.any? { |re| char =~ re }
    rescue StandardError
      false
    end

    # Codes a push tile may carry besides its move route: empty, comments, move-command rows (509), play SE (250).
    PUSH_TRIVIAL = [0, 108, 408, 509, 250]
    # The Set Move Route command code.
    MOVEROUTE_CODE = 209

    # True if an event is a push or conveyor tile: invisible, touch-triggered, its only real command a Set Move Route
    # that steps the player (-1). Cached per map.
    def self.push_tile?(ev)
      ($game_map && ($game_map.map_id rescue nil)) == @push_map or refresh_push_cache
      @push_ids.include?(ev.id)
    rescue StandardError
      false
    end

    # Rebuilds the per-map set of push-tile event ids.
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

    # True if an event is a two-state toggle (a lever, a candle): two action-button pages with the same sprite in a
    # different pattern, the second gated by a switch or self switch, and no transfer or battle. Cached per map.
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

    # The uncached two-state-toggle test for one event (see lever?).
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

    # A command that rules out a lever: a transfer or a battle script (a trainer's post-battle page looks like one).
    def self.lever_disqualifier?(c)
      code = (c.code rescue 0)
      return true if code == TRANSFER_CODE
      return false unless SCRIPT_CODES.include?(code)
      (c.parameters[0] rescue "").to_s =~ /pb\w*Battle|TrainerBattle|WildBattle/ ? true : false
    rescue StandardError
      false
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

    # True if an event belongs to the Eye/Lens of Truth plugin, whose events carry "#EOT" in their name.
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
    rescue StandardError
      nil
    end

    # The name of a warp within the current map: "passage to the <dir>" with a known destination, else "passage".
    def self.passage_name(ev)
      xy = (transfer_command_dest_xy(ev) rescue nil)
      dir = (xy ? cardinal_of(xy[1], xy[2]) : nil)
      return PokeAccess::I18n.t(:loc_passage_dir, :dir => PokeAccess::I18n.t(dir)) if dir
      PokeAccess::I18n.t(:loc_passage)
    rescue StandardError
      PokeAccess::I18n.t(:loc_passage)
    end

    # A map's name: the player's rename, else the MapInfos one (loaded once, failure cached too), cleaned for speech.
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
      nm = (@mapinfos[mapid].name rescue nil)
      nm.nil? ? nil : PokeAccess.clean(nm)
    end

    # MapInfos (id => RPG::MapInfo) through the engine's loader: those an engine's data provider keeps loaded,
    # pbLoadMapInfos from v19, pbLoadRxData on gen-6.
    def self.load_mapinfos
      kept = PokeAccess::Data.optional(:map_infos)
      return kept if kept
      return (pbLoadMapInfos rescue nil) if respond_to?(:pbLoadMapInfos, true)
      (pbLoadRxData("Data/MapInfos") rescue nil)
    end

    # Builds the spoken name for an event; a user tag wins, and a synthetic target keeps the name it was built with.
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
      n = "" if n =~ SYMBOL_NAME_RE
      return PokeAccess::I18n.t(:loc_trainer) if n =~ /^Trainer\(/i
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
      return PokeAccess::I18n.t(:loc_lever) + lever_state_suffix(ev) if lever?(ev)
      return n unless n.empty? || n =~ /^(EV\d+|size\()/i
      return PokeAccess::I18n.t(:loc_sign) if sign_event?(ev)
      if (PokeAccess::Config.name_items rescue true)
        it = item_name(ev)
        return PokeAccess::I18n.t(:loc_object_named, :name => it) if it
      end
      g = ev.character_name.to_s
      sp = sprite_species(g)
      return sp if sp
      return PokeAccess::I18n.t(:loc_shopkeeper) if shop_event?(ev)
      return PokeAccess::I18n.t(:loc_object) if g.empty? || g =~ /^\d+$/ || g =~ /objeto/i
      sprite_trainer_class(g) || g
    end

    # True when a door leads from outdoors into an interior: going in there is an entrance.
    def self.entrance?(dmap)
      here = ($game_map.map_id rescue nil)
      return false if dmap.nil? || here.nil?
      PokeAccess::MapMeta.outdoor?(here) == true && PokeAccess::MapMeta.outdoor?(dmap) == false
    rescue StandardError
      false
    end

    # True when a door's destination bears the name of the map the player is on, so the name tells nothing.
    def self.same_place?(dname)
      dname.to_s.strip.downcase == map_name(($game_map.map_id rescue nil)).to_s.strip.downcase
    rescue StandardError
      false
    end

    # What a door to a place named like this one leads to: from outdoors into an interior, the building --
    # a Pokemon Centre when the map is one -- and anywhere else another part of the same place.
    def self.same_place_name(dmap, dname)
      return PokeAccess::I18n.t(:loc_area_other, :map => dname) unless entrance?(dmap)
      PokeAccess::I18n.t(PokeAccess::MapMeta.pokecenter?(dmap) ? :loc_pokecenter : :loc_building)
    end

    # Script calls that open a shop: every mart the engine or a game defines (pbPokemonMart and its variants, the
    # battle-point and secret-base shops, a clothes or hat shop), never pbStoreItem, which is an item on the floor.
    SHOP_CALL = /\b(?:pb\w*Mart\w*|\w*[Ss]hop|tm_mart|enter_pokemart)\s*\(/

    # True if the event opens a shop: an unnamed shop attendant is called one, not by its sprite's file name.
    def self.shop_event?(ev)
      !!script_call_find(ev) { |s| s =~ SHOP_CALL }
    rescue StandardError
      false
    end

    # The species an overworld sprite named by national number shows ("025", "025s" shiny), or nil; only where
    # species are keyed by number (gen-6, Infinite Fusion).
    def self.sprite_species(g)
      return nil unless g.to_s =~ /\A(\d{3})s?\z/
      n = $1.to_i
      return nil if n <= 0
      return nil unless PokeAccess::Engine.gen6? || (::GameData::Species::DATA.has_key?(n) rescue false)
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

    # "Wild <species>" for a visible overworld encounter (the VOE plugin's Game_PokeEvent), else nil.
    def self.wild_pokemon_name(ev)
      return nil unless defined?(Game_PokeEvent) && ev.is_a?(Game_PokeEvent)
      pk = (ev.pokemon rescue nil)
      return nil unless pk
      nm = (pk.name rescue nil); nm = (pk.speciesName rescue nil) if nm.nil? || nm.to_s.empty?
      (nm && !nm.to_s.empty?) ? PokeAccess::I18n.t(:loc_wild, :name => nm) : nil
    rescue StandardError
      nil
    end

    # The name of the item a pickup event gives (pbItemBall or pbStoreItem in its script), or nil.
    def self.item_name(ev)
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      script_calls(list).each do |s|
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

    # True if the event hands over an item ball (pbItemBall, pbEventItem), whatever its sprite; not pbReceiveItem,
    # which gift NPCs use.
    def self.item_ball?(ev)
      !!script_call_find(ev) { |s| s =~ /pbItemBall|pbEventItem/ }
    rescue StandardError
      false
    end

    # Classifies a graphic event: a named person sprite is :people; a tile, a numbered, object or doorway sprite, a
    # hazard or an item ball is :objects.
    def self.event_category(ev)
      return :objects if hazard?(ev) || item_ball?(ev)
      g = (ev.character_name.to_s rescue "")
      (g.empty? || g =~ /^\d+$/ || g =~ /objeto/i || doorway_sprite?(g)) ? :objects : :people
    end

    # True if the event shows a character sprite or a map tile (a placed object).
    def self.has_graphic?(ev)
      return true unless ev.character_name.to_s.empty?
      (ev.tile_id rescue 0).to_i > 0
    end

    # True if an event runs the Essentials PC script.
    def self.pc_event?(ev)
      !!script_call_find(ev) { |s| s =~ /pbPokeCenterPC|pbPokemonPC|pbTrainerPC|PokemonPC/ }
    rescue StandardError
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
    rescue StandardError
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
    # and forced_z=N for its drawing layer.
    EDITOR_NOTE_RE = /\s*(?:size\s*\(\s*\d+\s*,\s*\d+\s*\)|\.sl\b|\bforced_z\s*=\s*-?\d+)/i
    # A name of punctuation alone (an apostrophe, a dot), which is how some mappers leave an event unnamed.
    SYMBOL_NAME_RE = /\A[\x20-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]+\z/
    # Codes that make an action-button event do something: text, script, goods (a dup, to leave TEXT_CODES alone).
    EXAMINE_CODES = TEXT_CODES.dup.concat(SCRIPT_CODES).concat(GOODS_CODES)
    # Control Switches (121), Control Variables (122) and Control Self Switch (123): on a drawn event, a lever or
    # button the player works; on an invisible one, a setup helper.
    STATE_CODES = [121, 122, 123]

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

    # True if the player can do something with this event: a transfer, an examinable event, or a touch event with
    # text, a script or goods.
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

# Clears the verdicts on a map change, as event ids repeat across maps.
PokeAccess::Caches.register(:verdicts) { PokeAccess::Locator.clear_verdicts }
