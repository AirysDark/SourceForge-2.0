using Microsoft.Data.Sqlite;

namespace SourceForge.Server.Services;

public class DatabaseService
{
    private const string DbFile = "Data/SourceForge.db";

    public string ConnectionString => $"Data Source={DbFile}";

    public DatabaseService()
    {
        Directory.CreateDirectory("Data");

        using var conn = new SqliteConnection(ConnectionString);
        conn.Open();

        var cmd = conn.CreateCommand();
        cmd.CommandText = @"
        CREATE TABLE IF NOT EXISTS Projects (
            Id INTEGER PRIMARY KEY AUTOINCREMENT,
            Name TEXT NOT NULL,
            Description TEXT,
            CreatedAt TEXT
        );

        CREATE TABLE IF NOT EXISTS Releases (
            Id INTEGER PRIMARY KEY AUTOINCREMENT,
            ProjectId INTEGER,
            Version TEXT,
            FilePath TEXT,
            Downloads INTEGER DEFAULT 0
        );
        ";

        cmd.ExecuteNonQuery();
    }
}