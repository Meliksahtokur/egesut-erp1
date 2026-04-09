# Memory Intelligence Skill

**Description:** Advanced memory search, knowledge graph queries, and intelligent data retrieval for Claude Agent

**Use Cases:**
- Search through project memory with FTS5 full-text search
- Query knowledge graph for entity relationships
- Get memory statistics and quality metrics
- Semantic search with vector embeddings
- Pattern discovery across historical data

**When to Use:**
- Need to recall previous conversations, decisions, or patterns
- Looking for similar past solutions or approaches
- Analyzing project knowledge and relationships
- Understanding codebase patterns and technical debt
- Cross-referencing multiple information sources

---

## Memory Search

**Quick search in memory database:**
```bash
python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "search_term" --limit 5
```

**Advanced search with filters:**
```bash
# Category-specific search
python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "RPC" --category "critical_rules"

# Date range search
python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "bug" --from "2026-04-01" --to "2026-04-05"

# JSON output for programmatic use
python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "memory" --format json
```

**List available categories:**
```bash
python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --list-categories
```

---

## Knowledge Graph

**Query entities and relationships:**
```bash
# Find entity
python3 /home/user/egesut-erp1/.claude/memory/knowledge_graph.py --query "entity_name"

# Graph statistics
python3 /home/user/egesut-erp1/.claude/memory/knowledge_graph.py --graph

# Find relationship between entities
python3 /home/user/egesut-erp1/.claude/memory/knowledge_graph.py --relate "Entity1" "Entity2"

# Path between entities
python3 /home/user/egesut-erp1/.claude/memory/knowledge_graph.py --path "Entity1" "Entity2"
```

---

## Semantic Search

**Vector-based semantic search:**
```bash
# Semantic search (meaning-based, not keyword)
python3 /home/user/egesut-erp1/.claude/memory/embedding_service.py --search "project management workflow"

# Get embedding statistics
python3 /home/user/egesut-erp1/.claude/memory/embedding_service.py --stats

# Generate embeddings for all notes
python3 /home/user/egesut-erp1/.claude/memory/embedding_service.py --embed-all
```

---

## Memory Statistics

**Get memory health and metrics:**
```bash
# Detailed memory report
python3 /home/user/egesut-erp1/.claude/memory/memory_stats.py

# JSON output
python3 /home/user/egesut-erp1/.claude/memory/memory_stats.py --json

# Cleanup suggestions
python3 /home/user/egesut-erp1/.claude/memory/memory_stats.py --suggest-cleanup
```

---

## Integration Patterns

**Use in Claude Agent workflows:**

1. **Context-Aware Decisions:**
   ```bash
   # Before making technical decisions
   search_result=$(python3 /home/user/egesut-erp1/.claude/memory/search_tool.py --query "similar_problem" --format json)
   # Use results to inform current decision
   ```

2. **Pattern Recognition:**
   ```bash
   # Analyze historical patterns
   python3 /home/user/egesut-erp1/.claude/memory/knowledge_graph.py --query "bug_pattern"
   ```

3. **Quality Assurance:**
   ```bash
   # Check memory health before important operations
   python3 /home/user/egesut-erp1/.claude/memory/memory_stats.py --suggest-cleanup
   ```

---

## API Reference

**Memory Database Schema:**
- `notes` table: id, timestamp, category, content, priority, tags, confidence, source
- `notes_fts` table: Full-text search index
- `notes_embeddings` table: Vector embeddings for semantic search

**Knowledge Graph Schema:**
- `entities` table: id, name, type, count, first_seen, last_seen
- `relationships` table: entity1_id, entity2_id, relationship_type, weight
- `entity_notes` table: Links entities to memory notes

**Categories:**
- project, tech_stack, file_structure, critical_rules, database_schema
- rpc_reference, domain_rules, commands, known_issues, mcp_permissions
- references, agent_identity, memory_enhancement, memory_tools, etc.

---

## Best Practices

1. **Search First:** Always search memory before asking questions or making decisions
2. **Categorize Results:** Use category filters for focused searches
3. **Time Context:** Use date filters for recent vs historical patterns
4. **Semantic + Keyword:** Combine FTS search with semantic search for best results
5. **Graph Exploration:** Use knowledge graph to discover unexpected relationships
6. **Quality Monitoring:** Regular memory stats checks ensure system health

**Remember:** This memory system learns from every interaction. The more you use it, the more intelligent it becomes.