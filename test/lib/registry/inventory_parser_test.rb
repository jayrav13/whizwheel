require "test_helper"

module Registry
  class InventoryParserTest < ActiveSupport::TestCase
    def write_inventory(contents)
      path = Rails.root.join("tmp", "inventory_parser_test_#{SecureRandom.hex(4)}.md")
      File.write(path, contents)
      @paths ||= []
      @paths << path
      path
    end

    teardown do
      Array(@paths).each { |p| File.delete(p) if File.exist?(p) }
    end

    test "parses the catalog table into rows keyed by header name" do
      path = write_inventory(<<~MD)
        # Intro prose

        | Calculator | Slug | Category | Complexity | Tags | Description | Source | Built (PRs) |
        |---|---|---|---|---|---|---|---|
        | Tip Calculator | tip | Other | 2 | multi-input | The tip on a bill. | [tip](http://x) | BE #1 |
      MD

      rows = InventoryParser.new(path).rows
      assert_equal 1, rows.size
      row = rows.first
      assert_equal "Tip Calculator", row[:calculator]
      assert_equal "tip", row[:slug]
      assert_equal "Other", row[:category]
      assert_equal "2", row[:complexity]
      assert_equal "multi-input", row[:tags]
      assert_equal "The tip on a bill.", row[:description]
      assert_equal "[tip](http://x)", row[:source]
      assert_equal "BE #1", row[:built]
    end

    test "keys by header name, not position (robust to column reordering)" do
      path = write_inventory(<<~MD)
        | Slug | Calculator | Description | Category | Tags | Complexity | Built (PRs) | Source |
        |---|---|---|---|---|---|---|---|
        | tip | Tip Calculator | The tip on a bill. | Other | multi-input | 2 | BE #1 | [tip](http://x) |
      MD

      row = InventoryParser.new(path).rows.first
      assert_equal "tip", row[:slug]
      assert_equal "Tip Calculator", row[:calculator]
      assert_equal "The tip on a bill.", row[:description]
      assert_equal "Other", row[:category]
    end

    test "blank cells come back as nil" do
      path = write_inventory(<<~MD)
        | Calculator | Slug | Category | Complexity | Tags | Description | Source | Built (PRs) |
        |---|---|---|---|---|---|---|---|
        | 401K Calculator |  | Financial | 4 |  |  | [401k](http://x) |  |
      MD

      row = InventoryParser.new(path).rows.first
      assert_equal "401K Calculator", row[:calculator]
      assert_nil row[:slug]
      assert_nil row[:tags]
      assert_nil row[:description]
      assert_nil row[:built]
    end

    test "ignores other markdown tables and stops at the first non-table line" do
      path = write_inventory(<<~MD)
        ## Complexity scale

        | Rating | Meaning |
        |---|---|
        | 1 | Trivial |

        ## Catalog

        | Calculator | Slug | Category | Complexity | Tags | Description | Source | Built (PRs) |
        |---|---|---|---|---|---|---|---|
        | Tip Calculator | tip | Other | 2 | x | y | [s](http://x) | BE #1 |
        | BMI Calculator | bmi | Health | 2 | x | y | [s](http://x) | BE #2 |

        Some trailing prose that is not a table row.
      MD

      rows = InventoryParser.new(path).rows
      assert_equal %w[tip bmi], rows.map { |r| r[:slug] }
    end

    test "handles a catalog table with no separator row" do
      path = write_inventory(<<~MD)
        | Calculator | Slug | Category | Complexity | Tags | Description | Source | Built (PRs) |
        | Tip Calculator | tip | Other | 2 | x | y | [s](http://x) | BE #1 |
      MD

      rows = InventoryParser.new(path).rows
      assert_equal %w[tip], rows.map { |r| r[:slug] }
    end

    test "raises when no catalog table is present" do
      path = write_inventory(<<~MD)
        # Just prose

        | Rating | Meaning |
        |---|---|
        | 1 | Trivial |
      MD

      assert_raises(InventoryParser::ParseError) { InventoryParser.new(path).rows }
    end

    test "parses the real docs/INVENTORY.md and finds the built calculators" do
      rows = InventoryParser.new.rows
      slugged = rows.select { |r| r[:slug] }.map { |r| r[:slug] }
      assert_includes slugged, "percentage"
      assert_includes slugged, "amortization"
      # there are also unbuilt (slug-less) rows
      assert(rows.any? { |r| r[:slug].nil? })
    end
  end
end
