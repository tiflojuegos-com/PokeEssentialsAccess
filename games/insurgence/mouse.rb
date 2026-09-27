module PokeAccess
  # Insurgence's pointer (Mouse.getMousePos and Input.releaseex?): a keyboard route arms one click at a point, which
  # the next pointer and release reads answer once each; a failed pointer read answers no pointer.
  module InsurgenceMouse
    # Arms a click at [x, y] (nil clears it).
    def self.click_at(xy)
      @point = xy
      @release = !xy.nil?
    end

    def self.clear
      @point = nil
      @release = false
    end

    # The armed point, taken; nil when none.
    def self.take_point
      pt = @point
      @point = nil
      pt
    end

    # Whether an armed release is pending, taken.
    def self.take_release
      r = @release ? true : false
      @release = false
      r
    end

    # Whether a key code is the left mouse button's.
    def self.left?(key)
      key == (Input::LeftMouseKey rescue 1)
    end
  end
end

PokeAccess::Hooks.wrap_singleton("Mouse", :getMousePos, "hook_ins_mouse_pos", :around) do |_args, nxt|
  PokeAccess::InsurgenceMouse.take_point || (nxt.call rescue nil)
end
PokeAccess::Hooks.wrap_singleton("Input", :releaseex?, "hook_ins_mouse_release", :around) do |args, nxt|
  (PokeAccess::InsurgenceMouse.left?(args[0]) && PokeAccess::InsurgenceMouse.take_release) ? true : nxt.call
end
