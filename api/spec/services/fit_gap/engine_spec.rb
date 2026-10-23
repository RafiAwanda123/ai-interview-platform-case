# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FitGap::Engine, type: :service do
  let(:org) { create(:organization) }
  let(:assessment) { create(:assessment, tenant_id: org.id) }
  let(:session_record) { create(:session, assessment: assessment, tenant_id: org.id) }
  let(:portfolio) { create(:portfolio, session: session_record, generation_status: 'complete') }
  let(:gemini_client) { instance_double(Gemini::HttpClient) }

  let(:vacancy) do
    v = Vacancy.create!(
      tenant_id: org.id,
      created_by: 1,
      role_title: 'Senior Backend Engineer',
      competency_expectations: 'Strong DB skills'
    )
    v.vacancy_skills.create!(skill_label: 'PostgreSQL Performance', expected_level: 4)
    v
  end

  before do
    Current.organization = org
    Current.tenant_id = org.id

    allow(gemini_client).to receive(:generate_content).and_return({
      'culture_narrative' => 'Good culture fit',
      'overall_narrative' => 'Strong potential'
    })
  end

  it 'tidak crash pada skill dengan ai_level nil dan menghasilkan not_assessed' do
    create(
      :portfolio_skill,
      portfolio: portfolio,
      skill_label: 'PostgreSQL Performance',
      ai_level: nil,
      ai_confidence: 'low'
    )

    engine = described_class.new(portfolio: portfolio, vacancy: vacancy, gemini_client: gemini_client)
    report = engine.call

    comparison = report.skill_comparisons.first
    expect(comparison['candidate_level']).to be_nil
    expect(comparison['delta']).to be_nil
    expect(comparison['result']).to eq('not_assessed')
  end

  it 'menggunakan override_level bila skill tidak ternilai memiliki override' do
    skill = create(
      :portfolio_skill,
      portfolio: portfolio,
      skill_label: 'PostgreSQL Performance',
      ai_level: nil,
      ai_confidence: 'low'
    )

    skill.create_assessor_override!(
      ai_level: nil,
      override_level: 4,
      overridden_by: 1,
      assessor_notes: 'Demonstrated in past projects'
    )

    engine = described_class.new(portfolio: portfolio, vacancy: vacancy, gemini_client: gemini_client)
    report = engine.call

    comparison = report.skill_comparisons.first
    expect(comparison['candidate_level']).to eq(4)
    expect(comparison['delta']).to eq(0)
    expect(comparison['result']).to eq('match')
  end
end
