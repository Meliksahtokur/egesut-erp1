#!/usr/bin/env python3
"""
Mini-Agent Enhanced Search Tool
================================
Gelişmiş bellek arama aracı - SQLite FTS5 + çoklu filtreler.

Kullanım:
    python3 search_tool.py --query "arama ifadesi"
    python3 search_tool.py --query "veritabanı" --category "tech_stack"
    python3 search_tool.py --query "hata" --from "2025-04-01" --to "2025-04-05"
    python3 search_tool.py --query "bellek" --tags "sqlite,fts5"
    python3 search_tool.py --query "proje" --limit 5 --format json

Örnekler:
    # RPC ile ilgili her şeyi bul
    python3 search_tool.py --query "RPC"
    
    # Sadece kritik kurallar kategorisinde ara
    python3 search_tool.py --query "YASAK" --category "critical_rules"
    
    # Son bir haftada eklenen notları bul
    python3 search_tool.py --query "EgeSüt" --from "2025-03-29"
    
    # Belirli etiketlere sahip notları bul
    python3 search_tool.py --query "bellek" --tags "enhancement,sqlite"
    
    # JSON formatında çıktı al
    python3 search_tool.py --query "bellek" --format json
"""

import sqlite3
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Optional, Any

# Konfigürasyon
MEMORY_DB = ".claude/memory/memory.db"

