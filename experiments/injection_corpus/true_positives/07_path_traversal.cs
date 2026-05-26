// VULN: CWE-22 Path Traversal — Path.Combine on user input without canonicalisation.
// Expected /check_security finding: High, Path traversal.
using System.IO;
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Vuln.PathTraversal;

public class FilesController : ControllerBase
{
    private readonly string _root = "/var/petrescue/uploads";

    [HttpGet("/files")]
    public IActionResult Read([FromQuery] string name)
    {
        // VULN: '..' segments escape _root.
        var path = Path.Combine(_root, name);
        return File(System.IO.File.OpenRead(path), "application/octet-stream");
    }
}
