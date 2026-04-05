# Claude Agent Intelligence System - Complete Usage Guide

**Version:** 1.0
**Date:** 2026-04-05
**System:** EgeSüt ERP Advanced Intelligence Framework

This guide covers the complete Claude Agent Intelligence System - a unified framework combining memory intelligence, agent orchestration, and autonomous AI capabilities.

---

## 🎯 Quick Start (5 Minutes)

### **1. Basic Memory Search**
```bash
# Search project memory
/skill memory-intelligence

# Then run:
python3 /root/opencode-dev/.claude/memory/search_tool.py --query "RPC" --limit 5
```

### **2. Spawn a Mini-Agent**
```bash
# Basic task delegation
/skill agent-orchestration

# Then run:
mini-agent --workspace /root/opencode-dev --task "analyze code quality"
```

### **3. Autonomous AI Task**
```bash
# Let AI handle everything
/skill autonomous-ai execute "optimize database performance"
```

---

## 📚 System Architecture

### **Three-Tier Intelligence**

```
┌─────────────────────────────────────────────────────────────┐
│                 AUTONOMOUS AI LAYER                         │
│  🧠 Unified Intelligence • Learning • Decision Making        │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                AGENT ORCHESTRATION LAYER                   │
│  🤖 Multi-Agent Coordination • Task Delegation • Workflows  │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                 MEMORY INTELLIGENCE LAYER                  │
│  💾 FTS5 Search • Knowledge Graph • Vector Embeddings       │
└─────────────────────────────────────────────────────────────┘
```

### **Core Components**

| Component | Purpose | Tools |
|-----------|---------|-------|
| **Memory Intelligence** | Search, recall, pattern recognition | search_tool.py, knowledge_graph.py, embedding_service.py |
| **Agent Orchestration** | Task delegation, parallel processing | mini-agent CLI, background execution |
| **Autonomous AI** | Unified intelligence, learning loops | Combined memory + agents + ML |

---

## 🛠️ Installation & Setup

### **Prerequisites Check**
```bash
# Verify memory system
ls -la /root/opencode-dev/.claude/memory/
python3 /root/opencode-dev/.claude/memory/search_tool.py --info

# Verify mini-agent
which mini-agent
mini-agent --version

# Verify Claude skills
ls -la /root/.claude/skills/
```

### **API Configuration**
```bash
# Ensure MiniMax API key is set
echo $MINIMAX_API_KEY

# If missing:
export MINIMAX_API_KEY="your_api_key_here"
echo 'export MINIMAX_API_KEY="your_api_key_here"' >> ~/.bashrc
```

### **Health Check**
```bash
# Memory system health
python3 /root/opencode-dev/.claude/memory/memory_stats.py

# Agent system health
mini-agent --workspace /root/opencode-dev --task "system health check"

# Skills availability
ls /root/.claude/skills/*/SKILL.md
```

---

## 💡 Usage Patterns by Use Case

### **🔍 Research & Analysis**

**Scenario:** Need to understand project patterns and history

```bash
# 1. Search historical context
python3 /root/opencode-dev/.claude/memory/search_tool.py --query "similar_analysis" --category "project"

# 2. Semantic pattern search
python3 /root/opencode-dev/.claude/memory/embedding_service.py --search "code quality issues"

# 3. Knowledge graph exploration
python3 /root/opencode-dev/.claude/memory/knowledge_graph.py --query "RPC" --relate "Supabase"

# 4. Deep autonomous analysis
/skill autonomous-ai execute "comprehensive project analysis with historical context"
```

### **🐛 Bug Investigation & Resolution**

**Scenario:** Complex bug that might have historical patterns

```bash
# 1. Check for similar bugs in memory
python3 /root/opencode-dev/.claude/memory/search_tool.py --query "similar_bug_symptoms" --category "known_issues"

# 2. Spawn specialized bug analysis agent
mini-agent --workspace /root/opencode-dev --task "analyze bug: [bug_description] using historical patterns"

# 3. Autonomous bug resolution (high-confidence issues)
/skill autonomous-ai fix-bug "bug_description" --auto-resolve

# 4. Learn from resolution for future bugs
/skill autonomous-ai learn-from-task "bug_resolution" --update-patterns
```

