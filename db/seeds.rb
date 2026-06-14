# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

RoleType.find_or_create_by!(permalink: "ADMIN") { |rt| rt.display_name = "Admin" }

# Populate the derived calculator registry from docs/INVENTORY.md (idempotent —
# upsert by slug, reconciled against Base.lookup). Tests get this data from fixtures
# instead, since db:test:prepare runs neither migrations nor seeds.
Registry::Ingest.new.call
