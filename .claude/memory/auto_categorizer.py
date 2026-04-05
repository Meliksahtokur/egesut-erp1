"""
Auto-categorization Module for Mini-Agent Memory

This module provides automatic category detection for memory notes based on
keyword matching and pattern recognition.

Features:
- Keyword-based category detection (Turkish + English)
- Confidence scoring (0.0 - 1.0)
- Auto-tagging with domain-specific keywords
- Pattern learning from existing notes
- Category suggestion with reasoning

Author: Mini-Agent (MiniMax M2.7)
Version: 1.0
Last Updated: 2025-04-05
"""

import re
from datetime import datetime
from typing import Dict, List, Optional, Tuple


class AutoCategorizer:
    """
    Automatic category detection for memory notes.
    
    Uses keyword matching with weighted scoring to determine
    the most appropriate category for a given content.
    """
    
    # Category definitions with Turkish and English keywords
    CATEGORIES = {
        "project": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "proje", "egesut", "erp", "sistem", "uygulama", "web", "github pages",
                    "canlı", "live", "deployment", "yayın", "versiyon", "roadmap",
                    "çiftlik", "hayvancılık", "süt", "yönetim", "management"
                ],
                "en": [
                    "project", "system", "application", "app", "web", "github pages",
                    "live", "deployment", "version", "roadmap", "farm", "dairy",
                    "management", " livestock", "cattle"
                ]
            },
            "description": "Project-level information, goals, and overview"
        },
        
        "tech_stack": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "vanilla js", "javascript", "html", "css", "pwa", "supabase", "postgresql",
                    "rpc", "rest api", "api", "backend", "frontend", "framework", "kütüphane",
                    "library", "dependency", "paket", "npm", "node", "indexeddb", "offline",
                    "cache", "migration", "github actions", "cli", "database", "veritabanı"
                ],
                "en": [
                    "vanilla js", "javascript", "html", "css", "pwa", "supabase", "postgresql",
                    "rpc", "rest api", "api", "backend", "frontend", "framework", "library",
                    "dependency", "package", "npm", "node", "indexeddb", "offline",
                    "cache", "migration", "github actions", "cli", "database"
                ]
            },
            "description": "Technology stack, tools, and dependencies"
        },
        
        "file_structure": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "dosya", "klasör", "dizin", "kaynak kod", "source code", "modül",
                    "index.html", "js/", "css/", "components", "utils", "helpers",
                    "migration", "supabase/", "config", "ayar", "struct", "yapı"
                ],
                "en": [
                    "file", "folder", "directory", "source code", "module",
                    "index.html", "js/", "css/", "components", "utils", "helpers",
                    "migration", "supabase/", "config", "structure", "architecture"
                ]
            },
            "description": "File and directory structure information"
        },
        
        "critical_rules": {
            "weight": 1.5,
            "keywords": {
                "tr": [
                    "yasak", "dikkat", "kritik", "önemli", "kural", "rule", "禁忌",
                    "restriction", "asla", "never", "mümkün değil", "impossible",
                    "rpc only", "sadece rpc", "free-text yasak", "dropdown zorunlu",
                    "immutable", "değiştirilemez", "silinmez", "paralel yazma yasak",
                    "main branch push yasak", "commit öncesi güncelle"
                ],
                "en": [
                    "forbidden", "critical", "important", "rule", "restriction",
                    "never", "must not", "cannot", "impossible", "rpc only",
                    "dropdown mandatory", "immutable", "do not delete",
                    "parallel write forbidden", "main branch push forbidden"
                ]
            },
            "description": "Critical rules, restrictions, and prohibitions"
        },
        
        "database_schema": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "tablo", "schema", "şema", "database", "veritabanı", "sütun",
                    "column", "satır", "row", "primary key", "foreign key", "fk",
                    "index", "constraint", "kısıtlama", "hayvanlar", "tohumlama",
                    "dogum", "stok", "hastalık", "ilaç", "cases", "vaka", "treatment",
                    "drug", "administration", "ledger", "defter"
                ],
                "en": [
                    "table", "schema", "database", "column", "row",
                    "primary key", "foreign key", "fk", "index", "constraint",
                    "animals", "breeding", "birth", "stock", "disease", "drug",
                    "case", "treatment", "administration", "ledger"
                ]
            },
            "description": "Database schema and table definitions"
        },
        
        "rpc_reference": {
            "weight": 1.2,
            "keywords": {
                "tr": [
                    "rpc", "fonksiyon", "function", "procedure", "stored procedure",
                    "hayvan_ekle", "hayvan_guncelle", "hayvan_not_ekle", "tohumlama_kaydet",
                    "tohumlama_sonuc_gebe", "tohumlama_sonuc_bos", "dogum_kaydet",
                    "abort_kaydet", "kizginlik_kaydet", "create_case", "add_treatment_day",
                    "add_drug_administration", "remove_drug_administration", "close_case",
                    "jsonb", "returns", "returns table", "parameter", "parametre"
                ],
                "en": [
                    "rpc", "function", "procedure", "stored procedure",
                    "hayvan_ekle", "hayvan_guncelle", "hayvan_not_ekle", "tohumlama_kaydet",
                    "tohumlama_sonuc_gebe", "tohumlama_sonuc_bos", "dogum_kaydet",
                    "abort_kaydet", "kizginlik_kaydet", "create_case", "add_treatment_day",
                    "add_drug_administration", "remove_drug_administration", "close_case",
                    "jsonb", "returns", "returns table", "parameter"
                ]
            },
            "description": "RPC function reference and definitions"
        },
        
        "domain_rules": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "domain", "domain kuralı", "iş kuralları", "business rules",
                    "grup", "padok", "erkek", "dişi", "boş", "gebe", "doğum", "abort",
                    "gebelik", "280 gün", "stok", "kullanım", "iade", "pozitif", "negatif",
                    "sağmal", "kuru", "grup_padok", "mapping", "eşleme", "state machine",
                    "durum makinesi", "state", "durum", "transition", "geçiş"
                ],
                "en": [
                    "domain", "business rules", "group", "padok", "male", "female",
                    "empty", "pregnant", "birth", "abort", "pregnancy", "280 days",
                    "stock", "usage", "return", "positive", "negative",
                    "milking", "dry", "grup_padok", "mapping", "state machine",
                    "state", "transition"
                ]
            },
            "description": "Domain-specific business rules"
        },
        
        "commands": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "komut", "command", "cmd", "çalıştır", "run", "execute",
                    "npm install", "npx", "supabase db push", "node --check",
                    "git push", "git commit", "git checkout", "git branch",
                    "pullTables", "renderFromLocal", "renderSafe", "playwright",
                    "test", "testing", "debug", "debugging"
                ],
                "en": [
                    "command", "cmd", "run", "execute",
                    "npm install", "npx", "supabase db push", "node --check",
                    "git push", "git commit", "git checkout", "git branch",
                    "pullTables", "renderFromLocal", "renderSafe", "playwright",
                    "test", "testing", "debug", "debugging"
                ]
            },
            "description": "Commands, CLI usage, and execution instructions"
        },
        
        "known_issues": {
            "weight": 1.3,
            "keywords": {
                "tr": [
                    "bug", "hata", "issue", "problem", "sorun", "eksik", "missing",
                    "yapılmadı", "not done", "incomplete", "monolitik", "3000+ satır",
                    "rpc bypass", "frontend eksik", "ui eksik", "migration eksik",
                    "tohumlama write path", "3 farklı yol", "TODO", "FIXME",
                    "workaround", "geçici çözüm"
                ],
                "en": [
                    "bug", "error", "issue", "problem", "missing", "not done",
                    "incomplete", "monolithic", "3000+ lines", "rpc bypass",
                    "frontend missing", "ui missing", "migration missing",
                    "tohumlama write path", "3 different ways", "TODO", "FIXME",
                    "workaround"
                ]
            },
            "description": "Known bugs, issues, and technical debt"
        },
        
        "mcp_permissions": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "mcp", "tool", "permission", "izin", "github", "context7",
                    "supabase", "search", "query", "list", "execute", "allowed",
                    "izin verilen", "mcp tool", "model context protocol"
                ],
                "en": [
                    "mcp", "tool", "permission", "github", "context7",
                    "supabase", "search", "query", "list", "execute", "allowed",
                    "mcp tool", "model context protocol"
                ]
            },
            "description": "MCP tool permissions and configurations"
        },
        
        "references": {
            "weight": 0.8,
            "keywords": {
                "tr": [
                    "referans", "doküman", "doc", "döküman", "documentation",
                    "readme", "guide", "rehber", "how to", "nasıl", "kılavuz",
                    "CLAUDE.md", "AGENTS.md", "ARCHITECTURE.md", "SPEC.md",
                    "QUICK_REF", "opencode-dev", "egesut-erp1", "workspace"
                ],
                "en": [
                    "reference", "document", "doc", "documentation",
                    "readme", "guide", "how to", "guide",
                    "CLAUDE.md", "AGENTS.md", "ARCHITECTURE.md", "SPEC.md",
                    "QUICK_REF", "opencode-dev", "egesut-erp1", "workspace"
                ]
            },
            "description": "References to other documents and resources"
        },
        
        "agent_identity": {
            "weight": 1.0,
            "keywords": {
                "tr": [
                    "agent", "mini-agent", "minimax", "model", "gpt", "llm",
                    "ai", "yapay zeka", "coding assistant", "coding",
                    "m2.7", "m2.5", "anthropic", "provider", "api key",
                    "base url", "workspace", "çalışma alanı", "identity", "kimlik"
                ],
                "en": [
                    "agent", "mini-agent", "minimax", "model", "gpt", "llm",
                    "ai", "artificial intelligence", "coding assistant", "coding",
                    "m2.7", "m2.5", "anthropic", "provider", "api key",
                    "base url", "workspace", "identity"
                ]
            },
            "description": "Agent identity and configuration"
        }
    }
    
    # Priority keywords for auto-tagging
    PRIORITY_KEYWORDS = {
        "high": ["yasak", "critical", "bug", "hata", "acil", "urgent", "important", "önemli"],
        "medium": ["rpc", "database", "veritabanı", "schema", "api", "endpoint"],
        "low": ["docs", "comment", "yorum", "readme", "reference", "referans"]
    }
    
    def __init__(self, existing_categories: Optional[List[str]] = None):
        """
        Initialize the auto-categorizer.
        
        Args:
            existing_categories: List of categories already in use for pattern learning
        """
        self.existing_categories = existing_categories or []
        self._build_pattern_cache()
    
    def _build_pattern_cache(self):
        """Build internal pattern cache for faster matching."""
        self.pattern_cache = {}
        for category, config in self.CATEGORIES.items():
            all_keywords = []
            for lang, keywords in config["keywords"].items():
                all_keywords.extend([k.lower() for k in keywords])
            self.pattern_cache[category] = {
                "keywords": all_keywords,
                "weight": config["weight"],
                "description": config["description"]
            }
    
    def detect_language(self, text: str) -> str:
        """
        Detect the primary language of the text.
        
        Args:
            text: Input text
            
        Returns:
            'tr', 'en', or 'mixed'
        """
        tr_chars = set('çğıöşüâîûêâîôûÇĞİÖŞÜ')
        en_chars = set('qwertyuiopasdfghjklzxcvbnm')
        
        tr_count = sum(1 for c in text.lower() if c in tr_chars)
        en_count = sum(1 for c in text.lower() if c in en_chars)
        
        if tr_count > en_count * 0.3:
            return 'tr'
        elif en_count > tr_count * 0.3:
            return 'en'
        return 'mixed'
    
    def tokenize(self, text: str) -> List[str]:
        """
        Tokenize text into words for matching.
        
        Args:
            text: Input text
            
        Returns:
            List of lowercase tokens
        """
        # Convert to lowercase
        text = text.lower()
        # Replace special chars with spaces
        text = re.sub(r'[^\w\s]', ' ', text)
        # Split by whitespace
        tokens = text.split()
        # Remove single-char tokens
        tokens = [t for t in tokens if len(t) > 2]
        return tokens
    
    def calculate_confidence(self, category: str, matched_keywords: List[str], 
                            total_tokens: int) -> float:
        """
        Calculate confidence score for a category match.
        
        Args:
            category: Category name
            matched_keywords: List of matched keywords
            total_tokens: Total number of tokens in text
            
        Returns:
            Confidence score between 0.0 and 1.0
        """
        if not matched_keywords:
            return 0.0
        
        base_score = len(matched_keywords) / max(total_tokens, 1)
        
        # Weight by category importance
        category_weight = self.pattern_cache[category]["weight"]
        
        # Calculate final score
        confidence = min(base_score * category_weight * 10, 1.0)
        
        # Boost for exact matches
        for keyword in matched_keywords:
            if keyword in ["rpc", "bug", "hata", "yasak", "critical"]:
                confidence = min(confidence * 1.2, 1.0)
        
        return round(confidence, 3)
    
    def suggest_category(self, content: str) -> Tuple[str, float, List[str], str]:
        """
        Suggest the most appropriate category for given content.
        
        Args:
            content: The note content to categorize
            
        Returns:
            Tuple of (category, confidence, matched_keywords, reasoning)
        """
        if not content or not content.strip():
            return ("general", 0.0, [], "Empty content")
        
        tokens = self.tokenize(content)
        if not tokens:
            return ("general", 0.0, [], "No meaningful tokens found")
        
        category_scores = {}
        matched_keywords_all = {}
        
        for category, config in self.pattern_cache.items():
            matched = []
            for keyword in config["keywords"]:
                keyword_tokens = keyword.split()
                if len(keyword_tokens) == 1:
                    # Single word match
                    if keyword in tokens:
                        matched.append(keyword)
                else:
                    # Multi-word phrase match
                    if keyword in content.lower():
                        matched.append(keyword)
            
            if matched:
                confidence = self.calculate_confidence(category, matched, len(tokens))
                category_scores[category] = confidence
                matched_keywords_all[category] = matched
        
        if not category_scores:
            return ("general", 0.1, [], "No category keywords matched")
        
        # Get best category
        best_category = max(category_scores, key=category_scores.get)
        best_confidence = category_scores[best_category]
        best_keywords = matched_keywords_all[best_category]
        
        reasoning = f"Matched keywords: {', '.join(best_keywords[:5])}"
        if len(best_keywords) > 5:
            reasoning += f" (+{len(best_keywords) - 5} more)"
        
        return (best_category, best_confidence, best_keywords, reasoning)
    
    def suggest_tags(self, content: str, category: str) -> List[str]:
        """
        Suggest tags for given content based on keywords.
        
        Args:
            content: The note content
            category: The assigned category
            
        Returns:
            List of suggested tags
        """
        tokens = self.tokenize(content)
        tags = set()
        
        # Add category as tag
        tags.add(category)
        
        # Extract keywords that are 3+ chars
        for token in tokens:
            if len(token) >= 3 and token not in ['the', 'and', 'for', 'with', 'bir', 'ile', 'icin']:
                tags.add(token)
        
        # Add priority-based tags
        content_lower = content.lower()
        for priority, keywords in self.PRIORITY_KEYWORDS.items():
            if any(kw in content_lower for kw in keywords):
                tags.add(f"priority:{priority}")
        
        # Limit to 10 tags max
        return list(tags)[:10]
    
    def suggest_priority(self, content: str, category: str) -> str:
        """
        Suggest priority level for the note.
        
        Args:
            content: The note content
            category: The assigned category
            
        Returns:
            'high', 'medium', or 'low'
        """
        content_lower = content.lower()
        
        # High priority triggers
        high_triggers = ["bug", "hata", "critical", "kritik", "acil", "urgent", 
                        "yasak", "forbidden", "impossible", "broken", "crash"]
        if any(trigger in content_lower for trigger in high_triggers):
            return "high"
        
        # Low priority triggers
        low_triggers = ["readme", "docs", "documentation", "comment", "yorum",
                       "reference", "referans", "trivial"]
        if any(trigger in content_lower for trigger in low_triggers):
            return "low"
        
        # Category-based defaults
        category_priority = {
            "critical_rules": "high",
            "known_issues": "high",
            "rpc_reference": "medium",
            "database_schema": "medium",
            "domain_rules": "medium",
            "commands": "medium",
            "tech_stack": "low",
            "references": "low"
        }
        
        return category_priority.get(category, "medium")
    
    def categorize_and_enhance(self, content: str, 
                               existing_category: Optional[str] = None) -> Dict:
        """
        Full categorization and enhancement of note content.
        
        Args:
            content: The note content
            existing_category: Optional existing category (for validation)
            
        Returns:
            Dictionary with category, confidence, tags, priority, and reasoning
        """
        # Detect language
        language = self.detect_language(content)
        
        # Get category suggestion
        suggested_category, confidence, matched_keywords, reasoning = \
            self.suggest_category(content)
        
        # Use suggested category if no existing category
        final_category = existing_category or suggested_category
        
        # Suggest tags
        tags = self.suggest_tags(content, final_category)
        
        # Suggest priority
        priority = self.suggest_priority(content, final_category)
        
        return {
            "category": final_category,
            "suggested_category": suggested_category,
            "confidence": confidence,
            "language": language,
            "tags": tags,
            "priority": priority,
            "matched_keywords": matched_keywords[:10],
            "reasoning": reasoning,
            "needs_review": confidence < 0.5
        }
    
    def learn_from_notes(self, notes: List[Dict]):
        """
        Learn category patterns from existing notes.
        
        Args:
            notes: List of note dictionaries with 'category' and 'content' fields
        """
        self.existing_categories = list(set(n.get("category", "general") for n in notes))
        
        # Update pattern cache with learned patterns
        for note in notes:
            content = note.get("content", "")
            category = note.get("category", "general")
            
            if category not in self.CATEGORIES:
                continue
            
            tokens = self.tokenize(content)
            for token in tokens:
                if len(token) >= 4 and token not in self.pattern_cache[category]["keywords"]:
                    self.pattern_cache[category]["keywords"].append(token)
    
    def get_category_info(self, category: str) -> Dict:
        """
        Get information about a specific category.
        
        Args:
            category: Category name
            
        Returns:
            Dictionary with category details
        """
        if category not in self.CATEGORIES:
            return {"error": f"Unknown category: {category}"}
        
        config = self.CATEGORIES[category]
        return {
            "name": category,
            "description": config["description"],
            "weight": config["weight"],
            "keywords_count": sum(len(kw) for kw in config["keywords"].values()),
            "supported_languages": list(config["keywords"].keys())
        }
    
    def list_categories(self) -> List[Dict]:
        """
        List all available categories with details.
        
        Returns:
            List of category information dictionaries
        """
        return [self.get_category_info(cat) for cat in self.CATEGORIES.keys()]


