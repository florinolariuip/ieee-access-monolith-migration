// VULN: CWE-862 Missing Authorization — admin endpoint with no [Authorize].
// Expected /check_security finding: Critical, Missing authorization.
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Vuln.MissingAuthz;

[ApiController]
public class AdminController : ControllerBase
{
    // VULN: no [Authorize], so anyone on the network can wipe data.
    [HttpDelete("/admin/animals/{id}")]
    public IActionResult DeleteAnimal(int id) { /* delete */ return NoContent(); }

    [HttpPost("/admin/users/{id}/promote")]
    public IActionResult PromoteToAdmin(int id) { /* promote */ return Ok(); }
}
