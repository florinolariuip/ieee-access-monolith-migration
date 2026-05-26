// CLEAN: ASP.NET Core's PasswordHasher uses PBKDF2 with defaults. /check_security should NOT flag.
using Microsoft.AspNetCore.Identity;

namespace PetRescue.Clean.Crypto;

public record AppUser(string UserName);

public class PasswordService
{
    private readonly PasswordHasher<AppUser> _hasher = new();

    public string Hash(AppUser user, string password) => _hasher.HashPassword(user, password);

    public bool Verify(AppUser user, string hashed, string provided)
        => _hasher.VerifyHashedPassword(user, hashed, provided) != PasswordVerificationResult.Failed;
}
