# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Portfolios', type: :request do
  let(:org) { create(:organization) }
  let(:assessment) { create(:assessment, tenant_id: org.id) }
  let(:session_record) { create(:session, assessment: assessment, tenant_id: org.id) }
  let(:headers) { auth_headers(org, role: 'admin') }

  describe 'GET /api/v1/sessions/:id/portfolio' do
    context 'Cacat f: Status pending' do
      it 'mengembalikan status HTTP 202 Accepted dengan status pending' do
        create(:portfolio, session: session_record, generation_status: 'pending')

        get "/api/v1/sessions/#{session_record.id}/portfolio", headers: headers

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('pending')
      end
    end

    context 'Cacat f: Status generating menggantung (stale)' do
      it 'memulihkan status menggantung ke failed setelah batas waktu' do
        create(:portfolio, session: session_record, generation_status: 'generating')

        get "/api/v1/sessions/#{session_record.id}/portfolio", headers: headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['portfolio']['generation_status']).to eq('failed')
      end
    end

    context 'Cacat g: Status failed dan privasi error' do
      it 'tidak menampilkan transkrip atau stack trace dalam pesan error' do
        create(
          :portfolio,
          session: session_record,
          generation_status: 'failed',
          generation_error: 'Upstream generation service timeout'
        )

        get "/api/v1/sessions/#{session_record.id}/portfolio", headers: headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['error']).to eq('Upstream generation service timeout')
        expect(body['error']).not_to include('backtrace')
        expect(body['error']).not_to include('candidate')
      end
    end

    context 'Status complete' do
      it 'mengembalikan portfolio lengkap dengan skills' do
        portfolio = create(:portfolio, session: session_record, generation_status: 'complete')
        create(:portfolio_skill, portfolio: portfolio, skill_label: 'PostgreSQL', ai_level: 3)

        get "/api/v1/sessions/#{session_record.id}/portfolio", headers: headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['portfolio']['generation_status']).to eq('complete')
        expect(body['portfolio']['skills'].length).to eq(1)
      end
    end
  end

  describe 'POST /api/v1/sessions/:id/portfolio/regenerate' do
    context 'Cacat e: Idempotensi dan pencegahan klik ganda' do
      it 'hanya meng-enqueue satu job saat regenerate dipanggil' do
        create(:portfolio, session: session_record, generation_status: 'failed', generation_error: 'Previous failure')

        expect {
          post "/api/v1/sessions/#{session_record.id}/portfolio/regenerate", headers: headers
        }.to change(PortfolioGeneratorWorker.jobs, :size).by(1)

        expect(response).to have_http_status(:ok)

        expect {
          post "/api/v1/sessions/#{session_record.id}/portfolio/regenerate", headers: headers
        }.not_to change(PortfolioGeneratorWorker.jobs, :size)

        expect(response.status).to be_in([409, 422])
      end
    end
  end
end
