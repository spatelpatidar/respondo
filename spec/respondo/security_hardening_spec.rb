# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "stringio"
require "open3"

# Regression tests for the issues found in the v2.1.3 security assessment.
RSpec.describe "security hardening" do
  # -------------------------------------------------------------------------
  # F1 — generator code injection
  # -------------------------------------------------------------------------
  describe "F1: install generator key handling" do
    require "rails/generators"
    require "rails/generators/base"
    require "generators/respondo/install/install_generator"

    let(:dest) { Dir.mktmpdir("respondo_sec_") }
    after      { FileUtils.rm_rf(dest) }

    before do
      app = double("app", class: double("app_class", module_parent_name: "MyApp"))
      allow(Rails).to receive(:application).and_return(app)
    end

    def run_with(*answers)
      old_in, old_out = $stdin, $stdout
      $stdin  = StringIO.new(answers.join("\n") + "\n")
      $stdout = StringIO.new
      Respondo::Generators::InstallGenerator.new([], {}, destination_root: dest).run_interactive_setup
    ensure
      $stdin, $stdout = old_in, old_out
    end

    def initializer
      File.read(File.join(dest, "config", "initializers", "respondo.rb"))
    end

    it "refuses the injection payload as a meta key and never writes it" do
      payload = 'a: nil }; puts "INJECTED_CODE_RAN"; { b=x'
      run_with("y", "App", "v1", "OK", "Err", "n", "n", "y", payload, "ok=fine", "", "n")

      expect(initializer).not_to include("INJECTED_CODE_RAN")
      expect(initializer).to include('ok: "fine"')
    end

    it "rejects keys that are not plain identifiers (api-version, my key)" do
      run_with("y", "App", "v1", "OK", "Err", "n", "n", "y", "api-version=1", "my key=2", "good=3", "", "n")

      expect(initializer).not_to include("api-version")
      expect(initializer).not_to include("my key")
      expect(initializer).to include('good: "3"')
    end

    it "generates a file that parses as valid Ruby and defines no extra statements" do
      run_with("y", "App", "v1", "OK", "Err", "n", "n", "y", 'x"; system("id"); "=1', "", "n")

      _out, status = Open3.capture2e("ruby", "-c", File.join(dest, "config", "initializers", "respondo.rb"))
      expect(status).to be_success
      expect(initializer).not_to include("system(")
    end

    it "build_content escapes hostile keys even if validation were bypassed" do
      gen = Respondo::Generators::InstallGenerator.new([], {}, destination_root: dest)
      gen.instance_variable_set(:@cfg, {
        project_name: "App\nsystem('x')", api_version: "v1",
        default_success_message: "OK", default_error_message: "Err",
        include_request_id: false, camelize_keys: false,
        default_meta: { 'a: nil }; puts "PWN"; { b' => "x" }
      })
      content = gen.send(:build_content)

      Dir.mktmpdir do |d|
        f = File.join(d, "i.rb")
        File.write(f, "module Respondo; end\nmodule Respondo; def self.configure; yield Struct.new(:default_meta, :default_success_message, :default_error_message, :include_request_id, :camelize_keys, :strict_serialization, :max_collection_size).new; end; end\n" + content)
        out, status = Open3.capture2e("ruby", f)
        expect(status).to be_success
        expect(out).not_to include("PWN")
      end
      expect(content.lines.first(6).join).not_to match(/^system/)
    end

    it "backs up an existing initializer instead of silently destroying it" do
      FileUtils.mkdir_p(File.dirname(File.join(dest, "config", "initializers", "respondo.rb")))
      File.write(File.join(dest, "config", "initializers", "respondo.rb"), "# my custom config\n")

      run_with("y", "App", "v1", "OK", "Err", "n", "n", "n", "n")

      expect(File.read(File.join(dest, "config", "initializers", "respondo.rb.bak"))).to eq("# my custom config\n")
    end
  end

  # -------------------------------------------------------------------------
  # F2 — raw ActiveRecord exposure
  # -------------------------------------------------------------------------
  describe "F2: raw ActiveRecord serialization guard" do
    let(:model_class) do
      Class.new do
        def self.name = "SecretUser"
        def as_json(*) = { email: "a@b.c", password_digest: "$2a$12$x" }
      end
    end

    before do
      stub_const("ActiveRecord::Base", Class.new)
      Respondo::Serializer.instance_variable_set(:@warned_classes, nil)
    end

    let(:record) do
      klass = Class.new(ActiveRecord::Base) do
        def self.name = "SecretUser"
        def as_json(*) = { email: "a@b.c", password_digest: "$2a$12$x" }
      end
      klass.new
    end

    it "warns once per class by default but still serializes (backwards compatible)" do
      expect(Kernel).to receive(:warn).with(/SecretUser serialized with all attributes/).once
      2.times { expect(Respondo::Serializer.call(record)).to include(:password_digest) }
    end

    it "raises in strict mode" do
      Respondo.configure { |c| c.strict_serialization = true }
      expect { Respondo::Serializer.call(record) }
        .to raise_error(Respondo::UnsafeSerializationError, /SecretUser/)
    end

    it "does not raise in strict mode when a custom serializer is configured" do
      Respondo.configure do |c|
        c.strict_serialization = true
        c.serializer = ->(r) { { email: r.as_json[:email] } }
      end
      expect(Respondo::Serializer.call(record)).to eq({ email: "a@b.c" })
    end

    it "does not touch plain hashes in strict mode" do
      Respondo.configure { |c| c.strict_serialization = true }
      expect(Respondo::Serializer.call({ a: 1 })).to eq({ a: 1 })
    end
  end

  # -------------------------------------------------------------------------
  # F4 — authoritative meta
  # -------------------------------------------------------------------------
  describe "F4: caller meta cannot spoof request_id / timestamp" do
    let(:request) { double("request", request_id: "real-id") }

    def build(meta:)
      Respondo::ResponseBuilder.new(success: true, meta: meta, request: request).build
    end

    before { Respondo.configure { |c| c.include_request_id = true } }

    it "keeps the real request_id and timestamp" do
      m = build(meta: { request_id: "spoofed", timestamp: "1999-01-01T00:00:00Z" })[:meta]
      expect(m[:request_id]).to eq("real-id")
      expect(m[:timestamp]).not_to eq("1999-01-01T00:00:00Z")
    end

    it "also blocks string-keyed spoofing and leaves no duplicate keys" do
      m = build(meta: { "request_id" => "spoofed" })[:meta]
      expect(m[:request_id]).to eq("real-id")
      expect(m.keys.map(&:to_s).tally.values.max).to eq(1)
    end

    it "blocks spoofing via default_meta" do
      Respondo.configure { |c| c.default_meta = { request_id: "spoofed" } }
      expect(build(meta: {})[:meta][:request_id]).to eq("real-id")
    end

    it "keeps request_id first and timestamp second" do
      expect(build(meta: { zzz: 1 })[:meta].keys.first(2)).to eq(%i[request_id timestamp])
    end

    it "still allows custom meta keys" do
      expect(build(meta: { region: "eu" })[:meta][:region]).to eq("eu")
    end
  end

  # -------------------------------------------------------------------------
  # F5 — camelize collisions
  # -------------------------------------------------------------------------
  describe "F5: camelize_keys never silently drops a value" do
    before { Respondo.configure { |c| c.camelize_keys = true } }

    it "leaves colliding keys untouched so both values survive" do
      data = { "user_id" => 1, "userId" => 2, "is_admin" => false, "isAdmin" => true }
      out  = Respondo::ResponseBuilder.new(success: true, data: data).build[:data]

      expect(out.size).to eq(4)
      expect(out["is_admin"]).to eq(false)
      expect(out["isAdmin"]).to eq(true)
    end

    it "still camelizes non-colliding keys" do
      out = Respondo::ResponseBuilder.new(success: true, data: { created_at: "x" }).build[:data]
      expect(out).to eq({ createdAt: "x" })
    end
  end

  # -------------------------------------------------------------------------
  # F7 — collection size cap
  # -------------------------------------------------------------------------
  describe "F7: max_collection_size" do
    it "raises for arrays over the limit" do
      Respondo.configure { |c| c.max_collection_size = 3 }
      expect { Respondo::Serializer.call([1, 2, 3, 4]) }.to raise_error(Respondo::CollectionTooLargeError)
    end

    it "allows arrays at the limit" do
      Respondo.configure { |c| c.max_collection_size = 3 }
      expect(Respondo::Serializer.call([1, 2, 3])).to eq([1, 2, 3])
    end

    it "limits relations at the database (limit(max + 1)) and raises when exceeded" do
      stub_const("ActiveRecord::Relation", Class.new)
      relation = Class.new(ActiveRecord::Relation) do
        attr_reader :asked
        def limit(n); @asked = n; self; end
        def to_a = [1, 2, 3, 4]
      end.new
      Respondo.configure { |c| c.max_collection_size = 3; c.strict_serialization = false }
      allow(Kernel).to receive(:warn)

      expect { Respondo::Serializer.call(relation) }.to raise_error(Respondo::CollectionTooLargeError)
      expect(relation.asked).to eq(4)
    end

    it "is unlimited by default" do
      expect(Respondo::Serializer.call((1..5000).to_a).size).to eq(5000)
    end
  end

  # -------------------------------------------------------------------------
  # F6 / F8 — controller helpers
  # -------------------------------------------------------------------------
  describe "controller helpers" do
    let(:controller_class) do
      Class.new do
        include Respondo::ControllerHelpers
        attr_reader :rendered_json, :rendered_status, :headers_set, :request, :response

        def initialize(host: "app.example.com")
          @headers_set = {}
          @request  = Struct.new(:host, :request_id).new(host, "rid")
          hs = @headers_set
          @response = Object.new.tap { |r| r.define_singleton_method(:set_header) { |k, v| hs[k] = v } }
        end

        def render(json:, status:)
          @rendered_json = json
          @rendered_status = status
        end
      end
    end
    let(:controller) { controller_class.new }

    describe "F6: 1xx helpers are gone" do
      %i[render_continue render_switching_protocols render_processing render_early_hints].each do |m|
        it "no longer defines ##{m}" do
          expect(controller).not_to respond_to(m)
        end
      end
    end

    describe "F6: redirect helpers" do
      it "sets a real Location header for a relative path" do
        controller.render_found(location: "/login")
        expect(controller.headers_set["Location"]).to eq("/login")
        expect(controller.rendered_json[:meta][:redirect_url]).to eq("/login")
        expect(controller.rendered_status).to eq(:found)
      end

      it "allows an absolute URL on the same host" do
        controller.render_moved_permanently(location: "https://app.example.com/new")
        expect(controller.headers_set["Location"]).to eq("https://app.example.com/new")
      end

      it "rejects another host by default" do
        expect { controller.render_found(location: "https://evil.example.net/") }
          .to raise_error(Respondo::UnsafeRedirectError, /allow_other_host/)
      end

      it "allows another host only when explicitly opted in" do
        controller.render_found(location: "https://partner.example.org/", allow_other_host: true)
        expect(controller.headers_set["Location"]).to eq("https://partner.example.org/")
      end

      it "rejects protocol-relative and backslash tricks" do
        expect { controller.render_found(location: "//evil.com") }.to raise_error(Respondo::UnsafeRedirectError)
        expect { controller.render_found(location: "/\\evil.com") }.to raise_error(Respondo::UnsafeRedirectError)
      end

      it "rejects CRLF header injection" do
        expect { controller.render_found(location: "/ok\r\nSet-Cookie: x=1") }
          .to raise_error(Respondo::UnsafeRedirectError, /control/)
      end

      it "rejects non-http schemes" do
        expect { controller.render_found(location: "javascript:alert(1)") }.to raise_error(Respondo::UnsafeRedirectError)
      end

      it "sets no header when no location is given (unchanged behavior)" do
        controller.render_found
        expect(controller.headers_set).to be_empty
      end
    end

    describe "F8: robustness" do
      it "treats meta: nil as empty on success helpers" do
        expect { controller.render_ok(meta: nil) }.not_to raise_error
        expect(controller.rendered_status).to eq(:ok)
      end

      it "treats meta: nil as empty on error helpers" do
        expect { controller.render_not_found(meta: nil) }.not_to raise_error
      end

      it "works in a plain object that has no #try and no #request" do
        bare = Class.new do
          include Respondo::ControllerHelpers
          attr_reader :out
          def render(json:, status:) = (@out = json)
        end.new
        expect { bare.render_ok(data: { a: 1 }) }.not_to raise_error
        expect(bare.out[:data]).to eq({ a: 1 })
      end
    end
  end