### **⚡ Performance Optimization**

**Scenario:** System performance issues requiring multi-domain analysis

```bash
# 1. Parallel analysis across domains
mini-agent --task "analyze frontend performance bottlenecks" &
mini-agent --task "analyze backend performance issues" &
mini-agent --task "analyze database optimization opportunities" &
wait

# 2. Synthesize results with memory context
/skill autonomous-ai execute "synthesize performance analysis with historical optimization patterns"

# 3. Predictive performance monitoring
/skill autonomous-ai monitor-health --predict-performance-issues
```

### **📖 Documentation & Knowledge Management**

**Scenario:** Keep documentation synchronized with evolving codebase

```bash
# 1. Autonomous documentation sync
/skill autonomous-ai docs-sync --auto-update

# 2. Knowledge graph analysis for documentation gaps
python3 /root/opencode-dev/.claude/memory/knowledge_graph.py --graph --identify-gaps

# 3. Learning-based documentation improvement
/skill autonomous-ai learn-from-task "documentation_patterns" --improve-quality
```

### **🏗️ Feature Development**

**Scenario:** Complex feature requiring analysis, planning, and implementation

```bash
# 1. Autonomous end-to-end feature development
/skill autonomous-ai project-autopilot \
  --project-goal "implement_user_authentication" \
  --autonomy-level "moderate" \
  --learning-enabled

# 2. Memory-informed architecture decisions
python3 /root/opencode-dev/.claude/memory/search_tool.py --query "authentication_patterns" --category "tech_stack"

# 3. Parallel development streams
mini-agent --task "design authentication database schema" &
mini-agent --task "implement frontend authentication UI" &
mini-agent --task "create authentication API endpoints" &
```

---

## 🎛️ Advanced Orchestration Patterns

### **1. Sequential Pipeline with Learning**
```bash
#!/bin/bash
# intelligent_pipeline.sh

echo "🚀 Starting intelligent pipeline..."

# Step 1: Analysis with memory context
echo "📊 Phase 1: Memory-informed analysis"
memory_context=$(python3 /root/opencode-dev/.claude/memory/search_tool.py --query "pipeline_analysis" --format json)
mini-agent --task "analyze current state with context: $memory_context"

# Step 2: Planning with historical success patterns
echo "📋 Phase 2: Intelligent planning"
mini-agent --task "create implementation plan using successful historical patterns"

# Step 3: Implementation with autonomous quality checks
echo "⚡ Phase 3: Implementation with AI oversight"
/skill autonomous-ai execute "implement plan with continuous quality monitoring"

# Step 4: Learning update
echo "🧠 Phase 4: Update knowledge base"
/skill autonomous-ai learn-from-task "pipeline_execution" --update-success-patterns

echo "✅ Intelligent pipeline complete"
```

### **2. Adaptive Parallel Processing**
```bash
#!/bin/bash
# adaptive_parallel.sh

# Determine optimal parallelism based on memory patterns
optimal_agents=$(python3 /root/opencode-dev/.claude/memory/search_tool.py --query "optimal_parallelism" --format json | jq '.suggested_agents // 3')

echo "🤖 Spawning $optimal_agents agents for adaptive processing..."

# Dynamic agent spawning
for i in $(seq 1 $optimal_agents); do
    mini-agent --task "parallel analysis task $i with learning feedback" &
    pids[${i}]=$!
done

# Intelligent wait with progress monitoring
for pid in ${pids[*]}; do
    wait $pid
    echo "✅ Agent $pid completed"
done

# Synthesize results with AI
/skill autonomous-ai execute "synthesize parallel results and update knowledge"
```

### **3. Self-Healing System**
```bash
#!/bin/bash
# self_healing.sh

while true; do
    echo "🔍 Proactive system monitoring..."

    # AI predicts potential issues
    /skill autonomous-ai monitor-health --predict-issues --auto-remediate

    # Learn from monitoring patterns
    /skill autonomous-ai learn-from-task "system_monitoring" --improve-prediction

    # Adaptive sleep based on system state
    sleep_duration=$(python3 /root/opencode-dev/.claude/memory/search_tool.py --query "monitoring_interval" --format json | jq '.recommended_seconds // 300')
    sleep $sleep_duration
done
```

