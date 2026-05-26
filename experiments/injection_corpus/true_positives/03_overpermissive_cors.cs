// VULN: CWE-942 Overly Permissive CORS — AllowAnyOrigin + AllowCredentials.
// Expected /check_security finding: High, Insecure CORS.
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace PetRescue.Vuln.Cors;

public static class Program
{
    public static void Main()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
            // VULN: any origin + credentials → CSRF on any site.
            p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod().AllowCredentials()
        ));
        var app = builder.Build();
        app.UseCors();
        app.Run();
    }
}
