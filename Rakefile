# frozen_string_literal: true

require "rake"
require "rspec/core/rake_task"
require_relative "lib/respondo/version"

RSpec::Core::RakeTask.new(:spec)
task default: :spec

# ─────────────────────────────────────────────────────────────────────────────
# publish — runs spec → build → contents check → push to RubyGems
#
# Usage:
#   bundle exec rake publish          # full pipeline (spec + build + push)
#   bundle exec rake publish:build    # build only
#   bundle exec rake publish:push     # push only (skips spec + build)
# ─────────────────────────────────────────────────────────────────────────────

GEM_NAME    = "respondo"
GEM_VERSION = Respondo::VERSION
GEM_FILE    = "#{GEM_NAME}-#{GEM_VERSION}.gem"
GEMSPEC     = "#{GEM_NAME}.gemspec"

namespace :publish do

  desc "Run RSpec test suite"
  task :spec do
    puts "\n#{"=" * 60}"
    puts "  Running specs for #{GEM_NAME} v#{GEM_VERSION}"
    puts "=" * 60
    sh "bundle exec rspec --format documentation" do |ok, _|
      abort "\n❌  Specs failed — aborting publish." unless ok
    end
    puts "\n✅  All specs passed.\n"
  end

  desc "Build #{GEM_FILE}"
  task :build do
    puts "\n#{"=" * 60}"
    puts "  Building #{GEM_FILE}"
    puts "=" * 60
    sh "gem build #{GEMSPEC}" do |ok, _|
      abort "\n❌  Build failed." unless ok
    end
    puts "\n✅  Built: #{GEM_FILE}\n"

    puts "\n📦  Contents:"
    puts "-" * 40
    # ✅ Works on Windows — reads the .gem file directly
    require "rubygems/package"
    Gem::Package.new(GEM_FILE).contents.sort.each { |f| puts f }
    puts "-" * 40
  end

  desc "Push #{GEM_FILE} to RubyGems.org"
  task :push do
    abort "❌  #{GEM_FILE} not found — run `rake publish:build` first." \
      unless File.exist?(GEM_FILE)

    puts "\n#{"=" * 60}"
    puts "  Pushing #{GEM_FILE} to RubyGems.org"
    puts "=" * 60
    sh "gem push #{GEM_FILE}" do |ok, _|
      abort "\n❌  Push failed." unless ok
    end
    puts "\n🚀  #{GEM_NAME} v#{GEM_VERSION} published successfully!\n"
  end

  desc "Move built .gem files to Gems/ folder"
  task :clean do
    require "fileutils"
    FileUtils.mkdir_p("Gems")
    Dir["*.gem"].each do |f|
      FileUtils.mv(f, "Gems/#{f}")
      puts "📦  Moved #{f} → Gems/#{f}"
    end
  end

end

# Full pipeline: spec → build → push
desc "Run specs, build, and publish #{GEM_NAME} v#{GEM_VERSION} to RubyGems.org"
task publish: ["publish:spec", "publish:build", "publish:push"] do
  puts "\n🎉  Done! #{GEM_NAME} v#{GEM_VERSION} is live on RubyGems.org\n"
end