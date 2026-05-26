// CLEAN: JwtBearer with full TokenValidationParameters. /check_security should NOT flag.
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace PetRescue.Clean.Jwt;

public static class AuthExtensions
{
    public static IServiceCollection AddAppJwt(this IServiceCollection services, IConfiguration cfg)
    {
        var key = cfg["Jwt:Key"] ?? throw new InvalidOperationException("Jwt:Key missing");
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(o =>
            {
                o.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = cfg["Jwt:Issuer"],
                    ValidAudience = cfg["Jwt:Audience"],
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
                };
            });
        return services;
    }
}
