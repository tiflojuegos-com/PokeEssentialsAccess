# Tiny test framework: a spec registers a named Suite (a block of assertions); the runner executes each
# suite under a fresh reset and tallies pass/fail with the failing label, suite and got/want for tracing.
# No external gem -- the project avoids dependencies, and this keeps full control of the CI output format.
module Suite
  @suites = []

  # Registers a named suite. Discovered and run by run_all.
  def self.define(name, &body)
    @suites.push([name, body])
  end

  # All registered suites as [name, body] pairs.
  def self.all
    @suites
  end
end

# Records assertion results for the current suite. Never raises, so one failing assert cannot abort the
# rest of its suite; the runner decides the exit code from the fail count.
module Assert
  class << self
    attr_accessor :suite, :pass, :fail, :failures
  end
  @pass = 0
  @fail = 0
  @failures = []

  # Records a pass or a fail (with its suite, label and detail) for the running suite.
  def self.check(label, cond, detail = nil)
    if cond
      @pass += 1
    else
      @fail += 1
      line = "[#{@suite}] #{label}"
      line += " :: #{detail}" if detail
      @failures.push(line)
    end
  end
end

# Asserts two values are equal.
def eq(label, got, want)
  Assert.check(label, got == want, "got #{got.inspect} want #{want.inspect}")
end

# Asserts a value matches a regular expression.
def match(label, got, re)
  Assert.check(label, (got.to_s =~ re ? true : false), got.inspect)
end

# Asserts a value is truthy.
def truthy(label, got)
  Assert.check(label, got ? true : false, got.inspect)
end

# Asserts a value is falsy.
def falsy(label, got)
  Assert.check(label, got ? false : true, got.inspect)
end

# Asserts that some captured spoken line matches re since the last clear.
def spoke(label, re)
  Assert.check(label, SpeakCapture.lines.any? { |l| l =~ re }, SpeakCapture.lines.inspect)
end

# Asserts that exactly one captured spoken line matches re (the dedup / no-spam workhorse).
def spoke_once(label, re)
  Assert.check(label, SpeakCapture.lines.count { |l| l =~ re } == 1, SpeakCapture.lines.inspect)
end

# Asserts that no captured line matches re since the last clear.
def not_spoke(label, re)
  Assert.check(label, SpeakCapture.lines.none? { |l| l =~ re }, SpeakCapture.lines.inspect)
end

# Asserts nothing was spoken since the last clear.
def silent(label)
  Assert.check(label, SpeakCapture.lines.empty?, SpeakCapture.lines.inspect)
end
