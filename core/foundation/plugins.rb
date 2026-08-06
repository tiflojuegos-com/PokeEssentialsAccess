module PokeAccess
  # What the mod knows about THIRD-PARTY plugin readers (the plugins/ layer). The loader fills this in as it
  # loads them; nothing here loads anything. The dependency runs this way on purpose: the loader loads the
  # core, so the core must not reach back into the loader to ask what happened.
  module Plugins
    # The plugin readers loaded this session.
    def self.loaded; @loaded ||= []; end

    # Records one, called by the loader as it evaluates each declared reader.
    def self.note_loaded(name); loaded.push(name.to_s) unless loaded.include?(name.to_s); end

    # name => the probe that gives that plugin away, straight from plugins/manifest.rb: a class name, or the
    # "Class#method" form for a plugin that adds a method to a class the engine already has.
    def self.table; @table ||= {}; end
    def self.table=(t); @table = t.is_a?(Hash) ? t : {}; end


    # The plugins the GAME itself says it has, from Essentials' own PluginManager: "name version" each.
    #
    # This is the other half of the picture the diagnostic could not show. Our own two lists answer "what
    # did the mod load" and "what did a profile forget"; both are limited to plugins the mod already knows.
    # This one is the game's own register, so a bug report from a fangame nobody has a script dump of still
    # names the plugins in play -- including the ones we have never heard of, which is exactly the set a
    # silent screen is most likely to belong to.
    #
    # nil, not an empty list, where there is no PluginManager: the older games paste plugin code straight
    # into the script list, so nothing registers and "none installed" would be a lie.
    def self.game_plugins
      pm = PokeAccess.const_at("PluginManager")
      return nil unless pm && pm.respond_to?(:plugins)
      names = (pm.plugins rescue nil)
      return nil unless names.is_a?(Array)
      names.map do |n|
        v = (pm.version(n) rescue nil)
        (v && !v.to_s.empty?) ? "#{n} #{v}" : n.to_s
      end.sort
    rescue StandardError
      nil
    end

    # Plugins this game HAS whose reader nobody declared, so they are running mute.
    #
    # Declaring by hand has exactly one weak spot -- forgetting -- and forgetting is silent: the only
    # symptom is a screen that says nothing, which is precisely what a blind player cannot diagnose. Asking
    # the running game whether the plugin is there turns that into a line in the diagnostic, and therefore
    # into a line in any session recording, even on fangames nobody has a script dump of.
    #
    # The question goes through Engine.has? rather than a bare constant lookup so a probe can also name a
    # METHOD. A plugin that reopens an engine class instead of adding its own is invisible to a class check
    # -- the class is there in every game, plugin or not -- and those are the ones a hand-written list is
    # likeliest to miss.
    def self.undeclared
      out = []
      table.each do |name, probe|
        next if loaded.include?(name.to_s)
        next unless (PokeAccess::Engine.has?(probe.to_s) rescue false)
        out.push(name.to_s)
      end
      out.sort
    end
  end
end
