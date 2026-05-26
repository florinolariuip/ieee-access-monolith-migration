// CLEAN: System.Text.Json with a typed DTO; no BinaryFormatter. /check_security should NOT flag.
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;

namespace PetRescue.Clean.Deser;

public record StateDto(int Version, string Name, int Count);

[JsonSerializable(typeof(StateDto))]
public partial class StateJsonContext : JsonSerializerContext { }

public class StateController : ControllerBase
{
    [HttpPost("/state/load")]
    public IActionResult Load([FromBody] StateDto state)
    {
        // strong typing + ASP.NET binding — no BinaryFormatter anywhere.
        return Ok(state);
    }
}
