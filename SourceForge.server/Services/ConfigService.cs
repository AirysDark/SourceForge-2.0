using System.Text.Json;
using SourceForge.Server.Models;

namespace SourceForge.Server.Services;

public class ConfigService
{
    private const string ConfigFile = "config.json";

    private static readonly JsonSerializerOptions JsonOptions =
        new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNameCaseInsensitive = true
        };

    public ServerConfig Config { get; private set; }

    public ConfigService()
    {
        Load();
    }

    // ==============================
    // Load Config Safely
    // ==============================
    private void Load()
    {
        try
        {
            if (!File.Exists(ConfigFile))
            {
                Config = CreateDefault();
                Save();
                return;
            }

            var json = File.ReadAllText(ConfigFile);

            Config = JsonSerializer.Deserialize<ServerConfig>(json, JsonOptions)
                     ?? CreateDefault();

            Validate();
        }
        catch
        {
            // If config is corrupted, back it up
            BackupCorruptedConfig();

            Config = CreateDefault();
            Save();
        }
    }

    // ==============================
    // Save Config
    // ==============================
    public void Save()
    {
        var json = JsonSerializer.Serialize(Config, JsonOptions);
        File.WriteAllText(ConfigFile, json);
    }

    // ==============================
    // Reload Config (future admin panel)
    // ==============================
    public void Reload()
    {
        Load();
    }

    // ==============================
    // Validation & Defaults
    // ==============================
    private void Validate()
    {
        if (Config.Server.Port <= 0)
            Config.Server.Port = 8080;

        if (Config.Server.HttpsPort <= 0)
            Config.Server.HttpsPort = 443;

        if (string.IsNullOrWhiteSpace(Config.Server.IP))
            Config.Server.IP = "0.0.0.0";

        if (Config.Security == null)
            Config.Security = new();

        if (Config.Server == null)
            Config.Server = new();
    }

    // ==============================
    // Default Config
    // ==============================
    private static ServerConfig CreateDefault()
    {
        return new ServerConfig();
    }

    // ==============================
    // Backup Corrupted Config
    // ==============================
    private void BackupCorruptedConfig()
    {
        try
        {
            if (File.Exists(ConfigFile))
            {
                var backupName = $"config_corrupted_{DateTime.UtcNow:yyyyMMddHHmmss}.json";
                File.Move(ConfigFile, backupName);
            }
        }
        catch
        {
            // ignore backup failures
        }
    }
}