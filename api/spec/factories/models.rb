# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Tenant #{n}" }
    sequence(:scheme) { |n| "tenant-#{n}" }
    sequence(:identifier) { |n| "org-#{n}" }
    sequence(:host) { |n| "tenant#{n}.example.com" }
    alias_hosts { [] }
    config { {} }
  end

  factory :assessment do
    sequence(:name) { |n| "Fullstack Engineer Assessment #{n}" }
    time_limit_min { 45 }
    language { 'en' }
    tenant_id { 1 }
    created_by { 1 }
    system_prompt { 'You are an interviewer.' }
  end

  factory :assessment_skill do
    assessment
    sequence(:skill_label) { |n| "Skill #{n}" }
    sequence(:skill_id) { |n| "sk-#{n}" }
    is_custom { false }
    expected_level { 3 }
    display_order { 1 }
    l1_anchor { 'Novice understanding' }
    l2_anchor { 'Applies routine patterns' }
    l3_anchor { 'Solves ambiguous problems' }
    l4_anchor { 'Cross-team architectural design' }
    l5_anchor { 'Industry authority' }
  end

  factory :session do
    assessment
    tenant_id { assessment.tenant_id }
    status { 'ended' }
    candidate_name { 'Budi Pratama' }
    candidate_id { 101 }
  end

  factory :transcript_turn do
    session
    sequence(:turn_number) { |n| n }
    speaker { 'candidate' }
    text { 'Saya mengoptimalkan database dengan menambahkan composite index.' }
  end

  factory :coverage_map do
    session
    sequence(:skill_label) { |n| "Skill #{n}" }
    sequence(:skill_id) { |n| "sk-#{n}" }
    state { 'covered' }
    probe_count { 3 }
    is_discovered { false }
  end

  factory :portfolio do
    session
    candidate_id { session.candidate_id }
    generation_status { 'pending' }
  end

  factory :portfolio_skill do
    portfolio
    sequence(:skill_label) { |n| "Skill #{n}" }
    sequence(:skill_id) { |n| "sk-#{n}" }
    is_discovered { false }
    ai_level { 3 }
    ai_confidence { 'high' }
    evidence { ['Saya mengoptimalkan database dengan menambahkan composite index.'] }
    competency_summary { 'Strong database optimization capabilities.' }
  end
end

