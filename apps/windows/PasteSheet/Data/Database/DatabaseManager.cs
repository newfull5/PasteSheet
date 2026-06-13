using System.IO;
using Microsoft.Data.Sqlite;

namespace PasteSheet.Data.Database;

public sealed class DatabaseManager
{
    public static readonly DatabaseManager Shared = new();

    private SqliteConnection? _connection;
    private SqliteTransaction? _currentTransaction;
    private readonly object _lock = new();

    private DatabaseManager() { }

    public string DatabasePath
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "PasteSheet");
            return Path.Combine(dir, "paste_sheets.db");
        }
    }

    public void Initialize()
    {
        var dir = Path.GetDirectoryName(DatabasePath)!;
        Directory.CreateDirectory(dir);

        _connection = new SqliteConnection($"Data Source={DatabasePath}");
        _connection.Open();

        Execute(DatabaseSchema.CreateDirectories);
        Execute(DatabaseSchema.CreatePasteSheets);
        Execute(DatabaseSchema.CreateSettings);
        Execute(DatabaseSchema.InsertDefaultDirectory);
        Execute(DatabaseSchema.InsertDefaultMouseEdge);
        MigrateIfNeeded();
        Execute(DatabaseSchema.SyncOrphanDirectories);
    }

    private void MigrateIfNeeded()
    {
        var columns = QueryColumnNames("paste_sheets");
        if (!columns.Contains("memo"))
            Execute(DatabaseSchema.AddMemoColumn);
    }

    private List<string> QueryColumnNames(string table) =>
        Query($"PRAGMA table_info({table})", null, r => r.GetString(1));

    // MARK: - Execution Helpers

    public void Execute(string sql, IReadOnlyList<object?>? parameters = null)
    {
        lock (_lock)
        {
            using var cmd = _connection!.CreateCommand();
            cmd.Transaction = _currentTransaction;
            cmd.CommandText = sql;
            Bind(cmd, parameters);
            cmd.ExecuteNonQuery();
        }
    }

    public long ExecuteReturningId(string sql, IReadOnlyList<object?>? parameters = null)
    {
        lock (_lock)
        {
            using var cmd = _connection!.CreateCommand();
            cmd.Transaction = _currentTransaction;
            cmd.CommandText = sql;
            Bind(cmd, parameters);
            cmd.ExecuteNonQuery();

            using var idCmd = _connection.CreateCommand();
            idCmd.Transaction = _currentTransaction;
            idCmd.CommandText = "SELECT last_insert_rowid()";
            return (long)idCmd.ExecuteScalar()!;
        }
    }

    public List<T> Query<T>(string sql, IReadOnlyList<object?>? parameters, Func<SqliteDataReader, T> mapper)
    {
        lock (_lock)
        {
            using var cmd = _connection!.CreateCommand();
            cmd.Transaction = _currentTransaction;
            cmd.CommandText = sql;
            Bind(cmd, parameters);
            using var reader = cmd.ExecuteReader();
            var results = new List<T>();
            while (reader.Read())
                results.Add(mapper(reader));
            return results;
        }
    }

    public T? QueryOne<T>(string sql, IReadOnlyList<object?>? parameters, Func<SqliteDataReader, T> mapper)
    {
        var results = Query(sql, parameters, mapper);
        return results.Count > 0 ? results[0] : default;
    }

    public void ExecuteInTransaction(Action block)
    {
        lock (_lock)
        {
            using var tx = _connection!.BeginTransaction();
            _currentTransaction = tx;
            try
            {
                block();
                tx.Commit();
            }
            catch
            {
                tx.Rollback();
                throw;
            }
            finally
            {
                _currentTransaction = null;
            }
        }
    }

    private static void Bind(SqliteCommand cmd, IReadOnlyList<object?>? parameters)
    {
        if (parameters is null) return;
        for (int i = 0; i < parameters.Count; i++)
            cmd.Parameters.AddWithValue($"@p{i + 1}", parameters[i] ?? DBNull.Value);
    }
}
