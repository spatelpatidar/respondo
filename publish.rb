# frozen_string_literal: true

require "fileutils"

# ─────────────────────────────────────────────────────────────────────────────
# publish.rb — Cross-platform publish pipeline (Windows / Mac / Linux)
# Usage: ruby publish.rb
# ─────────────────────────────────────────────────────────────────────────────

def colorize(text, code) = "\e[#{code}m#{text}\e[0m"
def green(t)  = colorize(t, 32)
def blue(t)   = colorize(t, 34)
def red(t)    = colorize(t, 31)

def run!(cmd)
  puts blue("  $ #{cmd}")
  system(cmd) || abort(red("❌  Command failed: #{cmd}"))
end

puts blue("=" * 60)
puts blue("   Starting Publish Pipeline for Respondo")
puts blue("=" * 60)

# Step 1: Clean → move old gems to Gems/
puts "\n#{blue("Step 1: Moving old gem files to Gems/...")}"
run!("bundle exec rake publish:clean")
puts green("✅  Clean done.")

# Step 2: Run specs
puts "\n#{blue("Step 2: Running RSpec suite...")}"
run!("bundle exec rake publish:spec")
puts green("✅  Specs passed.")

# Step 3: Build gem
puts "\n#{blue("Step 3: Building gem...")}"
run!("bundle exec rake publish:build")

# Step 4: Push to RubyGems
puts "\n#{blue("Step 4: Pushing to RubyGems...")}"
gem_files = Dir["*.gem"]
if gem_files.empty?
  abort red("❌  No .gem file found. Build might have failed.")
end
run!("bundle exec rake publish:push")

puts "\n#{green("=" * 60)}"
puts green("🎉  Done! Respondo is now live on RubyGems.org")
puts green("=" * 60)