module PokeAccess
  # The passwords menu of the engine Reborn and Desolation share (pbPasswordsMenu: the known passwords, and adding
  # one). Its list marks an active password with "> " and an inactive one with four spaces, marks a screen reader
  # leaves unsaid, so each password row is said with its state; the other rows ([Exit], [Add password]) go on as
  # painted.
  module PasswordsRV
    ACTIVE = /\A> (\S.*)\z/m
    INACTIVE = /\A {4}(\S.*)\z/m

    @open = false

    # Runs the list as the passwords menu.
    def self.listing
      @open = true
      yield
    ensure
      @open = false
    end

    # A password row as its name and state, or nil for any other row and outside the menu.
    def self.row(t)
      return nil unless @open && t.is_a?(String)
      return "#{$1}, #{PokeAccess::I18n.t(:val_on)}" if t =~ ACTIVE
      return "#{$1}, #{PokeAccess::I18n.t(:val_off)}" if t =~ INACTIVE
      nil
    end

    # Hooks the list where the game has it (Rejuvenation has none).
    def self.bind
      fn = :pbSelectPasswordToBeToggled
      return unless Object.private_method_defined?(fn) || Object.method_defined?(fn)
      PokeAccess::Hooks.wrap_kernel(fn.to_s, "rv_passwords", :around) do |_args, nxt|
        PokeAccess::PasswordsRV.listing { nxt.call }
      end
      PokeAccess::Hooks.override("PokeAccess::Menus", :checkbox_row, :tag => "rv_passwords") do |_mod, original, args|
        PokeAccess::PasswordsRV.row(args[0]) || original.call
      end
    end
  end
end

PokeAccess::PasswordsRV.bind if PokeAccess::DataRV.engine?