---

## 🧠 Memory Intelligence Deep Dive

### **Advanced Memory Queries**
```bash
# Complex category combinations
python3 /root/opencode-dev/.claude/memory/search_tool.py --query "performance" --category "known_issues,tech_stack"

# Time-based pattern analysis
python3 /root/opencode-dev/.claude/memory/search_tool.py --query "bug_resolution" --from "2026-03-01" --to "2026-04-01" --format json

# Confidence-weighted searches
python3 /root/opencode-dev/.claude/memory/search_tool.py --query "architecture_decision" --min-confidence 0.8
```

### **Knowledge Graph Power Queries**
```bash
# Find all entities related to a concept
python3 /root/opencode-dev/.claude/memory/knowledge_graph.py --query "RPC" --depth 2

# Analyze relationship strengths
python3 /root/opencode-dev/.claude/memory/knowledge_graph.py --relate "Frontend" "Backend" --analyze-strength

# Graph evolution analysis
python3 /root/opencode-dev/.claude/memory/knowledge_graph.py --graph --compare-timeframes
```

### **Semantic Search Mastery**
```bash
# Multi-model embedding comparison
python3 /root/opencode-dev/.claude/memory/embedding_service.py --search "database optimization" --model minimax
python3 /root/opencode-dev/.claude/memory/embedding_service.py --search "database optimization" --model local

# Embedding quality analysis
python3 /root/opencode-dev/.claude/memory/embedding_service.py --stats --analyze-quality

# Batch embedding for new content
python3 /root/opencode-dev/.claude/memory/embedding_service.py --embed-all --force-update
```

---

## 🤖 Agent Orchestration Mastery

### **Custom Agent Patterns**
```bash
# Specialist agent spawning
mini-agent --workspace /root/opencode-dev --task "security audit with penetration testing focus"
mini-agent --workspace /root/opencode-dev --task "accessibility audit with WCAG compliance check"
mini-agent --workspace /root/opencode-dev --task "performance audit with real-world usage patterns"

# Resource-aware orchestration
available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7*100/$2}')
if [ $available_memory -gt 80 ]; then
    echo "High memory available, enabling parallel processing"
    # Spawn multiple agents
else
    echo "Memory constrained, using sequential processing"
    # Sequential execution
fi
```

### **Agent Communication Patterns**
```bash
# Shared state management
mkdir -p /tmp/agent_shared_state

# Agent 1: Producer
mini-agent --task "analyze codebase and write findings to /tmp/agent_shared_state/analysis.json"

# Agent 2: Consumer
mini-agent --task "read analysis from /tmp/agent_shared_state/analysis.json and generate recommendations"

# Agent 3: Synthesizer
mini-agent --task "combine analysis and recommendations into final report"
```

### **Error Recovery Orchestration**
```bash
# Robust agent execution with retry logic
max_retries=3
retry_count=0

while [ $retry_count -lt $max_retries ]; do
    if mini-agent --task "complex_analysis_task"; then
        echo "✅ Task completed successfully"
        break
    else
        retry_count=$((retry_count + 1))
        echo "⚠️ Attempt $retry_count failed, retrying with simplified approach..."

        # Adapt task complexity based on failure
        case $retry_count in
            1) simplified_task="basic_analysis_task" ;;
            2) simplified_task="minimal_analysis_task" ;;
            3) simplified_task="emergency_fallback_task" ;;
        esac

        mini-agent --task "$simplified_task"
    fi
done
```

---

## 🎯 Autonomous AI Advanced Usage

### **Learning Configuration**
```python
# /root/.claude/skills/autonomous-ai/config/learning_config.py

LEARNING_CONFIG = {
    "memory_integration": {
        "search_weight": 0.7,
        "graph_weight": 0.5,
        "semantic_weight": 0.6
    },
    "agent_orchestration": {
        "max_parallel_agents": 5,
        "task_complexity_threshold": 0.8,
        "auto_retry_enabled": True
    },
    "autonomous_decisions": {
        "confidence_threshold": 0.85,
        "risk_tolerance": "moderate",
        "human_oversight": ["critical", "destructive"]
    },
    "learning_parameters": {
        "pattern_learning_rate": 0.1,
        "knowledge_decay_rate": 0.05,
        "exploration_factor": 0.15
    }
}
```

