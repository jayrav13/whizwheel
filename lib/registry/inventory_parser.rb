module Registry
  # Parses the catalog table out of docs/INVENTORY.md into an array of row Hashes
  # keyed by normalized header name (robust to column reordering — we key by header,
  # never by position).
  #
  # The catalog table is the markdown table whose header row contains a "Calculator"
  # and a "Slug" column; other markdown tables in the doc (e.g. the complexity scale)
  # are ignored.
  class InventoryParser
    DEFAULT_PATH = Rails.root.join("docs", "INVENTORY.md")

    def initialize(path = DEFAULT_PATH)
      @path = path
    end

    # => Array<Hash> with symbol keys: :calculator, :slug, :category, :complexity,
    #    :tags, :description, :source, :built. Missing columns come back as nil.
    def rows
      lines = File.readlines(@path).map(&:rstrip)
      header_index = lines.index { |l| catalog_header?(l) }
      raise ParseError, "no catalog table found in #{@path}" unless header_index

      headers = cells(lines[header_index]).map { |h| normalize_header(h) }
      data_lines(lines, header_index).map { |line| build_row(headers, cells(line)) }
    end

    class ParseError < StandardError; end

    private

    def catalog_header?(line)
      return false unless table_row?(line)

      keys = cells(line).map { |c| normalize_header(c) }
      keys.include?(:calculator) && keys.include?(:slug)
    end

    # The contiguous block of table rows after the header's separator row, up to the
    # first non-table line.
    def data_lines(lines, header_index)
      body = lines[(header_index + 1)..] || []
      body = body.drop(1) if body.first && separator_row?(body.first)
      body.take_while { |l| table_row?(l) }
    end

    def build_row(headers, values)
      row = headers.each_with_index.to_h { |key, i| [ key, values[i] ] }
      {
        calculator:  presence(row[:calculator]),
        slug:        presence(row[:slug]),
        category:    presence(row[:category]),
        complexity:  presence(row[:complexity]),
        tags:        presence(row[:tags]),
        description: presence(row[:description]),
        source:      presence(row[:source]),
        built:       presence(row[:built_prs])
      }
    end

    def table_row?(line)
      line.lstrip.start_with?("|")
    end

    def separator_row?(line)
      cells(line).all? { |c| c.match?(/\A:?-+:?\z/) }
    end

    # Splits a markdown table row into trimmed cell strings, dropping the empty
    # leading/trailing cells produced by the bordering pipes.
    def cells(line)
      line.strip.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip)
    end

    def normalize_header(text)
      text.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").to_sym
    end

    def presence(value)
      value if value && !value.strip.empty?
    end
  end
end
