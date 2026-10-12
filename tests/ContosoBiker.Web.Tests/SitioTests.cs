using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace ContosoBiker.Web.Tests;

public class SitioTests(WebApplicationFactory<Program> fabrica) : IClassFixture<WebApplicationFactory<Program>>
{
    private HttpClient Cliente(string? ambiente = null) =>
        fabrica.WithWebHostBuilder(b =>
        {
            if (ambiente is not null)
            {
                b.UseSetting("AMBIENTE", ambiente);
            }
        }).CreateClient();

    [Fact]
    public async Task Health_responde_ok()
    {
        var respuesta = await Cliente().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, respuesta.StatusCode);
        Assert.Contains("ok", await respuesta.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Info_refleja_el_ambiente_configurado()
    {
        var json = await Cliente("dev").GetStringAsync("/api/info");
        using var doc = JsonDocument.Parse(json);

        Assert.Equal("dev", doc.RootElement.GetProperty("ambiente").GetString());
        Assert.False(string.IsNullOrWhiteSpace(doc.RootElement.GetProperty("version").GetString()));
        Assert.StartsWith(".NET", doc.RootElement.GetProperty("runtime").GetString());
    }

    [Fact]
    public async Task Info_usa_local_si_no_hay_ambiente()
    {
        var json = await Cliente().GetStringAsync("/api/info");
        using var doc = JsonDocument.Parse(json);

        Assert.Equal("local", doc.RootElement.GetProperty("ambiente").GetString());
    }

    [Fact]
    public async Task La_portada_trae_los_elementos_que_rellena_el_script()
    {
        var html = await Cliente().GetStringAsync("/");

        Assert.Contains("Contoso Biker", html);
        foreach (var id in new[] { "etiqueta-ambiente", "dato-ambiente", "dato-version", "dato-commit", "dato-fecha", "dato-runtime" })
        {
            Assert.Contains($"id=\"{id}\"", html);
        }
    }

    [Theory]
    [InlineData("/styles.css")]
    [InlineData("/app.js")]
    public async Task Los_recursos_estaticos_existen(string ruta)
    {
        var respuesta = await Cliente().GetAsync(ruta);

        Assert.Equal(HttpStatusCode.OK, respuesta.StatusCode);
    }
}
