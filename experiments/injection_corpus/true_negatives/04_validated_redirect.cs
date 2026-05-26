// CLEAN: redirect only to local URLs. /check_security should NOT flag.
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Clean.Redirect;

public class AuthController : Controller
{
    [HttpGet("/login")]
    public IActionResult Login([FromQuery] string returnUrl)
    {
        if (!Url.IsLocalUrl(returnUrl))
        {
            returnUrl = "/";
        }
        return LocalRedirect(returnUrl);
    }
}
