module PokeAccess
  # Adapter API: the declarative surface a game profile uses to plug into the toolkit. Each method
  # forwards to a registration point, so it is a thin layer over the raw calls (which still work).
  module Game
    @profiles = []

    # The identifiers of the profiles defined so far (diagnostics only).
    def self.profiles; @profiles; end

    # Declares a game profile; the block registers its hooks/readers/puzzles/config. Additive and
    # repeatable (a game may use several define blocks).
    def self.define(name = nil, &blk)
      @profiles << name if name && !@profiles.include?(name)
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

      # Merges a game's own entries into one of the core name tables -- :status_names, :weather_names,
      # :field_weather_names -- added to the defaults, never replacing them. Fangames extend these engine
      # enums past the vanilla range, and the ids they add CLASH between games (field weather 8 is ShadowSky
      # in one and Charco in another), so each profile declares only its own; an unmapped id reads as nothing
      # rather than as somebody else's weather. Values are i18n symbols, or literals for a Spanish-only game.
      def names(table, map); PokeAccess::Config.send(table).merge!(map); end

      # Registers a focused-option reader for a command window. Yields (window, index) -> option text.
      def screen_reader(cname, &blk); PokeAccess::Menus.def_extractor(cname, &blk); end

      # Runs the block AFTER a method fires. Yields (instance, result, args). opts reaches the hook
      # untouched, so a profile has the same options the core does: :optional for a method legitimately
      # absent on some builds of the game (skipped silently instead of landing in Hooks.missing) and
      # :hook_container for an opener that delegates the announcement to hooked methods it drives.
      def after(cname, meth, opts = {}, &blk); PokeAccess::Hooks.after_hook(cname, meth, opts, &blk); end

      # Runs the block BEFORE a method fires. Yields (instance, args). opts as in after (:optional).
      def before(cname, meth, opts = {}, &blk); PokeAccess::Hooks.before_hook(cname, meth, opts, &blk); end

      # Wraps a method: the block runs around the original and must call the yielded nxt. Yields
      # (instance, nxt, args). opts as in after (:optional).
      def around(cname, meth, opts = {}, &body); PokeAccess::Hooks.around_hook(cname, meth, opts, &body); end

      # Speaks the block's text when a scene opens, queued (see Hooks.read_on_open). Yields (scene) ->
      # text; meth defaults to :pbStartScene; :timing => :before for openers that block in their own loop.
      def read_on_open(cname, meth = :pbStartScene, opts = {}, &blk); PokeAccess::Hooks.read_on_open(cname, meth, opts, &blk); end

      # REPLACES a core reader's module method (or a game class's instance method) for this profile,
      # declaring the intent -- the diag lists every override, so the core is never steamrolled in silence.
      # Yields (receiver, original, args); call original.() to wrap instead of substitute.
      def override(target, meth, &body); PokeAccess::Hooks.override(target, meth, :tag => "game_#{@name}", &body); end

      # Hooks a top-level function (a bare def, possibly on Kernel), for plugin functions that are not class
      # methods (e.g. pbItemBall). timing is :before/:after/:around; no-op where the function is absent.
      def kernel(fname, timing = :before, &body); PokeAccess::Hooks.wrap_kernel(fname, "game_#{@name}_#{fname}", timing, &body); end

      # Contributes a section to the diagnostic dump (and the debug menu's group), so a game's own
      # mechanics can be diagnosed without the core knowing the game. Yields the output line array.
      def diag_section(name, group = :scene, &body); PokeAccess::Keys.register_diag_section(name, group, &body); end

      # Registers a remappable extra action (a raw key that would otherwise clash), reassignable from
      # the controls menu.
      def remap_extra(sym, default_vk, label); PokeAccess::Remap.register_extra(sym, default_vk, label); end

      # Runs a block once per frame in every scene, for menus the game drives from its own blocking loop.
      def poll_each_frame(&blk); PokeAccess::Keys.on_frame(&blk); end

      # Registers a map puzzle (see Puzzles.register).
      def puzzle(map_id, opts); PokeAccess::Puzzles.register(map_id, opts); end

      # Registers an overworld hazard sprite pattern so matching events read with a label and a hazard cue.
      def hazard(pattern, label); PokeAccess::Locator.register_hazard(pattern, label); end

      # Maps picture file names to spoken text, for screens that light one picture per option.
      def picture_texts(map); PokeAccess::PictureCues::TEXTS.merge!(map); end

      # picture_texts for a game shipped as several per-language builds: each value is a hash of build
      # language => transcription, resolved at speak time against what the RUNNING build declares
      # (GameLang). base names the language the pictures were authored in -- the fallback when a build
      # declares a language nobody transcribed.
      def picture_texts_multibuild(base, map)
        map.each_key { |k| PokeAccess::PictureCues::BASE_LANG[k.to_s] = base }
        PokeAccess::PictureCues::TEXTS.merge!(map)
      end

      # Registers a handler invoked when a picture is shown. Yields (picture_name, args).
      def on_picture(&blk); PokeAccess::PictureCues.register(&blk); end
    end
  end
end