# Convenience functions for direct usage
def auto_categorize(content: str, existing_category: Optional[str] = None) -> Dict:
    """
    Convenience function to auto-categorize content.
    
    Args:
        content: The note content to categorize
        existing_category: Optional existing category
        
    Returns:
        Categorization result dictionary
    """
    categorizer = AutoCategorizer()
    return categorizer.categorize_and_enhance(content, existing_category)


def suggest_tags(content: str, category: str) -> List[str]:
    """
    Convenience function to suggest tags.
    
    Args:
        content: The note content
        category: The assigned category
        
    Returns:
        List of suggested tags
    """
    categorizer = AutoCategorizer()
    return categorizer.suggest_tags(content, category)


def get_all_categories() -> List[Dict]:
    """
    Get all available categories.
    
    Returns:
        List of category information
    """
    categorizer = AutoCategorizer()
    return categorizer.list_categories()


# Example usage
if __name__ == "__main__":
    # Test with sample content
    categorizer = AutoCategorizer()
    
    test_notes = [
        "EgeSüt ERP — 130+ hayvanlık süt çiftliği yönetim sistemi",
        "RPC hayvan_ekle fonksiyonu çalışmıyor, hata alıyorum",
        "Vanilla JS, Supabase, IndexedDB stack kullanıyoruz",
        "YASAK: Main branch'e direkt push yapma"
    ]
    
    print("=" * 60)
    print("Auto-Categorization Test")
    print("=" * 60)
    
    for note in test_notes:
        result = categorizer.categorize_and_enhance(note)
        print(f"\n📝 Content: {note[:50]}...")
        print(f"   Category: {result['category']} (confidence: {result['confidence']})")
        print(f"   Tags: {', '.join(result['tags'][:5])}")
        print(f"   Priority: {result['priority']}")
        print(f"   Reasoning: {result['reasoning']}")