# Renk kodları
COLORS = {
    "header": "\033[95m",
    "blue": "\033[94m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "red": "\033[91m",
    "cyan": "\033[96m",
    "bold": "\033[1m",
    "dim": "\033[2m",
    "end": "\033[0m"
}


class MemorySearch:
    """Gelişmiş bellek arama motoru"""
    
    def __init__(self, db_path: str = MEMORY_DB):
        self.db_path = db_path
        self.conn = None
    
    def connect(self):
        """Veritabanına bağlan"""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
    
    def close(self):
        """Bağlantıyı kapat"""
        if self.conn:
            self.conn.close()
            self.conn = None
    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
    
    def search(
        self,
        query: str,
        category: Optional[str] = None,
        tags: Optional[List[str]] = None,
        date_from: Optional[str] = None,
        date_to: Optional[str] = None,
        limit: int = 10,
        format: str = "text"
    ) -> List[Dict[str, Any]]:
        """
        Gelişmiş arama
        
        Args:
            query: Arama ifadesi (zorunlu)
            category: Kategori filtresi (opsiyonel)
            tags: Etiket listesi (opsiyonel)
            date_from: Başlangıç tarihi (YYYY-MM-DD, opsiyonel)
            date_to: Bitiş tarihi (YYYY-MM-DD, opsiyonel)
            limit: Maksimum sonuç sayısı (varsayılan: 10)
            format: Çıktı formatı ("text" veya "json")
        
        Returns:
            Arama sonuçları listesi
        """
        if not query:
            raise ValueError("query parametresi zorunludur")
        
        cursor = self.conn.cursor()
        
        # FTS5 sorgusu oluştur
        fts_query = self._build_fts_query(query)
        
        # SQL sorgusu
        sql_parts = [
            """
            SELECT notes.*, 
                   bm25(notes_fts) as rank,
                   highlight(notes_fts, 0, '{mark_start}', '{mark_end}') as highlighted_content
            FROM notes_fts
            JOIN notes ON notes.id = notes_fts.rowid
            WHERE notes_fts MATCH ?
            """.format(mark_start='<mark>', mark_end='</mark>')
        ]
        
        params = [fts_query]
        
        # Kategori filtresi
        if category:
            sql_parts.append("AND notes.category = ?")
            params.append(category)
        
        # Tarih aralığı filtresi
        if date_from:
            sql_parts.append("AND notes.timestamp >= ?")
            params.append(f"{date_from}T00:00:00")
        
        if date_to:
            sql_parts.append("AND notes.timestamp <= ?")
            params.append(f"{date_to}T23:59:59")
        
        # Etiket filtresi (JSON array üzerinden)
        if tags:
            for tag in tags:
                sql_parts.append("AND notes.tags LIKE ?")
                params.append(f'%"{tag}"%')
        
        # Sıralama ve limit
        sql_parts.append("ORDER BY rank LIMIT ?")
        params.append(limit)
        
        sql = " ".join(sql_parts)
        
        cursor.execute(sql, params)
        rows = cursor.fetchall()
        
        results = []
        for row in rows:
            result = dict(row)
            # JSON fields parse et
            result['tags'] = json.loads(result.get('tags', '[]'))
            result['related'] = json.loads(result.get('related', '[]'))
            results.append(result)
        
        return results
    
    def _build_fts_query(self, query: str) -> str:
        """
        FTS5 sorgusunu oluştur
        - Phrase search için tırnak ekle
        - OR/AND operatörlerini destekle
        """
        query = query.strip()
        
        # Eğer zaten phrase search ise (tırnak içinde)
        if query.startswith('"') and query.endswith('"'):
            return query
        
        # Kelimeleri ayır ve FTS5 syntax oluştur
        words = query.split()
        
        if len(words) == 1:
            # Tek kelime - wildcard ekle
            return f'{words[0]}*'
        else:
            # Çok kelime - AND ile birleştir
            return ' AND '.join(words)
    
    def get_categories(self) -> List[str]:
        """Mevcut kategorileri al"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT DISTINCT category FROM notes ORDER BY category")
        return [row['category'] for row in cursor.fetchall()]
    
    def get_all_tags(self) -> List[str]:
        """Tüm etiketleri al"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT tags FROM notes")
        all_tags = set()
        for row in cursor.fetchall():
            try:
                tags = json.loads(row['tags'])
                all_tags.update(tags)
            except:
                pass
        return sorted(all_tags)
    
    def get_date_range(self) -> Dict[str, str]:
        """Veritabanındaki tarih aralığını al"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT MIN(timestamp) as min_date, MAX(timestamp) as max_date FROM notes")
        row = cursor.fetchone()
        return {
            'min': row['min_date'][:10] if row['min_date'] else None,
            'max': row['max_date'][:10] if row['max_date'] else None
        }


def print_results_text(results: List[Dict], query: str, search_time: float = None):
    """Sonuçları text formatında yazdır"""
    if not results:
        print(f"\n{COLORS['yellow']}⚠ Sonuç bulunamadı: '{query}'{COLORS['end']}")
        return
    
    print(f"\n{COLORS['bold']}{COLORS['header']}╔{'═' * 70}╗{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}║{' ' * 70}║{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}║  🔍 ARAMA SONUCU: {query:<50}║{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}║{' ' * 70}║{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}╚{'═' * 70}╝{COLORS['end']}\n")
    
    for i, result in enumerate(results, 1):
        # Kategori rengi belirle
        cat = result['category']
        if cat in ['critical_rules', 'known_issues']:
            cat_color = COLORS['red']
        elif cat in ['project', 'tech_stack']:
            cat_color = COLORS['green']
        elif 'memory' in cat or 'sqlite' in cat:
            cat_color = COLORS['cyan']
        else:
            cat_color = COLORS['blue']
        
        # Tarih formatla
        timestamp = result['timestamp'][:16].replace('T', ' ')
        
        # İçerik uzunluğu kontrolü
        content = result.get('highlighted_content', result['content'])
        if len(content) > 200:
            content = content[:200] + "..."
        
        print(f"{COLORS['bold']}{i}. {result.get('highlighted_content', result['content'])[:100]}...{COLORS['end']}")
        print(f"   {cat_color}[{cat}]{COLORS['end']} | 📅 {timestamp} | 📊 rank: {result['rank']:.2f}")
        
        # Etiketler varsa göster
        if result.get('tags'):
            tags_str = ", ".join([f"{COLORS['cyan']}{t}{COLORS['end']}" for t in result['tags']])
            print(f"   🏷️  Etiketler: {tags_str}")
        
        print()
    
    # Özet
    print(f"{COLORS['dim']}{'─' * 70}{COLORS['end']}")
    print(f"{COLORS['green']}✅ {len(results)} sonuç bulundu{COLORS['end']}" + 
          (f" ({search_time*1000:.1f}ms)" if search_time else ""))
    print()


def print_results_json(results: List[Dict], query: str):
    """Sonuçları JSON formatında yazdır"""
    output = {
        "query": query,
        "count": len(results),
        "results": results
    }
    print(json.dumps(output, indent=2, ensure_ascii=False, default=str))


def print_categories(search: MemorySearch):
    """Mevcut kategorileri listele"""
    categories = search.get_categories()
    print(f"\n{COLORS['bold']}📁 Mevcut Kategoriler ({len(categories)}){COLORS['end']}\n")
    for cat in categories:
        print(f"  • {COLORS['blue']}{cat}{COLORS['end']}")
    print()


def print_tags(search: MemorySearch):
    """Tüm etiketleri listele"""
    tags = search.get_all_tags()
    print(f"\n{COLORS['bold']}🏷️  Tüm Etiketler ({len(tags)}){COLORS['end']}\n")
    for tag in tags:
        print(f"  • {COLORS['cyan']}{tag}{COLORS['end']}")
    print()


def main():
    """Ana fonksiyon"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Mini-Agent Enhanced Search Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Örnekler:
  python3 search_tool.py --query "RPC"
  python3 search_tool.py --query "veritabanı" --category "tech_stack"
  python3 search_tool.py --query "hata" --from "2025-04-01"
  python3 search_tool.py --query "bellek" --tags "sqlite,fts5"
  python3 search_tool.py --list-categories
  python3 search_tool.py --list-tags
        """
    )
    
    # Arama parametreleri
    parser.add_argument('--query', '-q', type=str, help='Arama ifadesi (zorunlu)')
    parser.add_argument('--category', '-c', type=str, help='Kategori filtresi')
    parser.add_argument('--tags', '-t', type=str, help='Etiketler (virgülle ayrılmış)')
    parser.add_argument('--from', dest='date_from', type=str, help='Başlangıç tarihi (YYYY-MM-DD)')
    parser.add_argument('--to', dest='date_to', type=str, help='Bitiş tarihi (YYYY-MM-DD)')
    parser.add_argument('--limit', '-l', type=int, default=10, help='Maksimum sonuç (varsayılan: 10)')
    parser.add_argument('--format', '-f', choices=['text', 'json'], default='text', help='Çıktı formatı')
    
    # Bilgi komutları
    parser.add_argument('--list-categories', action='store_true', help='Mevcut kategorileri listele')
    parser.add_argument('--list-tags', action='store_true', help='Tüm etiketleri listele')
    parser.add_argument('--info', action='store_true', help='Veritabanı bilgilerini göster')
    
    # Veritabanı yolu
    parser.add_argument('--db', default=MEMORY_DB, help=f'Veritabanı yolu (varsayılan: {MEMORY_DB})')
    
    args = parser.parse_args()
    
    search = MemorySearch(args.db)
    
    # Info modu
    if args.info:
        with search:
            date_range = search.get_date_range()
            categories = search.get_categories()
            tags = search.get_all_tags()
            
            print(f"\n{COLORS['bold']}{COLORS['header']}╔════════════════════════════════════════════════════════════════╗{COLORS['end']}")
            print(f"{COLORS['bold']}{COLORS['header']}║           Mini-Agent Memory - Veritabanı Bilgisi               ║{COLORS['end']}")
            print(f"{COLORS['bold']}{COLORS['header']}╚════════════════════════════════════════════════════════════════╝{COLORS['end']}\n")
            
            print(f"  📂 Veritabanı: {COLORS['blue']}{args.db}{COLORS['end']}")
            print(f"  📊 Kategori sayısı: {COLORS['green']}{len(categories)}{COLORS['end']}")
            print(f"  🏷️  Etiket sayısı: {COLORS['cyan']}{len(tags)}{COLORS['end']}")
            print(f"  📅 Tarih aralığı: {COLORS['yellow']}{date_range['min']} - {date_range['max']}{COLORS['end']}")
            print()
            
            print_categories(search)
    
    # Kategori listesi
    elif args.list_categories:
        with search:
            print_categories(search)
    
    # Etiket listesi
    elif args.list_tags:
        with search:
            print_tags(search)
    
    # Ana arama
    elif args.query:
        # Etiketleri parse et
        tags = None
        if args.tags:
            tags = [t.strip() for t in args.tags.split(',')]
        
        with search:
            # Arama yap
            start_time = datetime.now()
            results = search.search(
                query=args.query,
                category=args.category,
                tags=tags,
                date_from=args.date_from,
                date_to=args.date_to,
                limit=args.limit
            )
            search_time = (datetime.now() - start_time).total_seconds()
            
            # Çıktı ver
            if args.format == 'json':
                print_results_json(results, args.query)
            else:
                print_results_text(results, args.query, search_time)
    
    else:
        parser.print_help()
        print(f"\n{COLORS['yellow']}⚠ query parametresi zorunludur!{COLORS['end']}")
        print(f"\nBilgi için: python3 search_tool.py --info")
        sys.exit(1)


if __name__ == '__main__':
    main()
