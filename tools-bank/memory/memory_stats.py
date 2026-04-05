#!/usr/bin/env python3
"""
Mini-Agent Memory Statistics Tool
==================================
Bellek kullanım istatistiklerini analiz eder ve raporlar.

Kullanım:
    python memory_stats.py [--json] [--suggest-cleanup]
    
Örnekler:
    python memory_stats.py              # Detaylı rapor
    python memory_stats.py --json      # JSON formatında çıktı
    python_memory_stats.py --suggest-cleanup  # Temizlik önerileri
"""

import json
import os
import sys
from datetime import datetime, timedelta
from collections import defaultdict
from pathlib import Path

# Konfigürasyon
MEMORY_FILE = ".agent_memory.json"
COLORS = {
    "header": "\033[95m",
    "blue": "\033[94m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "red": "\033[91m",
    "bold": "\033[1m",
    "end": "\033[0m"
}


class MemoryStats:
    """Bellek istatistik analizörü"""
    
    def __init__(self, memory_file=MEMORY_FILE):
        self.memory_file = memory_file
        self.data = []
        self.stats = {}
        
    def load(self):
        """Bellek dosyasını yükle"""
        if not os.path.exists(self.memory_file):
            print(f"{COLORS['red']}✗ Hata: {self.memory_file} bulunamadı{self.memory_file}{COLORS['end']}")
            return False
        
        try:
            with open(self.memory_file, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            return True
        except json.JSONDecodeError as e:
            print(f"{COLORS['red']}✗ JSON parse hatası: {e}{COLORS['end']}")
            return False
        except Exception as e:
            print(f"{COLORS['red']}✗ Dosya okuma hatası: {e}{COLORS['end']}")
            return False
    
    def analyze(self):
        """İstatistikleri analiz et"""
        if not self.data:
            return
        
        # Temel istatistikler
        self.stats['total_notes'] = len(self.data)
        self.stats['file_size'] = os.path.getsize(self.memory_file)
        
        # Kategori dağılımı
        categories = defaultdict(int)
        for note in self.data:
            cat = note.get('category', 'unknown')
            categories[cat] += 1
        self.stats['categories'] = dict(categories)
        
        # Yaş dağılımı (gün bazında)
        now = datetime.now()
        ages = defaultdict(int)
        for note in self.data:
            try:
                ts = datetime.fromisoformat(note.get('timestamp', '').replace('Z', '+00:00'))
                age_days = (now - ts).days
                if age_days == 0:
                    ages['bugün'] += 1
                elif age_days == 1:
                    ages['dün'] += 1
                elif age_days < 7:
                    ages['bu-hafta'] += 1
                elif age_days < 30:
                    ages['bu-ay'] += 1
                else:
                    ages['30+gün'] += 1
            except:
                ages['bilinmeyen'] += 1
        self.stats['age_distribution'] = dict(ages)
        
        # İçerik uzunlukları
        content_lengths = [len(n.get('content', '')) for n in self.data]
        self.stats['avg_content_length'] = sum(content_lengths) // len(content_lengths) if content_lengths else 0
        self.stats['max_content_length'] = max(content_lengths) if content_lengths else 0
        self.stats['min_content_length'] = min(content_lengths) if content_lengths else 0
        
        # Alan kullanım analizi
        self.stats['field_analysis'] = self._analyze_fields()
        
        # Kalite puanı (basit heuristik)
        self.stats['quality_score'] = self._calculate_quality_score()
        
        # Temizlik önerileri
        self.stats['cleanup_suggestions'] = self._generate_cleanup_suggestions()
    
    def _analyze_fields(self):
        """Alan kullanım analizi"""
        field_usage = defaultdict(lambda: {'count': 0, 'empty': 0})
        
        for note in self.data:
            for key in ['timestamp', 'category', 'content']:
                field_usage[key]['count'] += 1
                if not note.get(key):
                    field_usage[key]['empty'] += 1
            
            # Ek alanlar
            for key in note.keys():
                if key not in ['timestamp', 'category', 'content']:
                    field_usage[key]['count'] += 1
                    if not note.get(key):
                        field_usage[key]['empty'] += 1
        
        return dict(field_usage)
    
    def _calculate_quality_score(self):
        """Bellek kalite puanı hesapla (0-100)"""
        score = 50  # Başlangıç
        
        # Kategori çeşitliliği (+10)
        unique_cats = len(self.stats.get('categories', {}))
        if unique_cats >= 10:
            score += 10
        elif unique_cats >= 5:
            score += 5
        
        # Ortalama içerik uzunluğu (+15)
        avg_len = self.stats.get('avg_content_length', 0)
        if avg_len >= 200:
            score += 15
        elif avg_len >= 100:
            score += 10
        
        # Dosya boyutu optimizasyonu (+10)
        size_kb = self.stats.get('file_size', 0) / 1024
        if size_kb < 10:
            score += 10
        elif size_kb < 20:
            score += 5
        
        # Zaman damgası dağılımı (+15)
        age_dist = self.stats.get('age_distribution', {})
        if 'bu-hafta' in age_dist or 'bu-ay' in age_dist:
            score += 15
        elif '30+gün' in age_dist and age_dist.get('30+gün', 0) > len(self.data) * 0.5:
            score -= 10  # Çok eski notlar
        
        return min(100, max(0, score))
    
    def _generate_cleanup_suggestions(self):
        """Temizlik önerileri oluştur"""
        suggestions = []
        
        # Çok kısa içerikler
        short_notes = [n for n in self.data if len(n.get('content', '')) < 30]
        if short_notes:
            suggestions.append({
                'type': 'short_content',
                'severity': 'low',
                'count': len(short_notes),
                'message': f"{len(short_notes)} not çok kısa içerik içeriyor (<30 karakter)",
                'action': 'İçeriği genişlet veya notu sil'
            })
        
        # Çok eski notlar (60+ gün)
        old_notes = []
        now = datetime.now()
        for note in self.data:
            try:
                ts = datetime.fromisoformat(note.get('timestamp', '').replace('Z', '+00:00'))
                if (now - ts).days > 60:
                    old_notes.append(note)
            except:
                pass
        
        if old_notes:
            suggestions.append({
                'type': 'old_notes',
                'severity': 'medium',
                'count': len(old_notes),
                'message': f"{len(old_notes)} not 60+ gün eski",
                'action': 'Gözden geçir ve güncelle veya arşivle'
            })
        
        # Tekrarlanan kategoriler
        cat_counts = self.stats.get('categories', {})
        single_category_notes = [n for n in self.data if cat_counts.get(n.get('category')) == 1]
        if single_category_notes:
            suggestions.append({
                'type': 'orphan_categories',
                'severity': 'low',
                'count': len(single_category_notes),
                'message': f"{len(single_category_notes)} not benzersiz kategoride (birleştirilebilir)",
                'action': 'Benzer notları birleştir'
            })
        
        # Eksik timestamp
        no_timestamp = [n for n in self.data if not n.get('timestamp')]
        if no_timestamp:
            suggestions.append({
                'type': 'missing_timestamp',
                'severity': 'high',
                'count': len(no_timestamp),
                'message': f"{len(no_timestamp)} not'ta timestamp eksik",
                'action': 'Timestamp ekle'
            })
        
        return suggestions
    
    def print_report(self, suggest_cleanup=False):
        """İstatistik raporunu yazdır"""
        if not self.stats:
            print(f"{COLORS['red']}✗ Analiz yapılmadı{self.memory_file}{COLORS['end']}")
            return
        
        print(f"\n{COLORS['bold']}{COLORS['header']}╔════════════════════════════════════════════════════════════════╗{COLORS['end']}")
        print(f"{COLORS['bold']}{COLORS['header']}║       Mini-Agent Bellek İstatistik Raporu                       ║{COLORS['end']}")
        print(f"{COLORS['bold']}{COLORS['header']}╚════════════════════════════════════════════════════════════════╝{COLORS['end']}\n")
        
        # 1. Temel İstatistikler
        print(f"{COLORS['bold']}{COLORS['blue']}📊 Temel İstatistikler{self.memory_file}{COLORS['end']}")
        print(f"{'─' * 60}")
        print(f"  Toplam Not Sayısı:    {COLORS['green']}{self.stats['total_notes']}{COLORS['end']}")
        print(f"  Dosya Boyutu:         {self.stats['file_size']:,} byte ({self.stats['file_size']/1024:.2f} KB)")
        print(f"  Kalite Puanı:         {self._get_quality_color()}{self.stats['quality_score']}/100{self.memory_file}{COLORS['end']}")
        print()
        
        # 2. Kategori Dağılımı
        print(f"{COLORS['bold']}{COLORS['blue']}📁 Kategori Dağılımı{self.memory_file}{COLORS['end']}")
        print(f"{'─' * 60}")
        categories = self.stats['categories']
        total = sum(categories.values())
        sorted_cats = sorted(categories.items(), key=lambda x: x[1], reverse=True)
        
        for cat, count in sorted_cats:
            pct = (count / total * 100) if total > 0 else 0
            bar_len = int(pct / 5)
            bar = '█' * bar_len + '░' * (20 - bar_len)
            print(f"  {cat:20s} │ {bar} │ {count:2d} ({pct:5.1f}%)")
        print()
        
        # 3. Yaş Dağılımı
        print(f"{COLORS['bold']}{COLORS['blue']}📅 Yaş Dağılımı{self.memory_file}{COLORS['end']}")
        print(f"{'─' * 60}")
        age_order = ['bugün', 'dün', 'bu-hafta', 'bu-ay', '30+gün', 'bilinmeyen']
        age_dist = self.stats['age_distribution']
        for period in age_order:
            count = age_dist.get(period, 0)
            if count > 0:
                pct = (count / self.stats['total_notes'] * 100)
                bar_len = int(pct / 5)
                bar = '█' * bar_len + '░' * (20 - bar_len)
                print(f"  {period:15s} │ {bar} │ {count:2d} ({pct:5.1f}%)")
        print()
        
        # 4. İçerik Analizi
        print(f"{COLORS['bold']}{COLORS['blue']}📝 İçerik Analizi{self.memory_file}{COLORS['end']}")
        print(f"{'─' * 60}")
        print(f"  Ortalama içerik uzunluğu: {self.stats['avg_content_length']} karakter")
        print(f"  Maksimum içerik uzunluğu: {self.stats['max_content_length']} karakter")
        print(f"  Minimum içerik uzunluğu: {self.stats['min_content_length']} karakter")
        print()
        
        # 5. Alan Kullanımı
        print(f"{COLORS['bold']}{COLORS['blue']}🔧 Alan Kullanımı{self.memory_file}{COLORS['end']}")
        print(f"{'─' * 60}")
        field_analysis = self.stats['field_analysis']
        for field, data in field_analysis.items():
            fill_rate = ((data['count'] - data['empty']) / data['count'] * 100) if data['count'] > 0 else 0
            status = f"{COLORS['green']}✓%{fill_rate:.0f}{COLORS['end']}" if fill_rate > 80 else f"{COLORS['yellow']}⚤%{fill_rate:.0f}{COLORS['end']}"
            print(f"  {field:20s}: {status}")
        print()
        
        # 6. Temizlik Önerileri
        if suggest_cleanup and self.stats['cleanup_suggestions']:
            print(f"{COLORS['bold']}{COLORS['yellow']}🧹 Temizlik Önerileri{self.memory_file}{COLORS['end']}")
            print(f"{'─' * 60}")
            for i, suggestion in enumerate(self.stats['cleanup_suggestions'], 1):
                severity_color = {
                    'high': COLORS['red'],
                    'medium': COLORS['yellow'],
                    'low': COLORS['green']
                }.get(suggestion['severity'], COLORS['end'])
                
                print(f"  {i}. [{severity_color}{suggestion['severity'].upper()}{COLORS['end']}] {suggestion['message']}")
                print(f"     → {suggestion['action']}")
            print()
    
    def _get_quality_color(self):
        """Kalite puanına göre renk döndür"""
        score = self.stats['quality_score']
        if score >= 80:
            return COLORS['green']
        elif score >= 60:
            return COLORS['yellow']
        else:
            return COLORS['red']
    
    def to_json(self):
        """İstatistikleri JSON olarak döndür"""
        return json.dumps(self.stats, indent=2, ensure_ascii=False, default=str)


def main():
    """Ana fonksiyon"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Mini-Agent Bellek İstatistikleri')
    parser.add_argument('--json', action='store_true', help='JSON formatında çıktı')
    parser.add_argument('--suggest-cleanup', action='store_true', help='Temizlik önerileri göster')
    parser.add_argument('--file', default=MEMORY_FILE, help='Bellek dosyası yolu')
    args = parser.parse_args()
    
    stats = MemoryStats(args.file)
    
    if not stats.load():
        sys.exit(1)
    
    stats.analyze()
    
    if args.json:
        print(stats.to_json())
    else:
        stats.print_report(suggest_cleanup=args.suggest_cleanup)


if __name__ == '__main__':
    main()
