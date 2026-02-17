namespace SourceFabric.Server.Models;

public class ServerConfig
{
    public ServerSection Server { get; set; } = new();
    public SecuritySection Security { get; set; } = new();
    public NoIpSection NoIP { get; set; } = new();
}

public class ServerSection
{
    // Network Binding
    public string IP { get; set; } = "0.0.0.0";
    public int Port { get; set; } = 8080;

    // HTTPS Support
    public bool EnableHttps { get; set; } = false;
    public int HttpsPort { get; set; } = 443;
    public string CertificatePath { get; set; } = "";
    public string CertificatePassword { get; set; } = "";

    // Domain
    public string Domain { get; set; } = "";
}

public class SecuritySection
{
    public bool EnableLogin { get; set; } = false;
    public string AdminUser { get; set; } = "admin";
    public string AdminPassword { get; set; } = "changeme";
}

public class NoIpSection
{
    public bool Enabled { get; set; } = false;
    public string Hostname { get; set; } = "";
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
}