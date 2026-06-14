module Registry
  # Projects docs/INVENTORY.md into the `calculators` table — the one sanctioned,
  # idempotent/convergent ingest (CLAUDE.md → "The calculator registry"). Re-running
  # converges the table to the inventory's built set.
  #
  # Contract:
  #   * Source of truth is docs/INVENTORY.md; the table is *derived*, never hand-edited.
  #   * Only rows that HAVE a slug are candidates (a blank slug means "catalogued but
  #     not built by us yet").
  #   * Code is authoritative: a candidate row only ingests when its slug resolves to a
  #     Calculators::X class (Base.lookup). A slugged row pointing at a non-existent
  #     class is skipped (the DB can never point at an unbuilt calculator).
  #   * Upsert by slug — convergent.
  #   * Drift warning: a BUILT class (Base.lookup resolves it) with no slugged/described
  #     INVENTORY row is a missed Close-phase backfill and is warned LOUDLY.
  #   * Deprecate, never delete: a previously-ingested calculator no longer present in
  #     the inventory's built set is marked deprecated, never destroyed. A row that
  #     reappears is reinstated.
  class Ingest
    Result = Struct.new(:upserted, :deprecated, :reinstated, :skipped, :drift, keyword_init: true)

    def initialize(parser: InventoryParser.new, logger: Rails.logger)
      @parser = parser
      @logger = logger
    end

    # Runs the ingest and returns a Result summary.
    def call
      result = Result.new(upserted: [], deprecated: [], reinstated: [], skipped: [], drift: [])
      ingested_slugs = upsert_rows(result)
      deprecate_missing(ingested_slugs, result)
      warn_drift(ingested_slugs, result)
      log_summary(result)
      result
    end

    private

    def upsert_rows(result)
      ingested = []
      slugged_rows.each do |row|
        slug = row[:slug]
        unless Calculators::Base.lookup(slug)
          result.skipped << slug
          warn_loudly("INVENTORY row '#{slug}' has no Calculators class — skipping (code is authoritative).")
          next
        end
        upsert(row, result)
        ingested << slug
      end
      ingested
    end

    def upsert(row, result)
      record = Calculator.find_or_initialize_by(slug: row[:slug])
      reinstated = record.persisted? && record.deprecated?
      record.assign_attributes(
        name:        row[:calculator],
        category:    row[:category],
        complexity:  row[:complexity],
        tags:        row[:tags],
        description: row[:description],
        source:      row[:source],
        deprecated_at: nil
      )
      record.save!
      result.reinstated << row[:slug] if reinstated
      result.upserted << row[:slug]
    end

    # Anything currently active in the table but no longer in the inventory's built set
    # gets deprecated, never destroyed (rule #4).
    def deprecate_missing(ingested_slugs, result)
      Calculator.active.where.not(slug: ingested_slugs).find_each do |record|
        record.deprecate
        result.deprecated << record.slug
        warn_loudly("Calculator '#{record.slug}' is no longer in INVENTORY's built set — deprecated (not deleted).")
      end
    end

    # A built class whose INVENTORY row is missing or lacks slug/description is a missed
    # backfill — surface it loudly rather than silently shipping a blank card.
    def warn_drift(ingested_slugs, result)
      built_class_slugs.each do |slug|
        next if ingested_slugs.include?(slug)

        result.drift << slug
        warn_loudly("DRIFT: built calculator '#{slug}' has no slugged/described row in docs/INVENTORY.md " \
                    "(missed Close-phase backfill) — its catalog card would be blank.")
      end
    end

    def slugged_rows
      @parser.rows.select { |row| row[:slug] && row[:description] }
    end

    # Every built calculator, by slug — the authoritative "what's built". Derived from
    # the files in app/calculators (each <slug>.rb is a Calculators::X), constantized
    # via Base.lookup so it works whether or not the app is eager-loaded.
    def built_class_slugs
      Dir[Rails.root.join("app/calculators/*.rb")]
        .map { |path| File.basename(path, ".rb") }
        .reject { |slug| slug == "base" }
        .select { |slug| Calculators::Base.lookup(slug) }
    end

    def log_summary(result)
      @logger.info(
        "[calculators:ingest] upserted=#{result.upserted.size} " \
        "deprecated=#{result.deprecated.size} reinstated=#{result.reinstated.size} " \
        "skipped=#{result.skipped.size} drift=#{result.drift.size}"
      )
    end

    def warn_loudly(message)
      @logger.warn("[calculators:ingest] #{message}")
    end
  end
end
