#!/usr/bin/env python3
"""
Claude Agent Intelligence System Health Checker
==============================================
Comprehensive health monitoring for the complete intelligence system.
"""

import json
import sqlite3
import subprocess
import os
import glob
from datetime import datetime, timedelta
from pathlib import Path
import sys

# Colors for output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    END = '\033[0m'

def print_header(title):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{title:^60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")

def print_status(component, status, details=""):
    status_color = Colors.GREEN if status == "✅" else Colors.RED if status == "❌" else Colors.YELLOW
    print(f"{status_color}{status}{Colors.END} {Colors.BOLD}{component}{Colors.END}")
    if details:
        print(f"    {Colors.DIM}{details}{Colors.END}")

def check_memory_system():
    """Check memory system health"""
    print_header("MEMORY INTELLIGENCE SYSTEM")

    # Check database files
    memory_db = Path("/root/opencode-dev/.claude/memory/memory.db")
    knowledge_db = Path("/root/opencode-dev/.claude/memory/knowledge_graph.db")

    if memory_db.exists():
        print_status("Memory Database", "✅", f"Size: {memory_db.stat().st_size / 1024:.1f} KB")
    else:
        print_status("Memory Database", "❌", "Database file missing")
        return False

    if knowledge_db.exists():
        print_status("Knowledge Graph DB", "✅", f"Size: {knowledge_db.stat().st_size / 1024:.1f} KB")
    else:
        print_status("Knowledge Graph DB", "❌", "Database file missing")

    # Check database content
    try:
        conn = sqlite3.connect(memory_db)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM notes")
        note_count = cursor.fetchone()[0]
        print_status("Memory Notes", "✅", f"{note_count} notes stored")

        cursor.execute("SELECT COUNT(DISTINCT category) FROM notes")
        category_count = cursor.fetchone()[0]
        print_status("Memory Categories", "✅", f"{category_count} categories")

        # Check recent activity
        cursor.execute("SELECT COUNT(*) FROM notes WHERE timestamp > datetime('now', '-7 days')")
        recent_count = cursor.fetchone()[0]
        print_status("Recent Activity", "✅", f"{recent_count} notes in last 7 days")

        conn.close()
    except Exception as e:
        print_status("Memory Database Content", "❌", f"Error: {e}")

    # Check Python tools
    tools = [
        "search_tool.py",
        "embedding_service.py",
        "knowledge_graph.py",
        "memory_stats.py"
    ]

    for tool in tools:
        tool_path = Path(f"/root/opencode-dev/.claude/memory/{tool}")
        if tool_path.exists():
            print_status(f"Tool: {tool}", "✅", "Available")
        else:
            print_status(f"Tool: {tool}", "❌", "Missing")

    return True

def check_agent_system():
    """Check mini-agent system health"""
    print_header("AGENT ORCHESTRATION SYSTEM")

    # Check mini-agent installation
    try:
        result = subprocess.run(["which", "mini-agent"], capture_output=True, text=True)
        if result.returncode == 0:
            print_status("Mini-Agent Installation", "✅", f"Path: {result.stdout.strip()}")
        else:
            print_status("Mini-Agent Installation", "❌", "Command not found")
            return False
    except:
        print_status("Mini-Agent Installation", "❌", "Cannot execute which command")
        return False

    # Check version
    try:
        result = subprocess.run(["mini-agent", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            print_status("Mini-Agent Version", "✅", result.stdout.strip())
        else:
            print_status("Mini-Agent Version", "⚠️", "Version check failed")
    except:
        print_status("Mini-Agent Version", "❌", "Cannot get version")

    # Check configuration
    config_path = Path("/root/.mini-agent/config/mcp.json")
    if config_path.exists():
        print_status("Agent Configuration", "✅", "Config file exists")

        try:
            with open(config_path) as f:
                config = json.load(f)
                servers = list(config.get("mcpServers", {}).keys())
                print_status("MCP Servers", "✅", f"Configured: {', '.join(servers)}")
        except Exception as e:
            print_status("Agent Configuration", "❌", f"Config parse error: {e}")
    else:
        print_status("Agent Configuration", "❌", "Config file missing")

    # Check recent logs
    log_dir = Path("/root/.mini-agent/log")
    if log_dir.exists():
        log_files = list(log_dir.glob("agent_run_*.log"))
        recent_logs = [f for f in log_files if (datetime.now() - datetime.fromtimestamp(f.stat().st_mtime)).days < 7]
        print_status("Recent Logs", "✅", f"{len(recent_logs)} runs in last 7 days")

        # Check for errors in recent logs
        error_count = 0
        for log_file in recent_logs[:5]:  # Check last 5 runs
            with open(log_file) as f:
                if "✗ Error:" in f.read():
                    error_count += 1

        if error_count == 0:
            print_status("Recent Run Quality", "✅", "No errors in recent runs")
        else:
            print_status("Recent Run Quality", "⚠️", f"{error_count} runs with errors")
    else:
        print_status("Log Directory", "❌", "Log directory missing")

    return True

def check_api_configuration():
    """Check API key configuration"""
    print_header("API CONFIGURATION")

    # Check MiniMax API key
    minimax_key = os.getenv("MINIMAX_API_KEY")
    if minimax_key:
        if minimax_key == "your_minimax_api_key_here":
            print_status("MiniMax API Key", "⚠️", "Placeholder key detected")
        else:
            print_status("MiniMax API Key", "✅", f"Configured ({minimax_key[:8]}...)")
    else:
        print_status("MiniMax API Key", "❌", "Not set")

    # Check Anthropic API key
    anthropic_key = os.getenv("ANTHROPIC_API_KEY")
    if anthropic_key:
        print_status("Anthropic API Key", "✅", f"Configured ({anthropic_key[:8]}...)")
    else:
        print_status("Anthropic API Key", "❌", "Not set")

    # Check base URLs
    anthropic_base = os.getenv("ANTHROPIC_BASE_URL")
    if anthropic_base:
        print_status("Anthropic Base URL", "✅", anthropic_base)
    else:
        print_status("Anthropic Base URL", "⚠️", "Using default")

    return True

def check_skill_installation():
    """Check Claude skills installation"""
    print_header("CLAUDE SKILLS SYSTEM")

    skills_dir = Path("/root/.claude/skills")
    if not skills_dir.exists():
        print_status("Skills Directory", "❌", "Directory missing")
        return False

    expected_skills = [
        "memory-intelligence",
        "agent-orchestration",
        "autonomous-ai"
    ]

    for skill in expected_skills:
        skill_path = skills_dir / skill / "SKILL.md"
        if skill_path.exists():
            print_status(f"Skill: {skill}", "✅", "Installed")
        else:
            print_status(f"Skill: {skill}", "❌", "Missing")

    # Check guide
    guide_path = skills_dir / "CLAUDE_AGENT_INTELLIGENCE_GUIDE.md"
    if guide_path.exists():
        print_status("Usage Guide", "✅", "Available")
    else:
        print_status("Usage Guide", "❌", "Missing")

    return True

def check_system_resources():
    """Check system resource availability"""
    print_header("SYSTEM RESOURCES")

    # Check disk space
    try:
        result = subprocess.run(["df", "-h", "/root"], capture_output=True, text=True)
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1:
            disk_info = lines[1].split()
            used_percent = disk_info[4].rstrip('%')
            if int(used_percent) < 80:
                print_status("Disk Space", "✅", f"Used: {used_percent}%")
            else:
                print_status("Disk Space", "⚠️", f"Used: {used_percent}% (high)")
    except:
        print_status("Disk Space", "❌", "Cannot check")

    # Check memory
    try:
        with open("/proc/meminfo") as f:
            lines = f.readlines()
            mem_total = int([l for l in lines if l.startswith("MemTotal:")][0].split()[1])
            mem_available = int([l for l in lines if l.startswith("MemAvailable:")][0].split()[1])
            mem_percent = ((mem_total - mem_available) / mem_total) * 100

            if mem_percent < 80:
                print_status("Memory Usage", "✅", f"Used: {mem_percent:.1f}%")
            else:
                print_status("Memory Usage", "⚠️", f"Used: {mem_percent:.1f}% (high)")
    except:
        print_status("Memory Usage", "❌", "Cannot check")

    # Check Python packages
    required_packages = ["sqlite3", "json", "pathlib"]
    for package in required_packages:
        try:
            __import__(package)
            print_status(f"Python: {package}", "✅", "Available")
        except ImportError:
            print_status(f"Python: {package}", "❌", "Missing")

    return True

def generate_health_summary():
    """Generate overall health summary"""
    print_header("SYSTEM HEALTH SUMMARY")

    # Run all checks
    memory_ok = check_memory_system()
    agent_ok = check_agent_system()
    api_ok = check_api_configuration()
    skills_ok = check_skill_installation()
    resources_ok = check_system_resources()

    # Overall status
    all_ok = all([memory_ok, agent_ok, api_ok, skills_ok, resources_ok])

    if all_ok:
        print(f"\n{Colors.BOLD}{Colors.GREEN}🎉 SYSTEM STATUS: HEALTHY{Colors.END}")
        print(f"{Colors.GREEN}All components are functioning properly.{Colors.END}")
        print(f"{Colors.DIM}Ready for autonomous intelligence operations.{Colors.END}")
    else:
        print(f"\n{Colors.BOLD}{Colors.YELLOW}⚠️  SYSTEM STATUS: NEEDS ATTENTION{Colors.END}")
        print(f"{Colors.YELLOW}Some components require maintenance.{Colors.END}")
        print(f"{Colors.DIM}Check the details above and run repairs if needed.{Colors.END}")

    # Suggestions
    print(f"\n{Colors.BOLD}Quick Actions:{Colors.END}")
    print(f"{Colors.DIM}• Run memory search test: python3 /root/opencode-dev/.claude/memory/search_tool.py --query 'test' --limit 1{Colors.END}")
    print(f"{Colors.DIM}• Test agent spawn: mini-agent --task 'system health check'{Colors.END}")
    print(f"{Colors.DIM}• View usage guide: cat /root/.claude/skills/CLAUDE_AGENT_INTELLIGENCE_GUIDE.md{Colors.END}")

def main():
    print(f"{Colors.BOLD}{Colors.CYAN}Claude Agent Intelligence System Health Check{Colors.END}")
    print(f"{Colors.DIM}Comprehensive system status analysis{Colors.END}")

    generate_health_summary()

    print(f"\n{Colors.DIM}Health check completed at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{Colors.END}")

if __name__ == "__main__":
    main()