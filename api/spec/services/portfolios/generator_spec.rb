# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Portfolios::Generator, type: :service do
  let(:org) { create(:organization) }
  let(:assessment) { create(:assessment, tenant_id: org.id) }
  let(:session) { create(:session, assessment: assessment, tenant_id: org.id) }
  let(:gemini_client) { instance_double(Gemini::HttpClient) }

  before do
    Current.organization = org
    Current.tenant_id = org.id

    create(:transcript_turn, session: session, turn_number: 1, speaker: 'ai', text: 'Halo, ceritakan pengalaman database Anda.')
    create(:transcript_turn, session: session, turn_number: 2, speaker: 'candidate', text: 'Saya menambahkan composite index pada tabel orders untuk optimasi query.')
    create(:transcript_turn, session: session, turn_number: 3, speaker: 'ai', text: 'Bagaimana hasilnya?')
    create(:transcript_turn, session: session, turn_number: 4, speaker: 'candidate', text: 'Query latency turun dari 450ms menjadi 12ms di traffic puncak.')

    create(:coverage_map, session: session, skill_label: 'PostgreSQL Performance', skill_id: 'sk-pg', state: 'covered', probe_count: 3)
    create(:coverage_map, session: session, skill_label: 'Docker & Containerization', skill_id: 'sk-doc', state: 'not_yet', probe_count: 0)
    create(:coverage_map, session: session, skill_label: 'System Design', skill_id: 'sk-sys', state: 'partial', probe_count: 2)
  end

  subject(:generator) { described_class.new(session: session, gemini_client: gemini_client) }

  describe 'Cacat a: Level unassessed' do
    it 'menyimpan skill unassessed dengan ai_level nil' do
      llm_response = {
        'configured_skills' => [
          {
            'skill_id' => 'sk-pg',
            'skill_label' => 'PostgreSQL Performance',
            'level' => 'N/A',
            'confidence' => 'high',
            'evidence' => ['Saya menambahkan composite index pada tabel orders untuk optimasi query.'],
            'competency_summary' => 'Belum cukup bukti untuk menilai level konkret.'
          }
        ],
        'discovered_skills' => []
      }

      allow(gemini_client).to receive(:generate_content).and_return(llm_response)

      portfolio = generator.call
      skill = portfolio.portfolio_skills.find_by(skill_id: 'sk-pg')

      expect(skill.ai_level).to be_nil
    end
  end

  describe 'Cacat b: Confidence deterministik & skill not_yet' do
    it 'menghitung confidence dari coverage map dan mengosongkan level untuk skill not_yet' do
      llm_response = {
        'configured_skills' => [
          {
            'skill_id' => 'sk-doc',
            'skill_label' => 'Docker & Containerization',
            'level' => 3,
            'confidence' => 'high',
            'evidence' => [],
            'competency_summary' => 'Candidate understands docker conceptually.'
          },
          {
            'skill_id' => 'sk-sys',
            'skill_label' => 'System Design',
            'level' => 3,
            'confidence' => 'low',
            'evidence' => [],
            'competency_summary' => 'Partial coverage on system architecture.'
          }
        ],
        'discovered_skills' => []
      }

      allow(gemini_client).to receive(:generate_content).and_return(llm_response)

      portfolio = generator.call

      doc_skill = portfolio.portfolio_skills.find_by(skill_id: 'sk-doc')
      expect(doc_skill.ai_level).to be_nil
      expect(doc_skill.ai_confidence).to eq('low')

      sys_skill = portfolio.portfolio_skills.find_by(skill_id: 'sk-sys')
      expect(sys_skill.ai_confidence).to eq('medium')
    end
  end

  describe 'Cacat c: Verifikasi kutipan evidence terhadap transkrip candidate' do
    it 'membuang kutipan yang bukan substring ucapan candidate' do
      llm_response = {
        'configured_skills' => [
          {
            'skill_id' => 'sk-pg',
            'skill_label' => 'PostgreSQL Performance',
            'level' => 3,
            'confidence' => 'high',
            'evidence' => [
              'Saya menambahkan composite index pada tabel orders untuk optimasi query.',
              'Halo, ceritakan pengalaman database Anda.',
              'Saya menggunakan Kubernetes di Google Cloud untuk auto scaling.'
            ],
            'competency_summary' => 'Memiliki pemahaman solid tentang index database.'
          }
        ],
        'discovered_skills' => []
      }

      allow(gemini_client).to receive(:generate_content).and_return(llm_response)

      portfolio = generator.call
      skill = portfolio.portfolio_skills.find_by(skill_id: 'sk-pg')

      expect(skill.evidence_quotes).to eq([
        'Saya menambahkan composite index pada tabel orders untuk optimasi query.'
      ])
    end
  end

  describe 'Cacat d: Transaksi atomik saat regenerasi' do
    it 'tidak menghapus skill lama jika terjadi kegagalan saat proses penyimpanan' do
      portfolio = create(:portfolio, session: session, generation_status: 'complete')
      old_skill = create(:portfolio_skill, portfolio: portfolio, skill_label: 'Old Skill', ai_level: 2)

      llm_response = {
        'configured_skills' => [
          {
            'skill_id' => 'sk-pg',
            'skill_label' => '',
            'level' => 3,
            'competency_summary' => 'Summary'
          }
        ],
        'discovered_skills' => []
      }

      allow(gemini_client).to receive(:generate_content).and_return(llm_response)

      expect { generator.call }.to raise_error(StandardError)
      expect(portfolio.reload.portfolio_skills.count).to eq(1)
      expect(portfolio.portfolio_skills.first.id).to eq(old_skill.id)
    end
  end

  describe 'Cacat e: Status tidak langsung failed saat retry Sidekiq aktif' do
    it 'tidak mengubah status portfolio menjadi failed di Generator saat error terjadi' do
      portfolio = create(:portfolio, session: session, generation_status: 'pending')
      allow(gemini_client).to receive(:generate_content).and_raise(Faraday::ConnectionFailed.new('Upstream timeout'))

      expect { generator.call }.to raise_error(Faraday::ConnectionFailed)
      expect(portfolio.reload.generation_status).not_to eq('failed')
    end
  end

  describe 'Cacat g: Perlindungan privasi kandidat' do
    it 'tidak menyimpan transkrip kandidat ke dalam generation_error' do
      portfolio = create(:portfolio, session: session, generation_status: 'pending')
      secret_candidate_quote = 'Kandidat rahasia: gajiku saat ini 50 juta dan tinggal di Jakarta Selatan.'

      allow(gemini_client).to receive(:generate_content).and_raise(
        StandardError.new("Error processing prompt with candidate text: #{secret_candidate_quote}")
      )

      expect { generator.call }.to raise_error(StandardError)
      expect(portfolio.reload.generation_error.to_s).not_to include(secret_candidate_quote)
    end
  end

  describe 'Cacat h: Validasi format respons Gemini' do
    it 'menangani respons JSON rusak dengan error terstruktur' do
      allow(gemini_client).to receive(:generate_content).and_return('Bukan JSON valid, format rusak {{{')

      expect { generator.call }.to raise_error(StandardError)
    end

    it 'menolak respons dengan field hilang atau tipe root tidak valid' do
      allow(gemini_client).to receive(:generate_content).and_return({ 'invalid_root' => 123 })

      expect { generator.call }.to raise_error(StandardError)
    end

    it 'menolak respons jika configured_skills bukan array' do
      allow(gemini_client).to receive(:generate_content).and_return({
        'configured_skills' => 'bukan sebuah array',
        'discovered_skills' => []
      })

      expect { generator.call }.to raise_error(StandardError)
    end

    it 'menolak respons jika item skill di dalam configured_skills bukan hash valid' do
      allow(gemini_client).to receive(:generate_content).and_return({
        'configured_skills' => ['bukan hash item'],
        'discovered_skills' => []
      })

      expect { generator.call }.to raise_error(StandardError)
    end
  end

  describe 'Cacat i: Override assessor terjaga saat regenerate' do
    it 'mempertahankan override assessor pada skill yang sama setelah regenerasi' do
      portfolio = create(:portfolio, session: session, generation_status: 'complete')
      skill = create(
        :portfolio_skill,
        portfolio: portfolio,
        skill_id: 'sk-pg',
        skill_label: 'PostgreSQL Performance',
        ai_level: 2
      )

      skill.create_assessor_override!(
        ai_level: 2,
        override_level: 4,
        assessor_notes: 'Pengalaman nyata terlihat mendalam di transkrip',
        overridden_by: 1
      )

      llm_response = {
        'configured_skills' => [
          {
            'skill_id' => 'sk-pg',
            'skill_label' => 'PostgreSQL Performance',
            'level' => 3,
            'confidence' => 'high',
            'evidence' => ['Saya menambahkan composite index pada tabel orders untuk optimasi query.'],
            'competency_summary' => 'Regenerated summary'
          }
        ],
        'discovered_skills' => []
      }

      allow(gemini_client).to receive(:generate_content).and_return(llm_response)

      generator.call

      new_skill = portfolio.reload.portfolio_skills.find_by(skill_id: 'sk-pg')
      expect(new_skill).to be_present
      expect(new_skill.assessor_override).to be_present
      expect(new_skill.assessor_override.override_level).to eq(4)
      expect(new_skill.assessor_override.assessor_notes).to eq('Pengalaman nyata terlihat mendalam di transkrip')
    end
  end

  describe 'Job zombie tidak menimpa hasil generasi yang lebih baru' do
    it 'membatalkan penyimpanan jika token generasi sudah berubah' do
      portfolio = create(:portfolio, session: session, generation_status: 'pending')

      llm_response = {
        'configured_skills' => [
          {
            'skill_id' => 'sk-pg',
            'skill_label' => 'PostgreSQL Performance',
            'level' => 3,
            'confidence' => 'high',
            'evidence' => ['Saya menambahkan composite index pada tabel orders untuk optimasi query.'],
            'competency_summary' => 'Summary'
          }
        ],
        'discovered_skills' => []
      }

      allow(gemini_client).to receive(:generate_content) do
        portfolio.update_columns(generation_started_at: Time.current + 1.minute)
        llm_response
      end

      expect { generator.call }.to raise_error(StandardError)
    end
  end
end