end

# Found by running a real Rails 6.1 / Rack 2.2 app against every helper:
# Rack 2.x has no :im_a_teapot symbol, so render_im_a_teapot raised
# "Unrecognized status code".
RSpec.describe "Rack-version status symbols" do
  let(:controller) do
    Class.new do
      include Respondo::ControllerHelpers
      attr_reader :status
      def render(json:, status:) = (@status = status)
    end.new
  end

  it "falls back to 418 when Rack does not know :im_a_teapot" do
    stub_const("Rack::Utils::SYMBOL_TO_STATUS_CODE", { ok: 200 })
    controller.render_im_a_teapot
    expect(controller.status).to eq(418)
  end

  it "uses the symbol when Rack knows it" do
    stub_const("Rack::Utils::SYMBOL_TO_STATUS_CODE", { im_a_teapot: 418 })
    controller.render_im_a_teapot
    expect(controller.status).to eq(:im_a_teapot)
  end
end

# Found by a Windows run on Rails 8.1 / Rack 3.x: Rack deprecated the status
# names :payload_too_large (renamed :content_too_large) and :not_extended.
RSpec.describe "deprecated Rack status names" do
  let(:controller) do
    Class.new do
      include Respondo::ControllerHelpers
      attr_reader :status
      def render(json:, status:) = (@status = status)
    end.new
  end

  it "uses :content_too_large on Rack 3.1+" do
    stub_const("Rack::Utils::SYMBOL_TO_STATUS_CODE", { content_too_large: 413, payload_too_large: 413 })
    controller.render_payload_too_large
    expect(controller.status).to eq(:content_too_large)
  end

  it "uses :payload_too_large on older Rack" do
    stub_const("Rack::Utils::SYMBOL_TO_STATUS_CODE", { payload_too_large: 413 })
    controller.render_payload_too_large
    expect(controller.status).to eq(:payload_too_large)
  end

  it "never passes the deprecated :not_extended symbol (uses 510)" do
    controller.render_not_extended
    expect(controller.status).to eq(510)
  end
end
