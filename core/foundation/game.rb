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
    rescue StandardError
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
      def poll_each_frame(&blk); PokeAccess::Keys.on_frame(&blk); end

      # Defines or replaces a named part of the trainer line the info key speaks; yields the player, answers a
      # spoken fragment or nil. A new name joins the end of the order (see trainer_order).
      def trainer_part(key, &reader); PokeAccess::Info.set_trainer_part(key, &reader); end

      # Sets the trainer line's parts and their order; a default part left out is simply not spoken.
      def trainer_order(keys); PokeAccess::Config.trainer_parts = keys.map { |k| k.to_sym }; end

      # Registers a map puzzle (see Puzzles.register).
      def puzzle(map_id, opts); PokeAccess::Puzzles.register(map_id, opts); end

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

      # Declares a script call this game's event conditions test, and what it returns: the block gets the match
      # and the walk's context (see EventPages::ScriptCondition.register_atom).
      def script_condition(pattern, &reader); PokeAccess::EventPages::ScriptCondition.register_atom(pattern, &reader); end

      # Declares terrain of this game that moves the player once they arrive on it (see Pathfinder.arrival_rule).
      def terrain_rule(&rule); PokeAccess::Pathfinder.arrival_rule(&rule); end

      # Declares tiles of this game where the direction key has to be kept held (see Pathfinder.held_key_rule).
      def held_key_ground(&rule); PokeAccess::Pathfinder.held_key_rule(&rule); end

      # Declares terrain of this game the player leaves by a move of its own (see Pathfinder.leave_rule).
      def terrain_exit(&rule); PokeAccess::Pathfinder.leave_rule(&rule); end

      # Declares something this game lets the player do to get past what stops a walk, for the assisted
      # route (see Pathfinder.assist_source).
      def assisted_step(&blk); PokeAccess::Pathfinder.assist_source(&blk); end

      # Declares that this game's player passability reads nothing an event can change but the map's tiles, tileset
      # and events, as checked against its scripts (see Pathfinder.plain_passability).
      def plain_passability; PokeAccess::Pathfinder.plain_passability; end

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
