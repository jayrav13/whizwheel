require "test_helper"

module Registry
  class IngestTest < ActiveSupport::TestCase
    # A test logger that records every warn/info message.
    class CaptureLogger
      attr_reader :warnings, :infos

      def initialize
        @warnings = []
        @infos = []
      end

      def warn(msg) = @warnings << msg
      def info(msg) = @infos << msg
    end

    # A stand-in parser returning canned rows.
    class FakeParser
      def initialize(rows) = (@rows = rows)
      def rows = @rows
    end

    def row(slug:, name: "Name", **extra)
      { calculator: name, slug: slug, category: "Math", complexity: "2",
        tags: "t", description: "A blurb.", source: "[s](http://x)", built: "BE #1" }.merge(extra)
    end

    # Rows for every real built calculator, so the default run reports no drift.
    def all_built_rows
      Dir[Rails.root.join("app/calculators/*.rb")]
        .map { |p| File.basename(p, ".rb") }
        .reject { |s| s == "base" }
        .map { |slug| row(slug: slug, name: slug.titleize) }
    end

    def setup
      Calculator.delete_all
      @logger = CaptureLogger.new
    end

    def ingest(rows)
      Ingest.new(parser: FakeParser.new(rows), logger: @logger).call
    end

    test "upserts a built, fully-described row keyed by slug" do
      result = ingest(all_built_rows)

      assert_includes result.upserted, "percentage"
      record = Calculator.find_by(slug: "percentage")
      assert_equal "Percentage", record.name
      assert_equal "Math", record.category
      assert_equal 2, record.complexity
      assert_not record.deprecated?
    end

    test "is idempotent and convergent — a second run changes nothing" do
      ingest(all_built_rows)
      count_after_first = Calculator.count
      slugs_after_first = Calculator.order(:slug).pluck(:slug)

      result = ingest(all_built_rows)
      assert_equal count_after_first, Calculator.count
      assert_equal slugs_after_first, Calculator.order(:slug).pluck(:slug)
      assert_empty result.deprecated
    end

    test "an updated inventory row converges the table row" do
      ingest(all_built_rows)
      rows = all_built_rows.map do |r|
        r[:slug] == "tip" ? r.merge(description: "A new blurb.", complexity: "5") : r
      end
      ingest(rows)

      tip = Calculator.find_by(slug: "tip")
      assert_equal "A new blurb.", tip.description
      assert_equal 5, tip.complexity
    end

    test "skips a slugged row with no Calculators class (code is authoritative)" do
      rows = all_built_rows + [ row(slug: "not_a_real_calculator") ]
      result = ingest(rows)

      assert_includes result.skipped, "not_a_real_calculator"
      assert_nil Calculator.find_by(slug: "not_a_real_calculator")
      assert(@logger.warnings.any? { |w| w.include?("not_a_real_calculator") && w.include?("no Calculators class") })
    end

    test "ignores rows with no slug (catalogued but unbuilt)" do
      rows = all_built_rows + [ row(slug: nil, name: "401K Calculator") ]
      result = ingest(rows)

      assert_equal all_built_rows.size, result.upserted.size
      assert_empty result.drift
    end

    test "ignores a slugged row that lacks a description (incomplete backfill)" do
      # tip has a slug but no description -> not ingested; and since tip IS built,
      # it surfaces as drift.
      rows = all_built_rows.map { |r| r[:slug] == "tip" ? r.merge(description: nil) : r }
      result = ingest(rows)

      assert_not_includes result.upserted, "tip"
      assert_includes result.drift, "tip"
    end

    test "warns LOUDLY on backfill drift — a built class with no slugged/described row" do
      rows = all_built_rows.reject { |r| r[:slug] == "amortization" }
      result = ingest(rows)

      assert_includes result.drift, "amortization"
      assert(@logger.warnings.any? { |w| w.include?("DRIFT") && w.include?("amortization") })
    end

    test "deprecates — never destroys — a calculator dropped from the built set" do
      ingest(all_built_rows)
      assert Calculator.find_by(slug: "tip")

      # Re-run without tip but keep tip's class present, so it's a genuine drop
      # from the inventory rather than a code change.
      rows = all_built_rows.reject { |r| r[:slug] == "tip" }
      result = ingest(rows)

      assert_includes result.deprecated, "tip"
      tip = Calculator.find_by(slug: "tip")
      assert_not_nil tip, "row must be marked, never destroyed"
      assert tip.deprecated?
      assert(@logger.warnings.any? { |w| w.include?("tip") && w.include?("deprecated") })
    end

    test "reinstates a previously-deprecated calculator that reappears" do
      ingest(all_built_rows)
      Calculator.find_by(slug: "tip").deprecate
      assert Calculator.find_by(slug: "tip").deprecated?

      result = ingest(all_built_rows)
      assert_includes result.reinstated, "tip"
      assert_not Calculator.find_by(slug: "tip").deprecated?
    end

    test "logs a summary line" do
      ingest(all_built_rows)
      assert(@logger.infos.any? { |i| i.include?("[calculators:ingest]") && i.include?("upserted=") })
    end

    test "defaults to the real InventoryParser and Rails.logger" do
      # Exercises the default-argument paths of the constructor.
      service = Ingest.new
      result = service.call
      assert_includes result.upserted, "percentage"
      assert_empty result.drift
    end
  end
end
