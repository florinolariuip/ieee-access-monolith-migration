// VULN: CWE-502 Insecure Deserialization — BinaryFormatter on request body.
// Expected /check_security finding: Critical, Insecure deserialisation.
#pragma warning disable SYSLIB0011
using System.IO;
using System.Runtime.Serialization.Formatters.Binary;
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Vuln.InsecureDeser;

public class StateController : ControllerBase
{
    [HttpPost("/state/load")]
    public IActionResult Load([FromBody] Stream body)
    {
        // VULN: BinaryFormatter is a known RCE vector.
        var fmt = new BinaryFormatter();
        var obj = fmt.Deserialize(body);
        return Ok(obj);
    }
}
