# AI Verification Log

Log ini mencatat keraguan, kesalahan asumsi, deteksi cacat tersembunyi, dan bukti perbaikan selama pengerjaan case study.

## Log 1: Dependensi AssessorOverride terhadap ai_level NULL
- **Apa yang ditemukan / diragukan**: Saat `portfolio_skills.ai_level` dijadikan nullable (untuk skill tidak ternilai / unassessed), `assessor_overrides.ai_level` masih memiliki constraint `null: false` dan validasi `in: 1..5`. Jika asesor meng-override skill yang unassessed (`ai_level: nil`), `PortfolioSkillsController#override` akan gagal menyimpan record karena `ai_level` bernilai `nil`.
- **Bagaimana ketahuan**: Membaca implementasi `PortfolioSkillsController#override` (baris 26-30) dan `assessor_overrides` schema definition.
- **Rekomendasi / Bagaimana ditangani**: Dilaporkan pada GATE 2; migrasi fokus pada `portfolio_skills` dan `portfolios` sesuai cakupan misi, namun ditandai bahwa `assessor_overrides` juga perlu mengakomodasi `ai_level: nil` bila asesor meng-override skill unassessed.

