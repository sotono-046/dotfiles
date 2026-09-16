import { DatabaseSync } from 'node:sqlite';
export function openDatabase(path) {
  const sqlite = new DatabaseSync(path);
  sqlite.exec('PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;');
  return {
    exec: sql => sqlite.exec(sql), close: () => sqlite.close(),
    prepare(sql) {
      const statement = sqlite.prepare(sql);
      return { bind(...values) { return {
        async first() { return statement.get(...values) || null; },
        async all() { return { results: statement.all(...values) }; },
        async run() { const result = statement.run(...values); return { meta: { changes: Number(result.changes) } }; }
      }; } };
    }
  };
}
