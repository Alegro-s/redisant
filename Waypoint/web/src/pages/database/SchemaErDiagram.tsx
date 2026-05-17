import '@xyflow/react/dist/style.css';
import React, { useCallback, useEffect, useMemo } from 'react';
import dagre from '@dagrejs/dagre';
import {
  Background,
  Controls,
  MiniMap,
  ReactFlow,
  ReactFlowProvider,
  useEdgesState,
  useNodesState,
  type Edge,
  type Node,
} from '@xyflow/react';
import { Box, Button, Paper, Stack, Typography } from '@mui/material';

const COLS = 4;
const CELL_X = 220;
const CELL_Y = 100;
const NODE_W = 200;
const NODE_H = 52;

type FkDef = { column: string; ref_table: string; ref_column: string };
type TableEntry = { foreign_keys?: FkDef[] };

function tablesFromSchema(schema: unknown): string[] {
  if (schema == null || typeof schema !== 'object') return [];
  return Object.keys(schema as Record<string, unknown>).sort();
}

function fkEdgesFromSchema(schema: unknown, tableNames: string[]): { id: string; source: string; target: string; label: string }[] {
  if (schema == null || typeof schema !== 'object') return [];
  const obj = schema as Record<string, TableEntry>;
  const set = new Set(tableNames);
  const out: { id: string; source: string; target: string; label: string }[] = [];
  for (const src of tableNames) {
    const fks = obj[src]?.foreign_keys;
    if (!Array.isArray(fks)) continue;
    fks.forEach((fk, i) => {
      if (set.has(fk.ref_table)) {
        out.push({
          id: `${src}->${fk.ref_table}-${i}`,
          source: src,
          target: fk.ref_table,
          label: fk.column,
        });
      }
    });
  }
  return out;
}

function layoutGrid(names: string[]): Node[] {
  return names.map((name, i) => {
    const row = Math.floor(i / COLS);
    const col = i % COLS;
    return {
      id: name,
      position: { x: col * CELL_X, y: row * CELL_Y },
      data: { label: name.replace(/^[^.]+\./, '') },
      style: { fontSize: 11, padding: 6, borderRadius: 6, maxWidth: NODE_W },
    };
  });
}

function layoutDagre(
  names: string[],
  edges: { id: string; source: string; target: string; label: string }[],
): { nodes: Node[]; edges: Edge[] } {
  const g = new dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}));
  g.setGraph({ rankdir: 'LR', nodesep: 50, ranksep: 90, marginx: 24, marginy: 24 });
  names.forEach((n) => g.setNode(n, { width: NODE_W, height: NODE_H }));
  edges.forEach((e) => {
    if (names.includes(e.source) && names.includes(e.target)) {
      g.setEdge(e.source, e.target);
    }
  });
  dagre.layout(g);
  const nodes: Node[] = names.map((id) => {
    const pos = g.node(id);
    const x = pos?.x ?? 0;
    const y = pos?.y ?? 0;
    return {
      id,
      position: { x: x - NODE_W / 2, y: y - NODE_H / 2 },
      data: { label: id.replace(/^[^.]+\./, '') },
      style: { width: NODE_W, fontSize: 11, padding: 6, borderRadius: 6 },
    };
  });
  const rfEdges: Edge[] = edges.map((e) => ({
    id: e.id,
    source: e.source,
    target: e.target,
    label: e.label,
  }));
  return { nodes, edges: rfEdges };
}

const SchemaErDiagramInner: React.FC<{ schema: unknown }> = ({ schema }) => {
  const names = useMemo(() => tablesFromSchema(schema), [schema]);
  const fkEdges = useMemo(() => fkEdgesFromSchema(schema, names), [schema, names]);
  const useAuto = fkEdges.length > 0;

  const buildFlow = useCallback((): { nodes: Node[]; edges: Edge[] } => {
    if (names.length === 0) return { nodes: [], edges: [] };
    if (useAuto) {
      return layoutDagre(names, fkEdges);
    }
    return { nodes: layoutGrid(names), edges: [] };
  }, [names, fkEdges, useAuto]);

  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);

  useEffect(() => {
    const { nodes: n, edges: e } = buildFlow();
    setNodes(n);
    setEdges(e);
  }, [buildFlow, setEdges, setNodes]);

  const exportJson = () => {
    const blob = new Blob(
      [JSON.stringify({ tables: names, edges: fkEdges }, null, 2)],
      { type: 'application/json' },
    );
    const u = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = u;
    a.download = 'lynx-schema-er.json';
    a.click();
    URL.revokeObjectURL(u);
  };

  if (names.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        Нет таблиц в снимке схемы.
      </Typography>
    );
  }

  return (
    <Stack spacing={2}>
      <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', alignItems: 'center' }}>
        <Typography variant="body2" color="text.secondary">
          {useAuto
            ? `Автораскладка dagre по ${fkEdges.length} FK (интерактивно: перетаскивание, зум).`
            : 'Нет FK в снимке — сетка по таблицам. Агент v2 включает foreign_keys в heartbeat.'}
        </Typography>
        <Button size="small" variant="outlined" onClick={exportJson}>
          Экспорт ER (JSON)
        </Button>
      </Box>
      <Paper variant="outlined" sx={{ height: 400, borderRadius: 2, overflow: 'hidden' }}>
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          fitView
          fitViewOptions={{ padding: 0.15 }}
          proOptions={{ hideAttribution: true }}
        >
          <Background />
          <Controls />
          <MiniMap pannable zoomable />
        </ReactFlow>
      </Paper>
    </Stack>
  );
};

export const SchemaErDiagram: React.FC<{ schema: unknown }> = ({ schema }) => (
  <ReactFlowProvider>
    <SchemaErDiagramInner schema={schema} />
  </ReactFlowProvider>
);