### **Custom Intelligence Workflows**
```bash
# Create custom AI workflow
cat > /tmp/custom_ai_workflow.py << 'EOF'
#!/usr/bin/env python3
"""Custom AI workflow combining all intelligence layers"""

import subprocess
import json
from pathlib import Path

class IntelligentWorkflow:
    def __init__(self, task_description):
        self.task = task_description
        self.memory_context = self.gather_memory_context()
        self.execution_plan = self.create_execution_plan()

    def gather_memory_context(self):
        """Gather relevant context from memory system"""
        cmd = [
            "python3", "/root/opencode-dev/.claude/memory/search_tool.py",
            "--query", self.task,
            "--format", "json",
            "--limit", "10"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return json.loads(result.stdout)

    def create_execution_plan(self):
        """AI-generated execution plan based on memory context"""
        # Analyze memory context and generate optimal approach
        historical_success = self.analyze_historical_success()
        return self.optimize_approach(historical_success)

    def execute(self):
        """Execute the intelligent workflow"""
        for step in self.execution_plan:
            self.execute_step(step)
            self.update_knowledge(step)

    def execute_step(self, step):
        """Execute individual workflow step"""
        if step["type"] == "agent_task":
            subprocess.run(["mini-agent", "--task", step["description"]])
        elif step["type"] == "memory_update":
            self.update_memory(step["data"])

    def update_knowledge(self, step):
        """Update knowledge base with step results"""
        # Learn from execution and update memory
        pass

# Usage
workflow = IntelligentWorkflow("optimize database performance")
workflow.execute()
EOF

python3 /tmp/custom_ai_workflow.py
```

---

## 📊 Monitoring & Analytics

### **System Health Dashboard**
```bash
#!/bin/bash
# intelligence_dashboard.sh

echo "🧠 Claude Agent Intelligence System Dashboard"
echo "============================================="

# Memory system health
echo "💾 Memory System:"
python3 /root/opencode-dev/.claude/memory/memory_stats.py --json | jq '{
    total_notes: .total_notes,
    quality_score: .quality_score,
    categories: .categories | length,
    embedding_coverage: .embedding_coverage
}'

# Agent system health
echo "🤖 Agent System:"
echo "  Active agents: $(pgrep mini-agent | wc -l)"
echo "  Recent runs: $(ls /root/.mini-agent/log/agent_run_*.log | wc -l)"
echo "  Success rate: $(grep -l "Session Statistics" /root/.mini-agent/log/agent_run_*.log | wc -l)"

# Knowledge graph metrics
echo "🕸️  Knowledge Graph:"
python3 /root/opencode-dev/.claude/memory/knowledge_graph.py --graph --json | jq '{
    entities: .total_entities,
    relationships: .total_relationships,
    connectivity: .avg_connectivity
}'

# AI learning metrics
echo "🎓 AI Learning:"
echo "  Pattern accuracy: $(grep -c "learning_success" /root/.mini-agent/log/*.log)"
echo "  Knowledge updates: $(grep -c "knowledge_update" /root/.mini-agent/log/*.log)"

echo "============================================="
```

### **Performance Analytics**
```bash
# Analyze system performance over time
python3 << 'EOF'
import json
import glob
from datetime import datetime
import matplotlib.pyplot as plt

# Collect performance metrics
metrics = []
for log_file in glob.glob("/root/.mini-agent/log/agent_run_*.log"):
    with open(log_file) as f:
        content = f.read()
        if "API Tokens Used:" in content:
            tokens = int(content.split("API Tokens Used: ")[1].split()[0].replace(",", ""))
            duration = content.split("Session Duration: ")[1].split()[0]
            metrics.append({"tokens": tokens, "duration": duration})

# Analyze trends
print(f"Average tokens per session: {sum(m['tokens'] for m in metrics) / len(metrics):.0f}")
print(f"Total sessions analyzed: {len(metrics)}")

# Generate efficiency report
efficiency_scores = [m['tokens'] / 60 for m in metrics]  # tokens per minute
print(f"Average efficiency: {sum(efficiency_scores) / len(efficiency_scores):.2f} tokens/min")
EOF
```

