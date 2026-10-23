module PokeAccess
  # The declarative API game profiles use (Game.define): each method forwards to a toolkit registration call.
  module Game
    @profiles = []
    @profile_name = nil

    # The identifiers of the profiles defined so far.
    def self.profiles; @profiles; end

    # The profile this game runs under, which the dictionaries stamp their files with; memoised (false for nil)
    # until Game.define adds a name.
    def self.profile_name
      @profile_name = (resolve_profile_name || false) if @profile_name.nil?
      @profile_name || nil
    end

    # The first Game.define name that is not a common's (a common loads first and names itself "<x>_common"), else
    # installed.json's profile, else nil; "generic" becomes "generic:<title>" so two unprofiled games never share a
    # stamp.
    def self.resolve_profile_name
      own = @profiles.find { |n| n.to_s !~ /_common\z/ }
      return own if own
      txt = (File.read("#{PokeAccess::Paths::DATA}/installed.json") rescue nil)
      m = txt ? txt.match(/"profile"\s*:\s*"([^"]+)"/) : nil
      return nil unless m
      return m[1] unless m[1] == "generic"
      t = game_title
      t ? "#{m[1]}:#{t}" : m[1]
    end

    # The game's title from $data_system, or nil when blank.
    def self.game_title
      t = ($data_system.game_title rescue nil)
      (t.nil? || t.to_s.strip.empty?) ? nil : t.to_s.strip
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Declares a game profile; the block registers its hooks/readers/puzzles/config. Additive and
    # repeatable (a game may use several define blocks).
    def self.define(name = nil, &blk)
      if name && !@profiles.include?(name)
        @profiles << name
        @profile_name = nil
      end
      d = Definition.new(name)
      d.instance_eval(&blk) if blk
      d
    end

    # The receiver for a Game.define block; each method is a one-liner over the toolkit's API.
    class Definition
      def initialize(name = nil); @name = name; end

      # Overrides a Config setting.
      def config(key, value); PokeAccess::Config.send("#{key}=", value); end

      # Merges per-game button relabels into the remap menu (added to the defaults, never replacing).
      def button_labels(map); PokeAccess::Config.rebind_labels.merge!(map); end

      # Declares which letters the game paints in its key hints and the button each stands for (see KeyHints),
      # only those checked against the code that reads the key: a letter the game reads raw stays out.
      def key_hints(map); PokeAccess::Config.key_hint_letters.merge!(map); end

      # Merges a game's own ids into a core name table (:status_names, :weather_names, :field_weather_names).
      # Values are i18n symbols, or literals for a Spanish-only game.
      def names(table, map); PokeAccess::Config.send(table).merge!(map); end

      # Registers a focused-option reader for a command window. Yields (window, index) -> option text.
      def screen_reader(cname, &blk); PokeAccess::Menus.def_extractor(cname, &blk); end

      # Says the focused entry of a screen whose cursor is an index each time it moves (FocusReader.define: :on,
      # :index, :items, :slot, :queue, :key, :optional, :hook_container); the block gives the line.
      def focus_reader(cname, opts = {}, &text); PokeAccess::FocusReader.define(cname, opts, &text); end

      # Declares one of this game's standing information windows (a sprite repainted with text= as the cursor moves).
      def info_window(cname, key, slot, opts = {}); PokeAccess::InfoWindow.watch(cname, key, slot, opts); end

      # Binds the hall-of-fame readers (member panel, banner, trainer box) to this game's copies of the
      # screen; core binds the two vanilla spellings.
      def hall_of_fame(*cnames)
        cnames.flatten.each { |c| PokeAccess::HallOfFame.bind(c) }
      end

      # Runs the block after a method fires; yields (instance, result, args). opts as in Hooks.after_hook: :optional
      # for a method absent on some builds, :hook_container for one that drives the hooks that announce.
      def after(cname, meth, opts = {}, &blk); PokeAccess::Hooks.after_hook(cname, meth, opts, &blk); end

      # Runs the block before a method fires; yields (instance, args). opts as in after (:optional).
      def before(cname, meth, opts = {}, &blk); PokeAccess::Hooks.before_hook(cname, meth, opts, &blk); end

      # Wraps a method: the block runs around the original and must call the yielded nxt. Yields
      # (instance, nxt, args). opts as in after (:optional).
      def around(cname, meth, opts = {}, &body); PokeAccess::Hooks.around_hook(cname, meth, opts, &body); end

      # Speaks the block's text when a scene opens, queued (see Hooks.read_on_open). Yields (scene) ->
      # text; meth defaults to :pbStartScene; :timing => :before for openers that block in their own loop.
      def read_on_open(cname, meth = :pbStartScene, opts = {}, &blk); PokeAccess::Hooks.read_on_open(cname, meth, opts, &blk); end

      # Replaces a core reader's module method (or a game class's instance method) for this profile, listed in the
      # diag. Yields (receiver, original, args); call original.() to wrap instead of substitute.
      def override(target, meth, &body); PokeAccess::Hooks.override(target, meth, :tag => "game_#{@name}", &body); end

      # Hooks a top-level function (a bare def, possibly on Kernel), for plugin functions that are not class
      # methods (e.g. pbItemBall). timing is :before/:after/:around; no-op where the function is absent.
      def kernel(fname, timing = :before, &body); PokeAccess::Hooks.wrap_kernel(fname, "game_#{@name}_#{fname}", timing, &body); end

      # Adds a section to the diagnostic dump (and the debug menu's group); yields the output line array.
      def diag_section(name, group = :scene, &body); PokeAccess::Keys.register_diag_section(name, group, &body); end

      # Registers a remappable extra action (a raw key that would otherwise clash), reassignable from
      # the controls menu.
      def remap_extra(sym, default_vk, label); PokeAccess::Remap.register_extra(sym, default_vk, label); end

      # Runs a block once per frame in every scene, for menus the game drives from its own blocking loop.
      def poll_each_frame(&blk); PokeAccess::Frame.each_pulse(&blk); end

      # Defines or replaces a named part of the trainer line the info key speaks; yields the player, answers a
      # spoken fragment or nil. A new name joins the end of the order (see trainer_order).
      def trainer_part(key, &reader); PokeAccess::Info.set_trainer_part(key, &reader); end

      # Sets the trainer line's parts and their order; a default part left out is simply not spoken.
      def trainer_order(keys); PokeAccess::Config.trainer_parts = keys.map { |k| k.to_sym }; end

      # Declares a puzzle of a kind (:state, :grid or :facing) on a map or several, by a block of verbs (see
      # World::Mechanics::Builder).
      def mechanic(kind, maps, &blk); PokeAccess::World::Mechanics.define(kind, maps, &blk); end

      # Names events before the core does: the block gives a name, or nil to leave it (Locator.register_rule).
      def event_name(&blk); PokeAccess::Locator.register_rule(:name, &blk); end

      # Files the events the block accepts under category cat; the player's own category still wins.
      def event_category(cat, &blk); PokeAccess::Locator.register_rule(:category, cat, &blk); end

      # Leaves the events the block accepts out of the locator and the sonar.
      def event_hidden(&blk); PokeAccess::Locator.register_rule(:hidden, &blk); end

      # Words said after an event's name in the target line: the block gives them, or nil.
      def name_mark(&blk); PokeAccess::Locator.register_rule(:mark, &blk); end

      # Registers an overworld hazard sprite pattern so matching events read with a label and a hazard cue.
      def hazard(pattern, label); PokeAccess::Locator.register_hazard(pattern, label); end

      # Registers a warp-pad sprite pattern this game alone uses, so a transfer event wearing it counts as
      # an exit however it is triggered and gets the teleporter cue rather than the door's.
      def teleporter(pattern); PokeAccess::Locator.register_teleporter(pattern); end

      # Registers a script call that transfers the player (doors that skip the Transfer Player command); the
      # pattern must capture the destination map id.
      def transfer_script(pattern); PokeAccess::Locator.register_transfer_script(pattern); end

      # Declares an item this game hands a field move to (a surfboard for Surf), so the route finder and
      # the guide know the player can use the move without a Pokemon that knows it.
      def field_move_item(move, item); PokeAccess::FieldMoves.register_item(move, item); end

      # Declares tools this game takes, all in the bag, in place of a Pokemon that knows a field move, the move's
      # badge still asked; with only, they are the one way to use it (see FieldMoves.register_tool).
      def field_move_tool(move, items, only = false)
        PokeAccess::FieldMoves.register_tool(move, Array(items), only)
      end

      # Declares the check this game's own Surf makes for surfing with someone along (see Pathfinder.surf_company).
      def surf_company(kind, &lets); PokeAccess::Pathfinder.surf_company(kind, &lets); end

      # Declares an obstacle this game clears with an item of its own: the script its event runs, the locator label
      # it is named by, and the item (see Routes::Effects.field_gate).
      def field_gate(pattern, label, item); PokeAccess::Routes::Effects.field_gate(pattern, label, item); end

      # Says an obstacle without what clears it, for a game whose field-move rules nobody checked (the generic
      # profile; see FieldMoves.named?).
      def field_moves_unnamed; PokeAccess::FieldMoves.named = false; end

      # Declares a script call this game's event conditions test, and what it returns: the block gets the match
      # and the walk's context (see EventPages::ScriptCondition.register_atom).
      def script_condition(pattern, &reader); PokeAccess::EventPages::ScriptCondition.register_atom(pattern, &reader); end

      # Declares terrain of this game that moves the player once they arrive on it, owned by the tiles of owner
      # (see Routes::Moves.arrival_rule and owns?).
      def terrain_rule(owner = nil, &rule); PokeAccess::Routes::Moves.arrival_rule(owner, &rule); end

      # Declares tiles of this game where the direction key has to be kept held (see Routes::Moves.held_key_rule).
      def held_key_ground(owner = nil, &rule); PokeAccess::Routes::Moves.held_key_rule(owner, &rule); end

      # Declares terrain of this game the player leaves by a move of its own (see Routes::Moves.leave_rule).
      def terrain_exit(owner = nil, &rule); PokeAccess::Routes::Moves.leave_rule(owner, &rule); end

      # Declares something this game lets the player do to get past what stops a walk, for the assisted
      # route, owned by the tiles in front of owner (see Routes::Moves.assist_source).
      def assisted_step(owner = nil, &blk); PokeAccess::Routes::Moves.assist_source(owner, &blk); end

      # Declares that this game's player passability reads nothing an event can change but the map's tiles, tileset
      # and events, as checked against its scripts (see World::Probe.plain!).
      def plain_passability; PokeAccess::World::Probe.plain!; end

      # Declares that this game pushes its pushables after the plain passable? check, not the strict one (see
      # World::Probe.loose_pushes!).
      def loose_pushes; PokeAccess::World::Probe.loose_pushes!; end

      # Declares a script this game moves its pushables with that also lets the player pull them, the action button
      # facing one (see Routes::Effects.pull_script).
      def pull_script(pattern); PokeAccess::Routes::Effects.pull_script(pattern); end

      # Declares a script this game moves its pushables with, ahead of the stock ones: the field move it needs (nil for
      # none) and, with a block, the condition it moves them under (see Routes::Effects.push_script).
      def push_script(pattern, move = nil, &ready); PokeAccess::Routes::Effects.push_script(pattern, move, &ready); end

      # Maps picture file names to spoken text, for screens that light one picture per option.
      def picture_texts(map); PokeAccess::PictureCues::TEXTS.merge!(map); end

      # picture_texts for a game shipped as per-language builds: each value maps build language => text, resolved
      # against the running build (GameLang); base is the pictures' own language, the fallback.
      def picture_texts_multibuild(base, map)
        map.each_key { |k| PokeAccess::PictureCues::BASE_LANG[k.to_s] = base }
        PokeAccess::PictureCues::TEXTS.merge!(map)
      end

      # Registers a handler invoked when a picture is shown. Yields (picture_name, args).
      def on_picture(&blk); PokeAccess::PictureCues.register(&blk); end
    end
  end
end
