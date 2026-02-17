namespace SourceForge.Server.Models;

public class Release
{
    public int Id { get; set; }
    public int ProjectId { get; set; }
    public string Version { get; set; } = "";
    public string FilePath { get; set; } = "";
    public int Downloads { get; set; }
}