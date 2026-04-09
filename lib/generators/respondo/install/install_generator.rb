# frozen_string_literal: true

require "rails/generators"

module Respondo
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Interactive setup — creates config/initializers/respondo.rb with your preferences."

      # We bypass Thor's `say` entirely for all display output and use
      # $stdout.puts / print directly. This prevents Thor from re-echoing
      # buffered output and causing duplicate lines in the terminal.

      def run_interactive_setup
        # out LOGO
        out logo_with_version
        out divider
        out line("  This wizard will generate config/initializers/respondo.rb")
        out line("  tailored to your project — no need to read the full README.")
        out blank
        out line(yellow("  All settings can be changed later by editing the initializer."))
        out divider
        out blank

        unless confirm("  Ready to configure Respondo? (y/n) ")
          out blank
          out line(yellow("  Skipped. Run this again any time:"))
          out line("    rails generate respondo:install")
          out blank
          return
        end

        @cfg = {}

        step_project_info
        step_messages
        step_request_id
        step_camelize
        step_default_meta
        step_serializer

        print_summary
        write_initializer
        print_done
      end

      private

      # =========================================================================
      # Steps
      # =========================================================================

      def step_project_info
        out section("Project Info")
        out line("  Project / app name")
        out line(yellow("  (Used as a comment header in the initializer)"))
        @cfg[:project_name] = prompt_default(Rails.application.class.module_parent_name)

        out blank
        out line("  API version")
        out line(yellow("  (e.g. v1 — added to every response meta block)"))
        @cfg[:api_version] = prompt_default("v1")
      end

      def step_messages
        out section("Response Messages")
        out line("  Fallback messages used when you don't pass message: explicitly.")
        out blank

        out line("  Default success message")
        @cfg[:default_success_message] = prompt_default("Success")

        out blank
        out line("  Default error message")
        @cfg[:default_error_message] = prompt_default("An error occurred")
      end

      def step_request_id
        out section("Request ID")
        out line("  When enabled, Rails request.request_id is included in every")
        out line("  response meta block — useful for log correlation and debugging.")
        out blank
        @cfg[:include_request_id] = confirm("  Include request_id in every response? (y/n) ")
      end

      def step_camelize
        out section("Key Format")
        out line("  When enabled, all JSON keys are camelCased:")
        out line(yellow('    { "createdAt": "...", "userId": 1 }'))
        out line("  Recommended for Flutter, React, and JavaScript clients.")
        out blank
        @cfg[:camelize_keys] = confirm("  Camelize all response keys? (y/n) ")
      end

      def step_default_meta
        out section("Global Meta Fields")
        out line("  Static key=value pairs merged into the meta block of EVERY response.")
        out line("  Example:  platform=mobile   environment=production")
        out blank
        out line(yellow("  Note: api_version from above is already included automatically."))
        out blank

        @cfg[:default_meta] = {}
        return unless confirm("  Add extra global meta fields? (y/n) ")

        out blank
        out line("  Enter key=value one at a time. Blank line to finish.")
        out blank

        loop do
          $stdout.print cyan("    key=value › ")
          raw = $stdin.gets.to_s.strip
          break if raw.empty?

          unless raw.include?("=")
            out line(yellow("    Use key=value format (e.g. platform=mobile). Skipping."))
            next
          end

          key, value = raw.split("=", 2)

          next out line(yellow("    Use key=value format.")) if key.nil? || key.strip.empty?

          k = key.strip
          v = (value || "").strip
          @cfg[:default_meta][k] = v
          out line(green("    ✓  #{k}: #{v.inspect}"))
        end
      end

      def step_serializer
        out section("Custom Serializer")
        out line("  By default Respondo serializes ActiveRecord models, collections,")
        out line("  hashes, and arrays automatically.")
        out blank
        out line("  You can override with any callable: ->(obj) { MySerializer.new(obj).as_json }")
        out blank
        @cfg[:custom_serializer] = confirm("  Add a custom serializer stub? (y/n) ")
      end

      # =========================================================================
      # Summary
      # =========================================================================

      def print_summary
        out blank
        out divider
        out line(cyan("  Configuration Summary"))
        out divider
        out blank
        summary_row "Project",            @cfg[:project_name]
        summary_row "API version",        @cfg[:api_version]
        summary_row "Success message",    @cfg[:default_success_message]
        summary_row "Error message",      @cfg[:default_error_message]
        summary_row "Include request_id", @cfg[:include_request_id]
        summary_row "Camelize keys",      @cfg[:camelize_keys]
        summary_row "Custom serializer",  @cfg[:custom_serializer]

        unless @cfg[:default_meta].empty?
          out blank
          out line("  Global meta:")
          @cfg[:default_meta].each { |k, v| out line("    #{k}: #{v.inspect}") }
        end

        out blank
        out divider
        out blank
      end

      def summary_row(label, value)
        bool_true = value == true
        val_str   = bool_true ? green(value.inspect) : yellow(value.inspect)
        out "  #{("#{label}:").ljust(24)}#{val_str}\n"
      end

      # =========================================================================
      # Write file
      # =========================================================================

      def write_initializer
        dir  = File.join(destination_root, "config", "initializers")
        path = File.join(dir, "respondo.rb")
        FileUtils.mkdir_p(dir)
        File.write(path, build_content)
        out line(green("  ✅  Created config/initializers/respondo.rb"))
        out blank
      end

      def build_content
        meta = { "api_version" => @cfg[:api_version] }.merge(@cfg[:default_meta])
        b    = Lines.new

        b << "# frozen_string_literal: true"
        b << ""
        b << "# Respondo initializer — #{@cfg[:project_name]}"
        b << "# Generated by: rails generate respondo:install"
        b << "# Respondo version: #{Respondo::VERSION}"
        b << "# Docs: https://github.com/your-org/respondo"
        b << ""
        b << "Respondo.configure do |config|"
        b << ""
        b << "  # ── Messages ─────────────────────────────────────────────────────────"
        b << "  # Fallback when render_success / render_error is called without message:"
        b << "  config.default_success_message = #{@cfg[:default_success_message].inspect}"
        b << "  config.default_error_message   = #{@cfg[:default_error_message].inspect}"
        b << ""
        b << "  # ── Request ID ───────────────────────────────────────────────────────"
        b << "  # Includes Rails request.request_id in every response meta block."
        b << "  config.include_request_id = #{@cfg[:include_request_id]}"
        b << ""
        b << "  # ── Key Format ───────────────────────────────────────────────────────"
        b << "  # CamelCase all JSON keys — recommended for Flutter / JS clients."
        b << "  config.camelize_keys = #{@cfg[:camelize_keys]}"
        b << ""
        b << "  # ── Global Meta ──────────────────────────────────────────────────────"
        b << "  # Static fields merged into the meta block of every response."

        if meta.empty?
          b << "  config.default_meta = {}"
        else
          b << "  config.default_meta = {"
          meta.each_with_index do |(k, v), i|
            comma = i < meta.size - 1 ? "," : ""
            b << "    #{k}: #{v.inspect}#{comma}"
          end
          b << "  }"
        end

        if @cfg[:custom_serializer]
          b << ""
          b << "  # ── Custom Serializer ────────────────────────────────────────────────"
          b << "  # Replace the lambda body with your own serialization logic."
          b << "  # Examples:"
          b << "  #   ActiveModelSerializers: ->(obj) { SomeSerializer.new(obj).as_json }"
          b << "  #   Blueprinter:            ->(obj) { UserBlueprint.render_as_hash(obj) }"
          b << "  #"
          b << "  # config.serializer = ->(obj) { MySerializer.new(obj).as_json }"
        end

        b << ""
        b << "end"
        b << ""
        b.to_s
      end

      # =========================================================================
      # Done
      # =========================================================================

      def print_done
        out divider
        out blank
        out line(cyan("  🎉  Respondo is ready!"))
        out blank
        out line("  Next steps:")
        out line("    1. Review   config/initializers/respondo.rb")
        out line("    2. Use      render_success / render_error in your controllers")
        out line("    3. Re-run   rails generate respondo:install  to regenerate")
        out blank
        out divider
        out blank
      end

      # =========================================================================
      # Output primitives — all output goes through $stdout, never through Thor
      # =========================================================================

      def out(str)
        $stdout.print str
        $stdout.flush
      end

      def line(str) = "#{str}\n"
      def blank     = "\n"

      def divider
        "  #{cyan("─" * 68)}\n"
      end

      def section(title)
        dashes = "─" * [0, 54 - title.length].max
        "\n  #{cyan("┌─ #{title} #{dashes}┐")}\n\n"
      end

      def prompt_default(default)
        $stdout.print "  #{cyan("›")} #{yellow("[#{default}]")}: "
        $stdout.flush
        result = $stdin.gets.to_s.strip
        result.empty? ? default.to_s : result
      end

      def confirm(question)
        $stdout.print question
        $stdout.flush
        $stdin.gets.to_s.strip.downcase.start_with?("y")
      end

      # =========================================================================
      # ANSI colors
      # =========================================================================

      def cyan(t)   = "\e[36m#{t}\e[0m"
      def green(t)  = "\e[32m#{t}\e[0m"
      def yellow(t) = "\e[33m#{t}\e[0m"

      # =========================================================================
      # ASCII logo
      # =========================================================================

      LOGOS = <<~'LOGO'

          ██████╗ ███████╗███████╗██████╗  ██████╗ ███╗   ██╗██████╗  ██████╗
          ██╔══██╗██╔════╝██╔════╝██╔══██╗██╔═══██╗████╗  ██║██╔══██╗██╔═══██╗
          ██████╔╝█████╗  ███████╗██████╔╝██║   ██║██╔██╗ ██║██║  ██║██║   ██║
          ██╔══██╗██╔══╝  ╚════██║██╔═══╝ ██║   ██║██║╚██╗██║██║  ██║██║   ██║
          ██║  ██║███████╗███████║██║     ╚██████╔╝██║ ╚████║██████╔╝╚██████╔╝
          ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═══╝╚═════╝  ╚═════╝

                        Smart JSON API Response Formatter for Rails
                                     ─── v#{Respondo::VERSION} ───

      LOGO

      def logo_with_version
        green(<<~LOGO)
          
          ██████╗ ███████╗███████╗██████╗  ██████╗ ███╗   ██╗██████╗  ██████╗
          ██╔══██╗██╔════╝██╔════╝██╔══██╗██╔═══██╗████╗  ██║██╔══██╗██╔═══██╗
          ██████╔╝█████╗  ███████╗██████╔╝██║   ██║██╔██╗ ██║██║  ██║██║   ██║
          ██╔══██╗██╔══╝  ╚════██║██╔═══╝ ██║   ██║██║╚██╗██║██║  ██║██║   ██║
          ██║  ██║███████╗███████║██║     ╚██████╔╝██║ ╚████║██████╔╝╚██████╔╝
          ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═══╝╚═════╝  ╚═════╝

                      Smart JSON API Response Formatter for Rails
                                ─── v#{Respondo::VERSION} ───

        LOGO
      end
      # =========================================================================
      # Simple line buffer for building file content
      # =========================================================================

      class Lines
        def initialize = (@buf = [])
        def <<(str)    = @buf << str
        def to_s       = @buf.join("\n") + "\n"
      end
    end
  end
end