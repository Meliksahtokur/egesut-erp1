# Agent Orchestration Skill

**Description:** Advanced multi-agent coordination, task delegation, and autonomous workflow orchestration for Claude

**Use Cases:**
- Spawn mini-agents for complex, multi-step tasks
- Parallel processing across multiple agents
- Pipeline workflows with sequential agent execution
- Background task management and monitoring
- Cross-agent memory sharing and coordination

**When to Use:**
- Tasks requiring deep analysis across multiple domains
- Long-running operations that can run in background
- Complex workflows with interdependent steps
- Parallel processing of independent work streams
- Tasks that benefit from specialized agent expertise

---

## Agent Spawning

> **NOT:** `mini-agent` CLI bu sistemde kurulu değil. Aşağıdaki pattern'ler
> Claude Code'un native `Agent` tool'u ile uygulanır.

**EgeSüt ERP Agent Tipleri:**
- `erp-explorer` — keşif, okuma, analiz
- `erp-implementer` — DB migration, RPC, frontend yazma
- `erp-qa-git` — syntax kontrol, commit/push

**Eski mini-agent karşılıkları (referans için):**
```bash
# mini-agent --workspace /home/user/egesut-erp1 --task "analyze codebase for RPC violations"
# → Artık: Agent(subagent_type="erp-explorer", prompt="RPC violations analiz et")
```

---

## Orchestration Patterns

### 1. **Sequential Pipeline**
```bash
# Step 1: Analysis
mini-agent --task "analyze code quality and identify issues" &&

# Step 2: Planning
mini-agent --task "create remediation plan based on previous analysis" &&

# Step 3: Implementation
mini-agent --task "implement top 3 priority fixes from plan"
```

### 2. **Parallel Processing**
```bash
# Launch multiple agents simultaneously
mini-agent --task "analyze frontend code patterns" &
PID1=$!

mini-agent --task "analyze backend architecture" &
PID2=$!

mini-agent --task "audit database schema and relationships" &
PID3=$!

# Wait for all to complete
wait $PID1 $PID2 $PID3
echo "All parallel analyses complete"
```

### 3. **Conditional Workflows**
```bash
# Analysis first
RESULT=$(mini-agent --task "check if critical bugs exist" --format json)

# Conditional execution based on analysis
if echo "$RESULT" | grep -q "critical"; then
    mini-agent --task "immediate critical bug remediation"
else
    mini-agent --task "routine quality improvements"
fi
```

### 4. **Memory-Informed Orchestration**
```bash
# Check historical patterns first
PATTERNS=$(python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "similar_task" --format json)

# Delegate based on memory
if echo "$PATTERNS" | grep -q "successful_approach"; then
    mini-agent --task "apply proven approach from memory to current task"
else
    mini-agent --task "experimental approach with detailed logging for future memory"
fi
```

---

## Agent Coordination

### **Resource Sharing**
```bash
# Agent 1: Create shared resource
mini-agent --task "generate shared analysis data in /tmp/shared_analysis.json"

# Agent 2: Use shared resource
mini-agent --task "process analysis from /tmp/shared_analysis.json and generate recommendations"
```

### **Memory Synchronization**
```bash
# Agent with memory update
mini-agent --task "analyze patterns and update memory database with findings"

# Subsequent agent using updated memory
python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "latest_findings"
mini-agent --task "apply latest findings to optimize current process"
```

---

## Monitoring & Management

### **Log Analysis**
```bash
# View recent agent runs
ls -la /root/.mini-agent/log/agent_run_*.log | tail -5

# Analyze latest run
tail -100 /root/.mini-agent/log/agent_run_$(date +%Y%m%d)_*.log | grep -E "(✓|✗|Step|Summary)"

# Get agent statistics
mini-agent log
```

### **Performance Tracking**
```bash
# Agent performance analysis
grep -E "Session Duration|API Tokens" /root/.mini-agent/log/agent_run_*.log | tail -10

# Resource utilization
du -sh /root/.mini-agent/log/
```

### **Error Recovery**
```bash
# Check for failed agents
grep -l "Error:" /root/.mini-agent/log/agent_run_*.log | tail -3

# Retry with adjusted parameters
mini-agent --task "retry_previous_task_with_simplified_approach"
```

---

## Advanced Orchestration

### **Multi-Workspace Coordination**
```bash
# Coordinate across different project workspaces
mini-agent --workspace /root/opencode-dev --task "analyze frontend patterns" &
mini-agent --workspace /root/egesut-erp1 --task "analyze backend patterns" &
mini-agent --workspace /root/qwen-dev --task "analyze AI integration patterns" &

# Combine results
wait
mini-agent --workspace /root/opencode-dev --task "synthesize cross-project analysis results"
```

### **Dynamic Task Generation**
```bash
# Agent generates its own subtasks
mini-agent --task "analyze project and generate prioritized task list for optimization"

# Execute generated tasks
while read -r task; do
    mini-agent --task "$task"
done < generated_tasks.txt
```

### **Feedback Loops**
```bash
# Agent 1: Initial implementation
mini-agent --task "implement feature X with testing"

# Agent 2: Quality review
mini-agent --task "review feature X implementation and suggest improvements"

# Agent 3: Apply improvements
mini-agent --task "apply suggested improvements to feature X"
```

---

## Integration with Memory System

```bash
# Pre-execution memory check
memory_context=$(python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "task_context" --format json)

# Task execution with context
mini-agent --task "execute task with context: $memory_context"

# Post-execution memory update
mini-agent --task "analyze results and update memory system with learnings"
```

---

## Best Practices

1. **Task Granularity:** Break complex tasks into smaller, manageable pieces
2. **Resource Planning:** Consider memory, CPU, and time requirements
3. **Error Handling:** Always plan for agent failure scenarios
4. **Logging:** Ensure comprehensive logging for debugging and analysis
5. **Memory Integration:** Leverage historical patterns for better decisions
6. **Parallel Safety:** Ensure agents don't conflict when running simultaneously
7. **Progress Monitoring:** Regular check-ins on long-running agents
8. **Resource Cleanup:** Clean up temporary files and resources after completion

---

## Troubleshooting

**Common Issues:**
- **Agent hanging:** Check MCP server connections
- **Memory conflicts:** Ensure proper workspace isolation
- **Resource exhaustion:** Monitor system resources during parallel execution
- **Incomplete results:** Check agent logs for step-by-step analysis

**Debug Commands:**
```bash
# Check agent health
mini-agent --version

# Verify MCP connections
grep -E "Connected|Failed" /root/.mini-agent/log/agent_run_*.log | tail -5

# Resource usage
ps aux | grep mini-agent
```

**Recovery Strategies:**
- Restart with simpler tasks
- Reduce parallelism
- Clear temporary workspace
- Check MCP server status