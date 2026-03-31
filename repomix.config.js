export default {
  output: {
    filePath: "repomix-output.xml",
    style: "xml",
    showLineNumbers: true,
    copyToClipboard: false,
    headerText: "EgeSüt ERP — Kaynak Kodu ve Mimari Bağlamı\nVanilla JS PWA + Supabase backend. İş mantığı DB katmanında, frontend sadece render eder.",
  },
  include: [
    // Proje tanımı
    "README.md",
    "ARCHITECTURE.md",
    "db_schema_snapshot.md",

    // Kaynak kod
    "index.html",
    "js/*.js",
    "sw.js",

    // Veritabanı
    "supabase/migrations/*.sql",

    // Alan kuralları ve API referansı
    ".claude/domain-rules.md",
    ".claude/rpc-reference.md",

    // Aktif sorunlar
    ".claude/knowledge/bugs.md",
  ],
  ignore: {
    useGitignore: true,
    useDefaultPatterns: true,
    customPatterns: [
      // Bağımlılıklar
      "node_modules/**",
      "package-lock.json",

      // Test altyapısı
      "tests/**",
      "test-results/**",
      "playwright.config.js",

      // Eski / eskimiş dökümanlar
      "PROJE_DURUMU.md",
      "SPEC.md",
      "LastSpec.md",
      "database_snapshot-1.md",
      "SONARCLOUD_REMEDIATION_PLAN.md",
      "ReFactorRoadmap.md",
      "RefactorRoadmap.md",

      // Yardımcı scriptler
      "patch.py",
      "apply.py",

      // Claude iç dosyaları (Gemini için gereksiz)
      ".claude/**",
      "CLAUDE.md",

      // Bu dosyanın kendisi
      "repomix.config.js",
      "repomix-output.xml",
    ],
  },
}
