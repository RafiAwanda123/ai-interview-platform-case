# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PortfolioGeneratorWorker, type: :worker do
  let(:org) { create(:organization) }
  let(:assessment) { create(:assessment, tenant_id: org.id) }
  let(:session) { create(:session, assessment: assessment, tenant_id: org.id) }
  let!(:portfolio) { create(:portfolio, session: session, generation_status: 'pending') }

  before do
    Current.organization = org
    Current.tenant_id = org.id
  end

  describe '#perform' do
    it 'memanggil Portfolios::Generator untuk session terkait' do
      generator_double = instance_double(Portfolios::Generator)
      expect(Portfolios::Generator).to receive(:new).with(session: session).and_return(generator_double)
      expect(generator_double).to receive(:call)

      described_class.new.perform(session.id)
    end
  end

  describe 'sidekiq_retries_exhausted callback' do
    it 'mengubah status menjadi failed dengan pesan aman dan tidak membocorkan PII/transkrip' do
      sensitive_candidate_info = 'NIK: 0000000000000000 Nama: Kandidat Uji'
      raw_error = "API Error communicating with Gemini: prompt contained #{sensitive_candidate_info}"

      msg = {
        'args' => [session.id],
        'retry_count' => 3,
        'error_message' => raw_error
      }

      described_class.sidekiq_retries_exhausted_block.call(msg, StandardError.new(raw_error))

      portfolio.reload
      expect(portfolio.generation_status).to eq('failed')
      expect(portfolio.generation_error).not_to include(sensitive_candidate_info)
    end
  end
end
