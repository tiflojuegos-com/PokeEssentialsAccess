module PokeAccess
  # Rejuvenation's password lists (PasswordEntry#entryForPasswords, at a new game and on the PC with Data Chips): each
  # password row starts with its state, "> " when it is on, "~ " when a bulk password is only partly on and four spaces
  # when it is off, marks a screen reader leaves unsaid; so each password is said with its state, the other rows as
  # painted. The bulk passwords' list opens inside the other.
  module RejuvPasswords
    ON = /\A> (\S.*)\z/m
    PARTLY = /\A~ (\S.*)\z/m
    OFF = /\A {4}(\S.*)\z/m

    @depth = 0

    # Runs a list of passwords.
    def self.listing
      @depth += 1
      yield
    ensure
      @depth -= 1
    end

    # A password row as its name and state, or nil for any other row and outside the lists.
    def self.row(t)
      return nil unless @depth > 0 && t.is_a?(String)
      return "#{$1}, #{PokeAccess::I18n.t(:val_on)}" if t =~ ON
      return "#{$1}, #{PokeAccess::I18n.t(:rj_pw_partly)}" if t =~ PARTLY
      return "#{$1}, #{PokeAccess::I18n.t(:val_off)}" if t =~ OFF
      nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  around("PasswordEntry", :entryForPasswords, :optional => true) do |_s, nxt, _a|
    PokeAccess::RejuvPasswords.listing { nxt.call }
  end

  override("PokeAccess::Menus", :checkbox_row) do |_mod, original, args|
    PokeAccess::RejuvPasswords.row(args[0]) || original.call
  end
end
