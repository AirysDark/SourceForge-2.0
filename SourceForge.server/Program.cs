using SourceForge.Server.Services;
using SourceForge.Server.Models;
using Microsoft.Extensions.Hosting;
using System.Net;

var configService = new ConfigService();
var config = configService.Config;

var builder = WebApplication.CreateBuilder(args);

// Windows Service Support
if (OperatingSystem.IsWindows())
{
    builder.Host.UseWindowsService();
}

// Configure Kestrel
builder.WebHost.ConfigureKestrel(options =>
{
    // HTTP binding
    if (config.Server.IP == "0.0.0.0")
        options.ListenAnyIP(config.Server.Port);
    else
        options.Listen(IPAddress.Parse(config.Server.IP), config.Server.Port);

    // HTTPS binding (if enabled)
    if (config.Server.EnableHttps &&
        !string.IsNullOrWhiteSpace(config.Server.CertificatePath) &&
        File.Exists(config.Server.CertificatePath))
    {
        if (config.Server.IP == "0.0.0.0")
        {
            options.ListenAnyIP(config.Server.HttpsPort, listenOptions =>
            {
                listenOptions.UseHttps(
                    config.Server.CertificatePath,
                    config.Server.CertificatePassword);
            });
        }
        else
        {
            options.Listen(IPAddress.Parse(config.Server.IP),
                config.Server.HttpsPort,
                listenOptions =>
                {
                    listenOptions.UseHttps(
                        config.Server.CertificatePath,
                        config.Server.CertificatePassword);
                });
        }
    }
});

// Register services
builder.Services.AddSingleton(configService);
builder.Services.AddSingleton<DatabaseService>();
builder.Services.AddRazorPages();

var app = builder.Build();

// Redirect HTTP ? HTTPS if enabled
if (config.Server.EnableHttps)
{
    app.UseHttpsRedirection();
}

app.UseStaticFiles();
app.UseRouting();
app.MapRazorPages();

PrintStartupInfo(config);

app.Run();


// =====================
// Helper
// =====================
static void PrintStartupInfo(ServerConfig config)
{
    Console.WriteLine("=================================");
    Console.WriteLine("     SourceForge Server");
    Console.WriteLine("=================================");
    Console.WriteLine($"HTTP  : {config.Server.IP}:{config.Server.Port}");

    if (config.Server.EnableHttps)
        Console.WriteLine($"HTTPS : {config.Server.IP}:{config.Server.HttpsPort}");

    Console.WriteLine($"Login Enabled: {config.Security.EnableLogin}");
    Console.WriteLine("=================================");
}