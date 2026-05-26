// VULN: CWE-347 Insufficient JWT Verification — ReadJwtToken without ValidateToken.
// Expected /check_security finding: Critical, Missing JWT signature verification.
using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Http;

namespace PetRescue.Vuln.JwtUnverified;

public class TokenMiddleware
{
    private readonly RequestDelegate _next;
    public TokenMiddleware(RequestDelegate next) => _next = next;

    public async Task Invoke(HttpContext ctx)
    {
        var raw = ctx.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");
        // VULN: ReadJwtToken DOES NOT verify the signature.
        var token = new JwtSecurityTokenHandler().ReadJwtToken(raw);
        ctx.Items["user"] = token.Subject;
        await _next(ctx);
    }
}
