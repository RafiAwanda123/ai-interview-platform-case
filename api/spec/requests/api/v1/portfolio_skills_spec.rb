# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PortfolioSkills', type: :request do
  let(:org) { create(:organization) }
  let(:assessment) { create(:assessment, tenant_id: org.id) }
  let(:session_record) { create(:session, assessment: assessment, tenant_id: org.id) }
  let(:portfolio) { create(:portfolio, session: session_record, generation_status: 'complete') }
  let(:headers) { auth_headers(org, role: 'assessor') }

  it 'berhasil menyimpan override pada skill yang tidak ternilai (ai_level nil)' do
    skill = create(
      :portfolio_skill,
      portfolio: portfolio,
      skill_label: 'PostgreSQL Performance',
      ai_level: nil,
      ai_confidence: 'low'
    )

    post "/api/v1/portfolio-skills/#{skill.id}/override",
         params: {
           override: {
             override_level: 3,
             assessor_notes: 'Kandidat menunjukkan bukti kuat di sesi diskusi teknis'
           }
         },
         headers: headers

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body['override']['ai_level']).to be_nil
    expect(body['override']['override_level']).to eq(3)
  end
end
