namespace :calculators do
  desc "Ingest the calculator registry from docs/INVENTORY.md (idempotent/convergent): rake calculators:ingest"
  task ingest: :environment do
    result = Registry::Ingest.new.call
    puts "[calculators:ingest] upserted=#{result.upserted.size} deprecated=#{result.deprecated.size} " \
         "reinstated=#{result.reinstated.size} skipped=#{result.skipped.size} drift=#{result.drift.size}"
  end
end