---

## 🔧 Troubleshooting & Debugging

### **Common Issues & Solutions**

**Issue: Memory search returns no results**
```bash
# Debug memory database
python3 /root/opencode-dev/.claude/memory/search_tool.py --info
sqlite3 /root/opencode-dev/.claude/memory/memory.db "SELECT COUNT(*) FROM notes;"

# Rebuild memory if corrupted
python3 /root/opencode-dev/.claude/memory/sqlite_backend.py --rebuild
```

**Issue: Mini-agent hanging or failing**
```bash
# Check MCP connections
grep -E "Connected|Failed" /root/.mini-agent/log/agent_run_*.log | tail -5

# Check resource usage
ps aux | grep mini-agent
df -h /tmp

# Clean restart
pkill mini-agent
rm -rf /tmp/mini-agent-*
```

**Issue: AI making poor decisions**
```bash
# Check learning configuration
cat /root/.claude/skills/autonomous-ai/config/learning_config.py

# Analyze decision patterns
grep -E "decision|confidence" /root/.mini-agent/log/*.log | tail -20

# Reset learning if needed
/skill autonomous-ai reset-learning --confirm-reset
```

### **Debug Mode Operation**
```bash
# Enable verbose debugging
export CLAUDE_INTELLIGENCE_DEBUG=1
export MINI_AGENT_VERBOSE=1

# Run with debug output
/skill memory-intelligence --debug
/skill agent-orchestration --debug
/skill autonomous-ai --debug
```

### **System Recovery Procedures**
```bash
# Full system recovery
./scripts/recovery_mode.sh

# Partial recovery options
python3 /root/opencode-dev/.claude/memory/search_tool.py --repair-database
mini-agent --workspace /root/opencode-dev --task "system diagnostic and repair"
/skill autonomous-ai execute "self-diagnostic and repair" --safe-mode
```

---

## 🚀 Future Enhancements & Roadmap

### **Planned Features**
- 🧪 **Experimental Mode:** AI safely tests new approaches
- 🌐 **Distributed Processing:** Multi-node agent coordination
- 🎓 **Curriculum Learning:** Progressive skill development
- 🔮 **Advanced Prediction:** Deep learning outcome models
- 🤝 **Multi-Project Learning:** Cross-project knowledge sharing

### **Integration Opportunities**
- 📱 **Mobile Interface:** Claude mobile app integration
- 🌍 **Web Dashboard:** Real-time system monitoring
- 📊 **Analytics Platform:** Advanced intelligence metrics
- 🔗 **API Gateway:** External system integration
- 🎯 **Custom Agents:** Domain-specific intelligent agents

### **Research Areas**
- 🧠 **Cognitive Architectures:** Human-like reasoning patterns
- 🔬 **Emergent Behaviors:** Complex system dynamics
- 📈 **Optimization Algorithms:** Meta-learning approaches
- 🛡️ **Safety Research:** Robust autonomous systems
- 🎭 **Human-AI Collaboration:** Seamless interaction patterns

---

## 📞 Support & Community

### **Getting Help**
- 📖 **Documentation:** This guide + individual skill docs
- 🐛 **Issues:** Report problems with detailed logs
- 💡 **Feature Requests:** Suggest new capabilities
- 🤝 **Community:** Share patterns and best practices

### **Contributing**
- 🔧 **Bug Fixes:** Help improve system reliability
- ⚡ **Performance:** Optimize algorithms and workflows
- 📚 **Documentation:** Improve guides and examples
- 🧪 **Testing:** Add test cases and validation
- 💡 **Innovation:** Develop new intelligence patterns

---

**Remember:** This is a living system that learns and evolves. The more you use it, the more intelligent it becomes. Start simple, experiment gradually, and let the AI learn from your patterns to become your perfect assistant.

**Happy Autonomous AI Development!** 🚀🧠🤖