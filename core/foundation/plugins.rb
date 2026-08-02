module PokeAccess
  # What the mod knows about THIRD-PARTY plugin readers (the plugins/ layer). The loader fills this in as it
  # loads them; nothing here loads anything. The dependency runs this way on purpose: the loader loads the
  # core, so the core must not reach back into the loader to ask what happened.
  module Plugins
    # The plugin readers loaded this session.
    def self.loaded; @loaded ||= []; end

    # Records one, called by the loader as it evaluates each declared reader.
    def self.note_loaded(name); loaded.push(name.to_s) unless loaded.include?(name.to_s); end

    # name => the class whose presence gives that plugin away, straight from plugins/manifest.rb.
    def self.table; @table ||= {}; end
    def self.table=(t); @table = t.is_a?(Hash) ? t : {}; end

    # Plugins this game HAS whose reader nobody declared, so they are running mute.
    #
    # Declaring by hand has exactly one weak spot -- forgetting -- and forgetting is silent: the only
    # symptom is a screen that says nothing, which is precisely what a blind player cannot diagnose. Asking
    # the running game whether the plugin's own class is there turns that into a line in the diagnostic, and
    # therefore into a line in any session recording, even on fangames nobody has a script dump of.
    def self.undeclared
      out = []
      table.each do |name, klass|
        next if loaded.include?(name.to_s)
        next if (PokeAccess.const_at(klass.to_s) rescue nil).nil?
        out.push(name.to_s)
      end
      out.sort
    end
  end
end
