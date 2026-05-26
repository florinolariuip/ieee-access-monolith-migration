// VULN: CWE-601 Open Redirect — destination from un-validated query parameter.
// Expected /check_security finding: Medium, Open redirect.
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Vuln.OpenRedirect;

public class AuthController : Controller
{
    [HttpGet("/login")]
    public IActionResult Login([FromQuery] string returnUrl)
    {
        // VULN: redirects to anywhere on the internet.
        return Redirect(returnUrl);
    }
}
