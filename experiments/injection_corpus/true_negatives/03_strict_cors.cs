// CLEAN: explicit allow-list CORS policy. /check_security should NOT flag.
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace PetRescue.Clean.Cors;

public static class Program
{
    public static void Main()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddCors(o => o.AddPolicy("strict", p =>
            p.WithOrigins("https://petrescue.example.com")
             .WithHeaders("Authorization", "Content-Type")
             .WithMethods("GET", "POST")
        ));
        var app = builder.Build();
        app.UseCors("strict");
        app.Run();
    }
}
