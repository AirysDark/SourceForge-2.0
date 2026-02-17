using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.Sqlite;
using SourceFabric.Server.Models;
using SourceFabric.Server.Services;

namespace SourceFabric.Server.Pages.Projects;

public class ProjectsModel : PageModel
{
    private readonly DatabaseService _db;

    public List<Project> Projects { get; set; } = new();

    public ProjectsModel(DatabaseService db)
    {
        _db = db;
    }

    public void OnGet()
    {
        using var conn = new SqliteConnection(_db.ConnectionString);
        conn.Open();

        var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT Id, Name, Description, CreatedAt FROM Projects";

        using var reader = cmd.ExecuteReader();

        while (reader.Read())
        {
            Projects.Add(new Project
            {
                Id = reader.GetInt32(0),
                Name = reader.GetString(1),
                Description = reader.IsDBNull(2) ? "" : reader.GetString(2)
            });
        }
    }
}