# frozen_string_literal: true

class HardenPortfolioLifecycle < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      ALTER TABLE ai_interview.portfolio_skills
        DROP CONSTRAINT IF EXISTS chk_portfolio_skills_ai_level;

      ALTER TABLE ai_interview.portfolio_skills
        ALTER COLUMN ai_level DROP NOT NULL;

      ALTER TABLE ai_interview.portfolio_skills
        ADD CONSTRAINT chk_portfolio_skills_ai_level
        CHECK (ai_level IS NULL OR (ai_level >= 1 AND ai_level <= 5));

      ALTER TABLE ai_interview.assessor_overrides
        DROP CONSTRAINT IF EXISTS chk_overrides_ai_level;

      ALTER TABLE ai_interview.assessor_overrides
        ALTER COLUMN ai_level DROP NOT NULL;

      ALTER TABLE ai_interview.assessor_overrides
        ADD CONSTRAINT chk_overrides_ai_level
        CHECK (ai_level IS NULL OR (ai_level >= 1 AND ai_level <= 5));
    SQL

    add_column 'ai_interview.portfolios', :generation_error_code, :string, limit: 50
    add_column 'ai_interview.portfolios', :generation_started_at, :datetime
  end

  def down
    null_skills_exist = execute("SELECT 1 FROM ai_interview.portfolio_skills WHERE ai_level IS NULL LIMIT 1").any?
    null_overrides_exist = execute("SELECT 1 FROM ai_interview.assessor_overrides WHERE ai_level IS NULL LIMIT 1").any?

    if null_skills_exist || null_overrides_exist
      raise ActiveRecord::IrreversibleMigration, "Cannot rollback when portfolio_skills or assessor_overrides contain NULL ai_level records. Clean up or assign explicit levels before rolling back."
    end

    remove_column 'ai_interview.portfolios', :generation_started_at, :datetime
    remove_column 'ai_interview.portfolios', :generation_error_code, :string

    execute <<~SQL
      ALTER TABLE ai_interview.portfolio_skills
        DROP CONSTRAINT IF EXISTS chk_portfolio_skills_ai_level;

      ALTER TABLE ai_interview.portfolio_skills
        ALTER COLUMN ai_level SET NOT NULL;

      ALTER TABLE ai_interview.portfolio_skills
        ADD CONSTRAINT chk_portfolio_skills_ai_level
        CHECK (ai_level >= 1 AND ai_level <= 5);

      ALTER TABLE ai_interview.assessor_overrides
        DROP CONSTRAINT IF EXISTS chk_overrides_ai_level;

      ALTER TABLE ai_interview.assessor_overrides
        ALTER COLUMN ai_level SET NOT NULL;

      ALTER TABLE ai_interview.assessor_overrides
        ADD CONSTRAINT chk_overrides_ai_level
        CHECK (ai_level >= 1 AND ai_level <= 5);
    SQL
  end
end
