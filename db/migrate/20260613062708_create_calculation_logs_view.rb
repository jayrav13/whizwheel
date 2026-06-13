class CreateCalculationLogsView < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE VIEW calculation_logs AS
      SELECT c.id, c.calculator, c.inputs, c.result, c.user_id,
             u.username, c.deleted_at, c.created_at, c.updated_at
      FROM calculations c
      LEFT JOIN users u ON u.id = c.user_id;
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS calculation_logs;"
  end
end
