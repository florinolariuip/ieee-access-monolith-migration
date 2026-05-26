// CLEAN: admin endpoint is role-protected. /check_security should NOT flag.
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Clean.Authz;

[ApiController]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    [HttpDelete("/admin/animals/{id}")]
    public IActionResult DeleteAnimal(int id) { return NoContent(); }

    [HttpPost("/admin/users/{id}/promote")]
    public IActionResult PromoteToAdmin(int id) { return Ok(); }
}
