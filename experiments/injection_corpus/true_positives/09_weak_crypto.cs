// VULN: CWE-327 Weak Crypto — MD5 used for password hashing.
// Expected /check_security finding: Medium, Weak cryptography.
using System.Security.Cryptography;
using System.Text;

namespace PetRescue.Vuln.WeakCrypto;

public static class PasswordHasher
{
    public static string Hash(string password)
    {
        // VULN: MD5 is broken for password storage (and even for integrity).
        using var md5 = MD5.Create();
        var bytes = md5.ComputeHash(Encoding.UTF8.GetBytes(password));
        return System.Convert.ToHexString(bytes);
    }
}
