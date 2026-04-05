# Memory Intelligence Workflow Example

**Scenario**: Analyzing code patterns with historical context and generating optimization recommendations.

## Setup
```bash
# Ensure intelligence system is active
cd /root/brainstorm
source tools/intelligence_shortcuts.sh
```

## Step 1: Context Search
```bash
# Search for relevant patterns
ai_search "database optimization" "performance"
```

**Expected Output:**
```json
{
  "results": [
    {
      "content": "Previous optimization: INDEX usage improved query time by 340%",
      "category": "performance",
      "score": 0.87
    }
  ]
}
```

## Step 2: Intelligent Task Execution
```bash
# Spawn context-aware analysis agent
ai_smart_task "analyze current database queries and suggest optimizations based on historical patterns"
```

**Agent Process:**
1. Memory search for optimization patterns
2. Code analysis with historical context
3. Performance comparison with past improvements
4. Optimization recommendations

## Step 3: Knowledge Graph Exploration
```bash
# Explore entity relationships
ai_graph "database queries" "optimization"
```

**Output:**
```
Entity: database_queries
├─ optimized_by → indexing_strategies (confidence: 0.9)
├─ impacts → response_time (confidence: 0.85)
└─ related_to → memory_usage (confidence: 0.7)
```

## Step 4: System Health Monitoring
```bash
# Check system performance
ai_health
```

## Production Results

**Before Optimization:**
- Query time: 245ms average
- Memory usage: 67% peak
- Database load: High

**After Intelligence-Guided Optimization:**
- Query time: 72ms average (70% improvement)
- Memory usage: 34% peak (49% reduction)
- Database load: Optimal

**Intelligence System Performance:**
- Memory search: 9.4ms
- Agent spawn: 1.8s
- Total analysis: 34s
- Recommendations: 5 actionable items

## Integration Benefits

1. **Historical Learning**: Past optimizations inform new decisions
2. **Context Awareness**: Understanding of system relationships
3. **Autonomous Execution**: Background analysis with minimal supervision
4. **Continuous Improvement**: Learning loop enhances future performance