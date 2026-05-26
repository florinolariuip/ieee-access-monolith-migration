// VULN: CWE-89 SQL Injection — user input concatenated into raw SQL.
// Expected /check_security finding: Critical, SQL Injection.
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace PetRescue.Vuln.SqlInjection;

public class AnimalsController : ControllerBase
{
    private readonly AppDbContext _db;
    public AnimalsController(AppDbContext db) => _db = db;

    [HttpGet("/api/animals/search")]
    public IActionResult Search([FromQuery] string name)
    {
        // VULN: raw SQL with string concatenation.
        var sql = "SELECT * FROM animals WHERE name = '" + name + "'";
        var rows = _db.Animals.FromSqlRaw(sql).ToList();
        return Ok(rows);
    }
}

public class Animal { public int Id { get; set; } public string Name { get; set; } = ""; }
public class AppDbContext : DbContext { public DbSet<Animal> Animals => Set<Animal>(); }
