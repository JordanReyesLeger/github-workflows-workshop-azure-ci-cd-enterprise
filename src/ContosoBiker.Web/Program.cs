using System.Runtime.InteropServices;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var inicio = DateTimeOffset.UtcNow;
var construccion = InformacionConstruccion.Leer(app.Environment.ContentRootPath);

app.UseDefaultFiles();
app.UseStaticFiles();

// El ambiente lo pone Terraform como app setting (AMBIENTE); la versión y el commit
// los escribe el pipeline de la aplicación en buildinfo.json al construir.
app.MapGet("/api/info", (IConfiguration configuracion) => new
{
    ambiente = configuracion["AMBIENTE"] ?? "local",
    version = construccion.Version,
    commit = construccion.Commit,
    publicado = inicio,
    runtime = RuntimeInformation.FrameworkDescription,
    servidor = Environment.MachineName,
});

// Lo usan App Service (health check) y la prueba de humo del pipeline.
app.MapGet("/health", () => Results.Ok(new { estado = "ok" }));

app.Run();

record InformacionConstruccion(string Version, string Commit)
{
    public static InformacionConstruccion Leer(string carpeta)
    {
        var archivo = Path.Combine(carpeta, "buildinfo.json");
        if (!File.Exists(archivo))
        {
            return new("0.0.0-local", "local");
        }

        using var json = JsonDocument.Parse(File.ReadAllText(archivo));
        var raiz = json.RootElement;
        return new(
            raiz.TryGetProperty("version", out var v) ? v.GetString() ?? "?" : "?",
            raiz.TryGetProperty("commit", out var c) ? c.GetString() ?? "?" : "?");
    }
}

// Permite a las pruebas arrancar la app con WebApplicationFactory<Program>.
public partial class Program;
