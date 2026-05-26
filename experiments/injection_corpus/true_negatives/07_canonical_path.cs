// CLEAN: path is canonicalised and verified to be inside _root. /check_security should NOT flag.
using System.IO;
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Clean.Path;

public class FilesController : ControllerBase
{
    private readonly string _root = "/var/petrescue/uploads";

    [HttpGet("/files")]
    public IActionResult Read([FromQuery] string name)
    {
        var requested = Path.GetFullPath(Path.Combine(_root, name));
        if (!requested.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
        {
            return BadRequest("invalid path");
        }
        return File(System.IO.File.OpenRead(requested), "application/octet-stream");
    }
}
