export default {
  output: {
    filePath: "repomix-output.xml",
    style: "xml",
    showLineNumbers: true,
    copyToClipboard: false,
    headerText:
      "EgeSüt ERP — Kaynak Kodu\nVanilla JS PWA + Supabase backend.",
  },
  include: [
    // Ana sayfa
    "index.html",
    "manifest.json",
    "sw.js",

    // JavaScript kaynak kod
    "js/*.js",
    "js/utils/*.js",

    // Veritabanı migrationları
    "supabase/migrations/*.sql",

    // Proje yapılandırması
    "package.json",
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

      // Bu dosyanın kendisi
      "repomix.config.js",
      "repomix-output.xml",
    ],
  },
};
