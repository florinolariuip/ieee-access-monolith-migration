// CLEAN: parameterised LINQ-to-EF equivalent of TP-01. /check_security should NOT flag.
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace PetRescue.Clean.Sql;

public class AnimalsController : ControllerBase
{
    private readonly AppDbContext _db;
    public AnimalsController(AppDbContext db) => _db = db;

    [HttpGet("/api/animals/search")]
    public IActionResult Search([FromQuery] string name)
    {
        // EF Core translates this to a parameterised query.
        var rows = _db.Animals.Where(a => a.Name == name).ToList();
        return Ok(rows);
    }
}

public class Animal { public int Id { get; set; } public string Name { get; set; } = ""; }
public class AppDbContext : DbContext { public DbSet<Animal> Animals => Set<Animal>(); }
