# frozen_string_literal: true

require "open3"
require "fileutils"

FileUtils.mkdir_p("suite-logs")

def run_logged(name, *command)
  output, status = Open3.capture2e(*command)
  File.binwrite("suite-logs/#{name}.log", output)
  puts output
  [output, status]
end

path = "lib/bootsnap/compile_cache/iseq.rb"
corrected = File.binread(path)
original, status = Open3.capture2("git", "show", "384fe647c1273061173c2b4678b194ddc64de622:#{path}")
raise "Original source unavailable" unless status.success?
_, status = run_logged("compile", "bundle", "exec", "rake", "compile")
raise "Extension compilation failed" unless status.success?

begin
  File.binwrite(path, original)
  output, status = run_logged("original-regression", "bundle", "exec", "ruby", "-Itest",
    "test/compile_cache/iseq_cache_test.rb", "--name", "test_source_encoding_does_not_depend_on_default_internal")
  unless !status.success? && output.include?("Encoding::UndefinedConversionError") &&
      output.match?(/1 runs, \d+ assertions, 0 failures, 1 errors, 0 skips/)
    raise "Original source did not reproduce the expected encoding regression"
  end
  puts "BOOTSNAP_UPSTREAM_REGRESSION_REPRODUCED"
ensure
  File.binwrite(path, corrected)
end

_, status = run_logged("corrected-suite", "bundle", "exec", "rake")
raise "Corrected full suite failed" unless status.success?
puts "BOOTSNAP_REVISED_REGRESSION_AND_SUITE_PASSED #{RUBY_DESCRIPTION}"
